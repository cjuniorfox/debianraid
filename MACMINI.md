# Macmini as router with PPPoE and using virtual network interface (VLAN)

First, we need to install the missing firmware files.

```
apt install isenkram-cli
isenkram-autoinstall-firmware
```
If you want to install ssh or any desktop environment, run **tasksel**.

Macmini have only one network adapter. To make it act as a rounter, it needed at least two adapter. An alternative it's using VLAN and manageable switch (can be any manageable switch or some router with OpenWRT installed. Mine it's a TP-Link Archer C7 with works great), Install the **VLAN**
```
apt install vlan && echo 8021q >> /etc/modules && modprobe 8021q
```

Create your VLAN adapters

VLAN 1 (LAN)
```
cat << EOF > /etc/network/interfaces.d/lan
auto vlan1
iface vlan1 inet static
        address 10.1.1.10
        netmask 255.255.255.0
        network 10.1.1.0
        broadcast 10.1.1.255
        vlan_raw_device enp4s0f0
EOF
```

VLAN 2 (WAN)
```
cat << EOF > /etc/network/interfaces.d/wan 
auto vlan2
iface vlan2 inet manual
vlan_raw_device enp4s0f0
EOF
```
## Getting online

It's time to configure the WAN connection using the VLAN adapter we created. At that example, let's configure a PPPoE connection.

```
apt install ppp
cat << EOF > /etc/ppp/peers/your_provider_name
plugin rp-pppoe.so vlan2

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
Place your username/passoword at file **/etc/ppp/pap-secrets** for wherever reason.
```
echo "ppp_username * ppp_password" >> /etc/ppp/pap-secrets
```
Let's test if our connection it's up and running.
```
pon your_provider_name
```
To disconnect, just run 
```
poff -a
```
Set the **/etc/network/interfaces** file to connect your PPPoE server automatically at bring up.
```
cat << EOF > /etc/network/interfaces.d/wan
auto auto vlan2
iface vlan2 inet ppp
  pre-up /sbin/ip link set dev enp4s0f0.2 up
  provider your_provider_name
vlan_raw_device enp4s0f0
EOF
```

## Let's make our server the internet router

We bring our server alive at the internet, but it's isn't a internet router yet. To do it, we need to setup some things, like a DHCP/DNS Server and configure our routing table.

1. Install and configure the DHCP/DNS server **dnsmasq**
```
apt install dnsmasq
cat << EOF > /etc/dnsmasq.d/lan.conf
interface=vlan1
listen-address=127.0.0.1
domain=lan
dhcp-range=10.1.1.100,10.1.1.150,12h
EOF
```
2. IPV4 Forwarding
```
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.d/99-sysctl.conf 
```
3. It's **iptables** time. We need to **masquerade** the connection to, effectivally, make our server work as a router. We also need the persist the settings, because if not, after rebooting the server, the masquerade configuration it's losted and you need to setup your iptables settings again. So, let's install **iptables-persistent**, set the rules and make those settings persistents.
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
4. You should have internet connection at that time, let's reboot the server and see if everything still working as should be.

## Bonus. Put the DVD Reader to act as auto CD Player when some CD it's inserterd.

If your unit had a working DVD reader installed and you have some good speakers laying around, with a little scripting, you can make the Macmini play audio CDs automatically when some CD it's inserted to the sytem.

Let's install the whole needed to make that happen
```
apt install mplayer pulseaudio alsa-utils
```
To make the CD play automatically, we need to trigger a device event. The correct tool to manage that on linux it's called *udevadm*. So, you think it's just make a very little script to play the CD when the disk it's inserted and it's done. But wasn't. The device driven event trigger was not made to a such long process, like reproducing a full lenght CD audio. If you do so, the event trigger will kill the process after while and the CD just stops playing after a couple minutes. The best way to address that, it's creating a systemd service and triggering at the device event. The full lenght disc will play and you will being able the check the status of the event and even kill it, if some some reason you with so.


1. Create a script to reproduce the CD. That it's in any means a fancy one. It's just starts to play the CD and eject it when it's done.
```
cat << EOF > /usr/local/bin/playcd
#!/bin/bash
blockdev --getsize64 /dev/sr0 #It's just to bring the device online before reproducing
mplayer cdda:// -cache 2000 #Caching to prevent audio dropping
eject /dev/sr0
EOF
chmod +x /usr/local/bin/playcd
```
2. Create a systemd service commanding to run the script we just created
```
cat << EOF > /etc/systemd/system/playcd.service
[Unit]
Description=Auto play CDs when inserted

[Service]
ExecStart=/usr/local/bin/playcd
EOF
chmod +x /etc/systemd/system/playcd.service
```

3. Let's create the device trigger event to initiate the service we just created.
```
cat << EOF > /etc/udev/rules.d/playcd.rules
KERNEL=="sr0", ENV{SYSTEMD_WANTS}+="playcd.service"
EOF
```

Now, just put a CD and the MacMini will start playing the CD over the output jack.
