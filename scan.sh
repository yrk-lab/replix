#!/bin/sh
# usage: scan.sh [root [dbpath]] <proto
# see also:
#  • apply.sh
#  • replica/updatedb in http://9p.io/magic/man2html/8/replica
#  • proto(1) in AIX: https://www.ibm.com/docs/en/aix/7.3?topic=p-proto-command
#
# test while hacking:
#	Watch ./scan_test.sh

exec awk -v "root=$1" -v "dbpath=$2" -v "time=`date +%s`" '
BEGIN {
	loaddb(dbpath)
} /^[\t ]*(#.*)?$/ {
	next
} {
	walk(stk, lvl($0), $1, $2, $3, $4, $5)
} END {
	dels()
}

function walk(stk, n, wname, mode, uid, gid, serverpath) {
	if(wname == "+" || wname == "*") {
		walkdir(stk[n], (wname == "+"))
	} else {
		stk[++n] = pathjoin(stk[n], expand(wname))
		walk1(stk[n], serverpath, mode, uid, gid)
	}
}

function walkdir(path, deep, _, cmd, s, p, isdir) {
	cmd = "ls " q(pathjoin(root, path))
	while(cmd | getline s > 0) {
		if(s ~ /[ \t]/)
			continue
		p = pathjoin(path, s)
		isdir = walk1(p)
		if(isdir && deep)
			walkdir(p, deep)
	}
	close(cmd)
}

function walk1(path, serverpath, mode, uid, gid, _, p, d, od) {
	p = path
	if(serverpath != "" && serverpath != "-") p = serverpath
	if(stat(pathjoin(root, p), d) < 0)
		return mode ~ /d/
	if(mode != "" && mode != "-")	d["mode"] = mode
	if(uid != "" && uid != "-")	d["uid"] = uid
	if(gid != "" && gid != "-")	d["gid"] = gid
	if(!dbpop(path, od))
		return update("a", path, serverpath, d)
	if(d["mode"] !~ /d/ && (d["mtime"] != od["mtime"] || d["length"] != od["length"]))
		return update("c", path, serverpath, d)
	if(d["mode"] != od["mode"] || d["gid"] != od["gid"])
		return update("m", path, serverpath, d)
	return d["mode"] ~ /d/
}

function dels(_, i, path, d) {
	for(i = dbn; i > 0; i--)
		if(dbpop(path=dbq[i], d))
			update("d", path, "-", d)
}

function update(verb, path, serverpath, d) {
	if(serverpath == "")	serverpath = "-"
	print time, gen++, verb, path, serverpath, \
		d["mode"], d["uid"], d["gid"], d["mtime"], d["length"]
	if(dbpath != "")
		print dbstr(path, d, verb) >> dbpath
	system("")  # fflush
	return d["mode"] ~ /d/
}

function dbstr(path, d, verb, _, mode) {
	mode = (verb=="d"? "REMOVED" : d["mode"])
	return path " " mode " " d["uid"] " " d["gid"] " " d["mtime"] " " d["length"]
}

function dbput(path, mode, str) {
	db[path] = str
	dbq[++dbn] = path
	if(mode == "REMOVED")
		delete db[path]
}

function loaddb(dbpath) {
	if(dbpath == "")
		return
	while(getline<dbpath > 0)
		dbput($1, $2, $0)
	close(dbpath)
}

function dbpop(path, d, _, r){
	if(r = dbstat(path, d))
		delete db[path]
	return r
}

function dbstat(path, d, _, f) {
	delete d
	if(!(path in db))
		return 0
	split(db[path], f)
	d["mode"] = f[2]
	d["uid"] = f[3]
	d["gid"] = f[4]
	d["mtime"] = int(f[5])
	d["length"] = int(f[6])
	return 1
}

function stat(path, d) {
	return stat_bsd(path, d)
}

function stat_bsd(path, d, _, cmd, s,  f, ret, flag) {
	delete d
	ret = -1
	flag = silentstat? "q" : ""	# noise-manage the tests
	cmd = "stat -" flag "f %.6Op/%Su/%Sg/%Um/%Uz " q(path)
	while(cmd | getline s > 0) {
		if(split(s, f, "/") != 5)
			continue
		d["mode"] = modestr_bsd(f[1])
		d["uid"] = f[2]
		d["gid"] = f[3]
		d["mtime"] = int(f[4])
		d["length"] = int(f[5])
		ret = 0
	}
	close(cmd)
	return ret
}

function modestr_bsd(s, _, r) {
	if(s ~ /^.[4]/)
		r = "d"
	return r substr(s, 4, 3)
}

function q(s,    apos, bsl) {
	apos = sprintf("%c", 39)
	bsl  = sprintf("%c", 92)
	gsub(apos, apos bsl apos apos, s)
	return apos s apos
}

function pathjoin(a, b, _, sep) {
	if(a != "" && b != "")
		sep = "/"
	return a sep b
}

function lvl(s) {
	match(s, "^\t*")  # count hard tabs only, by design
	return RLENGTH
}

function expand(s, _, v) {
	if(s !~ /^[$]/)
		return s
	v = substr(s, 2, length(s)-1)
	return ENVIRON[v]
}

' # <proto
