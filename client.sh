client_dir=$1 # path/to/batches
server_dir=$2 # user@host:path/to/batches
identity=$3 # ssh identity file needed to scp to server

copy () {
    if [ $identity ]; then
        scp -i $identity -v $*
    elif [[ $server_dir == *":"* ]]; then
        scp -v $*
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
        rm -rf $client_batch/.batchy
        mkdir -p $client_batch/.batchy

        echo "Uploading Batch \"$batch_name\""
        # Remove OUTPUT folder from the CLIENT BATCH.
        # TODO(usergenic): rotate any existing output folder to output.2 etc
        rm -rf $client_batch/output
        # Add an UPLOAD file to the CLIENT BATCH.
        echo $server_batch > $client_batch/.batchy/upload
        date >> $client_batch/.batchy/upload
        # Remove READY file from CLIENT BATCH.
        rm -rf $client_batch/ready
        # Copy the CLIENT BATCH folder to SERVER BATCH.
        cp -r $client_batch/. $server_batch
        # Add an EXECUTE file to the CLIENT BATCH.
        date > $client_batch/.batchy/execute
        # COPY the EXECUTE file to the SERVER BATCH (triggers execution).
        copy $client_batch/.batchy/execute $server_batch/.batchy/execute
        # Add a WAIT file to the CLIENT BATCH.
        date > $client_batch/.batchy/wait
    done

    # Download __pickup batches
    for wait in `ls -1 $client_dir/*/.batchy/wait 2> /dev/null`
    do
        # A CLIENT BATCH is found containing a WAIT file.
        client_batch=$(dirname `dirname $wait`)
        batch_name=`basename $client_batch`
        server_batch=`head -1 $client_batch/.batchy/upload`
        # Check the SERVER BATCH for a PICKUP file.
        # If there is no PICKUP file, try again later.
        copy $server_batch/.batchy/pickup $client_batch/.batchy/pickup 2> /dev/null
        if [[ $(copy $server_batch/.batchy/pickup $client_batch/.batchy/pickup 2> /dev/null) ]]; then
            echo "Downloading Batch \"$batch_name\""
            # Add a DOWNLOAD file to the CLIENT BATCH.
            echo $server_batch > $client_batch/.batchy/download
            date >> $client_batch/.batchy/download
            # Remove the WAIT file from the CLIENT BATCH.
            rm $client_batch/.batchy/wait
            # COPY the OUTPUT from the SERVER BATCH to the CLIENT BATCH.
            copy -r $server_batch/output $client_batch/
            # Add a DELIVERED file to the CLIENT BATCH.
            date > $client_batch/.batchy/delivered
            # COPY the DELIVERED file to the SERVER BATCH.
            copy $client_batch/.batchy/delivered $server_batch/.batchy/delivered
        fi
    done
    sleep 5
done
