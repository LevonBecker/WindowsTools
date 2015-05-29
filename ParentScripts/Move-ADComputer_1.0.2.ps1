#requires –version 2.0

Function Move-ADComputer {

#region Help

<#
.SYNOPSIS
	Move Active Directory Computer Object to another OU.
.DESCRIPTION
	Move Active Directory Computer Object to another OU.
.NOTES
	VERSION:    1.0.2
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
	%USERPROFILE%\Documents\Results\Move-ADComputer
	
	LOGS
	%USERPROFILE%\Documents\Logs\Move-ADComputer
	+---History
	+---JobData
	+---Latest
	+---WIP
.EXAMPLE
	Move-ADComputer -ComputerName server01 -DomainName domain01 -TargetOU "ou=workstations,cn=domain,cn=com" 
	Patch a single computer.
.EXAMPLE
	Move-ADComputer server01 domain01 -TargetOU "ou=workstations,cn=domain,cn=com" 
	Patch a single computer.
	The ComputerName parameter is in position 0 so it can be left off for a
	single computer.
.EXAMPLE
	Move-ADComputer -List server01,server02 -DomainName domain01 -TargetOU "ou=workstations,cn=domain,cn=com"
	Test a list of hostnames comma separated without spaces.
.EXAMPLE
	Move-ADComputer -List $MyHostList -DomainName domain01 -TargetOU "ou=workstations,cn=domain,cn=com"
	Test a list of hostnames from an already created array variable.
	i.e. $MyHostList = @("server01","server02","server03")
.EXAMPLE
	Move-ADComputer -FileBrowser -DomainName domain01 -TargetOU "ou=workstations,cn=domain,cn=com" 
	This switch will launch a separate file browser window.
	In the window you can browse and select a text or csv file from anywhere
	accessible by the local computer that has a list of host names.
	The host names need to be listed one per line or comma separated.
	This list of system names will be used to perform the script tasks for 
	each host in the list.
.EXAMPLE
	Move-ADComputer -FileBrowser -DomainName domain01 -TargetOU "ou=workstations,cn=domain,cn=com" -SkipOutGrid
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
.PARAMETER DomainName
	FQDN or NETBIOS name of the target domain the computer object is in.
	A specific DC FQDN can be used as well.
.PARAMETER TargetOU
	Full LDAP syntax without spaces for the target location in AD
.LINK
	http://www.bonusbits.com/wiki/HowTo:Use_Windows_Tools_PowerShell_Module
	http://www.bonusbits.com/wiki/HowTo:Enable_.NET_4_Runtime_for_PowerShell_and_Other_Applications
	http://www.bonusbits.com/wiki/HowTo:Setup_PowerShell_Module
	http://www.bonusbits.com/wiki/HowTo:Enable_Remote_Signed_PowerShell_Scripts
#>

#endregion Help

#region Parameters

	[CmdletBinding()]
	Param (
		[parameter(Mandatory=$false,Position=0)][string]$ComputerName,
		[parameter(Mandatory=$false)][array]$List,
		[parameter(Mandatory=$false)][switch]$FileBrowser,
		[parameter(Mandatory=$true,Position=1)][string]$DomainName,
		[parameter(Mandatory=$true,Position=2)][string]$TargetOU,
		[parameter(Mandatory=$false)][int]$MaxJobs = '1', #Can only have a single AD connection?
		[parameter(Mandatory=$false)][int]$JobQueTimeout = '1200', #This timer starts after all jobs have been queued.
		[parameter(Mandatory=$false)][int]$MinFreeMB = '10',
		[parameter(Mandatory=$false)][switch]$SkipOutGrid
	)

#endregion Parameters

#region Top Variables

	If (!$Global:WindowsToolsDefaults) {
		Show-WindowsToolsDefaultsMissingError
	}

	# GET STARTING GLOBAL VARIABLE LIST
	New-Variable -Name StartupVariables -Force -Value (Get-Variable -Scope Global | Select -ExpandProperty Name)
	
	# CAPTURE CURRENT TITLE
	[string]$StartingWindowTitle = $Host.UI.RawUI.WindowTitle

	# DEFAULTS
	[boolean]$filebrowserused = $false
	[string]$HostListPath = ($Global:WindowsToolsDefaults.HostListPath)
	
#endregion Top Variables

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
	[string]$ScriptVersion = '1.0.2'
	[string]$ScriptTitle = "Move AD Computer to Target OU by Levon Becker"
	[int]$DashCount = '45'

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
	[string]$LogPath = ($Global:WindowsToolsDefaults.MoveADComputerLogPath)
	[string]$ScriptLogPath = Join-Path -Path $LogPath -ChildPath 'ScriptLogs'
	[string]$JobLogPath = Join-Path -Path $LogPath -ChildPath 'JobData'
	[string]$ResultsPath = ($Global:WindowsToolsDefaults.MoveADComputerResultsPath)
	
	[string]$ModuleRootPath = $Global:WindowsToolsModulePath
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
			[string]$TimeZone = $Global:GetTimeZone.ShortForm
			[string]$TimeZoneString = "_" + $Global:GetTimeZone.ShortForm
		}
		Else {
			[string]$TimeZoneString = ''
		}
	
	#endregion Determine TimeZone
	
	#region Set Filenames and Paths

	# DIRECTORIES
	[string]$ResultsTempFolder = $FileDateTime + $TimeZoneString + "_($HostInputDesc)"
	[string]$ResultsTempPath = Join-Path -Path $ResultsPath -ChildPath $ResultsTempFolder
	[string]$WIPTempFolder = $FileDateTime + $TimeZoneString + "_($HostInputDesc)"
	[string]$WIPPath = Join-Path -Path $LogPath -ChildPath 'WIP'
	[string]$WIPTempPath = Join-Path -Path $WIPPath -ChildPath $WIPTempFolder
	
	# FILENAMES
	[string]$ResultsTextFileName = "Move-ADComputer_Results_" + $FileDateTime + $TimeZoneString + "_($HostInputDesc).log"
	[string]$ResultsCSVFileName = "Move-ADComputer_Results_" + $FileDateTime + $TimeZoneString + "_($HostInputDesc).csv"
	[string]$JobLogFileName = "JobData_" + $FileDateTime + $TimeZoneString + "_($HostInputDesc).log"

	# PATH + FILENAMES
	[string]$ResultsTextFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsTextFileName
	[string]$ResultsCSVFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsCSVFileName
	[string]$JobLogFullName = Join-Path -Path $JobLogPath -ChildPath $JobLogFileName
	
	#endregion Set Filenames and Paths


#endregion Variables

#region Check Dependencies
	
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

	#region Job Tasks
	
		Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle

		# STOP AND REMOVE ANY RUNNING JOBS
		Stop-Job *
		Remove-Job *
		
		# SHOULD SHOW ZERO JOBS RUNNING
		Get-JobCount 
		Set-WinTitleJobCount -WinTitleInput $Global:WinTitleInput -JobCount $Global:GetJobCount.JobsRunning
		
		# CREATE RESULTS TEMP DIRECTORY
		If ((Test-Path -Path $ResultsTempPath) -ne $true) {
			New-Item -Path $ResultsPath -Name $ResultsTempFolder -ItemType Directory -Force | Out-Null
		}
		
		# CREATE WIP TEMP DIRECTORY
		If ((Test-Path -Path $WIPTempPath) -ne $true) {
			New-Item -Path $WIPPath -Name $WIPTempFolder -ItemType Directory -Force | Out-Null
		}
		
		#region Job Loop
		
			[int]$HostCount = $HostList.Count
			$i = 0
			[boolean]$FirstGroup = $false
			Foreach ($ComputerName in $HostList) {
				$TaskProgress = [int][Math]::Ceiling((($i / $HostCount) * 100))
				# Progress Bar
				Write-Progress -Activity "STARTING MOVE COMPUTER OU JOB ON - ($ComputerName)" -PercentComplete $TaskProgress -Status "OVERALL PROGRESS - $TaskProgress%"
				
				# UPDATE COUNT AND WINTITLE
				Get-JobCount
				Set-WinTitleJobCount -WinTitleInput $Global:WinTitleInput -JobCount $Global:GetJobCount.JobsRunning
				# CLEANUP FINISHED JOBS
				Remove-Jobs -JobLogFullName $JobLogFullName

				#region Throttle Jobs
					
					While ($Global:GetJobCount.JobsRunning -ge $MaxJobs) {
						Sleep -Seconds 5
						Remove-Jobs -JobLogFullName $JobLogFullName
						Get-JobCount
						Set-WinTitleJobCount -WinTitleInput $Global:WinTitleInput -JobCount $Global:GetJobCount.JobsRunning
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
							$ResultsTempPath = $args[5]
							$WIPTempPath = $args[6]
							$Timezone = $args[7]
							$ScriptHost = $args[8]
							$UserDomain = $args[9]
							$UserName = $args[10]
							$LogPath = $args[11]
							$ScriptVersion = $args[12]
							$MinFreeMB = $args[13]
							$TargetOU = $args[14]
							$DomainName = $args[15]
							
							# DATE AND TIME
							$JobStartTimeF = Get-Date -Format g
							$JobStartTime = Get-Date
							
							# NETWORK SHARES
							[string]$RemoteShareRoot = '\\' + $ComputerName + '\C$' 
							[string]$RemoteShare = Join-Path -Path $RemoteShareRoot -ChildPath 'WindowsScriptTemp'
							
							# HISTORY LOG
							[string]$HistoryLogFileName = $ComputerName + '_MoveADComputer_History.log' 
							[string]$LocalHistoryLogPath = Join-Path -Path $LogPath -ChildPath 'History' 
							[string]$RemoteHistoryLogPath = $RemoteShare 
							[string]$LocalHistoryLogFullName = Join-Path -Path $LocalHistoryLogPath -ChildPath $HistoryLogFileName
							[string]$RemoteHistoryLogFullName = Join-Path -Path $RemoteHistoryLogPath -ChildPath $HistoryLogFileName
														
							# LATEST LOG
							[string]$LatestLogFileName = $ComputerName + '_MoveADComputer_Latest.log' 
							[string]$LocalLatestLogPath = Join-Path -Path $LogPath -ChildPath 'Latest' 
							[string]$RemoteLatestLogPath = $RemoteShare 
							[string]$LocalLatestLogFullName = Join-Path -Path $LocalLatestLogPath -ChildPath $LatestLogFileName 
							[string]$RemoteLatestLogFullName = Join-Path -Path $RemoteLatestLogPath -ChildPath $LatestLogFileName
							
							# RESULTS TEMP
							[string]$ResultsTempFileName = $ComputerName + '_Results.log'
							[string]$ResultsTempFullName = Join-Path -Path $ResultsTempPath -ChildPath $ResultsTempFileName

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
									"JOB STARTED: $DateTimeF $TimeZone",
									"SCRIPT VER:  $ScriptVersion",
									"ADMINUSER:   $UserDomain\$UserName",
									"SCRIPTHOST:  $ScriptHost"
								)
							
							#endregion Add Script Log Header
							
						#endregion Setup Files and Folders
						
						#region Gather Remote System Information
						
							#region Get Hard Drive Space
							
								[int]$MinFreeMB = '10'
								# C: DRIVE SPACE CHECK USER ENTERED VALUE
								Get-DiskSpace -ComputerName $ComputerName -MinFreeMB $MinFreeMB
								# ADD RESULTS TO SCRIPT LOG ARRAY
								$Results = $null
								$Results = ($Global:GetDiskSpace | Format-List | Out-String).Trim('')
								$ScriptLogData += @(
									'',
									'GET C: DRIVE SPACE',
									'-------------------',
									"$Results"
								)
								
								# DETERMINE RESULTS
								If ($Global:GetDiskSpace.Success -eq $true) {
									If ($Global:GetDiskSpace.Passed -eq $true) {
										[Boolean]$DiskSpaceOK = $true
									}
									Else {
										[boolean]$Failed = $true
										[boolean]$DiskSpaceOK = $false
										[string]$ScriptErrors += "Less Than Minimum Drive Space. "
									}
									# SET RESULT VARIABLES
#									[string]$FreeSpace = $Global:GetDiskSpace.FreeSpaceMB
#									[string]$DriveSize = $Global:GetDiskSpace.DriveSize
									
									# DETERMINE RESULTS FOR LOG MIN SPACE
									If (($Global:GetDiskSpace.FreeSpaceMB) -ge '5') {
										[boolean]$LogDiskSpaceOK = $true
									}
									Else {
										[boolean]$LogDiskSpaceOK = $false
										[string]$ScriptErrors += "Not Enough Disk Space for Logs. "
									}
								}
								Else {
									[boolean]$DiskSpaceOK = $false
									[boolean]$LogDiskSpaceOK = $false
#									[string]$FreeSpace = 'N/A'
#									[string]$DriveSize = 'N/A'
									[boolean]$Failed = $true
									[string]$ScriptErrors += $Global:GetDiskSpace.Notes
								}
									
							#endregion Get Hard Drive Space
						
						#endregion Gather Remote System Information
						
						#region Main Tasks
						
							#region Move Computer to Target OU
						
								Move-ADComputerOU -ComputerName $ComputerName -DomainName $DomainName -TargetOU $TargetOU -KeepModLoaded
								
								# WRITE RESULTS TO HISTORY LOGS LOGDATAARRAY
								$results = $null
								[array]$results = ($Global:MoveADComputerOU | Format-List | Out-String).Trim('')
								$ScriptLogData += @(
									'',
									'MOVE AD COMPUTER',
									'----------------',
									"$results"
								)
								
								If ($Global:MoveADComputerOU.Success -eq $true) {
									[string]$DNBefore = ($Global:MoveADComputerOU.DNBefore).Trim('').Replace(","," ")
									[string]$DNAfter = ($Global:MoveADComputerOU.DNAfter).Trim('').Replace(","," ")
									[Boolean]$MoveSuccess = $true
								}
								Else {
									[string]$DNBefore = 'Unknown'
									[string]$DNAfter = 'Unknown'
									[Boolean]$MoveSuccess = $false
									[string]$ScriptErrors += 'Move-ADComputerOU Function Failed - '
									[Boolean]$Failed = $true
								}
							
							#endregion Move Computer to Target OU
						
						#endregion Main Tasks
						
						#region Generate Report
						
							#region Set Results if Missing
							
								If (!$ScriptErrors) {
									[string]$ScriptErrors = 'None'
								}
							
							#endregion Set Results if Missing

							#region Output Results to File
							
								Get-Runtime -StartTime $JobStartTime #Results used for History Log Footer too
								[string]$TaskResults = $ComputerName + ',' + $MoveSuccess + ',' + $DNBefore + ',' + $DNAfter + ',' + $Global:GetRuntime.Runtime + ',' + $JobStartTimeF + ' ' + $TimeZone + ',' + $Global:GetRuntime.EndTimeF + ' ' + $TimeZone + ',' + $ScriptErrors + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName

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
									"COMPLETE SUCCESS: $MoveSuccess",
									'',
									"JOB:             [ENDED] $DateTimeF $Timezone",
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

					} -ArgumentList $ComputerName,$Assets,$SubScripts,$JobLogFullName,$ResultsTextFullName,$ResultsTempPath,$WIPTempPath,$Timezone,$ScriptHost,$UserDomain,$UserName,$LogPath,$ScriptVersion,$MinFreeMB,$TargetOU,$DomainName | Out-Null
					
				#endregion Background Job
				
				# PROGRESS COUNTER
				$i++
			} #/Foreach Loop
		
		#endregion Job Loop

		Show-ScriptHeader -blanklines '4' -DashCount $DashCount -ScriptTitle $ScriptTitle
		Show-ScriptStatusJobsQueued -JobCount $TotalHosts
		
	#endregion Job Tasks

	#region Job Monitor

		Get-JobCount
		Set-WinTitleJobCount -WinTitleInput $Global:WinTitleInput -JobCount $Global:GetJobCount.JobsRunning
		
		# Job Monitoring Function Will Loop Until Timeout or All are Completed
		Watch-Jobs -JobLogFullName $JobLogFullName -Timeout $JobQueTimeout -Activity "MOVING COMPUTER OBJECTS" -WinTitleInput $Global:WinTitleInput
		
	#endregion Job Monitor

#endregion Tasks

#region Cleanup WIP

	# GATHER LIST AND CREATE RESULTS FOR COMPUTERNAMES LEFT IN WIP
	If ((Test-Path -Path "$WIPTempPath\*") -eq $true) {
		Get-Runtime -StartTime $ScriptStartTime
		[string]$TimedOutResults = 'False,Unknown,N/A' + ',' + $Global:GetRuntime.Runtime + ',' + $ScriptStartTimeF + ' ' + $TimeZone + ',' + $Global:GetRuntime.EndTimeF + ' ' + $TimeZone + ',' + 'Timed Out' + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName

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
		"Success",
		"DN Before",
		"DN After",
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

	Show-ScriptHeader -BlankLines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
	Get-Runtime -StartTime $ScriptStartTime
	Show-ScriptStatusRuntimeTotals -StartTimeF $ScriptStartTimeF -EndTimeF $Global:GetRuntime.EndTimeF -Runtime $Global:GetRuntime.Runtime
#	[int]$TotalHosts = $Global:TestPermissions.PassedCount
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
		$OutFile | Out-GridView -Title "Move AD Computer Results for $InputItem"
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
	Get-Runtime
	Remove-Jobs
	Get-JobCount
	Watch-Jobs
	Reset-WindowsToolsUI
	Show-WindowsToolsHeader
	Show-ScriptHeader
	Invoke-StopWatch
	Set-WinTitle
	Show-ScriptStatus
	Move-ADComputerOU
	Get-DriveSpace
	ActiveDirectory Module
#>

<# TO DO

#>

<# Change Log
1.0.0 - 10/29/2012
	Created.
1.0.1 - 11/27/2012
	Removed FileName Parameter
	Changed WindowsScriptsTemp to WindowsScriptTemp
1.0.2 - 01/14/2013
	Added DomainName parameter and logic
	Removed Dot sourcing subscripts and load all when module is imported.
	Changed Show-ScriptStatus functions to not have second hypen in name.
	Changed Set-WinTitle functions to not have second hypen in name.
	Removed -SubScript parameter from all subfunction calls.
	Removed dot sourcing subscripts because all are loaded when the module is imported now.
	Removed dependency check for subscripts.
	Added Import WindowsTools Module to Background jobs.
	Removed Runas 32-bit from background jobs.
	Added Timezone argument passthrough to background jobs for logs.
	Added Timezone to result start and end times.
	Changed the way the output logs are wrote to avoid the issue of background jobs
		competing over writing to one file. Now a temp folder is created and each job
		writes it's own results log and then at the end they are all pulled together into
		one final CSV results log.
	Changed the WIP file to go to it's own temp folder just like the results logs.
		This seperates them if multiple instances of the script are ran at the same
		time. Then I can pull the computernames left over if the script times out and
		add them to the results.
	Added StopWatch Subscript at this level and not just in the Watch-Jobs subscript
	Added Start-StopWatch to get full script runtime instead of starting after all the
		jobs are queued once under the throttle limit.  Which then will include the
		time for the Test-Connections section etc.
#>


#endregion Notes
