#CHANGE LOG
---

##1.1.3 - 01/11/2013

* Removed Func_ from SubScript Filenames
* Removed dot sourcing subscripts
* Removed $SubScripts parameter from SubScripts and Parent Scripts
* Load all SubScripts when module is imported
* Added Import-Module to parent script background jobs to work around file access issue if in the system folder
* Most if not all the Subscripts versions were revised for the changes.
* Removed second hyphen from SubScript Function names
* Did some region cleanup and help/notes cleanup
* Moved Parent Scripts into a folder named ParentScripts
* Moved Shortcuts into a folder named Shortcuts
* Parent Script results file write method changed to a temp folder and individual files per job. Then combined at the end.
* Added Module Argument to skip showing the header. Used when loading Module in background job.
* Removed SubScript Dependency Checks from Parent Scripts
* Added Timezone to Log file datetime outputs

##1.1.2 - 12/27/2012

* Switched to Func_Show-WindowsToolsHeader 1.0.4
* Switched to Func_Reset-WindowsToolsUI 1.0.3
* Added Restart-Hosts
* Added Get-WTCommand
* Added Switch-Content
* Added Get-HostInfo

##1.1.1 - 12/27/2012

* Renamed Module, associated scripts and calls from LBTools to WindowsTools

##1.1.0 - 12/26/2012

* Switched to Get-DriveSpace 1.0.6

##1.0.9 - 12/04/2012

* Switched to Get-DriveSpace 1.0.5
* Switched to Watch-Jobs 1.0.5
* Switched to Set-LBToolsDefaults 1.0.3

##1.0.8 - 11/27/2012

* Switched to Get-DriveSpace 1.0.4
* Switched to Move-ADComputers 1.0.1

##1.0.7 - 11/08/2012

* Added Get-InactiveComputers 1.0.0

##1.0.5 - 10/29/2012

* Added Move-ADComputers 1.0.0

##1.0.3 - 08/24/2012

* Switched to Get-DiskSpace 1.0.3

##1.0.2 - 08/06/2012

* Switched to Get-DiskSpace 1.0.2

##1.0.1 - 07/25/2012

* Added Get-DiskSpace 1.0.1

##1.0.0 - 07/10/2012

* First Draft

---