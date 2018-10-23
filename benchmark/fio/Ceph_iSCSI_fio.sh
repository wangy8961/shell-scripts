#!/bin/bash
# Version: 1.0
# Email: wangy8961@163.com
# Description: fio测试Ceph iSCSI读写性能
# @Author: wangy
# @Date:   2016-12-21 16:41:42
# @Last Modified by:   wangy
# @Last Modified time: 2017-09-01 14:29:33

# 8k 顺序写
./fio_ceph_benchmark.sh --storage_type iSCSI --filename /dev/sdc --rw write --bs 8k --size 50G --runtime 30 --numjobs_array "8 16 24 28 32 64" --iodepth_array "16 32 64 128 192 256 320"
sleep 3

# 8k 随机读
./fio_ceph_benchmark.sh --storage_type iSCSI --filename /dev/sdc --rw randread --bs 8k --size 50G --runtime 30 --numjobs_array "8 16 24 28 32 64" --iodepth_array "16 32 64 128 192 256 320"
sleep 3

# 128k 顺序写
./fio_ceph_benchmark.sh --storage_type iSCSI --filename /dev/sdc --rw write --bs 128k --size 50G --runtime 30 --numjobs_array "8 16 24 28 32 64" --iodepth_array "16 32 64 128 192 256 320"
sleep 3

# 128k 随机读
./fio_ceph_benchmark.sh --storage_type iSCSI --filename /dev/sdc --rw randread --bs 128k --size 50G --runtime 30 --numjobs_array "8 16 24 28 32 64" --iodepth_array "16 32 64 128 192 256 320"
sleep 3

# 1024k 顺序写
./fio_ceph_benchmark.sh --storage_type iSCSI --filename /dev/sdc --rw write --bs 1024k --size 50G --runtime 30 --numjobs_array "8 16 24 28 32 64" --iodepth_array "16 32 64 128 192 256 320"
sleep 3

# 1024k 随机读
./fio_ceph_benchmark.sh --storage_type iSCSI --filename /dev/sdc --rw randread --bs 1024k --size 50G --runtime 30 --numjobs_array "8 16 24 28 32 64" --iodepth_array "16 32 64 128 192 256 320"
sleep 3

# 8k 随机混合读写，读70%
./fio_ceph_benchmark.sh --storage_type iSCSI --filename /dev/sdc --rw randrw --rwmixread 70 --bs 8k --size 50G --runtime 30 --numjobs_array "8 16 24 28 32 64" --iodepth_array "16 32 64 128 192 256 320"
sleep 3

# 另存日志目录
mv -T /tmp/fio /tmp/fio-ceph-iscsi-$(date +%F-%H-%M-%S)
