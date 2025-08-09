Endpoint Content Authoring
Endpoint content at Tanium refers to scripts contained within Sensors and Packages that allow the Tanium Client to target and act on an endpoint. The languages native to content development in Tanium are VBS, PowerShell, WQL, Shell, Bash, ZShell, and Python. This guide will help you take your knowledge of scripting and operating systems and use it to build powerful custom capabilities in Tanium. You will learn about the different kinds of endpoint content, common design patterns and best practices, and be ready to start creating your own sensors and packages

Prerequisite Knowledge
If you are unfamiliar with the Tanium concepts of Sensors and Packages or need a refresher, please review the platform documentation.

Sensor Overview (Link)
Package Overview (Link)
Advanced Content Training
The Advanced Content Training Course is offered by Tanium to introduce users to the development of custom sensors and packages. Successful completion of this course is strongly encouraged for anyone interested in writing endpoint code and is a requirement for Tanium Cloud customers. Details about the course are found here.

Accessing the course
Partners can self-enroll in the web-based version of the course via Tanium Partner University (Login Required).
Customers can access the course through learn.tanium.com.
Tanium employees can access the course through the Tanium Learning Center app.
Enable Content Authoring for Tanium Cloud Customers
Upon successful completion of the Advanced Content course, Tanium Cloud customers need to submit a Tanium Support Case requesting "Write Sensor Privilege" be enabled on their Tanium Environment. This will grant write sensor privileges to all user accounts in the instance, not only the user who submits the request. Your request MUST:

Be from the end user from the email domain associated with Tanium Cloud instance
Include the Tanium Cloud instance console URL (i.e. foo.cloud.tanium.com)
Include the Course Certificate of Completion for the individual that passed the Content Authoring course
Use Cases
The uses for custom content are limited only by your imagination. Here are some common themes we see among customers' solutions.

Check the health of an application or service
Install an application on an endpoint
Confirm or remediate a vulnerability or exploit
Validate a vendor's reported license usage and recover unused licenses
Use a sensor if all of these are true…	Use a package if any of these are true…
You are only reading data from the endpoint	You need to make any changes to the endpoint (install an app, write to a file, write to the registry, etc.)
All things you are accessing are local to the endpoint	You need to read from a networked resource (remote file, query, etc.) [1]
You are doing something quick that completes in under a second	You are doing something that may take longer than a second
Use Distribute Over Time to avoid overloading networked resources
Existing Content
Tanium maintains hundreds of sensors and packages that are available and ready to use in your environment. They have been developed over the years by Tanium engineers to be scalable and efficient to accommodate the numerous different ways our customers use Tanium. Before you begin creating a custom sensor or package, check the inventory of Tanium-provided content to see if there isn't something already available that meets your needs.

Environment Setup and Development Practices
Create a proper development and test environment that encourages best-practice coding in your language of choice and closely mimics how Tanium will run your scripts. Many eager developers skip this critical step in favor of jumping right into the code and end up spending a lot of time debugging avoidable issues.

Please read Development Environment And Practices before you begin development.

Language Selection
Scripting language selection within Tanium is less a matter of preference and more of a performance-impact decision given the way an interpreter may be used by Tanium and the frequency in which it may be used. Content performance will only be as fast as the slowest endpoint when it comes to bulk results for the environment it is operating in. Though the first thought may be portability of the code, that portability comes at a cost realized by extensive libraries that will take longer to load and will impact total runtime. Below is an overview of the languages available and how best to determine what is right for your project.
powershell bash python vbscript

Bash: Best choice for Linux, be aware of version and using utilities that may not be present.
PowerShell: Best choice for most Windows. Be aware of the version you are targeting as Tanium does not deploy this as part of our tooling.
ZSH: Best choice for Mac.
POSIX-compliant shell: best choice for AIX, Solaris, for portability across all UNIX endpoints.
WQL: Best choice if the information can be obtained in a simple WMI Query.
Python: Use this when this is the language you are most comfortable with, need libraries for JSON/XML/DB, prototyping, only sensors that will be run infrequently due to large spin-up time. We recommend not using this if it would be easy enough to use another option given the potential cost to performance.
VBS: Best choice only for very old Windows versions. Be aware that VBScript may have been removed from an endpoint and Tanium does not deploy this as part of our tooling.
Questions to ask yourself to help refine your decision making:

What operating systems are to be used? What is the lowest version I am willing to support?
An example. If Windows 8.1 or Server 2012 R2 is the lowest OS version targeted, then a baseline of PowerShell 4 functionality should work.
Will this be something run with high frequency?
An example. This content will need to run every hour to write to a local cache for collection later by another sensor. This should be written in a native language if possible.
Do I need to work with databases or parse a structured format like JSON or XML?
An example. You need to parse JSON formatted logs for potential patterns that are deeply nested. Python may be your best option, but you will want to find a way to limit its frequency.
Will this be run on resource constrained systems?
Native Languages may be best here: VBS, Bash, ZSH, Sh
Below is a simplified flowchart for picking which language to use quickly. There may be externalities not accounted for here, so use your own judgement based on the above information to help with your choice.

languageselection

Finding Good Examples
Tanium supplies a wide variety of content, though not every item is fit for reproduction. Tanium produced content may contain builder references (example: include comments in sensors) or calls to Tanium's internal tooling (example: CX mailboxes) which either do not exist for external use or can and do change without prior notice that could hinder your project's reliability.

Below is a curated list of content fit for reference:

Sensor	Good Example Of	Languages
Is Virtual	Boolean Return	VBScript, Bash, POSIX
Is Windows	Boolean Return	
Custom Tags	Counting Question Sensor	VBScript, POSIX
Installed Applications	Counting Question Sensor	VBScript, Bash, POSIX
Service Details	Counting Question Sensor	VBScript, Python, Bash, POSIX
File Exists	Boolean Return, Parameters	VBScript, Bash, POSIX
Folder Contents	Counting Question Sensor, Parameters	VBScript, POSIX
Installed Applications	Counting Question Sensor	VBScript, POSIX
Custom Tag Exists	Boolean Return, Parameters	VBScript, POSIX
Package	Good Example Of	Language
Custom Tagging - Add Tags	User Parameters	VBScript
Custom Tagging - Add Tags (Non-Windows)	User Parameters	POSIX
Custom Tagging - Remove Tags	Sensor Sourced Parameters	VBScript
Custom Tagging - Remove Tags (Non-Windows)	Sensor Sourced Parameters	POSIX
Start Service	Sensor Sourced Parameters	VBScript
Hosts File - Add Entry	User Parameters	VBScript

Some sample sensor and package scripts are also available for download. Sensors-and-Packages-Examples.zip.

You can search for additional examples in the Tanium console by navigating to Administration > Content > Sensors and applying a filter that will list the sensors that match your conditions.

sensorsearch

Create a Sensor
The best way to preserve knowledge is to use it, and with that in mind we will now create our first sensor. This section will give you a starting template for that purpose along with guidance around best practices, risks, and how to work through common problems you may encounter while writing a sensor. Sensors are used in Tanium questions

Results
All sensor results are Strings. A sensor may return a Boolean or numeric value, but these are still strings. Sensors return their results to standard out, with one line per result. If a sensor needs to return values in multiple columns, the results can be split using delimiters.

It is important that sensor results are thoughtfully designed with a couple goals in mind

Return as few unique strings as possible If a sensor has the possibility to return more than 100 unique strings, it is said to be "stringy” or more correctly, high cardinality. This reduces overall efficiency and performance and impacts Tanium in several ways including making your sensor unsuitable for TDS or even causing hash collisions. Worst case scenario is a sensor that returns a unique value for every endpoint on the network. Try your best to avoid this. This is particularly important if you intend to use your sensor in counting questions.
Return summarized, not raw data Output control is critical for well-crafted sensors. Don’t just return the output of some command blindly to stdout. Coerce the values you need to make the data stackable, useful, and concise then return those in columns. This is more efficient, but more importantly, makes your sensor more efficient on the platform. Tanium intentionally has high bounds for allowed data collection, this is because edge cases will always exist where some rules need to be broken. However, there’s a compounding cost when many pieces of content break these rules. A thousand pounds of feathers is still a thousand pounds.
Tips: Return bucketized or Boolean values. Examples: “2023-03-23” instead of “2023-03-23 12:34:16.123” or “high” instead of “93.76”

Errors and Logging
There is no logging for sensors, only packages. Sensors also do not consistently return or handle information sent to standard error. Your script needs to gracefully handle any errors that are thrown (Try/Catch). Capture errors and produce a sanitized message to stdout to see them displayed properly in the console. Using a predictable format like "Error: Something failed" makes error results easy to identify. Tracebacks for interpreters will be sent to the console but should be captured to produce a cleaner return. From the console, ensure you are not hiding your errors in question results to find potential issues, or they will be otherwise suppressed. Go to preferences under your profile to enable this feature. This is a user specific preference so there's no concern about generating noise for other users.

showerrors

Parameters
Sensors are not limited to fixed criteria, there may be times you find it is best not to assume everything of how the sensor is used. For instance, you have a need to do a process inspection for a specific process in your environment. You could statically fix the identifying pattern in your sensor, but then you will need a new sensor for every new process desired. The answer to this is what is known as a Parameterized Sensor. This allows you to create a placeholder in your sensor that Tanium can swap for a user provided value at runtime. We can set default values as placeholders making them optional parameters or force the user to make a choice by not providing a default.

Sensor Options
Let us begin with a breakdown of the Sensor Creator and its options.

createsensor

Sensor Details:

Name: The name of your sensor. This should be as concise as possible.
Description: A summary of what this sensor should do and some guidance on what to expect as a return.
Content Set: This is where you select which Content Set to assign your content to. Something to be aware of is this:
Content Sets are used by RBAC to determine user access. A recommended path would be to create your own Content Set for custom content due to this.
Sensor Settings:

Category: This refers to how to logically group content
Result Type: The type of return to be expected. This can have some effect on how filter operators evaluate the data. Text as a default is fine, but in some cases, you may need to specify integer, IP address, etc.
Max Sensor Age: This is a time range to set for how long sensor results should be trusted before reissuing the sensor on an endpoint. This can be overridden within a question, so do not be afraid to set this value higher than the default 15 minutes. There are performance impacts here to consider. Quick question to ask, how often do the values change that I am returning, and how often will this be reissued to catch all potential clients? If the value rarely changes, but I am issuing this on an hourly basis, setting this to 24 hours would be a reasonable Max Sensor Age.
Max String Age: Every unique row for a sensor return is referred to as a string. This determines how long a string should remain in memory when the max strings limit has been reached.
Max Strings: The total number of strings to allow before making room for new return values. This works with Max String Age to determine how many strings should be stored and for how long.
sensorparameters

Add Parameter: For selecting what parameter type to add to your sensor. Available types:
Text Input: String values provided by users which can be validated by regex.
Drop Down List: List of values for a user to select.
Checkbox: Boolean value provided by user.
Numeric: Integer values.
Numeric Interval: Integer values that allow a drop-down list of snap intervals.
Date Time: Allows users to select date and time,
Date: Allows users to select date.
Time: Allows user to select time.
Date Time Range: Allows user to select two dates and times for a range
List: Allows users to provide a list of values, like text area, but returns as an array.
Text Area: Allows users to provide a large string.
Separator: Cosmetic item to create sections in your parameter options.
Common Parameter Options: We will focus on the common items that may be less obvious:
Key: This will be the name used as an anchor in your sensor code. Example: test_val requires ||test_val|| in your sensor code.
Label: What users see as the name for the value field.
Provide Help Text: Produces a small helper message at mouse over.
Provide Prompt Text: Simulated value, helpful if you want a set of CSVs etc. Best practice if you require help text, you should provide an input example.
Provide Default Value: Default value if nothing provided by the user, helpful to match Prompt Text value so users are not surprised.
Provide Max Chars: Numerical limitation to characters in the string
Validation Expressions: Regex to test for special characters or harmful patterns.
sensorscript
Scripts:

Operating System: Selecting your OS Environment and selecting "Enable sensor for X platform" opens the field for entry.
Query Type: For selecting the language type to use.
Script Input Field: For your code which is limited to 2,8,000 characters.
Sensor Best Practices: Things you SHOULD do
We will try to capture as many recommended best practices as we can as they pertain to writing code to run in Tanium. There are times where some of these rules can be broken safely, but generally it is not encouraged as the consequences may not be easily perceived but they do have a negative impact.

Avoid endpoint-unique or time-unique results. Return Boolean or Bucketized results whenever possible. Why? Put simply, data cardinality, which speaks to volume of data which will be stored at least temporarily or in some cases longer term. This is one sensor, but how many other sensors are needed to run and store data? Tanium stores all the unique result values in memory. If they all are high cardinality, then there is a real impact to performance dealing with this within Tanium and it is components like TDS (Tanium Data Service), let alone if this data is to be shipped via Connect to other 3rd party sources. Be unique with returns where necessary, but something that creates high volume due to unique returns (prime example would be time by second) should be bucketed (last hour, last day, etc.).
High/Medium/Low rather than a raw numeric result.
Return a numeric range rather than a raw numeric results, such as "less than 10GB" rather than the exact amount of free disk space.
Round times to the nearest hour or day
Pass/Fail or True/False
Create 2 versions of a sensor: "Foo" and "Foo Details". The Foo sensor should be designed for use in Counting Questions and returns a limited number of unique values and stacks records with like responses. An example, sensor Foo would only return Pass or Fail which means all systems will fall into one of these types and will count the total number of endpoints in this state. It is innteded to be asked against a large number of endpoints at once. Foo Details would be used for drilldowns on a limited number of endpoints based on the return of Foo, while giving us more granular data around whatever Foo is.
Common workflow "Get Foo Details and Computer Name from All Computers with Foo = Fail"
Validate all user input parameters. Tanium URL-encodes all parameters to help prevent unwanted code execution, but you should still never blindly execute any input parameter. This can result in Shell or SQL injection attacks.
Include a Version number in your code. Tanium does not provide sensor versioning; this is left as an exercise to the creator. Some practices that work well for this are:
Consider placing version numbers at the top for ease of review.
Use a code repository system that allows versioning and tagging.
Sensors should rarely if ever return nothing.
This ensures we are running.
The user experience of [no results] gives little certainty to success.
Helps when testing, or troubleshooting.
Using stub sensors for an unsupported OS helps minimize this as well.
"N/A on AIX" as an example of a stub output, we might use for AIX systems.
Sensors need to execute quickly. Ideally, the execution time should be less than 100ms. Anything over 1sec is considered an inefficient, slow sensor. Sensors are terminated after 60 seconds.
powershellPowershell Specific
Use type accelerators over cmdlets where possible.
Be careful these accelerators are not .Net version specific
Make use of try and catch
Especially with module imports
Avoid using a gnarly one liner, they are a strength when operating in CLI only, but are quite difficult to read.
Set a reasonable PowerShell version baseline and stick with it.
bashSh/Bash Specific
Stick to POSIX compliant code if Bash is not always available.
Avoid using a gnarly one liner.
Avoid subshell spawning where possible.
Use nobody user when accessing RPMs.
pythonPython Specific
Download and familiarize yourself with the Tanium Core Python Documentation core-python-html-documentation-3.6.81.zip.
Use Pep-8 standard
Stick to imports from the standard library
Python will be slower due to spin-up time, so you will want to aim for even lower run times than other languages.
Use concurrency
Avoid excessive file IO
Make use of ctypes
Avoid excessive imports
vbscriptVBScript Specific
Use Option Explicit.
Avoid global variable declaration where possible.
Use classes and functions to avoid repetitive code.
This is true with all languages but especially true in VBScript as more lines can be required to do less and sensors are size constrained.
Sensor Pitfalls: Things you SHOULD NOT do
There are certain things that you should never do in your custom sensor code due to security or performance concerns. Performance is a security concern because a poorly designed sensor can result in thousands of endpoints across your network locked up at once.

Use any commands that would cause network traffic. This is not always obvious! Example: Access a mounted directory, AD commands, etc.
Make any changes to the endpoint. A sensor should be read-only. If you need to make any changes to the endpoint, create a package instead.
Attempt to access anything in the context of the current user. Tanium Sensors are run by the Tanium Client as root (UNIX) or SYSTEM(Windows) and will not have the context of the user that is logged in.
Access private Tanium APIs or functionality in your code. This includes making Mailbox requests.
64-bit-only PowerShell cmdlets are not available and therefore cannot be used.
Create a Package
Now we will focus on the other area of content, and how we should effect change on our endpoints within Tanium packages. This section will contain a breakdown of the anatomy of a Tanium package, best practices, and pitfalls to avoid when developing packages.

Parameters
Like sensors, packages support parameters. Unlike sensors, packages will utilize these values as part of a command line call when the package is run. Packages also support two methods for entry, one being user sourced and the other being sensor sourced. Parameters will always be passed as URL encoded strings. Your script will need to decode the values before using them. Below we will examine those two types and give a bit more detail around them.

User Parameters
User parameters are parameters that field their options at the time of deployment from the user. There are many types of parameters that can be defined, which we will explore more later when discussing Package options.

Sensor Sourced Parameters
Sensor parameters are an Interact fielded set of values pulled from sensor returns that can be defined within a package. When creating a package, the option to "add sensor variables" can be used which opens a window allowing you to find and select your variable if you do not know the exact variable. These values, like other package parameters, only modify the value being passed in your command line, but otherwise have no effect on your package's payload. When a package definition contains sensor parameters, it can only be deployed when all of those sensors are included in the targeting question.

Package Options
Now let us look at the Package creation page and discuss the elements within it as we did with sensors.

createpackage
Details:

Package Name: Name to be used by Tanium for this package.
Display Name: Name to display when browsing this package. If not set, it will default to the defined package name.
Content Set: Content set for this to belong to and be used by RBAC for determining who can use this package.
Command: Command line switches to be used with your package to make it run.
Command Timeout: How long is the longest expected run time for this package.
Download Timeout: How long is the longest expected download time. This combines with command timeout to determine the total allowed run time.
Ignore Action Lock: This will allow the package to bypass action lock if set.
Launch this package command in a process group: Toggled to allow a package to spawn a long running process.
Files:

Add File:
Local File: Files uploaded to the Tanium server directly from the creators or users' system.
Remote File: AURL or UNC path to file location which allows for update checks.
Parameters

Add Parameter:
Text Input: String values provided by users which can be validated by regex.
Drop Down List: List of values for a user to select.
Checkbox: Boolean value provided by user.
Numeric: Integer values.
Numeric Interval: Integer values that allow a drop-down list of snap intervals.
Date Time: Allows users to select date and time,
Date: Allows users to select date.
Time: Allows user to select time.
Date Time Range: Allows user to select two dates and times for a range
List: Allows users to provide a list of values, like text area, but returns as an array.
Text Area: Allows users to provide a large string.
Separator: Cosmetic item to create sections in your parameter options.
Verification Query A verification query allows you to craft a Tanium filter for validating a change in state of the endpoint to confirm success. Without a verification query configured on a package, Tanium will not have a way to determine if an action was completed successfully or not. The goal is to have the package modify the endpoint in such a way that the verification query will only match those exact endpoints where the action was completed successfully. Any endpoints that the filter matches are considered verified. These queries are the same format as the right hand side of a question, so it can be useful to use Interact to help construct and test your verification query. For example, let's say you have created a package that stages an executable on the endpoint. The verification query can confirm that the file exists.



Tanium File Exists[..\MyCustomThing\MyCustomThing.exe]
It is common for a custom package to have a corresponding custom sensor created to be used in a verification query.

Package Best Practices: Things you SHOULD do
Most of the best practices for Sensors apply to Packages as well. These are practices specific to packages.

Create a corresponding sensor for your package to return info to check if it has been run and confirm the desired effects.
Results of the endpoint change.
Status of tools if they are installed by your package.
Status sensor if you have dependencies with this package.
Packages are executed serially. With that in mind, you should avoid long running packages to avoid blocking subsequent actions.
Tanium should terminate all subprocesses that it spawns on exit when the process group closes, but it is a best practice to create controls within your content to insure you are not spawning unnecessary things and leaving them running.
Packages log all output from the package into its action log. This means verbosity in your code will work as a log source rather than needing to create a separate logging function.
If you are executing tools that you have staged previously, then it is best practice to use a log handler of sorts in your staged code.
With network related calls in packages, consider doing some form of time delayed randomization.
At time of deployment, users should select Distribute Over Time as appropriate to avoid potential network flooding or overloading virtualized environments.
If a package makes a change on the endpoint, ensure that there is sensor available (or create one) that can be used to confirm that the change has been made. This will be necessary to create a Validation Query.
powershellPowershell Specific
Consider making use of the –ExecutionPolicy Bypass argument.
Consider using –NoProfile argument
Use the Tanium-provided TPowershell package rather than the system Powershell when possible. It will automatically select for the proper 32 or 64 bit executable.
Be very careful about the performance impact of some Commandlets. For example, ForEach is considerably more performant in most cases than ForEach-Object. Consider using .NET static methods over Commandlets.
The Measure-Command commandlet can helpful during development to identify areas with performance improvement opportunities.
Example of typical package command using Powershell script



cmd.exe /d /c ..\..\Tools\StdUtils\TPowershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -NoProfile -File MyCustomScript.ps1
pythonPython Specific
Argparse is the recommended method for argument parsing of multiple parameters. It does create some overhead but allows for additional targeted validation should the parameters order be modified in any way.
If you need to use a package that is outside of the standard library, you can download it using pip and add it to the package and then import it in your code


pip download module_name --dest /path/to/destination/dir



from .module_name import something
Example of typical package command using Python script



../../TPython/TPython MyCustomScript.py
bashSh/Bash Specific
There is nothing specific about using bash in a package that does not also apply to sensors.
Example of typical package commands using POSIX-Compliant and Bash-specific shell scripts



/bin/sh MyCustomScript.sh
/bin/bash MyCustomScript.sh
vbscriptVBScript Specific
Use cscript for execution
Consider using /T: switches to set an execution timeout period.
Example of typical package command using VBScript



cmd.exe /d /c "%WinDir%\System32\cscript.exe" //T:1200 MyCustomScript.vbs
Package Pitfalls: Things you SHOULD NOT do
With packages, most sensor pitfalls still apply. However, as packages are less dependent on expedient performance, items like network calls, or slightly longer run times are acceptable. We will focus on specific things that should not be done.

If you have a large payload by size or volume, consider staging that content to avoid duplication of content stored in download directories of the client.
Do not use packages for long running processes, as they execute serially and will cause delays or timeouts of other actions.
Using a package to spin off the long-running process is not an acceptable work-around as there will be no visibility or control of this orphaned process. See Best Practices above.
Do not use packages to store sensitive information on the endpoints