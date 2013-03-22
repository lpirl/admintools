@echo off

REM BEGIN headline
echo Lukas Pirl 2008
echo.
echo #################
echo #               #
echo # Backup script #
echo #               #
echo #################
echo.
echo.
REM END headline

REM BEGIN vars
echo.
echo ### setting variable...
echo.

SETLOCAL ENABLEEXTENSIONS
echo Extensions: on

SETLOCAL ENABLEDELAYEDEXPANSION
echo Delayed expansion: on

set backups_to_keep=5
echo Maximum number of backups: %backups_to_keep%

set path_uri_file=paths.txt
echo File containing paths to backup: %path_uri_file%

set date_cur=%date:~-4%%date:~-7,2%%date:~-10,2%
echo Date: %date_cur%

rem options: yes/no
set poweroff=no
echo Shutdown when backup complete: %poweroff%

rem options: yes/no
set autoclose=no
echo Close window when backup complete: %autoclose%

echo.
echo ### done!
echo.
REM END vars

REM BEGIN deleting
echo.
echo ### deleting old backups and unknown directories...
echo.
rem backups newer than today and other directorys
for /f %%1 in ('dir /a:d /b') do if %%1 GEQ %date_cur% echo deleting %%1 & rd /s /q %%1
set /a count_bkps=0
rem delete more than %backups_to_keep%
for /f %%2 in ('dir /a:d /b /o:-n') do set /A count_bkps+=1 & if !count_bkps! GEQ %backups_to_keep% echo deleting !count_bkps!: %%2 & rd /s /q %%2
echo.
echo ### done!
echo.
REM END deleting

REM BEGIN copy URIs out of URI-file to backuptarget
echo.
echo ### Copying files...
echo.
for /f "tokens=*" %%3 in (%path_uri_file%) do xcopy "%%3" "%cd%\%date_cur%\%%~n3" /e /v /i /f /h /k /y
echo.
echo ### done
echo.

echo #####################
echo # Backup completed! #
echo #####################

rem BEGIN conditioned shutdown
if "%poweroff%" == "yes" (
shutdown /S /t 00
echo ### Shutting down...
)
rem END conditioned shutdown

if "%autoclose%" == "yes" exit

echo.
echo To close this window
pause
exit
