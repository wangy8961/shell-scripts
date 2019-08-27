#!/bin/bash
# Version: 2.0
# Email: wangy8961@163.com
# Description: Nikoyo 赞存分布式存储 配置完Team后分配IP等信息
# @Author: wangy
# @Date:   2017-03-20 21:36:41
# @Last Modified by:   wangy
# @Last Modified time: 2017-05-08 15:37:19

#-------------------------------------------------------------------------------
# Shell脚本基础设置
#-------------------------------------------------------------------------------

# set -e
# set -x

# unset any variable which system may be using
unset tcreset

# clear the screen
clear

# Define Variable for resetting teminal color
tcreset=$(tput sgr0)


#-------------------------------------------------------------------------------
# 使用帮助
#-------------------------------------------------------------------------------
function usage() {
    cat << EOF
Usage:
    The tool can help you to configure network ip address automatically.
    Please run such as:
        ./nikoyo_configure_ip_v2.sh --vlan_device teamdata --vlan_name cnaddr --vlan_id 100
        ./nikoyo_configure_ip_v2.sh --vlan_device teamdata --vlan_name pnaddr --vlan_id 101
        ./nikoyo_configure_ip_v2.sh --connection teamservice-master --bootproto DHCP
        ./nikoyo_configure_ip_v2.sh --connection pnaddr --bootproto static --address 172.18.0.11 --netmask 24

Options:
  --help | -h
    Print usage information.
  --vlan_device | -d
    Set the device name of vlan, eg. teamdata
  --vlan_name | -n
    Set the name of vlan, eg. cnaddr
  --vlan_id | -i
    Set the id of vlan, eg. 100
  --connection | -c
    Set the name of connection, eg. teamservice-master
  --bootproto | -b
    Set the BOOTPROTO, eg. DHCP/Static
  --address | -a
    Set the static ipv4 address, eg. 192.168.40.161
  --netmask | -m
    Set the netmask bits, eg. 24
  --gateway | -g
    Set the default gateway, eg. 192.168.40.25
  --dns | -s
    Set dns, eg. 192.168.0.1
  --domain | -o
    Set the dns-search domain, eg. madmalls.com
EOF
    exit 0
}

# 获取命令行参数值
while [ $# -gt 0 ]; do
    case "$1" in
        --help | -h) usage ;;
        --vlan_device | -d) shift; vlan_device=$1 ;;
        --vlan_name | -n) shift; vlan_name=$1 ;;
        --vlan_id | -i) shift; vlan_id=$1 ;;
        --connection | -c) shift; connection=$1 ;;
        --bootproto | -b) shift; bootproto=$1 ;;
        --address | -a) shift; address=$1 ;;
        --netmask | -m) shift; netmask=$1 ;;
        --gateway | -g) shift; gateway=$1 ;;
        --dns | -s) shift; dns=$1 ;;
        --domain | -o) shift; domain=$1 ;;
        *) shift ;;
    esac
    shift
done


#-------------------------------------------------------------------------------
# 功能函数
#-------------------------------------------------------------------------------

# 创建VLAN connection
function create_vlan() {
    echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
    echo -e '\E[32;1m'"Add vlan" ${tcreset}
    echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

    # 显示当前网络设备名称
    echo ""
    nmcli device status
    echo ""

    # 选择设备名称
    while true; do
        while [[ -z ${vlan_device} ]]; do
            echo -n -e '\E[32;1m'"Please choose the name of device, eg. teamdata : " ${tcreset}
            read vlan_device
            echo ""
        done
        # 是否有效的网络设备
        nmcli device show | grep "\<${vlan_device}\>" > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            unset vlan_device
            echo -e '\E[31;1m'"Invalid device !" ${tcreset}
            echo ""
        else
            break
        fi
    done

    # 提供 VLAN 名称
    while [[ -z ${vlan_name} ]]; do
        echo -n -e '\E[32;1m'"Please set the name of VLAN connection, eg. cnaddr : " ${tcreset}
        read vlan_name
        echo ""
    done

    # 提供 VLAN ID
    while [[ -z ${vlan_id} ]]; do
        echo -n -e '\E[32;1m'"Please set the number of VLAN, eg. 100 : " ${tcreset}
        read vlan_id
        echo ""
    done

    # 提示将要新增哪个VLAN
    echo ""
    echo -e '\E[31;1m'"Will add the VLAN connection: ${vlan_name}" ${tcreset}
    echo ""
    sleep 3

    # 创建 VLAN
    nmcli connection add type vlan con-name ${vlan_name} dev ${vlan_device} id ${vlan_id}
    # 禁用其ipv4和ipv6
    nmcli connection modify ${vlan_name} ipv4.method disabled ipv6.method ignore

    # 成功退出
    echo ""
    echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
    echo -e '\E[32;1m'"Success" ${tcreset}
    echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
    echo ""

    exit 0
}


#-------------------------------------------------------------------------------
# main 主程序执行部分
#-------------------------------------------------------------------------------
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Begin configuring ip" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

#-------------------------------------------------------------------------------
# 是否创建VLAN
#-------------------------------------------------------------------------------

if [[ -n "${vlan_device}" || -n "${vlan_name}" || -n "${vlan_id}" ]]; then
    # 命令行指定了参数的话，直接创建VLAN
    create_vlan
else
    # 命令行没有指定参数，询问是否创建VLAN
    echo -n -e '\E[31;1m'"Do you want to add VLAN (Y/N)? Auto choice 'N' after 3 second : " ${tcreset}
    # 超时3秒后，自动选择默认值N
    read -t 3 choice_vlan
    choice_vlan=${choice_vlan:="N"}
    echo ""

    # 判断选择值，是否继续执行; 转换为小写字母
    choice_vlan=$(echo ${choice_vlan} | tr '[:upper:]' '[:lower:]')
    if [[ "${choice_vlan}" == "y" ]] ; then
        create_vlan
    fi
fi


#-------------------------------------------------------------------------------
# 配置网络连接（IP）
#-------------------------------------------------------------------------------
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Modify connection" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

# 显示当前的网络连接名称
echo ""
nmcli connection show
echo ""


#-------------------------------------------------------------------------------
# 参数设置
#-------------------------------------------------------------------------------

# 指定网络连接名称
while true; do
    while [[ -z ${connection} ]]; do
        echo -n -e '\E[32;1m'"Please choose the name of network connection : " ${tcreset}
        read connection
        echo ""
    done
    # 是否有效的网络连接
    nmcli connection show | grep "\<${connection}\>" > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        unset connection
        echo -e '\E[31;1m'"Invalid connection !" ${tcreset}
        echo ""
    else
        break
    fi
done

# 提示将要配置哪个网络连接
echo ""
echo -e '\E[31;1m'"Will modify the connection: ${connection}" ${tcreset}
echo ""

# 配置网络的启动方式： DHCP 或 静态IP
while [[ -z ${bootproto} ]]; do
    echo -n -e '\E[32;1m'"Please choose BOOTPROTO, eg. DHCP/Static : " ${tcreset}
    read bootproto
    echo ""
done
# 全部转换为小写字母
bootproto=$(echo ${bootproto} | tr '[:upper:]' '[:lower:]')
while [[ "${bootproto}" != "dhcp" && "${bootproto}" != "static" ]]; do
    echo -n -e '\E[31m'"Incorrect choice! Must be one of (eg. DHCP OR Static): " ${tcreset}
    read bootproto
    echo ""
done


#-------------------------------------------------------------------------------
# 判断是DHCP还是静态IP
#-------------------------------------------------------------------------------

# DHCP
if [[ "${bootproto}" == "dhcp" ]] ; then
    nmcli connection modify ${connection} ipv6.method ignore ipv4.method auto ipv4.may-fail false
# Static IP
else
    # 指定IP地址
    while [[ -z ${address} ]]; do
        echo -n -e '\E[32;1m'"Please set static ipv4, eg. 192.168.40.161 : " ${tcreset}
        read address
        echo ""
    done

    # 指定netmask掩码位数
    while [[ -z ${netmask} ]]; do
        echo -n -e '\E[32;1m'"Please set netmask, eg. 24 : " ${tcreset}
        read netmask
        echo ""
    done

    # (非必须)指定网关, 有网关时，指定此网络连接为服务器上的默认网关
    if [[ -z ${gateway} ]] ; then
        echo -n -e '\E[32;1m'"Please set default gateway, eg. 192.168.40.25 : " ${tcreset}
        read -t 10 gateway
    fi
    # 等待用户输入，再次判断是否为空
    if [[ -z ${gateway} ]] ; then
        echo "NULL"
        gateway_str="ipv4.never-default true"
    else
        gateway_str="ipv4.gateway ${gateway}"
    fi
    echo ""

    # (非必须)指定DNS
    if [[ -z ${dns} ]] ; then
        echo -n -e '\E[32;1m'"Please set DNS, eg. 192.168.0.1 : " ${tcreset}
        read -t 10 dns
    fi
    # 等待用户输入，再次判断是否为空
    if [[ -z ${dns} ]] ; then
        echo "NULL"
    else
        dns_str="ipv4.dns ${dns}"
    fi
    echo ""

    # (非必须)指定Domain
    if [[ -z ${domain} ]] ; then
        echo -n -e '\E[32;1m'"Please set Domain, eg. madmalls.com : " ${tcreset}
        read -t 10 domain
    fi
    # 等待用户输入，再次判断是否为空
    if [[ -z ${domain} ]] ; then
        echo "NULL"
    else
        domain_str="ipv4.dns-search ${domain}"
    fi
    echo ""


    # 拼接成最终修改网络连接的命令
    nmcli connection modify ${connection} ipv6.method ignore ipv4.address ${address}/${netmask} ${gateway_str} ${dns_str} ${domain_str} ipv4.method manual ipv4.may-fail false
fi

# 再次激活该接口前，NetworkManger 不会意识到对 ifcfg 的手动更改
device=$(nmcli connection show | grep "\<${connection}\>" | awk '{print $NF}')
if [[ `nmcli connection show | grep "\<${connection}\>" | awk '{print $(NF-1)}'` == "team" ]]; then
    # 如果是修改team master connection，则要重新激活整个team 而不是team master
    nmcli connection down ${device}-port1
    sleep 1
    nmcli connection down ${device}-port2
    sleep 1
    nmcli connection down ${device}-master
    sleep 3
    echo ""

    nmcli connection up ${device}-port1
    sleep 1
    nmcli connection up ${device}-port2
    sleep 1
    echo ""
else
    nmcli connection down ${connection}
    sleep 1
    echo ""

    nmcli connection up ${connection}
    sleep 1
    echo ""
fi

# 并输出IP信息
ip addr show ${device}
echo ""

# 成功退出
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Success" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo ""

exit 0
