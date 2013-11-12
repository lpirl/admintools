Please save and execute the script in the directory you want the backups to be stored in.
	i.e. `C:\automatic_backups\backup.bat`

!!! IN A SEPARATE DIRECTORY !!!

The paths to the files or directories you want to backup must be listed in `paths.txt`

* 1 path per line
* script does not necessarily throw an error if a path is incorrect
* example file: `C:\photos\me_at_beach.jpg`
* example directory: `C:\photos\marriage`

All directories in the backup directory that are not recognized as a backup will be **deleted permanently** without request!

All directories above the maximum backup number will be deleted permanently.

To change the maximum numbers of backups to be kept:

1. right click on`backup.bat`
2. edit
3. enter your desired number X in the line
	* `set backups_to_keep=X`
4. save and quit

The script will copy all files and their attributes (that are readable, or course).
