#!/bin/bash
######################################################################
#       dyndns_iptables.sh
#   written by Maxim Ivchenko
#       18 July, 2013
#
#   The script will be add a iptables rule for a dyndns domain.
#   The list of dyndns domins will be locate in the file dyndns_domain
#
#   Format of the file dyndns_domain:
#       domain:port.protocol,[port.protocol]
#
#   Example:
#       example.ru:8000.tcp,7081.udp,12000-12050.tcp
#
#   Run of script:
#       dyndns_iptables.sh /usr/local/bin/dyndns_domain
#######################################################################
# version: 1.0

IPTABLES="/sbin/iptables"
CHAIN="DYNDNS"
DOMAINS="$1"
PROGRAMM_NAME=`basename $0`

if [ ! -e ${DOMAINS} ];
then
    echo "The file ${DOMAINS} doesn't exist"
    exit 1
fi

# Logging to local0
exec 1> >( logger -p user.notice -t "${PROGRAMM_NAME}[$$]: notice" )
exec 2> >( logger -p user.notice   -t "${PROGRAMM_NAME}[$$]: notice" )
exec 3> >( logger -p user.notice   -t "${PROGRAMM_NAME}[$$]: notice" )


# Flush CHAIN
${IPTABLES} -F ${CHAIN}

# Add of the domains
for domain in `cat ${DOMAINS} | grep -v "^#"`
do
    LIST_PORTS=`echo $domain | awk -F ":" '{print $2}' | tr "," " "`
    DOMAIN=`echo $domain | awk -F ":" '{print $1}'`

    for PORT in ${LIST_PORTS}
    do
        PROTOCOL=`echo $PORT | awk -F "." '{print $2}'`
        PORT=`echo $PORT | awk -F "." '{print $1}' | tr "-" ":"`
        echo ${PORT}
        ${IPTABLES} -I ${CHAIN} -p ${PROTOCOL} -s ${DOMAIN} --dport ${PORT} -m comment --comment "${DOMAIN}" -j ACCEPT 1>&2 > /dev/null

        if [ $? -eq 0 ]; then
            echo "I added the rule of IPTABLES for the domain ${DOMAIN}, port ${PORT}, protocol ${PROTOCOL}"
        else
            echo "I can't add the rule of IPTABLES for the domain ${DOMAIN}, port ${PORT}, protocol ${PROTOCOL}"
        fi 
    done
done

/sbin/service iptables save
