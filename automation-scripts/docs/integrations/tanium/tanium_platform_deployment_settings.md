Reference: Deployment-related Tanium Core Platform settings in an Appliance deployment
Last UpdatedAug 01, 202513 minute read
On PremUser GuidesServerApplianceAdministration
2025H1 PDF
2024H2 PDF
2024H1 PDF
PDF archive
While you configure the most critical Tanium Core Platform Server settings during initial installation, you can configure additional deployment-related settings afterward.

This section lists many of the deployment-related settings that you might need to change for your environment.

You can change most Tanium Core Platform Server settings through Tanium Console. For steps, see Tanium Console User Guide: Managing Tanium Core Platform settings.

For a reference of all Tanium Core Platform settings Tanium Console User Guide: Reference: Tanium Core Platform settings.

To configure Tanium Client settings, see Tanium Client Management User Guide: Tanium Client CLI and Client settings.

Contact Tanium Support for help configuring settings for your deployment.

Configure settings in TanOS
You can change most settings through Tanium Console (see Tanium Console User Guide: Managing Tanium Core Platform settings), but if the Console is unavailable, you can use the following steps to configure these settings.

Sign in to the TanOS console as a user with the tanadmin role.
Enter 2-2 (Tanium Operations > Configuration Settings).

Enter the line number for the Tanium Core Platform Server on which to modify settings.
Use the menu to view and edit settings. Enter the line number for a setting to edit that setting, or enter A to add a new setting.
Deployment-related settings reference
Platform settings used during deployment
Settings	Platform components	Guidelines
AddressMask	Tanium Server (local)	Enter the hexadecimal value of a subnet CIDR that defines the boundaries of a Tanium linear chain of IPv4 Tanium Clients. Contact Tanium Support for guidance before configuring this setting. For details about the setting, see .
AddressPrefixIPv6	Tanium Server (local)	
Enter a decimal number from 0 to 128 to represent the IPv6 prefix that defines the boundaries of a linear chain of IPv6 Tanium Clients. By default, this setting is hidden and has a value of 0, which specifies no peering. Contact Tanium Support to determine the optimum value for peering in IPv6 networks. Do not add or change the setting without direction from Support. See .

AllowedHubs	
Tanium Server (local)

Zone Server

Configure this setting based on the server type.

Tanium Server: Specify the Zone Server Hub that is allowed to connect to the Tanium Server. This setting has the value 127.0.0.1 because the Zone Server Hub is collocated on the Tanium Server in an Appliance deployment.

Zone Server: Enter a comma-separated list of IP addresses of Zone Server Hubs that are authorized to communicate with the Zone Server.
Tanium Server: Enter a comma-separated list of Zone Server Hubs that are authorized to communicate with the Tanium Server. Specify the hubs by FQDN or IP address. You must enter IPv6 addresses within square brackets (for example, [2001:db8::1]). Note that you can configure exceptions to the AllowedHubs list in the Tanium Console User Guide: AllowedLocalHubs setting.

Zone Server: Enter a comma-separated list of Zone Server Hubs that are authorized to communicate with the Zone Server. Specify the hubs by FQDN or IP address. You must enter IPv6 addresses within square brackets (for example, [2001:db8::1]).

If the Zone Server Hub resides on a different host than the Tanium Server, see .

BypassCRLCheckHostList	
Tanium Server

Module Server

TDownloader

List the servers that the Tanium Server or Module Server can trust without checking a certificate revocation list (CRL). The Tanium Server and Module Server perform a CRL check on all servers that are not in this list, and do not download files from a server that fails the check. Specify the servers by FQDN or IP address. You must enter IPv6 addresses within square brackets (for example, [2001:db8::1]).

Configure this setting in the TDownloader configuration on the Tanium Server and Module Server.

Configure this setting in the Tanium Server and Module Server configurations.

If you configure the Tanium Server and Module Server to access Internet sites through a proxy server, you can configure BypassCRLCheckHostList through Tanium Appliance. See Tanium Console User Guide: Configuring proxy server settings.

BypassProxyHostList	
Tanium Server

Module Server

TDownloader

If you configure the Tanium Core Platform to access Internet sites through a proxy server, enter a comma-separated list of FQDNs or IP addresses for the hosts that do not go through the proxy server. You do not have to enter 127.0.0.1, localhost, or the Module Server, but enter active-active Tanium Servers if necessary. You must enter IPv6 addresses within square brackets (for example, [2001:db8::1]). Specify literal values. All supported Tanium Core Platform versions allow wildcards.

Configure this setting in the TDownloader configuration on the Tanium Server and Module Server.

Configure this setting in the Tanium Server and Module Server configurations.

See Tanium Console User Guide: Configuring proxy server settings.

content_base_url	Tanium Server	Do not edit this setting, which is automatically set to https://fqdn/content for air-gapped environments when you import air gap content (where fqdn is the fully qualified domain name of the Appliance on which you are installing the update).
DefaultHeaders	Tanium Server	
The HTTP headers returned when a browser accesses Tanium Console.

You can use this setting to enable HTTP Strict Transport Security (HSTS). See . Otherwise, do not change this setting unless Tanium Support instructs you to do so.

Do not enable HSTS if you have not installed a CA-issued certificate. Doing so disables access to Tanium Console.

EnforceAllowedHubs	
Tanium Server (local)

Zone Server

Configure this setting to enable (1) or disable (0) enforcement of the Tanium Console User Guide: AllowedHubs setting.

EnforceAllowedHubs is a Zone Server setting. The default value is 1 and you must not change it.

EnforceAllowedHubs is a setting on the Tanium Server and Zone Server. If the Zone Server Hub resides on a different host than the Tanium Server, the best practice is to set the value to the default 1 on both Servers.

Tanium Server: The value 1 specifies that only hubs listed in AllowedHubs can communicate with the Tanium Server. The value 0 specifies that any hub can communicate with the Tanium Server regardless of the AllowedHubs setting.

Zone Server: The value 1 specifies that only hubs listed in AllowedHubs can communicate with the Zone Server. The value 0 specifies that any hub can communicate with the Zone Server regardless of the AllowedHubs setting.
See .

ForceIPV6	
Tanium Server

Module Server

TDownloader

In deployments where traffic between Tanium Core Platform Servers and the Internet traverses a proxy server, TDownloader resolves the proxy address as an IPv4 address by default. If the proxy server has an IPv6 address, add ForceIPV6 with a value of 1. ForceIPV6 is a TDownloader setting on the Tanium Server and Module Server in both Appliance and Windows deployments. The setting is hidden by default and its default value is 0. Contact Tanium Support for guidance before adding this setting (see Contact Tanium Support). For more information about proxy server settings, see Configuring proxy server settings.

HubPriorityList	Zone Server	
Add this setting on the Zone Server to specify the FQDN or IP address of the preferred Zone Server Hub for sending Tanium Client content (such as sensor definitions, configuration information, and action package files) to the Zone Server. As long as that hub is available, the Zone Server does not receive content from any other hub. If the preferred hub goes down, the Zone Server fails over to receiving content from any other available hub. Typically you use this setting for active-active deployments that have pairs of Zone Servers and hubs, where each hub connects to each Zone Server.

In active-active deployments, add HubPriorityList to ensure that each Zone Server receives content from its closest hub. Configuring this setting also optimizes hub usage by ensuring that each hub serves one Zone Server instead of one hub servicing both Servers.

is_airgap	Tanium Server	Do not edit this setting, which indicates an air-gapped environment and is set automatically when you first import air gap content.
LogPath	
Tanium Server

Module Server

Zone Server

The location for Tanium Server logs. The default is /opt/Tanium/TaniumServer/Logs.
LogVerbosityLevel	
Tanium Server (local)

Module Server

Zone Server

TDownloader

Specify the logging level as a decimal value on the Tanium Client, Tanium Server, Module Server, or Zone Server. On the Tanium Server and Module Server, you can configure the logging level separately for TDownloader. For best practices and configuration, see Logging levels.

By default, this setting is not present on Tanium Clients unless you set the logging level when deploying Clients.

If you deploy an action to configure this setting on Tanium Clients, use the Set Windows Tanium Client Logging Level or Set Tanium Client Logging Level [Non-Windows] package.

On Tanium Clients that run on virtual desktop infrastructure (VDI) endpoints or endpoints with limited resources, disable logging to reduce disk writes. Temporarily re-enable logging on individual endpoints for troubleshooting.

ModuleServer	Tanium Server (local)	This setting specifies the IP address or FQDN of the Module Server. It is set automatically when the Module Server registers with the Tanium Server during installation. Contact Tanium Support before editing this setting (see Contact Tanium Support).
ModuleServerPort	Tanium Server (local)	This setting specifies the Module Server port (default 17477) for traffic from the Tanium Server. The port is set automatically when the Module Server registers with the Tanium Server during installation. Contact Tanium Support before editing this setting (see Contact Tanium Support).
PKIDatabasePassword	Tanium Server (local)	Specify a password to encrypt the root keys that the Tanium Server stores in the pki.db file. See Tanium Console User Guide: Encrypt the root keys databaseTanium Console User Guide: Encrypt the root keys database.
ProxyPassword	
Tanium Server

Module Server

TDownloader

For a proxy server that requires authentication, enter the password of the Tanium Console User Guide: ProxyUserid user that establishes a connection with the proxy server.

Configure this setting in the TDownloader configuration on the Tanium Server and Module Server.

Configure this setting in the Tanium Server and Module Server configurations.

See Tanium Console User Guide: Configuring proxy server settings.

ProxyPort	
Tanium Server

Module Server

TDownloader

Specify the proxy server listening port.

Configure this setting in the TDownloader configuration on the Tanium Server and Module Server.

Configure this setting in the Tanium Server and Module Server configurations.

See Tanium Console User Guide: Configuring proxy server settings.

ProxyServer	
Tanium Server

Module Server

TDownloader

Specify the IP address of the proxy server.

Configure this setting in the TDownloader configuration on the Tanium Server and Module Server.

Configure this setting in the Tanium Server and Module Server configurations.

See Tanium Console User Guide: Configuring proxy server settings.

By default, the proxy server address is resolved as an IPv4 address. If the proxy server has an IPv6 address, you must enter it within brackets (for example, [2001:db8::1]) and configure the TDownloader setting Tanium Console User Guide: ForceIPV6 to 1.

ProxyType	
Tanium Server

Module Server

TDownloader

Specify the type of proxy server authentication.

Configure this setting in the TDownloader configuration on the Tanium Server and Module Server. The possible values are Basic, NTLM, or None.

Configure this setting in the Tanium Server and Module Server configurations. The possible values are Basic or NTLM.

See Tanium Console User Guide: Configuring proxy server settings.

ProxyUserid	
Tanium Server

Module Server

TDownloader

For a proxy server that requires authentication, specify the user ID of the account that establishes a connection with the proxy server.

ProxyUserid is a TDownloader setting on the Tanium Server and Module Server.

ProxyUserid is a Tanium Server and Module Server setting.

See Tanium Console User Guide: Configuring proxy server settings.

ReportingTLSCertPath	
Tanium Server

Zone Server

Setting for inbound connections. Path to the TLS certificate that was created upon installation. This certificate is used in TLS connections initiated by the Tanium Client, the Tanium Zone Server Hub, or the Tanium Zone Server.
ReportingTLSKeyPath	
Tanium Server

Zone Server

Setting for inbound connections. Path to the private key file used in TLS connections. This setting must be present to enable TLS.
ReportingTLSMode	
Tanium Server

Zone Server

Set the mode for TLS connections from the Tanium Client to the Tanium Server or Zone Server:

0 (TLS not used): TLS is disabled. This is the default value.
1 (TLS required): If a TLS handshake fails, the Tanium Client cannot register or communicate with the Tanium Server or Zone Server.
2 (TLS optional): The Tanium Client tries to connect over TLS. If the TLS connection fails, the Tanium Client tries a non-TLS connection.
If you will use TLS, initially setting the value to 2 is a best practice. After you confirm that Tanium Clients establish TLS connections reliably, setting the value to 1 will enforce the best security.

See See Securing Tanium Server, Zone Server, and Tanium Client access.

RequireIncomingEncryption	
Tanium Server

Zone Server

Setting for inbound connections. Implicitly set to 0 by default. To set a different value, you must add the setting.
0 (TLS not required)
1 (TLS required)
Important: When RequireIncomingEncryption is set to 1, only TLS connection requests are processed, so only Tanium Clients that have TLS enabled are able to register and be managed. Do not set this to 1 until you are sure all Tanium Clients that have been deployed are configured to use TLS (ReportingTLSMode=1 or ReportingTLSMode=2), and you are ready to deploy Tanium Client to new endpoints with TLS configured prior to initial registration.

ServerName	
Tanium Server

Module Server

On the Tanium Server or Module Server, specify the network adapter binding that the Server uses to listen for IPv4 Client registrations. By default, this setting is hidden and has a value of 0.0.0.0, which specifies binding to all network adapters. Contact Tanium Support for guidance before changing this setting (see Contact Tanium Support).

Do not specify a value for this setting on the Zone Server, where the setting is deprecated.

On the Tanium Client, specify the FQDN or IP address of the Tanium Server or Zone Server with which the Client tries to connect. For more information, see .

If you are manually configuring this setting, specify an FQDN.

If you deploy an action to configure this setting on the Tanium Client, use the Set Tanium Server Name or Set Tanium Server Name [Non-Windows] package.

ServerNameIPv6	
Tanium Server

Module Server

By default, this setting is hidden and has a value of [::], which specifies that the Server binds to all network adapters to listen for IPv6 Client registrations. To bind to a specific network adapter, add the setting and enter the IPv6 address of the adapter within square brackets (for example, [2001:db8::1]). Contact Tanium Support for guidance before adding this setting (see Contact Tanium Support).

ServerPort	
Tanium Server (local)

Module Server

Zone Server

On Tanium Core Platform Servers, the ServerPort is set during Server installation. Update this setting if necessary according to the Tanium infrastructure and Server:

For the steps to update the port, see Manage Tanium Core Platform settings. You can update the following ports:

Tanium Server: Specify the port on which the Server listens for Tanium Clients. The default is 17472. Do not change ServerPort in the TaniumServer.ini configuration file.
Module Server: Specify the port for traffic from the Tanium Server. The default is 17477.
Zone Server Hub: Specify the inbound port for traffic from the Tanium Server and Zone Server. The default is 17472.
Tanium Server: This is the port on which the Server listens for Tanium Clients. The default is 17472. You configure ServerPort when completing the Tanium Server installation wizard. See .
Module Server: Specify the port for traffic from the Tanium Server. The default is 17477. You configure ServerPort when completing the Module Server installation wizard. See .
Zone Server Hub: Specify the inbound port for traffic from the Tanium Server and Zone Server. The default is 17472. You configure ServerPort when completing the hub installation wizard. See .
For information about port settings on the Zone Server, see Reference: Deployment-related Tanium Core Platform settings in an Appliance deployment and Reference: Deployment-related Tanium Core Platform settings in an Appliance deployment.

On the Tanium Client, the ServerPort is set during Client installation. It specifies the port to use for communication between Clients and between Clients and Tanium Core Platform Servers. The default is 17472. If you need to update the port, see .

If you configure the Reference: Deployment-related Tanium Core Platform settings in an Appliance deployment or Reference: Deployment-related Tanium Core Platform settings in an Appliance deployment setting, it overrides ServerPort for client-client communication. See .

ServerSOAPPort	Tanium Server (local)	
Specify the port for Tanium Appliance and the SOAP API.

The default is 8443. Port 443 redirects to this 8443.

The default is 443. You specify the port when completing the Tanium Server installation wizard. See .

SQLConnectionString	Tanium Server (local)	
Specify connection information for the Tanium database server, such as in the following examples:

postgres:<server IP address>@user=postgres dbname=tanium sslmode=require sslcert=/opt/Tanium/.postgresql/postgresql.crt sslkey=/opt/Tanium/.postgresql/postgresql.key sslcompression=1

MSSQL: SQL1\SQLEXPRESS@tanium
PostgreSQL: postgres:<server IP address>@user=postgres dbname=tanium sslmode=require sslcert=/Program Files/Tanium/.postgresql/postgresql.crt sslkey=/Program Files/Tanium/.postgresql/postgresql.key sslcompression=1
See the PostgreSQL documentation for the supported PostgreSQL keywords, such as dbname, port, and user.

If you change this setting, you must restart the Tanium Server:
See Start, stop, and restart Tanium services.

See Manage Windows services for core platform Servers.

SSLCipherSuite	Tanium Server (local)	
Specify the cipher suites to use for TLS connections to the Tanium Server from the Module Server, Tanium Clients, or the systems of Tanium Appliance users. The default is ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK. See Supported cipher suites.

SSLHonorCipherOrder	Tanium Server (local)	
When the Tanium Server and Tanium Client determine a mutual set of supported ciphers, the Client normally selects which cipher to use. However, if you set SSLHonorCipherOrder to 1, the Server selects a mutually supported cipher based on the SSLCipherSuite setting. The Server applies an order of preference from left to right when selecting from the ciphers that SSLCipherSuite lists. See Supported cipher suites.

TrustedCertPath	
Tanium Server

TDownloader

Path to the certificate file used for secure connections to the Tanium Console port.
TrustedHostList	
Tanium Server (local)

Module Server

TDownloader

By default, the Tanium Server and Module Server validate the SSL/TLS certificate of remote servers when establishing connections to them (such as for downloading files). To bypass certificate validation for specific servers, enter their FQDN or IP address. You do not have to enter 127.0.0.1, localhost, the Tanium Module Server, or Tanium Servers (standalone or active-active). Wildcards are supported. You must enter IPv6 addresses within square brackets (for example, [2001:db8::1]).

TrustedHostList is a TDownloader setting on the Tanium Server and Module Server.

TrustedHostList is a Tanium Server and Module Server setting.

See Tanium Console User Guide: Configuring proxy server settings.

Version	
Tanium Server (local)

Module Server

Zone Server

Zone Server Hub

Do not edit this setting, which indicates the Server or Client version.
ZoneHubFlag	
Zone Server

Zone Server Hub

On the host where you install an instance of the Zone Server or Zone Server Hub, this setting indicates whether the current instance is (1) or is not (0) a hub.
View the setting through the TanOS console. See Manage Tanium Core Platform settings.

View the setting through the CLI. See .