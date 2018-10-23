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
nmcli c delete cnaddr
nmcli c delete pnaddr
nmcli c delete teamservice-master
nmcli c delete teamservice-port1
nmcli c delete teamservice-port2
nmcli c delete teamdata-master
nmcli c delete teamdata-port1
nmcli c delete teamdata-port2
nmcli c delete teamheart-master
nmcli c delete teamheart-port1
nmcli c delete teamheart-port2
nmcli c delete eno1
nmcli c delete eno2
nmcli c delete enp2s0f0
nmcli c delete enp2s0f1
nmcli c delete ens7f0
nmcli c delete ens7f1
nmcli c r
nmcli c s
nmcli d s

systemctl restart network


#-------------------------------------------------------------------------------
# 创建Team、VLAN，配置静态IP
#-------------------------------------------------------------------------------
./centos7_create_team.sh --team_device teamservice --team_type lacp --team_ports "eno1,enp2s0f0"
./centos7_create_team.sh --team_device teamdata --team_type lacp --team_ports "eno2,enp2s0f1"
./centos7_create_team.sh --team_device teamheart --team_type activebackup --team_ports "ens7f0,ens7f1"

sleep 3
./centos7_configure_ip.sh --vlan_device teamdata --vlan_name cnaddr --vlan_id 100
./centos7_configure_ip.sh --vlan_device teamdata --vlan_name pnaddr --vlan_id 101

sleep 3
#./centos7_configure_ip.sh --connection teamservice-master --bootproto static --address 192.168.40.161 --netmask 24 --gateway 192.168.40.25 --dns 192.168.0.1 --domain madmalls.com
./centos7_configure_ip.sh --connection teamservice-master --bootproto static --address 192.168.40.161 --netmask 24 --gateway 192.168.40.25 --dns 192.168.0.1
./centos7_configure_ip.sh --connection cnaddr --bootproto static --address 172.16.0.1 --netmask 24
./centos7_configure_ip.sh --connection pnaddr --bootproto static --address 172.18.0.1 --netmask 24
./centos7_configure_ip.sh --connection teamheart-master --bootproto static --address 10.10.10.1 --netmask 24

ip addr show

systemctl restart network

clear

#teamnl teamservice ports
#teamdctl teamservice state -v
#nmcli -p connection show teamservice-master

#teamnl teamdata ports
#teamdctl teamdata state -v
#nmcli -p connection show teamdata-master

#teamnl teamheart ports
#teamdctl teamheart state -v
#nmcli -p connection show teamheart-master
