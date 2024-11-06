#!/bin/bash

set  -eu

echo "备份开始时间：$(date +%H:%M:%S)"

mysql_container_name=`docker  ps | grep  3306  -i  | awk  '{print $NF}'`
postgre_container_name=`docker  ps | grep  5432  -i  | awk  '{print $NF}'`
mysql_dir="/root/UCEN/mysql_backup/mysql_$(date +%Y_%m_%d)"
postgre_dir="/root/UCEN/postgre_backup/postgre_$(date +%Y_%m_%d)"

if [[ ! -d /root/UCEN/mysql_backup ]];then
    echo "备份mysql数据的目录不存在，需要创建"
    mkdir -p /root/UCEN/mysql_backup
fi

if [[ ! -d /root/UCEN/postgre_backup ]];then
    echo "备份postgreSQL数据的目录不存在，需要创建"
    mkdir -p /root/UCEN/postgre_backup
fi

if [[ ! -z $mysql_container_name ]]; then
    if [[ ! -d $mysql_dir ]];then
        mkdir -p  $mysql_dir
        echo "开始备份mysql数据"
        docker exec $mysql_container_name  sh -c 'exec mysqldump --default-character-set=utf8mb4 -h 127.0.0.1 -uroot -p111111 --all-databases' > $mysql_dir/mysql_local_all.sql
    else
        echo "数据备份目录已经存在，请检查数据是否存在，不存在请删除目录再次执行！！！"
    fi
else
    echo "此服务器上不存在mysql容器服务，不进行数据备份"
fi

#备份PG数据库之前，需要给PG容器启动时候增加一项环境变量如下,不然脚本无法免密备份，会执行失败
#    PGPASSWORD=111111        
if [[ ! -z $postgre_container_name ]]; then
    if [[ ! -d $postgre_dir ]]; then
        mkdir -p $postgre_dir
        echo "开始备份postgre数据"
        docker exec $postgre_container_name  sh -c 'exec pg_dump -h 127.0.0.1 -U postgres  -d gis' > $postgre_dir/postgre_gis.sql
    fi
else
    echo "此服务器上不存在postgres容器服务，不进行数据备份"
fi

echo "完成备份时间：$(date +%H:%M:%S)"
