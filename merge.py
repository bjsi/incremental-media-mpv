#!/usr/bin/env python3
from csv_diff import load_csv, compare
import sys
import csv
import io
from abc import ABC, abstractmethod
from typing import List, Iterable, Text
import copy
from MediaPlayerCsv import MediaPlayerRow
from enum import Enum


class CSVLoader(ABC):

    @abstractmethod
    def load(self, s: str) -> Iterable[Text]:
        pass

class CSVTestLoader(CSVLoader):

    def load(self, s: str) -> Iterable[Text]:
        return io.StringIO(s)


class CSVFileLoader(CSVLoader):

    def load(self, f: str) -> Iterable[Text]:
        return open(f)

class CurtimeMergeMode(Enum):
    progress = 0
    update_time = 1


class Config:

    curtime_merge: CurtimeMergeMode = CurtimeMergeMode.progress
    priority_merge = False
    added_merge_types = ["youtube"]


def write_csv(data, output_file: str) -> bool:
    try:
        with open(output_file, 'w') as fobj:
            writer = csv.writer(fobj)
            for row in data:
                writer.writerow(row)
        return True
    except Exception:
            return False


class CSVMerger:

    fst: str
    snd: str
    loader: CSVLoader
    config: Config

    def __init__(self, fst: str, snd: str, loader: CSVLoader, config: Config):
        self.fst = fst
        self.snd = snd
        self.loader = loader
        self.config = config

    def diff(self):
        return compare(
                load_csv(self.loader.load(self.fst), key="id"),
                load_csv(self.loader.load(self.snd), key="id")
                )

    def merge(self):
        result = self.diff()
        fst = list(csv.reader(self.loader.load(self.fst)))
        snd = list(csv.reader(self.loader.load(self.snd)))

        header = fst[0]

        output = []
        changed_ids = [r["key"] for r in result["changed"]]
        output += [row for row in fst[1:] if row[0] not in changed_ids]

        if changed := result["changed"]:
            output += self.handle_changed(fst, snd, changed)

        if added := result["added"]:
            output += self.handle_added(added)

        if result["columns_added"] or result["columns_removed"]:
            raise ValueError("Columns misaligned")

        output.sort(key=lambda x: x[0])
        output.insert(0, header)

        return output

    @staticmethod
    def get_row(rows: List[List[str]], predicate) -> List[str]:
        for row in rows:
            if predicate(row):
                return row
        return None

    def handle_changed(self, fst: List[List[str]], snd: List[List[str]], data) -> List[str]:
        output = []
        for changed in data:
            key = changed["key"]

            a = MediaPlayerRow(self.get_row(fst, lambda x: x[0] == key))
            b = MediaPlayerRow(self.get_row(snd, lambda x: x[0] == key))

            merged = MediaPlayerRow(copy.deepcopy(a.row()))

            # Curtime
            if changed["changes"].get("curtime"):
                if self.config.curtime_merge == CurtimeMergeMode.progress:
                    if a.curtime > b.curtime:
                        merged.curtime = a.curtime
                        merged.curtime_updated = a.curtime_updated
                    elif b.curtime > a.curtime:
                        merged.curtime = b.curtime
                        merged.curtime_updated = b.curtime_updated
                    else:
                        # Equal - update curtime updated to latest
                        merged.curtime = a.curtime
                        merged.curtime_updated = a.curtime_updated \
                                if a.curtime_updated > b.curtime_updated \
                                else b.curtime_updated


                elif self.config.curtime_merge == CurtimeMergeMode.update_time:
                    # Pick last updated
                    if a.curtime_updated > b.curtime_updated:
                        merged.curtime = a.curtime
                        merged.curtime_updated = a.curtime_updated
                    elif b.curtime_updated > a.curtime_updated:
                        merged.curtime = b.curtime
                        merged.curtime_updated = b.curtime_updated
                    else:
                        # Equal - update curtime to greatest
                        merged.curtime_updated = a.curtime_updated
                        merged.curtime = a.curtime \
                                if a.curtime > b.curtime \
                                else b.curtime

            # Priority
            if changed["changes"].get("priority"):
                # TODO
                pass

            output.append(merged.row())

        return output


    def handle_added(self, data) -> List[str]:
        # TODO: Option to handle local youtube - downloaded youtube files
        output = []
        for added in data:
            if added.get("type") in self.config.added_merge_types:
                row = [
                        added["id"],
                        added["type"],
                        added["url"],
                        added["start"],
                        added["end"],
                        added["curtime"],
                        added["curtime_updated"],
                        added["priority"],
                    ]
                output.append(row)

        return output




if __name__ == "__main__":
    args = sys.argv
    if (len(args) != 4):
        print(f"{args[0]} requires 3 arguments: input_csv1 input_csv2 output_csv")

    a = args[1]
    b = args[2]
    merger = CSVMerger(a, b, CSVFileLoader(), Config())
    data = merger.merge()
    write_csv(data, args[3])

