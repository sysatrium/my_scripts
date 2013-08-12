#!/bin/bash
#
######################################################################################################
#       backup.sh
#   written by Maxim Ivchenko
#       12 August, 2013
#
#   This script will be do backup of some files of servers
#
#   Run of script:
#      /usr/local/bin/backup.sh /usr/local/bin/backup_servers_list /usr/local/bin/backup_resources_list
#######################################################################################################
#
# version: 1.0


LIB="/usr/local/bin"
DATE=`date +%F`
STORAGE="/srv/backup"
REMOTE_STORAGE="/tmp"
COMMAND_BACKUP="tar --selinux --acls -P --exclude=*.log.* -czf"

# It is the parameters for send of a report about the backup
EMAIL_NOTIFY_ENABLED=1
SMTP_SERVER="mail.example.com"
SMTP_AUTH=0
SMTP_LOGIN="null"
SMTP_PASSWORD="null"
SMTP_FROM="noreply@example.com"
SMTP_TO="event@example.com"
SUBJECT_KEY="Backup of servers on `echo ${DATE}`"
SMTP_LOG="/var/log/sendemail.log"

# It is a list of servers for backup
SERVERS_LIST="$1"

# It is a list of resources for backup
RESOURCES_LIST="$2"


if [ ! -e "${LIB}/functions.sh" ]; then
        echo "I can't including the lib file ${LIB}/functions.sh"
        exit 1
else
        . ${LIB}/functions.sh
fi

if [ -z ${SERVERS_LIST} ] || [ ! -e ${SERVERS_LIST} ]; then
	echo "Usage script: backup.sh /path/servers_list /path/resources_list"
	exit 1
fi

if [ -z ${RESOURCES_LIST} ] || [ ! -e ${RESOURCES_LIST} ]; then
	echo "Usage script: backup.sh /path/servers_list /path/resources_list"
	exit 1
else
    . ${RESOURCES_LIST}
fi

if [ ! -d ${STORAGE} ]; then
    mkdir ${STORAGE}
    if [ $? -ne 0 ]; then
        echo "I can't create ${STORAGE}"
        exit 1
    fi
fi

if [ ! -e ${SMTP_LOG} ]; then
    touch ${SMTP_LOG}
fi


# Send a report about the backup
# run:
#   echo "message" | send_report
#
function send_report {
    if [ $SMTP_AUTH -eq 1 ]; then
        AUTH="-xu \'${SMTP_LOGIN}\' -xp \'${SMTP_PASSWORD}\'"
    else
        AUTH=""
    fi

    /usr/bin/sendEmail -u "${SUBJECT_KEY}" ${AUTH} -q -o timeout=5 -s ${SMTP_SERVER} -f ${SMTP_FROM} -t ${SMTP_TO} -o message-charset=UTF-8 -l ${SMTP_LOG}
}


# Get of list of servers for Backup
# run:
#   get_servers FMN, when FMN - it is the type of the server
#
function get_servers {
    echo `cat ${SERVERS_LIST}  | grep -v "^#" | tr -d " " | grep $1 | awk -F ":" '{print $2}' | tr "," " "`
}


# Backup of files of servers 
# run:
#   backup FMN, when FMN - it is the type of the server
#
function backup {
    TYPE_SERVER="$1[*]"
    local SERVERS=`get_servers $1`
    for server in ${SERVERS}
    do
        echo "Starting of backup on ${server}"
        ssh ${server} "cd ${REMOTE_STORAGE} && ${COMMAND_BACKUP} ${server}_${DATE}.tar.gz `echo ${!TYPE_SERVER} ${ALL[*]}`"
        [ ! -d "${STORAGE}/${server}" ] && mkdir ${STORAGE}/${server}
        scp ${server}:${REMOTE_STORAGE}/${server}_*.tar.gz ${STORAGE}/${server}
        ssh ${server} "cd ${REMOTE_STORAGE} && rm -f ${server}_*.tar.gz"
        gunzip -t ${STORAGE}/${server}/${server}_${DATE}.tar.gz > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "The backup of ${server} has ended successfully"
        fi
    done
}


# Start syslog
syslog_begin

# Backup MySQL
if [ -e ${LIB}/backup_mysql.sh ]; then
    . ${LIB}/backup_mysql.sh
fi

# Backup PostgreSQL
if [ -e ${LIB}/backup_postgresql.sh ]; then
    . ${LIB}/backup_postgresql.sh
fi


# Backup of FMN severs
backup FMN
# Backup of WEB server
backup WEB
# Backup of MAN server
backup MAN
# Backup of KVM servers
backup KVM
# Backup of databases of VAS - VCC, CONFERENCE, URL
backup_mysql_mm "${DB_USER}" "${DB_PASSWORD}" "${BACKUP_DATABASES_VAS}" DB


# Stop syslog
syslog_end

# Send report
echo "
Date: ${DATE}
Host: `hostname`
Status: The backup of servers was completed successfully.

The list of backup files:
`find ${STORAGE} -type f -name "*${DATE}*" -exec ls -lh '{}' ';'`" | send_report
