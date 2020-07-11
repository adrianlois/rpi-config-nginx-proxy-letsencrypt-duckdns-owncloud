#!/bin/bash
if mountpoint -q "/mnt/sharedrpi";
then
	echo "Shared volume mount = OK"
else
	mount -t cifs //IP/SHAREDRPI /mnt/sharedrpi -o username=USER,password=PASS,domain=DOMAIN/HOSTNAME
fi
