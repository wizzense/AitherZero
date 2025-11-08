In special cases, such as troubleshooting specific issues with assistance from Tanium Support, you might use the command-line interface (CLI) on Tanium Core Platform Servers to configure platform settings.

Typically, you change platform settings through Tanium Console or the TanOS menu. For more information, see Tanium Console User Guide: Managing Tanium Core Platform settings and Manage Tanium Core Platform settings on Tanium Appliances.

For details about the TanOS CLI, which is separate from the Tanium Core Platform CLI, see Reference: TanOS command line interface.
Contact Tanium Support for guidance before you create, edit, or delete platform settings.

You must be granted read-write shell access before using this CLI. See Request read-write restricted shell or full shell access.
The following table lists the locations where the CLI programs reside. For descriptions of the settings that you can edit, see Deployment-related settings reference.

CLI executables on Tanium Appliances
Component	CLI program location
Tanium Server	/opt/Tanium/TaniumServer/TaniumServer
Tanium Module Server	/opt/Tanium/TaniumModuleServer/TaniumModuleServer
Tanium Zone Server	/opt/Tanium/TaniumZoneServer/ZoneServer
TDownloader: Tanium Server	/opt/Tanium/TaniumServer/TaniumTDownloader
TDownloader: Module Server	/opt/Tanium/TaniumModuleServer/TaniumTDownloader
CLI examples
The following examples show how to use the CLI.

Display help
cmd-prompt>./TaniumServer --help
Usage: TaniumServer [options] <command> [<args>]

General Options:
  -h [ --help ]         Print this help message
  -v [ --version ]      Print the version
  --verbose             Verbose output

Service Options:
  -i                    Install the service
  -u                    Uninstall the service
  -s                    Start the service
  -e                    Stop the service

Internal Tanium Options - DO NOT USE:
  -d                    Run without daemonizing

Commands:
  config                Manage configuration
  clean-downloads       Clean the downloads catalog
  database              Manages a database
  global-settings       Manages global settings
  license               Manages Deployment License
  pki                   Manages PKI
  registration-secret   Manages Client registration secrets
  server-registrations  Manages Server registration requests
  test-hsm              Test an HSM configuration
  trust-module-certs    Add trusted Module Server certificates

For help on a specific command run `TaniumServer COMMAND -h`
Display config help
cmd-prompt>./TaniumServer config --help
Usage: TaniumServer config <action> [<key>] [<value>]

Actions:
  config list                         List all keys and non-protected values
  config list-protected               List all keys and values
  config get <key>                    Print non-protected config value
  config get-protected <key>          Print config value
  config set <key> <value>            Set config value and try to guess type
  config set-string <key> <value>     Set string value
  config set-protected <key> <value>  Set protected string value
  config set-number <key> <value>     Set numeric value (in decimal or hex notation)
  config remove <key>                 Remove config value
Example: List configuration settings
When displaying the current settings, note that the CLI output displays (protected) instead of the actual value for settings that are designated as protected, which means they are sensitive in the security sense.

cmd-prompt>./TaniumServer config list
Keys:
  - AddressMask: 16777215
  - ConsoleSettingsJSON: C:\Program Files\Tanium\Tanium Server\http\config\console.json
  - DBUserDomain: tam.local
  - DBUserName: taniumsvc
  - LogPath: C:\Program Files\Tanium\Tanium Server\Logs
  - LogVerbosityLevel: 1
  - Logs:
    - Logs.MiniDumpMessages:
      - Logs.MiniDumpMessages.FilterRegex: .*Begin MiniDumper.*
      - Logs.MiniDumpMessages.LogVerbosityLevel: 1
  - ModuleServer: tms1.tam.local,TMS1.tam.local:17477
  - ModuleServerPort: 17477
  - PGDLLPath: C:\Program Files\Tanium\Tanium Server\postgres\bin
  - PKIDatabasePassword: (protected)
  - PGRoot: C:\Program Files\Tanium\Tanium Server\postgres
  - Path: C:\Program Files\Tanium\Tanium Server
  - ProxyPassword: (protected)
  - ProxyPort: 
  - ProxyServer: 
  - ProxyType: NONE
  - ProxyUserid: 
  - SQLConnectionString: postgres:localhost@dbname=postgres port=5432
  - ServerName: 0.0.0.0
  - ServerPort: 17472
  - ServerSOAPPort: 443
  - TrustedCertPath: C:\Program Files\Tanium\Tanium Server\Certs\installedcacert.crt
  - TrustedModuleServerCertsPath: C:\Program Files\Tanium\Tanium Server\trusted-module-servers.crt
  - Version: 7.7.3.8207
Example: Set configuration values
cmd-prompt>./TaniumServer config set BypassProxyHostList host1.example.com,192.168.0.1
cmd-prompt>./TaniumServer config get BypassProxyHostList
host1.example.com,192.168.0.1
Example: Set configuration values
cmd-prompt>./TaniumTDownloader config set ProxyServer 192.168.0.2
cmd-prompt>./TaniumTDownloader config get ProxyServer
192.168.0.2
Example: Configure global settings
cmd-prompt>./TaniumServer global-settings -h
Usage: TaniumServer global-settings list|list-all|get|set|set-string|set-numbe
r|set-flags|unset-flags|remove

  -c [ --command ] arg  Command to run:
                            list
                            list-all
                            get <setting>
                            set <setting> <value>
                            set-string <setting> <value>
                            set-number <setting> <value>
                            set-flags <setting> [public|hidden|read-only|server...]
                            unset-flags <setting> [public|hidden|read-only|server ...]
                            remove <setting>

cmd-prompt>./TaniumServer global-settings set ReportingTLSMode 0
Example: Add an administrator user
cmd-prompt>./TaniumServerdatabase -h
Usage: TaniumServer database create|upgrade|create-admin-user

  -c [ --command ] arg  Command to run:
                            create
                            upgrade
                            create-admin-user [username] [domain]
			     sqlserver2postgre outputfile

cmd-prompt>./TaniumServer database create-admin-user admin-recover tam.local