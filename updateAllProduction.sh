#!/bin/bash

# Uses ssh to synchronize production code bases on multiple
# machines. Needs a version of git that supports the -C flag.

##    Update All Production - Use ssh to bulk pull on multiple servers
##    Copyright (C) 2016 Charles A. Tilford
##
##    This library is free software; you can redistribute it and/or
##    modify it under the terms of the GNU Lesser General Public
##    License as published by the Free Software Foundation; either
##    version 2.1 of the License, or (at your option) any later
##    version.
##
##    This library is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU Lesser General Public License for more details.
##
##    You should have received a copy of the GNU Lesser General Public
##    License along with this library; if not, write to the Free
##    Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
##    Boston, MA 02110-1301 USA

BAR="#-#-#-#-#-#-#"

MPD="ManagePerl"

function msg () {
    COL=$1
    MSG=$2
    echo -e "\033[1;${COL}m${MSG}\033[0m\n"
}

# Settings file, with $USER, $EMAIL, $TOKEN
CSET=$1

if [ "$CSET" == "" ]; then
    if [ -e "$HOME/cvsOpts.sh" ]; then
        CSET="$HOME/cvsOpts.sh"
    else
        echo "Please provide a path to your settings shell file as the first argument"
        exit;
    fi
fi

source "$CSET"

if [ "$PRODDIR" == "" ]; then
    msg '33;41' "PRODDIR has not been set"
    exit;
fi

if [ "$myServers" == "" ]; then
    msg '33;41' "myServers (array of hostnames) has not been set"
    exit;
fi

for i in ${myServers[@]}; do
    echo ""
    msg '33;44' "$BAR Synchronizing $i $BAR"
    echo ""
    ssh "$i" "cd $PRODDIR && git -C $MPD fetch && git -C $MPD pull && $MPD/cloneAllRepos.sh && $MPD/pullAllRepos.sh && $MPD/linkFiles.pl" \
        2>&1| grep -v '\*'
done
