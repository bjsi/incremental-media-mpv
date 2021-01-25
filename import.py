#!/usr/bin/env python3

import os
import sys
import subprocess
import json
import csv
import shutil
import hashlib


URL_PREFIX = "https://youtube.com/watch?v="
data_dir = "data"
TOPICS_CSV = os.path.join(data_dir, "topics.csv")
TOPICS_HEADER_CSV = os.path.join(data_dir, "topics_header.csv")


def validate(idOrUrl):
    try:
        proc = subprocess.run([
            "youtube-dl",
            "--no-playlist",
            "-j",
            "--playlist-items", "0",
            idOrUrl
            ], capture_output=True)

        err = proc.stderr
        if err:
            raise Exception("Failed to validate youtube id or url: " + str(err))
        j = proc.stdout
        data = json.loads(j)
        return data["id"]

    except Exception as e:
        print("Failed to validate youtube id or url")
        raise e

def check_duplicate(id):
    if not os.path.exists(TOPICS_CSV): return False
    with open(TOPICS_CSV) as fobj:
        lines = fobj.readlines()[1:]
        if any(line.split(',')[0] == id for line in lines):
            return True
    return False

def import_video(ytId, priority):
    encoded = str.encode(ytId)
    hashobj = hashlib.sha1(encoded)
    id = hashobj.hexdigest()
    if check_duplicate(id):
        print("Failed to import because the video has already been imported.")
        return

    typ = "youtube"
    url = URL_PREFIX + ytId
    start = "0"
    end = "-1"
    curtime = "0"
    curtime_updated = "0"
    priority = "30"
    speed = "1"

    if not os.path.exists(TOPICS_CSV):
        shutil.copy(TOPICS_HEADER_CSV, TOPICS_CSV)

    with open(TOPICS_CSV, "a+") as fobj:
        fobj.write(",".join((id, typ, url, start, end, curtime, curtime_updated, priority, speed)) + "\n")


if __name__ == "__main__":
    args = sys.argv
    if len(args) != 3:
        print(f"{args[0]} takes two args: idOrUrl priority")

    id = validate(args[1])
    priority = float(args[2])
    if 100 < priority < 0:
        raise Exception("Priority must be between 0 and 100")

    import_video(id, priority)
