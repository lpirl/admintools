@ECHO off

rem This script intends to delete stuck print jobs.
rem
rem It does so by stopping the printer service, deleting the
rem print queue and finally starting the printer service again.

rem https://stackoverflow.com/a/11995662
echo|set /p="Checking for administrative permissions... "
net session >nul 2>&1
if %errorLevel% == 0 (
    echo ok
) else (
    echo
    echo Failure: Please start this script as Administrator.
    pause
    exit
)

net stop spooler

setlocal
cd /d "%windir%\System32\spool\PRINTERS"
if %errorLevel% == 0 (
    echo|set /p="Deleting print jobs... "
    del /Q *.*
    if %errorLevel% == 0 (
        echo ok
    ) else (
        echo failed
    )
) else (
    echo Failure: Could not cd into spool directory.
)
endlocal

net start spooler

echo All done.
pause
