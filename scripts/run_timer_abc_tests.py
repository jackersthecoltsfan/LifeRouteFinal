#!/usr/bin/env python3
"""Exactly three timer groups against unchanged extracted production classes.
Only AVAudioEngine/UIKit endpoints are recorded doubles; no Simulator required.
"""
import os,subprocess,tempfile,json
from pathlib import Path
from liferoute_storage import scratch_root
root=Path(__file__).resolve().parents[1]
domain=(root/'LifeRoute/SessionToolsDomain.swift').read_text()
view=(root/'LifeRoute/ScenicRoyalVisualTimerView.swift').read_text()
core=domain.split('@MainActor\nfinal class VisualTimerCore:',1)[1].split('@MainActor\nfinal class SessionToolsCore:',1)[0]
state=view.split('@MainActor\nfinal class VisualTimerPresentationState:',1)[1].split('// Kept as the existing fullscreen chrome seam;',1)[0]
source='import Foundation\nimport Combine\n@MainActor\nfinal class VisualTimerCore:'+core+'@MainActor\nfinal class VisualTimerPresentationState:'+state
# The external donor ledger is the run's exhaustive input, not a copied timer.
ledger_path=os.environ.get('TIMER_ABC_LEDGER')
if ledger_path:
 ledger=Path(ledger_path)
 groups={
  'LifeRoute/SessionToolsDomain.swift': {
   'initial core/state': [303,304,305,321,659],
   'Start/preset': [370,371,372,373,374,375],
   'deadline/paused/feedback recomputation': [380,382,528,558,616],
   'pause': [401,402], 'resume': [408,409],
   'Add Minute': [413,415,416,418],
   'adjustment/terminal': [424,431,433,438,442,444,561,562],
   'reset': [508,509,510], 'feedback setter rebuilds': [455,462,471,607]},
  'LifeRoute/VisualTimerFeedbackContracts.swift': {
   'scheduler projection': [307], 'adjustment helper': [822,823,825,828,829]},
  'LifeRoute/ScenicRoyalVisualTimerView.swift': {
   'source-bound UI delegation to exercised core/presentation methods':
    [18,68,116,160,180,200,252,276,284,285,370,381,412,637,638,695,798,816,841,853,855,869,893,905,1072]},
  'LifeRoute/V054ContentView.swift': {'source-bound root construction to exercised initial core': [145]}}
 expected={(file,line):group for file,entries in groups.items() for group,lines in entries.items() for line in lines}
 observed={}
 for row in ledger.read_text().splitlines()[2:]:
  file,line,description=[part.strip() for part in row.strip('|').split('|')]
  key=(file,int(line));assert key in expected, f'Unmapped ledger entry {key}'
  observed[key]=description
 assert observed.keys()==expected.keys(), 'Ledger coverage drift'
 manifest=[dict(file=f,line=n,write=observed[(f,n)],evidence=expected[(f,n)]) for f,n in sorted(observed)]
 output=os.environ.get('TIMER_ABC_LEDGER_MAP')
 if output:Path(output).write_text(json.dumps(manifest,indent=2)+'\n')
 print(f'Ledger reconciled: {len(manifest)} entries; native UI aliases use source-call proof plus executed core seams',flush=True)
cache=Path(os.environ.get('LIFEROUTE_CONTRACT_CACHE_DIRECTORY',scratch_root()/'contract-cache-v1'))
cache.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='timer-abc-',dir=cache) as folder:
 generated=Path(folder)/'ProductionTimer.swift';generated.write_text(source)
 executable=Path(folder)/'timer-abc-tests'
 command=['xcrun','swiftc','-parse-as-library',str(root/'LifeRoute/VisualTimerFeedbackContracts.swift'),str(generated),str(root/'scripts/timer_abc_tests.swift')]
 if os.environ.get('TIMER_ABC_TYPECHECK_ONLY')=='1':
  subprocess.run(command+['-typecheck'],cwd=root,check=True)
 else:
  subprocess.run(command+['-o',str(executable)],cwd=root,check=True)
  subprocess.run([str(executable)],cwd=root,check=True)
