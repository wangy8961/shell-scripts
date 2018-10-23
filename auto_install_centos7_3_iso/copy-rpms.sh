#!/bin/bash
rpm -qa  > package-list.txt
old_rpms='/mnt/cdrom/Packages'
new_rpms='/tmp/iso/Packages'
while read line; do
    cp ${old_rpms}/${line}*.rpm ${new_rpms} || echo "${line} not exist..."
done < package-list.txt
rm -f package-list.txt
