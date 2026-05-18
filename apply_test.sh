#!/bin/sh
# {Watch ./apply_test.sh}

tests=`sed -n '/^test.*[(][)].*{/ s/[^A-Za-z0-9_]*//gp' $0`
fns=`sed '/^function /,/^}/!d' apply.sh`

testq() {
	awk '
	BEGIN {
		testq()
	}
	function testq(    apos) {
		apos = sprintf("%c", 39)
		check("abc")
		check("")
		check("a" apos "b")
		check("a;b")
		check("$HOME")
		check("a\\b")
		check(apos apos)
	}
	function check(s,    got, quoted, cmd, tmp, apos) {
		apos = sprintf("%c", 39)
		tmp = "/tmp/" ENVIRON["testname"] ".tmp"
		quoted = q(s)
		cmd = "printf " apos "%s" apos " " quoted " >" tmp
		system(cmd)
		getline got < tmp
		close(tmp)
		system("rm -f " tmp)
		if (got != s) {
			printf "FAIL q(%s): roundtrip got [%s]\n", s, got | "cat >&2"
			exit 1
		}
	}
	'"$fns"
}

testapplyafresh() {
	r=/tmp/replica.${testname?} o=$r/old n=$r/new
	rm -rf $r
	mkdir $r $o $o/dir1 $n
	echo t > $o/file1 || exit
	rm -f $r/time
	{
		echo '1648215000 0 a dir0 - d755 user staff 1648208130 0'
		echo '1648215000 1 a dir1 - d755 user staff 1648208130 0'
		echo '1648215000 2 a file1 - 644 user staff 1648208130 2'
		echo '1648215000 3 a cp1 file1 644 user staff 1648208130 2'
	} >$r/log
	sh ./apply.sh $o $n $r/time <$r/log >$r/out || exit
	(
		set -x
		test -e $n/dir0 || exit
		test -d $n/dir1 || exit
		test -f $n/file1 || exit
		test -w $n/file1 || exit
		cmp $n/cp1 $o/file1 || exit
		nr=`wc -l <$r/out` && test "$nr" -eq 4 || exit
		time=`cat $r/time` && test "$time" = '1648215000 3' || exit
	) 2>$r/err || { cat $r/err; exit 1; }
	rm -r "$r"
}

testapplyresumed() {
	r=/tmp/replica.${testname?} o=$r/old n=$r/new
	rm -rf $r
	mkdir $r $o $o/dir1 $n
	touch $o/file1 $o/dir1/file2 || exit
	echo 1648215015 0 > $r/time
	{
		echo '1648215015 0 a shadowed - d755 user staff 1648208130 0'
		echo '1648215015 1 a dir1 - d755 user staff 1648208130 0'
		echo '1648215015 2 a file1 - 644 user staff 1648208130 0'
		echo '1648215015 3 a dir1/file2 - 444 user staff 1648208130 0'
		echo '1648215015 4 a dir2 - d755 user staff 1648208130 0'
	} >$r/log
	sh ./apply.sh $o $n $r/time <$r/log >$r/out || exit
	(
		set -x
		test ! -e $n/shadowed || exit
		test -d $n/dir1 || exit
		test -f $n/file1 || exit
		test -w $n/file1 || exit
		test -f $n/dir1/file2 || exit
		test ! -w $n/dir1/file2 || exit
		test -d $n/dir2 || exit
		time=`cat $r/time` && test "$time" = '1648215015 4' || exit
	) 2>$r/err || { cat $r/err; exit 1; }

	{
		echo '1648216000 0 m dir1/file2 - d644 user staff 1648208130 0'
		echo '1648216000 1 d file1 - 744 user staff 1648208130 0'
		echo '1648216000 2 d dir2 - d744 user staff 1648208130 0'
	} >>$r/log
	sh ./apply.sh $o $n $r/time <$r/log >$r/out || exit
	(
		set -x
		test -w $n/dir1/file2 || exit
		test '!' -e $n/file1 || exit
		test '!' -e $n/dir2 || exit
		nr=`wc -l < $r/out` && test "$nr" -eq 3 || exit
		time=`cat $r/time` && test "$time" = '1648216000 2' || exit
	) 2>$r/err || { cat $r/err; exit 1; }
}

testapplydeleted() {
	r=/tmp/replica.${testname?} o=$r/old n=$r/new
	rm -rf $r
	mkdir $r $o $n
	rm -f $r/time
	{
		echo '1648217000 0 a file1 - 644 user staff 1648208130 2'
		echo '1648217001 0 d file1 - 644 user staff 1648208130 2'
	} >$r/log
	sh ./apply.sh $o $n $r/time <$r/log >$r/out || exit
	(
		set -x
		test ! -e $n/file1 || exit
		time=`cat $r/time` && test "$time" = '1648217001 0' || exit
	) 2>$r/err || { cat $r/err; exit 1; }
	rm -r "$r"
}


testapplyq() {
	r=/tmp/replica.${testname?} o=$r/old n=$r/new
	rm -rf $r
	mkdir $r $o $n
	printf 'hello\n' > "$o/a'b"
	printf 'hello\n' > "$o/c;d"
	{
		echo "1648230000 0 a dir'x - d755 user staff 1648208130 0"
		echo "1648230000 1 a a'b - 644 user staff 1648208130 6"
		echo "1648230000 2 a c;d - 644 user staff 1648208130 6"
		echo "1648230000 3 m a'b - 500 user staff 1648208130 6"
		echo "1648230000 4 d c;d - 644 user staff 1648208130 6"
		echo "1648230000 5 d dir'x - d755 user staff 1648208130 0"
	} >$r/log
	sh ./apply.sh $o $n $r/time <$r/log >$r/out || exit
	(
		set -x
		test ! -e "$n/dir'x" || exit
		test -f "$n/a'b" || exit
		test ! -w "$n/a'b" || exit
		test ! -e "$n/c;d" || exit
		nr=`wc -l <$r/out` && test "$nr" -eq 6 || exit
		time=`cat $r/time` && test "$time" = '1648230000 5' || exit
	) 2>$r/err || { cat $r/err; exit 1; }
	rm -r "$r"
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
