## Steps Configuration my Raspberry Pi

Configuration steps for RaspberryPi and deploy containers Docker: nginx, nginx-proxy, letsencrypt, duckddns and onwcloud

### Download image Ubuntu for RPI
- https://ubuntu.com/download/raspberry-pi
- https://ubuntu.com/tutorials/how-to-install-ubuntu-on-your-raspberry-pi#2-prepare-the-sd-card

#### Add local user
```
useradd -m -s /bin/bash adrian
usermod -G sudo adrian
passwd adrian
```
#### Delete user by default RPI
```
userdel -f ubuntu
```
#### Change hostname RPI
```
echo "rpi" > /etc/hostname
echo "IP rpi" >> /etc/hosts
```

#### nano editor config (.nanorc)
```
set tabsize 4
set autoindent
set smooth
set linenumbers
set nohelp
set softwrap
```

#### Disable grace period sudo
- /etc/sudoers
```
echo "Defaults timestamp_timeout=0" >> /etc/sudoers
```

#### Package installation requirements
```
apt update -y && apt install -y sysstat htop mlocate bat cifs-utils p7zip-full p7zip-rar zip unzip tree fail2ban apache2-utils
```

#### Add aliases to my .bashrc
```
echo "alias cat='batcat'" >> $HOME/.bashrc
```

#### SSH server config
- /etc/ssh/sshd_config
```
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile  .ssh/authorized_keys
AllowUsers adrian
AllowTcpForwarding yes
GatewayPorts yes
X11Forwarding yes
AcceptEnv LANG LC_*
Subsystem sftp  /usr/lib/openssh/sftp-server
```
```
systemctl enable ssh && systemctl restart ssh
```

#### SSH permission in directories and configure public key authentication
```
su - adrian
mkdir -p -m 700 ~/.ssh
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
(install -m 600 /dev/null ~/.ssh/authorized_keys)
```
> set public key (ssh-rsa ...pubkey... rsa-key-xxxxxxxx)
```
adrian@rpi:~$ tree -pugah
├── [drwx------ adrian   adrian   4.0K]  .ssh
│   └── [-rw------- adrian   adrian    398]  authorized_keys
└── [lrwxrwxrwx root     root       14]  sharedrpi -> /mnt/sharedrpi
```

#### fail2ban config

- /etc/fail2ban/jail.conf
```
ignoreip = 127.0.0.1/8 ::1 <MY_NETWORK_IP>/<CIDR>
[sshd]
port     = ssh
logpath  = %(sshd_log)s
backend  = %(sshd_backend)s
bantime  = 172800
findtime = 600
maxretry = 3
```
```
systemctl enable fail2ban && systemctl restart fail2ban
```

#### Create shared and scripts folder
```
mkdir /mnt/sharedrpi
ln -s /mnt/sharedrpi /home/adrian/sharedrpi

mkdir /scripts && cd /scripts
git clone https://github.com/adrianlois/rpi-config-nginx-proxy-letsencrypt-duckdns-owncloud.git
mv rpi-config-nginx-proxy-letsencrypt-duckdns-owncloud/* . && mv scripts/* . && mv scripts/.[!.]* .
rm -rf rpi-config-nginx-proxy-letsencrypt-duckdns-owncloud/ docker/nginx/htpasswd scripts/ LICENSE README.md

chmod 600 .smbcredentials docker/.env
cp -r docker/nginx/.nginx-error-pages /home/adrian/sharedrpi/
```

#### Crontab config
```
chmod 700 /scripts/sharedrpi.sh
```
- /etc/crontab
```
# @reboot sleep 30 && /scripts/sharedrpi.sh
*/1 * * * * root /scripts/sharedrpi.sh
```

#### htpasswd file for nginx or apache2
```
htpasswd -c /scripts/docker/nginx/htpasswd USER
chmod 644 /scripts/docker/nginx/htpasswd
```

#### External USB format ext4 and mount for ownCloud
```
mkdir -m 777 /media/owncloud

fdisk -l
mkfs.ext4 /dev/sdaX

lsblk -o NAME,FSTYPE,SIZE /dev/sdaX
blkid -o list
(ls -l /dev/disk/by-uuid)
echo -e "\nUUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  /media/owncloud  ext4  defaults  0  0" >> /etc/fstab
mount -a
```

### Install Docker & Docker Compose
- https://docs.docker.com/engine/install/ubuntu/
- https://docs.docker.com/compose/install/
```
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && sudo python3 get-pip.py
apt install -y python3-pip libffi-dev
curl -sSL https://get.docker.com | sh
pip3 install docker-compose
```

#### Running docker without sudo from another user
```
sudo usermod -aG docker ${USER}
id -nG
```

#### Delay docker service startup at system boot

Start nginx containers after mounting the sharedrpi sharedrpi share (crontab script sharedrpi.sh).

```
sudo systemctl edit docker.service

[Service]
ExecStartPre=/bin/sleep 90
```

#### Deploy compatible docker containers for RaspberryPi

```
cd /scripts/docker
docker-compose up -d
```

*docker-compose.yaml*
- duckdns
- nginx
- nginx-proxy (80)
- owncloud (8080)
- mariadb
- redis

*docker-compose2.yaml*
- duckdns
- nginx
- nginx-proxy (80,443)
- letsencrypt

*docker-compose3.yaml*
- duckdns
- nginx
- nginx-proxy (80)

---
## Optional configs services

#### Samba config (optional)
- /etc/samba/smb.conf
```
[global]
workgroup = WORKGROUP
usershare allow guests = yes

# Shared resource with anonymous access without password
[sharedrpi]
   comment = Shared rpi
   path = /mnt/sharedrpi
   browseable = Yes
   writeable = Yes
   public = yes

security = SHARE
```
This service will be stopped.
```
systemctl disable smbd
systemctl stop smbd
```

#### Apache2 config (optional)
```
apt install -y apache2
# Update latest version apache2
apt install --only-upgrade apache2
```

Required modules.
```
apache2 -M
ls /etc/apache2/mods-available/
a2enmod auth_basic
a2enmod authn_file
a2enmod authz_user
a2enmod authn_core
a2enmod authz_core
```
- vhost 000-default.conf
```
DocumentRoot /var/www/sharedrpi
<Directory "/var/www/sharedrpi">
        AuthType Basic
        AuthName "Restricted access"
        AuthUserFile /var/www/htpasswd
        Require user USER
</Directory>
```
- /etc/apache/apache2.conf
```
# Hide Apache2 server info from Index Of /
ServerSignature Off
ServerTokens Prod
```

#### Proftpd config (optional)
- /etc/proftpd/proftpd.conf
```
MaxInstances                    3
User                            proftpd
Group                           nogroup
AllowOverwrite                  on

ServerName                      "FTP Server"

DefaultRoot /mnt/sharedrpi
Include /etc/proftpd/conf.d/

# Limit connection to only one user, jailed in their directory
DefaultRoot /mnt/ftp
<Limit LOGIN>
AllowUser USER
DenyAll
</Limit>
```

#### SFTP config (optional)
```
mkdir /var/sftpusers
groupadd sftp_users
useradd -d /var/sftpusers -G sftp_users sftpuser1
chown -R root:sftp_users /var/sftpusers/
chmod -R 770 /var/sftpusers/
```

- /etc/ssh/sshd_config
```
#Subsystem sftp /usr/libexec/openssh/sftp-server
Subsystem sftp internal-sftp
Match Group sftp_users
ChrootDirectory /var/sftpusers
ForceCommand internal-sftp
X11Forwarding no
AllowTcpForwarding no
```
