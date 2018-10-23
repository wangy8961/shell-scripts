#!/bin/bash

# 获取TB级别的数据盘对应的Virtual Disk ID，不包括SAS组成的系统盘，因为它一般是几百GB
L=$(/opt/MegaRAID/MegaCli/MegaCli64 -CfgDsply -aALL|grep -E "Raw Size:|Virtual Drive:"|grep -B 1 "[0-9] TB"|grep "Virtual Drive:"|awk -F : '{print $2}'|cut -b 1-3|sed 's/^[ \t]*//g')

for i in $L; do
    if [[ $(/opt/MegaRAID/MegaCli/MegaCli64 -LDGetProp -DskCache -LALL -a0|grep -w "target id: $i"|awk '{print $NF}') = "Disabled" ]]; then
        # 如果此Virtual Disk已经被禁用了缓存，则只输出提示信息
        echo "Virtual Drive: $i is Disabled"
    else
        # 禁用缓存
        /opt/MegaRAID/MegaCli/MegaCli64 -LDSetProp -DisDskCache -L$i -a0
    fi
done
