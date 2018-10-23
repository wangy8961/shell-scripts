#!/bin/bash
# Version: 1.0
# Email: wangy8961@163.com
# Description: Nikoyo 赞存分布式存储 收集系统相关日志等信息
# @Author: wangy
# @Date:   2016-06-17 17:27:07
# @Last Modified by:   wangy
# @Last Modified time: 2017-07-21 14:03:56


#-------------------------------------------------------------------------------
# Shell脚本基础设置
#-------------------------------------------------------------------------------

# set -e
# set -x

# unset any variable which system may be using
unset tcreset os architecture kernelrelease internalip externalip nameserver loadaverage

# clear the screen
clear

# Define Variable for resetting teminal color
tcreset=$(tput sgr0)


#-------------------------------------------------------------------------------
# 脚本支持的命令行选项参数
# -i 将脚本安装到/usr/bin/monitor，成为可执行的命令程序
# -v 显示脚本版本号
#-------------------------------------------------------------------------------

while getopts :iv name
do
    case $name in
      i)iopt=1;;
      v)vopt=1;;
      *)echo "Invalid arg";;
    esac
done

if [[ ! -z $iopt ]]
then
    wd=$(pwd)
    basename "$(test -L "$0" && readlink "$0" || echo "$0")" > /tmp/nikoyo_csp_monitor/scriptname
    scriptname=$(echo -e -n $wd/ && cat /tmp/nikoyo_csp_monitor/scriptname)
    su -c "cp $scriptname /usr/bin/monitor" root && echo "Congratulations! Script Installed, now run monitor Command" || echo "Installation failed"
fi

if [[ ! -z $vopt ]]
then
    echo -e "nikoyo_csp_monitor version 0.1\nDesigned by nikoyo.com.cn / wangy \nReleased Under Apache 2.0 License"
fi


#-------------------------------------------------------------------------------
# 如果不指定命令行选项参数
#-------------------------------------------------------------------------------

if [[ $# -eq 0 ]]
then

    #---------------------------------------------------------------------------
    # 1. Check OS Type
    #---------------------------------------------------------------------------
    os=$(uname -o)
    echo -e '\E[32;1m'">>>1. Operating System Type :" $tcreset $os
    echo ""


    #---------------------------------------------------------------------------
    # 2. Check OS Release Version and Name
    #---------------------------------------------------------------------------
    echo -n -e '\E[32;1m'">>>(1) OS Name :" $tcreset
    cat /etc/os-release | grep '^NAME\|^VERSION=' | grep -v 'VERSION_ID' | grep -v 'PRETTY_NAME' | grep -v "VERSION" | cut -f2 -d\"

    echo -n -e '\E[32;1m'">>>(2) OS Version :" $tcreset
    cat /etc/os-release | grep '^NAME\|^VERSION=' | grep -v 'VERSION_ID' | grep -v 'PRETTY_NAME' | grep -v "NAME" | cut -f2 -d\"

    echo ""


    #---------------------------------------------------------------------------
    # 3. Check Architecture
    #---------------------------------------------------------------------------
    architecture=$(uname -m)
    echo -e '\E[32;1m'">>>3. Architecture :" $tcreset $architecture
    echo ""


    #---------------------------------------------------------------------------
    # 4. Check Kernel Release
    #---------------------------------------------------------------------------
    kernelrelease=$(uname -r)
    echo -e '\E[32;1m'">>>4. Kernel Release :" $tcreset $kernelrelease
    echo ""


    #---------------------------------------------------------------------------
    # 5. Check hostname
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>5. Hostname :" $tcreset $HOSTNAME
    echo ""


    #---------------------------------------------------------------------------
    # 6. Check Logged In Users
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>6. Logged In users :" $tcreset
    who
    echo ""


    #---------------------------------------------------------------------------
    # 7. Check RAM and SWAP Usages
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>7. RAM and SWAP Usages :" $tcreset
    free -h
    echo ""


    #---------------------------------------------------------------------------
    # 8. Check Disk Usages
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>8. Disk Usages :" $tcreset
    df -h
    echo ""


    #---------------------------------------------------------------------------
    # 9. Check Load Average
    #---------------------------------------------------------------------------
    loadaverage=$(top -n 1 -b | grep "load average:" | awk '{print $12 $13 $14}')
    echo -e '\E[32;1m'">>>9. Load Average :" $tcreset $loadaverage
    echo ""


    #---------------------------------------------------------------------------
    # 10. Check System Uptime
    #---------------------------------------------------------------------------
    tecuptime=$(uptime | awk '{print $3,$4}' | cut -f1 -d,)
    echo -e '\E[32;1m'">>>10. System Uptime Days/(HH:MM) :" $tcreset $tecuptime
    echo ""


    #---------------------------------------------------------------------------
    # 11. Check if connected to Internet or not
    #---------------------------------------------------------------------------
    ping -c 1 www.baidu.com &> /dev/null

    if [[ $? -eq 0 ]]; then
    	echo -e '\E[32;1m'">>>11. Internet: $tcreset Connected"
    	externalip=$(curl -s ipecho.net/plain; echo)
    	echo -e '\E[32;1m'">>>(1) External IP :" $tcreset $externalip
    else
    	echo -e '\E[32;1m'">>>11. Internet: $tcreset Disconnected"
    	echo -e '\E[32;1m'">>>(1) External IP : $tcreset None"
    fi

    internalip=$(hostname -I)
    echo -e '\E[32;1m'">>>(2) Internal IP :" $tcreset $internalip
    echo ""


    #---------------------------------------------------------------------------
    # 12. Check DNS
    #---------------------------------------------------------------------------
    nameservers=$(cat /etc/resolv.conf | sed '1 d' | awk '{print $2}')
    echo -e '\E[32;1m'">>>12. Name Servers :" $tcreset $nameservers
    echo ""


    #---------------------------------------------------------------------------
    # 13. Check Intel NIC ixgbe driver info
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>13. Intel NIC ixgbe driver info :" $tcreset
    modinfo ixgbe
    echo ""


    #---------------------------------------------------------------------------
    # 14. Static Route
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>14. Static Route :" $tcreset
    ip route
    echo ""


    #---------------------------------------------------------------------------
    # 15. IP Addr Show
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>15. IP Addr Show :" $tcreset
    ip addr show
    echo ""


    #---------------------------------------------------------------------------
    # 16. Team Info
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>16. Team info :" $tcreset

    for teamname in `nmcli connection show | grep -w 'team' | awk '{print $4}'`
	do
		echo -e '\E[32;1m'"The status of team $teamname :" $tcreset
        echo ""

        echo -e '\E[32;1m'"(1) teamdctl $teamname state :" $tcreset
        teamdctl $teamname state
        echo ""

        echo -e '\E[32;1m'"(2) teamdctl $teamname state dump:" $tcreset
        teamdctl $teamname state dump
        echo ""

        echo -e '\E[32;1m'"(3) teamdctl $teamname config dump :" $tcreset
        teamdctl $teamname config dump
        echo ""

        echo -e '\E[32;1m'"(4) teamnl $teamname option :" $tcreset
        teamnl $teamname option
        echo ""

        echo -e '\E[32;1m'"(5) teamnl $teamname ports :" $tcreset
        teamnl $teamname ports
        echo ""
	done
    echo ""


    #---------------------------------------------------------------------------
    # 17. Check out dmesg log
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>17. dmesg :" $tcreset
    dmesg -T
    echo ""


    #---------------------------------------------------------------------------
    # 18. Info for PCI
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>18. PCI info :" $tcreset
    lspci -nn
    echo ""


    #---------------------------------------------------------------------------
    # 19. Check MegaRAID info
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>19. MegaRAID information :" $tcreset
    rpm -qa | grep MegaRAID
    if [[ $? -eq 0 ]]
    then
        echo -e "The MegaRAID Storage Manager already installed, the RPM package info :"
        rpm -qa | grep MegaRAID

        ps -ef | grep MegaRAID | grep -v grep
        if [[ $? -eq 0 ]]
        then
            echo -e "And the server process is started, the process info :"
            ps -ef | grep MegaRAID | grep -v grep
        else
            echo -e "But the server process is stoped. Please start it. Usage: # /etc/init.d/vivaldiframeworkd start"
        fi
    else
        echo -e "The MegaRAID Storage Manager not installed. Please install it first."
    fi
    echo ""


    #---------------------------------------------------------------------------
    # 20. Info for csp-agent
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>20. csp_agent status :" $tcreset
    ps -ef | grep csp_agent
    echo ""


    #---------------------------------------------------------------------------
    # 21. Info for corosync + pacemaker + pcs
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>21. pcs status :" $tcreset
    echo -e '\E[32;1m'"(1) corosync version :" $tcreset
    corosync -v
    echo ""

    echo -e '\E[32;1m'"(2) pacemaker version :" $tcreset
    pacemakerd -$
    echo ""

    echo -e '\E[32;1m'"(3) pcs version :" $tcreset
    pcs --version
    echo ""

    echo -e '\E[32;1m'"pcs status :" $tcreset
    pcs status
    echo ""


    #---------------------------------------------------------------------------
    # 22. Info for ceph
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>22. ceph status :" $tcreset
    echo -e '\E[32;1m'"(1) ceph version :" $tcreset
    ceph -v
    echo ""

    echo -e '\E[32;1m'"(2) ceph.conf :" $tcreset
    cat /etc/ceph/ceph.conf
    echo ""

    echo -e '\E[32;1m'"(3) ceph status :" $tcreset
    ceph -s
    echo ""


    #---------------------------------------------------------------------------
    # 23. Ceph OSD Tree
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>23. Ceph OSD Tree :" $tcreset
    ceph osd tree
    echo ""


    #---------------------------------------------------------------------------
    # 24. RPM list
    #---------------------------------------------------------------------------
    echo -e '\E[32;1m'">>>24. RPM list :" $tcreset
    rpm -qa
    echo ""


    #---------------------------------------------------------------------------
    # Unset Variables
    #---------------------------------------------------------------------------
    unset tcreset os architecture kernelrelease internalip externalip nameserver loadaverage
fi

shift $(($OPTIND -1))
