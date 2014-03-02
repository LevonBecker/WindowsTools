#requires –version 2.0

Function Get-DriveSpace {

#region Help

<#
.SYNOPSIS
	Automation Script.
.DESCRIPTION
	Script for automating a process.
.NOTES
	VERSION:    1.0.5
	AUTHOR:     Levon Becker
	EMAIL:      PowerShell.Guru@BonusBits.com 
	ENV:        Powershell v2.0, CLR 4.0+, PowerCLI 4.1+
	TOOLS:      PowerGUI Script Editor
.INPUTS
	ComputerName    Single Hostname
	List            List of Hostnames
	FileName        File with List of Hostnames
	FileBrowser     File with List of Hostnames
	
	DEFAULT FILENAME PATH
	---------------------
	HOSTLISTS
	%USERPROFILE%\Documents\HostList
.OUTPUTS
	DEFAULT PATHS
	-------------
	RESULTS
	%USERPROFILE%\Documents\Results\Get-DriveSpace
	
	LOGS
	%USERPROFILE%\Documents\Logs\Get-DriveSpace
	+---History
	+---JobData
	+---Latest
	+---WIP
.EXAMPLE
	Get-DriveSpace -ComputerName server01 
	Patch a single computer.
.EXAMPLE
	Get-DriveSpace server01 
	Patch a single computer.
	The ComputerName parameter is in position 0 so it can be left off for a
	single computer.
.EXAMPLE
	Get-DriveSpace -List server01,server02
	Test a list of hostnames comma separated without spaces.
.EXAMPLE
	Get-DriveSpace -List $MyHostList 
	Test a list of hostnames from an already created array variable.
	i.e. $MyHostList = @("server01","server02","server03")
.EXAMPLE
	Get-DriveSpace -FileBrowser 
	This switch will launch a separate file browser window.
	In the window you can browse and select a text or csv file from anywhere
	accessible by the local computer that has a list of host names.
	The host names need to be listed one per line or comma separated.
	This list of system names will be used to perform the script tasks for 
	each host in the list.
.EXAMPLE
	Get-DriveSpace -FileBrowser -SkipOutGrid
	FileBrowser:
		This switch will launch a separate file browser window.
		In the window you can browse and select a text or csv file from anywhere
		accessible by the local computer that has a list of host names.
		The host names need to be listed one per line or comma separated.
		This list of system names will be used to perform the script tasks for 
		each host in the list.
	SkipOutGrid:
		This switch will skip the results poppup windows at the end.
.PARAMETER ComputerName
	Short name of Windows host to patch
	Do not use FQDN 
.PARAMETER List
	A PowerShell array List of servers to patch or comma separated list of host
	names to perform the script tasks on.
	-List server01,server02
	@("server1", "server2") will work as well
	Do not use FQDN
.PARAMETER FileBrowser
	This switch will launch a separate file browser window.
	In the window you can browse and select a text or csv file from anywhere
	accessible by the local computer that has a list of host names.
	The host names need to be listed one per line or comma separated.
	This list of system names will be used to perform the script tasks for 
	each host in the list.
.PARAMETER MaxJobs
	Maximum amount of background jobs to run simultaneously. 
	Adjust depending on how much memory and load the localhost can handle.
	Because the entire task is rather quick it's better to keep this number 
	low for overall speed.
	It's not recommended to set higher than 400.
	Default = 100
.PARAMETER JobQueTimeout
	Maximum amount of time in seconds to wait for the background jobs to finish 
	before timing out. 	Adjust this depending out the speed of your environment 
	and based on the maximum jobs ran simultaneously.
	
	If the MaxJobs setting is turned down, but there are a lot of servers this 
	may need to be increased.
	
	This timer starts after all jobs have been queued.
	Default = 300 (5 minutes)
.PARAMETER SkipOutGrid
	This switch will skip displaying the end results that uses Out-GridView.
.PARAMETER SkipAllVmware
	This switch will skip all functions that require PowerCLI.
	Currently there are only a few small tasks to gather remote computer system
	data that are used. First it will try WMI and registry queries before resorting
	to quering vCenter.
.LINK
	http://wiki.bonusbits.com/main/PSScript:Get-DriveSpace
	http://wiki.bonusbits.com/main/PSModule:LBTools
	http://wiki.bonusbits.com/main/HowTo:Enable_.NET_4_Runtime_for_PowerShell_and_Other_Applications
	http://wiki.bonusbits.com/main/HowTo:Setup_PowerShell_Module
	http://wiki.bonusbits.com/main/HowTo:Enable_Remote_Signed_PowerShell_Scripts
#>

#endregion Help

#region Parameters

	[CmdletBinding()]
	Param (
		[parameter(Mandatory=$false,Position=0)][string]$ComputerName,
		[parameter(Mandatory=$false)][array]$List,
		[parameter(Mandatory=$false)][switch]$FileBrowser,
		[parameter(Mandatory=$false)][int]$MaxJobs = '10', #Because the entire task is rather quick it's better to keep this low for overall speed.
		[parameter(Mandatory=$false)][int]$JobQueTimeout = '600', #This timer starts after all jobs have been queued.
		[parameter(Mandatory=$false)][int]$MinFreeMB = '2000',
		[parameter(Mandatory=$false)][switch]$SkipOutGrid
	)

#endregion Parameters

	If (!$Global:LBToolsDefaults) {
		. "$Global:LBToolsModulePath\SubScripts\MultiFunc_Show-LBToolsErrors_1.0.0.ps1"
		Show-LBToolsDefaultsMissingError
	}

	# GET STARTING GLOBAL VARIABLE LIST
	New-Variable -Name StartupVariables -Force -Value (Get-Variable -Scope Global | Select -ExpandProperty Name)
	
	# CAPTURE CURRENT TITLE
	[string]$StartingWindowTitle = $Host.UI.RawUI.WindowTitle

	# DEFAULTS
#	[boolean]$FileBrowserUsed = $false
	[string]$HostListPath = ($Global:LBToolsDefaults.HostListPath)

#region Prompt: Host Input

	#region Prompt: FileBrowser
	
		If ($FileBrowser.IsPresent -eq $true) {
			. "$Global:LBToolsModulePath\SubScripts\Func_Get-FileName_1.0.0.ps1"
			Clear
			Write-Host 'SELECT FILE CONTAINING A LIST OF HOSTS TO PATCH.'
			Get-FileName -InitialDirectory $HostListPath -Filter "Text files (*.txt)|*.txt|Comma Delimited files (*.csv)|*.csv|All files (*.*)|*.*"
			[string]$FileName = $Global:GetFileName.FileName
			[string]$HostListFullName = $Global:GetFileName.FullName
		}
	
	#endregion Prompt: FileBrowser

	#region Prompt: Missing Host Input

		If (!($FileName) -and !($ComputerName) -and !($List)) {
#			[boolean]$HostInputPrompt = $true
			Clear
			$promptitle = ''
			
			$message = "Please Select a Host Entry Method:`n"
			
			# HM = Host Method
			$hmc = New-Object System.Management.Automation.Host.ChoiceDescription "&ComputerName", `
			    'Enter a single hostname'
			
			$hml = New-Object System.Management.Automation.Host.ChoiceDescription "&List", `
			    'Enter a List of hostnames separated by a commna without spaces'
			
			$hmf = New-Object System.Management.Automation.Host.ChoiceDescription "&File", `
			    'Text file name that contains a List of ComputerNames'
			
			$exit = New-Object System.Management.Automation.Host.ChoiceDescription "E&xit", `
			    'Exit Script'

			$options = [System.Management.Automation.Host.ChoiceDescription[]]($hmc, $hml, $hmf, $exit)
			
			$result = $host.ui.PromptForChoice($promptitle, $message, $options, 3) 
			
			# RESET WINDOW TITLE AND BREAK IF EXIT SELECTED
			If ($result -eq 3) {
				Clear
				Break
			}
			Else {
			Switch ($result)
				{
				    0 {$HostInputMethod = 'ComputerName'}
					1 {$HostInputMethod = 'List'}
				    2 {$HostInputMethod = 'File'}
				}
			}
			Clear
			
			# PROMPT FOR COMPUTERNAME
			If ($HostInputMethod -eq 'ComputerName') {
				Do {
					Clear
					Write-Host ''
#					Write-Host 'Short name of a single host.'
					$ComputerName = $(Read-Host -Prompt 'ENTER COMPUTERNAME')
				}
				Until ($ComputerName)
			}
			# PROMPT FOR LIST 
			Elseif ($HostInputMethod -eq 'List') {
				Write-Host 'Enter a List of hostnames separated by a comma without spaces to patch.'
				$commaList = $(Read-Host -Prompt 'Enter List')
				# Read-Host only returns String values, so need to split up the hostnames and put into array
				[array]$List = $commaList.Split(',')
			}
			# PROMPT FOR FILE
			Elseif ($HostInputMethod -eq 'File') {
				. "$Global:LBToolsModulePath\SubScripts\Func_Get-FileName_1.0.0.ps1"
				Clear
				Write-Host ''
				Write-Host 'SELECT FILE CONTAINING A LIST OF HOSTS TO PATCH.'
				Get-FileName -InitialDirectory $HostListPath -Filter "Text files (*.txt)|*.txt|Comma Delimited files (*.csv)|*.csv|All files (*.*)|*.*"
				[string]$FileName = $Global:GetFileName.FileName
				[string]$HostListFullName = $Global:GetFileName.FullName
			}
			Else {
				Write-Host 'ERROR: Host method entry issue'
				Break
			}
		}
		
	#endregion Prompt: Missing Host Input
		
#endregion Prompt: Host Input

#region Variables

	# DEBUG
	$ErrorActionPreference = "Inquire"
	
	# SET ERROR MAX LIMIT
	$MaximumErrorCount = '1000'
	$Error.Clear()

	# SCRIPT INFO
	[string]$ScriptVersion = '1.0.5'
	[string]$ScriptTitle = "Get Disk Space by Levon Becker"
	[int]$DashCount = '30'

	# CLEAR VARIABLES
	[int]$TotalHosts = 0

	# LOCALHOST
	[string]$ScriptHost = $Env:COMPUTERNAME
	[string]$UserDomain = $Env:USERDOMAIN
	[string]$UserName = $Env:USERNAME
	[string]$FileDateTime = Get-Date -UFormat "%Y-%m%-%d_%H.%M"
	[datetime]$ScriptStartTime = Get-Date
	$ScriptStartTimeF = Get-Date -Format g

	# DIRECTORY PATHS
	[string]$LogPath = ($Global:LBToolsDefaults.GetDriveSpaceLogPath)
	[string]$ScriptLogPath = Join-Path -Path $LogPath -ChildPath 'ScriptLogs'
	[string]$JobLogPath = Join-Path -Path $LogPath -ChildPath 'JobData'
	[string]$ResultsPath = ($Global:LBToolsDefaults.GetDriveSpaceResultsPath)
	
	[string]$ModuleRootPath = $Global:LBToolsModulePath
	[string]$SubScripts = Join-Path -Path $ModuleRootPath -ChildPath 'SubScripts'
	[string]$Assets = Join-Path -Path $ModuleRootPath -ChildPath 'Assets'
	
	#region  Set Logfile Name + Create HostList Array
	
		If ($ComputerName) {
			[string]$HostInputDesc = $ComputerName.ToUpper()
			# Inputitem is also used at end for Outgrid
			[string]$InputItem = $ComputerName.ToUpper() #needed so the WinTitle will be uppercase
			[array]$HostList = $ComputerName.ToUpper()
		}
		ElseIF ($List) {
			[array]$List = $List | ForEach-Object {$_.ToUpper()}
			[string]$HostInputDesc = "LIST - " + ($List | Select -First 2) + " ..."
			[string]$InputItem = "LIST: " + ($List | Select -First 2) + " ..."
			[array]$HostList = $List
		}		
		ElseIf ($FileName) {
			[string]$HostInputDesc = $FileName
			# Inputitem used for WinTitle and Out-GridView Title at end
			[string]$InputItem = $FileName
			If ((Test-Path -Path $HostListFullName) -ne $true) {
					Write-Host ''
					Write-Host "ERROR: INPUT FILE NOT FOUND ($HostListFullName)" -ForegroundColor White -BackgroundColor Red
					Write-Host ''
					Break
			}
			[array]$HostList = Get-Content $HostListFullName
			[array]$HostList = $HostList | ForEach-Object {$_.ToUpper()}
		}
		Else {
			Write-Host ''
			Write-Host "ERROR: INPUT METHOD NOT FOUND" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			Break
		}
		# Remove Duplicates in Array + Get Host Count
		[array]$HostList = $HostList | Select -Unique
		[int]$TotalHosts = $HostList.Count
	
	#endregion Set Logfile Name + Create HostList Array
	
	#region Determine TimeZone
	
		. "$SubScripts\Func_Get-TimeZone_1.0.0.ps1"
		Get-TimeZone -ComputerName 'Localhost'
		
		If (($Global:GetTimeZone.Success -eq $true) -and ($Global:GetTimeZone.ShortForm -ne '')) {
			[string]$TimeZone = "_" + $Global:GetTimeZone.ShortForm
		}
		Else {
			[string]$Timezone = ''
		}
	
	#endregion Determine TimeZone
	
	#region Set Filenames and Paths

	# FILENAMES
	[string]$ResultsTextFileName = "Get-DriveSpace_Results_" + $FileDateTime + $Timezone + "_($HostInputDesc).log"
	[string]$ResultsCSVFileName = "Get-DriveSpace_Results_" + $FileDateTime + $Timezone + "_($HostInputDesc).csv"
	[string]$JobLogFileName = "JobData_" + $FileDateTime + $Timezone + "_($HostInputDesc).log"

	# PATH + FILENAMES
	[string]$ResultsTextFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsTextFileName
	[string]$ResultsCSVFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsCSVFileName
	[string]$JobLogFullName = Join-Path -Path $JobLogPath -ChildPath $JobLogFileName
	
	#endregion Set Filenames and Paths


#endregion Variables

#region Check Dependencies
	
	[int]$depmissing = 0
	$depmissingList = $null
	# Create Array of Paths to Dependancies to check
	CLEAR
	$depList = @(
		"$SubScripts\Func_Get-Runtime_1.0.3.ps1",
		"$SubScripts\Func_Remove-Jobs_1.0.6.ps1",
		"$SubScripts\Func_Get-HostIP_1.0.5.ps1",
		"$SubScripts\Func_Get-JobCount_1.0.3.ps1",
		"$SubScripts\Func_Get-TimeZone_1.0.0.ps1",
		"$SubScripts\Func_Get-OSVersion_1.1.0.ps1",
		"$SubScripts\Func_Watch-Jobs_1.0.4.ps1",
		"$SubScripts\Func_Reset-LBToolsUI_1.0.0.ps1",
		"$SubScripts\Func_Show-LBToolsHeader_1.0.2.ps1",
		"$SubScripts\Func_Show-ScriptHeader_1.0.2.ps1",
		"$SubScripts\Func_Test-Connections_1.0.8.ps1",
		"$SubScripts\Func_Test-Permissions_1.1.0.ps1",
		"$SubScripts\MultiFunc_Set-WinTitle_1.0.5.ps1",
		"$SubScripts\MultiFunc_Show-Script-Status_1.0.3.ps1",
		"$LogPath",
		"$LogPath\History",
		"$LogPath\JobData",
		"$LogPath\Latest",
		"$LogPath\WIP",
		"$HostListPath",
		"$ResultsPath",
		"$SubScripts",
		"$Assets"
	)

	Foreach ($deps in $depList) {
		[boolean]$checkpath = $false
		$checkpath = Test-Path -Path $deps -ErrorAction SilentlyContinue 
		If ($checkpath -eq $false) {
			$depmissingList += @($deps)
			$depmissing++
		}
	}
	If ($depmissing -gt 0) {
		Write-Host "ERROR: Missing $depmissing Dependancies" -ForegroundColor White -BackgroundColor Red
		$depmissingList
		Write-Host ''
		Break
	}

#endregion Check Dependencies

#region Functions

	
	. "$SubScripts\Func_Get-Runtime_1.0.3.ps1"
	. "$SubScripts\Func_Remove-Jobs_1.0.6.ps1"
	. "$SubScripts\Func_Get-JobCount_1.0.3.ps1"
	. "$SubScripts\Func_Watch-Jobs_1.0.4.ps1"
	. "$SubScripts\Func_Reset-LBToolsUI_1.0.0.ps1"
	. "$SubScripts\Func_Show-ScriptHeader_1.0.2.ps1"
	. "$SubScripts\Func_Test-Connections_1.0.8.ps1"
	. "$SubScripts\MultiFunc_Set-WinTitle_1.0.5.ps1"
		# Set-WinTitle-Start
		# Set-WinTitle-Base
		# Set-WinTitle-Input
		# Set-WinTitle-JobCount
		# Set-WinTitle-JobTimeout
		# Set-WinTitle-Completed
	. "$SubScripts\MultiFunc_Show-Script-Status_1.0.3.ps1"
		# Show-ScriptStatus-StartInfo
		# Show-ScriptStatus-QueuingJobs
		# Show-ScriptStatus-JobsQueued
		# Show-ScriptStatus-JobMonitoring
		# Show-ScriptStatus-JobLoopTimeout
		# Show-ScriptStatus-RuntimeTotals
	
#endregion Functions

#region Show Window Title

	Set-WinTitle-Start -title $ScriptTitle
	Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle

#endregion Show Window Title

#region Console Start Statements
	
	Show-ScriptHeader -blanklines '4' -DashCount $DashCount -ScriptTitle $ScriptTitle
	Set-WinTitle-Base -ScriptVersion $ScriptVersion 
	[datetime]$ScriptStartTime = Get-Date
	[string]$ScriptStartTimeF = Get-Date -Format g

#endregion Console Start Statements

#region Update Window Title

	Set-WinTitle-Input -wintitle_base $Global:wintitle_base -InputItem $InputItem
	
#endregion Update Window Title

#region Tasks

	#region Test Connections

		Test-Connections -List $HostList -MaxJobs '25' -TestTimeout '120' -JobmonTimeout '600' -SubScripts $SubScripts -ResultsTextFullName $ResultsTextFullName -JobLogFullName $JobLogFullName -TotalHosts $TotalHosts -DashCount $DashCount -ScriptTitle $ScriptTitle -WinTitle_Input $Global:WinTitle_Input
		If ($Global:TestConnections.AllFailed -eq $true) {
			# IF TEST CONNECTIONS SUBSCRIPT FAILS UPDATE UI AND EXIT SCRIPT
			Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
			Write-Host "`r".padright(40,' ') -NoNewline
			Write-Host "`rERROR: ALL SYSTEMS FAILED PERMISSION TEST" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			Reset-LBToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts
			Break
		}
		ElseIf ($Global:TestConnections.Success -eq $true) {
			[array]$HostList = $Global:TestConnections.PassedList
		}
		Else {
			# IF TEST CONNECTIONS SUBSCRIPT FAILS UPDATE UI AND EXIT SCRIPT
			Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
			Write-Host "`r".padright(40,' ') -NoNewline
			Write-Host "`rERROR: Test Connection Logic Failed" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			Reset-LBToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts
			Break
		}

	#endregion Test Connections

	#region Job Tasks
	
		Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle

		# STOP AND REMOVE ANY RUNNING JOBS
		Stop-Job *
		Remove-Job *
		
		# SHOULD SHOW ZERO JOBS RUNNING
		Get-JobCount 
		Set-WinTitle-JobCount -WinTitle_Input $Global:WinTitle_Input -jobcount $Global:getjobcount.JobsRunning
	
		#Create CSV file with headers
		Add-Content -Path $ResultsTextFullName -Encoding ASCII -Value 'Hostname,Complete Success,DiskSpace OK,C: Size (MB),C: Free (MB),Connected,Operating System,OS Arch,Host IP,Runtime,Starttime,Endtime,Errors,Script Version,Admin Host,User Account'	
		
		#Add Failed Connection Systems to Results Text File
		If ($Global:TestConnections.FailedCount -gt '0') {
			Get-Runtime -StartTime $ScriptStartTime
			[string]$FailedConnectResults = 'False,Error,Error,Error,False,Unknown,Unknown,Unknown' + ',' + $Global:GetRuntime.Runtime + ',' + $ScriptStartTimeF + ',' + $Global:GetRuntime.EndTimeF + ',' + 'Failed Connection' + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName
			$Global:TestConnections.FailedList | Foreach-Object {Add-Content -Path $ResultsTextFullName -Encoding ASCII -Value ($_ + ',' + $FailedConnectResults)}
		}
		
		#region Job Loop
		
			[int]$hostcount = $HostList.Count
			$i = 0
#			[boolean]$FirstGroup = $false
			Foreach ($ComputerName in $HostList) {
				$taskprogress = [int][Math]::Ceiling((($i / $hostcount) * 100))
				# Progress Bar
				Write-Progress -Activity "STARTING DISK SPACE CHECK JOB ON - ($ComputerName)" -PercentComplete $taskprogress -Status "OVERALL PROGRESS - $taskprogress%"
				
				# UPDATE COUNT AND WINTITLE
				Get-JobCount
				Set-WinTitle-JobCount -WinTitle_Input $Global:WinTitle_Input -jobcount $Global:getjobcount.JobsRunning
				# CLEANUP FINISHED JOBS
				Remove-Jobs -JobLogFullName $JobLogFullName

				#region Throttle Jobs
					
					# PAUSE FOR A FEW AFTER THE FIRST 25 ARE QUEUED
#					If (($Global:getjobcount.JobsRunning -ge '20') -and ($FirstGroup -eq $false)) {
#						Sleep -Seconds 5
#						[boolean]$FirstGroup = $true
#					}
				
					While ($Global:getjobcount.JobsRunning -ge $MaxJobs) {
						Sleep -Seconds 5
						Remove-Jobs -JobLogFullName $JobLogFullName
						Get-JobCount
						Set-WinTitle-JobCount -WinTitle_Input $Global:WinTitle_Input -jobcount $Global:getjobcount.JobsRunning
					}
				
				#endregion Throttle Jobs
				
				# Set Job Start Time Used for Elapsed Time Calculations at End ^Needed Still?
				[string]$JobStartTime1 = Get-Date -Format g
				
				#region Background Job

					Start-Job -RunAs32 -ScriptBlock {

						#region Job Variables

							# Set Varibles from Argument List
							$ComputerName = $args[0]
							$Assets = $args[1]
							$SubScripts = $args[2]
							$JobLogFullName = $args[3] 
							$ResultsTextFullName = $args[4]
							$ScriptHost = $args[5]
							$UserDomain = $args[6]
							$UserName = $args[7]
							$SubScripts = $args[8]
							$LogPath = $args[9]
							$ScriptVersion = $args[10]
							$MinFreeMB = $args[11]

							$testcount = 1
							
							# DATE AND TIME
							$JobStartTimeF = Get-Date -Format g
							$JobStartTime = Get-Date
							
							# NETWORK SHARES
							[string]$RemoteShareRoot = '\\' + $ComputerName + '\C$' 
							[string]$RemoteShare = Join-Path -Path $RemoteShareRoot -ChildPath 'WindowsScriptTemp'
							
							# HISTORY LOG
							[string]$HistoryLogFileName = $ComputerName + '_GetDriveSpace_History.log' 
							[string]$LocalHistoryLogPath = Join-Path -Path $LogPath -ChildPath 'History' 
							[string]$RemoteHistoryLogPath = $RemoteShare 
							[string]$LocalHistoryLogFullName = Join-Path -Path $LocalHistoryLogPath -ChildPath $HistoryLogFileName
							[string]$RemoteHistoryLogFullName = Join-Path -Path $RemoteHistoryLogPath -ChildPath $HistoryLogFileName
														
							# LATEST LOG
							[string]$LatestLogFileName = $ComputerName + '_GetDriveSpace_Latest.log' 
							[string]$LocalLatestLogPath = Join-Path -Path $LogPath -ChildPath 'Latest' 
							[string]$RemoteLatestLogPath = $RemoteShare 
							[string]$LocalLatestLogFullName = Join-Path -Path $LocalLatestLogPath -ChildPath $LatestLogFileName 
							[string]$RemoteLatestLogFullName = Join-Path -Path $RemoteLatestLogPath -ChildPath $LatestLogFileName
							
							# TEMP WORK IN PROGRESS PATH
							[string]$WIPPath = Join-Path -Path $LogPath -ChildPath 'WIP' 
							[string]$WIPFullName = Join-Path -Path $WIPPath -ChildPath $ComputerName
							
							# SET INITIAL JOB SCOPE VARIBLES
							[boolean]$Failed = $false
							[boolean]$CompleteSuccess = $false
							[Boolean]$ConnectSuccess = $true
#							[string]$ScriptErrors = 'None'

						#endregion Job Variables

						#region Job Functions
						
							. "$SubScripts\Func_Get-DiskSpace_1.0.1.ps1"
							. "$SubScripts\Func_Get-HostIP_1.0.5.ps1"
							. "$SubScripts\Func_Get-OSVersion_1.1.0.ps1"
							. "$SubScripts\Func_Get-Runtime_1.0.3.ps1"

						#endregion Job Functions
						
						#region Start
						
							# CREATE WIP TRACKING FILE IN WIP DIRECTORY
							If ((Test-Path -Path $WIPFullName) -eq $false) {
								New-Item -Item file -Path $WIPFullName -Force | Out-Null
							}
							
							# CREATE CLIENT SIDE WORKING DIRECTORY FOR SCRIPT IF MISSING
							If ((test-path -Path $RemoteShare) -eq $False) {
								New-Item -Path $RemoteShareRoot -name WindowsScriptTemp -ItemType Directory -Force | Out-Null
							}
							
							#region Temp: Remove Old Remote Computer LBTools Directory
					
								If ((Test-Path -Path "$RemoteShareRoot\LBTools") -eq $true) {
									If ((Test-Path -Path "$RemoteShareRoot\LBTools\*.log") -eq $true) {
										Copy-Item -Path "$RemoteShareRoot\LBTools\*.log" -Destination $RemoteShare -Force
									}
									Remove-Item -Path "$RemoteShareRoot\LBTools" -Recurse -Force
								}
					
							#endregion Temp: Remove Old Remote Computer LBTools Directory
							
							#region Temp: Remove Old Remote Computer WindowsScriptsTemp Directory
						
								If ((Test-Path -Path "$RemoteShareRoot\WindowsScriptsTemp") -eq $true) {
									If ((Test-Path -Path "$RemoteShareRoot\WindowsScriptsTemp\*.log") -eq $true) {
										Copy-Item -Path "$RemoteShareRoot\WindowsScriptsTemp\*.log" -Destination $RemoteShare -Force
									}
									Remove-Item -Path "$RemoteShareRoot\WindowsScriptsTemp" -Recurse -Force
								}
						
							#endregion Temp: Remove Old Remote Computer WindowsScriptsTemp Directory
							
							# RENAME History file on remote system from old to new if needed
							$OldHistoryFileFullName = '\\' + $ComputerName + '\c$\WindowsScriptTemp\' + $ComputerName + '_GetDiskSpace_History.log'
							If ((Test-Path -Path $OldHistoryFileFullName) -eq $true) {
								Rename-Item -Path $OldHistoryFileFullName -NewName $HistoryLogFileName -Force
							}
							# RENAME Latest file on remote system from old to new if needed
							$OldHistoryFileFullName = '\\' + $ComputerName + '\c$\WindowsScriptTemp\' + $ComputerName + '_GetDiskSpace_Latest.log'
							If ((Test-Path -Path $OldHistoryFileFullName) -eq $true) {
								Rename-Item -Path $OldHistoryFileFullName -NewName $LatestLogFileName -Force
							}
								
							# WRITE HISTORY LOG HEADER TO LOGARRAY
							$DateTimeF = Get-Date -format g
							$results = $null
							$ScriptLogData = @()
							$ScriptLogData += @(
								'',
								'',
								'*******************************************************************************************************************',
								'*******************************************************************************************************************',
								"JOB STARTED: $DateTimeF",
								"SCRIPT VER:  $ScriptVersion",
								"ADMINUSER:   $UserDomain\$UserName",
								"SCRIPTHOST:  $ScriptHost"
							)
							
						#endregion Start
						
						#region Hard Drive Space Check
							
							## C: DRIVE SPACE CHECK ##
							Get-DiskSpace -ComputerName $ComputerName -SubScripts $SubScripts -MinFreeMB $MinFreeMB
							# Write Results to Logs
							$results = $null
							$results = ($Global:GetDiskSpace | Format-List | Out-String).Trim('')
#							$LogData = $null
							$ScriptLogData += @(
								'',
								'CHECK DRIVE SPACE',
								'------------------',
								"$results"
							)
#							Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogData
							
							If ($Global:GetDiskSpace.Success -eq $true) {
								[string]$FreeSpace = $Global:GetDiskSpace.FreeSpaceMB
								[string]$DriveSize = $Global:GetDiskSpace.DriveSize
							}
							Else {
								[boolean]$Failed = $true
								[string]$ScriptErrors += 'FAILED: Get-DiskSpace  '
								[string]$FreeSpace = 'Error'
								[string]$DriveSize = 'Error'
							}
							
							If ($Global:GetDiskSpace.Passed -eq $true) {
								[boolean]$DiskCheckPassed = $true
							}
							Else {
								[boolean]$DiskCheckPassed = $false
								[string]$ScriptErrors += 'FAILED: Min Disk Space  '
							}

#							[boolean]$diskcheck = $Global:GetDiskSpace.Success
							
						#endregion Hard Drive Space Check
						
						#region Get OS Version
						
							# ^NEED TO ADD ALTCREDS LOGIC
#							If ($SkipAllVmwareBool -eq $true) {
								Get-OSVersion -ComputerName $ComputerName -SubScripts $SubScripts -SkipVimQuery
#							}
#							Else {
#								Get-OSVersion -ComputerName $ComputerName -SubScripts $SubScripts -vCenter $vCenter
#							}
							# WRITE RESULTS TO HISTORY LOGS LOGDATAARRAY
							$results = $null
							[array]$results = ($Global:GetOSVersion | Format-List | Out-String).Trim('')
#							$LogData = $null
							$ScriptLogData += @(
								'',
								'GET OS VERSION',
								'---------------',
								"$results"
							)
#							Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogData
							
							If ($Global:GetOSVersion.Success -eq $true) {
								[string]$OSVersionShortName = $Global:GetOSVersion.OSVersionShortName
								[string]$OSArch = $Global:GetOSVersion.OSArch
								[string]$OSVersion = $Global:GetOSVersion.OSVersion
							}
							Else {
								[string]$OSVersionShortName = 'Error'
								[string]$OSArch = 'Error'
								[string]$OSVersion = 'Error'
							}
							
						#endregion Get OS Version
						
						#region Get Host IP
						
							Get-HostIP -ComputerName $ComputerName -SubScripts $SubScripts -SkipVimQuery
							
							# WRITE RESULTS TO HISTORY LOGS LOGDATAARRAY
							$results = $null
							[array]$results = ($Global:GetHostIP | Format-List | Out-String).Trim('')
							$ScriptLogData += @(
								'',
								'GET HOST IP',
								'------------',
								"$results"
							)
							
							If ($Global:GetHostIP.Success -eq $true) {
								[string]$HostIP = $Global:GetHostIP.HostIP
							}
							Else {
								[string]$HostIP = 'Unknown'
							}
						
						#endregion Get Host IP
						
						#region End
						
							# REMOVE WIP OBJECT FILE
							If ((Test-Path -Path $WIPFullName) -eq $true) {
								Remove-Item -Path $WIPFullName -Force
							}
							Get-Runtime -StartTime $JobStartTime #Results used for History Log Footer too
							
							If ($Failed -eq $false) {
								[boolean]$CompleteSuccess = $true
							}
							Else {
								[boolean]$CompleteSuccess = $false
							}
							
							If (!$ScriptErrors) {
								[string]$ScriptErrors = 'None'
							}
							If (!$OSVersion) {
								[string]$OSVersion = 'Unknown'
							}
							If (!$OSArch) {
								[string]$OSArch = 'Unknown'
							}
							If (!$HostIP) {
								[string]$HostIP = 'Unknown'
							}
							If (($DiskCheckPassed -ne $true) -and ($DiskCheckPassed -ne $false)) {
								[string]$DiskCheckPassed = 'Error'
							}

							
							[string]$TaskResults = $ComputerName + ',' + $CompleteSuccess + ',' + $DiskCheckPassed + ',' + $DriveSize + ',' + $FreeSpace + ',' + $ConnectSuccess + ',' + $OSVersion + ',' + $OSArch + ',' + $HostIP + ',' + $Global:GetRuntime.Runtime + ',' + $JobStartTimeF + ',' + $Global:GetRuntime.EndTimeF + ',' + $ScriptErrors + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName

							[int]$loopcount = 0
							[boolean]$errorfree = $false
							DO {
								$loopcount++
								Try {
									Add-Content -Path $ResultsTextFullName -Encoding Ascii -Value $TaskResults -ErrorAction Stop
									[boolean]$errorfree = $true
								}
								# IF FILE BEING ACCESSED BY ANOTHER SCRIPT CATCH THE TERMINATING ERROR
								Catch [System.IO.IOException] {
									[boolean]$errorfree = $false
									Sleep -Milliseconds 500
									# Could write to ScriptLog which error is caught
								}
								# ANY OTHER EXCEPTION
								Catch {
									[boolean]$errorfree = $false
									Sleep -Milliseconds 500
									# Could write to ScriptLog which error is caught
								}
							}
							# Try until writes to output file or 
							Until (($errorfree -eq $true) -or ($loopcount -ge '150'))
							
							# History Log Footer
							$Runtime = $Global:GetRuntime.Runtime
							$DateTimeF = Get-Date -format g
							$ScriptLogData += @(
								'',
								'',
								'',
								"COMPLETE SUCCESS: $CompleteSuccess",
								'',
								"JOB:             [ENDED] $DateTimeF",
								"Runtime:         $Runtime",
								'---------------------------------------------------------------------------------------------------------------------------------',
								''
							)
							# Write LogDataArray to History Logs
							Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $ScriptLogData
							Out-File -FilePath $LocalLatestLogFullName -Encoding ASCII -Force -InputObject $ScriptLogData
							Out-File -FilePath $RemoteLatestLogFullName -Encoding ASCII -Force -InputObject $ScriptLogData
						
						#endregion End

					} -ArgumentList $ComputerName,$Assets,$SubScripts,$JobLogFullName,$ResultsTextFullName,$ScriptHost,$UserDomain,$UserName,$SubScripts,$LogPath,$ScriptVersion,$MinFreeMB | Out-Null
					
				#endregion Background Job
				
				# PROGRESS COUNTER
				$i++
			} #/Foreach Loop
		
		#endregion Job Loop

		Show-ScriptHeader -blanklines '4' -DashCount $DashCount -ScriptTitle $ScriptTitle
		Show-ScriptStatus-JobsQueued -jobcount $Global:TestConnections.PassedCount
		
	#endregion Job Tasks

	#region Job Monitor

		Get-JobCount
		Set-WinTitle-JobCount -WinTitle_Input $Global:WinTitle_Input -jobcount $Global:getjobcount.JobsRunning
		
		# Job Monitoring Function Will Loop Until Timeout or All are Completed
		Watch-Jobs -SubScripts $SubScripts -JobLogFullName $JobLogFullName -Timeout $JobQueTimeout -Activity "GATHERING DISK SPACE DATA" -WinTitle_Input $Global:WinTitle_Input
		
	#endregion Job Monitor

#endregion Tasks

#region Convert Output Text File to CSV
	
	# Import text file as CSV formated variable - Used for outgrid and CSV file creation
	$outfile = Import-Csv -Delimiter ',' -Path $ResultsTextFullName
	# Create CSV file with CSV formated variable
	$outfile | Export-Csv -Path $ResultsCSVFullName -NoTypeInformation
	# Delete text file if CSV file was created successfully
	If ((Test-Path -Path $ResultsCSVFullName) -eq $true) {
		Remove-Item -Path $ResultsTextFullName -Force
	}

#endregion Convert Output Text File to CSV

#region Script Completion Updates

	Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
	Get-Runtime -StartTime $ScriptStartTime
	Show-ScriptStatus-RuntimeTotals -StartTimeF $ScriptStartTimeF -EndTimeF $Global:GetRuntime.EndTimeF -Runtime $Global:GetRuntime.Runtime
	[int]$TotalHosts = $Global:TestPermissions.PassedCount
	Show-ScriptStatus-TotalHosts -TotalHosts $TotalHosts
	Show-ScriptStatus-Files -ResultsPath $ResultsPath -ResultsFileName $ResultsCSVFileName -LogPath $LogPath
	
	If ($Global:WatchJobs.JobTimeOut -eq $true) {
		Show-ScriptStatus-JobLoopTimeout
		Set-WinTitle-JobTimeout -WinTitle_Input $Global:WinTitle_Input
		
		# Cleanup WIP Files
		Foreach ($ComputerName in $HostList) {
			[string]$WIPPath = Join-Path -Path $LogPath -ChildPath 'WIP' 
			[string]$WIPFullName = Join-Path -Path $WIPPath -ChildPath $ComputerName
			If ((Test-Path -Path $WIPFullName) -eq $true) {
				Remove-Item -Path $WIPFullName -Force
			}
		}
	}
	Else {
		Show-ScriptStatus-Completed
		Set-WinTitle-Completed -WinTitle_Input $Global:WinTitle_Input
	}

#endregion Script Completion Updates

#region Display Report
	
	If ($SkipOutGrid.IsPresent -eq $false) {
		$outfile | Out-GridView -Title "Get Disk Space Results for $InputItem"
	}
	
#endregion Display Report

#region Cleanup UI

	Reset-LBToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts
	
#endregion Cleanup UI

}

#region Notes

<# Dependents
#>

<# Dependencies
	Func_Get-Runtime
	Func_Remove-Jobs
	Func_Get-JobCount
	Func_Get-HostDomain
	Func_Get-HostIP
	Func_Watch-Jobs
	Func_Reset-LBToolsUI
	Func_Show-LBToolsHeader
	Func_Show-ScriptHeader
	MultiFunc_StopWatch
	Func_Test-Connections
	MultiFunc_Set-WinTitle
	MultiFunc_Show-Script-Status
#>

<# TO DO

#>

<# Change Log
1.0.0 - 07/10/2012-07/13/2012
	Created.
1.0.1 - 08/06/2012
	Added Get-OSVersion 1.1.0
	Cleaned up some commented code
	Added MinFreeMB parameter and logic.
	Switched to Test-Connection 1.0.7
1.0.2 - 08/24/2012
	Changed Remote Client Working Directory to WindowsScriptTemp
	Fixed Log output
1.0.3 - 10/22/2012
	Added Host IP lookup
1.0.4 - 11/27/2012
	Removed FileName Parameter
	Changed WindowsScriptsTemp to WindowsScriptTemp
1.0.5 - 12/04/2012
	Removed Job Throttle pause for first group
	Reduced MaxJobs default to see if will solve output issues.
	Switched to Func_Test-Connection 1.0.8
	Changed logic for if all systems fail connection test it will reset the UI
#>


#endregion Notes
