#!/system/bin/sh
#
# m30s_tee.sh - bring up Samsung's key services in recovery.
#
# TWRP's decryption code needs a keymaster 4.0 and a gatekeeper 1.0 HAL, and
# both need Samsung's secure-world daemon (tzdaemon) and its trusted apps.
# None of these files are in this recovery image. They are copied at boot
# from the phone's own vendor partition, so they always match the installed
# firmware (and no Samsung file is distributed with the recovery).
#
# Started by init (service m30s-tee). Reports through properties:
#   m30s.tee.prep   done            files are in place, init starts tzdaemon
#   m30s.tee.ready  1 | 0           TWRP waits for this before it decrypts
#   m30s.tee.error  <text>          why it is 0
# Log: /tmp/m30s_tee.log
#
# R and M30S_TEST_PATH are only set when the script is tested on a PC.
R="${M30S_TEST_ROOT:-}"
export TMPDIR="$R/tmp"
export PATH="${M30S_TEST_PATH:-/system/bin:/sbin}"
LOG="$R/tmp/m30s_tee.log"
exec >>"$LOG" 2>&1

BY="$R/dev/block/platform/13520000.ufs/by-name"
MV="$R/tee/mnt/vendor"
MS="$R/tee/mnt/system"
VNDK="$R/tee/vndk/lib64"
LIST="$R/tee/copied.txt"
RV="$R/vendor"
EFS="$R/mnt/vendor/efs"
IWT="$R/dev/socket/iwt"
MOUNTS="${M30S_TEST_MOUNTS:-/proc/mounts}"

now() { cut -d' ' -f1 /proc/uptime 2>/dev/null; }
say() { echo "[$(now)] $*"; }
fail() {
	say "FAILED: $*"
	umount "$MV" 2>/dev/null
	umount "$MS" 2>/dev/null
	setprop m30s.tee.error "$(echo "$*" | cut -c1-80)"
	setprop m30s.tee.ready 0
	exit 1
}
# wait_prop NAME VALUE TENTHS
wait_prop() {
	n=0
	while [ "$n" -lt "$3" ]; do
		[ "$(getprop "$1")" = "$2" ] && return 0
		n=$((n + 1))
		sleep 0.1
	done
	return 1
}
prop_from() { grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2-; }

say "===== m30s_tee start, selinux: $(getenforce 2>/dev/null) ====="

# ------------------------------------------------------------------ mount
mkdir -p "$MV" "$MS" "$VNDK" "$RV/bin/hw" "$RV/lib64/hw"
n=0
while [ ! -e "$BY/vendor" ] && [ "$n" -lt 100 ]; do n=$((n + 1)); sleep 0.1; done
[ -e "$BY/vendor" ] || fail "no vendor partition at $BY/vendor"

mount -t ext4 -o ro "$BY/vendor" "$MV" || fail "cannot mount the vendor partition"
[ -f "$MV/bin/tzdaemon" ] || fail "vendor has no bin/tzdaemon (not a stock-based ROM?)"
KM=$(ls "$MV"/bin/hw/android.hardware.keymaster@4.*-service* 2>/dev/null | head -n 1)
GK=$(ls "$MV"/bin/hw/android.hardware.gatekeeper@1.0-service* 2>/dev/null | head -n 1)
[ -n "$KM" ] || fail "vendor has no keymaster 4.x HIDL service"
[ -n "$GK" ] || fail "vendor has no gatekeeper 1.0 HIDL service"
say "keymaster: ${KM#$MV}  gatekeeper: ${GK#$MV}"

SYS=""
if mount -t ext4 -o ro "$BY/system" "$MS" 2>/dev/null; then
	if [ -f "$MS/system/build.prop" ]; then SYS="$MS/system"; elif [ -f "$MS/build.prop" ]; then SYS="$MS"; fi
fi
say "system: ${SYS:-not mounted}"

# ------------------------------------------------------------------- copy
# Programs go to the same path under /vendor in the ramdisk. Vendor libraries
# too. VNDK libraries (the system-side libraries built for this vendor) go to
# a folder of their own.
VNDK_SRC=""
for d in "$SYS/apex/com.android.vndk.current/lib64" "$SYS/lib64/vndk-sp-30" "$SYS/lib64/vndk-30" \
	"$SYS/lib64/vndk-sp-29" "$SYS/lib64/vndk-29" "$SYS/lib64/vndk-sp-28" "$SYS/lib64/vndk-28"; do
	[ -n "$SYS" ] && [ -d "$d" ] && VNDK_SRC="$VNDK_SRC $d"
done
say "vndk folders:${VNDK_SRC:- none (the recovery's own libraries will be used)}"

: > "$LIST"
TODO="$R/tee/todo.txt"
: > "$TODO"
for f in "$MV/bin/tzdaemon" "$MV/bin/tzts_daemon" "$KM" "$GK" \
	"$MV"/lib64/hw/android.hardware.gatekeeper@1.0-impl*.so \
	"$MV"/lib64/hw/gatekeeper.*.so "$MV"/lib64/hw/keystore.*.so \
	"$MV"/lib64/android.hardware.gatekeeper@1.0-impl*.so ; do
	[ -f "$f" ] && echo "V ${f#$MV}" >> "$TODO"
done

count=0
while :; do
	next=""
	while read -r kind path; do
		grep -q -x -F "$kind $path" "$LIST" || { next="$kind $path"; break; }
	done < "$TODO"
	[ -n "$next" ] || break
	echo "$next" >> "$LIST"
	kind="${next%% *}"
	path="${next#* }"
	if [ "$kind" = V ]; then
		src="$MV$path"
		dst="$RV$path"
	else
		src="$path"
		dst="$VNDK/${path##*/}"
	fi
	mkdir -p "${dst%/*}"
	cp "$src" "$dst" || { say "copy failed: $src"; continue; }
	chmod 0755 "$dst"
	count=$((count + 1))
	[ "$count" -ge 300 ] && { say "stopped copying at 300 files"; break; }
	for name in $(grep -a -o -E '[A-Za-z0-9_.@+-]+\.so' "$src" 2>/dev/null | sort -u); do
		found=0
		for d in /lib64 /lib64/hw; do
			if [ -f "$MV$d/$name" ]; then
				found=1
				grep -q -x -F "V $d/$name" "$TODO" || echo "V $d/$name" >> "$TODO"
			fi
		done
		[ "$found" = 1 ] && continue
		for d in $VNDK_SRC; do
			if [ -f "$d/$name" ]; then
				grep -q -x -F "S $d/$name" "$TODO" || echo "S $d/$name" >> "$TODO"
				break
			fi
		done
	done
done
say "copied $count files (list: $LIST)"

# trusted apps: tzdaemon loads them from /vendor/tee
if [ -d "$MV/tee" ]; then
	cp -R "$MV/tee" "$RV/" && say "trusted apps: $(ls "$RV/tee" | wc -l) entries in /vendor/tee"
else
	say "vendor has no tee folder"
fi

# ------------------------------------------------------------------ props
# The keymaster HAL and its trusted app look at these. They must say what the
# installed firmware says, not what this recovery was built as.
if [ -n "$SYS" ]; then
	for pair in "ro.build.version.release:ro.build.version.release" \
		"ro.build.version.security_patch:ro.build.version.security_patch" \
		"ro.build.fingerprint:ro.system.build.fingerprint" \
		"ro.build.type:ro.system.build.type" \
		"ro.build.tags:ro.system.build.tags"; do
		v=$(prop_from "$SYS/build.prop" "${pair##*:}")
		[ -n "$v" ] && resetprop "${pair%%:*}" "$v"
	done
fi
v=$(prop_from "$MV/build.prop" ro.vendor.build.security_patch)
[ -n "$v" ] && resetprop ro.vendor.build.security_patch "$v"
say "firmware: release=$(getprop ro.build.version.release) patch=$(getprop ro.build.version.security_patch) type=$(getprop ro.build.type)"
say "firmware: $(getprop ro.build.fingerprint)"

umount "$MS" 2>/dev/null
umount "$MV" || say "could not unmount $MV"

# --------------------------------------------------- what tzdaemon expects
# Same as the stock teegris_v3.rc. The secure storage of the trusted apps is
# under /mnt/vendor/efs/tee, so efs has to be mounted read-write, as it is in
# a normal boot.
mkdir -p "$EFS"
if ! grep -q ' /mnt/vendor/efs ' "$MOUNTS"; then
	mount -t ext4 -o noatime,nosuid,nodev "$BY/efs" "$EFS" || fail "cannot mount efs"
fi
if [ ! -d "$EFS/tee" ]; then
	mkdir "$EFS/tee"
	chown system:system "$EFS/tee"
	chmod 0700 "$EFS/tee"
fi
mkdir -p "$IWT/ca"
chown system:system "$IWT" "$IWT/ca"
chmod 0770 "$IWT" "$IWT/ca"

setprop vendor.tzdaemon ""
setprop m30s.tee.prep done
say "prep done, init starts tzdaemon"

# ------------------------------------------------------------------ watch
wait_prop vendor.tzdaemon Ready 250 || fail "tzdaemon did not report Ready (state: $(getprop init.svc.tz_service))"
say "tzdaemon: Ready"

wait_prop init.svc.vendor.keymaster-4-0 running 150 || fail "keymaster service is not running (state: $(getprop init.svc.vendor.keymaster-4-0))"
wait_prop init.svc.vendor.gatekeeper-1-0 running 100 || say "gatekeeper service is not running (state: $(getprop init.svc.vendor.gatekeeper-1-0))"
sleep 2
[ "$(getprop init.svc.vendor.keymaster-4-0)" = running ] || fail "keymaster service died right after start (see logcat)"
say "keymaster: $(getprop init.svc.vendor.keymaster-4-0)  gatekeeper: $(getprop init.svc.vendor.gatekeeper-1-0)"

# keystore2 was started before the keymaster HAL existed. Restart it so it
# talks to the real one, then make sure it stays up.
setprop ctl.restart keystore2
n=0
ok=0
last=""
while [ "$n" -lt 30 ]; do
	sleep 1
	n=$((n + 1))
	pid=$(pidof keystore2)
	if [ -n "$pid" ] && [ "$pid" = "$last" ]; then
		ok=$((ok + 1))
		[ "$ok" -ge 3 ] && break
	else
		ok=0
	fi
	last="$pid"
done
[ "$ok" -ge 3 ] || fail "keystore2 does not stay up (it cannot reach the keymaster HAL)"
say "keystore2: up (pid $last)"

setprop m30s.tee.ready 1
say "===== ready ====="
exit 0
