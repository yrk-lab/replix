#!/bin/sh
#	Watch ./apply_test.sh
usage(){
	echo >&2 'apply.sh old new [timefile] <log'
	echo >&2 'see also replica/applylog in https://9p.io/magic/man2html/8/replica'
	exit 64
}

case $# in
[23])	old=${1?} new=${2?} timefile=$3;;
*)	usage
esac

exec awk -v "old=$old" -v "new=$new" -v "timefile=$timefile"  '
BEGIN {
	Time=1; Gen=2; Verb=3; Path=4; Spath=5; Mode=6; Uid=7; Gid=8; Mtime=9; Len=10
	loadtime()
} $Time < time {
	next
} $Time == time && $Gen <= gen {
	next
}  $Verb~/[acdm]/ {
	print $Verb, $Path, $Spath, $Mode, $Uid, $Gid, $Mtime, $Len
} $Spath == "-" {
	$Spath = $Path
} $Verb~/a/ && $Mode~/d/ {
	mkdir(new "/" $Path)
} $Verb~/[ac]/ && $Mode!~/d/	{
	cp(old "/" $Spath, new "/" $Path)
} $Verb~/[acm]/ {
	chmod(new "/" $Path, $Mode)
} $Verb~/d/ && $Mode~/d/ {
	rmdir(new "/" $Path)
} $Verb~/d/ && $Mode!~/d/ {
	rm(new "/" $Path)
} !errors {
	time = $Time; gen = $Gen
} END {
	savetime()
}

function mkdir(path) {
	x("mkdir -p " path)
}

function rm(path) {
	x("rm -f " path)
}

function rmdir(path) {
	x("rmdir " path)
}

function cp(old, new) {
	x("test ! -e " old " || cp " old " " new " || test ! -e " old)
}

function chmod(path, mode) {
	sub("d", "", mode)
	x("test ! -e " path " || chmod " mode " " path)
}

function loadtime() {
	if(timefile != "" && getline <timefile > 0){
		time = int($1)
		gen = int($2)
	}
}

function savetime() {
	if(timefile != "")
		x("echo " time " " gen " >" timefile)
}

function x(s) {
	# DBG:  system("echo + \"" s "\" >&2")
	if(system(s) != 0) {
		errors++
		exit(1)
	}
}
' # <log
