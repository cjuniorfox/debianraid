# Macmini as router

1. Install [broadcom-sta-dkms_6.30.223.271-19_all.deb](http://ftp.br.debian.org/debian/pool/non-free/b/broadcom-sta/broadcom-sta-dkms_6.30.223.271-19_all.deb).
```
wget http://ftp.br.debian.org/debian/pool/non-free/b/broadcom-sta/broadcom-sta-dkms_6.30.223.271-19_all.deb && apt install ./broadcom-sta-dkms_6.30.223.271-19_all.deb
```
2. If you want to install ssh or any environment, run tasksel.
3. Install **VLAN**
```
apt install vlan && echo 8021q >> /etc/modules && modprobe 8021q
```
4. Install PPPOE
