from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from filter_pairs import IntervalIndex
from normalize_peaks import normalize


class PeakTests(unittest.TestCase):
    def test_blacklist_exclusion_keeps_native_count(self):
        peaks, counts = normalize([("chr1", 0, 10), ("chr1", 20, 40), ("chrM", 0, 5)],
                                  {"chr1": 100, "chrM": 20}, IntervalIndex([("chr1", 30, 35)]))
        self.assertEqual(peaks, [("chr1", 0, 10)])
        self.assertEqual(counts["native_peaks"], 3)
        self.assertEqual(counts["retained_peaks"], 1)

    def test_out_of_bounds_is_error(self):
        with self.assertRaises(ValueError):
            normalize([("chr1", 99, 101)], {"chr1": 100}, IntervalIndex())

    def test_empty_is_valid_and_overlapping_peaks_not_merged(self):
        peaks, counts = normalize([], {"chr1": 100}, IntervalIndex())
        self.assertEqual(counts["native_peaks"], 0)
        peaks, counts = normalize([("chr1", 0, 10), ("chr1", 5, 20)], {"chr1": 100}, IntervalIndex())
        self.assertEqual(len(peaks), 2)


if __name__ == "__main__":
    unittest.main()
