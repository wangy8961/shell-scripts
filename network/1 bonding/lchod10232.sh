#!/bin/bash

# 1. 删除默认的网络连接
nmcli c delete em1
nmcli c delete em2
nmcli c delete em3
nmcli c delete em4
nmcli c delete p4p1
nmcli c delete p4p2
nmcli c delete p6p1
nmcli c delete p6p2


# 2. 配置Ceph集群网络：Cluster Network 和 Public Network
# 将两个万兆网口 p4p1 和 p6p1 创建为 Bonding，模式为 active-backup，即 mode=1
# 2.1 创建 bonding master 接口
nmcli con add type bond con-name bond0 ifname bond0 bond.options "mode=1,miimon=100"
# 2.2 创建 bonding slaves 接口
nmcli con add type ethernet con-name bond0-slave-p4p1 ifname p4p1 master bond0
nmcli con add type ethernet con-name bond0-slave-p6p1 ifname p6p1 master bond0
# 2.3 激活 bonding （启动 slave 连接会自动启动 master 连接）
nmcli con up bond0-slave-p4p1
nmcli con up bond0-slave-p6p1
# 2.4 由于 bond0 上不会直接配置 IP 而是创建两个VLAN，所以需要禁用它的 IPv4 和 IPv6 功能
nmcli con modify bond0 ipv4.method disabled ipv6.method ignore
# 2.5 在 bond0 这个设备上创建两个VLAN，用于 Ceph 的复制网络和数据网络
nmcli con add type vlan con-name cnaddr dev bond0 id 3900 ip4 172.254.1.3/24
nmcli con add type vlan con-name pnaddr dev bond0 id 3901 ip4 172.254.2.3/24
# 2.6 禁用VLAN cnaddr 和 pnaddr 的 IPv6 功能
nmcli con modify cnaddr ipv6.method ignore
nmcli con modify pnaddr ipv6.method ignore


# 3. 配置对象存储服务网络
# 将两个万兆网口 p4p2 和 p6p2 创建为 Bonding，模式为 active-backup，即 mode=1
# 3.1 创建 bonding master 接口
nmcli con add type bond con-name bond1 ifname bond1 bond.options "mode=1,miimon=100"
# 3.2 创建 bonding slaves 接口
nmcli con add type ethernet con-name bond1-slave-p4p2 ifname p4p2 master bond1
nmcli con add type ethernet con-name bond1-slave-p6p2 ifname p6p2 master bond1
# 3.3 激活 bonding （启动 slave 连接会自动启动 master 连接）
nmcli con up bond1-slave-p4p2
nmcli con up bond1-slave-p6p2
# 3.4 需要直接在 bond1 上配置 IP，所以只需要禁用它的 IPv6 功能
nmcli con modify bond1 ipv6.method ignore
# 3.5 在 bond1 上为对象存储服务网络设置静态 IPv4 地址
nmcli con modify bond1 ipv4.address 10.156.10.232/24 ipv4.gateway 10.156.10.1 ipv4.method manual


# 4. 重启网络
systemctl restart network
cat /proc/net/bonding/bond0
cat /proc/net/bonding/bond1
