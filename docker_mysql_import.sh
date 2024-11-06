#!/usr/bin/bash

file_path=/home/ucen/UCEN/page/base/db/mysql/
docker exec  -it  mysql  mysql -uroot -p111111 -e "set foreign_key_checks = 0;"
#docker exec mysql mkdir /db

for x in  $file_path*; do
#    docker cp $x mysql:/db > /dev/null  2>&1
    sql_name=${x##*/}
    database_name=${sql_name%%.*}
  
    docker   exec  -it  mysql  mysql  -uroot  -p111111 -e  "show databases;"  | grep  -w -q $database_name
    if [[ $? -ne 0 ]];then
        echo "$database_name数据库不存在，需要创建！！！"
        docker exec  -it  mysql  mysql -uroot -p111111 -e 'create database `'"$database_name"'`'
    else
        echo "$database_name数据库已经存在。"   
    fi
#    docker exec  mysql  mysql -uroot -p111111  $database_name < $x > /dev/null 2>&1
    echo "===开始向$database_name数据库导入表和表结构==="
    docker exec -i  mysql  mysql -uroot -p111111 -t $database_name < $x
#    docker exec  mysql  mysql -uroot -p111111  -e "source /db/$sql_name" $database_name
done

docker exec  -it  mysql  mysql -uroot -p111111 -e "set foreign_key_checks = 1;"

#mysql数据备份
DIR="/home/ucen/UCEN/shell/mysql_$(date +%Y_%m_%d)"
echo $DIR
if [[ ! -d $DIR ]];then
    echo "当天数据文件未备份，先创建数据目录。"
    mkdir -p  $DIR
    echo "开始进行mysql数据备份"
    docker exec mysql  sh -c 'exec mysqldump --all-databases -uroot -p111111 --all-databases' > /home/ucen/UCEN/shell/mysql_"$(date +%Y_%m_%d)"/mysql_"$(date +%H:%m)".sql
else
    echo "数据已经备份过，不需要再次备份！！！"
fi
docker exec  -it  mysql  mysql -uroot -p111111 -e "set foreign_key_checks = 1;"
