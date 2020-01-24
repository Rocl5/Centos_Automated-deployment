#author:Roya
#script name:RyndOne-deploy
#creation time:2020-01-23
#version:0.1
#!/bin/bash
echo "input 1:Configure Yum source"
echo "input 2:Configure IP address,gateway,subnet mask,DNS server"
echo "input 3:Configure NFS server"
echo "input 4:Configure DHCP server" 
echo "input 5:Configure DNS server"
read -p "please input 1,2,3,4: " a 
case $a in #使用case语句判断输入
1)
echo "Prepare to configure Yum source...."
sleep 1  #等一秒执行下面命令
echo "One moment please"
sleep 3
echo "/dev/cdrom /mnt iso9660 defaults 0 0" >> /etc/fstab && mount -a &> /dev/null && echo 'mount success!' # 将挂载信息写入fstab
echo '[rhel]
name=rhel
baseurl=file:///mnt
gpgcheck=0
enabled=1' >> /etc/yum.repos.d/rhel.repo #yum源的配置文件
yum makecache &> /dev/null
if [ $? -eq 0 ]
then 
echo "Yum source configuration successfully!"
else echo "Yum source configuration failed!"
fi
yum repolist | grep repolist
;;
2)
read -p "Please enter IP address(Tips:192.168.1.1/24): " IPad
read -p "Please enter GATEWAY(Tips:192.168.1.254): " gate
read -p "please enter DNS server(Tips:114.114.114.114): " DNS
read -p "please enter Please enter the network card name(Tips:ens33,eth0): " name 
nmcli connection modify $name ipv4.method manual
nmcli connection modify $name ipv4.addresses $IPad
nmcli connection modify $name ipv4.dns $DNS ipv4.gateway $gate
nmcli connection modify $name connection.autoconnect yes
systemctl restart network 
if [ $? -eq 0 ]
then 
echo "Network configuration successful!"
ifconfig | awk 'NR==2'
else echo "Network configuration failed!" 
fi
;;
3)
yum install -y nfs-utils &> /dev/null #安装nfs服务端
if [ $? -eq 0 ]
then echo 'NFS service installed successfully!'
read -p 'Please enter NFS directory path you want to share(Tips:/nfsdir): ' nfsdir #输入nfs共享的目录
sleep 1 
read -p 'Please enter the IP address of the host allowed to be shared(Tips:192.168.1.1 or 192.168.1.*): ' nfsIP #输入允许共享的主机IP地址或者网段
sleep 1
read -p 'Please enter the permission of the shared host(Tips:sync,rw,ro): ' nfspwr #输入允许共享的主机的权限
sleep 1
echo "Configuring..... Please wait."
sleep 10
if [ -e $nfsdir ] #判断nfs共享目录是否存在
then echo 'File Exists'
else mkdir $nfsdir
chmod -Rf 777 $nfsdir
fi
echo "$nfsdir $nfsIP($nfspwr)" > /etc/exports 
systemctl restart nfs-server 
if [ $? -eq 0 ] 
then 
IP=`ifconfig | awk -F ' ' 'NR==2{print$2}'` #使用awk命令提取出IP地址
exportfs -r 
showmount -e $IP
if [ $? -eq 0 ] #判断服务是否配置正确
then echo "NFS server has been configured successfully!"
else echo "NFS server has been configured failed!"
fi
fi
systemctl restart rpcbind 
systemctl enable rpcbind &> /dev/null
systemctl enable nfs-server &> /dev/null #加入到开机自启动
firewall-cmd --add-service=nfs --permanent &> /dev/null
firewall-cmd --add-service=rpc-bind --permanent &> /dev/null
firewall-cmd --reload &> /dev/null
else echo 'NFS service installion failed!'
fi
;;
4)
yum install -y dhcp &> /dev/null
if [ $? -eq 0 ]
then 
read -p "Please enter the type of DNS service dynamic update(Tips:none,interim,ad-hoc): " style
read -p "Allow/ignore client update DNS records(Tips:allow/ignore): " judge
read -p "Please enter a DNS domain(Tips:roya.com): " domain 
IP=`ifconfig | awk -F ' ' 'NR==2{print$2}'` 
NETMASK=`ifconfig | awk -F ' ' 'NR==2{print$4}'`
IP0="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.0""
IP1="expr `ifconfig| awk -F ' ' 'NR==2{print$2}'  | awk -F '.' '{print$4}'` + 20"
IP2="expr `ifconfig| awk -F ' ' 'NR==2{print$2}'  | awk -F '.' '{print$4}'` + 100"
IP3="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.`$IP1`""
IP4="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.`$IP2`""
cat >> /etc/dhcp/dhcpd.conf << EOF
ddns-update-style $style;
$judge client-updates;
subnet `$IP0` netmask $NETMASK {
range `$IP3` `$IP4`;
option subnet-mask $NETMASK;
option routers $IP;
option domain-name "$domain";
option domain-name-servers $IP;
default-lease-time 21600;
max-lease-time 43200;
}
EOF
systemctl restart dhcpd 
if [ $? -eq 0 ]
then echo "DHCP service configuration succeeded!"
systemctl enable dhcpd &> /dev/null
firewall --add-service=dhcp --permanent &> /dev/null
firewall --reload &> /dev/null
systemctl status dhcpd
else echo "DHCP service configuration failed!"
fi
else echo "DHCP service not installed successfully!"
fi
;;
*) 
exit 0
;;
esac
