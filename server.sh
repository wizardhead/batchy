server_dir=$1 # path/to/batches

while true;
do
    # Execute batches
    for execute in `ls -1 $server_dir/*/.batchy/execute 2> /dev/null`
    do
        # A SERVER BATCH is found containing an EXECUTE file.
        batch=$(dirname `dirname $execute`)
        batch_name=`basename $batch`
        echo "Executing $batch"
        # Remove EXECUTE file from SERVER BATCH.
        rm $batch/.batchy/execute
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
        date > $batch/.batchy/pickup
    done

    # Clean up delivered batches
    for delivered in `ls -1 $server_dir/*/.batchy/delivered 2> /dev/null`
    do
        # A SERVER BATCH is found containing a DELIVERED file.
        batch=$(dirname `dirname $delivered`)
        echo "Removing $batch"
        # Remove the SERVER BATCH.
        rm -rf $batch
    done
    sleep 5
done