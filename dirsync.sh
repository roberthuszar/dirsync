#!/bin/bash

################################################################
# DirSync v0.1                                                 #
# Last update: 2020-06-05                                      #
# Created by:                                                  #
#    Robert Huszar                                             #
#    oberusza@gmail.com                                        #
#    roberthuszar.com                                          #
################################################################

#Variables
SOURCE_DIRECTORY="/var/tmp/test"                      # Source directory full path
DESTINATION_DIRECTORY="/var/tmp/test"                 # Destination directory full path
EVENTS="modify,attrib,close_write,move,create,delete" # Trigger events
GRACE_NUMBER=5                                        # File modification number
SERVERS="server1 server2"                             # Server IP-s or resolvable names, separated with spaces
USERNAME="username"                                   # Username for SSH sessions
MINFREEDISKSPACE="1"                                  # Minimum free disk space on destination servers (GB)
RSYNC_OPTIONS="-ar --delete-before"                   # Rsync options

################################################################

#File synchronization
syncfiles() {
    echo "Synchronization started on $SERVER..."
    rsync $RSYNC_OPTIONS $SOURCE_DIRECTORY/ $USERNAME@$SERVER:$DESTINATION_DIRECTORY/
    echo "Synchronization ended on $SERVER."
}

#Check servers
servercheck() {
    #Check free diskspace
    for SERVER in $SERVERS; do
	FREEDISKSPACE=$(ssh $USERNAME@$SERVER "df -PH --block-size=G $DESTINATION | tail -1 | awk '{print \$4}'" | tr -d "G")
	if [ $FREEDISKSPACE -ge $MINFREEDISKSPACE ]; then
		echo "Disk space is OK on $SERVER"
		syncfiles
	else
	    echo "Disk space is low on $SERVER (under $MINFREEDISKSPACE GB)"
	fi
    done
    exec ./dirsync.sh
}

#Scheduler
schedule() {
    while true; do
	count=0
	while read -t 1; do
	    (( count++ ))
	done
	if [ $count -gt 0 ]; then
		if [ $count -eq $GRACE_NUMBER ] || [ $count -gt $GRACE_NUMBER ]; then
			echo "$count changes detected."
			servercheck
		fi
	fi
    done < <(inotifywait -m -r -e $EVENTS $SOURCE_DIRECTORY 2>/dev/null)
}

#Starter
starter() {
    if [ $(pgrep "cadsync" | wc -l ) -le 1 ]; then
	echo "DirSync started..."
	schedule
    else
        echo "WARNING - DirSync is already watching, exiting."
    exit
    fi
}

#Check dependencies
command -v inotifywait &>/dev/null
if [ $? -ne 0 ]; then
	echo "ERROR - inotifywait command is missing."
    echo "Please install inotifywait command from inotify-tools package!"
    exit
else
    starter
fi
