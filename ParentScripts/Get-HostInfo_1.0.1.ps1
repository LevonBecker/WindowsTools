#requires –version 2.0

Function Get-HostInfo {

#region Help

<#
.SYNOPSIS
	Automation Script.
.DESCRIPTION
	Script for automating a process.
.NOTES
	VERSION:    1.0.1
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
	%USERPROFILE%\Documents\Results\Get-HostInfo
	
	LOGS
	%USERPROFILE%\Documents\Logs\Get-HostInfo
	+---History
	+---JobData
	+---Latest
	+---WIP
.EXAMPLE
	Get-HostInfo -ComputerName server01 
	Patch a single computer.
.EXAMPLE
	Get-HostInfo server01 
	Patch a single computer.
	The ComputerName parameter is in position 0 so it can be left off for a
	single computer.
.EXAMPLE
	Get-HostInfo -List server01,server02
	Test a list of hostnames comma separated without spaces.
.EXAMPLE
	Get-HostInfo -List $MyHostList 
	Test a list of hostnames from an already created array variable.
	i.e. $MyHostList = @("server01","server02","server03")
.EXAMPLE
	Get-HostInfo -FileBrowser 
	This switch will launch a separate file browser window.
	In the window you can browse and select a text or csv file from anywhere
	accessible by the local computer that has a list of host names.
	The host names need to be listed one per line or comma separated.
	This list of system names will be used to perform the script tasks for 
	each host in the list.
.EXAMPLE
	Get-HostInfo -FileBrowser -SkipOutGrid
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
.LINK
	http://wiki.bonusbits.com/main/PSScript:Get-HostInfo
	http://wiki.bonusbits.com/main/PSModule:WindowsTools
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
		[parameter(Mandatory=$false)][int]$MaxJobs = '200', 
		[parameter(Mandatory=$false)][int]$JobQueTimeout = '600', #This timer starts after all jobs have been queued.
		[parameter(Mandatory=$false)][int]$MinFreeMB = '2000',
		[parameter(Mandatory=$false)][switch]$SkipOutGrid
	)

#endregion Parameters

	If (!$Global:WindowsToolsDefaults) {
		Show-WindowsToolsDefaultsMissingError
	}

	# GET STARTING GLOBAL VARIABLE LIST
	New-Variable -Name StartupVariables -Force -Value (Get-Variable -Scope Global | Select -ExpandProperty Name)
	
	# CAPTURE CURRENT TITLE
	[string]$StartingWindowTitle = $Host.UI.RawUI.WindowTitle

	# PATHS NEEDED AT TOP
	[string]$ModuleRootPath = $Global:WindowsToolsModulePath
	[string]$SubScripts = Join-Path -Path $ModuleRootPath -ChildPath 'SubScripts'
	[string]$HostListPath = ($Global:WindowsToolsDefaults.HostListPath)

#region Prompt: Host Input

	#region Prompt: FileBrowser
	
		If ($FileBrowser.IsPresent -eq $true) {
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
				Reset-WindowsToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SkipPrompt
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
				Clear
				Write-Host ''
				Write-Host 'SELECT FILE CONTAINING A LIST OF HOSTS TO PATCH.'
				Get-FileName -InitialDirectory $HostListPath -Filter "Text files (*.txt)|*.txt|Comma Delimited files (*.csv)|*.csv|All files (*.*)|*.*"
				[string]$FileName = $Global:GetFileName.FileName
				[string]$HostListFullName = $Global:GetFileName.FullName
			}
			Else {
				Clear
				Write-Host 'ERROR: Host method entry issue'
				Reset-WindowsToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables
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
	[string]$ScriptVersion = '1.0.1'
	[string]$ScriptTitle = "Get Host Information by Levon Becker"
	[int]$DashCount = '35'

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
	[string]$LogPath = ($Global:WindowsToolsDefaults.GetHostInfoLogPath)
	[string]$ScriptLogPath = Join-Path -Path $LogPath -ChildPath 'ScriptLogs'
	[string]$JobLogPath = Join-Path -Path $LogPath -ChildPath 'JobData'
	[string]$ResultsPath = ($Global:WindowsToolsDefaults.GetHostInfoResultsPath)
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
					Clear
					Write-Host ''
					Write-Host "ERROR: INPUT FILE NOT FOUND ($HostListFullName)" -ForegroundColor White -BackgroundColor Red
					Write-Host ''
					Reset-WindowsToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables
					Break
			}
			[array]$HostList = Get-Content $HostListFullName
			[array]$HostList = $HostList | ForEach-Object {$_.ToUpper()}
		}
		Else {
			Clear
			Write-Host ''
			Write-Host "ERROR: INPUT METHOD NOT FOUND" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			Reset-WindowsToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables
			Break
		}
		# Remove Duplicates in Array + Get Host Count
		[array]$HostList = $HostList | Select -Unique
		[int]$TotalHosts = $HostList.Count
	
	#endregion Set Logfile Name + Create HostList Array
	
	#region Determine TimeZone
	
		Get-TimeZone -ComputerName 'Localhost'
		
		If (($Global:GetTimeZone.Success -eq $true) -and ($Global:GetTimeZone.ShortForm -ne '')) {
			[string]$TimeZone = "_" + $Global:GetTimeZone.ShortForm
		}
		Else {
			[string]$Timezone = ''
		}
	
	#endregion Determine TimeZone
	
	#region Set Filenames and Paths

	# DIRECTORIES
	[string]$ResultsTempFolder = $FileDateTime + $Timezone + "_($HostInputDesc)"
	[string]$ResultsTempPath = Join-Path -Path $ResultsPath -ChildPath $ResultsTempFolder
	[string]$WIPTempFolder = $FileDateTime + $Timezone + "_($HostInputDesc)"
	[string]$WIPPath = Join-Path -Path $LogPath -ChildPath 'WIP'
	[string]$WIPTempPath = Join-Path -Path $WIPPath -ChildPath $WIPTempFolder

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
	$MissingDependencyList = $null
	# Create Array of Paths to Dependancies to check
	CLEAR
	$DependencyList = @(
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

	[array]$MissingDependencyList = @()
	Foreach ($Dependency in $DependencyList) {
		[boolean]$CheckPath = $false
		$CheckPath = Test-Path -Path $Dependency -ErrorAction SilentlyContinue 
		If ($CheckPath -eq $false) {
			$MissingDependencyList += $Dependency
		}
	}
	$MissingDependencyCount = ($MissingDependencyList.Count)
	If ($MissingDependencyCount -gt 0) {
		Clear
		Write-Host ''
		Write-Host "ERROR: Missing $MissingDependencyCount Dependencies" -ForegroundColor White -BackgroundColor Red
		Write-Host ''
		$MissingDependencyList
		Write-Host ''
		Reset-WindowsToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables
		Break
	}

#endregion Check Dependencies

#region Show Window Title

	Set-WinTitleStart -title $ScriptTitle
	Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
	Add-StopWatch
	Start-Stopwatch

#endregion Show Window Title

#region Console Start Statements
	
	Show-ScriptHeader -blanklines '4' -DashCount $DashCount -ScriptTitle $ScriptTitle
	Set-WinTitleBase -ScriptVersion $ScriptVersion 
	[datetime]$ScriptStartTime = Get-Date
	[string]$ScriptStartTimeF = Get-Date -Format g

#endregion Console Start Statements

#region Update Window Title

	Set-WinTitleInput -WinTitleBase $Global:WinTitleBase -InputItem $InputItem
	
#endregion Update Window Title

#region Tasks

	#region Test Connections

		Test-Connections -List $HostList -MaxJobs '25' -TestTimeout '120' -JobmonTimeout '600' -ResultsTextFullName $ResultsTextFullName -JobLogFullName $JobLogFullName -TotalHosts $TotalHosts -DashCount $DashCount -ScriptTitle $ScriptTitle -WinTitleInput $Global:WinTitleInput
		If ($Global:TestConnections.AllFailed -eq $true) {
			# IF TEST CONNECTIONS SUBSCRIPT FAILS UPDATE UI AND EXIT SCRIPT
			Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
			Write-Host "`r".padright(40,' ') -NoNewline
			Write-Host "`rERROR: ALL SYSTEMS FAILED PERMISSION TEST" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			Reset-WindowsToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables
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
			Reset-WindowsToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables
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
		Set-WinTitleJobCount -WinTitleInput $Global:WinTitleInput -jobcount $Global:getjobcount.JobsRunning
	
		# CREATE RESULTS TEMP DIRECTORY
		If ((Test-Path -Path $ResultsTempPath) -ne $true) {
			New-Item -Path $ResultsPath -Name $ResultsTempFolder -ItemType Directory -Force | Out-Null
		}
		
		# CREATE RESULT TEMP FILE FOR FAILED SYSTEMS
		If ($Global:TestConnections.FailedCount -gt '0') {
			Get-Runtime -StartTime $ScriptStartTime
			[string]$FailedConnectResults = 'False,Unknown,Unknown,Unknown,False,Unknown,Unknown,Unknown,Unknown' + ',' + $Global:GetRuntime.Runtime + ',' + $ScriptStartTimeF + ',' + $Global:GetRuntime.EndTimeF + ',' + 'Failed Connection' + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName
			Foreach ($FailedComputerName in ($Global:TestConnections.FailedList)) {
				[string]$ResultsTempFileName = $FailedComputerName + '_Results.log'
				[string]$ResultsTempFullName = Join-Path -Path $ResultsTempPath -ChildPath $ResultsTempFileName
				[string]$ResultsContent = $FailedComputerName + ',' + $FailedConnectResults
				Out-File -FilePath $ResultsTempFullName -Encoding ASCII -InputObject $ResultsContent
			}
		}
		
		#region Job Loop
		
			[int]$HostCount = $HostList.Count
			$i = 0
#			[boolean]$FirstGroup = $false
			Foreach ($ComputerName in $HostList) {
				$TaskProgress = [int][Math]::Ceiling((($i / $HostCount) * 100))
				# Progress Bar
				Write-Progress -Activity "STARTING DISK SPACE CHECK JOB ON - ($ComputerName)" -PercentComplete $TaskProgress -Status "OVERALL PROGRESS - $TaskProgress%"
				
				# UPDATE COUNT AND WINTITLE
				Get-JobCount
				Set-WinTitleJobCount -WinTitleInput $Global:WinTitleInput -jobcount $Global:getjobcount.JobsRunning
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
						Set-WinTitleJobCount -WinTitleInput $Global:WinTitleInput -jobcount $Global:getjobcount.JobsRunning
					}
				
				#endregion Throttle Jobs
				
				# Set Job Start Time Used for Elapsed Time Calculations at End ^Needed Still?
				[string]$JobStartTime1 = Get-Date -Format g
				
				#region Background Job

					Start-Job -ScriptBlock {

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
							$ResultsTempPath = $args[12]
							$WIPTempPath = $args[13]

							$testcount = 1
							
							# DATE AND TIME
							$JobStartTimeF = Get-Date -Format g
							$JobStartTime = Get-Date
							
							# NETWORK SHARES
							[string]$RemoteShareRoot = '\\' + $ComputerName + '\C$' 
							[string]$RemoteShare = Join-Path -Path $RemoteShareRoot -ChildPath 'WindowsScriptTemp'
							
							# HISTORY LOG
							[string]$HistoryLogFileName = $ComputerName + '_GetHostInfo_History.log' 
							[string]$LocalHistoryLogPath = Join-Path -Path $LogPath -ChildPath 'History' 
							[string]$RemoteHistoryLogPath = $RemoteShare 
							[string]$LocalHistoryLogFullName = Join-Path -Path $LocalHistoryLogPath -ChildPath $HistoryLogFileName
							[string]$RemoteHistoryLogFullName = Join-Path -Path $RemoteHistoryLogPath -ChildPath $HistoryLogFileName
														
							# LATEST LOG
							[string]$LatestLogFileName = $ComputerName + '_GetHostInfo_Latest.log' 
							[string]$LocalLatestLogPath = Join-Path -Path $LogPath -ChildPath 'Latest' 
							[string]$RemoteLatestLogPath = $RemoteShare 
							[string]$LocalLatestLogFullName = Join-Path -Path $LocalLatestLogPath -ChildPath $LatestLogFileName 
							[string]$RemoteLatestLogFullName = Join-Path -Path $RemoteLatestLogPath -ChildPath $LatestLogFileName

							# RESULTS TEMP
							[string]$ResultsTempFileName = $ComputerName + '_Results.log'
							[string]$ResultsTempFullName = Join-Path -Path $ResultsTempPath -ChildPath $ResultsTempFileName
							
							# SET INITIAL JOB SCOPE VARIBLES
							[boolean]$Failed = $false
							[boolean]$CompleteSuccess = $false
							[Boolean]$ConnectSuccess = $true

						#endregion Job Variables

						#region Load Sub Functions
						
							Import-Module -Name WindowsTools -ArgumentList $true
						
						#endregion Load Sub Functions
						
						#region Setup Files and Folders
						
							#region Create WIP File
							
								If ((Test-Path -Path "$WIPTempPath\$ComputerName") -eq $false) {
									New-Item -Item file -Path "$WIPTempPath\$ComputerName" -Force | Out-Null
								}
							
							#endregion Create WIP File
						
							#region Create Remote Temp Folder
							
								If ((Test-Path -Path $RemoteShare) -eq $False) {
									New-Item -Path $RemoteShareRoot -name WindowsScriptTemp -ItemType Directory -Force | Out-Null
								}
							
							#endregion Create Remote Temp Folder
							
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
							
							#region Add Script Log Header
							
								$DateTimeF = Get-Date -format g
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
							
							#endregion Add Script Log Header
							
						#endregion Setup Files and Folders
						
						#region Gather Remote System Information
						
							#region Get Hard Drives
							
								# C: DRIVE SPACE CHECK USER ENTERED VALUE
								Get-HardDrives -ComputerName $ComputerName -MinFreeMB $MinFreeMB
								# ADD RESULTS TO SCRIPT LOG ARRAY
								$Results = $null
								$Results = ($Global:GetHardDrives | Format-List | Out-String).Trim('')
								$ScriptLogData += @(
									'',
									'GET HARD DRIVES',
									'----------------',
									"$Results"
								)
								
								# DETERMINE RESULTS
								If ($Global:GetHardDrives.Success -eq $true) {
									If ($Global:GetHardDrives.Passed -eq $true) {
										[Boolean]$DiskSpaceOK = $true
									}
									Else {
										[boolean]$Failed = $true
										[boolean]$DiskSpaceOK = $false
										[string]$ScriptErrors += "Less Than Minimum Drive Space "
									}
									# SET RESULT VARIABLES
									[string]$SystemDriveFree = $Global:GetHardDrives.SystemDriveFree
									[string]$SystemDriveSize = $Global:GetHardDrives.SystemDriveSize
									[string]$AllHardDrives = $Global:GetHardDrives.AllHardDrives
									[string]$DriveCount = $Global:GetHardDrives.DriveCount
									
									# DETERMINE RESULTS FOR LOG MIN SPACE
									If (($Global:GetHardDrives.SystemDriveFree) -ge '5') {
										[boolean]$LogDiskSpaceOK = $true
									}
									Else {
										[boolean]$LogDiskSpaceOK = $false
										[string]$ScriptErrors += "Not Enough Disk Space for Logs "
									}
								}
								Else {
									[boolean]$DiskSpaceOK = $false
									[boolean]$LogDiskSpaceOK = $false
									[string]$SystemDriveFree = 'N/A'
									[string]$SystemDriveSize = 'N/A'
									[boolean]$Failed = $true
									[string]$ScriptErrors += $Global:GetHardDrives.Notes
								}
									
							#endregion Get Hard Drives
						
							#region Get OS
							
								# ^NEED TO ADD ALTCREDS LOGIC
								Get-OS -ComputerName $ComputerName -SkipVimQuery
								# ADD RESULTS TO SCRIPT LOG ARRAY
								$Results = $null
								[array]$Results = ($Global:GetOS | Format-List | Out-String).Trim('')
								$ScriptLogData += @(
									'',
									'GET OS VERSION',
									'---------------',
									"$Results"
								)
								If ($Global:GetOS.Success -eq $true) {
									[string]$OSVersionShortName = $Global:GetOS.OSVersionShortName
									[string]$OSArchitecture = $Global:GetOS.OSArchitecture
									[string]$OSVersion = $Global:GetOS.OSVersion
									[string]$OSType = $Global:GetOS.OSType
									[string]$OSServicePack = $Global:GetOS.OSServicePack
									[string]$WindowsDirectory = $Global:GetOS.WindowsDirectory
									[string]$LastBootUpTime = $Global:GetOS.LastBootUpTime
									[string]$Uptime = $Global:GetOS.Uptime
									[string]$FreePhysicalMemoryMB = $Global:GetOS.FreePhysicalMemoryMB
									[string]$FreeVirtualMemoryMB = $Global:GetOS.FreeVirtualMemoryMB
									[string]$PageFiles = $Global:GetOS.PageFiles
								}
								Else {
									[string]$OSVersionShortName = 'Error'
									[string]$OSArchitecture = 'Error'
									[string]$OSVersion = 'Error'
									[string]$OSType = 'Error'
									[string]$OSServicePack = 'Error'
									[string]$WindowsDirectory = 'Error'
									[string]$LastBootUpTime = 'Error'
									[string]$Uptime = 'Error'
									[string]$FreePhysicalMemoryMB = 'Error'
									[string]$FreeVirtualMemoryMB = 'Error'
									[string]$PageFiles = 'Error'
								}
								
								
							#endregion Get OS
							
							#region Get Domain
								
								Get-Domain -ComputerName $ComputerName -SkipVimQuery
								# ADD RESULTS TO SCRIPT LOG ARRAY
								$Results = $null
								[array]$Results = ($Global:GetDomain | Format-List | Out-String).Trim('')
								$ScriptLogData += @(
									'',
									'GET HOST DOMAIN',
									'----------------',
									"$Results"
								)
								If ($Global:GetDomain.Success -eq $true) {
									[string]$HostDomain = $Global:GetDomain.HostDomain
								}
								Else {
									[string]$HostDomain = 'Error'
								}
								
							#endregion Get Domain
							
							#region Get Network
								
								Get-Network -ComputerName $ComputerName -SkipVimQuery
								# ADD RESULTS TO SCRIPT LOG ARRAY
								$Results = $null
								[array]$Results = ($Global:GetNetwork | Format-List | Out-String).Trim('')
								$ScriptLogData += @(
									'',
									'GET HOST IP',
									'------------',
									"$Results"
								)
								If ($Global:GetNetwork.Success -eq $true) {
									[string]$IPAddresses = $Global:GetNetwork.IPAddresses
								}
								Else {
									[string]$IPAddresses = 'Error'
								}
								
							#endregion Get Network
							
							#region Check Pending Reboot
						
								Get-PendingReboot -ComputerName $ComputerName
								If ($Global:GetPendingReboot.Success -eq $true) {
									[string]$PendingReboot = $Global:GetPendingReboot.Pending
								}
								Else {
									$Failed = $true
									[string]$PendingReboot = 'Error'
								}
								
							#endregion Check Pending Reboot
							
							#region Get Hardware
						
								Get-Hardware -ComputerName $ComputerName -vCenter $vCenter
								If ($Global:GetHardware.Success -eq $true) {
									[string]$Manufacturer = $Global:GetHardware.Manufacturer
									[string]$Model = $Global:GetHardware.Model
									[string]$Platform = $Global:GetHardware.Platform
									[string]$BootupState = $Global:GetHardware.BootupState
									[string]$NumberOfProcessors = $Global:GetHardware.NumberOfProcessors
									[string]$NumberOfLogicalProcessors = $Global:GetHardware.NumberOfLogicalProcessors
									[string]$TotalPhysicalMemoryMB = $Global:GetHardware.TotalPhysicalMemoryMB
									[string]$ProcessorName = $Global:GetHardware.ProcessorName
								}
								Else {
									$Failed = $true
									[string]$Make = 'Error'
									[string]$Model = 'Error'
									[string]$Platform = 'Error'
									[string]$BootupState = 'Error'
									[string]$NumberOfProcessors = 'Error'
									[string]$NumberOfLogicalProcessors = 'Error'
									[string]$TotalPhysicalMemoryMB = 'Error'
									[string]$ProcessorName = 'Error'
								}
								
							#endregion Get Hardware
							
							#region Get Pending Patches
									
								Get-PendingPatches -ComputerName $ComputerName
								If ($Global:getpendingpatches.Success -eq $true) {
									[int]$patchcount = $Global:getpendingpatches.PendingCount
								}
								Else {
									$Failed = $true
									[string]$patchcount = 'Error'
								}
								
							#endregion Get Pending Patches
								
							#region Get EPO Version
							
								Get-EPOVersion -ComputerName $ComputerName
								If ($Global:getepoversion.Success -eq $true) {
									[string]$epoversion = $Global:getepoversion.EPOVersion
								}
								Else {
									$Failed = $true
									[string]$epoversion = 'Error'
								}
								
							#endregion Get EPO Version
							
							#region Get VSE Version
							
								Get-VSEVersion -ComputerName $ComputerName
								If ($Global:getvseversion.Success -eq $true) {
									[string]$vseversion = $Global:getvseversion.VSEVersion
								}
								Else {
									$Failed = $true
									[string]$vseversion = 'Error'
								}
								
							#endregion Get VSE Version
						
							#region Get NBU Version
							
								Get-NBUVersion -ComputerName $ComputerName
								If ($Global:getnbuversion.Success -eq $true) {
									[string]$nbuversion = $Global:getnbuversion.NBUVersion
								}
								Else {
									$Failed = $true
									[string]$nbuversion = 'Error'
								}
								
							#endregion Get NBU Version		
							
							#region Get WU Info
							
								Get-WUInfo -ComputerName $ComputerName
								If ($Global:GetWUInfo.Success -eq $true) {
									[string]$wuserver = $Global:GetWUInfo.WUServer
									[string]$wustatusserver = $Global:GetWUInfo.WUStatusServer #^Not used yet
									[string]$wuserverok = $Global:GetWUInfo.WUServerOK #^Not used yet
								}
								Else {
									$Failed = $true
									[string]$wuserver = 'Error'
									[string]$wustatusserver = 'Error'
									[string]$wuserverok = 'Error'
								}
								
							#endregion Get Get WU Info							
						
						#endregion Gather Remote System Information
						
						#region Generate Report
						
							#region Determine Results
								
								If ($Failed -eq $false) {
									[boolean]$CompleteSuccess = $true
								}
								Else {
									[boolean]$CompleteSuccess = $false
								}
							
							#endregion Determine Results
							
							#region Set Results if Missing
							
								If (!$ScriptErrors) {
									[string]$ScriptErrors = 'None'
								}
								If (!$OSVersion) {
									[string]$OSVersion = 'Unknown'
								}
								If (!$OSArchitecture) {
									[string]$OSArchitecture = 'Unknown'
								}
								If (!$IPAddresses) {
									[string]$IPAddresses = 'Unknown'
								}
#								If (($DiskSpaceOK -ne $true) -and ($DiskSpaceOK -ne $false)) {
#									[string]$DiskSpaceOK = 'Error'
#								}
								
							#endregion Set Results if Missing
							
							#region Output Results to File
							
								Get-Runtime -StartTime $JobStartTime #Results used for History Log Footer too
								[string]$TaskResults = $ComputerName + ',' + $CompleteSuccess + ',' + $ConnectSuccess + ',' + $Location + ',' + $OSVersion + ',' + $OSArchitecture + ',' + $OSServicePack + ',' + $WindowsDirectory + ',' + $NICCount + ',' + $VLANS + ',' + $IPAddresses + ',' + $MACAddresses + ',' + $HostDomain + ',' + $HardDriveCount + ',' + $AllHardDrives + ',' + $SystemDriveFree + ',' + $NumberOfLogicalProcessors + ',' + $NumberOfProcessors + ',' + $ProcessorName + ',' + $TotalPhysicalMemory + ',' + $FreePhysicalMemoryMB + ',' + $FreeVirtualMemoryMB + ',' + $PageFiles + ',' + $Manufacturer + ',' + $Model + ',' + $BootupState + ',' + $LastBootUpTime + ',' + $Uptime + ',' + $LastLogon + ',' + $PendingReboot + ',' + $PendingPatches + ',' + $Global:GetRuntime.Runtime + ',' + $JobStartTimeF + ' ' + $TimeZone + ',' + $Global:GetRuntime.EndTimeF + ' ' + $TimeZone + ',' + $ScriptErrors + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName

								[int]$LoopCount = 0
								[boolean]$ErrorFree = $false
								DO {
									$LoopCount++
									Try {
										Out-File -FilePath $ResultsTempFullName -Encoding ASCII -InputObject $TaskResults -ErrorAction Stop
										[boolean]$ErrorFree = $true
									}
									# IF FILE BEING ACCESSED BY ANOTHER SCRIPT CATCH THE TERMINATING ERROR
									Catch [System.IO.IOException] {
										[boolean]$ErrorFree = $false
										Sleep -Milliseconds 500
										# Could write to ScriptLog which error is caught
									}
									# ANY OTHER EXCEPTION
									Catch {
										[boolean]$ErrorFree = $false
										Sleep -Milliseconds 500
										# Could write to ScriptLog which error is caught
									}
								}
								# Try until writes to output file or 
								Until (($ErrorFree -eq $true) -or ($LoopCount -ge '150'))
							
							#endregion Output Results to File
							
							#region Add Script Log Footer
							
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
								
							#endregion Add Script Log Footer
							
							#region Write Script Logs
							
								If ($LogDiskSpaceOK -eq $true) {
									Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $ScriptLogData
									Out-File -FilePath $LocalLatestLogFullName -Encoding ASCII -Force -InputObject $ScriptLogData
									Out-File -FilePath $RemoteLatestLogFullName -Encoding ASCII -Force -InputObject $ScriptLogData
								}
								Else {
									Add-Content -Path $LocalHistoryLogFullName -Encoding ASCII -Value $ScriptLogData
									Out-File -FilePath $LocalLatestLogFullName -Encoding ASCII -Force -InputObject $ScriptLogData
								}
							
							#endregion Write Script Logs
							
						#endregion Generate Report
						
						#region Remove WIP File
						
							If ((Test-Path -Path "$WIPTempPath\$ComputerName") -eq $true) {
								Remove-Item -Path "$WIPTempPath\$ComputerName" -Force
							}
						
						#endregion Remove WIP File

					} -ArgumentList $ComputerName,$Assets,$SubScripts,$JobLogFullName,$ResultsTextFullName,$ScriptHost,$UserDomain,$UserName,$SubScripts,$LogPath,$ScriptVersion,$MinFreeMB,$ResultsTempPath,$WIPTempPath | Out-Null
					
				#endregion Background Job
				
				# PROGRESS COUNTER
				$i++
			} #/Foreach Loop
		
		#endregion Job Loop

		Show-ScriptHeader -blanklines '4' -DashCount $DashCount -ScriptTitle $ScriptTitle
		Show-ScriptStatusJobsQueued -jobcount $Global:TestConnections.PassedCount
		
	#endregion Job Tasks

	#region Job Monitor

		Get-JobCount
		Set-WinTitleJobCount -WinTitleInput $Global:WinTitleInput -jobcount $Global:getjobcount.JobsRunning
		
		# Job Monitoring Function Will Loop Until Timeout or All are Completed
		Watch-Jobs -JobLogFullName $JobLogFullName -Timeout $JobQueTimeout -Activity "GATHERING DISK SPACE DATA" -WinTitleInput $Global:WinTitleInput
		
	#endregion Job Monitor

#endregion Tasks

#region Cleanup WIP

	# GATHER LIST AND CREATE RESULTS FOR COMPUTERNAMES LEFT IN WIP
	If ((Test-Path -Path "$WIPTempPath\*") -eq $true) {
		Get-Runtime -StartTime $ScriptStartTime
		[string]$TimedOutResults = 'False,Unknown,Unknown,Unknown,True,Unknown,Unknown,Unknown,Unknown' + ',' + $Global:GetRuntime.Runtime + ',' + $ScriptStartTimeF + ' ' + $TimeZone + ',' + $Global:GetRuntime.EndTimeF + ' ' + $TimeZone + ',' + 'Timed Out' + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName

		$TimedOutComputerList = @()
		$TimedOutComputerList += Get-ChildItem -Path "$WIPTempPath\*"
		Foreach ($TimedOutComputerObject in $TimedOutComputerList) {
			[string]$TimedOutComputerName = $TimedOutComputerObject | Select-Object -ExpandProperty Name
			[string]$ResultsContent = $TimedOutComputerName + ',' + $TimedOutResults
			[string]$ResultsFileName = $TimedOutComputerName + '_Results.log'
			Out-File -FilePath "$ResultsTempPath\$ResultsFileName" -Encoding ASCII -InputObject $ResultsContent
			Remove-Item -Path ($TimedOutComputerObject.FullName) -Force
		}
	}
	
	# REMOVE WIP TEMP DIRECTORY
	If ((Test-Path -Path $WIPTempPath) -eq $true) {
			Remove-Item -Path $WIPTempPath -Force -Recurse
	}

#endregion Cleanup WIP

#region Convert Output Text Files to CSV

	# CREATE RESULTS CSV
	[array]$Header = @(
		"Hostname",
		"Complete Success",
		"Connected",
		"Location",
		"Operating System",
		"OS Arch",
		"Service Pack",
		"WindowsDirectory",
		"NIC Count",
		"VLANS",
		"IP Addresses",
		"MAC Addresses",
		"Host Domain",
		"HD Count",
		"Hard Drives",
		"C: Free (MB)",
		"CPU Count",
		"CPU Core Count",
		"CPU Type",
		"Memory (MB)",
		"Free Memory (MB)",
		"Free Virtual Memory (MB)",
		"PageFiles",
		"Manufacturer",
		"Model",
		"BootupState",
		"LastBootTime",
		"Uptime (DHM)",
		"LastLogon",
#		"WU Server",
#		"WSUS Group",
#		"Last WSUS Sync",
#		"MA Agent",
#		"VSE Client",
#		"DAT Version",
#		"DAT Date",
#		"NBU Client",
#		"Marimba",
#		"PatchLink",
#		"BUE Client",
#		"SQL Version",
		"Pending Reboot",
		"Pending Patches",
		"Runtime",
		"Starttime",
		"Endtime",
		"Errors",
		"Script Version",
		"Admin Host",
		"User Account"
	)
	[array]$OutFile = @()
	[array]$ResultFiles = Get-ChildItem -Path $ResultsTempPath
	Foreach ($FileObject in $ResultFiles) {
		[array]$OutFile += Import-Csv -Delimiter ',' -Path $FileObject.FullName -Header $Header
	}
	$OutFile | Export-Csv -Path $ResultsCSVFullName -NoTypeInformation -Force

	# DELETE TEMP FILES AND DIRECTORY
	## IF CSV FILE WAS CREATED SUCCESSFULLY THEN DELETE TEMP
	If ((Test-Path -Path $ResultsCSVFullName) -eq $true) {
		If ((Test-Path -Path $ResultsTempPath) -eq $true) {
			Remove-Item -Path $ResultsTempPath -Force -Recurse
		}
	}

#endregion Convert Output Text Files to CSV

#region Script Completion Updates

	Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
	Get-Runtime -StartTime $ScriptStartTime
	Show-ScriptStatusRuntimeTotals -StartTimeF $ScriptStartTimeF -EndTimeF $Global:GetRuntime.EndTimeF -Runtime $Global:GetRuntime.Runtime
	[int]$TotalHosts = $Global:TestPermissions.PassedCount
	Show-ScriptStatusTotalHosts -TotalHosts $TotalHosts
	Show-ScriptStatusFiles -ResultsPath $ResultsPath -ResultsFileName $ResultsCSVFileName -LogPath $LogPath
	
	If ($Global:WatchJobs.JobTimeOut -eq $true) {
		Show-ScriptStatusJobLoopTimeout
		Set-WinTitleJobTimeout -WinTitleInput $Global:WinTitleInput
	}
	Else {
		Show-ScriptStatusCompleted
		Set-WinTitleCompleted -WinTitleInput $Global:WinTitleInput
	}

#endregion Script Completion Updates

#region Display Report
	
	If ($SkipOutGrid.IsPresent -eq $false) {
		$OutFile | Out-GridView -Title "Get Disk Space Results for $InputItem"
	}
	
#endregion Display Report

#region Cleanup UI

	Reset-WindowsToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables
	
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
	Func_Get-NetworkInfo
	Func_Watch-Jobs
	Func_Reset-WindowsToolsUI
	Func_Show-WindowsToolsHeader
	Func_Show-ScriptHeader
	MultiFunc_StopWatch
	Func_Test-Connections
	MultiFunc_Set-WinTitle
	MultiFunc_Show-Script-Status
#>

<# TO DO

#>

<# Change Log
1.0.0 - 12/27/2012
	Created.
#>


#endregion Notes
