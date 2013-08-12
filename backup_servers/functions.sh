function syslog_begin
{
trap 'echo "Control-C disabled"' SIGINT SIGTERM SIGCHLD

local program_name=${0##*/}

exec 1> >( logger -p user.notice -t "$program_name[$$]: debug" )
exec 2> >( logger -p user.notice   -t "$program_name[$$]: error" )
exec 3> >( logger -p user.notice   -t "$program_name[$$]: warning" )

echo "Starting..."
}

function syslog_end
{
echo "Completed"
trap SIGINT SIGTERM SIGCHLD
}

function ensure_one_instance
{
local program_name=${0##*/}
local lock_file=/tmp/$program_name.pid

if [ -r $lock_file ]
then
	local locked_process_id=`sed 's/[^0-9]//g' $lock_file`
	if [ -z "$locked_process_id" ] #Make Sure locked_process_id contains a value
	then
		echo "$lock_file exists but contains no process id" >&2
		exit 101
	else
		grep $program_name /proc/$locked_process_id/cmdline >/dev/null 2>&1
		case $? in
		0)
			echo "Script is currently running pid[$locked_process_id], exiting..." >&3
			exit 102
			;;
		1)
			echo "Old lock file with pid[$locked_process_id] exists but the running process is not ours"
			echo "Overwriting old pid with new pid value[$$]"
			;;
		2)
			echo "Old lock file with pid[$locked_process_id] exists but process is not running"
			echo "Overwriting old pid with new pid value[$$]"
			;;
		*)
			echo "Internal error during ensure_one_instance happened, see debug log above, exiting..." >&2
			exit 103
			;;
		esac
	fi
fi

trap "rm $lock_file" EXIT
echo $$ > $lock_file

if [ $? -ne 0 ]
then 
	exit "Could not create lock file[$lock_file], exiting..." >&2
	exit 104
fi
}
