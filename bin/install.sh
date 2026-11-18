#!/system/bin/sh
# install.sh —— 载荷安装 + 网页服务拉起（幂等）

MODDIR=/data/adb/modules/mirrorapps
BASE=/data/local/mirrorapps
PAYLOAD_VER=2
PORT=8898
LOG=$BASE/install.log

if [ "$MODDIR" != "/data/adb/modules/mirrorapps" ] || [ "$BASE" != "/data/local/mirrorapps" ]; then
    echo "install aborted: unexpected paths" > /dev/kmsg 2>/dev/null
    exit 0
fi

mkdir -p $BASE/bin $BASE/www/cgi-bin 2>/dev/null
echo "=== $(date '+%F %T') install start ===" >> $LOG

# busybox
BB=""
for c in $MODDIR/bin/busybox /data/adb/ksu/bin/busybox /system/bin/busybox; do
    if [ -x "$c" ]; then BB="$c"; break; fi
done

# 载荷
if [ ! -d "$MODDIR/www" ]; then
    echo "ERROR: payload missing" >> $LOG
    exit 0
fi
if [ "$(cat $BASE/.payload_ver 2>/dev/null)" != "$PAYLOAD_VER" ]; then
    cp -rf $MODDIR/bin/. $BASE/bin/ 2>>$LOG
    cp -rf $MODDIR/www/. $BASE/www/ 2>>$LOG
    chmod 755 $BASE $BASE/bin $BASE/www $BASE/www/cgi-bin 2>/dev/null
    chmod 755 $BASE/bin/busybox $BASE/bin/sqlite3 $BASE/www/cgi-bin/status $BASE/www/cgi-bin/ctl 2>/dev/null
    chmod 644 $BASE/www/index.html 2>/dev/null
    if [ -f "$BASE/www/index.html" ] && [ -f "$BASE/www/cgi-bin/status" ]; then
        echo "$PAYLOAD_VER" > $BASE/.payload_ver
        echo "payload refreshed" >> $LOG
    else
        echo "WARN: payload incomplete" >> $LOG
    fi
fi

# httpd
if [ -n "$BB" ]; then
    if ! $BB netstat -ltn 2>/dev/null | grep -q "127.0.0.1:$PORT"; then
        setsid $BB httpd -p 127.0.0.1:$PORT -h $BASE/www < /dev/null > /dev/null 2>&1 &
        echo "httpd started on $PORT" >> $LOG
    else
        echo "httpd already listening" >> $LOG
    fi
else
    echo "WARN: no busybox" >> $LOG
fi

echo "=== install done ===" >> $LOG
exit 0
