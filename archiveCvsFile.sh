#!/bin/bash

# This script just moves a file to an archive folder after it has been
# migrated to git. Useful for monolithic CVS repos that need to be
# split up into multiple smaller git repos.

##    Archive CVS File - Surgically extract a file from one CVS repo to another
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

TARGDIR="GitMigrated"
FILE="$1"

function err () {
    MSG=$1
    echo -e "\033[1;33;41m${MSG}\033[0m\n"
    exit
}

[ -z "$FILE" ] && err "Pass a file as the first argument"

[[ -f "$FILE" ]] || err "$FILE is not a file"

if [[ ! -d "$TARGDIR" ]]; then
    mkdir "$TARGDIR"   || err "Failed to create $TARGDIR"
    cvs add "$TARGDIR" || err "Failed to add $TARGDIR to cvs"
fi


# http://www.thathost.com/wincvs-howto/cvsdoc/cvs_7.html#SEC71

TARG="$TARGDIR/$FILE"

mv "$FILE" "$TARG" || err "Failed to move $FILE to $TARGDIR"
cvs remove "$FILE" || err "Failed to remove $FILE from repository"
cvs add "$TARG"    || err "Failed to add $TARG to repository"
cvs commit -m "Archived file after git migration" || err "Failed to commit"


