# Incremental Media Player

An mpv script that implements an incremental media player (video and audio).

## Requirements

ffmpeg, youtube-dl, mpv

## Installation

`git clone` this repository into the mpv scripts folder for your operating system.

| OS | Location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/scripts/` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/scripts/` |

To launch the incremental media script, run the following command:

`mpv --idle=once --script-opts=im-autostart=yes`
