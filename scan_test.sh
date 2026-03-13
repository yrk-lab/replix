#!/bin/sh
# {Watch ./scan_test.sh}
#
# "coverage": {grep '^func' scan.sh |sort; grep '^[ 	]*[a-z][a-z]* test[a-z]' $% |sort}

tests=`sed -n '/^test.*[(][)].*{/ s/[^A-Za-z0-9_]*//gp' $0`
fns=`sed '/^function /,/^}/!d' scan.sh`
fns=$fns'
	function fatal(s, testname) {
		testname = ENVIRON["testname"]
		if(name != "")
			testname = testname ": " name
		print "fail " testname ": " s |"cat >&2"
		exit(1)
	}
	function must(v, targ, comment) {
		if(v == targ)
			return
		fatal(sprintf("%s: expected \"%s\", got \"%s\"", comment, targ, v))
	}
	function args1(a)	{ return sprintf("(\"%s\")", a) }
	function args2(a, b)	{ return sprintf("(\"%s\", \"%s\")", a, b) }
'

testmany() {
	expandme='$once' \
	once=bug \
	awk '
	BEGIN {
		testpathjoin()
		testlvl()
		testexpand()
		testdbstat()
		testdbpop()
		testdbstr()
		teststat()
		testloaddb()
	} END {
		cleanteststat()
		cleanuptestloaddb()
	}
	function testpathjoin(_, a, b, targ, i) {
		ENVIRON["testname"] = "testpathjoin"
		a[++n] = "a";	b[n] = "b";	targ[n] = "a/b"
		a[++n] = "a/b";	b[n] = "c";	targ[n] = "a/b/c"
		a[++n] = "a";	b[n] = "";	targ[n] = "a"
		a[++n] = "";	b[n] = "b";	targ[n] = "b"
		a[++n] = "";	b[n] = "";	targ[n] = ""
		for(i in targ) {
			out = pathjoin(a[i], b[i])
			must(out, targ[i], args2(a[i], b[i]))
		}
	}
	function testlvl(_, tc, n, out, targ, i) {
		ENVIRON["testname"] = "testlvl"
		tc[++n] = "X"; targ[n] = 0
		tc[++n] = "\tX"; targ[n] = 1
		tc[++n] = "\t\tX"; targ[n] = 2
		tc[++n] = "\t\t\tX"; targ[n] = 3
		tc[++n] = "\t\t\tX\t"; targ[n] = 3
		for(i in targ) {
			out = lvl(tc[i])
			must(out, targ[i], args1(tc[i]))
		}
	}
	function testexpand(_, tc, n, targ, i, out) {
		ENVIRON["testname"] = "testexpand"
		tc[++n] = "$expandme" ; targ[n] = "$once"
		tc[++n] = "once"; targ[n] = "once"
		for(i in tc) {
			out = expand(tc[i])
			must(out, targ[i], args1(tc[i]))
		}
	}
	function testdbstat(_, d, s) {
		ENVIRON["testname"] = "testdbstat"
		db["x"] = "x d755 sys adm 1234567 12"
		d["foo"]
		dbstat("x", d)
		if("foo" in d) fatal("dir[foo] should have been gone")
		must(d["mode"], "d755", "dir[mode]")
		must(d["uid"], "sys", "dir[uid]")
		must(d["gid"], "adm", "dir[gid]")
		must(d["mtime"], 1234567, "dir[mtime]")
		must(d["length"], 12, "dir[length]")
		s = dbstr("x", d)
		must(s, db["x"], "dbstr() to be symmetric to dbstat()")
	}
	function testdbpop(_, d, s) {
		ENVIRON["testname"] = "testdbpop"
		db["0"] = "0 d755 sys adm 1234567 123"
		dbpop("0", d)
		if("0" in db) fatal("db[0] should have been gone")
		must(d["mode"], "d755", "dir[mode]")
		must(d["uid"], "sys", "dir[uid]")
		must(d["gid"], "adm", "dir[gid]")
		must(d["mtime"], 1234567, "dir[mtime]")
		must(d["length"], 123, "dir[length]")
	}
	function testdbstr(_, d, s) {
		ENVIRON["testname"] = "testdbstr"
		d["mode"] = "d755"
		d["uid"] = "sys"
		d["gid"] = "adm"
		d["mtime"] = 1234567
		d["length"] = 12
		s = dbstr("x", d, "a")
		must(s, "x d755 sys adm 1234567 12", "[a]")
		s = dbstr("xm", d, "m")
		must(s, "xm d755 sys adm 1234567 12", "[m]")
		s = dbstr("xc", d, "c")
		must(s, "xc d755 sys adm 1234567 12", "[c]")
		s = dbstr("xd", d, "d")
		must(s, "xd REMOVED sys adm 1234567 12", "[d]")
	}
	function teststat(_, wd, r, d) {
		ENVIRON["testname"] = "teststat"
		wd = "/tmp/replica.teststat"
		system("mkdir " wd)

		name = "dir"
		d["junk"]
		r = stat(wd, d)
		must(r, 0, "result of stat() call")
		if(d["mode"] !~ /d/) fatal(".: dir[mode]: expected to match /d/, got " d["mode"])
		if("junk" in d) fatal("dir[junk] should have been gone")

		name = "file+mode"
		system("echo x >  " wd "/a")
		system("chmod 644 " wd "/a")
		r = stat(wd "/a", d)
		must(r, 0, "result of stat() call")
		must(d["mode"], "644", "./a: dir[mode]")
		must(d["length"], 2, "./a: dir[length]")
		mustnot(d["mtime"], 0, "./a: dir[mtime]")
		mustnot(d["gid"], "", "./a: dir[gid]")

		name = "missing file"
		d["junk"]
		silentstat = 1
		r = stat(wd "/missing", d)
		must(r, -1, "result of stat() call")
		if("junk" in d) fatal("dir[junk] should have been gone")
		silentstat = 0
	}
	function cleanteststat() {
		system("rm -rf /tmp/replica.teststat")
	}
	function teststat_bsd() {
		# covered by teststat()
	}
	function testmodestr_bsd() {
		# covered by teststat()
	}
	function testloaddb(_, i, n, wd, dbpath) {
		ENVIRON["testname"] = "testloaddb"
		name = "no dbpath"
		delete db
		dbn = 0
		loaddb("")
		for(i in db) ++n
		must(dbn, 0, "dbn")
		must(int(n), 0, "n")

		name = "valid db"
		wd = "/tmp/replica.testloaddb"
		system("mkdir " wd)
		dbpath = wd "/t.db"
		print "p d755 test sys 1234567890 2" >>dbpath
		print "p/q 640 test sys 1234567890 44" >>dbpath
		print "p/q 644 test sys 1234567891 48" >>dbpath
		print "s d755 test sys 1234567892 3" >>dbpath
		print "s REMOVED test sys 1234567890 3" >>dbpath
		close(dbpath)
		loaddb(dbpath)
		must(db["p"], "p d755 test sys 1234567890 2", "db[p]")
		must(db["p/q"], "p/q 644 test sys 1234567891 48", "db[p/q]")
		must("s" in db, 0, "s in db while REMOVED")
		must(dbn, 5, "dbn")
		must(dbq[5], "s", "dbq[5]")
		must(dbq[4], "s", "dbq[4]")
		must(dbq[3], "p/q", "dbq[3]")
		must(dbq[2], "p/q", "dbq[2]")
		must(dbq[1], "p", "dbq[1]")
	}
	function testdbput() {
		# covered by testloaddb()
	}
	function cleanuptestloaddb() {
		system("rm -rf /tmp/replica.testloaddb")
	}
	function mustnot(v, targ, comment) {
		if(v != targ) return
		fatal(sprintf("%s: expected anything but %s, got %s\n", comment, targ, v))
	}
	'"$fns"
}

testwalk() {
	fns1=`echo "$fns" | sed '/^function update[(]/,/^}/d'`
	expandme='$once' \
	once=bad \
	awk '
	BEGIN {
		wd = "/tmp/replica." ENVIRON["testname"]
		system("mkdir " wd)
		root = wd
		testwalk_noupdate()
		testwalk_add()
		testwalk_meta()
		testwalk_metadir()
		testwalk_metaproto()
		testwalk_conlen()
		testwalk_contime()
		testwalk_del()
		testwalk_star()
		testwalk_plus()
		testwalk_expand()
		testwalk_missing()
		testwalk_serverpath()
		testdels()
	} END {
		system("rm -r " wd)
	}
	# mock
	function update(verb, path, serverpath, d,	n) {
		n = ++called["n"]
		called[n,"verb"] = verb
		called[n,"path"] = path
		called[n,"serverpath"] = serverpath
		called[n,"mode"] = d["mode"]
		called[n,"uid"] = d["uid"]
		called[n,"gid"] = d["gid"]
		called[n,"mtime"] = d["mtime"]
		called[n,"length"] = d["length"]
		return d["mode"]~/d/
	}
	function mustcalled(n, item, targ) {
		must(called[n,item], targ, item " in update() call " n)
	}
	function testwalk_noupdate() {
		name = "noupdate"
		f = "f1"
		system("touch " wd "/" f)
		system("chmod 644 " wd "/" f)
		stat(wd "/" f, d)
		db[f] = dbstr(f, d)
		called["n"] = 0
		walk(stk, 0, f)
		must(called["n"], 0, "times update() called")
		must(f in db, 0, "db record")
	}
	function testwalk_add() {
		name = "addition [a]"
		f = "f2"
		system("echo a > " wd "/" f)
		system("chmod 644 " wd "/" f)
		called["n"] = 0
		walk(stk, 0, f, "", "", "", f)
		must(called["n"], 1, "times update() called")
		mustcalled(1, "path", f)
		mustcalled(1, "verb", "a")
		mustcalled(1, "serverpath", f)
		mustcalled(1, "mode", "644")
		mustcalled(1, "length", "2")
		must(f in db, false, "db record")
	}
	function testwalk_meta() {
		name = "metadata change [m], new mode on file"
		f = "f3"
		system("touch " wd "/" f)
		system("chmod 644 " wd "/" f)
		stat(wd "/" f, d)
		d["mode"] = "111"
		db[f] = dbstr(f, d)
		called["n"] = 0
		walk(stk, 0, f)
		must(called["n"], 1, "times update() called")
		mustcalled(1, "path", f)
		mustcalled(1, "serverpath", "")
		mustcalled(1, "verb", "m")
		mustcalled(1, "mode", "644")
		must(f in db, false, "db record")
	}
	function testwalk_metadir() {
		name = "metadata change [m], new mode on dir"
		f = "d3"
		system("mkdir " wd "/" f)
		system("chmod 755 " wd "/" f)
		stat(wd "/" f, d)
		d["mode"] = "d111"
		# mtime and length should be ignored for directories
		d["mtime"] = 999
		d["length"] = 999
		db[f] = dbstr(f, d)
		called["n"] = 0
		walk(stk, 0, f)
		must(called["n"], 1, "times update() called")
		mustcalled(1, "path", f)
		mustcalled(1, "serverpath", "")
		mustcalled(1, "verb", "m")
		mustcalled(1, "mode", "d755")
		must(f in db, false, "db record")
	}
	function testwalk_metaproto() {
		name = "metadata change [m], new mode in proto"
		f = "f4"
		system("touch " wd "/" f)
		system("chmod 644 " wd "/" f)
		stat(wd "/" f, d)
		db[f] = dbstr(f, d)
		called["n"] = 0
		walk(stk, 0, f, "111")
		must(called["n"], 1, "times update() called")
		mustcalled(1, "path", f)
		mustcalled(1, "verb", "m")
		mustcalled(1, "mode", "111")
		must(f in db, false, "db record")
	}
	function testwalk_conlen() {
		name = "content change [c], lengths differ"
		f = "f5"
		system("touch " wd "/" f)
		system("chmod 644 " wd "/" f)
		stat(wd "/" f, d)
		d["length"] = 9
		db[f] = dbstr(f, d)
		called["n"] = 0
		walk(stk, 0, f)
		must(called["n"], 1, "times update() called")
		mustcalled(1, "path", f)
		mustcalled(1, "verb", "c")
		mustcalled(1, "length", 0)
		must(f in db, false, "db record")
	}
	function testwalk_contime() {
		name = "content change [c], mtimes differ"
		f = "f6"
		system("touch " wd "/" f)
		system("chmod 644 " wd "/" f)
		stat(wd "/" f, d)
		omtime = d["mtime"]
		d["mtime"] = 1
		db[f] = dbstr(f, d)
		called["n"] = 0
		walk(stk, 0, f)
		must(called["n"], 1, "times update() called")
		mustcalled(1, "path", f)
		must(called[1,"verb"], "c", "verb in update() call")
		must(called[1,"mtime"], omtime, "mtime in update() call")
		must(f in db, false, "db record")
	}
	function testwalk_del() {
		name = "deletion [d]"
		db[dbq[++dbn] = f="x1"] = f " 644 sys adm 1234567 33"
		db[dbq[++dbn] = f="x2"] = f " 644 sys adm 1111 44"
		db[dbq[++dbn] = f="x2"] = f " 644 sys adm 1111 55"
		called["n"] = 0
		dels()
		must(called["n"], 2, "times update() called")
		mustcalled(1, "path", "x2")
		mustcalled(1, "verb", "d")
		mustcalled(1, "mode", "644")
		mustcalled(1, "mtime", "1111")
		mustcalled(1, "length", 55)
		mustcalled(2, "path", "x1")
		mustcalled(2, "verb", "d")
		mustcalled(2, "mode", "644")
		mustcalled(2, "mtime", "1234567")
		mustcalled(2, "length", 33)
	}
	function testwalk_star() {
		name = "star [*]"
		system("mkdir -p " wd "/d1/p")
		system("touch " wd "/d1/p/x")
		system("touch " wd "/d1/q")
		called["n"] = 0
		walk(stk, 0, "d1")
		walk(stk, 1, "*")
		must(called["n"], 3, "times update() called")
		mustcalled(1, "verb", "a")
		mustcalled(1, "path", "d1")
		mustcalled(2, "path", "d1/p")
		mustcalled(3, "path", "d1/q")
	}
	function testwalk_plus() {
		name = "recurse [+]"
		system("mkdir -p " wd "/d2/a")
		system("touch " wd "/d2/a/p")
		system("mkdir -p " wd "/d2/b")
		system("touch " wd "/d2/b/p")
		system("touch " wd "/d2/b/q")
		system("touch " wd "/d2/b/\"s p a c e s\"") # should skip these
		system("mkdir -p " wd "/d2/b/z")
		system("touch " wd "/d2/b/z/a")
		called["n"] = 0
		walk(stk, 0, "d2")
		walk(stk, 1, "+")
		must(called["n"], 8, "times update() called")
		mustcalled(1, "path", "d2")
		mustcalled(2, "path", "d2/a")
		mustcalled(3, "path", "d2/a/p")
		mustcalled(4, "path", "d2/b")
		mustcalled(5, "path", "d2/b/p")
		mustcalled(6, "path", "d2/b/q")
		mustcalled(7, "path", "d2/b/z")
		mustcalled(8, "path", "d2/b/z/a")
	}
	function testwalk_expand() {
		name = "envvar [$]"
		f = ENVIRON["expandme"]
		system("mkdir -p " wd "/" f "/x")
		called["n"] = 0
		walk(stk, 0, "$expandme")
		walk(stk, 1, "x")
		must(called["n"], 2, "times update() called")
		mustcalled(1, "path", f)
		mustcalled(1, "verb", "a")
		mustcalled(2, "path", f "/x")
		must(f in db, false, "db record")
	}
	function testwalk_missing() {
		name = "missing file"
		called["n"] = 0
		silentstat = 1
		walk(stk, 0, "missing")
		must(called["n"]+0, 0, "times update() called")
		silentstat = 0
	}
	function testwalk_serverpath() {
		name = "serverpath"
		system("echo klmn > " wd "/fsp")
		called["n"] = 0
		walk(stk, 0, "fcopy", "600", "cetus", "adm", "fsp")
		must(called["n"], 1, "times update() called")
		mustcalled(1, "path", "fcopy")
		mustcalled(1, "verb", "a")
		mustcalled(1, "serverpath", "fsp")
		mustcalled(1, "length", 5)
		mustcalled(1, "mode", "600")
		mustcalled(1, "uid", "cetus")
		mustcalled(1, "gid", "adm")
		must(f in db, false, "db record")
	}
	function testdels() {
		# covered by testwalk_del
	}
	'"$fns1"
}

testdels() {
	true - tested in testwalk
}

testwalk1() {
	true - tested in testwalk
}

testwalkdir() {
	true - tested in testwalk
}

testupdate() {
	wd=/tmp/replica.${testname?}
	mkdir $wd
	awk -v 'wd='$wd >$wd/u.log <$wd/u.log '
	BEGIN {
		dbpath = wd "/u.db"
		time = 123
		delete d

		db["A"] = "A 644 sys adm 1111 99"
		db["B"] = "B d755 bunny sys 2222 88"
		db["C"] = "C 640 root staff 3333 77"
		db["D"] = "D 440 nobody world 4444 66"

		dbstat("A", d)
		update("a", "A",  "fs/a", d)
		if(getline q <dbpath <= 0)	fatal("short read from db file")
		if(getline p <= 0)	fatal("short read from captured log ")
		# path mode uid gid mtime length
		must(q, "A 644 sys adm 1111 99", "db line 1")
		# time gen verb path serverpath mode uid gid mtime length
		must(p, "123 0 a A fs/a 644 sys adm 1111 99", "log line 1")

		dbstat("B", d)
		update("m", "B",  "-", d)
		if(getline q <dbpath <= 0)	fatal("short read from db file")
		if(getline p <= 0)	fatal("short read from captured log ")
		must(q, "B d755 bunny sys 2222 88", "db line 2")
		must(p, "123 1 m B - d755 bunny sys 2222 88", "log line 2")

		dbstat("C", d)
		update("c", "C",  "", d)
		if(getline q <dbpath <= 0)	fatal("short read from db file")
		if(getline p <= 0)	fatal("short read from captured log ")
		must(q, "C 640 root staff 3333 77", "db line 3")
		must(p, "123 2 c C - 640 root staff 3333 77", "log line 3")

		dbstat("D", d)
		update("d", "D",  "", d)
		if(getline q <dbpath <= 0)	fatal("short read from db file")
		if(getline p <= 0)	fatal("short read from captured log ")
		must(q, "D REMOVED nobody world 4444 66", "db line 4")
		must(p, "123 3 d D - 440 nobody world 4444 66", "log line 4")
	} END {
		system("rm -r " wd)
	}
	'"$fns"
}

testcli() {
	wd=/tmp/replica.${testname?}
	rm -rf "$wd"
	mkdir $wd $wd/r $wd/r/1
	echo hi > $wd/r/a
	echo 123 > $wd/r/1/b
	echo "+" | ./scan.sh $wd/r > $wd/u.log || exit
	awk <$wd/u.log '
	BEGIN {
		Time=1; Gen=2; Verb=3; Path=4; Spath=5; Mode=6; Uid=7; Gid=8; Mtime=9; Len=10
	} $Gen < gen {
		fatal("gen is not increasing")
	} NR > 1{
		must($Time, time, "consistent time")
	} {
		must(NF, 10, "number of fields")
		must($Verb, "a", "verb")
		time = $Time; gen = $Gen
	} NR==1 {
		name = "[1]"
		must($Path, "1", "path")
		must($Mode~/d/, 1, "mode " $Mode "~/d/")
	} NR==2 {
		name = "[2]"
		must($Path, "1/b", "path")
		must($Mode~/d/, 0, "mode " $Mode "~/d/")
	} NR==3 {
		name = "[3]"
		must($Path, "a", "path")
		must($Mode~/d/, 0, "mode " $Mode "~/d/")
	} END {
		must(NR, 3, "number of log lines")
	}	
	'"$fns" &&
	rm -r "$wd"
	ret=$?
	if test $ret != 0
	then
		echo '* produced output:'
		cat $wd/u.log
	fi
	return $ret
}

testcliproto() {
	wd=/tmp/replica.${testname?}
	rm -rf "$wd"
	mkdir $wd $wd/r $wd/r/1
	echo hi > $wd/r/a
	echo 123 > $wd/r/1/b
	{
		echo '1'
		echo '	+'
	} | ./scan.sh $wd/r > $wd/u.log || exit
	awk <$wd/u.log '
	BEGIN {
		Time=1; Gen=2; Verb=3; Path=4; Spath=5; Mode=6; Uid=7; Gid=8; Mtime=9; Len=10
	} NR==1 {
		name = "[1]"
		must($Path, "1", "path")
		must($Mode~/d/, 1, "mode " $Mode "~/d/")
	} NR==2 {
		name = "[2]"
		must($Path, "1/b", "path")
		must($Mode~/d/, 0, "mode " $Mode "~/d/")
	} END {
		must(NR, 2, "number of log lines")
	}	
	'"$fns" &&
	rm -r "$wd"
	ret=$?
	if test $ret != 0
	then
		echo '* produced output:'
		cat $wd/u.log
	fi
	return $ret
}

testclidb() {
	wd=/tmp/replica.${testname?}
	ret=0
	rm -rf "$wd"
	mkdir $wd $wd/r $wd/r/1
	echo hi > $wd/r/a
	echo 123 > $wd/r/1/b
	rm -f $wd/u.db
	echo "+" | ./scan.sh $wd/r $wd/u.db >$wd/u.log || exit
	awk -v name='run1' <$wd/u.db 'END { must(NR, 3, "number of db lines") }'"$fns" || ret=$?
	awk -v name='run1' <$wd/u.log 'END { must(NR, 3, "number of log lines") }'"$fns" || ret=$?

	echo "+" | ./scan.sh $wd/r $wd/u.db >>$wd/u.log || exit
	awk -v name='run2' <$wd/u.db 'END { must(NR, 3, "number of db lines") }'"$fns" || ret=$?
	awk -v name='run2' <$wd/u.log 'END { must(NR, 3, "number of log lines") }'"$fns" || ret=$?

	echo mod >> $wd/r/a
	echo new > $wd/r/cc
	echo "+" | ./scan.sh $wd/r $wd/u.db >>$wd/u.log || exit
	awk -v name='run3' <$wd/u.db 'END { must(NR, 5, "number of db lines") }'"$fns" || ret=$?
	awk -v name='run3' <$wd/u.log '
	BEGIN {
		Time=1; Gen=2; Verb=3; Path=4; Spath=5; Mode=6; Uid=7; Gid=8; Mtime=9; Len=10
	} NR==4 {
		name = "[4]"
		must($Path, "a", "path")
		must($Verb, "c", "verb")
	} NR==5 {
		name = "[5]"
		must($Path, "cc", "path")
		must($Verb, "a", "verb")
	}
	END { must(NR, 5, "number of log lines") }
	'"$fns" || ret=$?
	
	if test $ret != 0
	then
		echo '* produced output:'
		cat $wd/u.log
		echo
		echo '* produced db:'
		cat $wd/u.db
	else
		rm -r "$wd"
	fi
	return $ret
}

p=''
for t in $tests
do	testname=$t $t &
	p=$p' '$!
done

err=''
for i in $p
do wait $i || err=$?
done
test -z $err && echo ok
