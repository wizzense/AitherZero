ADACLScan is a PowerShell script to view and manage Active Directory
permissions and audit settings.  

https://github.com/canix1/ADACLScanner


ADACLScan has the following features:

View HTML reports of DACLs/SACLs and save it to disk.
Export DACLs/SACLs on Active Directory objects in a CSV format.
Connect and browse you default domain, schema , configuration or a naming context defined by distinguishedname.
Browse naming context by clicking you way around, either by OU�s or all types of objects.
Report only explicitly assigned DACLs/SACLs.
Report on OUs , OUs and Container Objects or all object types.
Filter DACLs/SACLs for a specific access type.. Where does �Deny� permission exists?
Filter DACLs/SACLs for a specific identity. Where does "Domain\Client Admins" have explicit access? Or use wildcards like "jdoe".
Filter DACLs/SACLs for permission on specific object. Where are permissions set on computer objects?
Skip default permissions (defaultSecurityDescriptor) in report. Makes it easier to find custom permissions.
Report owner of object.
Compare previous results with the current configuration and see the differences by color scheme (Green=matching permissions, Yellow= new permissions, Red= missing permissions).
Report when permissions were modified
Can use AD replication metadata when comparing.
Can convert a previously created CSV file to a HTML report.
Effective rights, select a security principal and match it agains the permissions in AD.
Color coded permissions based on criticality when using effective rights scan.
List you domains and select one from the list.
Get the size of the security descriptor (bytes).
Rerporting on disabled inheritance .
Get all inherited permissions in report.
HTLM reports contain headers.
Summary of criticality for all report types.
Refresh Nodes by right-click container object.
Exclude of objects from report by matching string to distinguishedName
You can take a CSV file from one domain and use it for another. With replacing the old DN with the current domains you can resuse reports between domains. You can also replace the (Short domain name)Netbios name security principals.
Reporting on modified default security descriptors in Schema.
Verifying the format of the CSV files used in convert and compare functions.
When compairing with CSV file Nodes missing in AD will be reported as "Node does not exist in AD"
The progress bar can be disabled to gain speed in creating reports.
If the fist node in the CSV file used for compairing can't be connected the scan will stop.
System requirements
Powershell 2.0 or above
PowerShell using a single-threaded apartment
Somefunctions requires Microsoft .NET Framework version 4.0