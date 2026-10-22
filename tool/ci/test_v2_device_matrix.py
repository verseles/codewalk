import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tool.ci import validate_device_matrix as matrix


def _committed():
    return json.loads(matrix.DEFAULT.read_text())


def _passing(cell):
    cell.update(
        result="pass",
        build="0123abc",
        started="2026-10-23T10:00:00+00:00",
        ended="2026-10-23T10:02:00+00:00",
        steps="the scenario procedure",
        recovery_seconds=4.2,
        prompt_shown=1,
        duplicates=0,
        stuck_running=False,
        transport_proof="WIFI -> CELLULAR -> WIFI",
        evidence=["device-report.json"],
    )
    return cell


class MatrixTests(unittest.TestCase):
    def test_the_committed_matrix_holds_every_cell_once(self):
        data = _committed()
        self.assertEqual(matrix.problems(data), [])
        self.assertEqual(len(data["cells"]), 20)
        self.assertEqual(len(matrix.problems(data, final=True)), 20)

    def test_a_pass_needs_its_observables_inside_the_bounds(self):
        data = _committed()
        cell = _passing(data["cells"][0])
        self.assertEqual(matrix.problems(data), [])
        for field, value in (
            ("recovery_seconds", 11),
            ("prompt_shown", 2),
            ("duplicates", 1),
            ("stuck_running", True),
            ("evidence", []),
        ):
            with self.subTest(field=field):
                broken = copy.deepcopy(data)
                broken["cells"][0][field] = value
                self.assertNotEqual(matrix.problems(broken), [])
        self.assertEqual(cell["scenario"], "drop")

    def test_a_handover_pass_needs_the_observed_transport_change(self):
        data = _committed()
        cell = next(c for c in data["cells"] if c["scenario"] == "handover")
        _passing(cell)["transport_proof"] = None
        self.assertIn("pass needs the transport change", " ".join(matrix.problems(data)))

    def test_inconclusive_and_fail_need_a_reason(self):
        data = _committed()
        _passing(data["cells"][0]).update(result="inconclusive", reason=None)
        self.assertNotEqual(matrix.problems(data), [])
        data["cells"][0]["reason"] = "no second transport on this target"
        self.assertEqual(matrix.problems(data), [])

    def test_cells_are_unique_and_complete(self):
        data = _committed()
        data["cells"].append(copy.deepcopy(data["cells"][0]))
        self.assertIn("duplicate cell ('s25', 'drop')", matrix.problems(data))
        data = _committed()
        data["cells"].pop()
        self.assertIn("missing cell linux-arm64/tui", matrix.problems(data))

    def test_credentials_addresses_and_the_durable_log_are_refused(self):
        data = _committed()
        data["cells"][0]["reason"] = '"password": "hunter2-secret-value"'
        self.assertNotEqual(matrix.problems(data), [])
        data = _committed()
        data["cells"][0]["steps"] = "paired with 100.64.1.2"
        self.assertIn("an address is recorded: 100.64.1.2", matrix.problems(data))
        data["cells"][0]["steps"] = "paired with 10.0.2.2"
        self.assertEqual(matrix.problems(data), [])
        data["durable_log"]["enabled"] = True
        self.assertNotEqual(matrix.problems(data), [])


if __name__ == "__main__":
    unittest.main()
