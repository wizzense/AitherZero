PowerShell Core is the open source, cross-platform version 
of PowerShell.  Download the latest version from: 

      https://github.com/powershell

PowerShell Core can be installed and run side-by-side with
the built-in Windows PowerShell.  Installing PowerShell Core
will not replace or modify Windows PowerShell.

PowerShell Core is launched as pwsh.exe on Windows.

To opt out of sending telemetry, set the POWERSHELL_TELEMETRY_OPTOUT
environment variable to "1", preferably before pwsh is first run.

PowerShell Core is released under the MIT License.





######## PowerShell Core Paths On Windows ###################

By default the package is installed to $env:ProgramFiles\PowerShell\<version>

You can launch PowerShell via the Start Menu or like this with version 6.*:

      Start-Process -FilePath $env:ProgramFiles\PowerShell\6\pwsh.exe 




######## PowerShell Core Paths On Linux #####################

$PSHOME is /opt/microsoft/powershell/6.1.0/

User profiles will be read from ~/.config/powershell/profile.ps1

Default profiles will be read from $PSHOME/profile.ps1

User modules will be read from ~/.local/share/powershell/Modules

Shared modules will be read from /usr/local/share/powershell/Modules

Default modules will be read from $PSHOME/Modules

PSReadline history will be recorded to ~/.local/share/powershell/PSReadLine/ConsoleHost_history.txt

The profiles respect PowerShell's per-host configuration, so the default host-specific profiles exists at Microsoft.PowerShell_profile.ps1 in the same locations.
