# Incremental Media Player

An mpv script that implements an incremental media player (video and audio).

(work in progress)

## Requirements

### ffmpeg

Make sure to install the full version of ffmpeg which includes ffprobe. [Make sure to add the bin folder to your path](https://gist.github.com/nex3/c395b2f8fd4b02068be37c961301caa7).

### [youtube-dl](https://github.com/ytdl-org/youtube-dl#installation)

[Make sure to add the youtube-dl executable to your path](https://gist.github.com/nex3/c395b2f8fd4b02068be37c961301caa7).

### [mpv](https://mpv.io/installation/)

Mpv is an open-source media player with support for scripts (such as this one). Mpv will be used to control the playback of video and audio content.

**Note that the minimum version required to run this script is version 0.33.** Make sure to check this on Linux/Mac because some package managers only have old versions of mpv. For windows, install the "Windows builds by shinchiro" version. [Make sure to add the mpv bin folder to your path](https://gist.github.com/nex3/c395b2f8fd4b02068be37c961301caa7).

### curl

Curl is used to communicate between the mpv incremental media script and a plugin running inside a parent application such as SuperMemo. Curl is used when the script is running in "minion mode".

Curl should already be installed on most modern operating systems. It has been included in Windows 10 since April 2018.

### [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

Git is a version control system which will be used to clone this project and update to new versions in the future.

## Installation

To install, you need to install the dependencies listed above and [make sure they are available in your path](https://gist.github.com/nex3/c395b2f8fd4b02068be37c961301caa7). Next you simply need to use git to clone this project into the mpv scripts folder:

### Main Scripts Folder

1. Open a terminal and go to the mpv scripts folder for your operating system. **You may need to create the scripts folder if it doesn't already exist**.

| OS | Location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/scripts/` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/scripts/` |

2. Type `git clone`, followed by the URL of this repository and hit enter to download this repository into the mpv scripts folder

### Updating

To update to the latest version, navigate into the incremental-media-mpv folder in the mpv scripts folder for your operating system. Run `git pull` to update to the latest version.

## Running

The incremental media player script can be run both as a standalone program, or it can be launched as a plugin.

### Standalone

To launch the incremental media script as a standalone application, run the following command:

`mpv --idle=yes --script-opts=im-mode=master`

If you want to launch a particular queue, use this command, where `queue_name` should be replaced with the name of the queue you want to launch:

`mpv --idle=yes --script-opts=im-mode=master,im-queue=queue_name`

#### Other CLI options

*To be updated...*

### Minion Mode

*To be updated*

## Config

| OS | Location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/script-opts/` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/script-opts/` |

To increase the font size of the text dialog input (which is really tiny by default), create a file called user_input.conf in the script-opts folder and set the font_size option to your preferred size. The default is 16.

For example, to set the font size to 24:

`font_size=24`
