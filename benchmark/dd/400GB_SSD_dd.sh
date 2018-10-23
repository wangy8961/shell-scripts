#!/bin/bash
# Version: 1.0
# Email: wangy8961@163.com
# Description: dd测试400GB SSD单个磁盘的读写性能
# @Author: wangy
# @Date:   2016-12-21 16:41:42
# @Last Modified by:   wangy
# @Last Modified time: 2017-05-04 10:11:31

#-------------------------------------------------------------------------------
# 1. 打开磁盘write cache
#-------------------------------------------------------------------------------

# 顺序读写、随机写， 大小1G， 块大小4k 8k 16k 64k 256k 512k 1M 4M
./dd_device_benchmark.sh --device_type SSD --device /dev/sdb --hdparm 1 --readwrite "write read randwrite" --size 5G --bs_arr "4k 8k 16k 64k 256k 512k 1M 4M"
sleep 3

# 另存日志目录
mv -T /tmp/dd /tmp/dd-400GB-SSD-writecache-on


#-------------------------------------------------------------------------------
# 2. 关闭磁盘write cache
#-------------------------------------------------------------------------------

# 顺序读写、随机写， 大小1G， 块大小4k 8k 16k 64k 256k 512k 1M 4M
./dd_device_benchmark.sh --device_type SSD --device /dev/sdb --hdparm 0 --readwrite "write read randwrite" --size 5G --bs_arr "4k 8k 16k 64k 256k 512k 1M 4M"
sleep 3

# 另存日志目录
mv -T /tmp/dd /tmp/dd-400GB-SSD-writecache-off


