import importlib.util
import io
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import filter_pairs as f


def pair(chrom="chr1", start=101, end=300):
    # Two 50-base reads bounding a 200-base fragment at BED [100,300).
    length = end - start + 1
    mate_start = end - 49
    return [["read", "99", chrom, str(start), "40", "50M", "=", str(mate_start), str(length), "A" * 50, "I" * 50],
            ["read", "147", chrom, str(mate_start), "40", "50M", "=", str(start), str(-length), "A" * 50, "I" * 50]]


class PairTests(unittest.TestCase):
    def test_both_mates_and_full_nucleosomal_span(self):
        reason, interval = f.inspect_pair(pair(end=800), f.IntervalIndex())
        self.assertEqual(reason, "retained")
        self.assertEqual(interval, ("chr1", 100, 800))

    def test_bad_second_mate_drops_pair(self):
        records = pair()
        records[1][4] = "10"
        self.assertEqual(f.inspect_pair(records, f.IntervalIndex())[0], "low_mapq")

    def test_duplicate_on_either_mate_drops_pair(self):
        records = pair()
        records[1][1] = str(147 + 1024)
        self.assertEqual(f.inspect_pair(records, f.IntervalIndex())[0], "duplicate")

    def test_blacklist_body_and_half_open_boundary(self):
        self.assertEqual(f.inspect_pair(pair(), f.IntervalIndex([("chr1", 190, 210)]))[0], "blacklist")
        self.assertEqual(f.inspect_pair(pair(), f.IntervalIndex([("chr1", 300, 310)]))[0], "retained")

    def test_mitochondria_and_orphans(self):
        self.assertEqual(f.inspect_pair(pair("chrM"), f.IntervalIndex())[0], "excluded_contig")
        self.assertEqual(f.inspect_pair(pair()[:1], f.IntervalIndex())[0], "not_two_primary_mates")

    def test_output_contains_two_records_one_fragment(self):
        source = io.StringIO("@HD\tVN:1.6\tSO:queryname\n" + "\n".join("\t".join(x) for x in pair()) + "\n")
        dest, fragments = io.StringIO(), io.StringIO()
        qc, histogram = f.filter_stream(source, dest, fragments, f.IntervalIndex())
        self.assertEqual(qc["filtered_pairs"], 1)
        self.assertEqual(len(dest.getvalue().splitlines()), 3)
        self.assertEqual(len(fragments.getvalue().splitlines()), 1)
        self.assertEqual(histogram[200], 1)

    def test_requires_name_sort_and_valid_mate_positions(self):
        source = io.StringIO("@HD\tSO:coordinate\n" + "\t".join(pair()[0]) + "\n")
        with self.assertRaisesRegex(ValueError, "queryname"):
            f.filter_stream(source, io.StringIO(), io.StringIO(), f.IntervalIndex())
        records = pair()
        records[1][7] = "999"
        self.assertEqual(f.inspect_pair(records, f.IntervalIndex())[0], "invalid_mate_position")


if __name__ == "__main__":
    unittest.main()
