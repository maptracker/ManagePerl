#!/bin/bash

# This script is designed to subsume a repository into another
# one. This need is coming up as I migrate from CVS to git - I either
# overlook a file that needed to be surgically extracted from a large
# CVS repository, or I have files in two CVS repos that I now want in
# one.

# Change directory to the RECIPIENT repository (the one that will
# receive files). Run this script, passing two arguments:

# $1 - The URI of the SOURCE repository
# $2 - A commit message to associate with the merge

# Guidance is from:
# @Eric_Lee   : https://stackoverflow.com/a/14470212
# @Flimm      : https://stackoverflow.com/a/20974621
# Error Check : https://unix.stackexchange.com/a/22728

##    Absorb Another Repo - Move one repo entirely inside another, including log
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

if [ ! -d ".git" ]; then
    msg "1;33;41" "You do not appear to be inside a git repository"
    exit
fi

DonorURI=$1

if [ "$DonorURI" == "" ]; then
    msg "1;33;41" "Provide the URI to the second repository as the first argument"
    exit;
fi

ComMsg=$2

if [ "$ComMsg" == "" ]; then
    msg "1;33;41" "Please provide the commit message as the second argument"
    exit;
fi

DonorName="donorRepo"
DonorBranch="${DonorName}Branch"

if git remote add "$DonorName" "$DonorURI" ; then
    msg "1;33;44" "Registered second repository as remote"
else
    CHK=`git remote -v show | grep "$DonorName" | grep fetch | grep "$DonorURI"`
    if [[ -z "$CHK" ]]; then
        msg "1;33;41" "Failed to set up donor as a remote!"
        msg "1;33;42" "If the remote already existed, you can use:\n  git remote remove '$DonorName'"
        exit
    else
        msg "1;33;45" "Donor repo $DonorName already exists, but seems to be the correct URI:\n   $DonorURI"
    fi 
fi

if git fetch "$DonorName" ; then
    msg "1;33;44" "Donor repo fetched"
else
    msg "1;33;41" "Error fetching donor repo!"
    exit
fi

CHKBRANCH=`git branch -v --list | grep "$DonorBranch"`


if [[ -z "$CHKBRANCH" ]]; then
    if git branch "$DonorBranch" "${DonorName}/master" ; then
        msg "1;33;44" "Branch ${DonorName}/master created"
    else
        msg "1;33;41" "Failed to create branch!"
        exit
    fi
else
    msg "1;33;45" "Donor branch already exists, using as-is:\n   $CHKBRANCH"
fi

if git checkout master ; then
    msg "1;33;44" "${DonorName}/master checked out"
else
    msg "1;33;41" "Failed to checkout branch!"
    exit
fi

if git merge -m "$ComMsg" "$DonorBranch" ; then
    msg "1;33;44" "Branches merged"
else
    msg "1;33;41" "Failed to merge branch!"
    exit
fi

if git remote remove "$DonorName" ; then
    msg "1;33;44" "Donor remote removed"
else
    msg "1;33;41" "Failed to remove donor remote. This may be ok, but is unexpected."
fi

msg "1;33;44" "Finished!"
msg "1;33;41" "Don't forget to push!"

