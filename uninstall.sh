#!/system/bin/sh
BASE=/data/local/mirrorapps
if [ "$BASE" = "/data/local/mirrorapps" ] && [ -d "$BASE" ]; then
    for p in $(ps -A -o PID,ARGS 2>/dev/null | grep "httpd -p 127.0.0.1:8898" | grep -v grep | awk "{print \$1}"); do kill $p 2>/dev/null; done
    sleep 1
    rm -rf "$BASE"
fi
exit 0
