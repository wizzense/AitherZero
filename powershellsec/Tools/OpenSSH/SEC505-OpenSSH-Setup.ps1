# Jason, finish writing this before attendees find it!
# Doh! TOO LATE!
# Exit, because this is not a script to be run as-is yet:
exit

# Create $env:ProgramFiles\OpenSSH folder:
if (-not (Test-Path -Path $env:ProgramFiles\OpenSSH))
{ mkdir $env:ProgramFiles\OpenSSH } 

# Confirm we are still in C:\Tools\OpenSSH\:
cd C:\SANS\Tools\OpenSSH\

# Copy OpenSSH binaries to the new ProgramFiles folder:
# Jason, use copy instead, and del existin files:
robocopy.exe .\OpenSSH-Win64 "$env:ProgramFiles\OpenSSH" /MIR 

# Move into $env:ProgramFiles\OpenSSH folder:
cd $env:ProgramFiles\OpenSSH

# Run OpenSSH server install script:
.\install-sshd.ps1

# Create inbound firewall rule for TCP/22:
New-NetFirewallRule -Name OpenSSH-Server -DisplayName 'OpenSSH-Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 

# Start the OpenSSH (sshd) service:
Start-Service -Name sshd

# Start the OpenSSH Agent (ssh-agent) service:
Start-Service -Name ssh-agent

# Configure OpenSSH (sshd) service to start automatically:
Set-Service -Name sshd -StartupType Automatic 

# Configure OpenSSH Agent (ssh-agent) service to start automatically:
Set-Service -Name ssh-agent -StartupType Automatic 

# See the config files and keys for the OpenSSH service:
dir $env:ProgramData\ssh 

# See your SSH configuration as a user:
dir $env:USERPROFILE\.ssh

# Set PowerShell.exe as the default shell instead of CMD.EXE:
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force 
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShellCommandOption -Value "-Command" -PropertyType String -Force

# Set CMD.EXE as the default shell:
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\system32\cmd.exe" -PropertyType String -Force 
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShellCommandOption -Value "/c" -PropertyType String -Force


# Connect as a client to self:
# MUST BE IN POWERSHELL.EXE or PWSH.EXE (not ISE).
# Jason, create "ssh" function to wrap binary...


# Uninstall and Clean:
<#
# Get current folder:
$thisfolder = $PWD

# Delete server keys and config data:
del $env:ProgramData\ssh\*
del $env:ProgramData\ssh

# Move into ProgramFiles folder:
cd $env:ProgramFiles\OpenSSH

# Run uninstall script:
.\uninstall-sshd.ps1

# Delete service binaries:
cd $thisfolder
del $env:ProgramFiles\OpenSSH\*
del $env:ProgramFiles\OpenSSH

# Remove firewall rule:
Remove-NetFirewallRule -Name OpenSSH-Server

# What about cleaning client settings?
#>
