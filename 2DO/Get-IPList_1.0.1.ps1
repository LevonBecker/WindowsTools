#requires –version 2.0

#region Help

<#
.SYNOPSIS
	Automation Script.
.DESCRIPTION
	Script for automating a process.
.INPUTS
	Items to take action on.
.OUTPUTS
	Log Files.
.NOTES
	TITLE:      Get-HostIP
	VERSION:    1.0.0
	DATE:       02/06/2012
	TEMPLATE:   Check-WSUSClient
	AUTHOR:     Levon Becker
	ENV:        Powershell v2
	TOOLS:      PowerGUI Script Editor, RegexBuddy
.EXAMPLE
	.\Get-HostIP.ps1 -computer SERVER01
.EXAMPLE
	.\Get-HostIP.ps1 -FileName SERVERLIST.TXT
.EXAMPLE
	.\Get-HostIP.ps1 -List server1,server2
	Patch a List of hostnames from an array typed out (Shortnames)
.EXAMPLE
	.\Get-HostIP.ps1 -List $myList 
	Patch a List of hostnames from an already created array variable (Shortname)
.PARAMETER computer
	Short name of Windows host to patch
	Do not use FQDN 
.PARAMETER FileName
	Text or Comma Delimited file with a List of servers to patch
	One host per line
	Do not use FQDN
.PARAMETER List
	A PowerShell array List of servers to patch
	One host per line
	Do not use FQDN
	@(server1,server2) will work as well
.PARAMETER maxjobs
	Maximum background jobs to run simultaneously.
.PARAMETER vCenter
	Vmware vCenter or ViHost Server FQDN.
.PARAMETER wsusserver
	Microsoft WSUS Server FQDN.
.LINK
	https://isinfo.na.sageinternal.com/wiki/
#>

#endregion Help

#region Parameters

	[CmdletBinding()]
	Param (
		[parameter(Mandatory=$false)][string]$computer,
		[parameter(Mandatory=$false)][string]$FileName,
		[parameter(Mandatory=$false)][array]$List,
		[parameter(Mandatory=$false)][string]$vCenter = 'gsvsphere4.gs.adinternal.com',
		[parameter(Mandatory=$false)][int]$maxjobs = '1000', 
		[parameter(Mandatory=$false)][string]$wsusserver = "http://gaqsrvwsus01.gs.adinternal.com"
	)

#endregion Parameters

#region Prompt: Missing Host Input

	If (!($FileName) -and !($computer) -and !($List)) {
		Clear
		$promptitle = ''
		
		$message = "Please Select a Host Entry Method:`n"
		
		# HM = Host Method
		$hmc = New-Object System.Management.Automation.Host.ChoiceDescription "&Computer", `
		    'Enter a single hostname'

		$hmf = New-Object System.Management.Automation.Host.ChoiceDescription "&Textfile", `
		    'Text file name that contains a List of ComputerNames'
		
		$hml = New-Object System.Management.Automation.Host.ChoiceDescription "&List", `
		    'Enter a List of hostnames seperated by a commna without spaces'
		
		$exit = New-Object System.Management.Automation.Host.ChoiceDescription "E&xit", `
		    'Exit Script'

		$options = [System.Management.Automation.Host.ChoiceDescription[]]($hmc, $hmf, $hml, $exit)
		
		$result = $host.ui.PromptForChoice($promptitle, $message, $options, 3) 
		
		# RESET WINDOW TITLE AND BREAK IF EXIT SELECTED
		If ($result -eq 3) {
			Clear
			Break
		}
		Else {
		Switch ($result)
			{
			    0 {$hmoption = 'Computer'} 
			    1 {$hmoption = 'Textfile'}
				2 {$hmoption = 'List'}
			}
		}
		Clear
		
		# PROMPT FOR COMPUTER NAME
		If ($hmoption -eq 'Computer') {
			Write-Host 'Short name of a single host.'
			$computer = $(Read-Host -Prompt 'Enter Computer Name')
		}
		# PROMPT FOR Textfile NAME
		Elseif ($hmoption -eq 'Textfile') {
			Write-Host 'File name that contains a List of hosts to patch.'
			$FileName = $(Read-Host -Prompt 'Enter Textfile Name')
		}
		# PROMPT FOR List 
		Elseif ($hmoption -eq 'List') {
			Write-Host 'Enter a List of hostnames seperated by a comma without spaces to patch.'
			$commaList = $(Read-Host -Prompt 'Enter List')
			# Read-Host only returns String values, so need to split up the hostnames and put into array
			[array]$List = $commaList.Split(',')
		}
		Else {
			Write-Host 'ERROR: Host method entry issue'
			Break
		}
		Clear
	}

#endregion Prompt: Missing Host Input

#region Variables

	# SCRIPT INFO
	[string]$ScriptVersion = '1.0.0'
	[string]$ScriptTitle = "Get Host IP v$ScriptVersion by Levon Becker" # CHANGE

	# CLEAR VARIABLES
	[int]$TotalHosts = 0

	# LOCALHOST
	[string]$ScriptHost = Get-Content Env:\COMPUTERNAME
	[string]$UserDomain = Get-Content Env:\USERDOMAIN
	[string]$UserName = Get-Content Env:\USERNAME
	[string]$FileDateTime = Get-Date -UFormat "%m-%d%-%Y %H.%M.%S"

	# DIRECTORY PATHS
	[string]$scriptdir = 'C:\Scripts\Get-HostIP'
	[string]$PubSubScripts = 'C:\Scripts\_PubSubScripts'
	[string]$logpath = Join-Path -Path $scriptdir -ChildPath 'Logs'
	[string]$ScriptLogpath = Join-Path -Path $logpath -ChildPath 'Scriptlogs'
	[string]$JobLogpath = Join-Path -Path $logpath -ChildPath 'JobData'
	[string]$PrivSubScripts = Join-Path -Path $scriptdir -ChildPath 'Dependencies'
	[string]$PubCMDScripts = Join-Path -Path $PubSubScripts -ChildPath 'CMD'
	[string]$sharedexecpath = Join-Path -Path $PubSubScripts -ChildPath 'Exe'
	[string]$PubPSScripts = Join-Path -Path $PubSubScripts -ChildPath 'PS1'
	[string]$sharedvbspath = Join-Path -Path $PubSubScripts -ChildPath 'VBS'
	[string]$OutputPath = Join-Path -Path $scriptdir -ChildPath 'Output'

	#region  Set Logfile Name + Create HostList Array
	
		If ($computer) {
			[string]$f = $computer
			# Inputitem is also used at end for Outgrid
			[string]$InputItem = $computer.ToUpper() #needed so the WinTitle will be uppercase
			[array]$HostList = $computer.ToUpper()
		}
		ElseIf ($FileName) {
			[string]$f = $FileName
			# Inputitem is also used at end for Outgrid
			[string]$InputItem = $FileName
			[string]$InputFilepath = Join-Path -Path $scriptdir -ChildPath 'Input_Lists'
			[string]$InputFile = Join-Path -Path $InputFilepath -ChildPath $FileName
			If ((Test-Path -Path $InputFile) -ne $true) {
				Write-Host ''
				Write-Host "ERROR: INPUT FILE NOT FOUND ($InputFile)" -ForegroundColor White -BackgroundColor Red
				Write-Host ''
				Break
			}
			[array]$HostList = Get-Content $InputFile
			[array]$HostList = $HostList | ForEach-Object {$_.ToUpper()}
		}
		ElseIF ($List) {
			[array]$List = $List | ForEach-Object {$_.ToUpper()}
			[string]$f = "LIST - " + ($List | Select -First 2) + " ..."
			[string]$InputItem = "LIST: " + ($List | Select -First 2) + " ..."
			[array]$HostList = $List
		}
		Else {
			Write-Host ''
			Write-Host "ERROR: INPUT METHOD NOT FOUND" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			Break
		}
		# Change Hostnames to Upper Case
#		[array]$HostList = $HostList | ForEach-Object {$_.ToUpper()}
		# Remove Duplicates in Array
		[array]$HostList = $HostList | Select -Unique
		[int]$TotalHosts = $HostList.Count
	
	#endregion Set Logfile Name + Create HostList Array

	# FILENAMES
	[string]$FailedAccessLogFile = "Failed_Access_($f)_($FileDateTime).txt"
	[string]$OutputTextLogfile = "Output_($f)_($FileDateTime).txt"
	[string]$OutputCSVLogfile = "Output_($f)_($FileDateTime).csv"
	[string]$ScriptLogfile = "ScriptData_($f)_($FileDateTime).log"
	[string]$JobLogfile = "JobData_($f)_($FileDateTime).log"

	# PATH + FILENAMES
	[string]$FailedAccessLogPath = Join-Path $logpath 'Failed_Access'
	[string]$FailedAccessLog = Join-Path $FailedAccessLogPath $FailedAccessLogFile
	[string]$OutputTextLog = Join-Path -Path $OutputPath -ChildPath $OutputTextLogfile
	[string]$OutputCSVLog = Join-Path -Path $OutputPath -ChildPath $OutputCSVLogfile
	[string]$ScriptLog = Join-Path -Path $ScriptLogpath -ChildPath $ScriptLogfile 
	[string]$JobLog = Join-Path -Path $JobLogpath -ChildPath $JobLogfile
	
	# SET ERROR MAX LIMIT
	$MaximumErrorCount = '1000'

#endregion Variables

#region Check Dependencies
	
	[int]$depmissing = 0
	$depmissingList = $null
	# Create Array of Paths to Dependancies to check
	CLEAR
	$depList = @(
		"$PubPSScripts\Func_Get-Runtime_1.0.2.ps1",
		"$PubPSScripts\Func_ConvertTo-ASCII_1.0.0.ps1",
		"$PubPSScripts\Func_Remove-Jobs_1.0.3.ps1",
		"$PubPSScripts\Func_Get-JobCount_1.0.2.ps1",
		"$PubPSScripts\Func_Get-HostDomain_1.0.1.ps1",
		"$PubPSScripts\Func_Get-HostIP_1.0.3.ps1",
		"$PubPSScripts\Func_Watch-Jobs_1.0.1.ps1",
		"$PubPSScripts\MultiFunc_StopWatch_1.0.0.ps1",
		"$PubPSScripts\Func_Test-Connections_1.0.1.ps1",
		"$PubPSScripts\MultiFunc_Set-WinTitle.ps1",
		"$PubPSScripts\MultiFunc_Out-ScriptLog_1.0.2.ps1",
		"$PubPSScripts\MultiFunc_Show-Script-Status_1.0.1.ps1",
		"$PubPSScripts\Multi_Check-JobLoopScript-Parameters_1.0.0.ps1",
		"$scriptdir",
		"$logpath",
		"$ScriptLogpath",
		"$JobLogpath",
		"$PubSubScripts",
		"$logpath\WIP",
		"$PubPSScripts",
		"$OutputPath",
		"$PrivSubScripts\WUReset.cmd"
	)

	Foreach ($deps in $depList) {
		$checkpath = $false
		$checkpath = Test-Path -Path $deps -ErrorAction SilentlyContinue 
		If ($checkpath -eq $false) {
			$depmissingList += @($deps)
			$depmissing++
		}
	}
	If ($depmissing -gt 0) {
	#	Write-Host ''
		Write-Host "ERROR: Missing $depmissing Dependancies" -ForegroundColor White -BackgroundColor Red
		$depmissingList
		Write-Host ''
		Break
	}

#endregion Check Dependencies

#region Functions

	# LOCAL

	Function Set-Header {
	Clear
	Write-Host $ScriptTitle -ForegroundColor Green
	Write-Host '--------------------------------------------------' -ForegroundColor Green
	Write-Host ''
	}

	# EXTERNAL
	
	. "$PubPSScripts\Func_Get-Runtime_1.0.2.ps1"
	. "$PubPSScripts\Func_Check-Path_1.0.2.ps1"
	. "$PubPSScripts\Func_Remove-Jobs_1.0.3.ps1"
	. "$PubPSScripts\Func_Get-JobCount_1.0.2.ps1"
	. "$PubPSScripts\Func_Watch-Jobs_1.0.1.ps1"
	. "$PubPSScripts\MultiFunc_StopWatch_1.0.0.ps1"
	. "$PubPSScripts\Func_Test-Connections_1.0.1.ps1"
	. "$PubPSScripts\MultiFunc_Set-WinTitle.ps1"
		# Set-WinTitle-Notice
		# Set-WinTitle-Base
		# Set-WinTitle-Input
		# Set-WinTitle-JobCount
		# Set-WinTitle-JobTimeout
		# Set-WinTitle-Completed
	. "$PubPSScripts\MultiFunc_Out-ScriptLog_1.0.2.ps1"
		# Out-ScriptLog-Header
		# Out-ScriptLog-Starttime
		# Out-ScriptLog-JobTimeout
		# Out-ScriptLog-Footer
	. "$PubPSScripts\MultiFunc_Show-Script-Status_1.0.1.ps1"
		# Show-ScriptStatus-StartInfo
		# Show-ScriptStatus-QueuingJobs
		# Show-ScriptStatus-JobsQueued
		# Show-ScriptStatus-JobMonitoring
		# Show-ScriptStatus-JobLoopTimeout
		# Show-ScriptStatus-RuntimeTotals
	. "$PubPSScripts\Multi_Check-JobLoopScript-Parameters_1.0.0.ps1"
		# Check-Parameters-MultipleInputItems
		# Check-Parameters-Logpath
		# Check-Parameters-Inputfile
		# Check-Parameters-Dependancies
	
#endregion Functions

#region Window Title Info Indication

	Set-WinTitle-Notice -title $ScriptTitle
	Set-Header

#endregion Window Title Info Indication

#region Prompt: Test Connection

	$title = ""
	$message = "TEST CONNECTION FIRST?"

	$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
	    "Selecing yes will update the AD Group Policies on the ComputerNames."

	$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
	    "Selecting no will skip updating the AD Group Policies on the ComputerNames"

	$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

	$result = $host.ui.PromptForChoice($title, $message, $options, 0) 

	switch ($result)
	{
	    0 {$testfirst = $true} 
	    1 {$testfirst = $false} 
	}
	Write-Host ""

#endregion Prompt: Test Connection

#region Console Start Statements

	# Get PowerShell Version with External Script
	$dotnetversion = $PSVersionTable.CLRVersion.ToString() #^WIP
	$psversion = $PSVersionTable.PSVersion.ToString()
	Set-WinTitle-Base -psver $psversion -ScriptVersion $ScriptVersion
	[datetime]$ScriptStartTime = Get-Date
	[string]$ScriptStartTimef = Get-Date -Format g
	Show-ScriptStatus-StartInfo -StartTimef $ScriptStartTimef
	Out-ScriptLog-Starttime -StartTime $ScriptStartTimef -ScriptLog $ScriptLog

#endregion Console Start Statements

#region Add Scriptlog Header

	Out-ScriptLog-Header -ScriptLog $ScriptLog -psversion $psversion -ScriptHost $ScriptHost -UserDomain $UserDomain -UserName $UserName

#endregion Add Scriptlog Header

#region Update Window Title

	Set-WinTitle-Input -wintitle_base $global:wintitle_base -InputItem $InputItem
	
#endregion Update Window Title

#region Tasks

	#region Test Connections
	
		If ($testfirst -eq $true) {

			Test-Connections -List $HostList -maxjobs '500' -TestTimeout '60' -JobmonTimeout '900' -PubPSScripts $PubPSScripts -FailedLog $FailedAccessLog -OutputTextLog $OutputTextLog -JobLog $JobLog -TotalHosts $TotalHosts
			If ($global:TestConnections.Success -eq $true) {
				[array]$HostList = $global:TestConnections.PassedList
			}
			Else {
				# IF TEST CONNECTIONS SUBSCRIPT FAILS UPDATE UI AND EXIT SCRIPT
				## This is redundant, but wanted just to have some protection in place for subscript issues.
				Write-Host "`r".padright(40,' ') -NoNewline
				Write-Host "`rERROR: TEST CONNECTIONS FUNCTION FAILURE" -ForegroundColor White -BackgroundColor Red
				Write-Host ''
				Break
			}
		}
		Set-Header

	#endregion Test Connections

	#region Job Tasks

		# STOP AND REMOVE ANY RUNNING JOBS
		Stop-Job *
		Remove-Job * -Force

		Start-Stopwatch 
		Show-ScriptStatus-QueuingJobs
		Show-Stopwatch
		Get-JobCount
		Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount
	
		#Create CSV file with headers
#		Add-Content -Path $OutputTextLog -Encoding ASCII -Value 'Hostname,Complete Success,Runtime,Starttime,Endtime,Operating System,Host IP,Host Domain,Passed Reg Check,WU Server,WU Status Server,Use WU Server,GPO Update Success,WUReset Success,Script Version,Admin Host,User Account'	
		Add-Content -Path $OutputTextLog -Encoding ASCII -Value 'Hostname,Complete Success,Runtime,Starttime,Endtime,Host IP'	

		#region Job Loop
		
			Foreach ($ComputerName in $HostList) {
#				Sleep -Milliseconds 100
				Show-Stopwatch

				## THROTTLE RUNNING JOBS ##
				# Loop Until Less Than Max Jobs Running
				Get-JobCount
				While ($global:getjobcount.JobCount -gt $maxjobs) {
					Show-Stopwatch
					Sleep -Seconds 1
					Remove-Jobs -JobLog $JobLog
					Get-JobCount
					Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount
				}
				
				# Set Job Start Time Used for Elapsed Time Calculations at End ^Needed Still?
				[string]$jobStartTime1 = Get-Date -Format g
				Add-Content -Path $ScriptLog -Encoding ASCII -Value "JOB STARTED:     ($ComputerName) $jobStartTime1"
				
				#region Background Job

					Start-Job -ScriptBlock {

						#region Job Variables

						# Set Varibles from Argument List
						$ComputerName = $args[0]
						$ScriptLog = $args[1]
						$JobLog = $args[2] 
						$PubPSScripts = $args[3]
						$sharedexecpath = $args[4]
						$OutputTextLog = $args[5]
						$ScriptHost = $args[6]
						$UserDomain = $args[7]
						$UserName = $args[8]
						$PrivSubScripts = $args[9]
						$logpath = $args[10]
						$vCenter = $args[11]
						$ScriptVersion = $args[12]
						$wsusserver = $args[13]

						$testcount = 1
						
						# DATE AND TIME
#						$day = Get-Date -uformat "%m-%d-%Y"
						$jobStartTimef = Get-Date -Format g
						$jobStartTime = Get-Date
						
						# NETWORK SHARES
						[string]$ComputerNameshareroot = '\\' + $ComputerName + '\C$' 
						[string]$ComputerNameshare = Join-Path $ComputerNameshareroot 'Windows-Patching'
						
						# HISTORY LOG
#						[string]$historyfile = $ComputerName + '_WSUSCheck.log' 
#						[string]$adminhistorypath = Join-Path -Path $logpath -ChildPath 'History' 
#						[string]$ComputerNamehistorypath = $ComputerNameshare 
#						[string]$adminhistorylog = Join-Path -Path $adminhistorypath -ChildPath $historyfile
#						[string]$ComputerNamehistorylog = Join-Path -Path $ComputerNamehistorypath -ChildPath $historyfile
						
						# LATEST LOG
#						[string]$latestfile = $ComputerName + '_LastPatch.log' 
#						[string]$adminlatestpath = Join-Path -Path $logpath -ChildPath 'Latest' 
#						[string]$ComputerNamelatestpath = $ComputerNameshare 
#						[string]$adminlatestlog = Join-Path -Path $adminlatestpath -ChildPath $latestfile 
#						[string]$ComputerNamelatestlog = Join-Path -Path $ComputerNamelatestpath -ChildPath $latestfile 

						# TEMP WORK IN PROGRESS PATH
						[string]$wippath = Join-Path -Path $logpath -ChildPath 'WIP' 
						[string]$wip = Join-Path -Path $wippath -ChildPath $ComputerName
						
						# SCRIPTS
#						[string]$updatewufile = "WUReset.cmd"
#						[string]$ComputerNameupdatewu = Join-Path -Path $ComputerNameshare -ChildPath $updatewufile
#						[string]$adminupdatewu = Join-Path -Path $PrivSubScripts -ChildPath $updatewufile
#						[string]$psexec = Join-Path -Path $sharedexecpath -ChildPath 'PsExec.exe'
						
						# SET INITIAL JOB SCOPE VARIBLES
						[string]$failed = $false
						[string]$completesuccess = $false
						[string]$connectfailed = $false
						[string]$wuserver = 'Unknown'
						[string]$wustatusserver = 'Unknown'
						[string]$usewuserver = 'Unknown'
						[string]$gpoupdatesuccess = 'Not Selected'
						[string]$wuresetsuccess = 'Not Selected'
						[string]$ostype = 'Unknown'
						[string]$hostip = 'Unknown'
						[string]$hostdomain = 'Unknown'
						

						#endregion Job Variables

						#region Job Functions
						
#						. "$PubPSScripts\Func_Get-RegValue_1.0.4.ps1"
						. "$PubPSScripts\Func_Get-Runtime_1.0.2.ps1"
#						. "$PubPSScripts\Func_ConvertTo-ASCII_1.0.0.ps1"
#						. "$PubPSScripts\Func_Get-HostDomain_1.0.1.ps1"
						. "$PubPSScripts\Func_Get-HostIP_1.0.3.ps1"
#						. "$PubPSScripts\Func_Get-OSVersion_1.0.6.ps1"
						. "$PubPSScripts\MultiFunc_Out-ScriptLog_1.0.2.ps1"
							# Out-ScriptLog-Header
							# Out-ScriptLog-Starttime
							# Out-ScriptLog-Error
							# Out-ScriptLog-JobTimeout
							# Out-ScriptLog-Footer	
						

						#endregion Job Functions
						
						#region Convert Client PatchHistory File to ASCII
					
							# Temporary Step to fix existing Client Patch History Logs that got encoded as Unicode by old versions of script.
							# ^Remove or set a condition (Test if Ascii)
#							If ((Test-Path -Path $ComputerNamehistorylog) -eq $true) {
#								ConvertTo-ASCII -path $ComputerNamehistorylog
#							}
						
						#endregion Convert Client PatchHistory File to ASCII
						
						#region Start
						
							# CREATE WIP TRACKING FILE IN WIP DIRECTORY
							If ((Test-Path -Path $wip) -eq $false) {
								New-Item -Item file -Path $wip -Force | Out-Null
							}
							
							# CREATE CLIENT PATCH DIRECTORY FOR SCRIPTS IF MISSING
#							If ((test-path -Path $ComputerNameshare) -eq $False) {
#								New-Item -Path $ComputerNameshareroot -name Windows-Patching -ItemType directory -Force | Out-Null
#							}
							
							# WRITE START INFO TO HISTORY LOGS
#							$datetime = Get-Date -format g
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value ''
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value ''
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value '*******************************************************************************************************************'
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value '*******************************************************************************************************************'
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value "JOB STARTED: $datetime"
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value "SCRIPT VER:  $ScriptVersion"
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value "ADMINUSER:   $UserDomain\$UserName"
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value "ADMINHOST:   $ScriptHost"
							
	#						Write-Logs-JobStart -adminhistorylog $adminhistorylog -ComputerNamehistorylog $ComputerNamehistorylog -adminlatestlog $adminlatestlog -ScriptVersion $ScriptVersion -JobLog $JobLog -UserDomain $UserDomain -UserName $UserName -ScriptHost $ScriptHost -jobStartTime $jobStartTime -ComputerName $ComputerName
	#						Set-WinTitle-FileList-Testcount -wintitle_base $global:wintitle_base -rootfile $rootfile -fileList $fileList -testcount $testcount
						
						#endregion Start
						
						#region Get OS Version
						
#							Get-OSVersion -ComputerName $ComputerName -vCenter $vCenter
#							# WRITE RESULTS TO HISTORY LOG
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value ''
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value 'GET OS VERSION'
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value '---------------'
#							Out-File -FilePath $adminhistorylog -Encoding ASCII -InputObject $global:GetOSVersion -Append
#							Out-File -FilePath $ComputerNamehistorylog -Encoding ASCII -InputObject $global:GetOSVersion -Append
#							If ($global:GetHostDomain.Success -eq $true) {
#								[string]$ostype = $global:GetOSVersion.OSType
#							}
#							Else {
#								[string]$ostype = 'Error'
#							}
							
							
						#endregion Get OS Version
						
						#region Get Host Domain
						
#							Get-HostDomain -ComputerName $ComputerName -vCenter $vCenter
#							# WRITE RESULTS TO HISTORY LOG
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value ''
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value 'GET HOST DOMAIN'
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value '---------------'
#							Out-File -FilePath $adminhistorylog -Encoding ASCII -InputObject $global:GetHostDomain -Append
#							Out-File -FilePath $ComputerNamehistorylog -Encoding ASCII -InputObject $global:GetHostDomain -Append
#							If ($global:GetHostDomain.Success -eq $true) {
#								[string]$hostdomain = $global:GetHostDomain.HostDomain
#							}
#							Else {
#								[string]$hostdomain = 'Error'
#							}
							
						#endregion Get Host Domain
						
						#region Get HOST IP
						
							Get-HostIP -ComputerName $ComputerName -vCenter $vCenter
							# WRITE RESULTS TO HISTORY LOG
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value ''
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value 'GET HOST IP'
#							Add-Content -Path $adminhistorylog,$ComputerNamehistorylog -Encoding ASCII -Value '------------'
#							Out-File -FilePath $adminhistorylog -Encoding ASCII -InputObject $global:GetHostIP -Append
#							Out-File -FilePath $ComputerNamehistorylog -Encoding ASCII -InputObject $global:GetHostIP -Append
							If ($global:GetHostIP.Success -eq $true) {
								[string]$hostip = $global:GetHostIP.HostIP
							}
							Else {
								[string]$hostip = 'Error'
								$failed = $true
							}
							
						#endregion Get HOST IP
						
						#region End
						
							# REMOVE WIP OBJECT FILE
							If ((Test-Path -Path $wip) -eq $true) {
								Remove-Item -Path $wip -Force
							}
							Get-Runtime -StartTime $jobStartTime					
#							Write-Logs-JobEnd -jobStartTime $jobStartTime -PubSubScripts $PubSubScripts	-adminlatestlog $adminlatestlog	-ComputerNamehistorylog $ComputerNamehistorylog -ScriptLog $ScriptLog -FailedLog $FailedLog	-patchingFailedLog $patchingFailedLog -connectFailedLog $connectFailedLog -rebootFailedLog $rebootFailedLog	-completesuccesslog $completesuccesslog -RunTime $global:GetRunTime.Runtime
							
							If ($failed -eq $false) {
								[string]$completesuccess = $true
							}
							Else {
								[string]$completesuccess = $false
							}
#							If ($global:GetOSVersion.Success -eq $true) {
#								[string]$osver = $global:GetOSVersion.OSVersion
#							}
#							Else {
#								[string]$osver = 'Unknown'
#							}
#							[string]$outstring = $ComputerName + ',' + $completesuccess + ',' + $global:GetRunTime.Runtime + ',' + $jobStartTimef + ',' + $global:GetRunTime.Endtimef + ',' + $osver + ',' + $hostip + ',' + $hostdomain + ',' + $passedregaudit + ',' + $wuserver + ',' + $wustatusserver + ',' + $usewuserver + ',' + $gpoupdatesuccess + ',' + $wuresetsuccess + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName
							[string]$outstring = $ComputerName + ',' + $completesuccess + ',' + $global:GetRunTime.Runtime + ',' + $jobStartTimef + ',' + $global:GetRunTime.Endtimef + ',' + $hostip + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName

							[int]$loopcount = 0
							[string]$errorfree = $false
							DO {
								$loopcount++
								Try {
									Add-Content -Path $OutputTextLog -Encoding Ascii -Value $outstring -ErrorAction Stop
									$errorfree = $true
								}
								# IF FILE BEING ACCESSED BY ANOTHER SCRIPT CATCH THE TERMINATING ERROR
								Catch [System.IO.IOException] {
									$errorfree = $false
									Sleep -Milliseconds 100
									# Could write to ScriptLog which error is caught
								}
								# ANY OTHER EXCEPTION
								Catch {
									$errorfree = $false
									Sleep -Milliseconds 100
									# Could write to ScriptLog which error is caught
								}
							}
							# Try until writes to output file or 
							Until (($errorfree -eq $true) -or ($loopcount -ge '150'))
						
						#endregion End

					} -ArgumentList $ComputerName,$ScriptLog,$JobLog,$PubPSScripts,$sharedexecpath,$OutputTextLog,$ScriptHost,$UserDomain,$UserName,$PrivSubScripts,$logpath,$vCenter,$ScriptVersion | Out-Null
					
				#endregion Background Job
				
				# REFRESH UI JOB COUNT AND RUNTIME AS EACH JOB LOADS
				Show-Stopwatch
				Get-JobCount
				Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount

			} #/Foreach Loop
		
		#endregion Job Loop

		Stop-Stopwatch
		Set-Header 
#		Get-JobCount
#		Show-ScriptStatus-JobsQueued -jobcount $global:getjobcount.JobCount
		Show-ScriptStatus-JobsQueued -jobcount $global:TestConnections.PassedCount
		
	#endregion Job Tasks

	#region Job Monitor

#		Show-ScriptStatus-JobMonitoring -hostmethod $hostmethod
		Get-JobCount
		Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount
		
		# Job Monitoring Function Will Loop Until Timeout or All are Completed
		Watch-Jobs -JobLog $JobLog -PubPSScripts $PubPSScripts -timeout '900' -wintitle_input $global:wintitle_input
		
	#endregion Job Monitor

#endregion Tasks

#region Convert Output Text File to CSV
	
	# Import text file as CSV formated variable - Used for outgrid and CSV file creation
	$outfile = Import-Csv -Delimiter ',' -Path $OutputTextLog
	# Create CSV file with CSV formated variable
	$outfile | Export-Csv -Path $OutputCSVLog -NoTypeInformation
	# Delete text file if CSV file was created successfully
	If ((Test-Path -Path $OutputCSVLog) -eq $true) {
		Remove-Item -Path $OutputTextLog -Force
	}

#endregion Convert Output Text File to CSV

#region Script Completion Updates

	Set-Header 
#	[string]$scriptEndTimef = Get-Date -Format g
	Get-Runtime -StartTime $ScriptStartTime
	Show-ScriptStatus-RuntimeTotals -StartTimef $ScriptStartTimef -EndTimef $global:GetRunTime.Endtimef -RunTime $global:GetRunTime.Runtime
	[int]$TotalHosts = $global:TestPermissions.PassedCount
	Show-ScriptStatus-TotalHosts -TotalHosts $TotalHosts
	If ($global:WatchJobs.JobTimeOut -eq $true) {
		Out-ScriptLog-JobTimeout -ScriptLog $ScriptLog -JobmonNotes $global:WatchJobs.Notes -EndTime $global:GetRunTime.Endtime -RunTime $global:GetRunTime.Runtime
		Show-ScriptStatus-JobLoopTimeout
		Set-WinTitle-JobTimeout -wintitle_input $global:wintitle_input
	}
	Else {
		Out-ScriptLog-Footer -EndTime $global:GetRunTime.Endtime -RunTime $global:GetRunTime.Runtime -ScriptLog $ScriptLog
		Show-ScriptStatus-Completed
		Set-WinTitle-Completed -wintitle_input $global:wintitle_input
	}

#endregion Script Completion Updates

#region Display Report

	$outfile | Out-GridView -Title "Windows Patching Results for $InputItem"

#endregion Display Report

#region Notes

<# Dependents
	None
#>

<# Dependencies
	Func_Get-Runtime
	Func_Get-HostIP
	Func_Cleanup_Jobs
	Func_Get-JobCount
	Func_Watch-Jobs
	MultiFunc_StopWatch
	MultiFunc_Set-WinTitle
		# Set-WinTitle-Notice
		# Set-WinTitle-Base
		# Set-WinTitle-Input
		# Set-WinTitle-JobCount
		# Set-WinTitle-JobTimeout
		# Set-WinTitle-Completed
	MultiFunc_Out-ScriptLog
		# Out-ScriptLog-Header
		# Out-ScriptLog-Starttime
		# Out-ScriptLog-JobTimeout
		# Out-ScriptLog-Footer
	MultiFunc_Show-Script-Status
		# Show-ScriptStatus-StartInfo
		# Show-ScriptStatus-QueuingJobs
		# Show-ScriptStatus-JobsQueued
		# Show-ScriptStatus-JobMonitoring
		# Show-ScriptStatus-JobLoopTimeout
		# Show-ScriptStatus-RuntimeTotals
	Multi_Check-JobLoopScript-Parameters
		# Check-Parameters-MultipleInputItems
		# Check-Parameters-Logpath
		# Check-Parameters-Inputfile
		# Check-Parameters-Dependancies
#>

<# TO DO
	1. Clean up commented stuff not needed
#>

<# Change Log
	1.0.0 - 02/06/2012
		Created.
#>


#endregion Notes
