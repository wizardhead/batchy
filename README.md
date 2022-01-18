# batchy

A little pair of utilities that uploads files and runs command on a server then downloads results.  Makes it easy to do batch processing without manual steps.

# How to run:

Run `server.sh` on your server:
```
$ ./server.sh path/to/server/workspace
```

Run `client.sh` on your client:
```
$ ./client.sh path/to/client/workspace user@host:path/to/server/workspace
```

Now create subfolders in your `path/to/client/workspace` locally that obey the following rules:

1. A file called `command.sh` will contain the command to run.
2. Add any other files you need to perform the work.
3. Touch a file called `ready`.
4. The client script will pick up the batch and send it off to the server.
5. The server will process the results and the client will download the `output` folder.

