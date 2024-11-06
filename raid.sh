#!/bin/bash

set -ex
#warning判断
if [ "$1" = "-y" ];then
    :
elif [ "$1" = "" ];then
    read -p "Warning:执行前请确认关闭docker等可能对机械硬盘有读写的程序，同时脚本会清空机械硬盘里面的数据，确定要执行吗(yes/no)" judge
    if [ "$judge" = "yes" ];then
        :
    else
        exit 1
    fi
else
    echo unknow arguments && exit 1
fi

#环境准备
sudo apt-get update && sudo apt-get install mdadm gdisk -y

#获取机械硬盘名称
disk=$(lsblk -o name,type,rota,rm | grep disk | awk '{if (($4==0)&&($3==1)) print}' | awk '{ print $1 }' | sed "s:s:/dev/s:g")

#获取现有磁盘的阵列信息，如果有raid，将其还原
if [[ "$(lsblk -o type | grep raid)" != "" ]];then
    md=$(lsblk -o kname,type | grep raid | head -1 | awk '{ print $1 }' | sed "s:m:/dev/m:g")
    mountpoint=$(lsblk -o type,mountpoint | grep raid | awk '{print $2}' | head -1)
    if [[ $mountpoint != "" ]];then
        sudo umount $mountpoint
    fi
    sudo sed -i '/\/media\/tx-deepocean\/Data/d' /etc/fstab
    sudo mdadm --stop $md
    sudo mdadm --remove $md || true
    sudo mdadm --zero-superblock $disk
    sudo sed -i '/\/dev\/md/d' /etc/mdadm/mdadm.conf
    sudo update-initramfs -u

#获取现在磁盘的阵列信息，如果有lvm，将其还原
elif [[ "$(lsblk -o type | grep lvm)" != "" ]];then
    lvm=$(sudo vgs -o name --noheadings | awk '{ print $1 }')
    mountpoint=$(lsblk -o type,mountpoint | grep lvm | head -1 | awk '{print $2}')
    if [[ $mountpoint != "" ]];then
        sudo umount $mountpoint
    fi
    sudo vgchange -a n /dev/$lvm
    sudo vgremove /dev/$lvm << EOF
y
y
EOF
    sudo sed -i "/$(echo $mountpoint | sed 's/\//\\\//g')/d" /etc/fstab

#将磁盘解挂载
else
    for sdisk in ${disk[@]}
    do
        mountpoint=$(lsblk -o kname,mountpoint | grep `echo $sdisk | sed "s:/dev/::g"` | awk '{print $2}')
        for m in $mountpoint
        do
            if [[ $m != "" ]];then
                sudo umount $m
            fi
        done
    done
fi

#将磁盘内容清空
for sdisk in ${disk[@]}
do
    sudo dd if=/dev/zero of=$sdisk bs=512 count=1
done

#判断磁盘数量，若只有一块，就直接挂载
count=$(echo $disk | awk '{print NF;exit;}')
if [ $count == 1 ];then
    sudo gdisk $disk << EOF

o
y
n




w
y
EOF
    part=$(lsblk -o kname,type,rota,rm | grep part | awk '{if (($4==0)&&($3==1)) print}' | awk '{print $1}' | sed "s:s:/dev/s:g")
    sudo mkfs.ext4 -F $part
    sudo mkdir -p /media/tx-deepocean/Data
    sudo mount $part /media/tx-deepocean/Data
#开机自动挂载
    sudo sed -i "/\/media\/tx-deepocean\/Data/d" /etc/fstab
    echo "UUID=$(sudo lsblk -o name,uuid | grep `echo $part| sed "s:/dev/::g"` | head -1 | awk '{print $2}') /media/tx-deepocean/Data ext4 defaults,nofail,discard 0 0" | sudo tee -a /etc/fstab

else

#将现有磁盘组成raid
    sudo mdadm --create --verbose /dev/md0 --level=0 --raid-devices=$count $disk << EOF
y
EOF
#挂载，并记录分区表等信息
    sudo mkfs.ext4 -F /dev/md0
    sudo mkdir -p /media/tx-deepocean/Data
    sudo mount /dev/md0 /media/tx-deepocean/Data
#开机自动挂载
    sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
    sudo update-initramfs -u
    echo "UUID=$(sudo lsblk -o name,uuid | grep md | head -1 | awk '{print $2}') /media/tx-deepocean/Data ext4 nosuid,nodev,nofail 0 0" | sudo tee -a /etc/fstab
fi

#磁盘挂载完成，输出success
echo 'success!!!'

