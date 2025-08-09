Tanium Appliances contain a command line interface (CLI) that you can access from SSH.

Requirements
To access all CLI commands, you must access the CLI as a user with the tanadmin role. Some CLI commands are available to users with the tanuser role, as noted in Tanium platform commands.

Configure an SSH key to authenticate the user account you use to run CLI commands. If you have not configured an SSH key, you are prompted for a password each time you run a command.

Syntax
ssh -q[t] <user>@<ip-or-fqdn> <command> [action/options] ...
Always include the ssh -q option for Appliance CLI commands to suppress unnecessary messages.

You must include the ssh -t option with interactive commands that prompt for information. This option is not necessary for commands that run silently or only return information.

Tanium platform commands
Command	Description
add hub	Install the Tanium Zone Server Hub add-on to an existing Tanium Server role.
configure cap <action>	
Configure the Tanium Cloud Access Point role.

This command has the following options:

show - Show the current Cloud Access Point configuration.

set <host1> <host2> <listen_port_client> - Configure the host names from the Tanium Cloud Client edge URLs (host1 and host2) and the port that you want Tanium Clients to use to communicate with the Cloud Access Point (listen_port_client).

Usage example:

ssh -q user@appliance configure cap set sample-zsb1 sample-zsb2 443

configure ipsec <action>

Configure IPsec communication with a peer Appliance in an Array. Both Appliances must have the same Tanium role of either Tanium Server or Tanium Module Server.

This command has the following actions:

show - Show the current IPsec configuration

set <serial> - Enable IPsec with the Appliance with the specified serial number

test - Test the IPsec connection

disable - Clear the IPsec configuration and preserve the key

reset - Reset the IPsec configuration and generate a new key

After you perform an IPsec reset, run refresh array on an Array Manager Appliance to distribute the updated IPsec key to the other Appliances in the Array.

configure tms sync <action>

Configure the Tanium Module Server synchronization feature, which copies content from an active Tanium Module Server to a standby Tanium Module Server. To use this feature, you must:

Install two Tanium Module Servers.

Add both Tanium Module Servers to the Array.

For more information about Tanium Module Server synchronization, see Schedule sync jobs.

This command has the following actions:

status - Shows the current Tanium Module Server synchronization status

source - Specifies the source, or active, Tanium Module Server from which data is copied

target - Specifies the target, or standby, Tanium Module Server to which data is copied

disable - Disables synchronization between the two Tanium Module Servers

dec proxy

Install, upgrade or remove the Direct Connect (DEC) Zone Proxy.

Available options:

list: List the available DEC proxy versions.
install <version>: Install the selected version of DEC proxy.
remove: Uninstall the DEC proxy.
show <item>: Show the current DEC proxy status (version or apipayload).
show instructions: Show instructions for how to configure a DEC proxy.
help	Show a list of available commands. Add help to any command to show help for that particular command.
install aio [version]	
Install the specified version of the Tanium All-in-One role. Run the command without a version to display the available versions found on the Appliance.

Usage example:

ssh -q user@appliance install aio 7.7.3.8207

Use Tanium Appliances configured with the All-in-One role only for evaluation purposes. Tanium does not support All-in-One deployments in production environments. Do not allow a Tanium Appliance that is configured with the All-in-One role to accept inbound connections from the internet.

install cap	Install the Tanium Cloud Access Point role.
install tms [version]	
Install the specified version of the Tanium Module Server role. Run the command without a version to display the available versions found on the Appliance.

Usage example:

ssh -q user@appliance install tms 7.7.3.8207

install ts [version]	
Install the specified version of the Tanium Server role. Run the command without a version to display the available versions found on the Appliance.

Usage example:

ssh -q user@appliance install ts 7.7.3.8207
install tzs [version]	
Install the specified version of the Tanium Zone Server role. Run the command without a version to display the available versions found on the Appliance.

Usage example:

ssh -q user@appliance install tzs 7.7.3.8207
Make sure to import the public key to the Zone Server Appliance before you run this command (TanOS menu 2-I).The public keys are stored in the tanium-init.dat file. For detailed steps, see Import the Tanium Server public key file to the Zone Server.

manage ldaps <action>	
Manage the LDAPS or StartTLS CA certificates used by the Tanium Server.

This command has the following actions:

list - List the installed certificates

add - Add a certificate or certificates. Provide the certificate contents on stdin.

remove <SHA256> - Remove the certificate with the specified SHA256 fingerprint.

print <SHA256> - Display details for the certificate with the specified SHA256 fingerprint.

enable - Enable the LDAPS configuration.

disable - Disable the LDAPS configuration.

alwaysvalidate - Enable certificate validation.

nevervalidate - Disable certificate validation.

syncpeer - Synchronize LDAPS settings and certificates to the peer Tanium Server in the cluster.

copypeer <SHA256> - Copy the certificate with the specified SHA256 fingerprint to the peer Tanium Server in the cluster.

status - Display the LDAPS configuration status.

promote tms <user> <serial>

Promote a secondary Tanium Module Server to become the active Module Server in the Array, where user is the user name of a Tanium Console user with the Admin role and serial is the serial number of the Module Server to promote. You must supply the password of the Tanium Console user on stdin.

Run this command from an Array Manager Appliance.
This command performs the following actions:

Stops the Tanium Module Server synchronization target from receiving data from the active Module Server

Updates all Tanium Servers in the Array to use the specified Tanium Module Server as the active remote Module Server

Registers the selected Tanium Module Server with all Tanium Servers in the Array

Usage example:

ssh -q user@appliance promote tms MyAdminConsoleUser 8ca9c7bae2e8ec27-5484b887017201d5 <<< 'mypassword123'

remove hub	Remove the Tanium Zone Server Hub add-on.
set manifest url <type> <value>	Set the URL of a Tanium manifest. For type, specify main or labs. For value, specify the URL for the corresponding manifest.
show fingerprint <ts|tzs|hub|soap>	
Show the Tanium fingerprint for the Tanium Server (ts), the Tanium Server SOAP certificate (soap), Tanium Zone Server (tzs), or Tanium Zone Server hub (hub).

Usage example:

ssh -q user@appliance show fingerprint ts

show manifest urls [json]	Show the URLs for the main and labs Tanium manifests. By default, the URLs are returned in plain text. Use the json option to return the URLs in JSON format.
sync tms

Copy the contents of the active Tanium Module Server to the standby Tanium Module Server. Run this command in interactive mode using the -t option for ssh to ensure proper cleanup after canceling. You can send this command to the Array Manager or the active Module Server.

Usage example

ssh -qt user@appliance sync tms

upgrade tanium [version]	
Upgrade the Tanium software on the Appliance to the specified version. Run the command without a version to display the available versions found on the Appliance.

ssh -q user@appliance upgrade tanium 7.7.3.8207

Appliance Array commands
Command	Description
add array member <ip_address>	
Add another Appliance with the specified IP address to the Appliance Array that is defined on the current Appliance.

When you run this command, it might include interactive prompts to trust the new Array member and to enter the password for the new Array member. If you are using this command in a script, you can avoid these prompts as follows:

To avoid a prompt that asks whether to trust the new Array member and continue connecting, you can use the following command to register the fingerprint of the new Array member before you use the add array member command to add it:

ssh -qt user@new_Array_member show ssh-host-fingerprints | \ssh -qt user@Array_manager register ssh-host \new_Array_member

To avoid a password prompt when you add an Array member, you can use one of the following methods:

Copy the public key for the tanadmin user on the primary Appliance to the tanadmin user accounts on the remaining Appliances. For information on how to use TanOS menus to add a public key for a user account, see Manage SSH keys for TanOS users. For information on how to use the CLI to add a public key for a user account, see the add pubkeys command at TanOS management commands.
Configure separate public keys for the tanadmin user on each Appliance, and then use agent forwarding to authenticate with the added Array members by including the -A SSH option in the command.

ssh -qtA user@appliance add array member <ip_address>

Agent forwarding requires an SSH agent (such as ssh-agent in OpenSSH) to be running on your local host. For more information, see the documentation for your SSH client.

array assign roles <action>	
Use a JSON document to assign the desired roles to Array members and perform necessary setup steps.

This command has the following actions:

show - Provides a template for the JSON configuration file on stdout.

Usage example:

ssh -q user@appliance array assign roles show > config.json

dryrun - Using a JSON configuration file supplied on stdin, display the actions.

Usage example:

ssh -q user@appliance array assign roles dryrun < config.json

apply - Using a JSON configuration file supplied on stdin, apply the requested changes.

Usage example:

ssh -q user@appliance array assign roles apply < config.json

In the JSON configuration file template you retrieve from the Array assign roles show command, you must configure the following settings:

password_b64: The base64-encoded password for the Tanium Console admin user that is specified for the tanium_username setting.

You can use one of the following commands to base64-encode the password:

Windows: powershell "[convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(\"password\"))"

Non-Windows: printf 'password' | base64

role: The role to assign for each Array member, using one of the following numeric settings:

1: All-in-One
2: Tanium Server
3: Tanium Module Server
4: Tanium Zone Server
array create health-check	Generate a new health check report on each Array member. Any previous reports are deleted. After running this command, the results of the latest report are stored in the health.log file in the /outgoing directory on each Array member.
array restart replication	Restart LDAP replication for the local authentication service to resolve internal LDAP errors.
array self test	Run a self-test on all Array members.
array sync partitions	
Create backups of the active partitions by copying their contents to the inactive partitions for each affected Appliance in the Array. This may take a while to complete. Tanium services are stopped during the backup. Appliances that do not have alternate partitions are not affected.

array upgrade appliance [--interactive] [version]	
Upgrade TanOS on all Appliances in the Array to the specified version. Run this command only on the primary Tanium Server in the Array. Run the command without a version to display the available versions found on the Appliance. Specify the upgrade version, or use the --interactive flag to select from available versions and include interactive confirmations.

Usage example:

ssh -q user@appliance array upgrade appliance 1.8.5.0215

array upgrade tanium [--interactive] [version]	
Upgrade the Tanium software on all Appliances in the Array to the specified version. Run the command without a version to display the available versions found on the Appliance.

Load all RPMs to the incoming directory on the primary Tanium Server before running this command.

Specify the upgrade version, or use the --interactive flag to select from available versions and include interactive confirmations.

Usage example:

ssh -q user@appliance array upgrade tanium 7.7.3.8207

create array <ip_address> <name of array>	Create an Appliance Array with the specified name (spaces accepted) and add the current Appliance as a member, using the specified IP address.
promote member <serial_number>	
Promote an Array member with the Tanium Server role to be an Array Manager. Specify the serial number of the Tanium Server to promote.

refresh array	Retrieve current membership from the other Appliances in the Array. This information is refreshed on all Appliances in the Array.
reset array	Remove the current Appliance from the Appliance Array.
TanOS management commands
Command	Description
create backup <backup_type> [user@SCP_host]>	Create a core or comprehensive backup bundle, and copy it to the /outgoing directory and optionally an SCP destination. For backup_type, use core or comprehensive.
create health-check	
Generate a new health check report. Any previous reports are deleted. After running this command, the results of the latest report are stored in the health.log file in the /outgoing directory.

To generate a new health check report on all Array members, use the array create health-check command.

create tsg <--list|tsg-type> [sftp-destination]	
Create a Tanium Support Gatherer (TSG) ZIP file and optionally upload it to an SFTP destination. Specify a tsg-type, typically appliance or a specific solution.

Use the --list option to display the TSG types that are available in your environment.

Optionally, specify the sftp-destination in the format sftp-user@host:destination. If you include only the user name and host, the TSG is uploaded to the SFTP server's home directory with the default generated file name. If you do not include an sftp-destination, the TSG is created in the /outgoing directory.

You can use the A option with the ssh command to use agent forwarding to authenticate with the SFTP destination. Agent forwarding requires an SSH agent (such as ssh-agent in OpenSSH) to be running on your local host. For more information, see the documentation for your SSH client. Alternatively, you can generate an SSH key pair using the TanOS console for the specified TanOS user and add the public key to the SFTP destination's authorized keys. For information, see Manage SSH keys for TanOS users.

Usage examples:

ssh -q user@appliance create tsg connect

ssh -qtA user@appliance create tsg appliance username@sftphost.example:newfilename.zip

download package <URL|token>	
Download a package from download.tanium.com to the /incoming directory. Specify either the full URL of the download or the token from the URL.

No download URL or token is necessary to download an available upgrade package for TanOS. See command download package Appliance-upgrade.

Usage examples:

ssh -q user@appliance download package https://download.tanium.com/hGAE28KOIAv0OYVtBIZk5IPv5o_iWBVeAhabcdefghi

ssh -q user@appliance download package hGAE28KOIAv0OYVtBIZk5IPv5o_iWBVeAhabcdefghi

This command includes an interactive prompt to confirm the download. You can supply yes as a here string on stdin to skip the prompt automatically. For example:

ssh -q user@appliance download package hGAE28KOIAv0OYVtBIZk5IPv5o_iWBVeAhabcdefghi <<< 'yes'

download package appliance-upgrade <version>	
Download an upgrade package for a specific version of TanOS to the /incoming directory.

Usage example:

ssh -q user@appliance download package appliance-upgrade 1.8.5

This command includes an interactive prompt to confirm the download. You can supply yes as a here string on stdin to skip the prompt automatically. For example:

ssh -q user@appliance download package appliance-upgrade 1.8.5 <<< 'yes'

export security key <key_type>	Export the RAID or GRUB key to the /outgoing directory. For key_type, specify raid or GRUB.
performance <tool> [options]	
Manage performance data collection.

The following tools are available:

perf record <duration> - Record performance data, where duration is the number of seconds to record.

Usage example:

ssh -q user@appliance performance perf record 60 -t

perf top - Monitor a performance counter in real-time. This command requires the ssh -t option. To exit, press Q.
vmstat <delay> [count] - Monitor virtual memory statistics, where delay is the number of seconds between updates, and count is the number of times to show statistics. For example, if you specify a delay of 3 and a count of 10, the command shows statistics for ten intervals of three seconds, so the total duration is 30 seconds. If you omit the count, the command returns statistics according to the delay until you press Ctrl-C.

Usage example:

ssh -qt user@appliance performance vmstat 3 10

iostat <delay> [count] - Monitor I/O statistics, where delay is the number of seconds between updates, and count is the number of times to show statistics. For example, if you specify a delay of 3 and a count of 10, the command shows statistics for ten intervals of three seconds, so the total duration is 30 seconds. If you omit the count, the command returns statistics according to the delay until you press Ctrl-C.
pidstat <delay> [count] - Monitor individual processes, where delay is the number of seconds between updates, and count is the number of times to show statistics. For example, if you specify a delay of 3 and a count of 10, the command shows statistics for ten intervals of three seconds, so the total duration is 30 seconds. If you omit the count, the command returns statistics according to the delay until you press Ctrl-C.
htop - Monitor process usage in real-time. This command requires the ssh -t option. To exit, press Q.

Usage example:

ssh -qt user@appliance performance htop

iotop - Monitor I/O usage in real-time. This command requires the ssh -t option. To exit, press Q.
Options:

-t - Limit results to Tanium-related process. This option is unavailable for the iostat and pidstat tools.
-D - Data clean-up, for when a command is interrupted.
reboot appliance	
Reboot the Appliance.

This command includes an interactive prompt to confirm the reboot. You can supply yes as a here string on stdin to skip the prompt automatically. For example:

ssh -q user@appliance reboot appliance <<< 'yes'

report info	
Report basic information for the Appliance, including the serial number, Server name, TanOS version, role, and Tanium version.

This command is available to users with the tanuser role.

reset software	
Removes all Tanium Core Platform software from the Appliance, but preserves TanOS settings such as network and system user configuration.

This command includes an interactive prompt to confirm the reset. You can supply yes as a here string on stdin to skip the prompt automatically. For example:

ssh -q user@appliance reset software <<< 'yes'

rotate security key grub	Generate a new GRUB key
security export aide	Export the last run Advanced Intrusion Detection Environment (AIDE) report to the /outgoing directory.
security initialize aide	Enable AIDE and weekly AIDE reports.
security run aide	Manually run an AIDE report.
security set <setting> <value>	
Configure advanced security settings. Available settings, with the available values for each setting, are as follows:

fips - FIPS mode
enabled
disabled
aide - AIDE reporting
enabled
disabled
selinux - Security-Enhanced Linux (SELinux) mode
enforcing
permissive
menu_timeout - The time TanOS menus wait for input before canceling user sessions
0 (timeout disabled)
Timeout value in seconds
dos_protection - Denial of Service (DoS) attack protection
enabled
disabled
Enabling FIPS mode includes an interactive prompt. You can supply yes as a here string on stdin to skip the prompt automatically. For example:

ssh -q user@appliance security set fips enabled <<< 'yes'

security show [json]	Show advanced security settings. To return settings in JSON format, specify json.
service <action>	
Control Tanium Core Platform and TanOS services

This command has the following actions:

list [service|alias] [service|alias] ... - List controllable services with the basic status for each service. Specify an alias to list a specific group of services, or specify service names to view the basic status of those services.
status <service|alias> [service|alias] ... - Display detailed status and activity for each specified service or each service indicated by a specified alias.
start <service|alias> [service|alias] ... - Start each specified service or each service indicated by a specified alias.
stop <service|alias> [service|alias] ... - Stop each specified service or each service indicated by a specified alias.
restart <service|alias> [service|alias] ... - Restart each specified service or each service indicated by a specified alias.
enable <service|alias> [service|alias] ... - Enable each specified service or each service indicated by a specified alias.
disable <service|alias> [service|alias] ... - Disable each specified service or each service indicated by a specified alias.
is-enabled <service|alias> [service|alias] ... - Display whether each specified service or each service indicated by a specified alias is enabled.
is-active <service|alias> [service|alias] ... - Display whether each specified service or each service indicated by a specified alias is active.
is-failed <service|alias> [service|alias] ... - Display whether each specified service or each service indicated by a specified alias has failed.
You can indicate multiple services using the following aliases:

all - All controllable services
all_tanium - All Tanium Core Platform services, except for database services
all_db - All database services
all_os - All TanOS services
all_ts - All Tanium Server services
all_tms - All Module Server and module services
Usage examples:

ssh -q user@appliance service list

ssh -q user@appliance service status all_tanium

ssh -q user@appliance service restart taniumserver.service

set backup key	
Set the public key to encrypt backup files. The public key must be in PEM format.

set fqdn	Set the FQDN for the Appliance. This command is available only when the Appliance does not have a role installed.
Usage example:

ssh -q user@appliance set fqdn Appliance.example.com

set nameservers	Set one or more DNS name servers for the Appliance. Any existing name servers are overwritten.
Usage example:

ssh -q user@appliance set nameservers 8.8.8.8 9.9.9.9

set ntp <server1> [server2]	
Set NTP servers for the Appliance. To configure an NTP server that requires authentication, you can specify a colon-separated value for the argument that contains the server name, key ID, key type, and key value.

Usage example:

ssh -q user@appliance set ntp ntp.secret.corp:42:SHA1:bfb7759a67daeb65410490b4d98bb9da7d1ea2ce
show nameservers	
Show the DNS name servers for the Appliance.

show ntp	
Show the NTP servers that are configured and connection information.

This command is available to users with the tanuser role.

show ssh-host-fingerprints	Show the SSH host fingerprints.
sync partitions	Create a backup of the active partition by copying its contents to the inactive partition. This may take a while to complete. Tanium services are stopped during the backup.
upgrade appliance [version]	
Upgrade TanOS to the specified version on the Appliance. Run the command without a version to display the available versions found on the Appliance.

Usage example:

ssh -q user@appliance upgrade appliance 1.8.5

TanOS user management commands
Command	Description
add pubkeys	
Add entries to the authorized_keys file for the user. The command prompts you to paste the contents of keys to add, or you can provide the key file or contents on stdin.

This command is available to users with the tanuser role.

Usage example:

ssh -q user@appliance add pubkeys < ~/.ssh/my-key.pub

You can use the ssh-copy-id command in OpenSSH to add an SSH public key from your local host to any TanOS user with the tanadmin role on the Tanium Appliance. For example:

ssh-copy-id -i public_key_file user@appliance

configure mfa <action>	
Configure authentication requirements and multifactor settings.

This command has the following actions:

show global [json] - Show the global authentication requirements and multifactor settings. Specify json to output JSON format.
enable global <auth_type> - Enable global password requirement, key requirement, or multifactor authentication. For auth_type, specify key, password, or mfa.

To make sure an admin user can still sign in through SSH after you enable multifactor authentication, you must either exempt at least one admin user or configure multifactor authentication individually for at least one admin user before you enable multifactor authentication globally.

disable global <auth_type> - Disable global password requirement, key requirement, or multifactor authentication. For auth_type, specify key, password, or mfa.

exempt user <user_name> - Exempt the specified user from global multifactor authentication requirements.
reset global - Reset global password, key, and multifactor authentication requirements to optional.
show user <user_name> - Show the account requirements and multifactor settings for the specified user.
enable user gauth <user_name> - Configure Google Authenticator multifactor authentication for a user.

You must use the -t option to run SSH in terminal mode for TanOS to display the QR code during MFA setup; otherwise, TanOS displays only the URL.

reset user <user_name> - Reset the multifactor authentication settings for the specified user.
Usage examples:

ssh -q user@appliance exempt user backup-admin

ssh -q user@appliance enable global mfa

copy pubkeys tancopy	Copy the SSH keys for the current user to the authorized_keys file for the tancopy user account.
delete pubkeys	
Remove entries from the authorized_keys file for the user. The command prompts you to paste the contents of keys to delete, or you can provide key contents on stdin.

Use the following command to list the contents of the authorized_keys file. You can copy the contents of individual keys from the provided list.

ssh -q user@appliance show pubkeys authorized_keys

This command is available to users with the tanuser role.

Usage example:

ssh -q user@appliance delete pubkeys < key-to-delete.pub

ldap-auth <action>	
Configure LDAP authentication for TanOS users.

This command has the following actions:

config list - Display the current TanOS LDAP configuration.
config get <setting> - Display the value of the specified setting.
config set <setting> <value> - Set the value of the specified setting.
config enable - Enable the TanOS LDAP configuration with the current settings.
config disable - Disable the TanOS LDAP configuration.
config validate - Validate whether the required settings are configured.

This action does not check the server connection.

config password - Set the password for the user used to sign in and query the directory. This command prompts you to enter the password, or you can provide the password on stdin.

Usage example:

ssh -q user@appliance ldap-auth config password <<< 'my_ldap_password'

Configure the user name in the bind_dn setting:

ssh -q user@appliance ldap-auth config set bind_dn <user_name>
config import - Import the TanOS LDAP configuration from the /incoming directory on the Appliance.
config export -Export the TanOS LDAP configuration from the /outgoing directory on the Appliance.
config install - Import a TanOS LDAP configuration supplied on stdin.
config reset - Reset the TanOS LDAP configuration.
cert install - Install the LDAP server root CA certificate supplied on stdin.
cert import - Import a LDAP server root CA certificate from the /incoming directory on the Appliance.
cert export -Export the LDAP server root CA certificate to the /outgoing directory on the Appliance.
verify group <groupname> - Verify that an LDAP query returns a specific group.

verify user <username> - Verify that an LDAP query returns a specific user.
status sssd - Display the status of the sssd service.
status counts -Display counts of users and groups.
status users - Display the list of visible users.
status groups - Display the list of visible groups.
status privileges - Display roles for visible users.
settings - Display the list of available settings for the TanOS LDAP configuration.
The following TanOS LDAP settings are configurable with the ldap-auth config set command:

attribute_sshkey- The LDAP attribute that contains the SSH public key for each user

base_dn - The base DN from which TanOS queries the directory

bind_dn - The user name used to sign in to and query the LDAP server in a format accepted by the server

Configure the password using the ldap-auth config password command.

debug_level - The logging level for the configured domain (0-9)

domain_name - The domain by which the system and logs refer to the LDAP configuration. This setting does not affect the connection to the LDAP server.

filter_groups - The LDAP search filter to use to limit the groups that the LDAP server returns for the query. Leave this setting blank to return all groups under the base search DN.

filter_users - The LDAP search filter to use to limit the users that the LDAP server returns for the query. Leave this setting blank to return all users under the base search DN.

ldap_enabled - Specifies whether LDAP authentication is enabled for authenticating TanOS system users (true or false)

ldap_host - The host name of the LDAP server

ldap_port - The port on which to connect to the LDAP server

ldap_referrals - Specifies whether TanOS allows the LDAP server to refer the query to other connected LDAP servers when you have multiple LDAP servers in your organization (true or false)

ldap_schema - The schema used by the LDAP server (ad, rfc2307, rfc2307bis, or ipa)

mappings_tanadmin - A pipe-delimited list of LDAP groups that are granted the tanadmin role

mappings_tanuser - A pipe-delimited list of LDAP groups that are granted the tanuser role

local-auth <action>	
Manage Tanium Console user accounts in the local authentication service when it is enabled. See Configure the local authentication service for Tanium Console users.

This command has the following actions:

local-auth add user <user_name> <first_name> <last_name> - Add a Tanium Console user account with the specified user name, first name, and last name to the local authentication service. This command prompts for the password for the new user when run interactively, or you can supply the password on stdin.
local-auth delete user <user_name> - Delete the specified Tanium Console user account from the local authentication service.
local-auth list users - List Tanium Console user accounts in the local authentication service.
local-auth set password <user_name> - Change the password for the specified Tanium Console user account in the local authentication service. This command prompts for the new password when run interactively, or you can supply the new password on stdin.

Usage example:

ssh -q user@appliance local-auth set password SomeConsoleUser <<< 'new-console-password'

local-auth unlock user <username> - Unlock a Tanium Console user account in the local authentication service.
register ssh-host <remote_host> [scan]	
Add entries to SSH known_hosts file for the current user.

You can provide fingerprints for the remote host on stdin, or you can use the scan option to automatically discover and add the fingerprints of a remote host. For example:

ssh -q user@Array_manager register ssh-host 192.168.15.115 < fingerprints.txt
ssh -q user@Array_manager register ssh-host 192.168.15.253 scan

For a higher level of security, explicitly provide the fingerprints that you have verified to belong to the remote host on stdin instead of using the scan option.

show pubkeys <key_type>	
Show the SSH public keys for the current user.

Key types:

identity - Show the identity public key file for the user (id_rsa.pub).
authorized_keys - Show entries in the authorized_keys file for the user.
set password	
Change the password for the current user. This command prompts for the new password when run interactively, or you can supply the new password on stdin.

This command is available to users with the tanuser role.

Usage example:

ssh -q user@appliance set password <<< 'my-new-password'

system-auth <action>	
Manage TanOS system users.

This command has the following actions:

list users - List all TanOS system users.
show user <user_name> - Show the details of the specified TanOS system user.
add user <user_name> <first_name> <last_name> [options] - Add a TanOS system user with the specifier user name, first name, and last name.

The following options are available:

--role - Specify tanadmin or tanuser. The default is tanadmin.

--sshkey - Add an SSH key for the user. If you specify this option, you must provide a single SSH public key on stdin.

--nopassword - Disable password authentication for the user and require an SSH key for sign-in on SSH connections.

Usage example:

ssh -q user@appliance add user NewUser John Smith --sshkey < pubkey.pub

reset ssh lockout <user_name> - Reset a specified TanOS system user who is locked out from sign-in on SSH connections.
change password <user_name> - Reset the password for another TanOS system user. The command randomly generates and displays a new password for the specified user.

If you specify the user who is currently signed in rather than another user, the command behaves the same as set password, and you can either provide a new password on the standard input stream or set a password at the interactive prompt. You cannot specify a new password for another user.

disable password access <user_name> - Disable password authentication for the specified TanOS system user and require an SSH key for sign-in on SSH connections.
enable user <user_name> - Enable the specified TanOS system user.
disable user <user_name> - Disable the specified TanOS system user.
delete user <user_name> - Delete the specified TanOS system user.
Examples
Show a list of commands
Command:

ssh -q tanadmin@10.10.10.55 help
Example response:

The following commands are available in the TanOS CLI.

Tanium Platform
 install aio: Install the All-in-One role
 install ts: Install the Tanium Server role
 install tms: Install the Tanium Module Server role
 install tzs: Install the Tanium Zone Server role
 add hub: Add a Zone Server Hub to a TS or AiO
 remove hub: Remove the Tanium Zone Server Hub
 upgrade tanium: Upgrade Tanium software
 configure module service: Configure the Tanium Server to use a Module Server
 register module service: Register the Tanium Module Server

TanOS Appliance Array
 create Array: Create a new Appliance Array
 reset Array: Reset this Appliance's Array configuration
 add Array member: Add a Member to the Array

TanOS Management
 report info: Report information about the Appliance
 reset software: Reset the software on the Appliance
 upgrade Appliance: Upgrade the Appliance
 set backup key: Set the Backup Encryption Key
 copy pubkeys tancopy: Copy the user's SSH keys to tancopy

To see more information about each command, run it with the option "help". E.g.
ssh -q user@appliance install ts help
Show help for the install aio command
Command:

ssh -q tanadmin@10.10.10.55 install aio help
Example response:

Install the All-in-One role

Installs the All-in-One role (TaniumServer and TaniumModuleServer) onto the Appliance. This option requires the password to be used for the 'tanium'
console user.

Usage:   install aio <version>
Example: ssh -q user@appliance install aio 7.7.3.8207 
Menu:    1-1
Install the Tanium Zone Server Hub add-on
Command:

ssh -q tanadmin@10.10.10.55 add hub
Example response:

staging /opt/utils/installers/TaniumZoneServer-7.7.3.8207-1.x86_64.rpm
Checking RPM signatures
Signature verification succeeded.
Installing Tanium Zone Server
Preparing packages...
TaniumZoneServer-7.7.3.8207-1.x86_64
TaniumZoneServer service installed. Complete installation by:
1. Set ServerName with '/opt/Tanium/TaniumZoneServer/TaniumZoneServer config set ServerName <name>'
2. Set any desired optional settings (ServerPort, LogVerbosityLevel, etc) by running '/opt/Tanium/TaniumZoneServer/TaniumZoneServer config set <key> <value>'
3. Copy tanium-init.dat file into /opt/Tanium/TaniumZoneServer/TaniumZoneServer
4. Enable the TaniumZoneServer with 'systemctl enable taniumzoneserver'
5. Start the TaniumZoneServer with 'systemctl start taniumzoneserver'
If you are configuring this to be a TaniumZoneServer Hub do the following:
1. '/opt/Tanium/TaniumZoneServer/TaniumZoneServer config set ZoneHubFlag 1'
2. Create a file named ZoneServerList.txt in the /opt/Tanium/TaniumZoneServer/ directory with the ip addresses/FQDNs of the ZoneServers
Tanium Zone Server Installation completed
Configuring Zone Server Hub
 Add-On Zone Server Hub install - copied public key
Tanium Zone Server Installation completed
Retrieve Appliance information
Command:

ssh -q tanadmin@10.10.10.55 report info
Example response:

Serial Number:      5c7a65fd-2b96-4732-b2a1-fd9f56b8801e
Name:               ts1
TanOS Version:      1.8.5.0215
Role:               Tanium Server
TaniumServer:       7.7.3.8207