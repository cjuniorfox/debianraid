# Macmini as router with PPPoE server and using virtual network interface (VLAN)

1. Install [broadcom-sta-dkms_6.30.223.271-19_all.deb](http://ftp.br.debian.org/debian/pool/non-free/b/broadcom-sta/broadcom-sta-dkms_6.30.223.271-19_all.deb).
```
wget http://ftp.br.debian.org/debian/pool/non-free/b/broadcom-sta/broadcom-sta-dkms_6.30.223.271-19_all.deb && apt install ./broadcom-sta-dkms_6.30.223.271-19_all.deb
```
2. If you want to install ssh or any environment, run **tasksel**.
3. Install **VLAN**
```
apt install vlan && echo 8021q >> /etc/modules && modprobe 8021q
```
4. Setup your PPPOE connection, you can use your VLAN if you wish to. Do not forget to check the networking interface name ifname. At that example, the name it's **enp4s0f0**, but can be another name, depending of your setup. At mine, I'm using a manageable switch and using VLAN with ID 1.
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
5. Place your username/passoword at file **/etc/ppp/chap-secrets** for wherever reason.
```
echo "ppp_username ppp_password" >> /etc/ppp/chap-secrets
```
6. You can test your connection running:
```
pon your_provider_name
```
To disconnect, just run 
```
poff -a
```
7. Configure your **/etc/network/interfaces** file to connect your PPPoE server automatically at bring up.
```
cat << EOF > /etc/network/interfaces.d/pppoe-wan
auto enp4s0f0.1
iface enp4s0f0.1 inet manual
  pre-up /sbin/ip link set dev enp4s0f0.10 up
  provider your_provider_name
EOF
```
