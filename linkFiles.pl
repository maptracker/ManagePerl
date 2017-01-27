#!/stf/biobin/perl -w

use strict;

# The code should be run in a directory that contains all the git
# repos that need their contents linked into the relevant parts of the
# Perl script and/or module directories.

##    Link Files - Make symlinks from git Perl repos to appropriate Perl folders
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

my $gFile    = 'perlGuide.conf';
my $logFile  = "perlLinkLog.txt";
my ($lfh, %doneDir, %okDir);
open($lfh, ">$logFile") || &death("Failed to write log", $logFile, $!);

my $pwd = $ARGV[0] || `pwd`;
my $opts = lc($ARGV[1] || "");
my $isTrial = $opts =~ /(test|trial|tm)/ ? 1 : 0;

$pwd = `pwd` if ($pwd =~ /^\.[\/]+$/);
$pwd =~ s/[\/\n\r]+$//;

&death("Requested directory does not exist", $pwd) unless (-d $pwd);

&msg('1;35;40', "Searching for Perl git projects in:", $pwd);


my $dirDat = &parse_guide("$pwd/$gFile");
&death("Primary guide file does not exist. Expected location: $pwd/$gFile")
    unless ($dirDat);


# In the absence of a specific 
my $libDir   = $pwd; $libDir =~ s/\/[^\/]+$//;
my $modDirKey = 'DIR.pm';
unless ($dirDat->{$modDirKey}) {
    push @{$dirDat->{$modDirKey}}, $libDir;
}
&msg('1;35;40', "Perl module root:", $dirDat->{$modDirKey}[0]);

&parse_dir( $pwd, $dirDat );

&finish();

sub parse_dir {
    my ($gitDir, $gdat, $repoPath) = @_;
    return if (!defined $gitDir || $gitDir eq '');
    $gitDir =~ s/\/\s*$//;
    return if ($doneDir{$gitDir}++);
    
    my %guide = %{$gdat};
    if (my $localDat = &parse_guide("$gitDir/$gFile", $gdat)) {
        # Allow a local guide file to over-ride values in the prior one
        while (my ($k, $v) = each %{$localDat}) {
            $guide{$k} = $v;
        }
    }
    my %skip  = map { $_ => 1 } ('.', '..', '.git', '.gitignore',
                                 $gFile, $logFile,
                                 @{$guide{SKIP} || []});
    my @skRE  = ('~$', '#$');
    while (my ($k, $vals) = each %guide) {
        if ($k =~ /(\S+).REGEXP/) {
            my $typ = $1;
            if ($typ eq 'SKIP') {
                push @skRE, @{$vals};
            }
        }
    }
    my $skipRE = join('|', @skRE);
    my @stack = ($gitDir);
    if (opendir(DIR, $gitDir)) {
        my $gitDepth; # sublevel of this directory within the git repo
        if ($repoPath) {
            $gitDepth = "$gitDir/";
            $gitDepth =~ s/^\Q$repoPath\E//;
        }
        my (@subdirs, %bySfx);
        foreach my $file (readdir DIR) {
            next if ($skip{$file} || $file =~ /$skipRE/);
            my $path = "$gitDir/$file";
            if (-d $path) {
                push @subdirs, $path;
                next;
            } elsif ($repoPath) {
                my $sfx = "";
                if ($file =~ /\.([^\/\.]+)$/) { $sfx = $1; }
                push @{$bySfx{$sfx}}, $file;
            } else {
                &msg('0;35', "Unexpected - Ignoring file at generic git directory level",
                     $path);
            }
        }
        closedir DIR;
        while (my ($sfx, $files) = each %bySfx) {
            my ($tds, $issues) = &target_paths($sfx, \%guide, $gitDepth);
            if ($#{$tds} == -1) {
                my $why = join('/', map {"Directory $_"} @{$issues}) || "No suffix target";
                my @skf = map { &_relative_path($pwd, "$gitDir/$_") } @{$files};
                map { &msg('0;34', "Skip - $why - $_") } @skf;
            } else {
                foreach my $file (@{$files}) {
                    my $targs = $tds;
                    my $gfile = "$gitDir/$file";
                    if ($guide{"SUBDIR.$file"} || $guide{"DIR.$file"} ||
                        $guide{"BACKUP.$file"}) {
                        # This file has a different subdirectory
                        ($targs) = &target_paths
                            ($sfx, \%guide, $gitDepth, $file);
                        if ($#{$targs} == -1) {
                            &err('1;43', "Failed to find file-specific target directories", $gfile);
                            next;
                        }
                    }
                    foreach my $tdir (@{$targs}) {
                        &make_link($gfile, "$tdir/$file", $tdir, \%guide);
                    }
                }
            }
        }
        foreach my $sdir (@subdirs) {
            &parse_dir( $sdir, \%guide, $repoPath || $sdir );
        }
    } else {
        &err('1;41;33', "Failed to parse git directory!", $gitDir);
    }
}

sub make_link {
    my ($trg, $link, $tdir, $guide) = @_;
    return if ($link =~ /^\/dev\/null/);
    if (-l $link) {
        # The link already exists, and as a link. Perl's readlink() is
        # fast, but will not canonicalize the link
        my $rd = readlink($link);
        if ($rd) {
            my $abs = $rd;
            if ($rd =~ /^\.\./) {
                # De-relativize the link
                my $ldir = $link;
                $ldir =~ s/\/[^\/]+$//;
                $abs = &_absolute_path("$ldir/$rd");
            }
            if ($abs eq $trg) {
                &msg('0;37', "Exists  : ".&_absolute_path($link));
            } else {
                # Some of our systems have a rabbit warren of symlinks
                # and may present links that will resolve to identical
                # paths, but only after canonicalization. Use system's
                # readlink():
                my $abs  = `readlink -n -e '$link'` || "<DEAD LINK>";
                my $tabs = `readlink -n -e '$trg'`;
                if ($abs eq $tabs) {
                    &msg('0;37', "Exists  : ".&_absolute_path($link));
                } else {
                    my $dontComplain = 0;
                    if (my $ncomp = $guide->{NOCOMPLAIN}) {
                        # Perhaps it is ok that there is a different link here?
                        foreach my $nc (@{$ncomp}) {
                            $dontComplain++ if ($nc && $link =~ /\Q$nc\E/);
                        }
                    }
                    if ($dontComplain) {
                        &msg('0;37', "Ignoring: ".&_absolute_path($link));
                    } else {
                        &err('0;45;1;36', "Failed - Link exists to different ".
                             "target. Remove 'Link' path to resolve.",
                             "Link    = $link", "Desired = $tabs","Exists  = $abs");
                    }
                }
            }
        }
        return;
    } elsif (-d $link) {
        # Ah! It is there, but as a directory!
        &err('1;43;31', "Failed - Link path exists as a directory!", $link);
        return;
    } elsif (-e $link) {
        &err('1;43;31', "Failed - Link path exists as a file!", $link);
        return;
    }
    my $rel = &_relative_path( $link, $trg);
    my $cleanLink = &_absolute_path($link);
    if ($isTrial) {
        &msg('1;35', "Waiting : $cleanLink -> $rel");      
    } else {
        system("ln -s '$rel' '$link'");
        &msg("Created : $cleanLink -> $rel");
    }
}

sub target_paths {
    my ($sfx, $guide, $gitDepth, $file) = @_;
    my (@issues, @rv);
    $file  ||= "NO-FILE-PROVIDED";
    if (my $targs = $guide->{"DIR.$file"} || $guide->{"DIR.$sfx"}) {
        #if ($targs->[0] =~ /^<DIR\.(.+)>$/) {
        #    # eg <DIR.pl> --> inherit the setting for a different suffix
        #    # This is useful if you want to inherit 'upstream' settings,
        #    # for example to allow higher-level segregation from DEV/PROD
        #    # conf files
        #    my $inherit = $1;
        #    unless ($targs = $guide->{"DIR.$inherit"}) {
        #        return ([], ["$file tries to inherit DIR setting from empty $inherit suffix"]);
        #    }
        # }
        my @sdir = @{$guide->{"SUBDIR.$file"} || 
                         $guide->{"SUBDIR.$sfx"} || []};
        if ($#sdir == -1) {
            my $reqSD = $guide->{"REQUIRE_SUBDIR.$file"} ||
                $guide->{"REQUIRE_SUBDIR.$sfx"};
            if ($reqSD && $reqSD->[0]) {
                push @issues, "Subdirectory required but not designated";
            } else {
                # Need at least one 
                push @sdir, "";
            }
        }
        foreach my $main (@{$targs}) {
            foreach my $sd (@sdir) {
                my $dir = join('/', $main, $sd, $gitDepth);
                if (my $bkup = $guide->{"BACKUP.$file"} || 
                    $guide->{"BACKUP.$sfx"}) {
                    if ($bkup->[0] && $bkup->[0] =~ /^\/?\.\.(\/\.\.)*\/?$/) {
                        # This is in fact a backup request
                        $dir .= "/$bkup->[0]/";
                    } else {
                        &err('1;41;33', "Illegal backup request! Should be multiples of '..'", 
                             "DIR : $dir", "BKUP: $bkup->[0]");
                    }
                }
                $dir = &_absolute_path($dir);
                $dir =~ s/\/$//;
                if (my $issue = &dir_issue($dir, $guide)) {
                    push @issues, "$dir - $issue";
                } else {
                    push @rv, $dir;
                }
            }
        }
    }
    return (\@rv, \@issues);
}

sub dir_issue {
    my ($dir, $guide, $isPar) = @_;
    return 0 unless ($dir);
    $dir =~ s/\/+$//;
    return $okDir{$dir} if (defined $okDir{$dir});
    my $par = $dir; $par =~ s/\/[^\/]+$//;
    if (my $parIssue = &dir_issue($par, $guide, $isPar || $dir)) {
        return $okDir{$dir} = "Parent - $parIssue";
    }
    if (-l $dir) {
        # The directory exists but as a symlink. We are rejecting most
        # of these as they are historic hold-overs from the previous
        # CVS module management system.
        my @okLinks = @{$guide->{"OKDIRLINKS"} || []};
        for my $i (0..$#okLinks) {
            if ($okLinks[$i] =~ /^\Q$dir\E\/?$/) {
                # This directory has been explicitly listed as ok if
                # it exists as a link
                return $okDir{$dir} = 0;
            }
        }
        # No salvation for this directory, fail it as a symlink:
        return $okDir{$dir} = "already exists as a symlink" ;
    }
    if (-e $dir && !-d $dir) {
        if ($dir eq "/dev/null") {
            return $okDir{$dir} = 0;
        } else {
            return $okDir{$dir} = "already exists as a file";
        }
    }
    if (-d $dir) {
        &msg('1;37', "Exists  : ".&_absolute_path($dir)) unless ($isPar);
    } elsif ($dir !~ /^\/dev\/null($|\/)/) {
        mkdir($dir, 01777);
        # Not really sure why the above does not work (neither does 1777)
        # It sets permissions to drwxrwxr-t rather than drwxrwxrwt
        # I am using a system call to set directory permissions fully:
        system("chmod 1777 '$dir'");
        return $okDir{$dir} = "could not be created" unless (-d $dir);
        &msg('0;32', "Created : $dir");
    }
    return $okDir{$dir} = 0;
}

sub parse_guide {
    my ($file, $parent) = @_;
    my %data;
    if (-s $file) {
        open(GFH, "<$file") || death("Failed to open guide file", $file, $!);
        while (<GFH>) {
            next if (/^#/); # Skip comments
            s/[\n\r]+$//;
            if (/^\s*(\S+)\s*[:=]\s*(.+?)\s*$/) {
                my ($tag, $val) = ($1, $2);
                if ($val =~ /^<(.+)>$/) {
                    # We want to also inherit values from the parent guide file
                    my $inherit = $1;
                    if (my $vals = $data{$inherit}) {
                        # We are aliasing a parameter already set in this file
                        push @{$data{$tag}}, @{$vals};
                    } elsif ($parent) {
                        if (my $vals = $parent->{$inherit}) {
                            push @{$data{$tag}}, @{$vals};
                        } else {
                            &err('0;45;1;36', "$file tries to inherit '$tag' param from '$inherit', but parent had not set that parameter");
                        }
                    } else {
                        &err('0;45;1;36', "$file tries to inherit '$tag' param from '$inherit', but no parent guide file was found");
                    }
                } else {
                    push @{$data{$tag}}, $val;
                }
            }
        }
        close GFH;
    }
    if ($parent) {
        # Take any parent keys that were not set by the file
        while (my ($k, $v) = each %{$parent}) {
            $data{$k} ||= $v;
        }
    }
    return \%data;
}

sub finish {
    my @dIssues;
    foreach my $dir (sort keys %okDir) {
        if (my $issue = $okDir{$dir}) {
            push @dIssues, ($dir, "  $issue");
        }
    }
    &err('1;41;33',"Some directories had issues, preventing creation", @dIssues)
        unless ($#dIssues == -1);
    close $lfh;
    warn sprintf("\nLog File: \033[1;30;42m%s\033[0m\n\n", $logFile);
}

sub death {
    my $first = shift || "Unspecified error!";
    &msg("[FATAL] $first", @_);
    &finish();
    exit;
}

sub err {
    my $first = shift || "Unspecified error!";
    if ($first =~ /^[\d;]+$/) {
        my $ans = $first;
        $first = shift || "Unspecified error!";
        return &msg($ans, "!! $first", @_);
    } else {
        return &msg("!! $first", @_);
    }
}

sub msg {
    my $txt = "";
    my @lines = @_;
    my $ansiCol;
    if ($lines[0] && $lines[0] =~ /^[\d;]+$/) {
        $ansiCol = sprintf("\033[%sm%%s\033[0m", shift @lines);
    }
    for my $i (0..$#lines) {
        my $l = sprintf("%s%s", $i ? "    " : "" , $lines[$i]);
        print $lfh "$l\n" if ($lfh);
        if ($ansiCol) { $l = sprintf($ansiCol, $l); $ansiCol = ""; }
        $txt .= "$l\n";
    }
    warn $txt unless ($lines[0] =~ /^(Exists|Ignoring)/);
    return $txt;
}

sub _relative_path {
    my ($link, $targ) = @_;
    return "" unless ($link && $targ && $link =~ /^\// && $targ =~ /^\//);
    $link = &_absolute_path( $link );
    $targ = &_absolute_path( $targ );
    #$link =~ s/\/{2,}/\//g;
    #$targ =~ s/\/{2,}/\//g;
    my @lbit = split(/\//, $link);
    my @pbit = split(/\//, $targ);
    # Take off the first element ('/' root)
    shift @lbit; shift @pbit;
    my $shared = 0;
    while ($#lbit != -1 && $#pbit != -1 && $lbit[0] eq $pbit[0]) {
        shift @lbit; shift @pbit; $shared++;
    }
    # Have to use absolute paths if nothing is shared
    return $targ unless ($shared);
    # We have at least one common directory above root.
    # How far back do we need to go to get to a common directory?
    my $subdirs = $#lbit;
    my $backup  = ('../' x $subdirs) || '';
    return $backup . join('/', @pbit);
}

sub _absolute_path {
    my $path = $_[0] || "";
    $path =~ s/\/{2,}/\//g; # Turn '//' into '/'
    # Will not work on files starting with './'
    # Leaving it be for the moment, to catch SUBDIR oversights
    while ($path =~ /(\/[^\/]+\/\.\.\/)/) {
        my $backup = $1;
        if ($backup eq '/../../') {
            # Not really sure what to do here - this could be
            # significantly bad, so we will die
            &death('1;41;33', "Failed to normalize ../..!", $path);
            last;
        }
        $path =~ s/\Q$backup\E/\//g;
    }
    # Again, we should have eliminated .., so if it's still there let's die
    &death('1;41;33', "Disallowed residual '..' !", $_[0])
        if ($path =~ /\/\.\.\//);
    return $path;
}
