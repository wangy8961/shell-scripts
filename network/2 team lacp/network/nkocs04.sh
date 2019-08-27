#!/bin/bash
# Version: 1.0
# Email: wangy8961@163.com
# Description: nikoyo_team_v2 和 nikoyo_configure_ip_v2第一版v1，只能执行脚本后，人工交互逐步输入各参数值，第二版v2，既支持交互输入参数，也支持执行脚本时在命令行指定相关参数
# @Author: wangy
# @Date:   2017-03-06 11:52:51
# @Last Modified by:   wangy
# @Last Modified time: 2017-07-06 10:58:16


#-------------------------------------------------------------------------------
# 删除原配置
#-------------------------------------------------------------------------------
nmcli c s | awk '{print $1}' | xargs nmcli c delete
nmcli c r
nmcli c s
nmcli d s

systemctl restart network


#-------------------------------------------------------------------------------
# 创建Team、VLAN，配置静态IP
#-------------------------------------------------------------------------------
./nikoyo_team.sh --team_device team0 --team_type lacp --team_ports "eno1,enp2s0f0"
./nikoyo_team.sh --team_device team1 --team_type lacp --team_ports "eno2,enp2s0f1"

sleep 3
# Ceph Cluster Network
./nikoyo_configure_ip.sh --vlan_device team0 --vlan_name cnaddr --vlan_id 400
# Ceph Public Network
./nikoyo_configure_ip.sh --vlan_device team0 --vlan_name pnaddr --vlan_id 401
# 文件存储 VLAN
./nikoyo_configure_ip.sh --vlan_device team1 --vlan_name nasaddr --vlan_id 4
# 对象存储 VLAN
./nikoyo_configure_ip.sh --vlan_device team1 --vlan_name s3addr --vlan_id 5
# iSCSI VLAN
./nikoyo_configure_ip.sh --vlan_device team1 --vlan_name iscsiaddr --vlan_id 402


sleep 3
# Ceph Cluster Network
./nikoyo_configure_ip.sh --connection cnaddr --bootproto static --address 172.16.5.4 --netmask 24
# Ceph Public Network
./nikoyo_configure_ip.sh --connection pnaddr --bootproto static --address 172.16.6.4 --netmask 24
# 文件存储 DIP
./nikoyo_configure_ip.sh --connection nasaddr --bootproto static --address 192.168.40.9 --netmask 24 --gateway 192.168.40.25 --dns 192.168.0.1
# 对象存储 DIP
./nikoyo_configure_ip.sh --connection s3addr --bootproto static --address 172.18.0.9 --netmask 24
# iSCSI 服务IP
./nikoyo_configure_ip.sh --connection iscsiaddr --bootproto static --address 172.16.7.2 --netmask 24

ip addr show

systemctl restart network

clear
