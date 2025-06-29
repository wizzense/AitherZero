Incognito is a free tool for viewing and editing logon credentials (SATs).

Run from with CMD.EXE running as Local System.

To launch CMD.EXE as Local System with Process Hacker:
  Open Process Hacker with administrative privileges.
  Hacker menu > Run As:
     Program: cmd.exe
     User name: NT AUTHORITY\SYSTEM
     Type: Service
     Session ID: 1
     Desktop: WinSta0\Default


Then run this command:

    .\incognito.exe list_tokens -u



