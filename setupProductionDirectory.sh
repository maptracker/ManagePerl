#!/bin/bash

# This script will initialize a folder on a host to hold the
# "production" git directory. The directory will ultimately be managed
# by the ManagePerl repository.

##    Setup Production Directory - Set basic structures for ManagePerl (PROD)
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

# Settings file, with $USER, $EMAIL, $TOKEN
CSET=$1

function msg () {
    COL=$1
    MSG=$2
    echo -e "\033[1;${COL}m${MSG}\033[0m\n"
}

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

if [ "$RMTURL" == "" ]; then
    msg '33;41' "RMTURL has not been set"
    exit;
fi

if [ "$USER" == "" ]; then
    msg '33;41' "USER has not been set"
    exit;
fi

# Create the directory (if needed) and move there
mkdir -p "$PRODDIR"
chmod 1777 "$PRODDIR"
cd "$PRODDIR"

# Make sure the ManagePerl repo is present
git clone "git@$RMTURL:$USER/ManagePerl.git"

# Make symlink to guide file
ln -s ManagePerl/PROD-perlGuide.conf perlGuide.conf

# Symlink to list of managed repositories
ln -s ManagePerl/managedRepos.txt .

# Make a link to a README explaining the folder
ln -s ManagePerl/Production-README README
ln -s ManagePerl/Production-README README

msg '33;44' "Production directory created: $PRODDIR"


# You can now add this machine's domain name to
# updateAllProduction.sh, and then run that script to clone in all the
# relevant repos to the directory.
