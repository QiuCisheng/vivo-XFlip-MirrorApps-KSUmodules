#!/system/bin/sh
# 非阻塞：新会话后台执行，立刻退出
if [ -x /system/bin/setsid ]; then
    setsid sh /data/adb/modules/mirrorapps/bin/install.sh < /dev/null > /dev/null 2>&1 &
else
    sh /data/adb/modules/mirrorapps/bin/install.sh < /dev/null > /dev/null 2>&1 &
fi
exit 0
