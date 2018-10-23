#!/bin/bash
# Version: 1.0
# Email: wangy8961@163.com
# Description: 部署赞存分布式存储: 配置RadosGW对象网关（在Admin节点运行此脚本）
# @Author: wangy
# @Date:   2016-12-21 16:41:42
# @Last Modified by:   wangy
# @Last Modified time: 2017-05-11 11:34:17

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
    The tool can help you to deploy the ceph radosgw envirement automatically.
    Please run such as:
        ./install_radosgw.sh -g "172.18.0.1 172.18.0.2" -m 172.18.0.1

Options:
  --help | -h
    Print usage information.
  --gateway_ips | -g
    Set the public network ip of ceph radosgw servers
  --mysql_master_ip | -m
    Set the public network ip of mysql master server
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


# 获取命令行参数值
while [ $# -gt 0 ]; do
    case "$1" in
        --help | -h) usage ;;
        --gateway_ips | -g) shift; gateway_ips=$1 ;;
        --mysql_master_ip | -m) shift; mysql_master_ip=$1 ;;
        *) shift ;;
    esac
    shift
done

# 如果未指定命令行参数，则提示用户手动交互输入
while [[ -z "${gateway_ips}" ]]; do
    echo -n -e '\E[32;1m'"Please set the public network ip of ceph radosgw servers, eg. \"172.18.0.1 172.18.0.2\" : " ${tcreset}
    read gateway_ips
    echo ""
done
# 字符串"172.18.0.1 172.18.0.2"转换成数组(172.18.0.1 172.18.0.2)
gateway_ips=(${gateway_ips})

while [[ -z "${mysql_master_ip}" ]]; do
    echo -n -e '\E[32;1m'"Please set the public network ip of mysql master server, eg. 172.18.0.1 : " ${tcreset}
    read mysql_master_ip
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

# 配置Admin节点与各RadosGW节点基于SSH免密码登录
echo ""
echo -e '\E[31;1m'"Copy SSH public key to all ceph storage cluster hosts: " ${tcreset}

# 通过aossdb数据库中csp_aoss_ceph_host表，获取Ceph集群所有主机（包括存储节点和网关节点）
ssh_copy_id_expect ${linux_username} ${linux_password} ${mysql_master_ip}
ssh ${linux_username}@${mysql_master_ip} "mysql -uroot -p${mysql_root_pass} --connect-expired-password -e \"select ip from aossdb.csp_aoss_ceph_host;\"" | awk 'NR>1 {print $0}'> /tmp/csp_aoss_ceph_hosts.txt

cat /tmp/csp_aoss_ceph_hosts.txt | while read line; do
    ssh_copy_id_expect ${linux_username} ${linux_password} ${line}
    echo ""
done


#-------------------------------------------------------------------------------
# 配置Ceph radosgw认证
#-------------------------------------------------------------------------------
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Configure ceph radosgw authentication" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

# 创建空的秘钥环（keyring）
echo ""
echo -e '\E[31;1m'"Create a new keyring, overwriting any existing keyringfile" ${tcreset}
ceph-authtool --create-keyring /etc/ceph/ceph.client.radosgw.keyring
chmod +r /etc/ceph/ceph.client.radosgw.keyring
cat /etc/ceph/ceph.client.radosgw.keyring


# 为每个实例生成Ceph对象网关用户名和密钥
echo ""
echo -e '\E[31;1m'"Generate a new secret key for the specified entityname" ${tcreset}
for ((i=1; i<=${#gateway_ips[@]}; i++)) {
    ceph-authtool /etc/ceph/ceph.client.radosgw.keyring -n client.radosgw.gateway${i} --gen-key
}
cat /etc/ceph/ceph.client.radosgw.keyring


# 授予每个密钥key对mon和osd的相应权限
echo ""
echo -e '\E[31;1m'"Allow privilege for every ceph radosgw entity" ${tcreset}
for ((i=1; i<=${#gateway_ips[@]}; i++)) {
    ceph-authtool -n client.radosgw.gateway${i} --cap osd 'allow rwx' --cap mon 'allow rwx' /etc/ceph/ceph.client.radosgw.keyring
}
cat /etc/ceph/ceph.client.radosgw.keyring


# 一旦你创建了keyring和密钥，使Ceph对象网关能访问Ceph对象集群，作为入口添加每个密钥到你的Ceph存储集群
echo ""
echo -e '\E[31;1m'"Add the keyringfile to Ceph" ${tcreset}
for ((i=1; i<=${#gateway_ips[@]}; i++)) {
    ceph -k /etc/ceph/ceph.client.admin.keyring auth add client.radosgw.gateway${i} -i /etc/ceph/ceph.client.radosgw.keyring
}


# 修改/etc/ceph/ceph.conf，添加各对象网关的实例配置信息
echo ""
echo -e '\E[31;1m'"Append [client.radosgw.gateway] to /etc/ceph/ceph.conf" ${tcreset}
for ((i=1; i<=${#gateway_ips[@]}; i++)) {
    hostname=$(ssh ${linux_username}@${gateway_ips[${i}-1]} "hostname -s")

    cat >> /etc/ceph/ceph.conf << EOF
[client.radosgw.gateway${i}]
    host = ${hostname}
    keyring = /etc/ceph/ceph.client.radosgw.keyring
    rgw socket path = /var/run/ceph/ceph-client.radosgw.gateway${i}.sock
    log file = /var/log/radosgw/client.radosgw.gateway${i}.log
    rgw frontends = fastcgi socket_port=9000 socket_host=0.0.0.0
    rgw print continue = false
EOF
}
# 输出刚添加的内容
sed -n '/client.radosgw.gateway/,$ p' /etc/ceph/ceph.conf


# 将配置文件/etc/ceph/ceph.conf同步到所有其它集群节点
echo ""
echo -e '\E[31;1m'"Scp /etc/ceph/ceph.conf to all ceph cluster hosts" ${tcreset}
cat /tmp/csp_aoss_ceph_hosts.txt | while read line; do
    echo "${line}"
    scp /etc/ceph/ceph.conf ${linux_username}@${line}:/etc/ceph
    echo ""
done


# 将/etc/ceph/ceph.client.radosgw.keyring同步到所有对象网关节点
echo -e '\E[31;1m'"Scp /etc/ceph/ceph.client.radosgw.keyring to all radosgw hosts" ${tcreset}
for gw in ${gateway_ips[@]}; do
    echo "${gw}"
    scp /etc/ceph/ceph.client.radosgw.keyring ${linux_username}@${gw}:/etc/ceph
    echo ""
done


#-------------------------------------------------------------------------------
# 配置所有对象网关节点上的httpd服务
#-------------------------------------------------------------------------------
echo ""
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Configure the httpd of all radosgw hosts" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

for gw in ${gateway_ips[@]}; do
    # 是否安装httpd （OS默认安装了Apache版本2.4.6，并启用了mod_proxy mod_proxy_fcgi mod_rewrite动态模块）
    echo ""
    echo -e '\E[31;1m'"Installed httpd on ${gw} ?" ${tcreset}
    ssh ${linux_username}@${gw} "rpm -qa|grep -E 'httpd-[[:digit:]]+'"
    if [[ $? -ne 0 ]]; then
        echo -e '\E[32;1m'"Please install httpd first on then Ceph RadosGW Server ${gw}" ${tcreset}
        exit 1
    fi

    # 获取各对象网关的主机名
    gw_hostname=$(ssh ${linux_username}@${gw} "hostname -s")

    # 配置httpd: 修改/etc/httpd/conf/httpd.conf
    echo ""
    echo -e '\E[31;1m'"Modify /etc/httpd/conf/httpd.conf on ${gw} " ${tcreset}
    ssh ${linux_username}@${gw} "sed -i \"s@#ServerName www.example.com:80@ServerName ${gw_hostname}@\" /etc/httpd/conf/httpd.conf"
    echo "change #ServerName www.example.com:80 to ServerName ${gw_hostname}"

    ssh ${linux_username}@${gw} "sed -i 's@DocumentRoot \"/var/www/html\"@#DocumentRoot \"/var/www/html\"@' /etc/httpd/conf/httpd.conf"
    echo "change DocumentRoot \"/var/www/html\" to #DocumentRoot \"/var/www/html\""

    # 创建radosgw虚拟主机
    echo ""
    echo -e '\E[31;1m'"Create /etc/httpd/conf.d/rgw.conf on ${gw}" ${tcreset}
    ssh ${linux_username}@${gw} "cat > /etc/httpd/conf.d/rgw.conf <<-EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/html
    ErrorLog /var/log/httpd/rgw_error.log
    CustomLog /var/log/httpd/rgw_access.log combined
    # LogLevel debug
    RewriteEngine On
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization},L]
    SetEnv proxy-nokeepalive 1
    ProxyPass / fcgi://localhost:9000/
</VirtualHost>
EOF"
    ssh ${linux_username}@${gw} "cat /etc/httpd/conf.d/rgw.conf"
    echo ""

    # 启用httpd服务
    echo -e '\E[31;1m'"Start httpd on ${gw}" ${tcreset}
    ssh ${linux_username}@${gw} "systemctl start httpd"
    ssh ${linux_username}@${gw} "ps -ef | grep -v 'grep' | grep 'httpd'"
    echo ""
done


#-------------------------------------------------------------------------------
# 在所有节点上重启整个Ceph Storage Cluster集群
#-------------------------------------------------------------------------------
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Restart ceph storage cluster" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

host_str=$(cat /tmp/csp_aoss_ceph_hosts.txt)
host_arr=(${host_str})
for host in ${host_arr[@]}; do
    echo "${host}"
    ssh ${linux_username}@${host} "service ceph restart"
    echo ""
    sleep 1
done

sleep 10

# 判断ceph -s状态恢复正常后
while true; do
    ceph -s | grep -E 'stale|degraded|undersized|peering|stuck inactive|stuck unclean'
    if [[ $? -eq 0 ]]; then
        echo ""
        echo -e '\E[31;1m'"Hold on, please wait ceph cluster to be ready..." ${tcreset}
        echo ""
        sleep 10
    else
        echo -e '\E[31;1m'"shell> ceph -s" ${tcreset}
        ceph -s
        echo ""
        break
    fi
done


#-------------------------------------------------------------------------------
# 在所有对象网关节点上，重启httpd和ceph-radosgw服务
#-------------------------------------------------------------------------------
echo ""
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Enable and restart httpd/ceph-radosgw on all radosgw hosts" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}

for gw in ${gateway_ips[@]}; do
    # 重启httpd，并设置其开机启动
    echo ""
    echo -e '\E[31;1m'"Enable and restart httpd on ${gw}" ${tcreset}
    ssh ${linux_username}@${gw} "systemctl enable httpd"
    ssh ${linux_username}@${gw} "systemctl restart httpd"
    ssh ${linux_username}@${gw} "ps -ef | grep -v 'grep' | grep 'httpd'"

    sleep 5

    # 重启ceph-radosgw，并设置其开机启动
    echo ""
    echo -e '\E[31;1m'"Enable and restart ceph-radosgw on ${gw}" ${tcreset}
    ssh ${linux_username}@${gw} "chkconfig ceph-radosgw on"
    ssh ${linux_username}@${gw} "/etc/init.d/ceph-radosgw restart"

    sleep 30

    # 判断ceph-radosgw的状态
    echo ""
    echo -e '\E[31;1m'"Whether ceph-radosgw success on ${gw} ? " ${tcreset}
    ssh ${linux_username}@${gw} "curl -X GET http://127.0.0.1 -i"
    ssh ${linux_username}@${gw} "curl -X GET http://127.0.0.1 -i" > /tmp/ceph-radosgw-${gw}.txt
    grep 'HTTP/1.1 200 OK' /tmp/ceph-radosgw-${gw}.txt &> /dev/null
    if [[ $? -ne 0 ]]; then
        echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
        echo -e '\E[31;1m'"Ceph RadosGW Server ${gw} not success, " ${tcreset}
        echo -e '\E[31;1m'"please restart ceph/httpd/ceph-radosgw !" ${tcreset}
        echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
        exit 1
    fi
done


#-------------------------------------------------------------------------------
# 创建RGW Admin用户
#-------------------------------------------------------------------------------
echo ""
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Create radosgw admin user" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
radosgw-admin user create --uid=admin --display-name="admin" > /tmp/radosgw-admin-user.txt
radosgw-admin caps add --caps="users=*;buckets=*;zone=*;metadata=*;usage=*" --uid=admin &> /dev/null

access_key=`sed -n 's/ *"access_key": "\(.*\)",/\1/p' /tmp/radosgw-admin-user.txt`
secret_key=`sed -n 's/ *"secret_key": "\(.*\)"/\1/p' /tmp/radosgw-admin-user.txt`

echo -e '\E[31;1m'"USER: " ${tcreset} "admin"
echo -e '\E[31;1m'"ACCESS_KEY: " ${tcreset} ${access_key}
echo -e '\E[31;1m'"SECRET_KEY: " ${tcreset} ${secret_key}


# 成功退出
echo ""
echo ""
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo -e '\E[32;1m'"Success" ${tcreset}
echo -e '\E[32;1m'"------------------------------------------------------" ${tcreset}
echo ""
exit 0

