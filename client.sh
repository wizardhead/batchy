client_dir=$1 # path/to/batches
server_dir=$2 # user@host:path/to/batches
identity=$3 # ssh identity file needed to scp to server

copy () {
    if [ -n $identity ]; then
        scp -i $identity $*
    elif [[ $server_dir == *":"* ]]; then
        scp $*
    else
        cp -v $*
    fi
    return 0
}

timestamp () {
    python3 -c 'from datetime import datetime; curr_time = datetime.now(); formatted_time = curr_time.strftime("%F-%Hh%Mm%Ss-%f"); print(formatted_time)'
}

while true;
do
    # Upload "ready" batches
    for ready in `ls -1 $client_dir/*/ready 2> /dev/null`
    do
        # A CLIENT BATCH is found containing a READY file.
        client_batch=`dirname $ready`
        batch_name=`basename $client_batch`
        server_batch=$server_dir/$batch_name-`timestamp`
        
        # Remove old batchy status files if present.
        rm -rf $client_batch/_batch
        mkdir -p $client_batch/_batch

        echo "Uploading Batch \"$batch_name\""
        # Remove OUTPUT folder from the CLIENT BATCH.
        # TODO(usergenic): rotate any existing output folder to output.2 etc
        rm -rf $client_batch/output
        # Add an UPLOAD file to the CLIENT BATCH.
        echo $server_batch > $client_batch/_batch/upload
        date >> $client_batch/_batch/upload
        # Remove READY file from CLIENT BATCH.
        rm -rf $client_batch/ready
        # Copy the CLIENT BATCH folder to SERVER BATCH.
        copy -r $client_batch $server_batch
        # Add an EXECUTE file to the CLIENT BATCH.
        date > $client_batch/_batch/execute
        # COPY the EXECUTE file to the SERVER BATCH (triggers execution).
        copy $client_batch/_batch/execute $server_batch/_batch/execute
        # Add a WAIT file to the CLIENT BATCH.
        date > $client_batch/_batch/wait
    done

    # Download __pickup batches
    for wait in `ls -1 $client_dir/*/_batch/wait 2> /dev/null`
    do
        # A CLIENT BATCH is found containing a WAIT file.
        client_batch=$(dirname `dirname $wait`)
        batch_name=`basename $client_batch`
        server_batch=`head -1 $client_batch/_batch/upload`
        # Check the SERVER BATCH for a PICKUP file.
        # If there is no PICKUP file, try again later.
        copy $server_batch/_batch/pickup $client_batch/_batch/pickup 2> /dev/null
        if [[ `copy $server_batch/_batch/pickup $client_batch/_batch/pickup 2> /dev/null && ls $client_batch/_batch/pickup 2> /dev/null` ]]; then
            echo "Downloading Batch \"$batch_name\""
            # Add a DOWNLOAD file to the CLIENT BATCH.
            echo $server_batch > $client_batch/_batch/download
            date >> $client_batch/_batch/download
            # Remove the WAIT file from the CLIENT BATCH.
            rm $client_batch/_batch/wait
            # COPY the OUTPUT from the SERVER BATCH to the CLIENT BATCH.
            copy -r $server_batch/output $client_batch/
            # Add a DELIVERED file to the CLIENT BATCH.
            date > $client_batch/_batch/delivered
            # COPY the DELIVERED file to the SERVER BATCH.
            copy $client_batch/_batch/delivered $server_batch/_batch/delivered
        fi
    done
    sleep 5
done
