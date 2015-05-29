# Windows Tools PowerShell Module

[Wiki](http://www.bonusbits.com/wiki/HowTo:Use_Windows_Tools_PowerShell_Module)

## Setup Summary

1. PowerShell 2.0+
2. .NET 4.0+
3. PowerShell CLR set to run 4.0+
4. Set-ExecutionPolicy to Unrestricted
5. Create %USERPROFILE%\Documents\WindowsPowerShell\Modules Folder if needed
6. Download latest Module version
7. Extract Module folder to %USERPROFILE%\Documents\WindowsPowerShell\Modules\
8. Import-Module
9. Run Set-WindowsToolsDefaults


## Optional 
Add code to PowerShell user profile script to Import and run Set-WindowsToolsDefaults automatically when PowerShell is launched.

#### EXAMPLE

**$ENV:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1**

```powershell
# LOAD WINDOWS TOOLS MODULE
$ModuleList = Get-Module -ListAvailable | Select -ExpandProperty Name
If ($ModuleList -contains 'WindowsTools') {
	Import-Module �Name WindowsTools
}

# REMOVE TEMP MODULE LIST
If ($ModuleList) {
	Remove-Variable -Name ModuleList
}
	
# SET WINDOWS TOOLS MODULE DEFAULTS
If ((Get-Module | Select-Object -ExpandProperty Name | Out-String) -match "WindowsTools") {
	Set-WindowsToolsDefaults -vCenter "vcenter01.domain.com" -Quiet
}
```


## Disclaimer

Use at your own risk.