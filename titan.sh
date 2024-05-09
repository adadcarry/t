#!/bin/bash

RED="31m"
GREEN="32m"
YELLOW="33m"
BLUE="34m"
SKYBLUE="36m"
FUCHSIA="35m"

colorEcho() {
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}

titan_amd64_url=https://gitee.com/blockchain-tools/titan-tools/releases/download/0.1.18/titan_v0.1.18_linux_amd64.tar.gz
titan_arm_url=https://gitee.com/blockchain-tools/titan-tools/releases/download/0.1.18/titan_v0.1.18_linux_arm.tar.gz
titan_arm64_url=https://gitee.com/blockchain-tools/titan-tools/releases/download/0.1.18/titan_v0.1.18_linux_arm64.tar.gz

init_system() {
    # 关闭 selinux
    echo "System initialization"
    if [ -f "/etc/selinux/config" ]; then
        sed -i 's/\(SELINUX=\).*/\1disabled/g' /etc/selinux/config
        setenforce 0 >/dev/null 2>&1
    fi

    echo "net.ipv4.ip_forward = 1" >>/etc/sysctl.conf
    echo "net.core.netdev_max_backlog = 50000" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog = 8192" >>/etc/sysctl.conf
    echo "net.core.somaxconn = 50000" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_syncookies = 1" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_tw_reuse = 1" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_tw_recycle = 1" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_keepalive_time = 1800" >>/etc/sysctl.conf
    sysctl -p >/dev/null 2>&1

    # 关闭 firewalld, ufw
    systemctl stop firewalld >/dev/null 2>&1
    systemctl disable firewalld >/dev/null 2>&1
    systemctl stop ufw >/dev/null 2>&1
    systemctl disable ufw >/dev/null 2>&1
    colorEcho $GREEN "selinux,sysctl.conf,firewall 设置完成 ."
}

change_limit() {
    colorEcho $BLUE "修改系统最大连接数"
    ulimit -n 65535
    changeLimit="n"

    if [ $(grep -c "root soft nofile" /etc/security/limits.conf) -eq '0' ]; then
        echo "root soft nofile 65535" >>/etc/security/limits.conf
        echo "* soft nofile 65535" >>/etc/security/limits.conf
        changeLimit="y"
    fi

    if [ $(grep -c "root hard nofile" /etc/security/limits.conf) -eq '0' ]; then
        echo "root hard nofile 65535" >>/etc/security/limits.conf
        echo "* hard nofile 65535" >>/etc/security/limits.conf
        changeLimit="y"
    fi

    if [ $(grep -c "DefaultLimitNOFILE=65535" /etc/systemd/user.conf) -eq '0' ]; then
        echo "DefaultLimitNOFILE=65535" >>/etc/systemd/user.conf
        changeLimit="y"
    fi

    if [ $(grep -c "DefaultLimitNOFILE=65535" /etc/systemd/system.conf) -eq '0' ]; then
        echo "DefaultLimitNOFILE=65535" >>/etc/systemd/system.conf
        changeLimit="y"
    fi

    if [[ "$changeLimit" = "y" ]]; then
        echo "连接数限制已修改为65535,重启服务器后生效"
    else
        echo -n "当前连接数限制："
        ulimit -n
    fi
    colorEcho $GREEN "已修改最大连接数限制！"
}

user_add() {
    for i in $(seq $node_number);do
       useradd admin$i
       [ ! -d /home/admin$i ] && mkdir -p /home/admin$i
       chown -R admin$i:admin$i /home/admin$i
    done
}

download_file() {
    if [[ ! $(command -v wget) ]];then
        echo "开始安装wget..."
        apt update
        apt -y install wget
    fi
    rm -rf ./titan*
    wget $1
    tar -zxf titan_*.tar.gz
    rm -rf ./titan*.gz
    mv $(ls -d titan*)/* /usr/local/bin
}

service_install() {
    for i in $(seq $node_number);do
	cat >/etc/systemd/system/titan$i.service <<-EOF
	[Unit]  
	Description=My Custom Service  
	After=network.target  
  
	[Service]  
	ExecStart=titan-edge daemon start --init --url https://test-locator.titannet.io:5000/rpc/v0
	Restart=always  
	User=admin$i  
	Group=admin$i
  
	[Install]  
	WantedBy=multi-user.target
	EOF
        systemctl daemon-reload
        systemctl enable --now titan${i}.service
        while true;do
            if [ -f /home/admin$i/.titanedge/config.toml ];then
                sed -i "/^\ \ #ListenAddress/c \ \ ListenAddress\ \=\ \"0.0.0.0:123$i\"" /home/admin$i/.titanedge/config.toml
                sed -i "/^\ \ #StorageGB/c \ \ StorageGB\ \=\ ${storagegb}" /home/admin$i/.titanedge/config.toml
                systemctl restart titan${i}.service
		s=0
		while true;do
		    sleep 5
		    sudo -u admin${i} titan-edge state  >/dev/null 2>&1
		    if [ $? -ne 0 ];then
			if [ $s -lt 10 ];then
	                    let s=$s+5
			    continue
			else
		            s=0
			    systemctl restart titan${i}.service
			    continue
			fi
		    else
			break
		    fi
		done
                sudo -u admin$i titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding
                break
            else
               systemctl restart titan${i}.service
            fi
            sleep 5
        done
    done
}

install_app(){
    colorEcho ${BLUE} "###  请选择cpu架构类型，输入序号按回车继续 ###"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "1 → x86_64/amd64位架构"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "2 → armv7/arm32位架构"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "3 → armv8/arm64位架构"   
    colorEcho ${GREEN} "--------------------------------------------"
    colorEcho ${BLUE} "###  请输入操作号按回车继续，按Ctrl+C退出此程序 ###"
    read -p "$(echo -e "请选择CPU架构[1-3]:|choose[1-3]:")" choose
    case $choose in
    1)
        download_url=$titan_amd64_url
        ;;
    2)
        download_url=$titan_arm_url
        ;;
    3)
        download_url=$titan_arm64_url
        ;;
    *)
        echo "输入错误，请重新选择"
        ;;
    esac
    read -p "$(echo -e "请输入安装的节点数量|Please enter the number of nodes:")" node_number
    read -p "$(echo -e "请输入你的身份码|Please enter your id:")" id
    read -p "$(echo -e "请输入每个节点的存储容量(GB)|Please enter storage GB:")" storagegb
    init_system
    change_limit
    user_add
    download_file $download_url
    service_install
    monitor_install
}

update_app() {
    colorEcho ${BLUE} "###  请选择cpu架构类型，输入序号按回车继续 ###"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "1 → x86_64/amd64位架构"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "2 → armv7/arm32位架构"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "3 → armv8/arm64位架构"   
    colorEcho ${GREEN} "--------------------------------------------"
    colorEcho ${BLUE} "###  请输入操作号按回车继续，按Ctrl+C退出此程序 ###"
    read -p "$(echo -e "请选择CPU架构[1-3]:|choose[1-3]:")" choose
    case $choose in
    1)
        download_url=$titan_amd64_url
        ;;
    2)
        download_url=$titan_arm_url
        ;;
    3)
        download_url=$titan_arm64_url
        ;;
    *)
        echo "输入错误，请重新选择"
        ;;
    esac
    download_file $download_url
    restart_app
    colorEcho ${BLUE} "升级成功！update success"
}

monitor_install() {
cat >/usr/local/bin/titan-monitor.sh <<EOF
#!/bin/bash
while true;do
  for i in {1..5};do
    systemctl status titan\$i >/dev/null 2>&1
    if [ \$? -ne 0 ];then
      systemctl restart titan\$i
    fi
  done
  sleep 20
done
EOF

cat >/etc/systemd/system/titan-monitor.service <<EOF
[Unit]  
Description=titan Monitor Service  
After=network.target  
  
[Service]  
ExecStart=/usr/local/bin/titan-monitor.sh
Restart=always  
User=root
Group=root
  
[Install]  
WantedBy=multi-user.target
EOF

chmod +x /usr/local/bin/titan-monitor.sh
systemctl enable --now titan-monitor.service
}

restart_app(){
    for i in {1..5};do
        systemctl restart titan$i    
    done     
    colorEcho ${GREEN} "服务重启完成|server restarted"
}

stop_app(){
    for i in {1..5};do
        systemctl stop titan$i
    done
    systemctl stop titan-monitor
    colorEcho ${GREEN} "服务已经停止|server stoped"
}

main() {
    colorEcho ${GREEN} "--------------------------------------------"
    colorEcho ${GREEN} "######### 欢迎使用 摸金校尉 出品工具 #########"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "1 → 安装节点- install node"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "2 → 卸载节点- uninstall node"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "3 → 检测节点- check node"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "4 → 修改存储- change storage limit"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "5 → 重启节点- restart node"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "6 → 监控检测- monitor and check"
    colorEcho ${GREEN} "--------------------------------------------"
    echo "7 → 升级版本- update version"
    colorEcho ${GREEN} "--------------------------------------------"
    colorEcho ${YELLOW} "###  请输入操作号按回车继续，按Ctrl+C退出此程序 ###"
    colorEcho ${YELLOW} "###  please choose number and press enter,or Ctrl+C  exit  ###"
    colorEcho ${GREEN} "--------------------------------------------"

    read -p "$(echo -e "请选择[1-7]:|choose[1-7]:")" choose

    case $choose in
    1)
        install_app
        ;;
    2)
        uninstall_app
        ;;
    3)
        restart_app
        ;;
    4)
        stop_app
        ;;
    5)
        restart_app
        ;;
    6)
        monitor_install
        ;;
    7)
        update_app
        ;;
    *)
        echo "功能待完成, 请选择其它选项。"
        ;;
    esac
}

main
