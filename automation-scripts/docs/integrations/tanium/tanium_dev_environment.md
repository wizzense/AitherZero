Environment Setup and Development Practices
Starting your custom content project with a thoughtful environment to build and test your code will set you up for success and avoid costly issues later on. Development environments are often as much about personal style and preference as it is about technical requirements. Below we will discuss some common items that should exist and why, but your mileage will vary.

Environment Considerations
A purpose-built test environment and an IDE should be used for development. Do not try to author scripts in the Tanium Console sensor screen or test them in your production environment.

Sensors run in a 32bit environment, so you will need to test them in one
In Windows this is achieved by launching your code from a 32bit terminal like cmd.exe in the %windir%\sysWOW64\ directory.
For Linux, it is best to have a 32bit install to achieve this.
Code executes as SYSTEM user or UID0. HKCU and environment variables point to System account, not the logged-in user.
In Windows, psexec from sysinternals can achieve this.
Non-Windows, sudo should be sufficient to give a correct run state permission.
Tanium doesn't have specific recommended tooling, but within the Tanium Content team, we use the following:
IDEs:
VSCode
Free modular IDE
VBSEdit
Paid IDE tailored specifically to VBScript
Vim
Free modular and command driven IDE that works within a terminal
Linters are static code analysis tools used to help flag bad patterns, errors, or poor construction. They are language specific, so we will list the ones commonly used within Tanium.
Bash = ShellCheck
PowerShell = PSScriptAnalyzer
Python = Pylint
VBScript = n/a
Tanium does not version files or sensors in the platform. With that in mind it is recommended to make use of a version control system for this purpose. I would highly encourage the use of git as it contains the largest volume of tools and support.
Include the version number of your content in the script file so that it is easy to see which one is currently in place
Testing Considerations
Testing code becomes a major need for any developer. We do not have an official stance on how the environment should look for testing, but we can provide some considerations.

Selecting which operating systems to test on

Determine your lowest common denominator for target reference and spin up a test VM for that. Then an instance of the latest OS version.
This allows you to validate that you are not calling a function or library that has been deprecated.
For a list of supported operating systems, see the Tanium docs page.
For Linux, consider main line distributions.
RHEL
Ubuntu
SuSE
Consider staging your workspace to a shared folder that can be accessed by your test endpoints and provide an execution wrapper (.bat or .sh file that contains execution commands).

Internally at Tanium we use home grown tools to perform these actions and it may be worth doing something similar that allows for the following basic actions.

Spin up VMs for testing against.
Stage to test systems.
Execute with specific commands.
Dump results to a file.
Compare results.
Deployment Considerations
When you have a workable solution, the promotion process should look like this:
Import or Create content into your Tanium dev instance.
Schedule a saved question to repeat the question or deployment over a fixed interval (every 3 hours for instance)
Review sensor runtimes in the Tanium console and ensure you see expected run times.
Review results.
After an appropriate bake time in the dev environment with no observed negative or unexpected impacts, move to a stage or live instance.
Consider limiting usage by RBAC in live environment until you can review for negative impact. Increase at a rate that your business can tolerate from there.