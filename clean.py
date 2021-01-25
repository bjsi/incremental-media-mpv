#!/usr/bin/env python3

import os

media_dir = "media"
data_dir = "data"
data_files = [
        "topics.csv",
        "extracts.csv",
        "items.csv",
]

def rm_files(directory, predicate):
    _, _, files = next(os.walk(directory))
    for f in files:
        if predicate(f):
            to_rm = os.path.join(directory, f)
            print(f"Removing: {to_rm}")
            os.remove(to_rm)


def main():
    rm_files(data_dir, lambda x: x in data_files)
    rm_files(media_dir, lambda x: "sine.opus" not in x)


if __name__ == "__main__":
    print("Are you sure you want to delete data and media files? (y/n) ", end='')
    yes = {'yes','y', 'ye', ''}
    no = {'no','n'}

    choice = input().lower()
    if choice in yes:
        print("Deleting...")
        main()
    elif choice in no:
        print("Exiting...")
    else:
        print("Please respond with 'y(es)' or 'n(o)'")
