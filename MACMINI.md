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

