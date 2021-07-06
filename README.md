# Incremental Media Player

An mpv script that implements an incremental media player (video and audio).

## Requirements

ffmpeg, youtube-dl, mpv

## Installation

`git clone` this repository into the mpv scripts folder for your operating system. You may need to create the scripts folder.

| OS | Location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/scripts/` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/scripts/` |

### Updating

To update to the latest version, navigate into the incremental-media-mpv folder in the mpv scripts folder for your operating system. Run `git pull` to update to the latest version.

## Running

To launch the incremental media script, run the following command:

`mpv --idle=once --script-opts=im-start=yes`

Copy youtube video or playlist urls to the clipboard and press Ctrl+Shift+V to import into the topic queue. Hit G to reload the global topic queue.

## Elements

The incremental media player script uses the same terminology as SuperMemo to refer to different kinds of playable elements (video and audio files). Different kinds of queues contain different kinds of elements.

### Topics

Topics are full-length lectures, documentaries, podcasts etc.
Topics are sorted by priority.
Topics can be scheduled.
Topics can have a dependency.
Extracts can be extracted from topics.

### Extracts

Extracts are sections extracted from topics.
All extracts have a parent topic.

### Items

Items are audio clozes taken from extracts.
All items have a parent extract.

## Queues

### Global Topic Queue

The elements in this queue are topics.
The topics in this queue are scheduled. 
Pressing next repetition will increment the interval and create a next repetition date at some point in the future.

### Local Topic Queue

The elements in this queue are topics
The elements in this queue are scheduled.
Global Topic Queues are activated by pressing the `parent` command when on an extract.
The elements in this queue are sorted according to priority, except for the first element in the queue which will be the parent of the child extract you called `parent` on.

### Global Extract Queue

The elements in this queue are extracts.
The extracts in this queue are scheduled.
Pressing next repetition will increment the interval and create a next repetition date at some point in the future.

### Local Extract Queue

The elements in this queue are extracts.
The extracts in this queue are not scheduled.
Local extract queues are activated by pressing the `child` command when on a topic, or by pressing the `parent` command when on an item.

### Global Item Queue

The elements in this queue are items.
The items in this queue are not scheduled.

### Local Item Queue

The elements in this queue are items.
The items in this queue are not scheduled.
Local Item Queues are activated by pressing the `child` command when on an extract.
