# Incremental Media Player

An mpv script that implements an incremental media player (video and audio).

(work in progress)

## Requirements

ffmpeg, youtube-dl, mpv, git, curl

## Installation

To install, you need to install the dependencies listed above and make sure they are available in your path. Next you simply need to use git to clone this project into the mpv scripts folder.

### Main Scripts Folder

1. Go to the mpv scripts folder for your operating system. NOTE: You may need to create the scripts folder.

| OS | Location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/scripts/` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/scripts/` |

2. `git clone` this repository into the mpv scripts folder

### Updating

To update to the latest version, navigate into the incremental-media-mpv folder in the mpv scripts folder for your operating system. Run `git pull` to update to the latest version.

## Running

To launch the incremental media script, run the following command:

`mpv --idle=once --script-opts=im-mode=master`

## Config

| OS | Location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/script-opts/` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/script-opts/` |

To increase the font size of the text dialog input (which is really tiny by default), create a file called user_input.conf in the script-opts folder and set the font_size option to your preferred size. The default is 16.

eg. font_size=24
