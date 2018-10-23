#!/bin/bash
# Version: 1.0
# Email: wangy8961@163.com
# Description: FIO测试400GB SSD单个磁盘的读写性能
# @Author: wangy
# @Date:   2017-03-17 14:31:52
# @Last Modified by:   wangy
# @Last Modified time: 2017-09-01 14:29:20

#-------------------------------------------------------------------------------
# 1. 打开磁盘write cache
#-------------------------------------------------------------------------------

# 512k 顺序写
./fio_device_benchmark.sh --storage_type SSD --filename /dev/sdb --hdparm 1 --rw write --bs 512k --size 50G --runtime 15 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"
sleep 3

# 512k 顺序读
./fio_device_benchmark.sh --storage_type SSD --filename /dev/sdb --hdparm 1 --rw read --bs 512k --size 50G --runtime 15 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"
sleep 3

# 4k 随机写
./fio_device_benchmark.sh --storage_type SSD --filename /dev/sdb --hdparm 1 --rw randwrite --bs 4k --size 50G --runtime 15 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"
sleep 3

# 4k 随机读
./fio_device_benchmark.sh --storage_type SSD --filename /dev/sdb --hdparm 1 --rw randread --bs 4k --size 50G --runtime 15 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"
sleep 3

# 512k 顺序混合读写，读70%
./fio_device_benchmark.sh --storage_type SSD --filename /dev/sdb --hdparm 1 --rw rw --rwmixread 70 --bs 512k --size 50G --runtime 15 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"
sleep 3

# 4k 随机混合读写，读70%
./fio_device_benchmark.sh --storage_type SSD --filename /dev/sdb --hdparm 1 --rw randrw --rwmixread 70 --bs 4k --size 50G --runtime 15 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"
sleep 3

# 另存日志目录
mv -T /tmp/fio /tmp/fio-400GB-SSD-writecache-on


#-------------------------------------------------------------------------------
# 2. 关闭磁盘write cache
#-------------------------------------------------------------------------------

# 512k 顺序写
./fio_device_benchmark.sh --storage_type SSD --filename /dev/sdb --hdparm 0 --rw write --bs 512k --size 50G --runtime 15 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"
sleep 3

# 512k 顺序读
./fio_device_benchmark.sh --storage_type SSD --filename /dev/sdb --hdparm 0 --rw read --bs 512k --size 50G --runtime 15 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"
sleep 3

# 4k 随机写
./fio_device_benchmark.sh --storage_type SSD --filename /dev/sdb --hdparm 0 --rw randwrite --bs 4k --size 50G --runtime 15 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"
sleep 3

# 4k 随机读
./fio_device_benchmark.sh --storage_type SSD --filename /dev/sdb --hdparm 0 --rw randread --bs 4k --size 50G --runtime 15 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"
sleep 3

# 512k 顺序混合读写，读70%
./fio_device_benchmark.sh --storage_type SSD --filename /dev/sdb --hdparm 0 --rw rw --rwmixread 70 --bs 512k --size 50G --runtime 15 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"
sleep 3

# 4k 随机混合读写，读70%
./fio_device_benchmark.sh --storage_type SSD --filename /dev/sdb --hdparm 0 --rw randrw --rwmixread 70 --bs 4k --size 50G --runtime 15 --numjobs_array "1 2 4 8 16 24" --iodepth_array "1 2 4 8 16 32 64"
sleep 3

# 另存日志目录
mv -T /tmp/fio /tmp/fio-400GB-SSD-writecache-off
