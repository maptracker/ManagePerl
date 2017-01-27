### Managing git repositories with Perl

These files are designed to aid in the maintenance of Perl modules in
git repositories. The goal is to allow Perl libraries to be found from
in-place, 'live' git repositories. The challenge here is that git (as
a collection of folders) is effectively flat, while Perl modules are
found in an explicit directory hierarchy search. Initially it seemed
like submodules might be a means to address the issue, but that was
ultimately rejected.
