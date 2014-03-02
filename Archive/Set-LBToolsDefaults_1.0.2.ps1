#requires –version 2.0

Function Set-LBToolsDefaults {

#region Help

<#
.SYNOPSIS
	Sets a global variable with a default vCenter Hostname.
.DESCRIPTION
	This is used with several of the Windows Patching scripts to reduce parameter typing and keep the scripts universal.
.NOTES
	AUTHOR:  Levon Becker
	STATE:	 Stable
.EXAMPLE
	Set-LBToolsDefaults -vCenter "vcenter01.domain.com" 
	Sets the defaults, creates missing folders and displays the results.
.EXAMPLE
	Set-LBToolsDefaults -vCenter "vcenter01.domain.com" -Quiet
	Sets the defaults, creates missing folders and does not display the results.
.PARAMETER vCenter
	FQDN to Vmware Virtual Center host.
.PARAMETER RootLogPath
	This is the full path to the root directory where logs will be created.
	The default is your user profile documents folder under WindowsPowerShell.
	This can be change to any local or network mapped drive, but be beware
	if using a network mapped drive because latency may cause issues.
	Of course double check permissions with the account running PowerShell
	as well.
.PARAMETER HostListRootPath
	This is the full path to the root directory where Host List Files
	Can be placed and is the default location the FileBrowser function will
	look.
	The default is your user profile documents folder.
	This can be change to any local or network mapped drive, but be beware
	if using a network mapped drive because latency may cause issues.
	Of course double check permissions with the account running PowerShell
	as well.
.PARAMETER ResultsRootPath
	This is the full path to the root directory where the results spreadsheets
	will be created.
	The default is your user profile documents folder.
	This can be change to any local or network mapped drive, but be beware
	if using a network mapped drive because latency may cause issues.
	Of course double check permissions with the account running PowerShell
	as well.
.PARAMETER NoHeader
	This switch will skip showing the Module Header after initial load.
.PARAMETER NoTips
	This switch will skip showing the Module Header after initial load.
.PARAMETER Quiet
	If this switch is used the results will not be displayed.
.LINK
	http://wiki.bonusbits.com:PSScript:Set-LBToolsDefaults
#>

#endregion Help

	Param (
		[parameter(Position=0,Mandatory=$true)][string]$vCenter,
#		[parameter(Position=1,Mandatory=$true)][string]$UpdateServerURL,
		[parameter(Mandatory=$false)][string]$RootLogPath = "$Env:USERPROFILE\Documents",
		[parameter(Mandatory=$false)][string]$HostListRootPath = "$Env:USERPROFILE\Documents",
		[parameter(Mandatory=$false)][string]$ResultsRootPath = "$Env:USERPROFILE\Documents",
		[parameter(Mandatory=$false)][switch]$NoHeader,
		[parameter(Mandatory=$false)][switch]$NoTips,
		[parameter(Mandatory=$false)][switch]$Quiet
	)
	
	# REMOVE EXISTING OUTPUT PSOBJECT	
	If ($Global:LBToolsDefaults) {
		Remove-Variable LBToolsDefaults -Scope "Global"
	}
	
	[Boolean]$NoHeaderBool = ($NoHeader.IsPresent)
	[Boolean]$NoTipsBool = ($NoTips.IsPresent)
	
	If ($NoHeader.IsPresent -eq $true) {
		Clear
	}
	
	#region Tasks
	
		#region Set Module Paths
	
			[string]$ModuleRootPath = $Global:LBToolsModulePath
			[string]$SubScripts = Join-Path -Path $ModuleRootPath -ChildPath 'SubScripts'
			[string]$Assets = Join-Path -Path $ModuleRootPath -ChildPath 'Assets'
			
		#region Set Module Paths
	
		#region Create Log Directories
		
			# CREATE WINDOWSPOWERSHELL DIRECTORY IF MISSING
			## My Module Defaults
			[string]$UserDocsFolder = "$Env:USERPROFILE\Documents"
			[string]$UserPSFolder = "$Env:USERPROFILE\Documents\WindowsPowerShell"
			[string]$LogPath = "$RootLogPath\Logs"
			[string]$ResultsPath = "$ResultsRootPath\Results"
			[string]$HostListPath = "$HostListRootPath\HostLists"
			## Unique Cmdlet Results Paths
			[string]$SwitchContentResultsPath = "$ResultsPath\Switch-Content"
			[string]$GetHostInfoResultsPath = "$ResultsPath\Get-HostInfo"
			[string]$GetDriveSpaceResultsPath = "$ResultsPath\Get-DriveSpace"
			[string]$MoveADComputerResultsPath = "$ResultsPath\Move-ADComputer"
			[string]$GetInactiveComputersResultsPath = "$ResultsPath\Get-InactiveComputers"
			
			If ((Test-Path -Path $UserPSFolder) -eq $false) {
				New-Item -Path $UserDocsFolder -Name 'WindowsPowerShell' -ItemType Directory -Force | Out-Null
			} 
		
			# CREATE ROOT DIRECTORIES IF MISSING
			If ((Test-Path -Path $LogPath) -eq $false) {
				New-Item -Path $RootLogPath -Name 'Logs' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $HostListPath) -eq $false) {
				New-Item -Path $HostListRootPath -Name 'HostLists' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $ResultsPath) -eq $false) {
				New-Item -Path $ResultsRootPath -Name 'Results' -ItemType Directory -Force | Out-Null
			}
			## Unique to this Module
			# RESULTS SUBFOLDERS
			If ((Test-Path -Path $SwitchContentResultsPath) -eq $false) {
				New-Item -Path $ResultsPath -Name 'Switch-Content' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $GetHostInfoResultsPath) -eq $false) {
				New-Item -Path $ResultsPath -Name 'Get-HostInfo' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $GetDriveSpaceResultsPath) -eq $false) {
				New-Item -Path $ResultsPath -Name 'Get-DriveSpace' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $MoveADComputerResultsPath) -eq $false) {
				New-Item -Path $ResultsPath -Name 'Move-ADComputer' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $GetInactiveComputersResultsPath) -eq $false) {
				New-Item -Path $ResultsPath -Name 'Get-InactiveComputers' -ItemType Directory -Force | Out-Null
			}
		
			# ROOT LOG DIRECTORIES
			$SwitchContentLogPath = Join-Path -Path $LogPath -ChildPath 'Switch-Content'
			$GetHostInfoLogPath = Join-Path -Path $LogPath -ChildPath 'Get-HostInfo'
			$GetDriveSpaceLogPath = Join-Path -Path $LogPath -ChildPath 'Get-DriveSpace'
			$MoveADComputerLogPath = Join-Path -Path $LogPath -ChildPath 'Move-ADComputer'

			# CREATE LOG ROOT DIRECTORY IF MISSING
			If ((Test-Path -Path $SwitchContentLogPath) -eq $false) {
				New-Item -Path $LogPath -Name 'Switch-Content' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $GetHostInfoLogPath) -eq $false) {
				New-Item -Path $LogPath -Name 'Get-HostInfo' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $GetDriveSpaceLogPath) -eq $false) {
				New-Item -Path $LogPath -Name 'Get-DriveSpace' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $MoveADComputerLogPath) -eq $false) {
				New-Item -Path $LogPath -Name 'Move-ADComputer' -ItemType Directory -Force | Out-Null
			}

			$SubFolderList = @(
				'History',
				'JobData',
				'Latest',
				'WIP'
			)

			# CREATE LOG SUB DIRECTORIES IF MISSING
			Foreach ($folder in $SubFolderList) {
				If ((Test-Path -Path "$SwitchContentLogPath\$folder") -eq $false) {
					New-Item -Path $SwitchContentLogPath -Name $folder -ItemType Directory -Force | Out-Null
				}
			}
			Foreach ($folder in $SubFolderList) {
				If ((Test-Path -Path "$GetHostInfoLogPath\$folder") -eq $false) {
					New-Item -Path $GetHostInfoLogPath -Name $folder -ItemType Directory -Force | Out-Null
				}
			}
			Foreach ($folder in $SubFolderList) {
				If ((Test-Path -Path "$GetDriveSpaceLogPath\$folder") -eq $false) {
					New-Item -Path $GetDriveSpaceLogPath -Name $folder -ItemType Directory -Force | Out-Null
				}
			}
			Foreach ($folder in $SubFolderList) {
				If ((Test-Path -Path "$MoveADComputerLogPath\$folder") -eq $false) {
					New-Item -Path $MoveADComputerLogPath -Name $folder -ItemType Directory -Force | Out-Null
				}
			}
		
		#endregion Create Log Directories
	
	#endregion Tasks
	
	# Create Results Custom PS Object
	$Global:LBToolsDefaults = New-Object -TypeName PSObject -Property @{
		vCenter = $vCenter
		ModuleRootPath = $ModuleRootPath
		SubScripts = $SubScripts
		Assets = $Assets
		RootLogPath = $RootLogPath
		UserDocsFolder = $UserDocsFolder
		UserPSFolder = $UserPSFolder
		HostListPath = $HostListPath
		ResultsPath = $ResultsPath
		NoHeader = $NoHeaderBool
		NoTips = $NoTipsBool
		SwitchContentLogPath = $SwitchContentLogPath
		SwitchContentResultsPath = $SwitchContentResultsPath
		GetHostInfoLogPath = $GetHostInfoLogPath
		GetHostInfoResultsPath = $GetHostInfoResultsPath
		GetDriveSpaceResultsPath = $GetDriveSpaceResultsPath
		GetDriveSpaceLogPath = $GetDriveSpaceLogPath
		MoveADComputerResultsPath = $MoveADComputerResultsPath
		MoveADComputerLogPath = $MoveADComputerLogPath
		GetInactiveComputersResultsPath = $GetInactiveComputersResultsPath
	}
	If ($Quiet.IsPresent -eq $false) {
		$Global:LBToolsDefaults | Format-List
	}
}

#region Notes

<# Dependents
	
#>

<# Dependencies
	
#>

<# To Do List

	 
#>

<# Change Log
1.0.0 - 05/10/2012
	Created
1.0.1 - 07/09/2012
	Added Get-HostInfo
1.0.2 - 10/29/2012
	Added Move-ADComputer
#>

#endregion Notes
