#!/usr/bin/env python3

import io
import unittest

from merge import CSVTestLoader, CSVMerger, Config, CurtimeMergeMode

### Merging curtime

ONE = """id,type,url,start,end,curtime,curtime_updated,priority
1,youtube,9_gkpYORQLU,0,-1,0,1611044988,30"""

TWO = """id,type,url,start,end,curtime,curtime_updated,priority
1,youtube,9_gkpYORQLU,0,-1,30,1611044988,30"""

THREE = """id,type,url,start,end,curtime,curtime_updated,priority
1,youtube,9_gkpYORQLU,0,-1,30,1611044980,30"""

### Merging priority


### Merging added

FOUR = """id,type,url,start,end,curtime,curtime_updated,priority
1,youtube,9_gkpYORQLU,0,-1,30,1611044980,30"""

FIVE = """id,type,url,start,end,curtime,curtime_updated,priority
2,youtube,9_gkpYORQLU,0,-1,30,1611044980,30"""

SIX = """id,type,url,start,end,curtime,curtime_updated,priority
2,local,9_gkpYORQLU,0,-1,30,1611044980,30"""

### Merging integration

def to_rows(s: str):
    return list(map(lambda x: x.split(','), s.split('\n')))


class MergeTests(unittest.TestCase):
    def test_unchanged_merge(self):
        merger = CSVMerger(ONE, ONE, CSVTestLoader(), Config())
        merged = merger.merge()
        expected = to_rows(ONE)
        assert merged == expected

    def test_curtime_changed_progress_merge(self):
        config = Config()
        config.curtime_merge = CurtimeMergeMode.progress
        merger = CSVMerger(ONE, TWO, CSVTestLoader(), config)
        merged = merger.merge()

        expected = to_rows(TWO)

        assert merged == expected

    def test_curtime_changed_progress_merge_correct_update_time(self):
        config = Config()
        config.curtime_merge = CurtimeMergeMode.progress
        merger = CSVMerger(ONE, THREE, CSVTestLoader(), config)
        merged = merger.merge()

        expected = to_rows(THREE)

        assert merged == expected

    def test_curtime_changed_update_time_merge(self):
        config = Config()
        config.curtime_merge = CurtimeMergeMode.update_time
        merger = CSVMerger(ONE, TWO, CSVTestLoader(), config)
        merged = merger.merge()

        expected = to_rows(TWO)

        assert merged == expected

    def test_curtime_changed_update_time_merge_correct_update_time(self):
        config = Config()
        config.curtime_merge = CurtimeMergeMode.update_time
        merger = CSVMerger(ONE, THREE, CSVTestLoader(), config)
        merged = merger.merge()

        expected = to_rows(ONE)

        assert merged == expected


    def test_merge_added_youtube(self):
        config = Config()
        config.added_merge_types = ["youtube"]
        merger = CSVMerger(FOUR, FIVE, CSVTestLoader(), config)
        merged = merger.merge()

        expected = to_rows("\n".join((FOUR, FIVE.split('\n')[1])))

        assert merged == expected

    def test_merge_added_local(self):
        config = Config()
        config.added_merge_types = ["youtube"] # not local
        merger = CSVMerger(FOUR, SIX, CSVTestLoader(), config)
        merged = merger.merge()

        expected = to_rows(FOUR)

        assert merged == expected

if __name__ == "__main__":
    unittest.main()

