#!/bin/sh -e

# What's the equivalent of use-commit-times for git?
# Answer 1 : https://stackoverflow.com/a/2038768

# If, however you really want to use commit times for timestamps when
# checking out then try using this script and place it (as executable)
# in the file $GIT_DIR/.git/hooks/post-checkout:

OS=${OS:-`uname`}
old_rev="$1"
new_rev="$2"

get_file_rev() {
    git rev-list -n 1 "$new_rev" "$1"
}

if   [ "$OS" = 'Linux' ]
then
    update_file_timestamp() {
        file_time=`git show --pretty=format:%ai --abbrev-commit "$(get_file_rev "$1")" | head -n 1`
        touch -d "$file_time" "$1"
    }
elif [ "$OS" = 'FreeBSD' ]
then
    update_file_timestamp() {
        file_time=`date -r "$(git show --pretty=format:%at --abbrev-commit "$(get_file_rev "$1")" | head -n 1)" '+%Y%m%d%H%M.%S'`
        touch -h -t "$file_time" "$1"
    }
else
    echo "timestamp changing not implemented" >&2
    exit 1
fi

IFS=`printf '\t\n\t'`

git ls-files | while read -r file
do
    update_file_timestamp "$file"
done
