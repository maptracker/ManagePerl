#!/bin/bash

# This file should be passed as the first argument to
# migrateCvsToGit.sh. It is also used by other ManagePerl scripts to
# define characteristics of the git server.

# The local database where the CVSROOT directory is held:
export CVSDIR="/stf/source_distribution"
# The cvs2git executable
export C2G="/apps/external/cvs2svn-2.4.0/cvs2git"

# Username for the commits
export USER="gamgees"
# Real name and email; One or both of these (not sure which) needs to
# be available to mesh with git
export NAME="Samwise Gamgee"
export EMAIL="sam.gamgee@shire.com"

# Defining the git remote domain and giving it a name
export RMTURL="git.mordor.edu"
export RMTNAME="onering"

# GitHub access token - You need to make your own here:
# http://<YOUR_GITHUB_SERVER>/settings/tokens/new
# You will need just public_repo / repo scopes (maybe just public_repo?)
export TOKEN="83042a6e5bf59188945545447957974bf2f37a00"

# Optional guide file template for linkFiles.pl
# Will be added into git repo as 'perlGuide.conf'
export GUIDEFILE="$HOME/hobbit-guideFile.conf"

# This is the directory where the git repos will be cloned
# Only needed by setupProductionDirectory.sh
export PRODDIR="/mirkwood/production/gitFiles"

# List of servers used by updateAllProduction.sh
export myServers=(
    orc.mordor.edu
    allaboutsauron.mypages.com
)
