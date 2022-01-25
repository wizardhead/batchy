server_dir=$1 # path/to/batches
remove_after=$2 # seconds after which to remove a delivered batch

have_seconds_elapsed () {
    local since=$1
    local limit=$2

    if python3 -c "from datetime import datetime; since = datetime.strptime(\"$since\", \"%a %b %d %H:%M:%S %Z %y\"); datediff = datetime.now() - since; seconds_elapsed = datediff.total_seconds(); exit(0 if seconds_elapsed > $2 else 1);"; then
        return 0
    else
        return 1
    fi
}

while true;
do
    # Execute batches
    for execute in `ls -1 $server_dir/*/_batch/execute 2> /dev/null`
    do
        # A SERVER BATCH is found containing an EXECUTE file.
        batch=$(dirname `dirname $execute`)
        batch_name=`basename $batch`
        echo "Executing $batch"
        # Remove EXECUTE file from SERVER BATCH.
        rm $batch/_batch/execute
        # Add a clean OUTPUT folder to the SERVER BATCH.
        # TODO(usergenic): rotate any existing output folder to output.2 etc
        rm -rf $batch/output 2> /dev/null
        mkdir -p $batch/output
        # Run the COMMAND file and record its stdout to a LOG file in its OUTPUT folder.
        echo Execution Start: $(date) >> $batch/output/log
        cat $batch/command.sh >> $batch/output/log
        (cd $batch && time bash command.sh) 2>&1 | tee -a $batch/output/log
        echo Execution Finish: $(date) >> $batch/output/log
        # Add a PICKUP file to the SERVER BATCH.
        date > $batch/_batch/pickup
    done

    # As a safety measure, only when remove_after is set should we remove
    # delivered batches.
    if [ -n "$remove_after" ]; then
        for delivered in `ls -1 $server_dir/*/_batch/delivered 2> /dev/null`
        do
            # A SERVER BATCH is found containing a DELIVERED file.
            batch=$(dirname `dirname $delivered`)
            delivered_at=`head -1 $batch/_batch/delivered`
            if have_seconds_elapsed "$delivered_at" $remove_after; then
                echo "Removing $batch"
                # Remove SERVER BATCH.
                rm -rf $batch
            fi
        done
    fi
    # Clean up delivered batches
    sleep 5
done