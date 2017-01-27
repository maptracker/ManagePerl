#!/bin/bash

# This script uses git clone via SSH to clone all repositories defined
# in a text file. The text file should contain 'bare' repo names (eg
# 'MyRepo', not 'MyRepo.git'), one per line. Part of the ManagePerl
# suite of tools for managing a collection of Perl libraries in git.

##    Clone All Repos - Bulk clone many git repositories at once
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

function msg () {
    COL=$1
    MSG=$2
    echo -e "\033[1;${COL}m${MSG}\033[0m\n"
}

if [ "$1" != "" ]; then
    # First argument specifies a directory other than the current one
    cd "$1"
fi

# Settings file, with $USER, $EMAIL, $TOKEN
CSET=$2

if [ "$CSET" == "" ]; then
    if [ -e "$HOME/cvsOpts.sh" ]; then
        CSET="$HOME/cvsOpts.sh"
    else
        echo "Please provide a path to your settings shell file as the second argument"
        exit;
    fi
fi

if [ "$RMTURL" == "" ]; then
    msg '33;41' "RMTURL has not been set"
    exit;
fi

if [ "$USER" == "" ]; then
    msg '33;41' "USER has not been set"
    exit;
fi

SSHPREFIX="git@$RMTURL:$USER/"
REPOLIST="managedRepos.txt"


HERE=`pwd`
msg "35;40" "$HERE"

# Make sure the repo file is updated
msg "0;34;43" "Updating repository list..."
git -C ManagePerl/ fetch && git -C ManagePerl/ pull

echo -e "Cloning all repositories defined in \033[1;35;40m$REPOLIST\033[0m ..."

# Read a file: https://stackoverflow.com/a/10929511
while IFS='' read -r REPO || [[ -n "$REPO" ]]; do
    echo -e "\n\033[1;33;44m#### $REPO\033[0m"
    URI="$SSHPREFIX$REPO".git
    if [ -d "$REPO" ]; then
        # The directory exists. Is it already a git repo?
        # https://stackoverflow.com/a/4089452
        NOWURI=`git -C "$REPO" config --get remote.origin.url`
        if [ "$NOWURI" == "" ]; then
            # This directory does not appear to be a git repo!
            echo -e "\n\033[1;31;43mDirectory exists and is not a git repository!\033[0m"
        elif [ "$NOWURI" == "$URI" ]; then
            # Ok, same repo we are requesting
            echo -e "\n\033[1;32;40mRepository is already cloned.\033[0m"
        else
            # It is a repo, but not the one we want!!
            echo -e "\n\033[1;31;43mDirectory exists but for different repository!  $NOWURI\033[0m"
        fi
        continue
    fi
    # git clone does weird stuff with STDERR. --progress makes sure it's there
    # https://stackoverflow.com/a/4063660

    git -c color.status=always clone "$URI" --progress 2>&1 | \
        egrep '(remote: Total|Checking connectivity)'

    if [[ -f "ManagePerl/update_timestamps.sh" ]]; then
        # Update the timestamps
        ManagePerl/update_timestamps.sh "$REPO"
    fi
done < "$REPOLIST"

echo -e "\n"
