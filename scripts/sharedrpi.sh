#!/bin/bash
if mountpoint -q "/mnt/sharedrpi";
  then
	echo "Shared volume mount = OK"
  else
	mount -t cifs //IP/SHAREDRPI /mnt/sharedrpi -o credentials=/scripts/.smbcredentials,iocharset=utf8
fi