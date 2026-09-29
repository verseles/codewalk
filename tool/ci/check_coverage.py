"""Evaluate fresh Flutter LCOV with consistent exclusions on local and CI hosts."""

import argparse
from decimal import Decimal, InvalidOperation
import os
from pathlib import Path, PurePosixPath
import tempfile


ROOT = Path(__file__).resolve().parents[2]


def percentage(value):
    try:
        result = Decimal(value)
    except InvalidOperation as error:
        raise ValueError(f"Invalid coverage threshold: {value}") from error
    if not result.is_finite() or not 0 <= result <= 100:
        raise ValueError(f"Coverage threshold must be between 0 and 100: {value}")
    return result


def source_name(value):
    candidate = PurePosixPath(value.replace("\\", "/"))
    if ".." in candidate.parts:
        raise ValueError(f"Traversal is not allowed in LCOV sources: {value}")
    path = candidate.as_posix()
    root = ROOT.as_posix() + "/"
    if path.startswith(root):
        path = path[len(root):]
    if not path.startswith("lib/"):
        raise ValueError(f"LCOV source is outside the project lib directory: {value}")
    return path


def excluded(source):
    return (
        source.startswith("lib/l10n/")
        or (source.startswith("lib/") and source.endswith(".g.dart"))
        or source.rsplit("/", 1)[-1] == "generated_plugin_registrant.dart"
    )


def read_report(path):
    records = {}
    block = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() and not block:
            continue
        block.append(line)
        if line != "end_of_record":
            continue
        sources = [source_name(item[3:]) for item in block if item.startswith("SF:")]
        if len(sources) != 1 or not sources[0]:
            raise ValueError("Each LCOV record must identify exactly one source")
        source = sources[0]
        if source in records:
            raise ValueError(f"Duplicate LCOV source; merge reports first: {source}")
        lines = {}
        totals = {}
        for item in block:
            if item.startswith("DA:"):
                fields = item[3:].split(",")
                if len(fields) < 2:
                    raise ValueError(f"Invalid DA record in {source}")
                number, hits = int(fields[0]), int(fields[1])
                if number <= 0 or hits < 0 or number in lines:
                    raise ValueError(f"Invalid or duplicate line coverage in {source}")
                lines[number] = hits
            elif item.startswith(("LF:", "LH:")):
                key, value = item.split(":", 1)
                if key in totals:
                    raise ValueError(f"Duplicate {key} in {source}")
                totals[key] = int(value)
        total = len(lines)
        covered = sum(hits > 0 for hits in lines.values())
        # Flutter emits both totals. Requiring them detects records missing
        # summary metadata instead of treating a partial DA list as complete.
        if totals.keys() != {"LF", "LH"}:
            raise ValueError(f"Missing LF or LH totals in {source}")
        if any(value < 0 for value in totals.values()):
            raise ValueError(f"Negative LCOV totals in {source}")
        if totals["LF"] != total or totals["LH"] != covered:
            raise ValueError(f"LCOV totals disagree with line records in {source}")
        records[source] = (covered, total, block)
        block = []
    if block:
        raise ValueError("Unterminated LCOV record")
    return {name: value for name, value in records.items() if not excluded(name)}


def read_baseline(path):
    floors = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split()
        if len(fields) != 2:
            raise ValueError(f"Invalid baseline row: {line}")
        source, minimum = fields
        if source in floors or source_name(source) != source or excluded(source):
            raise ValueError(f"Invalid or duplicate protected source: {source}")
        floors[source] = percentage(minimum)
    return floors


def evaluate(raw, minimum, output, baseline):
    if raw.resolve() == output.resolve():
        raise ValueError("Raw input and filtered output must be different files")
    if baseline.resolve() == output.resolve():
        raise ValueError("Coverage policy and filtered output must be different files")
    records = read_report(raw)
    total = sum(value[1] for value in records.values())
    covered = sum(value[0] for value in records.values())
    if not total:
        raise ValueError("No executable lines found after coverage exclusions")
    floors = read_baseline(baseline)
    rate = Decimal(100) * covered / total
    failures = []
    print(f"Coverage: {rate:.2f}% ({covered}/{total}), required >= {minimum}%")
    if rate < minimum:
        failures.append(f"Global coverage is below {minimum}%")
    for source, floor in floors.items():
        entry = records.get(source)
        if entry is None or entry[1] == 0:
            failures.append(f"Protected source missing or has no executable lines: {source}")
            continue
        source_rate = Decimal(100) * entry[0] / entry[1]
        print(f"  {source}: {source_rate:.2f}% (minimum {floor}%)")
        if source_rate < floor:
            failures.append(f"{source}: {source_rate:.2f}% is below {floor}%")

    # Never read an existing filtered artifact. Publish only the validated
    # current input, including on a threshold failure for useful diagnostics.
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=output.parent, delete=False,
            prefix=f".{output.name}.",
        ) as stream:
            temporary = Path(stream.name)
            for _, _, block in records.values():
                stream.write("\n".join(block) + "\n")
        os.replace(temporary, output)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    if failures:
        raise ValueError("Coverage gate failed: " + "; ".join(failures))
    print("Coverage gate passed.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw", type=Path)
    parser.add_argument("minimum", type=percentage)
    parser.add_argument("output", type=Path)
    parser.add_argument("baseline", type=Path)
    args = parser.parse_args()
    try:
        evaluate(args.raw, args.minimum, args.output, args.baseline)
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
