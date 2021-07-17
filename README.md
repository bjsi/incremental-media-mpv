# Incremental Media Player

An mpv script that implements an incremental media player (video and audio).

(work in progress)

## Requirements

ffmpeg, youtube-dl, mpv, git

## Installation

The installation process involves using git to clone this project into the mpv scripts folder, and also downloading a couple of script modules that the script depends on for the UI.

### Main Scripts Folder

1. Go to the mpv scripts folder for your operating system. NOTE: You may need to create the scripts folder.

| OS | Location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/scripts/` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/scripts/` |

2. `git clone` this repository into the mpv scripts folder
3. Copy the text from [this file](https://raw.githubusercontent.com/CogentRedTester/mpv-user-input/master/user-input.lua) into a new file called user-input.lua in the scripts folder.

### Script Modules Folder

1. Go to the mpv script-modules folder for your operating system. NOTE: You may need to create the script-modules folder.

| OS | Location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/script-modules/` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/script-modules/` |

2. Save the text from [this file](https://raw.githubusercontent.com/CogentRedTester/mpv-scroll-list/master/scroll-list.lua) into a new file called scroll-list.lua inside the script-modules folder.
3. Save the text from [this file](https://raw.githubusercontent.com/CogentRedTester/mpv-user-input/master/user-input-module.lua) into a new file called user-input-module.lua in the script-modules folder.

### Updating

To update to the latest version, navigate into the incremental-media-mpv folder in the mpv scripts folder for your operating system. Run `git pull` to update to the latest version.

## Running

To launch the incremental media script, run the following command:

`mpv --idle=once --script-opts=im-start=yes`

## Config

| OS | Location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/script-opts/` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/script-opts/` |

To increase the font size of the text dialog input (which is really tiny by default), create a file called user-input.conf in the script-opts folder and set the font_size option to your preferred size. The default is 16.

eg. font_size=24
