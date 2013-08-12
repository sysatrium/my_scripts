DB_USER="test"
DB_PASSWORD="test"
BACKUP_DATABASES_VAS="test1 test2"

# Backup of MySQL in the mode master-master
function backup_mysql_mm {
        local DB_USER="$1"
        local DB_PASSWORD="$2"
        local BACKUP_DATABASES="$3"
        local SERVERS=`get_servers $4`

        for server in ${SERVERS}
        do
            [ ! -d "${STORAGE}/${server}" ] && mkdir ${STORAGE}/${server}

            HA_STATUS=`ssh ${server} "/usr/bin/cl_status rscstatus"`
            Slave_IO_Running=`mysql -u ${DB_USER} -p${DB_PASSWORD} -h ${server} -e "show slave status\G" | awk '$1 == "Slave_IO_Running:" {print $2}'`
            Slave_SQL_Running=`mysql -u ${DB_USER} -p${DB_PASSWORD} -h ${server} -e "show slave status\G" | awk '$1 == "Slave_SQL_Running:" {print $2}'`

            if [ ${HA_STATUS} = "none" -a ${Slave_IO_Running} = "Yes" -a ${Slave_SQL_Running} = "Yes" ]; then
                echo "I'm slave - ${server} and I'm running backup of MySQL"
                for db in `echo $BACKUP_DATABASES`
                do
                    echo "Backuping of the database ${db}"
                    mysqldump -u ${DB_USER} -p${DB_PASSWORD} -h ${server} --add-drop-table --master-data --single-transaction --extended-insert -R -B ${db} -r ${STORAGE}/${server}/${db}_${DATE}_mysql_dump.sql && gzip -f ${STORAGE}/${server}/${db}_${DATE}_mysql_dump.sql
                    echo "The backup of the database ${db} has ended successfully"
                done
            else
                if [ ${HA_STATUS} = "all" ] && [ ${Slave_IO_Running} != "Yes" -o ${Slave_SQL_Running} != "Yes" ]; then
                   echo "I'm master - ${server}. My slave is dead. I'm running backup of MySQL"
                   for db in `echo $BACKUP_DATABASES`
                   do
                       echo "Backuping of the database ${db}"
                       mysqldump -u ${DB_USER} -p${DB_PASSWORD} -h ${server} --add-drop-table --single-transaction --extended-insert -R -B ${db} -r ${STORAGE}/${server}/${db}_${DATE}_mysql_dump.sql && gzip -f ${STORAGE}/${server}/${db}_${DATE}_mysql_dump.sql
                       echo "The backup of the database ${db} has ended successfully"
                   done
                fi
            fi
        done
}
