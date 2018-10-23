#!/bin/bash
# Version: 1.0
# Email: wangy8961@163.com
# Description: dd测试Ceph iSCSI读写性能
# @Author: wangy
# @Date:   2016-12-21 16:41:42
# @Last Modified by:   wangy
# @Last Modified time: 2017-05-04 10:02:28

# 顺序读写、随机写， 大小5G， 块大小4k 8k 16k 64k 256k 512k 1M 4M
./dd_ceph_benchmark.sh --device_type iSCSI --device /dev/sdb --readwrite "write read randwrite" --size 5G --bs_arr "4k 8k 16k 64k 256k 512k 1M 4M"

# 另存日志目录
mv -T /tmp/dd /tmp/dd-ceph-iscsi
