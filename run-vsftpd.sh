#!/bin/bash

# If no env var for FTP_USER has been specified, use 'admin':
if [[ -z "${FTP_USER}" ]]; then
    echo "FTP_USER is not set"
	exit 1
fi

# If no env var has been specified, generate a random password for FTP_USER:
if [[ -z "${FTP_PASS}" ]]; then
    export FTP_PASS=$(cat /dev/urandom | tr -dc A-Z-a-z-0-9 | head -c${1:-32})
fi

# Create home dir and update vsftpd user db:
mkdir -p "/home/vsftpd/${FTP_USER}"
chown -R ftp:ftp /home/vsftpd/

echo -e "${FTP_USER}\n${FTP_PASS}" > /etc/vsftpd/virtual_users.txt
/usr/bin/db_load -T -t hash -f /etc/vsftpd/virtual_users.txt /etc/vsftpd/virtual_users.db
rm /etc/vsftpd/virtual_users.txt

# Set passive mode parameters:
if [[ -z "$PASV_ADDRESS" ]]; then
    export PASV_ADDRESS=$(/sbin/ip route|awk '/default/ { print $3 }')
fi

CONFBCK=$(cat /etc/vsftpd/vsftpd.conf | grep -e pasv_address -e pasv_max_port -e pasv_min_port -e pasv_addr_resolve -e pasv_enable -e file_open_mode -e local_umask -e xferlog_std_format -e reverse_lookup_enable -e pasv_promiscuous -e port_promiscuous)
if [ -n "${CONFBCK}" ] ; then
echo "=== these will be changed in vsftpd.conf ==="
echo "${CONFBCK}"
echo "=== these will be changed in vsftpd.conf ==="
fi

echo "$(cat /etc/vsftpd/vsftpd.conf|grep -v -e pasv_address -e pasv_max_port -e pasv_min_port -e pasv_addr_resolve -e pasv_enable -e file_open_mode -e local_umask -e xferlog_std_format -e reverse_lookup_enable -e pasv_promiscuous -e port_promiscuous)" > /etc/vsftpd/vsftpd.conf
echo "pasv_address=${PASV_ADDRESS}" >> /etc/vsftpd/vsftpd.conf
echo "pasv_max_port=${PASV_MAX_PORT}" >> /etc/vsftpd/vsftpd.conf
echo "pasv_min_port=${PASV_MIN_PORT}" >> /etc/vsftpd/vsftpd.conf
echo "pasv_addr_resolve=${PASV_ADDR_RESOLVE}" >> /etc/vsftpd/vsftpd.conf
echo "pasv_enable=${PASV_ENABLE}" >> /etc/vsftpd/vsftpd.conf
echo "file_open_mode=${FILE_OPEN_MODE}" >> /etc/vsftpd/vsftpd.conf
echo "local_umask=${LOCAL_UMASK}" >> /etc/vsftpd/vsftpd.conf
echo "xferlog_std_format=${XFERLOG_STD_FORMAT}" >> /etc/vsftpd/vsftpd.conf
echo "reverse_lookup_enable=${REVERSE_LOOKUP_ENABLE}" >> /etc/vsftpd/vsftpd.conf
echo "pasv_promiscuous=${PASV_PROMISCUOUS}" >> /etc/vsftpd/vsftpd.conf
echo "port_promiscuous=${PORT_PROMISCUOUS}" >> /etc/vsftpd/vsftpd.conf

# Get log file path
export LOG_FILE=$(grep xferlog_file /etc/vsftpd/vsftpd.conf|cut -d= -f2)

# stdout server info:
if [[ -z "$LOG_STDOUT" || "${LOG_STDOUT}" == "false" ]]; then
cat << EOB
	*************************************************
	*                                               *
	*    Docker image: fauria/vsftpd                *
	*    https://github.com/fauria/docker-vsftpd    *
	*                                               *
	*************************************************

	SERVER SETTINGS
	---------------
	· FTP User: $FTP_USER
	· FTP Password: $FTP_PASS
	· Log file: $LOG_FILE
	· Redirect vsftpd log to STDOUT: No.
EOB
else
    /usr/bin/ln -sf /proc/1/fd/1 "${LOG_FILE}"
fi

# Run vsftpd:
&>/dev/null /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf
