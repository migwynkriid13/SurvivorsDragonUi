#!/usr/bin/env python3
"""Native-base batching reference model; not addon execution or GPU measurement.

Transcribes crt_qsort_into from crates/benilla-ui/src/script/layer_batch.rs,
read in the local source reconstruction. The public base substitutes texture
creation rank for device addresses. It is not proof of the packaged client's
allocator order, draw calls, pixels or performance. Only GitHub Actions runs it.
"""

from itertools import permutations


PARTS = 14


def crt_qsort(keys):
    """Return the exact index permutation of the source's unstable CRT sort."""
    order = list(range(len(keys)))
    if len(order) < 2:
        return order
    stack = []
    lo, hi = 0, len(order) - 1
    while True:
        size = hi - lo + 1
        if size <= 8:
            while hi > lo:
                maximum = lo
                for position in range(lo + 1, hi + 1):
                    if keys[order[position]] > keys[order[maximum]]:
                        maximum = position
                order[maximum], order[hi] = order[hi], order[maximum]
                hi -= 1
        else:
            middle = lo + size // 2
            order[middle], order[lo] = order[lo], order[middle]
            low_guy, high_guy = lo, hi + 1
            while True:
                low_guy += 1
                while low_guy <= hi and keys[order[low_guy]] <= keys[order[lo]]:
                    low_guy += 1
                high_guy -= 1
                while high_guy > lo and keys[order[high_guy]] >= keys[order[lo]]:
                    high_guy -= 1
                if high_guy < low_guy:
                    break
                order[low_guy], order[high_guy] = order[high_guy], order[low_guy]
            order[lo], order[high_guy] = order[high_guy], order[lo]
            left, right = high_guy - 1 - lo, hi - low_guy
            if left >= right:
                if lo + 1 < high_guy:
                    stack.append((lo, high_guy - 1))
                if low_guy < hi:
                    lo = low_guy
                    continue
            else:
                if low_guy < hi:
                    stack.append((low_guy, hi))
                if lo + 1 < high_guy:
                    hi = high_guy - 1
                    continue
        if not stack:
            break
        lo, hi = stack.pop()
    return order


def canonical_patterns(length, prefix=(0,)):
    """Restricted-growth strings enumerate each equality pattern once."""
    if len(prefix) == length:
        yield prefix
        return
    for value in range(max(prefix) + 2):
        yield from canonical_patterns(length, prefix + (value,))


def inputs(slots):
    old = [(path, part) for path in slots for part in range(PARTS)]
    new = [
        (path, part)
        for path in dict.fromkeys(slots)
        for part in range(PARTS)
        for slot_path in slots
        if slot_path == path
    ]
    return old, new


def runs(quads, ranks):
    keys = [ranks[path] for path, _ in quads]
    if all(first < second for first, second in zip(keys, keys[1:])):
        sorted_quads = quads
    else:
        sorted_quads = [quads[index] for index in crt_qsort(keys)]
    return sum(index == 0 or quad != sorted_quads[index - 1] for index, quad in enumerate(sorted_quads))


def compare(slots, ranks, peers=(), placement="before"):
    old, new = inputs(slots)
    old = list(peers) + old if placement == "before" else old + list(peers)
    new = list(peers) + new if placement == "before" else new + list(peers)
    return runs(old, ranks), runs(new, ranks)


def main():
    print("Native-base CRT qsort material-run model; no addon/client execution or GPU measurement.")
    assert crt_qsort([7, 7]) == [1, 0]
    assert crt_qsort([7, 7, 7]) == [1, 2, 0]
    assert crt_qsort([3] * 9) == [4, 1, 2, 3, 0, 5, 6, 7, 8]
    for count in (2, 5):
        old, new = compare((0,) * count, {0: 0})
        print(f"isolated {count} equal slots: old={old}, new={new}")
        assert old == PARTS * count and new == 16 and new < old

    totals = {"improved": 0, "equal": 0, "worse": 0}
    ranges = {"old": [], "new": [], "delta": []}
    examples = {}
    peer_reports = {}
    cases = 0
    for slots in canonical_patterns(5):
        paths = tuple(dict.fromkeys(slots))
        for rank_values in permutations(range(len(paths))):
            ranks = dict(zip(paths, rank_values))
            old, new = compare(slots, ranks)
            outcome = "improved" if new < old else "worse" if new > old else "equal"
            totals[outcome] += 1
            examples.setdefault(outcome, (slots, rank_values, old, new))
            ranges["old"].append(old)
            ranges["new"].append(new)
            ranges["delta"].append(new - old)
            cases += 1
            if len(paths) == 5:
                assert inputs(slots)[0] == inputs(slots)[1] and old == new
            for peer_kind in ("unique paths", "duplicate first jewelry path"):
                peer_ranks = dict(ranks)
                if peer_kind == "unique paths":
                    peers = [(len(paths) + index, PARTS) for index in range(7)]
                    peer_ranks.update({path: path for path, _ in peers})
                else:
                    peers = [(paths[0], PARTS)] * 7
                for placement in ("before", "after"):
                    before, after = compare(slots, peer_ranks, peers, placement)
                    key = (peer_kind, placement)
                    report = peer_reports.setdefault(key, {"improved": 0, "equal": 0, "worse": 0, "delta": []})
                    result = "improved" if after < before else "worse" if after > before else "equal"
                    report[result] += 1
                    report["delta"].append(after - before)
    print(f"five populated slots: {cases} equality-pattern/rank-permutation cases; {totals}")
    for name, values in ranges.items():
        print(f"isolated {name} min={min(values)}, max={max(values)}")
    for outcome, case in examples.items():
        print(f"isolated {outcome} example (slots, ranks, old, new): {case}")
    for (kind, placement), report in peer_reports.items():
        delta = report.pop("delta")
        print(f"seven foreign peers {placement}, {kind}: {report}; delta min={min(delta)}, max={max(delta)}")
    print("Peer cases bound only these fixed full-image UV peers and rank assignments.")
    print("Mixed textures, other artwork and native allocation orders can change sorting; no universal improvement claim.")


if __name__ == "__main__":
    main()
