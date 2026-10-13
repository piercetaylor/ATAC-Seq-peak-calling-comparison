"""Small independently calculable interval and completion-contract tests."""
import csv
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("summarize", Path(__file__).resolve().parents[1] / "scripts/summarize.py")
m = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)


class MetricsTests(unittest.TestCase):
    def test_union_avoids_double_counting(self):
        a = {"chr1": [(0, 10), (5, 15), (20, 30)]}
        b = {"chr1": [(10, 25)]}
        result = m.compare_intervals(a, b)
        self.assertEqual(result["intersection_bp"], 10)
        self.assertEqual(result["union_bp"], 30)
        self.assertAlmostEqual(result["jaccard"], 1 / 3)
        self.assertAlmostEqual(result["fraction_a_overlapping_b"], 2 / 3)

    def test_half_open_boundaries_and_chromosomes(self):
        index = m.interval_index({"chr1": [(10, 20)]})
        self.assertFalse(m.overlaps(index, "chr1", 0, 10))
        self.assertFalse(m.overlaps(index, "chr1", 20, 30))
        self.assertFalse(m.overlaps(index, "chr2", 10, 20))
        self.assertTrue(m.overlaps(index, "chr1", 19, 21))

    def test_empty_sets_are_undefined_not_perfect(self):
        result = m.compare_intervals({}, {})
        self.assertEqual(result["union_bp"], 0)
        self.assertIsNone(result["jaccard"])
        self.assertEqual(m.compare_intervals({}, {"chr1": [(0, 10)]})["jaccard"], 0)

    def test_fragment_counted_once(self):
        with tempfile.TemporaryDirectory() as folder:
            bed = Path(folder) / "fragments.bed"
            bed.write_text("chr1\t0\t50\ta\nchr1\t100\t150\tb\n")
            count, hits, lengths = m.fragment_metrics(bed, {"a": {"chr1": [(1, 10), (20, 30)]}})
            self.assertEqual(count, 2)
            self.assertEqual(hits["a"], 1)
            self.assertEqual(lengths[50], 2)

    def test_invalid_coordinates_fail(self):
        with tempfile.TemporaryDirectory() as folder:
            bed = Path(folder) / "bad.bed"
            bed.write_text("chr1\t-1\t20\n")
            with self.assertRaises(ValueError):
                m.load_intervals(bed)

    def fixture(self, root):
        (root / "config").mkdir()
        (root / "config/project.json").write_text(json.dumps({"dataset": "TEST ONLY", "assembly": "test"}))
        (root / "config/samples.tsv").write_text("sample\nrepA\n")
        pre = root / "results/preprocessing/repA"
        pre.mkdir(parents=True)
        (pre / ".complete").touch()
        (pre / "fragments.bed").write_text("chr1\t0\t50\ta\nchr1\t100\t150\tb\n")
        (pre / "qc.json").write_text(json.dumps({"raw_pairs": 3, "filtered_pairs": 2}))
        for caller in m.CALLERS:
            path = root / "results/peaks/repA" / caller
            path.mkdir(parents=True)
            (path / ".complete").touch()
            (path / "peaks.bed").write_text("chr1\t1\t10\nchr1\t20\t30\n")
            (path / "runtime.tsv").write_text("elapsed_seconds\tmax_rss_kb\texit_status\n1.2\t100\t0\n")

    def test_full_bundle_marks_fixture_and_computes_real_metrics(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.fixture(root)
            output = m.summarize(root, root / "results", "synthetic_fixture")
            rows = m.read_tsv(output / "peak_metrics.tsv")
            self.assertEqual(len(rows), 3)
            self.assertEqual(float(rows[0]["frip"]), .5)
            self.assertEqual(int(rows[0]["total_peak_bp"]), 19)
            status = json.loads((output / "status.json").read_text())
            self.assertEqual(status["mode"], "synthetic_fixture")
            self.assertEqual(status["status"], "complete")

    def test_missing_peak_file_fails_instead_of_zero(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.fixture(root)
            (root / "results/peaks/repA/genrich/peaks.bed").unlink()
            with self.assertRaises(FileNotFoundError):
                m.summarize(root, root / "results", "synthetic_fixture")
            status = json.loads((root / "results/dashboard/status.json").read_text())
            self.assertEqual(status["status"], "failed")

    def test_inconsistent_denominator_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.fixture(root)
            (root / "results/preprocessing/repA/qc.json").write_text('{"filtered_pairs": 99}')
            with self.assertRaisesRegex(ValueError, "denominator mismatch"):
                m.summarize(root, root / "results", "synthetic_fixture")

    def test_partial_caller_cannot_be_reported_complete(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.fixture(root)
            (root / "results/peaks/repA/genrich/.complete").unlink()
            with self.assertRaisesRegex(ValueError, "not marked successfully complete"):
                m.summarize(root, root / "results", "synthetic_fixture")


if __name__ == "__main__":
    unittest.main()
