#!/bin/bash

# This script automates the transfer of a CVS repository (including
# commit history) into git. 99% of the work is done by cvs2git
# (authored by a team at Tigris.org), this script primarily organizes
# the steps in the transfer process, and also abstracts some settings
# to a configuration file.

# Main documentation for cvs2git:
# http://cvs2svn.tigris.org/cvs2git.html

# Make sure your CVS repo is fully comitted first! To find untracked
# files in CVS, use, the following command, untracked files will show
# up as '?'   https://unix.stackexchange.com/a/12123

#   cvs -qn update

# Arguments:
# $1 = Settings file -  see sampleMigrateOptionsFile.sh for guidance
# $2 = name for new git repository
# $3 = Path to CVS repository. Can be the CVS folder name, if CVSDIR was
#      set in your options file. If the git name is identical to the CVS folder,
#      then it can be left out
# $4 = Optional list of files to keep from CVS repo, all others will be
#      excluded. Pipe separated, eg 'MyLib.pm|MyLib'

##    Migrate CVS to git - Move CVS repositories and history to git
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

# Settings file, with $USER, $EMAIL, $TOKEN
CSET=$1

function msg () {
    COL=$1
    MSG=$2
    echo -e "\033[1;${COL}m${MSG}\033[0m\n"
}

if [ "$CSET" == "" ]; then
    echo "Please provide a path to your settings shell file as the first argument"
    exit;
fi

source "$CSET"

# These variables should have been defined in the settings file:
if [ "$USER" == "" ]; then
    echo "USER has not been set"
    exit;
fi

if [ "$EMAIL" == "" ]; then
    echo "EMAIL has not been set"
    exit;
fi

if [ "$RMTNAME" == "" ]; then
    echo "RMTNAME has not been set"
    exit;
fi

if [ "$RMTURL" == "" ]; then
    echo "RMTURL has not been set"
    exit;
fi

if [ "$TOKEN" == "" ]; then
    echo "TOKEN has not been set"
    echo "If you need a token, make one here: https://$RMTURL/settings/tokens"
    exit;
fi

if [ "$C2G" == "" ]; then
    echo "C2G (cvs2git executable) has not been set"
    echo "You can find it here: http://cvs2svn.tigris.org/cvs2git.html"
    exit;
fi


# What you want the repo named in git
REPO=$2

if [ "$REPO" == "" ]; then
    echo "Please provide the git repo name as the second argument"
    exit;
fi

# The path that contains the CVS repo
# /stf/source_distribution/ ...
SRC=$3

if [ "$SRC" == "" ]; then
    if [ "$CVSDIR" == ""]; then
        echo "Please provide the path to the CVS repository as the third argument"
        exit;
    else
        SRC="$CVSDIR/$REPO"
        echo -e "Source set using CVSDIR to $SRC"
    fi
else
    HASSLASH=`echo "$SRC" | grep '\/'`
    if [ "$HASSLASH" == "" ]; then
        if [ "$CVSDIR" == "" ]; then
            echo "You are providing a simple CVS path ($SRC) without setting CVSDIR."
            echo "If the repository path can not be found, either set CVSDIR or provide the full path to the repo"
        else
            SRC="$CVSDIR/$SRC"
            echo -e "Source set using CVSDIR to $SRC"
        fi
    fi        
fi

msg '33;44' "$BAR Setting up local files $BAR"

# The local working directory
WRKDIR="$HOME/cvs2git/$REPO"


PDIR="$WRKDIR/$REPO"
BAREDIR="$PDIR.git"

mkdir -p "$WRKDIR"

cd "$WRKDIR"
echo -en "Working in "
msg '34;47' "$WRKDIR"

BLOB="git-blob.dat"
PREDUMP="git-dump-WrongTimeZone.dat"
DUMP="git-dump.dat"
OPTFILE="cvs2git.options"

# We are going with the options file to define the email/name mappings.

rm -f "$OPTFILE"

cat <<EOF > "$OPTFILE"
# http://cvs2svn.tigris.org/cvs2git.html#docs
# https://github.com/mhagger/cvs2svn/blob/master/cvs2git-example.options

# I almost certainly do not need all of these, but I am too lazy
# to work at pruning them down

import os

from cvs2svn_lib import config
from cvs2svn_lib import changeset_database
from cvs2svn_lib.common import CVSTextDecoder
from cvs2svn_lib.log import logger
from cvs2svn_lib.git_revision_collector import GitRevisionCollector
from cvs2svn_lib.external_blob_generator import ExternalBlobGenerator
from cvs2svn_lib.git_output_option import GitRevisionMarkWriter
from cvs2svn_lib.git_output_option import GitOutputOption
from cvs2svn_lib.dvcs_common import KeywordHandlingPropertySetter
from cvs2svn_lib.rcs_revision_manager import RCSRevisionReader
from cvs2svn_lib.cvs_revision_manager import CVSRevisionReader
from cvs2svn_lib.symbol_strategy import AllBranchRule
from cvs2svn_lib.symbol_strategy import AllTagRule
from cvs2svn_lib.symbol_strategy import BranchIfCommitsRule
from cvs2svn_lib.symbol_strategy import ExcludeRegexpStrategyRule
from cvs2svn_lib.symbol_strategy import ForceBranchRegexpStrategyRule
from cvs2svn_lib.symbol_strategy import ForceTagRegexpStrategyRule
from cvs2svn_lib.symbol_strategy import ExcludeTrivialImportBranchRule
from cvs2svn_lib.symbol_strategy import ExcludeVendorBranchRule
from cvs2svn_lib.symbol_strategy import HeuristicStrategyRule
from cvs2svn_lib.symbol_strategy import UnambiguousUsageRule
from cvs2svn_lib.symbol_strategy import HeuristicPreferredParentRule
from cvs2svn_lib.symbol_strategy import SymbolHintsFileRule
from cvs2svn_lib.symbol_transform import ReplaceSubstringsSymbolTransform
from cvs2svn_lib.symbol_transform import RegexpSymbolTransform
from cvs2svn_lib.symbol_transform import IgnoreSymbolTransform
from cvs2svn_lib.symbol_transform import NormalizePathsSymbolTransform
from cvs2svn_lib.property_setters import AutoPropsPropertySetter
from cvs2svn_lib.property_setters import ConditionalPropertySetter
from cvs2svn_lib.property_setters import cvs_file_is_binary
from cvs2svn_lib.property_setters import CVSBinaryFileDefaultMimeTypeSetter
from cvs2svn_lib.property_setters import CVSBinaryFileEOLStyleSetter
from cvs2svn_lib.property_setters import DefaultEOLStyleSetter
from cvs2svn_lib.property_setters import EOLStyleFromMimeTypeSetter
from cvs2svn_lib.property_setters import ExecutablePropertySetter
from cvs2svn_lib.property_setters import KeywordsPropertySetter
from cvs2svn_lib.property_setters import MimeMapper
from cvs2svn_lib.property_setters import SVNBinaryFileKeywordsPropertySetter

ctx.username = '$USER'

author_transforms={
    '$USER' : ('$NAME', '$EMAIL'),
    }

ctx.revision_collector = GitRevisionCollector(
    '$BLOB',
    CVSRevisionReader(cvs_executable=r'cvs'),
    )

ctx.output_option = GitOutputOption(
    '$PREDUMP',
    GitRevisionMarkWriter(),
    author_transforms=author_transforms,
    )

global_symbol_strategy_rules = [
    ExcludeTrivialImportBranchRule(),
    UnambiguousUsageRule(),
    BranchIfCommitsRule(),
    HeuristicStrategyRule(),
    HeuristicPreferredParentRule(),
    ]

run_options.set_project(
    r'$SRC',
    symbol_transforms=[
        # The following transform, which converts backslashes into forward
        # slashes, should usually be included:
        ReplaceSubstringsSymbolTransform('\\\\','/'),

        # This last rule eliminates leading, trailing, and repeated
        # slashes within the output symbol names:
        NormalizePathsSymbolTransform(),
        ],

    # See the definition of global_symbol_strategy_rules above for a
    # description of this option:
    symbol_strategy_rules=global_symbol_strategy_rules,

EOF

# Optional list of one or more files to *keep*.
# Must be listed as seen by cvs (eg "foo.p,v", not "foo.p")
# Separated by vertical bars, eg:
# CsfManager|CsfManager.pm,v|CsfManager.param,v
KEEP=$4

if [ "$KEEP" != "" ]; then
    # 1. Find all files in target directory
    # 2. grep away the ones we want to keep
    # 3. Swap new lines into comma-separated quoted values (2 steps)
    # 4. Remove trailing whitespace/quotes/commas
    EXCLUDE=`ls -1 "$SRC" | egrep -v "($KEEP)" |\
             tr '\n' '@' | sed "s/@/', '/g" | sed $'s/[,\' ]*$//g'`
    cat <<EOF >> "$OPTFILE"
    # Files to exclude:
    exclude_paths=['$EXCLUDE'],
    # Keeping: $KEEP
EOF
    
fi

cat <<EOF >> "$OPTFILE"
    )

ctx.file_property_setters.extend([
    CVSBinaryFileEOLStyleSetter(),
    CVSBinaryFileDefaultMimeTypeSetter(),
    DefaultEOLStyleSetter(None),
    SVNBinaryFileKeywordsPropertySetter(),
    KeywordsPropertySetter(config.SVN_KEYWORDS_VALUE),
    ExecutablePropertySetter(),
    ConditionalPropertySetter(
        cvs_file_is_binary, KeywordHandlingPropertySetter('untouched'),
        ),
    KeywordHandlingPropertySetter('collapsed'),

    ])

EOF

echo -en "Options file: "
msg '34;47' "$OPTFILE"

msg '33;44' "$BAR Extracting information from CVS $BAR"

$C2G --options=$OPTFILE

if [ -s "$PREDUMP" ]; then
    # No apparent way to change time zone. Set it with sed
    sed 's/\+0000$/-0500/g' "$PREDUMP" > "$DUMP"
else
    msg '33;41' "Failed to generate dump file!"
    exit
fi

# Make the remote repository
curl -u "$USER:$TOKEN" "https://$RMTURL/api/v3/user/repos" \
     -d "{\"name\":\"$REPO\"}" > remoteInfo.json

msg '33;44' "$BAR Making initial bare git repo $BAR"

rm -rf "$BAREDIR"
git init --bare "$BAREDIR"
cd "$BAREDIR"

# If you do not tell *git* about who you are, you will not match up
# the commit information in the dump file with your git account. I
# think the email is used as the primary key?
git config user.email "$EMAIL"
git config user.name "$NAME"


cat "../$BLOB" "../$DUMP" | git fast-import

git branch -D TAG.FIXUP

git gc --prune=now

cd "$WRKDIR"

msg '33;44' "$BAR Making local git clone $BAR"

rm -rf "$PDIR"
git clone "$BAREDIR"

cd $PDIR

# Add a new remote
git remote add $RMTNAME "git@$RMTURL:$USER/$REPO.git"

# Set the remote as the default
# https://stackoverflow.com/a/18801178
git push -u $RMTNAME master

if [ "$GUIDEFILE" != "" ]; then
    # There is a template guide file specified
    LOCGUIDE="perlGuide.conf"
    cp "$GUIDEFILE" "$LOCGUIDE"
    if [ -s "$LOCGUIDE" ]; then
        git add "$LOCGUIDE"
        git commit -m "Added template guide file"
        echo -en "Guide file copied : "
        msg '35;43' "$LOCGUIDE"
    else
        msg '33;41' "Failed to copy guide file from $GUIDEFILE"
    fi
fi

# FINALLY - push to remote!
git push
git status

msg '33;44' "$BAR Finished! $BAR"

echo -en "Options file : "
msg '34;47' "$WRKDIR/$OPTFILE"
echo -en "Local repo   : "
msg '34;47' "$PDIR"
echo -en "Remote URL   : "
msg '35;47' "http://$RMTURL/$USER/$REPO"
