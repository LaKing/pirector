#!/bin/bash

xsetroot -solid white

function authorinfo {
echo "$(hostname) IP: $(hostname -I) -  $(date +%Y.%m.%d-%H:%M:%S)" >> message
echo 'Playlist player / mix-recorder / vnc controll / raspberry / fedora' >> message
echo 'Written by Istvan Kiraly - LaKing@D250.hu - D250 Laboratories 2015' >> message
echo '__________________________________________________________________' >> message
echo '' >> message
}

if [ -f "apps.pid" ]
then
    echo "WARNING, script supposed to be a singleton - PID found - killing $(cat apps.pid)" >> log
    kill $(cat apps.pid | xargs)
    authorinfo
fi

echo $$ > apps.pid


if [ -f /etc/fedora-release ]
then
    ## palyin fedora
    FEDORA=true
fi

if [ -f /etc/rpi-issue ] && [ -d ~/cirrus ]
then
    ## raspberry PI 2 with cirrus logic audi card
    PICI=true
fi


if [ -f config ]
then
    source config
fi

## atostart at
if [ -z "$AUTOSTART_TIME" ]
then
    AUTOSTART_TIME=16:00
    AUTOSTART_PLAYLIST=false
else
    AUTOSTART_PLAYLIST=true
fi

## record on/off
if [ -z "$RECORD_ENABLED" ]
then
    RECORD_ENABLED=$PICI
fi

## playlist on/off
if [ -z "$PLAYLIST_ENABLED" ]
then
    PLAYLIST_ENABLED=true
fi

## upload on/off
if ! [ -z "$UPLOAD_COMMAND" ]
then
    UPLOAD_ENABLED=true
fi

if [ -f upload.sh ]
then
    UPLOAD_ENABLED=true
    UPLOAD_COMMAND="bash upload.sh"
fi

if [ -z "$MUSIC_DIR" ]
then
    MUSIC_DIR=~/Music
fi


if [ -z "$REC_DIR" ]
then
    REC_DIR=~/rec
fi




## by the way, if using ratpoison,
## Ctrl-t Ctrl-C will open a terminal.


## random string generator
randa(){ < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-16};echo;}

## random tracklist
function symlink_Music {

    rm -rf symlinks
    mkdir -p symlinks

    find $MUSIC_DIR -name '*.mp3' -or -name '*.wav' > musicfiles

    while read f 
    do 
	echo "Symlinking $f"
	ln -s "$f" symlinks/$(randa).mp3
    done < musicfiles

}

## this uses xmms2 for music playback
function play_playlist {

    symlink_Music
    xmms2 clear
    xmms2 add symlinks
    xsetroot -solid gray
    xmms2 play
    lxmusic
    xmms2 stop
    xmms2 list > playlist

}


function set_message {

    ## generate message string
    cat current >> message
    NOW="$(date +%Y-%m-%d)"
    echo "NOW: $NOW" >> message

    df -k -h . >> message

    echo "CAPACITY check" >> message
    du -hs $REC_DIR >> message
    
    echo "MEDIA LIB: $MUSIC_DIR" >> message
    du -hs $MUSIC_DIR >> message
    
    echo "PLAYLIST" >> message
    cat playlist >> message
}

function autostart_dialog {

    while true
    do
	echo '' > message
	authorinfo

	echo "WAITING FOR AUTOSTART AT $AUTOSTART_TIME - current time is $(date +%H:%M)" >> message
	xmessage -buttons START:40,WAIT:60,ABORT:61 -default WAIT -timeout 60 -file message
	res=$?


	if [ "$(date +%H%M)" -ge "$(echo $AUTOSTART_TIME | tr -d ':')" ] || [ "$res" == "40" ] 
	then
	    play_playlist
	    break
	fi

	if [ "$res" == "61" ]
	then
	    break
	fi

    done

}

## if there is Music, then default to play playlist at start
if $AUTOSTART_PLAYLIST
then
    autostart_dialog
fi

## the default response
res=2

#### THE MAIN LOOP ######
while [ "$res" != "100" ]
do

    echo '' > message
    authorinfo


    xmms2 stop

    set_message

    buttons="REFRESH:5"

    if $PLAYLIST_ENABLED
    then
        buttons="$buttons,PLAYLIST:40,START@$AUTOSTART_TIME:50"
    fi

    if $RECORD_ENABLED
    then
        if $PICI 
        then
		buttons="$buttons,ANALOG-IN:10,SPDIF-IN:11"
        fi
        buttons="$buttons,RECORD:30"
        if $UPLOAD_ENABLED
        then
		buttons="$buttons,UPLOAD:35"
        fi
    fi

    buttons="$buttons,REBOOT:90,SHUTDOWN:91,EXIT:100"

    xmessage -buttons $buttons -file message
    res=$?


    if [ "$res" == "10" ]
    then
	xsetroot -solid red
        bash ~/cirrus/Record_from_lineIn.sh
    fi

    if [ "$res" == "11" ]
    then
	xsetroot -solid yellow
	bash ~/cirrus/SPDIF_record.sh
    fi

    if [ "$res" == "35" ]
    then
	xsetroot -solid white
	echo $UPLOAD_COMMAND > upload
	$UPLOAD_COMMAND >> upload 2>&1 &
	uploadpid=$!

	while true
	do
	    if ps -p $uploadpid > /dev/null
	    then
		btn=REFRESH:36,ABORT:37
	    else
		btn=DONE:37,CLEANUP:38
	    fi

	    xmessage -buttons $btn -timeout 60 -file upload 
	    res=$?

	    if [ "$res" == "37"  ]
	    then
		kill $uploadpid
		break
	    fi

	    if [ "$res" == "38"  ]
	    then
		echo CLEANUP >> upload
		rm -rf $REC_DIR/* >> upload
		df -k -h . >> upload
		break
	    fi

	done
    fi


    if [ "$res" == "30" ]
    then
	## create an empty file that we can just overwrite with a few clicks
	if [ ! -f "$REC_DIR/$PREFIX-$NOW.flac" ] && [ ! -z "$PREFIX" ]
	then
    	    echo '' > $REC_DIR/$PREFIX-$NOW.flac
        fi
        cat audacity.cfg > ~/.audacity-data/audacity.cfg
        #echo "Parh=$(dirname $REC_DIR/$NOW)/$NOW" >> ~/.audacity-data/audacity.cfg
        $(cd $REC_DIR && audacity)
    fi



    if [ "$res" == "40" ]
    then
        play_playlist
    fi

    if [ "$res" == "50" ]
    then
        autostart_dialog
    fi



    if [ "$res" == "90" ]
    then
        sudo reboot
        exit
    fi


    if [ "$res" == "91" ]
    then
        sudo halt
        exit
    fi

done # main loop

rm -rf apps.pid
exit
