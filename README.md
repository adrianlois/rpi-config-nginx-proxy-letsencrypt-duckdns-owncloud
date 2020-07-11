## Configuration steps for RPI

#### Add local user
```
useradd -m -s /bin/bash adrian
usermod -G sudo adrian
passwd adrian
```
#### Delete user by default RPI
```
userdel -f pi
```
#### Change hostname RPI
```
echo "rpi" > /etc/hostname
echo "IP rpi" >> /etc/hosts
```

#### Install Docker & Docker Compose
```
https://docs.docker.com/engine/install/debian/
https://docs.docker.com/compose/install/
```

#### SSH server config
- /etc/ssh/sshd_config
```
PasswordAuthentication yes
PubkeyAuthentication yes
AllowUsers adrian
AllowTcpForwarding yes
GatewayPorts yes
X11Forwarding yes
AcceptEnv LANG LC_*
Subsystem sftp  /usr/lib/openssh/sftp-server
```

#### SSH permission directories
```
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### Config fail2ban:
```
apt-get install -y fail2ban
systemctl enable fail2ban
systemctl restart fail2ban
```
- /etc/fail2ban/jail.conf
```
ignoreip = 127.0.0.1/8 ::1 NETWORK_IP/24
[sshd]
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
bantime = 172800
findtime = 600
maxretry = 3
```

#### Create shared folder
```
mkdir /mnt/sharedrpi
ln -s /mnt/sharedrpi /home/USER/sharedrpi
```

#### Crontab config
- /etc/crontab
```
# @reboot sleep 30 && /scripts/sharedrpi.sh
*/1 * * * * root /scripts/sharedrpi.sh
```

#### htpasswd file for nginx or apache2
```
apt install -y apache2-utils
htpasswd -c /scripts/docker/nginx/htpasswd USER
```

#### Deploy docker containers

- duckdns
- nginx
- nginx-proxy
- letsencrypt
```
cd /scripts/docker
docker-compose up -d
```

---
## Optional configs

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

#### Config proftpd (optional)
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