#!/bin/bash
#
# Script to start LVS DR real server.
# description: LVS DR real server
#

. /etc/rc.d/init.d/functions

# Set $VIP
VIP=192.168.40.150

case "$1" in
start)
        # Start LVS-DR real server on this machine.
        echo -e '\e[32;1m'"Start LVS-DR real server on this machine."'\e[0m'
        /sbin/ifconfig lo down
        /sbin/ifconfig lo up
        echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore
        echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce
        echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore
        echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce
        /sbin/ifconfig lo:0 $VIP broadcast $VIP netmask 255.255.255.255 up
        /sbin/route add -host $VIP dev lo:0
;;

stop)
        # Stop LVS-DR real server loopback device(s).
        echo -e '\e[32;1m'"Stop LVS-DR real server loopback device(s)."'\e[0m'
        /sbin/ifconfig lo:0 down
        echo 0 > /proc/sys/net/ipv4/conf/lo/arp_ignore
        echo 0 > /proc/sys/net/ipv4/conf/lo/arp_announce
        echo 0 > /proc/sys/net/ipv4/conf/all/arp_ignore
        echo 0 > /proc/sys/net/ipv4/conf/all/arp_announce
;;

status)
        # Status of LVS-DR real server.
        echo -e '\e[32;1m'"Status of LVS-DR real server."'\e[0m'
        islothere=`/sbin/ifconfig lo:0 | grep $VIP`
        isrothere=`netstat -rn | grep "lo:0" | grep $VIP`
        if [ ! "$islothere" -o ! "isrothere" ];then
            # Either the route or the lo:0 device
            # not found.
            echo "LVS-DR real server Stopped."
        else
            echo "LVS-DR real server Running."
        fi
;;

*)
        # Invalid entry.
        echo -e '\e[32;1m'"Invalid entry."'\e[0m'
        echo -e '\e[32;1m'"$0: Usage: $0 {start|status|stop}"'\e[0m'
        exit 1
;;

esac