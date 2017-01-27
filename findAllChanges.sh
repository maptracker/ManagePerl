#!/bin/bash

# This script is intended to be run in a folder that contains multiple
# git repositories. It will fetch each repository, then run a status
# to report the state of each one. Output is streamlined to remove a
# lot of the git verbosity.

# Inspired by         https://stackoverflow.com/a/13337546
# git -C flag         https://stackoverflow.com/a/20115526
# Redirecting STDERR  https://unix.stackexchange.com/a/3540
# keep color in git   https://stackoverflow.com/a/18304605
# Branch vs master    https://stackoverflow.com/a/822859
# Reminding me that I have to fetch before status: Matt Ralston

##    Find All Changes - Find all changes in a folder of git repos
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

if [ "$1" != "" ]; then
    # First argument specifies a directory other than the current one
    cd "$1"
fi
HERE=`pwd`
echo -e "\n\033[1;35;40m$HERE\033[0m"

echo "Finding changes in all repositories..."

for REPO in `ls`; do
    # Check to see if it is actually a git repository
    if [ -d "$REPO/.git" ]; then
        echo -e "\n\033[1;33;44m#### $REPO\033[0m"
        git -C "$REPO" -c color.status=always fetch 2>&1 | \
            egrep '( -> )'
        # Ignoring untracked files
        git -C "$REPO" -c color.status=always status 2>&1 | \
            egrep \
                '(is up-to-date|is behind|is ahead of|modified:|renamed:|new file:)'
        # Almost certainly missing some states that should be added to above...

        # Now check to see if we are not on master:
        BRANCH=`git -C "$REPO" branch | grep '\*' | egrep -o '[^\* ].*'`
        if [ "$BRANCH" != 'master' ]; then
            # Does not look like it - compare this branch to master:
            echo -e "        \033[2;4;30;46m$BRANCH relative to master:\033[0m"
            git -C "$REPO" diff --name-status master..$BRANCH
        fi
    fi
done

echo -e "\n"
