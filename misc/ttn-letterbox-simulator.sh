#/bin/bash
#
# Letterbox simulator to test server application
#
# (P) & (C) 2019-2021 Peter Bieringer <pb@bieringer.de>
#
# License: GPLv3
#
# 2019xxxx/pbiering: initial version
# 20210627/pbiering: add support for options, major extension

program=$(basename $0)
version="0.0.2"

counter_file="./$(basename $0 .sh).counter"

hw_serial="0000000000000000"

help() {
	cat <<END
$program -U <url> -H <auth-header> -D <device-id> [-S <serial>] [-C <counter-file>] [-d] [-r]

 Mandatory
  -U <url>             URL to post simulation data, e.g. https://my.iot.domain.example/cgi-bin/ttn-letterbox-test.cgi
  -H <auth-header>     authentication header, e.g. "X-TTN-AUTH: MySeCrEt"
  -D <device-id>       device ID
  -B <box-status>      box status to submit (full|empty|filled|emptied)

 Optional:
  -C <counter-file>    fetch/store counter value of sensors (default: $counter_file.<device-id>)
  -S <serial>          hardware serial (default: $hw_serial)
  -d                   debug
  -r                   real-run (otherwise only print what will be done)
END
}

while getopts "C:A:U:D:B:rdh?" opt; do
	case $opt in
	    C)
		counter_file="$OPTARG"
		;;
	    A)
		auth_header="$OPTARG"
		;;
	    U)
		url="$OPTARG"
		;;
	    D)
		device_id="$OPTARG"
		;;
	    S)
		hw_serial="$OPTARG"
		;;
	    B)
		box_status="$OPTARG"
		;;
	    d)
		debug=1
		;;
	    r)
		real_run=1
		;;
	    ?|h)
		help
		exit 1
		;;
	    *)
		echo "ERROR : invalid option: -$OPTARG" >&2
		exit 1
		;;
	esac
done

shift $[ OPTIND - 1 ]

## failsafe checks
if [ -z "$url" ]; then
	echo "ERROR : mandatory URL is missing (-U ...)" >&2
	exit 1
fi

if [ -z "$auth_header" ]; then
	echo "ERROR : mandatory authentication header is missing (-A ...)" >&2
	exit 1
fi

if [ -z "$device_id" ]; then
	echo "ERROR : mandatory device-id is missing (-D ...)" >&2
	exit 1
fi

if [ -z "$box_status" ]; then
	echo "ERROR : mandatory box-status is missing (-B ...)" >&2
	exit 1
fi


# generate final counter file name
counter_file="$counter_file.$device_id"

if [ ! -e "$counter_file" ]; then
	echo "NOTICE: default/provided counter file is not existing: $counter_file (create now)" >&2
	touch $counter_file
fi

if [ ! -f "$counter_file" ]; then
	echo "ERROR : default/provided counter file is not a real file: $counter_file" >&2
	exit 1
fi

if [ ! -r "$counter_file" ]; then
	echo "ERROR : default/provided counter file is not readable: $counter_file" >&2
	exit 1
fi

if [ ! -w "$counter_file" ]; then
	echo "ERROR : default/provided counter file is not writable: $counter_file" >&2
	exit 1
fi


## read counter
counter=$(cat $counter_file)
if [ -z "$counter" ]; then
	counter=0
fi

[ "$debug" = "1" ] && echo "DEBUG : counter fetched from file ($counter_file): $counter"

counter=$[ $counter + 1 ]
if [ "$real_run" = "1" ]; then
	[ "$debug" = "1" ] && echo "DEBUG : counter stored to file ($counter_file): $counter"
	echo -n "$counter" >$counter_file
	if [ $? -ne 0 ]; then
		echo "ERROR : can't update counter file: $counter_file" >&2
		exit 1
	fi
else
	echo "NOTICE: real-run (-r) not seleced, don't update counter file: $counter_file" >&2
fi

case $box_status in
    full|filled)
	sensor=500
	;;
    empty|emptied)
	sensor=25
	;;
esac

echo "NOTICE: box_status=$box_status sensor=$sensor counter=$counter" >&2

# default data (TODO: make optional if required)
timestamp=$(date -u "+%s")
datetime=$(date -u "+%FT%T.%NZ")

temp="244"
tempC="19"
threshold="30"
voltage="3.242"

gtw_id="eui-b827ebff00000000" # dummy
frequency="868.3"
channel="1"
rssi="-27"
snr="8.5"
rf_chain="1"
latitude="0.0000"
longitude="0.0000"
altitude="0"
downlink_url="https://integrations.thethingsnetwork.org/ttn-eu/api/v2/down/my-letterbox-sensor/my-letterbox-sensor?key=TEST"

user_agent="$program/$version"

print_request() {
	# TODO: calculate "payload_raw" according to provided values
	cat <<END
{"app_id":"$device_id","dev_id":"$device_id","hardware_serial":"$hw_serial","port":1,"counter":$counter,"payload_raw":"/6oMgQIe9A==","payload_fields":{"box":"$box_status","sensor":$sensor,"temp":$temp,"tempC":$tempC,"threshold":$threshold,"voltage":$voltage},"metadata":{"time":"$datetime","frequency":$frequency,"modulation":"LORA","data_rate":"SF7BW125","coding_rate":"4/5","gateways":[{"gtw_id":"$gtw_id","timestamp":$timestamp,"time":"$datetime","channel":$channel,"rssi":$rssi,"snr":$snr,"rf_chain":$rf_chain,"latitude":$latitude,"longitude":$longitude,"altitude":$altitude}]},"downlink_url":"$downlink_url"}
END
}

if [ "$real_run" = "1" ]; then
	print_request | curl -A "$user_agent" -H "$auth_header" --data @- $url
	rc=$?

	if [ $rc -ne 0 ]; then
		echo "ERROR : call not successful (rc=$rc)"
	else
		echo "INFO  : call successful"
	fi
else 
	echo "NOTICE: dry-run mode active by default (missing: -r)" >&2
	echo "INFO  : URL to call: $url"
	echo "INFO  : AuthHeader : $auth_header"
	echo "INFO  : UserAgent  : $user_agent"
	echo "INFO  : Request BEGIN"
	print_request
	echo "INFO  : Request END"
fi
