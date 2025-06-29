@echo OFF
REM **********************************************
REM *** Don't run this script from the CD-ROM. ***
REM *** Copy it to your hard drive first, and  ***
REM *** put SHA1DEEP.EXE into the same folder  ***
REM *** or into the %PATH% beforehand.         ***
REM ***                                        ***
REM *** Get SHA1DEEP.EXE for free from:        ***
REM ***      http://md5deep.sourceforge.net    ***
REM **********************************************

cls
echo.
echo   This script demonstrates the use of SHA1DEEP.EXE to take a 
echo   "SHA-1 snapshot" of the %SystemRoot%\System32\InetSrv folder. 
echo   SHA1DEEP.EXE is a free tool from http://md5deep.sourceforge.net 
echo.
echo.  
pause


sha1deep.exe -s %SystemRoot%\System32\InetSrv\* > snapshot.txt 
cls
echo.
echo.
echo   An SHA-1 snapshot was taken of the folder by running:
echo     "sha1deep.exe -s %SystemRoot%\System32\InetSrv\* > snapshot.txt"
echo.
echo   Take a look at the snapshot file in Notepad, then close Notepad.
notepad snapshot.txt 


cls
echo.
echo   Now add a file to the InetSrv folder, press any key
echo   to continue, and the script will show the new file.
echo   The -X switch does the comparison, the -s switch
echo   suppresses status messages about directories...
echo.
pause
echo.
echo.


echo sha1deep.exe -s -X snapshot.txt %SystemRoot%\System32\InetSrv\*
echo.
sha1deep.exe -s -X snapshot.txt %SystemRoot%\System32\InetSrv\*

echo.
echo   Now change a file in the InetSrv folder, press any key
echo   to continue, and the script will show the edited file
echo   as well as the newly added file.
echo.
pause
echo.
echo.


echo sha1deep.exe -s -X snapshot.txt %SystemRoot%\System32\InetSrv\*
echo.
sha1deep.exe -s -X snapshot.txt %SystemRoot%\System32\InetSrv\*


sha1deep.exe -s %SystemRoot%\System32\InetSrv\* > snapshot.txt 
echo.
echo.
echo   A new snapshot file was just made of the folder, overwriting the
echo   prior one you saw in Notepad.  The new snapshot includes your new
echo   file.  Now delete that new file you added, press any key to 
echo   continue, and the script will show the missing file (see -n switch).
echo.
pause
echo.
echo.

echo sha1deep.exe -s -n -X snapshot.txt %SystemRoot%\System32\InetSrv\*
echo.
sha1deep.exe -s -n -X snapshot.txt %SystemRoot%\System32\InetSrv\*

echo.
echo.
pause
del snapshot.txt
cls
echo sha1deep.exe -h
echo.
sha1deep.exe -h
echo.
echo.
echo.
echo   ******************************************************************
echo   Now try it yourself by making a snapshot of your entire C: drive
echo   using the -r switch of the tool to recursively follow all folders,
echo   e.g., "sha1deep.exe -r c:\ > drive.txt".  This can take quite a
echo   while, so feel free to stop it with Ctrl-C at any time and then
echo   look at the drive.txt file.
echo   ******************************************************************
echo.
echo.

