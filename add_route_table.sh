#!/bin/bash

# 1. 清空路由表
ip route flush table mgr
# 2. 添加规则, 源地址为192.202.11.31的数据包，默认使用mgr路由表，再根据第3点，使用自定义路由表中的默认路由
ip rule add from 192.202.11.31 table mgr
# 3. 添加自定义路由表中默认路由条目
ip route add default via 192.202.11.254 dev crcmgr src 192.202.11.31 table mgr
# 4. 删除main路由表中默认添加的规则，否则192.202.11.31无法ping通192.202.11.32等(但可以ping通192.202.11.254等)，只可以ssh
ip route del 192.202.11.0/24
