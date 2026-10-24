import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tool.ci import validate_platform_evidence as evidence


def _committed():
    return json.loads(evidence.DEFAULT.read_text())


def _passing(cell, gate=False):
    cell.update(result="pass", revision="0123abcd", producer="release.yml dry run",
                evidence=["launch.json"])
    if gate:
        cell["command"] = "make v2-architecture"
    else:
        cell.update(sha256="ab" * 32, signer_sha256="cd" * 32, device="ubuntu-24.04-arm runner")
    return cell


def _write(folder, matrix, files=None):
    (folder / "matrix.json").write_text(json.dumps(matrix))
    for name, text in (files or {}).items():
        (folder / name).write_text(text)
    lines = [f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}"
             for path in sorted(folder.iterdir()) if path.name != "SHA256SUMS"]
    (folder / "SHA256SUMS").write_text("\n".join(lines) + "\n")
    return folder / "matrix.json"


def _all_passing():
    data = _committed()
    for cell in data["cells"]:
        _passing(cell)
    for gate in data["gates"].values():
        _passing(gate, gate=True)
    return data


class PlatformEvidenceTests(unittest.TestCase):
    def test_the_committed_matrix_holds_every_cell_once(self):
        data = _committed()
        self.assertEqual(evidence.problems(data), [])
        self.assertEqual(len(data["cells"]), 16)

    def test_a_fully_observed_matrix_is_final(self):
        self.assertEqual(evidence.problems(_all_passing(), final=True), [])

    def test_pending_cells_block_the_final_matrix(self):
        found = evidence.problems(_committed(), final=True)
        self.assertIn("android-s25/functional: still pending", found)
        self.assertIn("G3: still pending", found)

    def test_a_pass_needs_revision_producer_and_evidence(self):
        data = _all_passing()
        cell = data["cells"][0]
        for key, message in (("revision", "no revision"), ("producer", "without its producer"),
                             ("evidence", "without evidence")):
            broken = copy.deepcopy(data)
            del broken["cells"][0][key]
            with self.subTest(key=key):
                self.assertTrue(any(message in line for line in evidence.problems(broken)))
        gate = copy.deepcopy(data)
        del gate["gates"]["G4"]["command"]
        self.assertIn("G4: pass without the command that ran", evidence.problems(gate))
        self.assertEqual(cell["result"], "pass")

    def test_a_missing_resource_names_it_and_the_next_action(self):
        data = _all_passing()
        data["cells"][3].update(result="pending-resource", resource="the owner's Galaxy S25")
        self.assertTrue(any("next action" in line for line in evidence.problems(data)))
        data["cells"][3]["next_action"] = "owner runs the runbook"
        self.assertEqual(evidence.problems(data, final=True), [])

    def test_each_dimension_records_its_own_fact(self):
        for dimension, key, message in (("package", "sha256", "artifact sha256"),
                                        ("signature", "signer_sha256", "explicit unsigned record"),
                                        ("install", "device", "device or runner"),
                                        ("functional", "device", "device or runner")):
            data = _all_passing()
            cell = next(c for c in data["cells"] if c["dimension"] == dimension)
            del cell[key]
            with self.subTest(dimension=dimension):
                self.assertTrue(any(message in line for line in evidence.problems(data)))
        data = _all_passing()
        cell = next(c for c in data["cells"] if c["dimension"] == "signature")
        del cell["signer_sha256"]
        cell["unsigned"] = True
        self.assertEqual(evidence.problems(data), [])

    def test_an_approved_tier_links_its_decision(self):
        data = _all_passing()
        data["cells"][0].update(result="approved-tier")
        self.assertIn("android-s25/package: approved-tier without the recorded decision", evidence.problems(data))
        data["cells"][0]["decision"] = "v2-plan.md §17 row"
        self.assertEqual(evidence.problems(data, final=True), [])

    def test_fail_and_inconclusive_need_a_reason(self):
        for result in ("fail", "inconclusive"):
            data = _all_passing()
            data["cells"][0].update(result=result)
            with self.subTest(result=result):
                self.assertIn(f"android-s25/package: {result} without a reason", evidence.problems(data))

    def test_every_cell_appears_exactly_once(self):
        data = _committed()
        data["cells"].append(copy.deepcopy(data["cells"][0]))
        self.assertTrue(any(line.startswith("duplicate cell") for line in evidence.problems(data)))
        data = _committed()
        data["cells"].pop()
        self.assertIn("missing cell linux-arm64/functional", evidence.problems(data))
        data = _committed()
        data["cells"][0]["target"] = "linux-riscv"
        self.assertTrue(any(line.startswith("unknown cell") for line in evidence.problems(data)))

    def test_deferred_platforms_never_pass(self):
        data = _committed()
        data["deferred"]["web"]["result"] = "pass"
        self.assertIn("deferred web: must stay deferred-post-mvp, never pass", evidence.problems(data))
        data = _committed()
        del data["deferred"]["ios"]
        self.assertTrue(any(line.startswith("deferred must be exactly") for line in evidence.problems(data)))

    def test_gates_are_exactly_g3_g4_and_the_provisional_g5(self):
        data = _committed()
        data["gates"]["G5"] = data["gates"].pop("G5-provisional")
        self.assertTrue(any(line.startswith("gates must be exactly") for line in evidence.problems(data)))

    def test_credentials_and_addresses_are_never_recorded(self):
        data = _committed()
        data["cells"][0]["note"] = "Authorization: Bearer abcdefghijklmnopqrstuvwxyz123456"
        self.assertIn("a credential-shaped value is recorded", evidence.problems(data))
        data = _committed()
        data["cells"][0]["note"] = "paired with 192.168.1.20"
        self.assertIn("an address is recorded: 192.168.1.20", evidence.problems(data))

    def test_the_committed_folder_is_pinned(self):
        self.assertEqual(evidence.folder_problems(evidence.DEFAULT.parent, _committed()), [])

    def test_the_cli_checks_the_digests_beside_the_matrix(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            path = _write(folder, _all_passing(), {"launch.json": "{}\n"})
            self.assertEqual(evidence.main(["--final", str(path)]), 0)
            (folder / "launch.json").write_text('{"changed": true}\n')
            self.assertEqual(evidence.main([str(path)]), 1)
            (folder / "SHA256SUMS").unlink()
            self.assertIn("SHA256SUMS is missing", evidence.folder_problems(folder, _all_passing()))

    def test_every_file_is_pinned_and_every_cited_file_exists(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            _write(folder, _all_passing())
            self.assertIn("cited evidence launch.json is not beside the matrix",
                          evidence.folder_problems(folder, _all_passing()))
            (folder / "extra.json").write_text("{}\n")
            self.assertIn("extra.json is not pinned in SHA256SUMS", evidence.folder_problems(folder, _committed()))
            data = _all_passing()
            for cell in data["cells"]:
                cell["evidence"] = ["https://github.com/verseles/codewalk/actions/runs/1"]
            for gate in data["gates"].values():
                gate["evidence"] = ["https://github.com/verseles/codewalk/actions/runs/1"]
            _write(folder, data)
            self.assertEqual(evidence.folder_problems(folder, data), [])

    def test_evidence_files_carry_no_credentials_or_addresses(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            _write(folder, _all_passing(), {"launch.json": '{"log": "Authorization: Bearer abcdefghijklmnopqrstuvwxyz123456"}\n'})
            self.assertIn("launch.json: a credential-shaped value is recorded",
                          evidence.folder_problems(folder, _all_passing()))
            _write(folder, _all_passing(), {"launch.json": '{"peer": "100.64.1.2"}\n'})
            self.assertIn("launch.json: an address is recorded: 100.64.1.2",
                          evidence.folder_problems(folder, _all_passing()))


if __name__ == "__main__":
    unittest.main()
