# Macmini as router with PPPoE server and using virtual network interface (VLAN)

1. Maybe you would need to install the network device driver first. Find some way to download the file and install it manually at your Macmini server.

[broadcom-sta-dkms_6.30.223.271-19_all.deb](http://ftp.br.debian.org/debian/pool/non-free/b/broadcom-sta/broadcom-sta-dkms_6.30.223.271-19_all.deb).
```
wget http://ftp.br.debian.org/debian/pool/non-free/b/broadcom-sta/broadcom-sta-dkms_6.30.223.271-19_all.deb && apt install ./broadcom-sta-dkms_6.30.223.271-19_all.deb
```
2. If you want to install ssh or any desktop environment, run **tasksel**.

3. If your device has only one Network adapter, but you have a manageable switch (can be any manageable switch or some router with OpenWRT installed. Mine it's a TP-Link Archer C7 with works great), Install the **VLAN**
```
apt install vlan && echo 8021q >> /etc/modules && modprobe 8021q
```

## Making the server getting online

1. Setup your PPPOE connection, you can use your VLAN if you wish to. Do not forget to check the networking interface name ifname. At that example, the name it's **enp4s0f0**, but can be another name, depending of your setup. At mine, I'm using a manageable switch and using VLAN with ID 1.
```
cat << EOF > /etc/ppp/peers/your_provider_name
plugin rp-pppoe.so enp4s0f0.1

user "ppp_username"
noauth
hide-password

# Connection settings.
persist
maxfail 0
holdoff 5

# LCP settings.
lcp-echo-interval 10
lcp-echo-failure 3

# PPPoE compliant settings.
noaccomp
default-asyncmap
mtu 1492

# IP settings.
noipdefault
defaultroute
EOF
```
2. Place your username/passoword at file **/etc/ppp/chap-secrets** for wherever reason.
```
echo "ppp_username ppp_password" >> /etc/ppp/chap-secrets
```
3. You can test your connection running:
```
pon your_provider_name
```
To disconnect, just run 
```
poff -a
```
4. Configure your **/etc/network/interfaces** file to connect your PPPoE server automatically at bring up.
```
cat << EOF > /etc/network/interfaces.d/pppoe-wan
auto enp4s0f0.1
iface enp4s0f0.1 inet manual
  pre-up /sbin/ip link set dev enp4s0f0.10 up
  provider your_provider_name
EOF
```

## Let's make our server the internet router

We bring the server alive at the internet, but it's isn't a internet router yet. To do it, we need to setup some things, like a DHCP/DNS Server and configure our routing table.

1. Change the IP Address to static. Some manageable switchs accept working with two connections. One tagged and another untagged. I prefer to tagging the both connections. At that setup, we would go to remove the /etc/network/interfaces DHCP client configuration and setup a new file with the specs for our server.

```
cat << EOF > /etc/network/interfaces
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug enp4s0f0
EOF
```

2. Let's set the LAN connection. At example, the VLAN for LAN it's tagged as 2.
```
cat << EOF > /etc/network/interfaces.d/lan
iface enp4s0f0.2 inet static
        address 10.1.1.1
        netmask 255.255.255.0
        broadcast 10.1.1.255
        network 10.1.1.0
EOF
```
2. Install and configure the DHCP/DNS server **dnsmasq**
```
apt install dnsmasq
cat << EOF > /etc/dnsmasq.d/lan.conf
interface=enp4s0f0.2
listen-address=127.0.0.1
domain=lan
dhcp-range=10.1.1.100,10.1.1.150,12h
EOF
```
3. IPV4 Forwarding
```
cat << EOF > /etc/sysctl.d/sysctl.conf
net.ipv4.ip_forward=1
EOF
```
4. It's **iptables** time. We need to **masquerade** the connection to, effectivally, make our server work as a router. We also need the persist the settings, because if not, after rebooting the server, the masquerade configuration it's losted and you need to setup your iptables settings again. So, let's install **iptables-persistent**, set the rules and make those settings persistents.
```
apt install iptables-persistent
cat << EOF > /etc/iptables/rules.v4
*nat
-A POSTROUTING -o ppp0 -j MASQUERADE
COMMIT
*filter
-A INPUT -i lo -j ACCEPT
# allow ssh, so that we do not lock ourselves
-A INPUT -i ppp0 -p tcp -m tcp --dport 22 -j ACCEPT
# allow incoming traffic to the outgoing connections,
# et al for clients from the private network
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
# prohibit everything else incoming 
-A INPUT -i ppp0 -j DROP
COMMIT
EOF
iptables-restore < /etc/iptables/rules.v4
```
5. You should have internet connection at that time, let's reboot the server and see if everything still working as should be.

