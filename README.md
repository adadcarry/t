# titan-tools

#### 介绍
titan-network节点 Linux系统批量部署、升级、维护工具，支持一键更新。自主选择部署节点数量，自动安装监控，故障自动重启。
一键部署完自动安装监控，无需再单独安装第6步，系统服务方式安装，无需docker。脚本已经测试过的系统  ubuntu armbian  debian  hiveos

#### 软件架构
shell脚本，linux系统运行，支持ubuntu、armbian、debian


#### 安装教程
在终端中输入以下命令，回车执行：
bash <(curl -s -L https://gitee.com/blockchain-tools/titan-tools/raw/master/titan.sh)

![输入图片说明](images/titan.jpg)

#### 使用说明

1.  部署太快可能会因为主网的访问失败导致节点注册失败，手动注册方法如下（复制全部命令）：

for i in {1..5};do sudo -u admin$i titan-edge bind --hash=改成你的id https://api-test1.container1.titannet.io/api/v2/device/binding;done

