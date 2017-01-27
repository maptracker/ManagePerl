#!/bin/sh -e


# USAGE: Run this script in a repo's folder to alter the timestamps of
# all tracked files to their last commit time. This enrages Linus
# Torvalds, but if you're not using 'make' then you should be fine.


# What's the equivalent of use-commit-times for git?
# Answer 2 : https://stackoverflow.com/a/5531813

# I (Alex Dean) took Giel's answer and instead of using a post-commit
# hook script, worked it into my custom deployment script.

# Adapted to use HEAD rather than the new commit ref
get_file_rev() {
    git rev-list -n 1 HEAD "$1"
}

# Same as Giel's answer above
update_file_timestamp() {
    file_time=`git show --pretty=format:%ai --abbrev-commit "$(get_file_rev "$1")" | head -n 1`
    touch -d "$file_time" "$1"
}

# CAT - Add optional directory to run in

if [[ ! -z "$1" ]]; then
    if [[ -d "$1" ]]; then
        cd "$1"
    else
        echo "Optional first argument should be a directory. It is not"
        exit
    fi
fi

# Loop through and fix timestamps on all files in our CDN directory
old_ifs=$IFS
IFS=$'\n' # Support files with spaces in them
for file in $(git ls-files | grep "$cdn_dir")
do
    update_file_timestamp "${file}"
done
IFS=$old_ifs
