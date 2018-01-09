#!/bin/bash

read -p "已配置好当前节点yum源 [y/n]" YUM

if [ "$YUM" == "n" ]; then
    exit 1
fi

read -p "已配置好当前节点ntp服务 [y/n]" NTP

if [ "$YUM" == "n" ]; then
    exit 1
fi

read -p "root name:" ROOT_USER_NAME
read -p "root passwd:" ROOT_PASSWD

read -p "user name:" USER_NAME
read -p "user passwd:" PASSWD

OK="[\033[32mOK\033[0m]"
FAILED="[\033[31mFAILED\033[0m]"

check_gcc() {
    rpm -qa | grep "^gcc-"
    if [ $? -ne 0 ]; then
        echo "gcc check $FAILED"
        exit 1
    else
        echo "gcc check $OK"
    fi
}

check_expect() {
    which expect
    if [ $? -eq 0 ]; then
        echo "expect check $OK"
    else
        echo "expect check $FAILED"
        read -p "yum install expect [y/n]" flag
        if [ "$flag" == "y" ]; then
            yum install expect -y
        elif [ "$flag" == "n" ]; then
            exit
        fi
    fi
}

clean_ssh_key() {
    for i in `cat ip_list | awk '{print $1}'`; do
        expect expect/cleanExpect.sh $ROOT_PASSWD $i "/root"
    done
}


make_ssh_key() {
    echo "make ssh-key"
    ssh-keygen -q -P "" -f /root/.ssh/id_rsa && cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/id_rsa && chmod 644 /root/.ssh/id_rsa.pub
    for i in `cat ip_list | awk '{print $1}'`; do
        echo "send ssh-key to $i"
        expect expect/ssh-copy-id.sh $PASSWD $i
    done 
}

install_pdsh() {
    for i in `cat ip_list | awk '{print $1}'`; do
        scp /usr/local/bin/* $i:/usr/local/bin
        scp -r  /usr/local/lib/pdsh $i:/usr/local/lib
    done 
}

set_hostname() {
    for i in `cat ip_list | awk '{print $1}'`; do
        hostname=`cat ip_list | grep "$i" | awk '{print $2}'`
        echo $i $hostname
        ssh  $i hostnamectl set-hostname $hostname
    done 
}
check_gcc
check_expect
clean_ssh_key
make_ssh_key
install_pdsh
set_hostname
