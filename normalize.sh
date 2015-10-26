#!/bin/bash


if [ -f config ]
then
    source config
fi

if [ -z "$MUSIC_DIR" ]
then
    MUSIC_DIR=~/Music
fi

find $MUSIC_DIR -iname '*.mp3' -exec mp3gain -r {} \;