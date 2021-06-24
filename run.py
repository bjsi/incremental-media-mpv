#!/usr/bin/env python3

import subprocess
import os
import sys


# TODO: pass in extra args
def main(args):
    default = [
        "mpv",
        "--ytdl-format=bestvideo[height<=?480][fps<=?30][vcodec!=?vp9]+bestaudio/best",
        "--idle=once",
        "--scripts=" + os.getcwd(),
        "--ytdl-raw-options=no-check-certificate=",
        "--input-ipc-server=/tmp/testing-mpv.sock"
        ]
    if args:
        default += args
    subprocess.run(default)


if __name__ == "__main__":
    args = sys.argv[1:]
    try:
        main(args)
    except KeyboardInterrupt:
        try:
            sys.exit(0)
        except SystemExit:
            os._exit(0)

