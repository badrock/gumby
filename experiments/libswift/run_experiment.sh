#!/bin/bash -xe

# Set defaults for config variables ---------------------------------------------------
# Override these on Jenkins before running the script.
[ -z $EXPERIMENT_TIME ] && EXPERIMENT_TIME=30
[ -z $FILE_SIZE ] && FILE_SIZE="10MB"
[ -z $NO_OF_LEECHERS ] && NO_OF_LEECHERS="1"
# ------------------------------------------------------------------------------

function cleanup {
  echo "Cleaning up"
	sudo /usr/bin/lxc-stop -n seeder

	# umount the union filesystem
	if mount | grep $CONTAINER_DIR; then
		sudo /bin/umount $CONTAINER_DIR -l
	fi
	if mount | grep /tmp/container; then
		sudo /bin/umount /tmp/container	-l
	fi
	rmdir $CONTAINER_DIR
}
trap cleanup EXIT
trap cleanup TERM

EXPERIMENT_DIR=$( dirname $(readlink -f "$0"))
if [ ! -d "$EXPERIMENT_DIR" ]; then
    EXPERIMENT_DIR=$( dirname $(readlink -f $(which "$0")))
fi
if [ ! -d "$EXPERIMENT_DIR" ]; then
    echo "Couldn't figure out where the experiment is, bailing out."
    exit 1
fi

# check if netem config is set correctly
# heterogeneous delay?
if [[ $NETEM_DELAY == *,* ]]
then
	# split in array
	DELAY=(`echo $NETEM_DELAY | tr ',' ' '`)
	if [[ ${#DELAY[@]} != $NO_OF_LEECHERS ]]
	then
		echo "No of delay settings should be equal to 1 or the number of leechers"
		exit 65
	fi
	HETEROGENEOUS_DELAY=true
else
	DELAY=$NETEM_DELAY
	HETEROGENEOUS_DELAY=false
fi

if [[ $NETEM_PACKET_LOSS == *,* ]]
then
	# split in array
	PACKET_LOSS=(`echo $NETEM_PACKET_LOSS | tr ',' ' '`)
	if [[ ${#PACKET_LOSS[@]} != $NO_OF_LEECHERS ]]
	then
		echo "No of packet loss settings should be equal to 1 or the number of leechers"
		exit 65
	fi
	HETEROGENEOUS_PACKET_LOSS=true
else
	PACKET_LOSS=$NETEM_PACKET_LOSS
	HETEROGENEOUS_PACKET_LOSS=false
fi

if [[ $NETEM_RATE == *,* ]]
then
	# split in array
	RATE=(`echo $NETEM_RATE | tr ',' ' '`)
	if [[ ${#RATE[@]} != $NO_OF_LEECHERS ]]
	then
		echo "No of rate limit settings should be equal to 1 or the number of leechers"
		exit 65
	fi
	HETEROGENEOUS_RATE=true
else
	RATE=$NETEM_RATE
	HETEROGENEOUS_RATE=false
fi

if [[ $LEECHER_OFFSET == *,* ]]
then
	# split in array
	OFFSET=(`echo $LEECHER_OFFSET | tr ',' ' '`)
	if [[ ${#OFFSET[@]} != $NO_OF_LEECHERS ]]
	then
		echo "No of offset settings should be equal to 1 or the number of leechers"
		exit 65
	fi
	HETEROGENEOUS_OFFSET=true
else
	OFFSET=$LEECHER_OFFSET
	HETEROGENEOUS_OFFSET=false
fi

# get full path, easier for use in container
WORKSPACE_DIR=$(readlink -f $WORKSPACE_DIR)
FILENAME=file_$FILE_SIZE.tmp


echo "Running swift processes for $EXPERIMENT_TIME seconds"
echo "Workspace: $WORKSPACE_DIR"
echo "Output dir: $OUTPUT_DIR"

# wait for the hash to be generated - note that this happens in the container fs
while [ ! -f $CONTAINER_DIR/$OUTPUT_DIR/$FILENAME.mbinmap ] ;
do
      sleep 2
done

HASH=$(cat $CONTAINER_DIR/$OUTPUT_DIR/$FILENAME.mbinmap | grep hash | cut -d " " -f 3)

for element in "${DELAY[@]}"
do
    echo "$element"
done

for (( i = 0 ; i < $NO_OF_LEECHERS; i++ ))
do
	# read delay and packet loss
	if $HETEROGENEOUS_DELAY;
	then
		LEECHER_DELAY=${DELAY[$i]}
	else
		LEECHER_DELAY=$DELAY
	fi

	if $HETEROGENEOUS_PACKET_LOSS;
	then
		LEECHER_PACKET_LOSS=${PACKET_LOSS[$i]}
	else
		LEECHER_PACKET_LOSS=$PACKET_LOSS
	fi

	if $HETEROGENEOUS_RATE;
	then
		LEECHER_RATE=${RATE[$i]}
	else
		LEECHER_RATE=$RATE
	fi

	if $HETEROGENEOUS_OFFSET;
	then
		sleep ${OFFSET[$i]}
	else
		sleep $OFFSET
	fi

	LEECHER_IP=$NETWORK_IP_RANGE.$(($LEECHER_ID+$i))
	sudo /usr/bin/lxc-execute -n leecher_$i \
		-s lxc.network.type=veth \
		-s lxc.network.flags=up \
		-s lxc.network.link=$BRIDGE_NAME \
		-s lxc.network.ipv4=$LEECHER_IP/24 \
		-s lxc.rootfs=$CONTAINER_DIR \
		-s lxc.pts=1024 \
		-- $WORKSPACE_DIR/$LEECHER_CMD $WORKSPACE_DIR/$REPOSITORY_DIR $OUTPUT_DIR $HASH $LEECHER_DELAY $LEECHER_PACKET_LOSS $WORKSPACE_DIR/$PROCESS_GUARD_CMD $EXPERIMENT_TIME $BRIDGE_IP $SEEDER_IP $SEEDER_PORT $OUTPUT_DIR $(($LEECHER_ID+$i)) $USER $LEECHER_RATE &
done


wait


# ------------- LOG PARSING -------------

# copy logs back from containers
#cp -R $CONTAINER_DIR/$OUTPUT_DIR/src $OUTPUT_DIR
#cp -R $CONTAINER_DIR/$OUTPUT_DIR/dst $OUTPUT_DIR

# TODO: parsing very broken at the moment
# TODO: tmp preprocess because process_guard.py in gumby now adds a first line to the resource_usage.log files
if $GENERATE_PLOTS; then


	tail -n +2 $LOGS_DIR/src/resource_usage.log > $LOGS_DIR/src/resource_usage.log.tmp
	# remove the (sh) process
	sed '/(sh)/d' $LOGS_DIR/src/resource_usage.log.tmp > $LOGS_DIR/src/resource_usage.log
	tail -n +2 $LOGS_DIR/dst/resource_usage.log > $LOGS_DIR/dst/resource_usage.log.tmp
	sed '/(sh)/d' $LOGS_DIR/dst/resource_usage.log.tmp > $LOGS_DIR/dst/resource_usage.log

	$WORKSPACE_DIR/gumby/experiments/libswift/parse_logs.py $LOGS_DIR/src
	$WORKSPACE_DIR/gumby/experiments/libswift/parse_logs.py $LOGS_DIR/dst

	# ------------- PLOTTING -------------
	gnuplot -e "logdir='$LOGS_DIR/src';peername='src';plotsdir='$PLOTS_DIR'" $WORKSPACE_DIR/gumby/experiments/libswift/resource_usage.gnuplot
	gnuplot -e "logdir='$LOGS_DIR/dst';peername='dst';plotsdir='$PLOTS_DIR'" $WORKSPACE_DIR/gumby/experiments/libswift/resource_usage.gnuplot

	gnuplot -e "logdir='$LOGS_DIR';plotsdir='$PLOTS_DIR'" $WORKSPACE_DIR/gumby/experiments/libswift/speed.gnuplot

	rm -f $PLOTS_DIR_LAST/*
	cp $PLOTS_DIR/* $PLOTS_DIR_LAST/
fi

# remove leeched files
for (( i = 0 ; i < $NO_OF_LEECHERS; i++ ))
do
	LEECHER_ID_TMP=$(($LEECHER_ID+$i))
	rm -f $OUTPUT_DIR/dst/$LEECHER_ID_TMP/$HASH*
done





