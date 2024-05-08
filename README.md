# titan-tools

#### 介绍
titan-network部署、升级、维护工具。

#### 软件架构
shell脚本，linux系统运行，支持ubuntu、armbian、debian


#### 安装教程

bash <(curl -s -L https://gitee.com/clwangweb/titan-tools/raw/master/titan.sh)

#### 使用说明

1.  部署太快可能会因为主网的访问失败导致节点注册失败，手动注册方法如下：

for i in {1..5};do sudo -u admin$i titan-edge bind --hash=改成你的id https://api-test1.container1.titannet.io/api/v2/device/binding;done

