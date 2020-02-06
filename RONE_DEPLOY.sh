#AUTHOR:Roya
#DESCIRPTION:One click deployment of CentOS service
#SCRIPET NAME:RONE_DEPLOY
#CREATE TIME:2020-01-23
#UPDATE TIME:2020-02-04
#VERSION:0.30
#!/bin/bash
OPTION=$(whiptail --title "CONFIGURE SERVICE" --menu "Please select the service you want to Configure: " 15 60 6 \
"1." "Configure Yum source" \
"2." "Configure IP address" \
"3." "Configure NFS server" \
"4." "Configure DHCP server" \
"5." "Configure DNS server" \
"6." "Configure PXE unattended installation service" 3>&1 1>&2 2>&3)
case $OPTION in
1)
if [ -e /media/cdrom ]
then sleep 0.1 
else mkdir /media/cdrom
fi
function Yum()
{
rm -rf /etc/yum.repos.d/*
echo "/dev/cdrom /media/cdrom iso9660 defaults 0 0" >> /etc/fstab 
mount -a &> /dev/null 
echo '[rhel]
name=rhel
baseurl=file:///media/cdrom
gpgcheck=0
enabled=1' > /etc/yum.repos.d/rhel.repo
}
{
for ((i = 0 ; i <=100 ; i+=5))
do
sleep 0.1
echo $i
done 
} | whiptail --gauge "Configuring, please wait..." 6 60 0 &
Yum &
wait
yum update &> /dev/null
if [ $? -eq 0 ] 
then  
whiptail --title "Message Box" --msgbox "Yum Source Configuration Successed!" 10 40
else 
whiptail --title "Message Box" --msgbox "Yum source Configuration Failed!" 10 40
fi
;;
2)
function IPConfigure()
{
NETCARD=$(whiptail --title "Net Card" --inputbox "Please enter the network card name: " 10 60 ens33 3>&1 1>&2 2>&3)
IPADDRESS=$(whiptail --title "IP Address" --inputbox "Please enter IP Address: " 10 60 192.168.1.1/24 3>&1 1>&2 2>&3) 
nmcli connection modify $NETCARD ipv4.addresses $IPADDRESS &> /dev/null
nmcli connection modify $NETCARD ipv4.method manual &> /null
GATEWAY=$(whiptail --title "GateWay" --inputbox "Please enter GATEWAY: " 10 60 192.168.1.254 3>&1 1>&2 2>&3)
DNS=$(whiptail --title "DNS server" --inputbox "Please enter DNS server: " 10 60 114.114.114.114 3>&1 1>&2 2>&3)
nmcli connection modify $NETCARD ipv4.dns $DNS ipv4.gateway $GATEWAY &> /dev/null
nmcli connection modify $NETCARD connection.autoconnect yes &> /dev/null
}
IPConfigure 
{
for ((i = 0 ; i <= 100 ; i+=5))
do 
sleep 0.1 
echo $i
done 
} | whiptail --gauge "Configuring, please wait..." 6 60 0 
systemctl restart network 
if [ $? -eq 0 ]
then 
whiptail --title "Message Box" --msgbox "Network Configration Successful!" 10 40
IPADDR=`ifconfig | awk -F ' ' 'NR==2{print$2}'`
whiptail --title "Message Box" --msgbox "Your IP address is $IPADDR" 10 40
else 
whiptail --title "Message Box" --msgbox "Network Configration Failed!" 10 40
fi
;;
3)
function nfs()
{
yum install -y nfs-utils &> /dev/null 
yum install -y rpcbind &> /dev/null
}
{
for ((i = 0 ; i <=100 ; i+=5))
do
sleep 0.1
echo $i
done 
} | whiptail --gauge "Installing, please wait..." 6 60 0 &
nfs &
wait 
IPADDRS=`ifconfig | awk -F ' ' 'NR==2{print$2}'`
NFSSD=$(whiptail --title "NFS Share Directory" --inputbox "Please enter NFS directory path you want to share: " 10 70 /nfsdir 3>&1 1>&2 2>&3)
NFSSI=$(whiptail --title "NFS Share IPaddress" --inputbox "Please enter the IP address of the host allowed to be shared: " 10 70 192.168.1.1 3>&1 1>&2 2>&3)
NFSSHP=$(whiptail --title "NFS Share Host Permissions" --inputbox "Please enter the permission of the shared host: " 10 60 sync,rw,all_squash 3>&1 1>&2 2>&3)
if [ ! -e $NFSSD ]
then  
mkdir $NFSSD &> /dev/null
chmod -Rf 777 $NFSSD 
fi
cat > /etc/exports << EOF
$NFSSD $NFSSI($NFSSHP)
EOF
exportfs -r
function nfsfirewalld()
{
systemctl restart rpcbind  
systemctl enable rpcbind &> /dev/null
systemctl enable nfs-server &> /dev/null 
firewall-cmd --add-service=nfs --permanent &> /dev/null
firewall-cmd --add-service=rpc-bind --permanent &> /dev/null
firewall-cmd --reload &> /dev/null
}
systemctl restart nfs-server && systemctl enable nfs-server &> /dev/null &
nfsfirewalld &
{
for ((i = 0 ; i <=100 ; i+=5))
do
sleep 0.1
echo $i
done 
} | whiptail --gauge "Configuring, please wait..." 6 60 0 &
wait
showmount -e $IPADDRS
if [ $? -eq 0 ]
then
whiptail --title "Message Box" --msgbox "NFS Service Configuration successed!" 10 40 
else
whiptail --title "Message Box" --msgbox "NFS Service Configuration Failed!" 10 40 
fi
;;
4)
yum install -y dhcp &> /dev/null &
{
for ((i = 0 ; i <=100 ; i+=5))
do
sleep 0.2
echo $i
done 
} | whiptail --gauge "Installing, please wait..." 6 60 0 &
wait
OPTION1=$(whiptail --title "DNS Services Dynamic Update" --menu "Please enter the type of DNS service dynamic update: " 10 30 3 \
"none" "1" \
"interim" "2" \
"ad-hoc" "3" 3>&1 1>&2 2>&3)
OPTION2=$(whiptail --title "Client Update" --menu "Allow/ignore client update DNS records: " 10 30 2 \
"ignore" "1" \
"allow" "2"  3>&1 1>&2 2>&3)
DOMAIN=$(whiptail --title "DNS Domain" --inputbox "Please enter a DNS domain : " 10 40 runtime.com 3>&1 1>&2 2>&3)
IP=`ifconfig | awk -F ' ' 'NR==2{print$2}'`  
NETMASK=`ifconfig | awk -F ' ' 'NR==2{print$4}'` 
IP0="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.0"" 
IP1="expr `ifconfig| awk -F ' ' 'NR==2{print$2}'  | awk -F '.' '{print$4}'` + 20" 
IP2="expr `ifconfig| awk -F ' ' 'NR==2{print$2}'  | awk -F '.' '{print$4}'` + 100" 
IP3="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.`$IP1`"" 
IP4="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.`$IP2`""
cat > /etc/dhcp/dhcpd.conf << EOF
ddns-update-style $OPTION1;
$OPTION2 client-updates;
subnet `$IP0` netmask $NETMASK {
range `$IP3` `$IP4`;
option subnet-mask $NETMASK;
option routers $IP;
option domain-name "$DOMAIN";
option domain-name-servers $IP;
default-lease-time 21600;
max-lease-time 43200;
}
EOF
systemctl restart dhcpd > /dev/null &
{
for ((i = 0 ; i <=100 ; i+=5))
do
sleep 0.1
echo $i
done 
} | whiptail --gauge "Configuring, please wait..." 6 60 0 &
wait
STATUS=$(systemctl status dhcpd | grep Active | cut -d ':' -f 2 | awk -F ' ' '{print$1}')
if [ "$STATUS" == "active" ]
then 
whiptail --title "Message Box" --msgbox "DHCP Service Configuration Succeeded!" 10 50 
systemctl enable dhcpd &> /dev/null
firewall-cmd --permanent --add-service=dhcp  &> /dev/null
firewall-cmd --reload &> /dev/null
else 
whiptail --title "Message Box" --msgbox "DHCP Service Configuration Failed" 10 40
fi
;;
5)
yum install -y bind* &> /dev/null &
{
for ((i = 0 ; i <=100 ; i+=5))
do
sleep 0.3
echo $i
done 
} | whiptail --gauge "Installing, please wait..." 6 60 0 &
wait
sed -i "s/listen-on port 53 { 127.0.0.1; };/listen-on port 53 { any; };/g" /etc/named.conf 
sed -i "s/listen-on-v6 port 53 { ::1; };/\/\/listen-on-v6 port 53 { ::1; };/g" /etc/named.conf 
sed -i "s/allow-query     { localhost; };/allow-query     { any; };/g" /etc/named.conf
domain=$(whiptail --title "DOMAIN" --inputbox "Please enter the domain name to be resolved: " 10 70 runtime.com 3>&1 1>&2 2>&3)
IP_0="`ifconfig | awk -F ' ' 'NR==2{print$2}'`"
IP_1="`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1`"
IP_2="`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 2`"
IP_3="`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 3`"
IP_4="`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 4`"
function dns(){
cat > /etc/named.rfc1912.zones << EOF
zone "$domain" IN {
        type master;
        file "$domain.local";
        allow-update { none; };
};
zone "$IP_3.$IP_2.$IP_1.in-addr.arpa" IN {
        type master;
        file "$domain.zone";
        allow-update { none; };
};
EOF
cp -a /var/named/named.localhost /var/named/$domain.local
cp -a /var/named/named.loopback /var/named/$domain.zone
cat > /var/named/$domain.local << EOF
\$TTL 1D
@       IN SOA  root.$domain. $domain. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
        NS      ns.$domain.
ns      A       $IP_0
        A       $IP_0
EOF
cat > /var/named/$domain.zone << EOF
\$TTL 1D
@       IN SOA  root.$domain. $domain. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
        NS        ns.$domain.
$IP_4   PTR       $domain.
$IP_4   PTR       ns.$domain.      
EOF
}
dns &
{
for ((i = 0 ; i <=100 ; i+=5))
do
sleep 0.1
echo $i
done 
} | whiptail --gauge "Configuring, please wait..." 6 60 0 &
wait
systemctl restart named
if [ $? -eq 0 ]
then 
whiptail --title "Message Box" --msgbox "DNS Service Configuration Succeeded" 10 50
else 
whiptail --title "Message Box" --msgbox "DNS Service Configuration Failed!" 10 50
fi 
;;
6)
function installed()
{
yum install -y xinetd &> /dev/null 
yum install -y dhcp &> /dev/null 
yum install -y tftp-server &> /dev/null
yum install -y syslinux &> /dev/null
yum install -y vsftpd &> /dev/null
}
installed &
{
for ((i = 0 ; i <=100 ; i+=2))
do
sleep 1
echo $i
done 
} | whiptail --gauge "Installing, please wait..." 6 60 0 &
wait
IP_a=`ifconfig | awk -F ' ' 'NR==2{print$2}'`
netmask=`ifconfig | awk -F ' ' 'NR==2{print$4}'`
IP_b="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.0""
IP_c="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.0""  
IP_d="expr `ifconfig| awk -F ' ' 'NR==2{print$2}'  | awk -F '.' '{print$4}'` + 100" 
IP_e="expr `ifconfig| awk -F ' ' 'NR==2{print$2}'  | awk -F '.' '{print$4}'` + 200" 
IP_f="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.`$IP_d`"" 
IP_g="echo "`ifconfig | awk -F ' ' 'NR==2{print$2}' | cut -d '.' -f 1,2,3`.`$IP_e`""
function Configured()
{
cat > /etc/dhcp/dhcpd.conf << EOF
allow booting;
allow bootp;
ddns-update-style interim;
ignore client-updates;
subnet `$IP_b`  netmask $netmask {
        option subnet-mask      $netmask;
        option domain-name-servers  $IP_a;
        range dynamic-bootp `$IP_f` `$IP_g`;
        default-lease-time      21600;
        max-lease-time          43200;
        next-server             $IP_a;
        filename                "pxelinux.0";
}
EOF
systemctl restart dhcpd 
if [ $? -eq 0 ]
then 
whiptail --title "Message Box" --msgbox "DHCP Service Configured Success!" 10 50
else 
whiptail --title "Message Box" --msgbox "DHCP Servcie Configured Failed!" 10 50
exit 
fi
cat > /etc/xinetd.d/tftp <<EOF
service tftp
{
        socket_type             = dgram
        protocol                = udp
        wait                    = yes
        user                    = root
        server                  = /usr/sbin/in.tftpd
        server_args             = -s /var/lib/tftpboot
        disable                 = no
        per_source              = 11
        cps                     = 100 2
        flags                   = IPv4
}
EOF
systemctl restart xinetd
systemctl restart tftp 
if [ $? -eq 0 ] 
then
whiptail --title "Message Box" --msgbox "TFTP Servcie Configuration Successed!" 10 50 
else 
whiptail --title "Message Box" --msgbox "TFTP Servcie Configuration Failed!" 10 50
exit 0
fi
systemctl enable xinetd &> /dev/null
firewall-cmd --permanent --add-service=tftp &> /dev/null
firewall-cmd --reload &> /dev/null
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot
cp /media/cdrom/images/pxeboot/{vmlinuz,initrd.img} /var/lib/tftpboot
cp /media/cdrom/isolinux/{vesamenu.c32,boot.msg} /var/lib/tftpboot
if [ ! -e /var/lib/tftpboot/pxelinux.cfg ]
then mkdir /var/lib/tftpboot/pxelinux.cfg
fi
cp /media/cdrom/isolinux/isolinux.cfg /var/lib/tftpboot/pxelinux.cfg/default
version_0=`cat /etc/redhat-release | awk -F ' ' '{print$7}'`
cat > /var/lib/tftpboot/pxelinux.cfg/default <<EOF
default linux
timeout 600
display boot.msg
# Clear the screen when exiting the menu, instead of leaving the menu displayed.
# For vesamenu, this means the graphical background is still displayed without
# the menu itself for as long as the screen remains in graphics mode.
menu clear
menu background splash.png
menu title Red Hat Enterprise Linux $version_0
menu vshift 8
menu rows 18
menu margin 8
#menu hidden
menu helpmsgrow 15
menu tabmsgrow 13
# Border Area
menu color border * #00000000 #00000000 none
# Selected item
menu color sel 0 #ffffffff #00000000 none
# Title bar
menu color title 0 #ff7ba3d0 #00000000 none
# Press [Tab] message
menu color tabmsg 0 #ff3a6496 #00000000 none
# Unselected menu item
menu color unsel 0 #84b8ffff #00000000 none
# Selected hotkey
menu color hotsel 0 #84b8ffff #00000000 none
# Unselected hotkey
menu color hotkey 0 #ffffffff #00000000 none
# Help text
menu color help 0 #ffffffff #00000000 none
# A scrollbar of some type? Not sure.
menu color scrollbar 0 #ffffffff #ff355594 none
# Timeout msg
menu color timeout 0 #ffffffff #00000000 none
menu color timeout_msg 0 #ffffffff #00000000 none
# Command prompt text
menu color cmdmark 0 #84b8ffff #00000000 none
menu color cmdline 0 #ffffffff #00000000 none
# Do not display the actual menu unless the user presses a key. All that is displayed is a timeout message.
menu tabmsg Press Tab for full configuration options on menu items.
menu separator # insert an empty line
menu separator # insert an empty line
label linux
  menu label ^Install Red Hat Enterprise Linux $version_0
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=ftp://$IP_a ks=ftp://$IP_a/pub/ks.cfg quiet
label check
  menu label Test this ^media & install Red Hat Enterprise Linux $version_0
  menu default
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=RHEL-7.6\x20Server.x86_64 rd.live.check quiet
menu separator # insert an empty line
# utilities submenu
menu begin ^Troubleshooting
  menu title Troubleshooting
label vesa
  menu indent count 5
  menu label Install Red Hat Enterprise Linux $version_0 in ^basic graphics mode
  text help
	Try this option out if you're having trouble installing
	Red Hat Enterprise Linux $version_0.
  endtext
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=RHEL-$version_0\x20Server.x86_64 xdriver=vesa nomodeset quiet
label rescue
  menu indent count 5
  menu label ^Rescue a Red Hat Enterprise Linux system
  text help
	If the system will not boot, this lets you access files
	and edit config files to try to get it booting again.
  endtext
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=RHEL-$version_0\x20Server.x86_64 rescue quiet
label memtest
  menu label Run a ^memory test
  text help
	If your system is having issues, a problem with your
	system's memory may be the cause. Use this utility to
	see if the memory is working correctly.
  endtext
  kernel memtest
menu separator # insert an empty line
label local
  menu label Boot from ^local drive
  localboot 0xffff
menu separator # insert an empty line
menu separator # insert an empty line
label returntomain
  menu label Return to ^main menu
  menu exit
menu end
EOF
systemctl restart vsftpd 
if [ $? -eq 0 ] 
then 
whiptail --title "Message Box" --msgbox "FTP Service Configuration Successed!" 10 50
else 
whiptail --title "Message Box" --msgbox "FTP Service Configuration Successed!" 10 50
fi
systemctl enable vsftpd &> /dev/null
firewall-cmd --permanent --add-service=ftp &> /dev/null
firewall-cmd --reload &> /dev/null
setsebool -P ftpd_connect_all_unreserved=on &> /dev/null
cp ~/anaconda-ks.cfg /var/ftp/pub/ks.cfg
chmod +r /var/ftp/pub/ks.cfg
echo "#version=RHEL$version_0
# System authorization information
auth --enableshadow --passalgo=sha512
repo --name="Server-HighAvailability" --baseurl=file:///run/install/repo/addons/HighAvailability
repo --name="Server-ResilientStorage" --baseurl=file:///run/install/repo/addons/ResilientStorage
# Use CDROM installation media
url --url=ftp://$IP_a
# Use graphical install
graphical
# Run the Setup Agent on first boot
firstboot --enable
ignoredisk --only-use=sda
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=dhcp --device=ens33 --ipv6=auto --no-activate
network  --hostname=localhost.localdomain

# Root password
rootpw --iscrypted \$6\$qRAoZkxh5SHa7N4X\$w2osf.ZFey1hPtFdOJVIMgVOzc8dygUol2JphmSNQB6MHb7vPL63D6s9hIfrT9ydduKFOlq0S5/kp6.zJzYMy.
# System services
services --enabled="chronyd"
# System timezone
timezone Asia/Shanghai --isUtc
user --name=roya --password=\$6\$ZT/uZLv5GPvdSNr7\$caWMweAE4l9z93nmeRSttpiwHeJr9rjEGlAANrZBv5pRcZVkUfFzTAGQuQgNXEhKjI75sD9aVUmH.n55fUocX0 --iscrypted --gecos="roya"
# X Window System configuration information
xconfig  --startxonboot
# System bootloader configuration
bootloader --location=mbr --boot-drive=sda
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part swap --fstype="swap" --ondisk=sda --size=5000
part /boot --fstype="xfs" --ondisk=sda --size=2000
part / --fstype="xfs" --ondisk=sda --size=13000

%packages
@^graphical-server-environment
@base
@core
@desktop-debugging
@dial-up
@fonts
@gnome-desktop
@guest-agents
@guest-desktop-agents
@hardware-monitoring
@input-methods
@internet-browser
@multimedia
@print-client
@x11
chrony

%end
" > /var/ftp/pub/ks.cfg
} 
Configured &
cp -r /media/cdrom/* /var/ftp &
{
for ((i = 0 ; i <=100 ; i+=1))
do
sleep 5
echo $i
done 
} | whiptail --gauge "Configuring, please wait..." 6 60 0 &
wait
whiptail --title "Message Box" --msgbox "PXE Service Configuration Successed!" 10 50
;;
*)
exit
;;
esac
