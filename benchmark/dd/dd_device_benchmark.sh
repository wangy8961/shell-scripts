#!/bin/bash
# Version: 1.0
# Email: wangy8961@163.com
# Description: dd工具测试单个磁盘的读写性能
# @Author: wangy
# @Date:   2016-12-21 16:41:42
# @Last Modified by:   wangy
# @Last Modified time: 2017-05-04 15:37:12

#-------------------------------------------------------------------------------
# Shell脚本基础设置
#-------------------------------------------------------------------------------

#set -e
#set -x

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
    The tool can help you to test the benchmark of SSA ceph storage automatically.
    Please run such as './dd_device_benchmark.sh --device_type iSCSI --device /dev/sdb --hdparm 0 --readwrite "write read randwrite" --size 10G --bs_arr "4k 8k 16k 64k 256k 512k 1M 4M"'

Options:
  --help | -h
    Print usage information.
  --device_type | -t
    Set the device type, eg. KRBD iSCSI NFS
  --device | -d
    Set the device name, eg. /dev/sdb
  --hdparm | -p
    Set the write cache of device on/off
  --readwrite | -r
    Set the I/O type array, eg. "write read randwrite"
  --size | -s
    Set the size of dd test, eg. suggest the hole size of the test disk
  --bs_arr | -b
    Set the block size array, eg. 4k 8k 16k 64k 256k 512k 1M 4M
EOF
    exit 0
}


#-------------------------------------------------------------------------------
# 参数设置
#-------------------------------------------------------------------------------

# 获取命令行参数值
while [ $# -gt 0 ]; do
    case "$1" in
        --help | -h) usage ;;
        --device_type | -t) shift; device_type=$1 ;;
        --device | -d) shift; device=$1 ;;
        --hdparm | -p) shift; hdparm=$1 ;;
        --readwrite | -r) shift; readwrite=$1 ;;
        --size | -s) shift; size=$1 ;;
        --bs_arr | -b) shift; bs_arr=$1 ;;
        *) shift ;;
    esac
    shift
done

# 如果未指定命令行参数，则提示用户手动交互输入
# 设置存储类型（用于创建日志目录时命名），可选值：KRBD iSCSI NFS
while [[ -z "${device_type}" ]]; do
    echo -n -e '\E[32;1m'"Please set the device type, eg. KRBD iSCSI NFS : " ${tcreset}
    read device_type
    echo ""
done

# output file 名称
while [[ -z "${device}" ]]; do
    echo -n -e '\E[32;1m'"Please set the device name, eg. /dev/sdb : " ${tcreset}
    read device
    echo ""
done

# 打开/关闭磁盘写缓存 write cache; 1:开 0:关
while [[ -z "${hdparm}" ]]; do
    echo -n -e '\E[32;1m'"Please set the write cache of device on/off, eg. 1(on) 0(off) : " ${tcreset}
    read hdparm
    echo ""
done
hdparm -W ${hdparm} ${device}

# 读写模式, 可选值：write read randwrite
while [[ -z "${readwrite}" ]]; do
    echo -n -e '\E[32;1m'"Please set the I/O type array, eg. write read randwrite : " ${tcreset}
    read readwrite
    echo ""
done

# 读写容量大小
while [[ -z "${size}" ]]; do
    echo -n -e '\E[32;1m'"Please set the size of dd test, eg. suggest the hole size of the test disk : " ${tcreset}
    read size
    echo ""
done

# 设置I/O块大小 eg. 4k 8k 16k 64k 256k 512k 1M 4M
while [[ -z "${bs_arr}" ]]; do
    echo -n -e '\E[32;1m'"Please set the block size array, eg. 4k 8k 16k 64k 256k 512k 1M 4M : " ${tcreset}
    read bs_arr
    echo ""
done


#-------------------------------------------------------------------------------
# 运行dd测试任务
#-------------------------------------------------------------------------------

# 初始化日志保存目录
[ ! -d /tmp/dd/${device_type}/log ] && mkdir -pv /tmp/dd/${device_type}/log
rm -rf /tmp/dd/${device_type}/log/*

# size的单位: 截取最后一个字符并转换为小写
size_unit=$(echo ${size:0-1} | tr '[:upper:]' '[:lower:]')
# size的值: 删除非数字的字符
size_value=$(echo ${size} | tr -cd "[0-9]")
# 转换为KB
if [[ "${size_unit}" == "m" ]]; then
    (( size_value=size_value*1024 ))
elif [[ "${size_unit}" == "g" ]]; then
    (( size_value=size_value*1024*1024 ))
else [[ "${size_unit}" == "t" ]]
    (( size_value=size_value*1024*1024*1024 ))
fi

# 循环读写模式
for rw in ${readwrite[@]}; do
    # 初始化record_count
    record_count=1

    # 打印开始循环信息到屏幕
    echo ""
    echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
    echo -e '\E[32;1m'"即将执行 ${device_type} ${rw} DD 测试..." ${tcreset}
    echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
    echo ""
    echo -e '\E[32;1m'">> Start Loop <<" ${tcreset}

    # 循环块大小
    for bs in ${bs_arr[@]}; do
        # bs的单位: 截取最后一个字符并转换为小写
        bs_unit=$(echo ${bs:0-1} | tr '[:upper:]' '[:lower:]')
        # bs的值: 删除非数字的字符
        bs_value=$(echo ${bs} | tr -cd "[0-9]")
        # 转换为KB
        [[ "${bs_unit}" == "m" ]] && (( bs_value=bs_value*1024 ))

        # 计算count值
        (( count=size_value/bs_value ))

        # 根据读写模式分类，执行dd命令
        case ${rw} in
            write )
                # 日志文件
                log_file="/tmp/dd/${device_type}/log/write.log"

                # 本次dd的开始执行时间
                echo "Start time:" >> ${log_file}
                echo $(date) >> ${log_file}
                echo "" >> ${log_file}

                # 执行dd命令
                echo "[root@CentOS7 ~]$ dd if=/dev/zero of=${device} bs=${bs} count=${count} oflag=direct,dsync" >> ${log_file}
                dd if=/dev/zero of=${device} bs=${bs} count=${count} oflag=direct,dsync &>> ${log_file}

                # 本次dd的结束执行时间
                echo "" >> ${log_file}
                echo "End time:" >> ${log_file}
                echo $(date) >> ${log_file}
                echo "" >> ${log_file}

                # 打印本次dd执行完成信息到屏幕
                echo -e '\E[33;4m'"($record_count) “[root@CentOS7 ~]$ dd if=/dev/zero of=${device} bs=${bs} count=${count} oflag=direct,dsync” has complete!" ${tcreset}

                # 将 record_count 自增1
                ((record_count++))

                # 睡眠3秒
                sleep 3
                ;;

            read )
                # 日志文件
                log_file="/tmp/dd/${device_type}/log/read.log"

                # 本次dd的开始执行时间
                echo "Start time:" >> ${log_file}
                echo $(date) >> ${log_file}
                echo "" >> ${log_file}

                # 执行dd命令
                echo "[root@CentOS7 ~]$ dd if=${device} of=/dev/null bs=${bs} count=${count} iflag=direct,dsync" >> ${log_file}
                dd if=${device} of=/dev/null  bs=${bs} count=${count} iflag=direct,dsync &>> ${log_file}

                # 本次dd的结束执行时间
                echo "" >> ${log_file}
                echo "End time:" >> ${log_file}
                echo $(date) >> ${log_file}
                echo "" >> ${log_file}

                # 打印本次dd执行完成信息到屏幕
                echo -e '\E[33;4m'"($record_count) “[root@CentOS7 ~]$ dd if=${device} of=/dev/null bs=${bs} count=${count} iflag=direct,dsync” has complete!" ${tcreset}

                # 将 record_count 自增1
                ((record_count++))

                # 睡眠3秒
                sleep 3
                ;;

            randwrite )
                # 日志文件
                log_file="/tmp/dd/${device_type}/log/randwrite.log"

                # 本次dd的开始执行时间
                echo "Start time:" >> ${log_file}
                echo $(date) >> ${log_file}
                echo "" >> ${log_file}

                # 执行dd命令
                echo "[root@CentOS7 ~]$ dd if=/root/${bs}-randfile of=${device} bs=${bs} count=${count} oflag=direct,dsync" >> ${log_file}
                dd if=/dev/urandom of=/root/${bs}-randfile bs=${bs} count=${count} && sync
                dd if=/root/${bs}-randfile of=${device} bs=${bs} count=${count} oflag=direct,dsync &>> ${log_file}

                # 删除随即文件
                rm -f /root/${bs}-randfile

                # 本次dd的结束执行时间
                echo "" >> ${log_file}
                echo "End time:" >> ${log_file}
                echo $(date) >> ${log_file}
                echo "" >> ${log_file}

                # 打印本次dd执行完成信息到屏幕
                echo -e '\E[33;4m'"($record_count) “[root@CentOS7 ~]$ dd if=/root/${bs}-randfile of=${device} bs=${bs} count=${count} oflag=direct,dsync” has complete!" ${tcreset}

                # 将 record_count 自增1
                ((record_count++))

                # 睡眠3秒
                sleep 3
                ;;
        esac

    done
done
