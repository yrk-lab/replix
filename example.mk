fs=mycloudcpu
mnt=/n/${fs}

s=${HOME}
proto=${s}/src/replix/example.proto
db=${s}/replica/home.db
log=${s}/replica/home.log
c=${mnt}/home/${USER}/term
time=${c}/sync.time

put:: ${c}
	${HOME}/src/replix/scan.sh ${s} ${db} <${proto} >> ${log} && \
	${HOME}/src/replix/apply.sh ${s} ${c} ${time} <${log}
