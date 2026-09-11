#!/usr/bin/env python3
"""Versioned, phase-insensitive motion comparator from sealed lossless native samples.

Dependencies: numpy and Pillow. Input capture.json lists SHA256-bound frames sampled
alongside motion.mp4; identity.json binds the source, binary and artwork ROI. The
video is retained and verified; calculations use its simultaneous lossless PNGs.
No filtering, denoising, optical interpolation, manual multipliers or beauty verdict.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import numpy as np
from PIL import Image, ImageDraw

VERSION = 'living-motion-range-v1'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--compare', type=Path)
    args = parser.parse_args()
    capture = args.capture.resolve()
    meta = json.loads((capture / 'capture.json').read_text())
    identity = json.loads((capture / 'identity.json').read_text())
    config = identity['configuration']
    artwork = args.root / config['artwork']
    assert sha(artwork) == config['artwork_sha256']
    assert sha(capture / 'motion.mp4') == meta['video_sha256']
    width, height = meta['frame_size']
    art_width, art_height = Image.open(artwork).size
    fill = max(width / art_width, height / art_height)
    uvx, uvy = width / (art_width * fill), height / (art_height * fill)
    def mask(polygons):
        result = Image.new('1', (width, height))
        draw = ImageDraw.Draw(result)
        for polygon in polygons:
            draw.polygon([((x - .5) / uvx * width + width / 2,
                           (y - .5) / uvy * height + height / 2) for x, y in polygon], fill=1)
        return np.asarray(result, dtype=bool)
    masks = {'primary': mask(config['primary'])}
    masks.update({name: mask(polygons) for name, polygons in config.get('depth_regions', {}).items()})
    masks['fixed'] = mask(config.get('fixed_horizon', config['static']))
    assert all(region.any() for region in masks.values())
    frames = []
    for sample in meta['frames']:
        path = capture / sample['file']
        assert sha(path) == sample['sha256'], path
        rgb = np.asarray(Image.open(path).convert('RGB'))
        assert rgb.shape == (height, width, 3)
        frames.append(rgb)
    times = np.array([sample['midpoint'] for sample in meta['frames']])
    assert times[-1] - times[0] >= 20 and np.all(np.diff(times) > 0)
    threshold = 4.0  # mean sRGB byte range, comparator threshold, not perceptibility acceptance
    def describe(selected):
        low = np.minimum.reduce(selected).astype(np.float32)
        high = np.maximum.reduce(selected).astype(np.float32)
        delta = (high - low).mean(axis=2)
        results = {}
        for name, region in masks.items():
            values = delta[region]
            moving = values[values > threshold]
            fraction = len(moving) / len(values)
            median = float(np.median(moving) / 255) if len(moving) else 0.0
            results[name] = {'roi_pixels': int(len(values)), 'moving_pixels': int(len(moving)),
                             'moving_fraction': fraction, 'moving_median_normalized': median,
                             'moving_median_255': median * 255,
                             'motion_score': fraction * median}
        return results
    # Equal nominal 20-second windows, each endpoint recorded with actual time.
    windows = []
    for start in range(len(times)):
        if times[-1] - times[start] < 19.9:
            break
        end = int(np.argmin(abs(times - times[start] - 20)))
        assert abs(times[end] - times[start] - 20) <= .15
        windows.append({'start_sample': start, 'end_sample': end,
                        'actual_seconds': float(times[end] - times[start]),
                        'regions': describe(frames[start:end + 1])})
    assert windows
    aggregate = {region: {key: float(np.mean([w['regions'][region][key] for w in windows]))
                           for key in windows[0]['regions'][region]}
                 for region in masks}
    glance = []
    for start in range(len(times) - 3):
        end = start + 3
        glance.append({'start_sample': start, 'actual_seconds': float(times[end] - times[start]),
                       'regions': describe(frames[start:end + 1])})
    # Opponent-color magnitude in encoded sRGB. A reproducible color-excursion
    # proxy, not a perceptual color-space claim or license to force saturation.
    chroma = []
    clipped = []
    primary = masks['primary']
    for frame in frames:
        rgb = frame[primary].astype(np.float32) / 255
        r, g, b = rgb.T
        chroma.append(np.sqrt(((r-g)**2 + (g-b)**2 + (b-r)**2) / 2))
        clipped.append(float((rgb >= 254/255).any(axis=1).mean()))
    chroma_range = np.maximum.reduce(chroma) - np.minimum.reduce(chroma)
    result = {'formula_version': VERSION,
              'formula': 'moving ROI fraction * median(mean RGB temporal max-minus-min / 255) among moving pixels',
              'threshold_255': threshold, 'target_window_seconds': 20,
              'phase_insensitive': True, 'scene': meta['scene'],
              'input_clip': str(capture/'motion.mp4'), 'video_sha256': meta['video_sha256'],
              'capture_manifest': str(capture/'capture.json'), 'capture_sha256': sha(capture/'capture.json'),
              'roi_identity': str(capture/'identity.json'), 'roi_identity_sha256': sha(capture/'identity.json'),
              'script_sha256': sha(Path(__file__)), 'invocation': [sys.executable, *sys.argv],
              'aggregate': aggregate, 'windows': windows, 'three_second_diagnostics': glance,
              'chroma_proxy': {'formula': 'temporal range of sqrt(((r-g)^2+(g-b)^2+(b-r)^2)/2), sRGB normalized',
                               'mean_excursion': float(chroma_range.mean()),
                               'median_excursion': float(np.median(chroma_range)),
                               'maximum_near_clipped_fraction': max(clipped)},
              'boundary': 'Phase-insensitive engineering comparator. Temporal pixel activity alone is not physical perceptibility acceptance.'}
    if args.compare:
        parent = json.loads(args.compare.read_text())
        assert parent['formula_version'] == VERSION and parent['scene'] == result['scene']
        assert parent['threshold_255'] == threshold
        ratios = {name: {key: (value / parent['aggregate'][name][key] if parent['aggregate'][name][key] else None)
                         for key, value in values.items() if key in ['motion_score', 'moving_fraction', 'moving_median_normalized']}
                  for name, values in aggregate.items()}
        result['comparison'] = {'parent_output': str(args.compare.resolve()), 'parent_sha256': sha(args.compare),
                                'candidate_to_parent': ratios,
                                'ocean_score_within_ten_percent': .9 <= ratios['primary']['motion_score'] <= 1.1,
                                'ocean_coverage_within_ten_percent_relative': .9 <= ratios['primary']['moving_fraction'] <= 1.1}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
    print(json.dumps({'scene': result['scene'], 'aggregate': aggregate,
                      'comparison': result.get('comparison'), 'output': str(args.out)}, sort_keys=True))

if __name__ == '__main__':
    main()
