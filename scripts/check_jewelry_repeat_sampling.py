#!/usr/bin/env python3
"""Non-runtime sampling reference; not addon execution or GPU/pixel proof.

The current jewelry icon has fourteen rectangular strips. Each uses the native
half-texel-inset UV clamp. The candidate subdivides every strip into nine cells,
samples a losslessly 180-degree-flipped alias with negative UVs and REPEAT, and
therefore needs no per-strip clamp material. Reflecting both axes is exact in
real arithmetic away from the source texture's outer seam.

Source model: modules/ui/jewelry.lua; public-base ui_script/extract/mod.rs's
uv_clamp_window; ui_pass.rs's rectangular quad; ui_quad.wgsl's clamp-before-
sample. The public base is not proof of the packaged client's GPU behavior.

This script separately reports an exact Fraction identity and two explicitly
specified float32 interpolation models. Real GPU interpolation, subpixel edge
rules, texture addressing/filter weights, sRGB arithmetic, compression decoding,
blend order and arbitrary overlaps are NOT simulated. A passing tolerance is not
visual acceptance; a nonzero discrepancy is not a measured visible difference.
No images, addon code, native client or graphics APIs are loaded or executed.
"""

from fractions import Fraction
from itertools import product
import math
import struct


ICON_SIZE = 32
SOURCE_SIZE = 64
ICON_SPAN = 1 / 1.05
ICON_INSET = (1 - ICON_SPAN) / 2
HALF_TEXEL = 0.5 / SOURCE_SIZE
SCALES = sorted(set([n / 10 for n in range(4, 31)] + [0.65, 0.85, 1.05, 1.25, 1.75]))
PHASES = (0.0, 0.125, 0.5, 0.875)
ORIGIN_BASES = (0.0, 1024.0)
TOLERANCES = (0.0, 2 ** -24, 1e-7, 1e-6)


def f32(value):
    """Round one operation to binary32; struct has no graphics dependency."""
    return struct.unpack("<f", struct.pack("<f", value))[0]


def bits(value):
    return struct.unpack("<I", struct.pack("<f", value))[0]


def lerp32(first, last, point, left, right, style):
    """Two possible CPU references, neither asserted to be GPU interpolation."""
    amount = f32(f32(point - left) / f32(right - left))
    if style == "difference":
        return f32(first + f32(f32(last - first) * amount))
    if style == "weighted":
        return f32(f32(f32(1 - amount) * first) + f32(amount * last))
    raise ValueError(style)


def strips():
    result = []
    for band in range(1, 17):
        top, bottom = (band - 1) * 2, band * 2
        edge = max(abs(top - 16), abs(bottom - 16))
        half = math.sqrt(max(0, 256 - edge * edge))
        if half <= 0:
            continue
        left, width = 16 - half, half * 2
        result.append({
            "band": band,
            "x": (left, width, ICON_INSET + left * ICON_SPAN / ICON_SIZE,
                  ICON_INSET + (16 + half) * ICON_SPAN / ICON_SIZE),
            "y": (top, 2.0, ICON_INSET + top * ICON_SPAN / ICON_SIZE,
                  ICON_INSET + bottom * ICON_SPAN / ICON_SIZE),
        })
    return result


def uploaded_axis(axis):
    first, last = f32(axis[2]), f32(axis[3])
    low, high = f32(first + HALF_TEXEL), f32(last - HALF_TEXEL)
    return first, last, low, high


def rational_identity(parts):
    """Use uploaded binary32 constants exactly, without subsequent rounding.

    Every clamp cell is affine or constant on each axis. Matching its endpoints
    proves equality throughout that cell; the extra interior points make the
    printed evidence easy to inspect. Positive scale and translation cancel from
    the interpolation parameter, so this identity holds for every such layout.
    """
    comparisons = 0
    maximum = Fraction(0)
    for part in parts:
        axes = []
        for key in ("x", "y"):
            first, last, low, high = map(Fraction, uploaded_axis(part[key]))
            cuts = (Fraction(0), (low - first) / (last - first),
                    (high - first) / (last - first), Fraction(1))
            values = (low, low, high, high)
            axes.append((first, last, low, high, cuts, values))
        for x_cell, y_cell in product(range(3), repeat=2):
            for x_fraction, y_fraction in product((Fraction(0), Fraction(1, 3), Fraction(1)), repeat=2):
                for cell, fraction, axis in ((x_cell, x_fraction, axes[0]),
                                              (y_cell, y_fraction, axes[1])):
                    first, last, low, high, cuts, values = axis
                    position = cuts[cell] + fraction * (cuts[cell + 1] - cuts[cell])
                    original = min(high, max(low, first + (last - first) * position))
                    negative = -(values[cell] + (values[cell + 1] - values[cell]) * fraction)
                    # REPEAT(-u) on a reflected image corresponds to the original u.
                    restored = -negative
                    maximum = max(maximum, abs(original - restored))
                    comparisons += 1
    if maximum != 0:
        raise AssertionError("Exact rational subdivision identity failed")
    return comparisons, maximum


def axis_geometry(axis, scale, origin, policy):
    start, size, source_first, source_last = axis
    first, last, low, high = uploaded_axis(axis)
    left, right = f32(origin + start * scale), f32(origin + (start + size) * scale)
    if policy == "uploaded-boundaries":
        # Best-case cuts derived from the actual uploaded UVs and clamp uniform.
        # This does not assert that Lua can read the renderer's rounded constants.
        cuts = (left,
                f32(left + (right - left) * (low - first) / (last - first)),
                f32(left + (right - left) * (high - first) / (last - first)),
                right)
    elif policy == "source-boundaries":
        # Natural authoring formula before the renderer rounds geometry/UVs.
        inset = size * HALF_TEXEL / (source_last - source_first)
        cuts = (left, f32(origin + (start + inset) * scale),
                f32(origin + (start + size - inset) * scale), right)
    else:
        raise ValueError(policy)
    return first, last, low, high, cuts


def sample_axis(axis, scale, origin, policy, style):
    first, last, low, high, cuts = axis_geometry(axis, scale, origin, policy)
    left, right = cuts[0], cuts[-1]
    values = (low, low, high, high)
    result = []
    for pixel in range(math.ceil(left - 0.5), math.ceil(right - 0.5)):
        point = pixel + 0.5
        original = min(high, max(low, lerp32(first, last, point, left, right, style)))
        cell = next((index for index in range(3)
                     if cuts[index] <= point < cuts[index + 1]), None)
        if cell is None:
            raise AssertionError("Subdivision left a hole at a sampled pixel center")
        negative = lerp32(f32(-values[cell]), f32(-values[cell + 1]),
                          point, cuts[cell], cuts[cell + 1], style)
        restored = f32(-negative)
        result.append((point, original, restored, abs(original - restored),
                       abs(bits(original) - bits(restored))))
    return result


def describe_sample(context, x_sample, y_sample):
    return {
        **context,
        "pixel_center": [x_sample[0], y_sample[0]],
        "original_uv": [x_sample[1], y_sample[1]],
        "candidate_uv": [x_sample[2], y_sample[2]],
        "delta_uv": [x_sample[3], y_sample[3]],
        "delta_source_texels": [x_sample[3] * SOURCE_SIZE, y_sample[3] * SOURCE_SIZE],
        "delta_ulps": [x_sample[4], y_sample[4]],
    }


def float32_report(parts, policy, style):
    samples = 0
    cases = 0
    exceeded = {tolerance: 0 for tolerance in TOLERANCES}
    first_difference = None
    maximum = -1.0
    maximum_sample = None
    maximum_ulps = 0
    for scale, base, phase_x, phase_y, part in product(
            SCALES, ORIGIN_BASES, PHASES, PHASES, parts):
        origin_x, origin_y = base + phase_x, base + phase_y
        xs = sample_axis(part["x"], scale, origin_x, policy, style)
        ys = sample_axis(part["y"], scale, origin_y, policy, style)
        if not xs or not ys:
            continue
        cases += 1
        samples += len(xs) * len(ys)
        context = {"band": part["band"], "scale": scale,
                   "origin": [origin_x, origin_y], "policy": policy, "interpolation": style}
        for tolerance in TOLERANCES:
            equal_x = sum(sample[3] <= tolerance for sample in xs)
            equal_y = sum(sample[3] <= tolerance for sample in ys)
            exceeded[tolerance] += len(xs) * len(ys) - equal_x * equal_y
        x_max = max(xs, key=lambda sample: sample[3])
        y_max = max(ys, key=lambda sample: sample[3])
        error = max(x_max[3], y_max[3])
        if error > maximum:
            maximum = error
            maximum_sample = describe_sample(context, x_max, y_max)
        maximum_ulps = max(maximum_ulps, max(sample[4] for sample in xs + ys))
        if first_difference is None:
            x_bad = next((sample for sample in xs if sample[3] != 0), None)
            y_bad = next((sample for sample in ys if sample[3] != 0), None)
            if x_bad is not None or y_bad is not None:
                first_difference = describe_sample(context, x_bad or xs[0], y_bad or ys[0])
    print(f"\nfloat32 model: {policy}; interpolation={style}")
    print(f"  populated strip/layout cases={cases}; physical pixel-center samples={samples}")
    print(f"  maximum UV delta={maximum:.12g}; source-texel delta={maximum * SOURCE_SIZE:.12g}; maximum ULP distance={maximum_ulps}")
    for tolerance, count in exceeded.items():
        print(f"  samples exceeding UV tolerance {tolerance:.12g}: {count}/{samples}")
    print(f"  first finite-precision discrepancy: {first_difference}")
    print(f"  maximum-delta sample: {maximum_sample}")


def main():
    parts = strips()
    if len(parts) != 14:
        raise AssertionError("Source model no longer has fourteen nonempty strips")
    print("Jewelry repeat/subdivision CPU reference; NOT GPU measurement or pixel parity")
    print(f"Scales={SCALES}; physical phases={PHASES} on both axes; origin bases={ORIGIN_BASES}")
    print("Tolerance counts describe UV arithmetic only and are not pass/fail visual thresholds.")
    comparisons, maximum = rational_identity(parts)
    print(f"Exact rational clamp/subdivision identity: {comparisons} axis comparisons; maximum delta={maximum}")
    print("Positive affine scale/translation cancel from this identity; finite geometry/interpolation need separate evidence.")
    print("The negative/reflected address identity assumes lossless alias texels and no outer-image seam footprint.")
    print("\nFive different icons, isolated contiguous native texture groups:")
    print("  current: 70 regions; 70 clamp-material runs; 280 vertices; 140 triangles")
    print("  nine-cell candidate: 630 regions; 5 possible runs; 2520 vertices; 1260 triangles")
    print("  delta: +560 regions; -65 possible runs; +2240 vertices; +1120 triangles")
    print("  V-only three-cell/seven-width-alias alternative: 210 regions; 35 possible runs; 840 vertices; 420 triangles")
    print("Run counts assume distinct handles per needed material group and no interleaved foreign peers.")
    print("Texture-handle changes, ordering, source decoders, GPU edge coverage and total frame cost remain outside this model.")
    for policy, style in product(("source-boundaries", "uploaded-boundaries"),
                                 ("difference", "weighted")):
        float32_report(parts, policy, style)


if __name__ == "__main__":
    main()
