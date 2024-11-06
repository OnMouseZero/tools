#!/bin/bash

set  -eu

current_date=$(date +'%Y-%m-%d') 
day_of_year=$(date -d "$current_date" +%j)
echo "今天是今年的第 $day_of_year 天。"

DIR="/ncsfs/rtcm/rinex/"
DIR1="/root/shell/"

if [[ ! -e $DIR1$((day_of_year-1)) ]]; then
    echo "当天文件的存储目录不存在,需要创建"
    mkdir  -p $DIR1$((day_of_year-1))
#    find $DIR1  -maxdepth 1 -type  f  -ctime -1 -exec  mv  {} $DIR1$((day_of_year-1))  \;
    find $DIR1  -maxdepth 1 -type  f  -name "*2024$((day_of_year-1))*" -exec  mv  {} $DIR1$((day_of_year-1))  \;
else
    echo "当天文件的存储目录已经存在，请假查，暂不进行文件移动"
fi
