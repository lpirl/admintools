The three tiny helpers support you in maintaining common configuration
files for all vservers.

The directory `fsroot` contains all the files that will be copied to all
vservers.

Add a file using `./add.sh /path/to/my/.config` and the copy it to all
vservers using `./apply.sh`.

To delete a file from `fsroot`, you have to… delete it.
