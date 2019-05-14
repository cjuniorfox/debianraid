#!/bin/bash
#Chroot additional installation

echo "DebianRAID" > /etc/hostname
chown root /usr/local/bin/snapraid && \
chown root /etc/snapraid.conf && \
chmod +x /usr/local/bin/snapraid

echo "America/Sao_Paulo" > /etc/timezone && \
    echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \
    dpkg-reconfigure -f noninteractive tzdata && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    echo '# KEYBOARD CONFIGURATION FILE
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT="alt-intl"
XKBOPTIONS=""
BACKSPACE="guess"' > /etc/default/keyboard 

apt-get update && \
DEBIAN_FRONTEND=noninteractive \
apt-get install \
    -yq \
    linux-image-amd64 \
    live-boot \
    network-manager net-tools wireless-tools wpagui ufw \
    locales pciutils \
    systemd-sysv \
    curl openssh-client \
    xfsprogs \
    ssh \
    gdisk \
    fuse mergerfs \
    bcache-tools \
    vim \
    whiptail \
    qemu-kvm libvirt-clients \
    libvirt-daemon-system \
    bridge-utils \
    libguestfs-tools \
    virtinst \
    libosinfo-bin \
    ovmf \
    uml-utilities \
    network-manager \
    iputils-ping \
    apt-transport-https \
    ca-certificates curl \
    gnupg2 software-properties-common

#shares
    groupadd network && \
    chgrp network /share/Download \
     /share/ISO \
     /share/Media \
     /share/Files \
     /share/timemachine

    chmod -R 770 /share/Download/ \
     /share/ISO/ \
     /share/Media/ \
     /share/Files/ \
     /share/timemachine/

#samba
    apt install libcups2 samba samba-common cups &&
    	mv /etc/samba/smb.conf /etc/samba/smb.conf.bak &&
    	mkdir -p /var/spool/samba/ &&
    	chmod 1777 /var/spool/samba/ &&
    	curl -sL "https://raw.githubusercontent.com/cjuniorfox/debianraid/master/chroot/smb.conf" \
    		-o /etc/samba/smb.conf

#netatalk
    TRACKER_VERSION="1.0"
    apt-get update && apt-get install -qy build-essential libevent-dev libssl-dev libgcrypt11-dev \
        libkrb5-dev  libpam0g-dev libwrap0-dev libdb-dev libtdb-dev default-libmysqlclient-dev \
        avahi-daemon libavahi-client-dev libacl1-dev libldap2-dev libcrack2-dev systemtap-sdt-dev \
        libdbus-1-dev libdbus-glib-1-dev libglib2.0-dev tracker libcrack2-dev \
        libtracker-sparql-$TRACKER_VERSION-dev libtracker-miner-$TRACKER_VERSION-dev 
    mkdir /tmp/netatalk3 && cd /tmp/netatalk3 && \
    curl -L https://sourceforge.net/projects/netatalk/files/latest/download?source=files --output /tmp/netatalk3/netatalk.tar.bz2 && \
    tar -xvf /tmp/netatalk3/netatalk.tar.bz2
    netatalkDir=$(find ./ -name 'netatalk-*' -type d)
    cd $netatalkDir
    ./configure \
            --with-init-style=debian-sysv \
            --without-libevent \
            --without-tdb \
            --with-cracklib \
            --enable-krbV-uam \
            --with-pam-confdir=/etc/pam.d \
            --with-dbus-sysconf-dir=/etc/dbus-1/system.d \
            --with-tracker-pkgconfig-version=$TRACKER_VERSION
    make && make install
    cd ~
    rm -rf /tmp/netatalk /tmp/netatalk3 /tmp/netatalk.tar.bz2
    systemctl enable netatalk

    apt-get remove --purge build-essential -y

    curl -sL "https://raw.githubusercontent.com/cjuniorfox/debianraid/master/chroot/afp.conf" \
    	-o /usr/local/etc/afp.conf

    apt install insserv -y
    insserv avahi-daemon && \
    insserv netatalk

#transmission
apt-get update && apt-get install transmission-daemon apache2 -y
/etc/init.d/transmission-daemon stop
DOWNLOAD_PATH=/share/Download
sed -i '/download-dir/s/.*/"download-dir": "'${DOWNLOAD_PATH//\//\\/}'",/' /var/lib/transmission-daemon/info/settings.json
sed -i 's/}/,\n   "umask" : 2\n}/' /var/lib/transmission-daemon/info/settings.json

echo '
        <Directory />
           Redirect permanent /transmission /transmission/web/
        </Directory>
              <Proxy *>
                      Order deny,allow
                      Allow from all
              </Proxy>
              ProxyPass /transmission http://localhost:9091/transmission
              ProxyPassReverse /transmission http://localhost:9091/transmission
    ' > /etc/apache2/sites-available/transmission.conf
    a2ensite transmission
    a2enmod proxy
    a2enmod proxy_http
    a2enmod headers
    service apache2 restart

#Docker
    curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - && \
    apt-key fingerprint 0EBFCD88 && \
    add-apt-repository  "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs)  stable" && \
    apt-get update && \
    apt-get install docker-ce -y && \
    apt-get clean && \
    curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose
    
#kvm-vfio    
    echo -e "vfio\nvfio_iommu_type 1\nvfio_pci\nvfio_virqfd" > /etc/modules
    update-initramfs -u
    echo -e "senha123\nsenha123" | (passwd root)
    rm -rf initrd.img.old vmlinuz.old

#webVirt
    apt-get update && \
    apt-get install -qy \
      apache2 git python-pip python-libvirt python-libxml2 novnc supervisor insserv 
    git clone git://github.com/retspen/webvirtmgr.git && \
    cd webvirtmgr && \
    pip install -r requirements.txt
    ./manage.py syncdb --noinput && \
    ./manage.py collectstatic --noinput
    cd ..
    mv webvirtmgr /opt/
    
    service novnc stop
    insserv -r novnc
    
  echo "#!/bin/sh
### BEGIN INIT INFO
# Provides:          nova-novncproxy
# Required-Start:    $network $local_fs $remote_fs $syslog
# Required-Stop:     $remote_fs
# Default-Start:     
# Default-Stop:      
# Short-Description: Nova NoVNC proxy
# Description:       Nova NoVNC proxy
### END INIT INFO" > /etc/insserv/overrides/novnc


echo "[program:webvirtmgr]
command=/usr/bin/python /opt/webvirtmgr/manage.py run_gunicorn -c /opt/webvirtmgr/conf/gunicorn.conf.py
directory=/opt/webvirtmgr
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/webvirtmgr.log
redirect_stderr=true
user=root

[program:webvirtmgr-console]
command=/usr/bin/python /opt/webvirtmgr/console/webvirtmgr-console
directory=/opt/webvirtmgr
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/webvirtmgr-console.log
redirect_stderr=true
user=root
" > /etc/supervisor/conf.d/webvirtmgr.conf
service supervisor start
apt remove --purge git
apt clean

#proxy apache
  #monta proxy_http baseado nos diretorios de instalação.
  webvirtRedirect=''
  for d in /opt/webvirtmgr/*/ ; do 
      webvirtRedirect="$webvirtRedirect\n  $(echo ProxyHTMLURLMap /`basename "$d"`/ /webvirtmgr/`basename "$d"`/| sed 's|/webvirtmgr/webvirtmgr|/webvirtmgr|')";
  done

  echo -e "
Redirect permanent /webvirtmgr /webvirtmgr/
 
ProxyRequests Off
  
<Proxy *>
  Order deny,allow
  Allow from all
</Proxy>
  
ProxyPass /webvirtmgr/ http://localhost:8000/
ProxyPassReverse /webvirtmgr/ http://localhost:8000/

<Location /webvirtmgr/>  
  ProxyPassReverse /
  ProxyHTMLEnable On  
  ProxyHTMLExtended On
  $webvirtRedirect
  ProxyHTMLURLMap /info/ /webvirtmgr/info/
  ProxyHTMLURLMap /host/ /webvirtmgr/host/
  ProxyHTMLURLMap /instances/ /webvirtmgr/instances/
  RequestHeader    unset  Accept-Encoding  
</Location>

<Location />
    Order allow,deny
    Allow from all
</Location>
  " > /etc/apache2/sites-available/webvirtmgr.conf

    
  a2ensite webvirtmgr
  a2enmod proxy
  a2enmod proxy_http
  a2enmod proxy_html
  service apache2 reload

#webmin
  echo deb http://download.webmin.com/download/repository sarge contrib > /etc/apt/sources.list.d/webmin.list
  rm ./tmp/jcameron-key.asc
  curl http://www.webmin.com/jcameron-key.asc --output /tmp/jcameron-key.asc 
  apt-key add /tmp/jcameron-key.asc 
  apt-get update && apt-get install apache2 webmin -qy
  echo "Configurando apache para repassar Webmin"
  echo '
  Redirect permanent /webmin /webmin/
  
  ProxyRequests Off
  
  <Proxy *>
    Order deny,allow
    Allow from all
  </Proxy>
  
  ProxyPass /webmin/ http://localhost:10000/
  ProxyPassReverse /webmin/ http://localhost:10000/
  ' > /etc/apache2/sites-available/webmin.conf

  if !(grep -q "webprefix=/webmin" "/etc/webmin/config"); then
    echo "webprefix=/webmin
webprefixnoredir=1
referer=1">> /etc/webmin/config
  fi
  sed -i s/ssl=1/ssl=0/ /etc/webmin/miniserv.conf
  a2ensite webmin
  a2enmod proxy
  a2enmod proxy_http
  service apache2 restart
  service webmin restart
#firmware-realtek
    echo "#realtek firmware
deb http://ftp.de.debian.org/debian stretch main non-free
deb-src  http://ftp.de.debian.org/debian stretch main non-free" > /etc/apt/sources.list.d/realtek.list
    apt-get update && apt-get install firmware-realtek
exit