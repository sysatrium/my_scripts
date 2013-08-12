###WEBCALL2###
HOST_WEBCALL2="db.int"
export PGPASSWORD="test1"

if [ ! -d ${STORAGE}/${HOST_WEBCALL2} ]; then
    mkdir ${STORAGE}/${HOST_WEBCALL2}
fi

pg_dump -Fc --file=${STORAGE}/${HOST_WEBCALL2}`date +"/webcall2-%Y-%m-%d.dump"` --compress=3 --serializable-deferrable --host=${HOST_WEBCALL2} --port=5432 --username=test1 webcall2

if [ $? -eq 0 ]; then
    echo "The backup of database webcall2 on ${HOST_WEBCALL2} was completed successfully"
else
    echo "The backup of database webcall2 on ${HOST_WEBCALL2} was completed unsuccessfully"
fi

unset PGPASSWORD
