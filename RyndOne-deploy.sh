#author:Roya
#script name:RyinddOne-deploy
#creation time:2020-01-23
#update time:2020-01-24
#version:0.15
#!/bin/bash
echo "------------------------------"
echo "|input 1:Configure Yum source|"
echo "------------------------------"
echo "|input 2:Configure IP address|"
echo "------------------------------"
echo "|input 3:Configure NFS server|"
echo "------------------------------"
echo "|input 4:Configure DHCP server|" 
echo "------------------------------"
echo "|input 5:Configure DNS server|"
echo "------------------------------"
read -p "please input 1,2,3,4,5: " a 
case $a in #使用case语句判断输入
1)
echo "-------------------------------------"
echo "|Prepare to configure Yum source...|"
echo "-------------------------------------"
sleep 1  #等一秒执行下面命令
echo "|One moment...please|"
echo "---------------------"
sleep 3
echo "/dev/cdrom /mnt iso9660 defaults 0 0" >> /etc/fstab && mount -a &> /dev/null && echo '|mount success!|' # 将挂载信息写入fstab
echo "----------------"
sleep 0.7
echo '[rhel]
name=rhel
baseurl=file:///mnt
gpgcheck=0
enabled=1' >> /etc/yum.repos.d/rhel.repo #yum源的配置文件
yum makecache &> /dev/null
if [ $? -eq 0 ]
then
sleep 0.7
echo "|Yum source configuration successfully!|"
else echo "|Yum source configuration failed!|"
fi
yum repolist | grep repolist
;;
2) #配置IP地址
echo "----------------------------------------------"
read -p "|Please enter IP address(Tips:192.168.1.1/24)|: " IPad #请输入IP地址
sleep 0.7
echo "------------------------------------------"
read -p "|Please enter GATEWAY(Tips:192.168.1.254)|: " gate #请输入网关
sleep 0.7
echo "-----------------------------------------------"
read -p "|please enter DNS server(Tips:114.114.114.114)|: " DNS #请输入网关
sleep 0.7
echo "-----------------------------------------------------------"
read -p "|please enter Please enter the network card name(Tips:ens33,eth0)|: " wlanname #请输入网卡名
sleep 0.7 
echo "-----------------------------------------------------------"
nmcli connection modify $wlanname ipv4.addresses $IPad
nmcli connection modify $wlanname ipv4.method manual 
nmcli connection modify $wlanname ipv4.dns $DNS ipv4.gateway $gate &>/dev/null
nmcli connection modify $wlanname connection.autoconnect yes &>/dev/null
systemctl restart network 
if [ $? -eq 0 ]
then
echo "|Network configuration successful!|" #网络配置成功
echo "----------------------------------"
ifconfig | awk 'NR==2'
else echo "Network configuration failed!" 
fi
;;
3) #配置NFS服务
echo "-------------------------------------"
yum install -y nfs-utils &> /dev/null #安装nfs服务端
if [ $? -eq 0 ]
then echo '|NFS service installed successfully!|'  #nfs服务安装成功
echo "-------------------------------------------------------------"
read -p '|Please enter NFS directory path you want to share(Tips:/nfsdir)|: ' nfsdir #输入nfs共享的目录
echo "------------------------------------------------------------"
sleep 0.7 
read -p '|Please enter the IP address of the host allowed to be shared(Tips:192.168.1.1 or 192.168.1.*)|: ' nfsIP #输入允许共享的主机IP地址或者网段
echo "---------------------------------------------------------------"
sleep 0.7
read -p '|Please enter the permission of the shared host(Tips:sync,rw,ro)|: ' nfspwr #输入允许共享的主机的权限
echo "-------------------------------"
sleep 0.7
echo "|Configuring..... Please wait.|"
echo "-------------------------------"
sleep 3
if [ -e $nfsdir ] #判断nfs共享目录是否存在
then echo '|File Exists|' 
echo "------------"
sleep 0.7
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
4) #配置DHCP服务
echo "-------------------"
echo '|one momnet...please|' 
yum install -y dhcp &> /dev/null 
if [ $? -eq 0 ]
then 
echo "DHCP service installed successfully!"
echo "----------------------------------------------------------------------------"
read -p "|Please enter the type of DNS service dynamic update(Tips:none,interim,ad-hoc)|: " style  #请输入DNS服务动态更新的类型
case $style in 
none|interim|ad-hoc)
continue
;;
*)
echo "input error!"
exit 0
;;
esac
echo "---------------------------------------------------------"
sleep 0.7
read -p "|Allow/ignore client update DNS records(Tips:allow/ignore)|: " judge #允许/忽略客户端更新DNS记录
case $judge in
allow|ignore)
continue
;;
*)
echo "input error!"
exit 0
esac
echo "------------------------------------------"
sleep 0.7
read -p "|Please enter a DNS domain(Tips:roya.com)|: " domain #请输入DNS域
echo "------------------------------------------"
sleep 0.7
IP=`ifconfig | awk -F ' ' 'NR==2{print$2}'`  #IP地址
NETMASK=`ifconfig | awk -F ' ' 'NR==2{print$4}'` #子网掩码
IP0="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.0""  #取IP地址前三位
IP1="expr `ifconfig| awk -F ' ' 'NR==2{print$2}'  | awk -F '.' '{print$4}'` + 20" #将IP地址最后一位加20
IP2="expr `ifconfig| awk -F ' ' 'NR==2{print$2}'  | awk -F '.' '{print$4}'` + 100" #将IP地址最后一位加100
IP3="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.`$IP1`"" #增加之后的IP地址
IP4="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.`$IP2`""
cat >> /etc/dhcp/dhcpd.conf << EOF #写入配置文件
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
5) #配置DNS服务
echo "---------------------"
echo "|one moment...please|"
yum install -y bind* &> /dev/null 
if [ $? -eq 0 ]
then
sed -i "s/listen-on port 53 { 127.0.0.1; };/listen-on port 53 { any; };/g" /etc/named.conf 
sed -i "s/listen-on-v6 port 53 { ::1; };/\/\/listen-on-v6 port 53 { ::1; };/g" /etc/named.conf 
sed -i "s/allow-query     { localhost; };/allow-query     { any; };/g" /etc/named.conf
read -p "Please enter the website you want to analyze(Tips:runtime.com): " local1 #请输入你想解析的域名
sleep 1.7 
IP_0="`ifconfig | awk -F ' ' 'NR==2{print$2}'`"
IP_1="`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1`"
IP_2="`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 2`"
IP_3="`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 3`"
IP_4="`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 4`"
cat > /etc/named.rfc1912.zones << EOF
zone "$local1" IN {
        type master;
        file "$local1.local";
        allow-update { none; };
};
zone "$IP_3.$IP_2.$IP_1.in-addr.arpa" IN {
        type master;
        file "$local1.zone";
        allow-update { none; };
};
EOF
cp -a /var/named/named.localhost /var/named/$local1.local
cp -a /var/named/named.loopback /var/named/$local1.zone
cat > /var/named/$local1.local << EOF
\$TTL 1D
@       IN SOA  root.$local1. $local1. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
        NS      ns.$local1.
ns      A       $IP_0
        A       $IP_0
EOF
cat > /var/named/$local1.zone << EOF
\$TTL 1D
@       IN SOA  root.$local1. $local1. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
        NS        ns.$local1.
$IP_4   PTR       $local1.
$IP_4   PTR       ns.$local1.      
EOF
systemctl restart named
if [ $? -eq 0 ]
then
echo "--------------------------------------"
echo "|DNS service configuration succeeded!|"
systemctl enable named &> /dev/null
firewall-cmd --add-service=dns --permanent &> /dev/null
firewall-cmd --reload &> /dev/null
echo "--------------------------------------"
nslookup $IP_0
echo "--------------------------------------"
else echo "|DNS service is not configured successfully!|"
fi
else echo "|DNS service not installed succesfully!|"
echo "--------------------------------------"
fi
;;
*) 
exit 0
;;
esac
