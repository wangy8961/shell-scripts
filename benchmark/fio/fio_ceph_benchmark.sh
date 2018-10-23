#!/bin/bash
# Version: 1.0
# Email: wangy8961@163.com
# Description: Nikoyo 赞存分布式存储FIO性能基准测试
# @Author: wangy
# @Date:   2016-12-21 16:41:42
# @Last Modified by:   wangy
# @Last Modified time: 2017-09-04 10:51:08

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
    Please run such as './fio_ceph_benchmark.sh --storage_type iSCSI --filename /dev/sdb --rw randrw --rwmixread 70 --bs 4k --size 10G --runtime 30 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"'

Options:
  --help | -h
    Print usage information.
  --storage_type | -t
    Set the storage type
  --filename | -f
    Set the filename of fio test
  --rw | -r
    Set the I/O type
  --rwmixread | -m
    If your chocie is mixed readwrite, please set the rwmixread
  --bs | -b
    Set the block size
  --size | -s
    Set the size of job file
  --runtime | -e
    Set the run time of fio test
  --numjobs_array | -n
    Set the numjobs of fio test
  --iodepth_array | -i
    Set the iodepth of fio test
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
        --storage_type | -t) shift; storage_type=$1 ;;
        --filename | -f) shift; filename=$1 ;;
        --rw | -r) shift; rw=$1 ;;
        --rwmixread | -m) shift; rwmixread=$1 ;;
        --bs | -b) shift; bs=$1 ;;
        --size | -s) shift; size=$1 ;;
        --runtime | -e) shift; runtime=$1 ;;
        --numjobs_array | -n) shift; numjobs_array=$1 ;;
        --iodepth_array | -i) shift; iodepth_array=$1 ;;
        *) shift ;;
    esac
    shift
done

# 如果未指定命令行参数，则提示用户手动交互输入
# 设置存储类型（用于创建日志目录时命名），可选值：KRBD iSCSI NFS
while [[ -z "${storage_type}" ]]; do
    echo -n -e '\E[32;1m'"Please set the storage type, eg. KRBD iSCSI NFS : " ${tcreset}
    read storage_type
    echo ""
done

# 设置Fio的filename，KRBD和iSCSI建议使用裸盘如'/dev/sdb'，NFS建议使用绝对路径文件名如'/mnt/NFS/fio-nfs-test.data'
while [[ -z "${filename}" ]]; do
    echo -n -e '\E[32;1m'"Please set the filename, eg. suggest '/dev/sdb' for KRBD or iSCSI, and '/mnt/NFS/fio-nfs-test.data' for NFS : " ${tcreset}
    read filename
    echo ""
done

# 设置I/O读写模式，可选值：write read randwrite randread rw randrw
while [[ -z "${rw}" ]]; do
    echo -n -e '\E[32;1m'"Please set the I/O type, eg. write read randwrite randread rw randrw : " ${tcreset}
    read rw
    echo ""
done
# 如果是混合读写，需指定读的比例 0--100
if [[ "${rw}" == "rw" || "${rw}" == "randrw" ]]; then
    while [[ -z "${rwmixread}" ]]; do
        echo -n -e '\E[32;1m'"Because of your chocie is mixed readwrite, so please set the rwmixread, eg. 50 : " ${tcreset}
        read rwmixread
        echo ""
    done
fi

# 设置I/O块大小 eg. 4k 8k 128k 512k 1024k
while [[ -z "${bs}" ]]; do
    echo -n -e '\E[32;1m'"Please set the block size, eg. 4k 8k 128k 512k 1024k : " ${tcreset}
    read bs
    echo ""
done

# 设置job file的大小，一般指定全盘容量大小
while [[ -z "${size}" ]]; do
    echo -n -e '\E[32;1m'"Please set the size of job file, eg. suggest the hole size of the test disk : " ${tcreset}
    read size
    echo ""
done

# 设置job运行时长，建议60秒
while [[ -z "${runtime}" ]]; do
    echo -n -e '\E[32;1m'"Please set the run time of fio test, eg. 60 : " ${tcreset}
    read runtime
    echo ""
done

# 设置numjobs数组, 未指定 numjobs 时的默认值数组
if [[ -z "${numjobs_array}" ]]; then
    # numjobs array (1 2 4 8 12 16 20 24 28 32 36 40 44 48 52 56 60 64) 共18个
    numjobs_array=(1 2)
    arr1=($(seq 4 4 64))
    numjobs_array+=(${arr1[@]})
fi

# 设置iodepth数组, 未指定 iodepth 时的默认值数组
if [[ -z "${iodepth_array}" ]]; then
    # iodepth array (1 2 4 8 16 24 32 ... 256) 共35个
    iodepth_array=(1 2 4)
    arr2=($(seq 8 8 256))
    iodepth_array+=(${arr2[@]})
fi


#-------------------------------------------------------------------------------
# 运行Fio测试任务
#-------------------------------------------------------------------------------

# 创建日志文件目录
[ ! -d /tmp/fio/${storage_type}/${bs}-${rw}/log ] && mkdir -pv /tmp/fio/${storage_type}/${bs}-${rw}/log

# 初始化日志文件目录
rm -rf /tmp/fio/${storage_type}/${bs}-${rw}/log/*
rm -f /tmp/fio/${storage_type}/${bs}-${rw}/markdown.log

# 打印开始循环信息到屏幕
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"即将执行 ${storage_type} ${bs} ${rw} FIO 测试..." ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo ""
echo -e '\E[32;1m'">> Start Loop <<" ${tcreset}

# 为Markdown文件创建计数标志位
count=1

# 开始循环
for numjobs in ${numjobs_array[@]}; do
    for iodepth in ${iodepth_array[@]}; do
        # iodepth必须比numjobs大
        if [[ $iodepth -lt $numjobs ]]; then
            continue
        fi

        # 创建本次FIO的日志文件
        log_file="/tmp/fio/${storage_type}/${bs}-${rw}/log/fio-${bs}-${rw}-numjobs(${numjobs})-iodepth(${iodepth}).log"

        # 本次FIO的开始执行时间
        echo "Start time:" >> ${log_file}
        echo $(date) >> ${log_file}
        echo '' >> ${log_file}

        # 执行FIO测试命令
        if [[ "${rw}" == "rw" || "${rw}" == "randrw" ]]; then
            fio -name="${storage_type} ${bs} ${rw} test" -filename=${filename} -ioengine=libaio -direct=1 -thread -rw=${rw} -rwmixread=${rwmixread} -bs=${bs} -size=${size} -numjobs=${numjobs} -iodepth=${iodepth} -runtime=${runtime} --time_based -group_reporting >> ${log_file}
        else
            fio -name="${storage_type} ${bs} ${rw} test" -filename=${filename} -ioengine=libaio -direct=1 -thread -rw=${rw} -bs=${bs} -size=${size} -numjobs=${numjobs} -iodepth=${iodepth} -runtime=${runtime} --time_based -group_reporting >> ${log_file}
        fi

        # 本次FIO的结束执行时间
        echo '' >> ${log_file}
        echo "End time:" >> ${log_file}
        echo $(date) >> ${log_file}

        # 复制FIO输出信息到Markdown文件中
        markdown_log="/tmp/fio/${storage_type}/${bs}-${rw}/markdown.md"
        echo "####（$count）<font color=\"red\">**-numjobs=${numjobs} -iodepth=${iodepth}**</font>" >> ${markdown_log}
        echo "\`\`\`" >> ${markdown_log}
        cat ${log_file} >> ${markdown_log}
        echo "\`\`\`" >> ${markdown_log}
        echo '' >> ${markdown_log}

        # 打印本次FIO执行完成信息到屏幕
        echo -e '\E[33;4m'"($count) ${log_file} has complete!" ${tcreset}

        # 如果是NFS测试，则删除fio测试文件； 如果是iSCSI测试，且直接指定的硬盘标示符，则不予理会
        # 即判断${filename}中是否包含dev字符串
        #[[ "${filename}" != *"dev"* ]] && rm -f ${filename}

        # 将 count 自增1
        ((count++))

        # 睡眠3秒
        sleep 3
    done
done

# 打印结束整个循环信息到屏幕
echo -e '\E[32;1m'">> End Loop <<" ${tcreset}
