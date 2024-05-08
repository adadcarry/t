#!/bin/bash
if [[ ! $(command -v wget) ]];then
        echo "开始安装wget..."
        apt update
        apt -y install wget
fi
rm -rf ./titab.tar.gz
wget http://0.0.0.0/tar.gz