#!/usr/bin/env python3

from csv_diff import load_csv, compare
import sys
import csv
from typing import List, Dict
import copy
import os


def write_csv(data, output_file: str) -> bool:
    try:
        with open(output_file, 'w') as fobj:
            writer = csv.writer(fobj)
            for row in data:
                writer.writerow(row)
        return True
    except Exception:
        return False

# TODO: Handle only header, no header etc
# TODO: Need multiple outputs -
# the csv for the central repo wants all new cols
# the csv for individual clients doesn't want all cols

class CSVMerger:

    local: Dict
    git: Dict

    def __init__(self, local: str, git: str):
        self.local = load_csv(open(local), key="id")
        self.git = load_csv(open(git), key="id")

    def diff(self):
        return compare(self.local, self.git)

    def merge(self) -> List[List[str]]:
        print("Merging CSV files:\n---")
        diff = self.diff()

        header: List[str] = []
        body: List[Dict[str, str]] = []

        # Create merged header
        print("Merging headers:\n---")
        header = self.handle_columns(diff["columns_added"])

        # Add unchanged rows
        print("Adding unchanged rows:\n---")
        body += self.handle_unchanged(diff["changed"])

        # Rows where attribute(s) changed
        print("Merging changed rows:\n---")
        body += self.handle_changed(diff["changed"])

        # Rows which were added
        print("Adding added rows:\n---")
        body += self.handle_added(diff["added"], header)

        output = [header]
        for row in body:
            output.append([row.get(col, "null") for col in header])

        print("Output:\n--")
        print(output)

        return output

    def handle_columns(self, added: List[str]) -> List[str]:
        prev_header = list(list(self.local.values())[0].keys())
        print("previous:")
        print(prev_header)
        print("added:")
        print(added)
        prev_header += [col for col in added if col not in prev_header]
        print("merged:")
        print(prev_header)
        return prev_header

    def handle_unchanged(self, changed) -> List[Dict[str, str]]:
        ids_of_changed = [r["key"] for r in changed]
        print("changed keys:")
        print(ids_of_changed)
        prev_rows = list(self.local.values())
        unchanged = [row for row in prev_rows if row["id"] not in ids_of_changed]
        print("unchanged rows:")
        print(unchanged)
        return unchanged


    def handle_changed(self, data) -> List[Dict[str, str]]:
        output = []
        for changed in data:

            prev_row: Dict[str, str] = self.local[changed["key"]]
            cur_row: Dict[str, str] = self.git[changed["key"]]
            merged_row: Dict[str, str] = copy.deepcopy(prev_row)

            # Curtime
            if changed["changes"].get("curtime"):
                if prev_row["curtime"] > cur_row["curtime"]:
                    merged_row["curtime"] = prev_row["curtime"]
                elif cur_row["curtime"] > prev_row["curtime"]:
                    merged_row["curtime"] = cur_row["curtime"]
                else:
                    # Equal - update curtime updated to latest
                    merged_row["curtime"] = prev_row["curtime"]

            output.append(merged_row)

        return output


    def handle_added(self, data, header) -> List[Dict[str, str]]:
        output = []
        print("Adding YouTube type rows.")
        for added in data:
            if added.get("type") in ["youtube"]:
                row = [added.get(key, "") for key in header]
                output.append(row)
        return output


if __name__ == "__main__":
    args = sys.argv
    if (len(args) != 4):
        print(f"{args[0]} requires 3 arguments: input_csv1 input_csv2 output_csv")
        sys.exit(1)

    a = args[1]
    b = args[2]
    if not os.path.exists(a) or not os.path.exists(b):
        print("One or both of the CSV files does not exist.")
        sys.exit(1)
    merger = CSVMerger(a, b)
    data = merger.merge()
    write_csv(data, args[3])

