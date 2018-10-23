#!/bin/bash
# Version: 2.0
# Email: wangy8961@163.com
# Description: Nikoyo 赞存分布式存储Team配置脚本
# @Author: wangy
# @Date:   2017-03-06 11:52:51
# @Last Modified by:   wangy
# @Last Modified time: 2017-05-08 16:21:15

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
    The tool can help you to configure network team automatically.
    Please run such as './centos7_create_team.sh --team_device teamservice --team_type lacp --team_ports "eno1,eno2"'

Options:
  --help | -h
    Print usage information.
  --team_device | -d
    Set the name of team, eg. teamservice
  --team_type | -t
    Set the type of team, eg. lacp, activebackup
  --team_ports | -p
    Set the ports of team, separated by commas, only support two ports, eg. eno1,eno2
EOF
    exit 0
}

# 获取命令行参数值
while [ $# -gt 0 ]; do
    case "$1" in
        --help | -h) usage ;;
        --team_device | -d) shift; team_device=$1 ;;
        --team_type | -t) shift; team_type=$1 ;;
        --team_ports | -p) shift; team_ports=$1 ;;
        *) shift ;;
    esac
    shift
done


#-------------------------------------------------------------------------------
# 功能函数
#-------------------------------------------------------------------------------

# 列出当前服务器上未绑定Team组的网络设备的速率
function team_nic_speed() {
    # 初始化
    [[ -f /tmp/device.txt ]] && rm -f /tmp/device.txt
    [[ -f /tmp/device_speed.txt ]] && rm -f /tmp/device_speed.txt

    # 查找已连接的ethernet网络设备, 且未加入Team组
    nmcli device status | awk '$2 ~ /ethernet/ && $0 !~ /team/ {print $1}' > /tmp/device.txt

    # 判断/tmp/device.txt是否为空
    if [[ ! -s /tmp/device.txt ]]; then
        echo -e '\E[31;1m'"No matched devices, please use 'nmcli device status' to check out!" ${tcreset}
        echo ""
        exit 1
    else
        echo -e '\E[31;1m'"List of devices and its speed which have not joined team:" ${tcreset}
        echo ""

        # 循环网络设备，判断属于万兆网络接口(10Gb/s)还是千兆网络接口(1Gb/s)
        cat /tmp/device.txt | while read line; do
            # 是否10Gb/s ?
            ethtool ${line} | grep '10000baseT/Full' > /dev/null
            if [ $? == 0 ]; then
                printf "%-20s %-20s" ${line} "10Gb/s" &>> /tmp/device_speed.txt
                echo '' &>> /tmp/device_speed.txt
            else
                # 是否1Gb/s ?
                ethtool ${line} | grep '1000baseT/Full' > /dev/null
                if [ $? == 0 ]; then
                    printf "%-20s %-20s" ${line} "1Gb/s" &>> /tmp/device_speed.txt
                    echo '' &>> /tmp/device_speed.txt
                fi
            fi
        done

        # 排序
        cat /tmp/device_speed.txt | sort -k 2
    fi
}


# 检查 选择的各网络接口 合法性
function check_team_ports() {
    # 初始化合法性标志位
    count=0

    # 转换为小写字母
    team_ports=$(echo ${team_ports} | tr '[:upper:]' '[:lower:]')
    # 将${team_ports}以逗号分隔的字符串中，所有的逗号替换为空格，变成数组
    team_ports=${team_ports//,/ }   # 字符串替换
    team_ports_arr=(${team_ports})  # 字符串转换为数组

    # 判断是否只指定了一个端口
    if [[ ${#team_ports_arr[@]} -eq 1 ]] ; then
        echo -e '\E[31;1m'"The ports of team must greater than one !" ${tcreset}
        (( count++ ))
    fi

    # 网络接口1和接口2
    port1=${team_ports_arr[0]}
    port2=${team_ports_arr[1]}

    # 判断端口名是否相同
    if [[ "${port1}" == "${port2}" ]] ; then
        echo -e '\E[31;1m'"The name of two ports is the same!" ${tcreset}
        (( count++ ))
    fi

    # 判断端口名是否全部在可选端口列表中
    for port in ${team_ports} ; do
        check_out=$(awk -v p=${port} '{if($1==p) print $1}' /tmp/device.txt)
        if [[ -z ${check_out} ]] ; then
            echo -e '\E[31;1m'"The name of ${port} is not in the effective list!" ${tcreset}
            (( count++ ))
        fi
    done

    echo ""
}


# 配置Team
# $1: team_device
# $2: team_type
# $3: port1
# $4: port2
function create_team() {
    # 初始化
    [[ -f /tmp/team_lacp.conf ]] && rm -f /tmp/team_lacp.conf
    [[ -f /tmp/team_activebackup.conf ]] && rm -f /tmp/team_activebackup.conf

    # 提示将要配置哪个网络连接
    echo ""
    echo -e '\E[31;1m'"Will add the team: ${team_device} ${team_type}" ${tcreset}
    echo ""

    # 添加Team Master网络连接
    nmcli connection add type team con-name ${team_device}-master ifname ${team_device}
    # 禁用其ipv4和ipv6
    nmcli connection modify ${team_device}-master ipv4.method disabled ipv6.method ignore

    # 添加Team Ports各子网络连接
    nmcli connection add type team-slave con-name ${team_device}-port1 ifname ${port1} master ${team_device}
    nmcli connection add type team-slave con-name ${team_device}-port2 ifname ${port2} master ${team_device}

    # 指定runner和watches
    if [[ "${team_type}" = "lacp" ]] ; then
        # 创建包含runner和watches的配置文件
        cat >> /tmp/team_lacp.conf << EOF
{
    "device":               "${team_device}",
    "runner": {
            "name": "lacp",
            "active": true,
            "fast_rate": true,
            "tx_hash": ["eth", "ipv4", "ipv6"]
    },
    "link_watch":           {"name": "ethtool"},
    "ports":                {"${port1}": {}, "${port2}": {}}
}
EOF
        # 为Team指定包含runner和watches的配置文件
        nmcli connection modify ${team_device}-master team.config '/tmp/team_lacp.conf'

    elif [[ "${team_type}" = "activebackup" ]]; then
        # 创建配置文件
        cat >> /tmp/team_activebackup.conf << EOF
{
        "device":       "${team_device}",
        "runner":       {"name": "activebackup"},
        "link_watch":   {"name": "ethtool"},
        "ports":        {
                "${port1}": {
                        "prio": -10,
                        "sticky": true
                },
                "${port2}": {
                        "prio": 100
                }
        }
}
EOF
        # 为Team指定包含runner和watches的配置文件
        nmcli connection modify ${team_device}-master team.config '/tmp/team_activebackup.conf'

    fi


    #---------------------------------------------------------------------------
    # 让配置生效:
    # nmcli工具是NetworkManager的配置管理工具，会直接修改网络配置文件，
    # 但是NetworkManager不会实时监控配置信息的变化，
    # 需要重载网络配置文件并再次启用网络连接
    #---------------------------------------------------------------------------
    echo ""
    echo ""
    echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
    echo -e '\E[32;1m'"Reload configuration and up the connection" ${tcreset}
    echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

    # down掉team组的slave接口及master(其实只需down master，因为down master会自动down slave)
    echo -e '\E[31;1m'"down slave and master connection of ${team_device} : " ${tcreset}
    nmcli connection down ${team_device}-port1
    sleep 1
    nmcli connection down ${team_device}-port2
    sleep 1
    nmcli connection down ${team_device}-master
    sleep 3
    echo ""

    # 对于LACP而言，down掉team组后会自动启起来； 对于activebackup而言，down掉team组后不会自动启起来，所以需要手动up slave
    # 启动team组的master不会自动启动各slave，但是启动slave会自动启动mater
    echo -e '\E[31;1m'"up slave connection of ${team_device} : " ${tcreset}
    nmcli connection up ${team_device}-port1
    sleep 1
    nmcli connection up ${team_device}-port2
    sleep 1
    echo ""

    # 结果查询
    echo -e '\E[31;1m'"nmcli connection show : " ${tcreset}
    nmcli connection show
    sleep 3
    echo ""

    echo -e '\E[31;1m'"nmcli device status : " ${tcreset}
    nmcli device status
    sleep 3
    echo ""

    echo -e '\E[31;1m'"teamnl ${team_device} ports : " ${tcreset}
    teamnl ${team_device} ports
    sleep 3
    echo ""

    echo -e '\E[31;1m'"teamdctl ${team_device} state : " ${tcreset}
    teamdctl ${team_device} state
    sleep 3
    echo ""
}


#-------------------------------------------------------------------------------
# main 主程序执行部分
#-------------------------------------------------------------------------------

echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Begin configuring team" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

# 打印未绑定Team组的网络设备速率列表
team_nic_speed
echo ""


#-------------------------------------------------------------------------------
# 参数设置
#-------------------------------------------------------------------------------
# 如果未指定命令行参数，则提示用户手动交互输入
# 设置Team名称
while [[ -z ${team_device} ]]; do
    echo -n -e '\E[32;1m'"Please set the name of team, eg. teamservice : " ${tcreset}
    read team_device
    echo ""
done

# 设置Team类型
while [[ -z ${team_type} ]]; do
    echo -n -e '\E[32;1m'"Please set the type of team, eg. lacp, activebackup : " ${tcreset}
    read team_type
    echo ""
done
# 全部转换为小写字母
team_type=$(echo ${team_type} | tr '[:upper:]' '[:lower:]')
while [[ "${team_type}" != "lacp" && "${team_type}" != "activebackup" ]]; do
    echo -n -e '\E[31m'"Incorrect choice! Must be one of (eg. lacp OR activebackup): " ${tcreset}
    read team_type
    echo ""
done

# 选择要绑定的网络接口(数组)
while true; do
    while [[ -z "${team_ports}" ]]; do
        echo -n -e '\E[32;1m'"Please choose the ports of team, separated by commas, only support two ports, eg. eno1,eno2 : " ${tcreset}
        read team_ports
        echo ""
    done

    # 合法性检查失败后，要求重新指定网络接口
    check_team_ports  # 生成变量${port1} 与 ${port2}，供create_team函数使用
    if [[ "${count}" -ne 0 ]]; then
        unset team_ports
    else
        break
    fi
done


#-------------------------------------------------------------------------------
# 创建Team
#-------------------------------------------------------------------------------

echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Create team" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
create_team  # 调用 配置Team 函数

# 成功退出
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Success" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo ""
exit 0
