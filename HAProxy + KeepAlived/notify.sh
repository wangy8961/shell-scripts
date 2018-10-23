#!/bin/bash
# Author: wangy
# description: An example of notify script
# Usage: notify.sh {mater|backup} VVIP

vvip=$2
contact=252954311@qq.com

Usage (){
    echo "Usage: `basename $0` {mater|backup} VVIP"
}

Notify() {
    subject="`hostname` to be $1: $vvip floating"
    content="`date '+%F %H:%M:%S'`, vrrp transition, `hostname` changed to be $1."
    echo $content | mail -s "$subject" $contact
}

[ $# -lt 2 ] && Usage && exit 1

case $1 in
    master)
        Notify master
        ;;
    backup)
        Notify backup
        ;;
    fault)
        Notify fault
        ;;
    *)
        Usage
        exit 1
    ;;
esac