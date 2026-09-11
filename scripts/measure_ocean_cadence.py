#!/usr/bin/env python3
"""Compare actual production GPU wave probes, integrating all 20s start offsets.

This measures event-model cadence. Native playback and temporal appearance require
the separately sealed native captures; 2, 3 or 4 events in one short clip alone
cannot establish a rate change in a jittered overlapping wave system.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import statistics
import sys


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def measure(path, fractions):
    source = json.loads(path.read_text())
    rows = {}
    for pair in source['overlapSamples']:
        for prefix in ['earlier', 'later']:
            row = [pair[prefix+'Start'], pair[prefix+'Lifetime']]
            key = int(pair[prefix+'ID'])
            assert key not in rows or rows[key] == row
            rows[key] = row
    ordered = sorted(rows)
    assert len(ordered) >= 20 and all(b == a+1 for a,b in zip(ordered, ordered[1:]))
    result = {}
    for name, fraction in fractions.items():
        times = [rows[key][0] + rows[key][1]*fraction for key in ordered]
        intervals = [b-a for a,b in zip(times,times[1:])]
        assert min(intervals) > 0
        low, high = times[0], times[-1]-20
        assert high > low
        breaks = sorted({low,high,*[t for t in times if low < t < high],
                         *[t-20 for t in times if low < t-20 < high]})
        distribution = {}
        for a,b in zip(breaks,breaks[1:]):
            start = (a+b)/2
            count = sum(start <= t < start+20 for t in times)
            distribution[count] = distribution.get(count,0)+(b-a)/(high-low)
        expected = sum(k*v for k,v in distribution.items())
        result[name] = {'event_ids':ordered,'landmark_times':times,'intervals':intervals,
                        'interval_min':min(intervals),'interval_median':statistics.median(intervals),
                        'interval_max':max(intervals),'twenty_second_start_domain':[low,high],
                        'twenty_second_count_distribution':distribution,
                        'expected_events_per_twenty_seconds':expected}
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--parent',type=Path,required=True)
    p.add_argument('--candidate',type=Path,required=True)
    p.add_argument('--header',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    constants = dict(re.findall(r'^#define (\w+) ([0-9.]+)f$',a.header.read_text(),re.M))
    fractions={'arrival':0.0, **{name:float(constants['LIVING_OCEAN_'+name.upper()+'_FULL'])
                               for name in ['crest','break','foam']}}
    parent,candidate = measure(a.parent,fractions),measure(a.candidate,fractions)
    comparison={}
    for name in fractions:
        before,after=parent[name],candidate[name]
        assert before['event_ids']==after['event_ids']
        ratio=after['expected_events_per_twenty_seconds']/before['expected_events_per_twenty_seconds']
        comparison[name]={'cadence_ratio':ratio,'within_ten_percent':.9<=ratio<=1.1,
                          'maximum_matched_landmark_difference_seconds':max(abs(x-y) for x,y in zip(before['landmark_times'],after['landmark_times']))}
    result={'version':'ocean-gpu-cadence-v1','invocation':[sys.executable,*sys.argv],
            'inputs':{str(path.resolve()):sha(path) for path in [a.parent,a.candidate,a.header,Path(__file__)]},
            'fractions_from_production_header':fractions,'parent':parent,'candidate':candidate,
            'comparison':comparison,'pass':all(v['within_ten_percent'] for v in comparison.values()),
            'boundary':'GPU model cadence; verify native clock advancement separately. Every possible 20s start phase in the bounded complete event domain is integrated.'}
    a.out.parent.mkdir(parents=True,exist_ok=True)
    a.out.write_text(json.dumps(result,sort_keys=True,indent=2)+'\n')
    print(json.dumps({'comparison':comparison,'output':str(a.out)}))


if __name__=='__main__':
    main()
