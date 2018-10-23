#!/bin/bash
#
# LVS script for VS/DR
#

. /etc/rc.d/init.d/functions

# Set $VIP $RIPs...
VIP=10.0.0.10
RIP1=10.0.0.13
RIP2=10.0.0.14
PORT=80

# 
case "$1" in
start) 
    # Setup VIP on which interface ? 
      /sbin/ifconfig eth0:0 $VIP broadcast $VIP netmask 255.255.255.255 up
      /sbin/route add -host $VIP dev eth0:0

    # Since this is the Director we must be able to forward packets
      echo 1 > /proc/sys/net/ipv4/ip_forward

    # Clear all iptables rules.
      /sbin/iptables -F
    # Reset iptables counters.
      /sbin/iptables -Z
    # Clear all ipvsadm rules/services.
      /sbin/ipvsadm -C

    # Add an IP virtual service for VIP 192.168.0.219 port 80
    # In this recipe, we will use the round-robin scheduling method.
    # In production, however, you should use a weighted, dynamic scheduling method.
      /sbin/ipvsadm -A -t $VIP:80 -s wlc
    # Now direct packets for this VIP to
    # the real server IP (RIP) inside the cluster
      /sbin/ipvsadm -a -t $VIP:80 -r $RIP1 -g -w 1
      /sbin/ipvsadm -a -t $VIP:80 -r $RIP2 -g -w 2
      /bin/touch /var/lock/subsys/ipvsadm &> /dev/null
;;

stop)
    # Stop forwarding packets
      echo 0 > /proc/sys/net/ipv4/ip_forward
    # Reset ipvsadm
      /sbin/ipvsadm -C
    # Bring down the VIP interface
      /sbin/ifconfig eth0:1 down
      /sbin/route del $VIP                              
      /bin/rm -f /var/lock/subsys/ipvsadm                                                                   
      echo "ipvs is stopped..."
;;

status)
    if [ ! -e /var/lock/subsys/ipvsadm ]; then
      echo "ipvsadm is stopped ..."
    else
      echo "ipvs is running ..."
      ipvsadm -L -n
    fi
;;

*)
    echo "Usage: $0 {start|stop|status}"
;;

esac
