#!/usr/bin/env python3
import hashlib
import math
import os
import shutil
import struct
import subprocess
import sys
import zlib
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"v0.7.1 theme fixture validation failed: {message}")


def png_dimensions(path: Path) -> tuple[int, int]:
    header = path.read_bytes()[:24]
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        fail(f"{path} is not a PNG")
    return struct.unpack(">II", header[16:24])


def analysis_png(path: Path) -> Path:
    sips = shutil.which("sips")
    cache_value = os.environ.get("LIFEROUTE_FIXTURE_ANALYSIS_DIR")
    if sys.platform != "darwin" or not sips or not cache_value:
        return path
    cache = Path(cache_value)
    cache.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(str(path.resolve()).encode("utf-8")).hexdigest()[:16]
    target = cache / f"{digest}-{path.name}"
    if target.is_file() and target.stat().st_mtime_ns >= path.stat().st_mtime_ns:
        return target
    result = subprocess.run(
        [sips, "-Z", "320", str(path), "--out", str(target)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if result.returncode != 0 or not target.is_file():
        fail(f"sips could not create analysis fixture for {path}: {result.stderr.strip()}")
    return target


def decode_png(path: Path) -> tuple[int, int, bytes]:
    path = analysis_png(path)
    payload = path.read_bytes()
    if payload[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{path} is not a PNG")
    offset = 8
    width = height = bit_depth = color_type = interlace = None
    compressed = bytearray()
    while offset < len(payload):
        length = struct.unpack(">I", payload[offset : offset + 4])[0]
        chunk_type = payload[offset + 4 : offset + 8]
        chunk = payload[offset + 8 : offset + 8 + length]
        offset += length + 12
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
        elif chunk_type == b"IDAT":
            compressed.extend(chunk)
        elif chunk_type == b"IEND":
            break
    if None in (width, height, bit_depth, color_type, interlace):
        fail(f"{path} has no valid IHDR")
    if bit_depth != 8 or interlace != 0 or color_type not in (0, 2, 4, 6):
        fail(f"{path} uses unsupported PNG format (depth={bit_depth}, color={color_type}, interlace={interlace})")
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color_type]
    stride = width * channels
    raw = zlib.decompress(bytes(compressed))
    expected = height * (stride + 1)
    if len(raw) != expected:
        fail(f"{path} decoded to {len(raw)} bytes; expected {expected}")
    prior = bytearray(stride)
    rgb = bytearray(width * height * 3)
    source_offset = 0
    destination_offset = 0
    for _ in range(height):
        filter_type = raw[source_offset]
        source_offset += 1
        scanline = bytearray(raw[source_offset : source_offset + stride])
        source_offset += stride
        for index in range(stride):
            left = scanline[index - channels] if index >= channels else 0
            above = prior[index]
            upper_left = prior[index - channels] if index >= channels else 0
            if filter_type == 1:
                scanline[index] = (scanline[index] + left) & 0xFF
            elif filter_type == 2:
                scanline[index] = (scanline[index] + above) & 0xFF
            elif filter_type == 3:
                scanline[index] = (scanline[index] + ((left + above) // 2)) & 0xFF
            elif filter_type == 4:
                predictor = left + above - upper_left
                pa, pb, pc = abs(predictor - left), abs(predictor - above), abs(predictor - upper_left)
                nearest = left if pa <= pb and pa <= pc else above if pb <= pc else upper_left
                scanline[index] = (scanline[index] + nearest) & 0xFF
            elif filter_type != 0:
                fail(f"{path} uses unknown PNG filter {filter_type}")
        for pixel in range(width):
            source = pixel * channels
            if color_type in (0, 4):
                value = scanline[source]
                rgb[destination_offset : destination_offset + 3] = bytes((value, value, value))
            else:
                rgb[destination_offset : destination_offset + 3] = scanline[source : source + 3]
            destination_offset += 3
        prior = scanline
    return width, height, bytes(rgb)


def difference_metrics(first: tuple[int, int, bytes], second: tuple[int, int, bytes]) -> tuple[float, float]:
    if first[:2] != second[:2]:
        fail(f"fixture dimensions differ: {first[:2]} versus {second[:2]}")
    one, two = first[2], second[2]
    channel_delta = changed_pixels = 0
    for index in range(0, len(one), 3):
        deltas = (abs(one[index] - two[index]), abs(one[index + 1] - two[index + 1]), abs(one[index + 2] - two[index + 2]))
        channel_delta += sum(deltas)
        changed_pixels += max(deltas) >= 2
    return channel_delta / len(one), changed_pixels / (len(one) // 3)


def validate_health(path: Path) -> None:
    original_width, original_height = png_dimensions(path)
    _, _, pixels = decode_png(path)
    if original_width < 700 or original_height < 1400 or original_height <= original_width:
        fail(f"{path} is not a modern portrait iPhone capture ({original_width}x{original_height})")
    luminance_sum = luminance_square_sum = 0.0
    near_black = 0
    pixel_count = len(pixels) // 3
    for index in range(0, len(pixels), 3):
        luminance = pixels[index] * 0.2126 + pixels[index + 1] * 0.7152 + pixels[index + 2] * 0.0722
        luminance_sum += luminance
        luminance_square_sum += luminance * luminance
        near_black += luminance < 4
    mean = luminance_sum / pixel_count
    deviation = math.sqrt(max(0.0, luminance_square_sum / pixel_count - mean * mean))
    black_fraction = near_black / pixel_count
    if not 8.0 <= mean <= 247.0 or deviation < 9.0 or black_fraction > 0.88:
        fail(f"{path} appears blank/flat (mean={mean:.2f}, deviation={deviation:.2f}, near-black={black_fraction:.2%})")
    print(f"health {path.name}: {original_width}x{original_height}, mean={mean:.2f}, deviation={deviation:.2f}, near-black={black_fraction:.2%}")


def validate_coverage(path: Path) -> None:
    width, height, pixels = decode_png(path)
    first_row = int(height * 0.55)
    final_row = int(height * 0.88)
    luminance_sum = luminance_square_sum = 0.0
    near_black = pixel_count = 0
    for row in range(first_row, final_row):
        for column in range(width):
            index = (row * width + column) * 3
            luminance = pixels[index] * 0.2126 + pixels[index + 1] * 0.7152 + pixels[index + 2] * 0.0722
            luminance_sum += luminance
            luminance_square_sum += luminance * luminance
            near_black += luminance < 4
            pixel_count += 1
    mean = luminance_sum / pixel_count
    deviation = math.sqrt(max(0.0, luminance_square_sum / pixel_count - mean * mean))
    black_fraction = near_black / pixel_count
    if mean < 6.0 or deviation < 4.0 or black_fraction > 0.94:
        fail(f"{path} does not fill the app shell (background mean={mean:.2f}, deviation={deviation:.2f}, near-black={black_fraction:.2%})")
    print(f"coverage {path.name}: mean={mean:.2f}, deviation={deviation:.2f}, near-black={black_fraction:.2%}")


def validate_pair(command: str, first_path: Path, second_path: Path) -> None:
    mean_delta, changed_fraction = difference_metrics(decode_png(first_path), decode_png(second_path))
    minimum_delta, minimum_changed = (0.20, 0.01) if command == "validate-motion" else (7.0, 0.28)
    if mean_delta < minimum_delta or changed_fraction < minimum_changed:
        fail(f"{command} {first_path.name} versus {second_path.name}: mean delta {mean_delta:.3f}, changed {changed_fraction:.2%}; minimums are {minimum_delta:.3f} and {minimum_changed:.2%}")
    print(f"{command} {first_path.name} versus {second_path.name}: mean delta={mean_delta:.3f}, changed={changed_fraction:.2%}")


def sampled_signature(decoded: tuple[int, int, bytes]) -> bytes:
    return bytes(decoded[2][index] for index in range(0, len(decoded[2]), 51))


def validate_distinct(paths: list[Path]) -> None:
    if len(paths) < 2:
        fail("validate-distinct requires at least two PNGs")
    decoded = [decode_png(path) for path in paths]
    if len({item[:2] for item in decoded}) != 1:
        fail("catalog fixture dimensions differ")
    signatures = [sampled_signature(item) for item in decoded]
    for first_index in range(len(paths)):
        for second_index in range(first_index + 1, len(paths)):
            first, second = signatures[first_index], signatures[second_index]
            delta = sum(abs(a - b) for a, b in zip(first, second)) / len(first)
            changed = sum(abs(a - b) >= 2 for a, b in zip(first, second)) / len(first)
            if delta < 1.25 or changed < 0.10:
                fail(f"catalog fixtures {paths[first_index].name} and {paths[second_index].name} are effectively identical (sample delta={delta:.3f}, changed={changed:.2%})")
    print(f"validate-distinct: all {len(paths)} fixtures are quantitatively distinct")


def main() -> None:
    if len(sys.argv) < 3:
        fail("usage: compare_v0_7_1_theme_fixtures.py COMMAND PNG [PNG ...]")
    command = sys.argv[1]
    paths = [Path(value) for value in sys.argv[2:]]
    for path in paths:
        if not path.is_file() or path.stat().st_size < 150_000:
            fail(f"fixture is missing or unexpectedly small: {path}")
    if command == "validate-health":
        for path in paths:
            validate_health(path)
    elif command == "validate-coverage":
        for path in paths:
            validate_coverage(path)
    elif command in ("validate-motion", "validate-identity") and len(paths) == 2:
        validate_pair(command, paths[0], paths[1])
    elif command == "validate-distinct":
        validate_distinct(paths)
    else:
        fail(f"invalid command or argument count: {command}")


if __name__ == "__main__":
    main()
