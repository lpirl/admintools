This script backs up specified directories (one per line in `dirs.txt`) from a specified
drive (`source_drive`) to a backup site (`target`).

* Directories are backed up in parallel
* Common useless files (from a backup point of view) will be excluded
* Run as admin
* for automation: schedule execution with Windows Task Scheduler
