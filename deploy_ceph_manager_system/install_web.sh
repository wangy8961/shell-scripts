#!/bin/bash
# Version: 1.0
# Email: wangy8961@163.com
# Description: 部署赞存分布式存储: 配置Web管理程序（在Admin节点运行此脚本）
# @Author: wangy
# @Date:   2016-12-21 16:41:42
# @Last Modified by:   wangy
# @Last Modified time: 2017-07-06 14:04:35

#-------------------------------------------------------------------------------
# Shell脚本基础设置
#-------------------------------------------------------------------------------

#set -e
#set -x

# unset any variable which system may be using
unset tcreset mysql_master_temp_pass mysql_slave_temp_pass

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
    The tool can help you to deploy the ssa web(redis、mysql、tomcat) envirement automatically.
    Please run such as './install_web.sh -d /root/ssa-V2.5.6 -r 172.18.0.3 -m 172.18.0.1 -s 172.18.0.2 -w "172.18.0.1 172.18.0.2"'

Options:
  --help | -h
    Print usage information.
  --ssa_dir | -d
    Set the ssa software directory
  --redis_ip | -r
    Set the public network ip of redis server
  --mysql_master_ip | -m
    Set the public network ip of mysql master server
  --mysql_slave_ip | -s
    Set the public network ip of mysql slave server
  --web_ips | -w
    Set the public network ip of Web Servers(Tomcat)
EOF
    exit 0
}


#-------------------------------------------------------------------------------
# 参数设置
#-------------------------------------------------------------------------------

# 默认参数值（部分参数一般无需用户指定，将使用默认值）
# Linux系统用户名
linux_username="root"
# Linux系统root用户密码
linux_password="password"
# MySQL数据库root用户密码
mysql_root_pass="pass1234"
# 指定后台Job运行节点主机名（Admin节点）
schedule_host=$(hostname -s)

# 获取命令行参数值
while [ $# -gt 0 ]; do
    case "$1" in
        --help | -h) usage ;;
        --ssa_dir | -d) shift; ssa_dir=$1 ;;
        --redis_ip | -r) shift; redis_ip=$1 ;;
        --mysql_master_ip | -m) shift; mysql_master_ip=$1 ;;
        --mysql_slave_ip | -s) shift; mysql_slave_ip=$1 ;;
        --web_ips | -w) shift; web_ips=$1 ;;
        *) shift ;;
    esac
    shift
done

# 如果未指定命令行参数，则提示用户手动交互输入
while [[ ! -d "${ssa_dir}" ]]; do
    echo -n -e '\E[32;1m'"Please set the valid ssa software directory, eg. /root/ssa-V2.5.6 : " ${tcreset}
    read ssa_dir
    echo ""
done

while [[ -z "${redis_ip}" ]]; do
    echo -n -e '\E[32;1m'"Please set the public network ip of redis server, eg. 172.18.0.3 : " ${tcreset}
    read redis_ip
    echo ""
done

while [[ -z "${mysql_master_ip}" ]]; do
    echo -n -e '\E[32;1m'"Please set the public network ip of mysql master server, eg. 172.18.0.1 : " ${tcreset}
    read mysql_master_ip
    echo ""
done

while [[ -z "${mysql_slave_ip}" ]]; do
    echo -n -e '\E[32;1m'"Please set the public network ip of mysql slave server, eg. 172.18.0.2 : " ${tcreset}
    read mysql_slave_ip
    echo ""
done

while [[ -z "${web_ips}" ]]; do
    echo -n -e '\E[32;1m'"Please set the public network ip of web servers, eg. \"172.18.0.1 172.18.0.2\" : " ${tcreset}
    read web_ips
    echo ""
done


#-------------------------------------------------------------------------------
# 功能函数
#-------------------------------------------------------------------------------

# 结合expect，实现Admin节点与其它节点基于SSH无密码通信，且配置过程无需用户介入
function ssh_copy_id_expect() {
    # 检查是否安装了expect软件包
    if [[ ! `rpm -qa | grep expect` ]]; then
        echo ""
        echo -e '\E[31;1m'"Please install expect first, eg. yum -y install expect" ${tcreset}
        echo ""
        exit 1
    fi

    /usr/bin/expect -c "
        spawn ssh-copy-id -i /${1}/.ssh/id_rsa.pub ${1}@${3}
        expect {
            \"*(yes/no)?\" { send \"yes\r\"; exp_continue }
            \"*password:\" { send \"${2}\r\" }
        }
        expect eof
    "
}


#-------------------------------------------------------------------------------
# main 主程序执行部分
#-------------------------------------------------------------------------------

# 配置SSH认证，Admin节点创建SSH密钥对（不需要用户交互）
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Generate ssh authentication key" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo ""

if [[ ! -f /${linux_username}/.ssh/id_rsa ]]; then
    ssh-keygen -t rsa -P "" -f /${linux_username}/.ssh/id_rsa
else
    ls -l /${linux_username}/.ssh/
fi

# 安装包内shell脚本授权
cd ${ssa_dir}
chmod +x deploy-db/*.sh
chmod +x deploy-aoss/*.sh


#-------------------------------------------------------------------------------
# 安装Redis
#-------------------------------------------------------------------------------

echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Install Redis Server" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
# 配置Admin节点与Redis节点基于SSH免密码登录
echo ""
echo -e '\E[31;1m'"Copy SSH public key to Redis Server: " ${tcreset}
ssh_copy_id_expect ${linux_username} ${linux_password} ${redis_ip}

# 传输ssa安装包(SSA安装目录不存在时才传输)
ssh ${linux_username}@${redis_ip} "ls -d ${ssa_dir}"
if [[ $? -ne 0 ]]; then
    echo ""
    echo -e '\E[31;1m'"SCP the SSA pakage to Redis Server: " ${tcreset}
    scp -r ${ssa_dir} ${linux_username}@${redis_ip}:${ssa_dir}
else
    echo ""
    echo -e '\E[32;1m'"SSA pakage already exists!" ${tcreset}
fi

# SSH连接到Redis节点，安装Redis软件包，并重启该节点
echo ""
echo -e '\E[31;1m'"Install the redis(el7) RPM: " ${tcreset}
ssh ${linux_username}@${redis_ip} "cd ${ssa_dir}/deploy-db; sh ./install_redis_el7.sh; reboot now"


#-------------------------------------------------------------------------------
# 配置MySQL主节点
#-------------------------------------------------------------------------------
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Install MySQL Master" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

# 配置Admin节点与MySQL master节点基于SSH免密码登录
echo ""
echo -e '\E[31;1m'"Copy SSH public key to MySQL Master Server: " ${tcreset}
ssh_copy_id_expect ${linux_username} ${linux_password} ${mysql_master_ip}

# 传输ssa安装包(SSA安装目录不存在时才传输)
ssh ${linux_username}@${mysql_master_ip} "ls -d ${ssa_dir}"
if [[ $? -ne 0 ]]; then
    echo ""
    echo -e '\E[31;1m'"SCP the SSA pakage to MySQL Master Server: " ${tcreset}
    scp -r ${ssa_dir} ${linux_username}@${mysql_master_ip}:${ssa_dir}
else
    echo ""
    echo -e '\E[32;1m'"SSA pakage already exists!" ${tcreset}
fi

# 1. SSH连接到MySQL主节点，安装MySQL软件包
echo ""
echo -e '\E[31;1m'"Install the mysql-server RPM: " ${tcreset}
ssh ${linux_username}@${mysql_master_ip} "cd ${ssa_dir}/deploy-db; sh ./install_mysql_el7.sh"

# 2. 修改初始密码
# 获取临时root密码
sleep 5
mysql_master_temp_pass=$(ssh ${linux_username}@${mysql_master_ip} "grep 'temporary password' /var/log/mysqld.log" | awk -F'root@localhost:' '{print $2}' | awk -F' ' '{print $1}')
echo ""
echo -e '\E[31;1m'"MySQL master temp password: ${mysql_master_temp_pass}" ${tcreset}

echo ""
echo -e '\E[31;1m'"Change the mysql root password to ${mysql_root_pass}" ${tcreset}
ssh ${linux_username}@${mysql_master_ip} "
    # 修改MySQL密码策略
    mysql -uroot -p'${mysql_master_temp_pass}' --connect-expired-password -e \"set global validate_password_policy=0;\"
    # 修改MySQL的root密码
    mysql -uroot -p'${mysql_master_temp_pass}' --connect-expired-password -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_pass}';\"
"

# 3. 初始化数据库
echo ""
echo -e '\E[31;1m'"Init aossdb: " ${tcreset}
ssh ${linux_username}@${mysql_master_ip} "
    cd ${ssa_dir}/deploy-db
    sh ./init_aossdb.sh
"

# 4. 创建Web用户并授权, 默认aoss/pass1234
echo ""
echo -e '\E[31;1m'"Create mysql user for AOSS-WEB ('aoss'@'*', password: pass1234): " ${tcreset}
ssh ${linux_username}@${mysql_master_ip} "
    mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"CREATE USER 'aoss'@'*' IDENTIFIED BY 'pass1234';\"
"

for web_ip in ${web_ips[@]}; do
    ssh ${linux_username}@${mysql_master_ip} "
        mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"GRANT ALL PRIVILEGES ON aossdb.* TO 'aoss'@'${web_ip}' IDENTIFIED BY 'pass1234' WITH GRANT OPTION;\"
    "
done

ssh ${linux_username}@${mysql_master_ip} "
    mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"FLUSH PRIVILEGES;\"
"

# 5. 指定后台Job运行节点
echo ""
echo -e '\E[31;1m'"Insert the hostname of schedule into aossdb.csp_aoss_sys_config: " ${tcreset}
ssh ${linux_username}@${mysql_master_ip} "
    mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"insert into aossdb.csp_aoss_sys_config(id,name,value) values(UUID(),'schedule_host','${schedule_host}');\"
"

# 6. 配置主从
echo ""
echo -e '\E[31;1m'"Configurate MySQL master(create slave user, modify /etc/my.cnf, restart mysqld): " ${tcreset}
ssh ${linux_username}@${mysql_master_ip} "
    # 创建slave账号, 默认slave/pass1234
    mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"GRANT REPLICATION SLAVE ON *.* TO 'slave'@'${mysql_slave_ip}' IDENTIFIED BY 'pass1234';\"
    mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"FLUSH PRIVILEGES;\"

    # 修改/etc/my.cnf配置文件
    cat >> /etc/my.cnf << EOF

# MySQL replication: Master Configuration
log-bin = mysql-bin
binlog_format = mixed
server-id = 1
read-only = 0
binlog-do-db=aossdb
log_bin_trust_function_creators=1
EOF

    # 重启MySQL
    systemctl restart mysqld
"

# 查询Master status
ssh ${linux_username}@${mysql_master_ip} "
    mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"show master status\G;\"
" > /tmp/mysql_master_status.log

echo ""
echo -e '\E[31;1m'"Show master status: " ${tcreset}
cat /tmp/mysql_master_status.log
sleep 3
master_log_file=$(grep 'File' /tmp/mysql_master_status.log | cut -d: -f2 | sed 's/^[ \t]*//g')
master_log_pos=$(grep 'Position' /tmp/mysql_master_status.log | cut -d: -f2 | sed 's/^[ \t]*//g')


#-------------------------------------------------------------------------------
# 配置MySQL从节点
#-------------------------------------------------------------------------------
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Install MySQL Slave" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

# 配置Admin节点与MySQL slave节点基于SSH免密码登录
echo ""
echo -e '\E[31;1m'"Copy SSH public key to MySQL Slave Server: " ${tcreset}
ssh_copy_id_expect ${linux_username} ${linux_password} ${mysql_slave_ip}

# 传输ssa安装包(SSA安装目录不存在时才传输)
ssh ${linux_username}@${mysql_slave_ip} "ls -d ${ssa_dir}"
if [[ $? -ne 0 ]]; then
    echo ""
    echo -e '\E[31;1m'"SCP the SSA pakage to MySQL Slave Server: " ${tcreset}
    scp -r ${ssa_dir} ${linux_username}@${mysql_slave_ip}:${ssa_dir}
else
    echo ""
    echo -e '\E[32;1m'"SSA pakage already exists!" ${tcreset}
fi

# 1. SSH连接到MySQL主节点，安装MySQL软件包
echo ""
echo -e '\E[31;1m'"Install the mysql-server RPM: " ${tcreset}
ssh ${linux_username}@${mysql_slave_ip} "cd ${ssa_dir}/deploy-db; sh ./install_mysql_el7.sh"

# 2. 修改初始密码
# 获取临时root密码
sleep 5
mysql_slave_temp_pass=$(ssh ${linux_username}@${mysql_slave_ip} "grep 'temporary password' /var/log/mysqld.log" | awk -F'root@localhost:' '{print $2}' | awk -F' ' '{print $1}')
echo ""
echo -e '\E[31;1m'"MySQL slave temp password: ${mysql_slave_temp_pass}" ${tcreset}

echo ""
echo -e '\E[31;1m'"Change the mysql root password to ${mysql_root_pass}" ${tcreset}
ssh ${linux_username}@${mysql_slave_ip} "
    # 修改MySQL密码策略
    mysql -uroot -p'${mysql_slave_temp_pass}' --connect-expired-password -e \"set global validate_password_policy=0;\"
    # 修改MySQL的root密码
    mysql -uroot -p'${mysql_slave_temp_pass}' --connect-expired-password -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_pass}';\"
"

# 3. 初始化数据库
echo ""
echo -e '\E[31;1m'"Init aossdb: " ${tcreset}
ssh ${linux_username}@${mysql_slave_ip} "
    cd ${ssa_dir}/deploy-db
    sh ./init_aossdb.sh
"

# 4. 创建Web用户并授权, 默认aoss/pass1234
echo ""
echo -e '\E[31;1m'"Create mysql user for AOSS-WEB ('aoss'@'*', password: pass1234): " ${tcreset}
ssh ${linux_username}@${mysql_slave_ip} "
    mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"CREATE USER 'aoss'@'*' IDENTIFIED BY 'pass1234';\"
"

for web_ip in ${web_ips[@]}; do
    ssh ${linux_username}@${mysql_slave_ip} "
        mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"GRANT ALL PRIVILEGES ON aossdb.* TO 'aoss'@'${web_ip}' IDENTIFIED BY 'pass1234' WITH GRANT OPTION;\"
    "
done

ssh ${linux_username}@${mysql_slave_ip} "
    mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"FLUSH PRIVILEGES;\"
"

# 5. 指定后台Job运行节点
echo ""
echo -e '\E[31;1m'"Insert the hostname of schedule into aossdb.csp_aoss_sys_config: " ${tcreset}
ssh ${linux_username}@${mysql_slave_ip} "
    mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"insert into aossdb.csp_aoss_sys_config(id,name,value) values(UUID(),'schedule_host','${schedule_host}');\"
"

# 6. 配置主从
echo ""
echo -e '\E[31;1m'"Configurate MySQL master(modify /etc/my.cnf, restart mysqld): " ${tcreset}
ssh ${linux_username}@${mysql_slave_ip} "
    # 修改/etc/my.cnf配置文件
    cat >> /etc/my.cnf << EOF

# MySQL replication: Slave Configuration
log-bin = mysql-bin
binlog_format = mixed
server-id=2
replicate-do-db=aossdb
relay_log=mysqld-relay-bin
log_bin_trust_function_creators=1
EOF

    # 重启MySQL
    systemctl restart mysqld
"

# MySQL从数据库配置master信息
echo ""
echo -e '\E[31;1m'"Change master to MySQL Master Server: " ${tcreset}
ssh ${linux_username}@${mysql_slave_ip} "
    mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"CHANGE MASTER TO MASTER_HOST='${mysql_master_ip}',MASTER_USER='slave', MASTER_PASSWORD='pass1234', MASTER_LOG_FILE='${master_log_file}', MASTER_LOG_POS=${master_log_pos};\"
"

# 重启MySQL
ssh ${linux_username}@${mysql_slave_ip} "systemctl restart mysqld"

# 验证slave status
echo ""
echo -e '\E[31;1m'"Show slave status: " ${tcreset}
ssh ${linux_username}@${mysql_slave_ip} "
    mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"show slave status\G;\"
"


#-------------------------------------------------------------------------------
# 部署WEB管理组件（AOSS-WEB）
#-------------------------------------------------------------------------------
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Install AOSS-WEB" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

# 检查Admin是否能够连接Redis Server(因为重启过)
echo ""
echo -e '\E[31;1m'"Check whether it can connect Redis Server: " ${tcreset}
while true ; do
    ping -c10 ${redis_ip}
    if [[ $? -eq 0 ]]; then
        sleep 30
        break
    fi
done

# 检查Redis节点是否已成功部署完Redis
ssh ${linux_username}@${redis_ip} "ps -ef | grep 'redis' | grep -v 'grep'"

while [[ $? -eq 0 ]] ; do
    # 如果Redis Server正常，则开始部署Web Server
    echo ""
    echo -e '\E[31;1m'"Admin can connect to Redis Server, and the redis service is on: " ${tcreset}
    for web_ip in ${web_ips[@]}; do
        # 配置Admin节点与Web节点基于SSH免密码登录
        echo ""
        echo -e '\E[31;1m'"Copy SSH public key to Web Server(${web_ip}): " ${tcreset}
        ssh_copy_id_expect ${linux_username} ${linux_password} ${web_ip}

        # 传输ssa安装包(SSA安装目录不存在时才传输)
        ssh ${linux_username}@${web_ip} "ls -d ${ssa_dir}"
        if [[ $? -ne 0 ]]; then
            echo ""
            echo -e '\E[31;1m'"SCP the SSA pakage to Web Server(${web_ip}): " ${tcreset}
            scp -r ${ssa_dir} ${linux_username}@${web_ip}:${ssa_dir}
        else
            echo ""
            echo -e '\E[32;1m'"SSA pakage already exists!" ${tcreset}
        fi

        # SSH连接到Web节点，安装Tomcat软件包
        echo ""
        echo -e '\E[31;1m'"Install tomcat and start service(${web_ip}): " ${tcreset}
        ssh ${linux_username}@${web_ip} "
            cd ${ssa_dir}/deploy-aoss
            sh ./deploy.sh ${mysql_master_ip} ${redis_ip}
            sed -i s/AOSS-WEB-IP/${web_ip}/ /usr/local/aoss/tomcat/aoss-conf/ssa.properties

            # 启动服务
            sed -i s/'JRE_HOME=\/usr\/lib\/jvm\/jre-1.7.0-openjdk.x86_64'/'JAVA_HOME=\/usr\/lib\/jvm\/java-1.7.0'/ /usr/local/aoss/tomcat/bin/catalina.sh
            cd /usr/local/aoss/tomcat/bin/
            sh ./startup.sh
        "
    done

    break
done


#-------------------------------------------------------------------------------
# 赞存分布式存储AOSS-WEB部署完毕
#-------------------------------------------------------------------------------
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Success" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

web_arr=(${web_ips})  # Web IPs字符串转换为数组
echo ""
echo -e '\E[31;1m'"The installation is complete! Please visit http://${web_arr[0]}:8080/ssa OR http://${web_arr[1]}:8080/ssa" ${tcreset}
echo ""
