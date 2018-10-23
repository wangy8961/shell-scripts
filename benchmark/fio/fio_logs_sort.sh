#!/bin/bash
# Version: 1.0
# Email: wangy8961@163.com
# Description: Nikoyo 赞存分布式存储FIO性能基准测试，获取最优参数组合
# @Author: wangy
# @Date:   2016-12-21 16:41:42
# @Last Modified by:   wangy
# @Last Modified time: 2017-05-24 11:31:36

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
# Usage:
#   $0 [-d /tmp/fio]
#-------------------------------------------------------------------------------

function _usage() {
    echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

    echo -e '\E[32;1m'"Usage:" ${tcreset}
    echo "  $0 [-d /tmp/fio/NFS/512k-write/log]"

    echo -e '\E[32;1m'"\nPOSIX options:" ${tcreset}
    echo -e "  -h:   Print usage information."
    echo -e "  -d [log_path]:   Flexible IO Tester log path (eg. /tmp/fio/NFS/512k-write/log).\n"

    echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
}


#-------------------------------------------------------------------------------
# 处理命令行选项/参数
# 最前面的冒号":"用于指定getopts工作于silent mode
#-------------------------------------------------------------------------------

while getopts :hd: opts ; do
    case ${opts} in
        h )
            _usage
            exit 0
            ;;
        d )
            log_path=${OPTARG}
            ;;
        \? )
            echo -e '\E[31;1m'"Invalid Options !" ${tcreset}
            _usage
            exit 1
            ;;
    esac
done


#-------------------------------------------------------------------------------
# 检查各参数的赋值情况
# 暂时未判断参数值的合法性
#-------------------------------------------------------------------------------

function _checkPara() {
    if [[ -z "${log_path}" ]] ; then
        echo -e '\E[31;1m'"\${log_path} 尚未赋值, 将使用初始值: " ${tcreset} "/tmp/fio/NFS/512k-write/log"
        log_path="/tmp/fio/NFS/512k-write/log"
    else
        ls -l ${log_path} &> /dev/null
        if [[ $? -ne 0 ]] ; then
            echo -e '\E[31;1m'"日志目录${log_path}不存在，请确认后再次执行本脚本..." ${tcreset}
            echo
            exit 1
        fi
        echo -e '\E[32;1m'"\${log_path} 已赋值: " ${tcreset} ${log_path}
    fi

    # 询问是否接受参数设定?
    echo -n -e '\E[32;1m'"\n是否接受以上参数设定? (Y/N)" ${tcreset}
    # 超时30秒后，自动选择默认值Y
    read -t 30 choice
    choice=${choice:="Y"}

    # 判断选择值，是否继续执行
    # 转换为小写字母
    choice=$(echo ${choice} | tr '[:upper:]' '[:lower:]')
    if [[ "${choice}" == "y" || "${choice}" == "yes" ]]; then
        echo -e '\E[32;1m'"\n正在处理日志文件...\n" ${tcreset}
    else
        echo -e '\E[32;1m'"\n已终止执行！Goodbye\n" ${tcreset}
        exit 1
    fi
}


#-------------------------------------------------------------------------------
# 处理日志文件，获取各指标
# bandwidth / IOPS / latency / util
#-------------------------------------------------------------------------------

function _getMaxIOPS() {
    # 创建sort排序后记录保存的临时文件名，依据提供的日志目录（类似/tmp/fio/NFS/512k-write/log）
    temp_log=${log_path//// }   # 将${log_path}以/分隔的字符串中，所有的/替换为空格，变成数组
    temp_log_arr=(${temp_log})  # 字符串转换为数组
    # 定义临时文件
    temp_log="/tmp/${temp_log_arr[1]}-${temp_log_arr[2]}-${temp_log_arr[3]}.log"
    # 初始化
    printf "%-20s %-15s %-15s %-15s %-15s %-20s %-15s" "mode" "numjobs" "iodepth" "bandwidth" "iops" "avg_latency(msec)" "util" > ${temp_log}
    echo -e "\n" >> ${temp_log}  # 换行

    # 循环目录下的日志文件
    ls ${log_path} | while read log_file; do

        # 判断readwrite是否为混合读写，因为混合读写的日志文件中有读跟写的两部分bandwidth与iops
        readwrite=$(echo ${log_file} | cut -d'-' -f3)

        if [[ "${readwrite}" == "rw" || "${readwrite}" == "randrw" ]]; then
            #-------------------------------------------------------------------
            # 分析 read 部分
            #-------------------------------------------------------------------

            # mode
            read_mode=$(echo ${log_file} | cut -d'-' -f2)-$(echo ${log_file} | cut -d'-' -f3)-read

            # numjobs
            read_numjobs=$(echo ${log_file} | cut -d'-' -f4)

            # iodepth
            read_iodepth=$(echo ${log_file} | cut -d'-' -f5 | cut -d'.' -f1)

            # 以下值的获取只截取日志文件中，匹配单词read的后10行中查找
            # bandwidth
            read_bandwidth=$(grep -A10 '\<read\>' ${log_path}/${log_file} | awk '/iops=*/ {print $0}' | cut -d ',' -f 2 | cut -d '=' -f 2)

            # IOPS
            read_iops=$(grep -A10 '\<read\>' ${log_path}/${log_file} | awk '/iops=*/ {print $0}' | cut -d ',' -f 3 | cut -d '=' -f 2)

            # 平均延时的单位
            read_unit=$(grep -A10 '\<read\>' ${log_path}/${log_file} | grep 'clat percentiles (.*):' | awk -F '[()]' '{print $2}')
            # 平均延时 clat percentiles (msec): 95.00th=[  *]
            read_avg_lat=$(grep -A10 '\<read\>' ${log_path}/${log_file} | grep '95.00th=' | cut -d ',' -f 4 | awk -F '[' '{print $2}' | tr -d ']' | sed 's/^[ \t]*//g')
            # 如果是usec则转换为msec，保留3位小数
            if [[ "${read_unit}" == "usec" ]]; then
                read_avg_lat=$(printf "%.3f" `echo "scale=3; ${read_avg_lat}/1000" | bc`)
            fi
            # 不拼接，带单位后不能按整数排序
            #read_avg_lat=${read_avg_lat}${read_unit}

            # 磁盘利用率
            read_util=$(grep -A10 '\<read\>' ${log_path}/${log_file} | grep 'util=' | cut -d ',' -f 5 | cut -d '=' -f 2)

            # 输出到临时文件
            printf "%-20s %-15s %-15s %-15s %-15s %-20s %-15s" ${read_mode} ${read_numjobs} ${read_iodepth} ${read_bandwidth} ${read_iops} ${read_avg_lat} ${read_util} >> ${temp_log}
            echo "" >> ${temp_log}  # 每写入一条记录，换行

            #-------------------------------------------------------------------
            # 分析 write 部分
            #-------------------------------------------------------------------

            # mode
            write_mode=$(echo ${log_file} | cut -d'-' -f2)-$(echo ${log_file} | cut -d'-' -f3)-write

            # numjobs
            write_numjobs=$(echo ${log_file} | cut -d'-' -f4)

            # iodepth
            write_iodepth=$(echo ${log_file} | cut -d'-' -f5 | cut -d'.' -f1)

            # 以下值的获取只截取日志文件中，匹配单词read的后10行中查找
            # bandwidth
            write_bandwidth=$(grep -A10 '\<write\>' ${log_path}/${log_file} | awk '/iops=*/ {print $0}' | cut -d ',' -f 2 | cut -d '=' -f 2)

            # IOPS
            write_iops=$(grep -A10 '\<write\>' ${log_path}/${log_file} | awk '/iops=*/ {print $0}' | cut -d ',' -f 3 | cut -d '=' -f 2)

            # 平均延时的单位
            write_unit=$(grep -A10 '\<write\>' ${log_path}/${log_file} | grep 'clat percentiles (.*):' | awk -F '[()]' '{print $2}')
            # 平均延时 clat percentiles (msec): 95.00th=[  *]
            write_avg_lat=$(grep -A10 '\<write\>' ${log_path}/${log_file} | grep '95.00th=' | cut -d ',' -f 4 | awk -F '[' '{print $2}' | tr -d ']' | sed 's/^[ \t]*//g')
            # 如果是usec则转换为msec，保留3位小数
            if [[ "${write_unit}" == "usec" ]]; then
                write_avg_lat=$(printf "%.3f" `echo "scale=3; ${write_avg_lat}/1000" | bc`)
            fi
            # 不拼接，带单位后不能按整数排序
            #write_avg_lat=${write_avg_lat}${write_unit}

            # 磁盘利用率
            write_util=$(grep -A10 '\<read\>' ${log_path}/${log_file} | grep 'util=' | cut -d ',' -f 5 | cut -d '=' -f 2)

            # 输出到临时文件
            printf "%-20s %-15s %-15s %-15s %-15s %-20s %-15s" ${write_mode} ${write_numjobs} ${write_iodepth} ${write_bandwidth} ${write_iops} ${write_avg_lat} ${write_util} >> ${temp_log}
            echo "" >> ${temp_log}  # 每写入一条记录，换行

        else
            # mode
            mode=$(echo ${log_file} | cut -d'-' -f2)-$(echo ${log_file} | cut -d'-' -f3)

            # numjobs
            numjobs=$(echo ${log_file} | cut -d'-' -f4)

            # iodepth
            iodepth=$(echo ${log_file} | cut -d'-' -f5 | cut -d'.' -f1)

            # bandwidth
            bandwidth=$(cat ${log_path}/${log_file} | awk '/iops=*/ {print $0}' | cut -d ',' -f 2 | cut -d '=' -f 2)

            # IOPS
            iops=$(cat ${log_path}/${log_file} | awk '/iops=*/ {print $0}' | cut -d ',' -f 3 | cut -d '=' -f 2)

            # 平均延时的单位
            unit=$(cat ${log_path}/${log_file} | grep 'clat percentiles (.*):' | awk -F '[()]' '{print $2}')
            # 平均延时 clat percentiles (msec): 95.00th=[  *]
            avg_lat=$(cat ${log_path}/${log_file} | grep '95.00th=' | cut -d ',' -f 4 | awk -F '[' '{print $2}' | tr -d ']' | sed 's/^[ \t]*//g')
            # 如果是usec则转换为msec，保留3位小数
            if [[ "${unit}" == "usec" ]]; then
                avg_lat=$(printf "%.3f" `echo "scale=3; ${avg_lat}/1000" | bc`)
            fi
            # 不拼接，带单位后不能按整数排序
            #avg_lat=${avg_lat}${unit}

            # 磁盘利用率
            util=$(cat ${log_path}/${log_file} | grep 'util=' | cut -d ',' -f 5 | cut -d '=' -f 2)

            # 输出到临时文件
            printf "%-20s %-15s %-15s %-15s %-15s %-20s %-15s" ${mode} ${numjobs} ${iodepth} ${bandwidth} ${iops} ${avg_lat} ${util} >> ${temp_log}
            echo "" >> ${temp_log}  # 每写入一条记录，换行
        fi

    done

    # 输出排序结果
    # 先输出前两行（表头与空行）
    sed -n '1,2 p' ${temp_log}

    # 从第3行开始，按IOPS升序、延时倒序排列
    sed -n '3,$ p' ${temp_log} | sort -k5,5n -k6,6nr

    echo ""
}


#-------------------------------------------------------------------------------
# main 主程序执行部分
#-------------------------------------------------------------------------------

echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Begin sorting fio test log" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo ""

# 调用 检查参数 及 排序 函数
_checkPara
_getMaxIOPS

echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Success" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo ""

