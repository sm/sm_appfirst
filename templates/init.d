#! /bin/bash
# /etc/init.d/afcollector
#

#
# chkconfig: 2345 51 31
# description: Start/stop AppFirst collector
#

DAEMON=/usr/bin/collector
JMXCOLLECTOR=/usr/share/appfirst/plugins/libexec/jmx-collector/jmxcollector

if [ -e /etc/rc.d/init.d/functions ]
then
    . /etc/rc.d/init.d/functions
    failmsg=failure
    warnmsg=warning
    successmsg=success
    status=status
else
    if [ -e /lib/lsb/init-functions ]
    then
	. /lib/lsb/init-functions
	failmsg=log_failure_msg
	warnmsg=log_warning_msg
	successmsg=log_success_msg
	status=/sbin/pidof
    fi
fi

ld_preload_chk () {
	if [ -f /etc/ld_preload ]; then
	    export LD_PRELOAD=/usr/share/appfirst/libwrap.so.1.0.1
        export LD_LIBRARY_PATH=/usr/share/appfirst
	    $DAEMON --test
	    if [ $? -gt 0 ]; then
		unset LD_PRELOAD
		echo "Warning: overlay issue, preload has been disabled"
		$warnmsg ""
		exit 0
	    fi
	    unset LD_PRELOAD

	    if [ -s /etc/ld.so.preload ]; then
		    exec < /etc/ld.so.preload
		    value=0
		    while read value
		    do
		        grep $value /etc/ld_preload > /dev/null
		        if [ $? -ne 0 ]; then
		            cat $value >> /etc/ld_preload
		        fi
		    done
	    fi

        if [ -e /dev/shm ]; then
            /bin/cp -f /etc/ld_preload /dev/shm/.
            /bin/chmod 644 /dev/shm/ld_preload
            /bin/ln -s /dev/shm/ld_preload /etc/ld.so.preload
        else
            /bin/cp -f /etc/ld_preload /tmp/.
            /bin/ln -s /tmp/ld_preload /etc/ld.so.preload
        fi
	else
	    /bin/rm -f /etc/ld.so.preload
	    $warnmsg "Warning: preload disabled: no ld_preload"
	    exit 0
	fi
}

selinux_chk () {
	if [[ -e /etc/selinux/config ]]
	then
		enforcing=$(getenforce)
		case ${enforcing} in
			(Permissive)
				return 0

				;;
			(Enforcing)
				echo "AppFirst Collector can not be started.  You need to configure selinux to disabled/permissive"
				$failmsg
				exit 0
		  ;;
	  esac
  fi
}

# The rc interface:
case "$1" in
start)
	if /sbin/pidof $DAEMON >> /dev/null
	then
	    echo "AppFirst collector is already running"
	    exit 0
	fi

	# check selinux
	selinux_chk

	export LD_LIBRARY_PATH=/usr/share/appfirst

	# validate ld.so.preload
	ld_preload_chk

	$DAEMON
	RETVAL=$?
	unset LD_LIBRARY_PATH

	if [ -e $JMXCOLLECTOR ]
	then
	    $JMXCOLLECTOR start
	fi

	$successmsg "AppFirst collector has started" "afcollector"
	;;
  stop)
	if [ -f /etc/ld.so.preload ]; then
	    /bin/cp -f /etc/ld.so.preload /etc/ld_preload
	    /bin/sed '/appfirst\/libwrap.so/d' /etc/ld.so.preload > /etc/ld.so.preload
	    flen=`/usr/bin/stat /etc/ld.so.preload | /bin/grep Size | /usr/bin/cut -d: -f2 | /usr/bin/cut -c1-2`
	    if [ $flen -lt 3 ]; then
		/bin/rm /etc/ld.so.preload
	    fi
	fi
	killproc $DAEMON -10
	RETVAL=$?

	if [ -e $JMXCOLLECTOR ]
	then
	    $JMXCOLLECTOR stop
	fi

	$successmsg "AppFirst collector is stopped" "afcollector"
	;;
  restart)
    $0 stop
    sleep 1
    $0 start
	;;
# upgrade is same as 'start' except that it does not check if collector is already running
  upgrade)
    # check selinux
    selinux_chk

    # validate ld.so.preload
    ld_preload_chk

	export LD_LIBRARY_PATH=/usr/share/appfirst
	$DAEMON
	RETVAL=$?
	unset LD_LIBRARY_PATH
	$successmsg "AppFirst collector has started" "afcollector"
	;;
  collector_restart)
	killproc $DAEMON -10
	export LD_LIBRARY_PATH=/usr/share/appfirst
	$DAEMON
	export LD_LIBRARY_PATH=""
	;;
  collector_start)
	if /sbin/pidof $DAEMON >> /dev/null
	then
	    $successmsg "AppFirst collector is already running" "afcollector"
	    exit 0
	fi

	export LD_LIBRARY_PATH=/usr/share/appfirst
	$DAEMON
	export LD_LIBRARY_PATH=""
	;;
  collector_stop)
	killproc $DAEMON -10
	;;
  status)
        $status collector
	RETVAL=$?
	;;
  *)
	$failmsg "Usage: /etc/init.d/afcollector {start|stop}"
	exit 1
	;;
esac

exit $RETVAL
