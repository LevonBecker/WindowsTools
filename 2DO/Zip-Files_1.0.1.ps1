#requires –version 2.0

#region Notes

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
	TITLE:      Zip-Files
	VERSION:    1.0.0
	DATE:       12/30/2011
	TEMPLATE:   1.0.9
	AUTHOR:     Levon Becker
	ENV:        Powershell v2
	TOOLS:      PowerGUI Script Editor, RegexBuddy
.EXAMPLE
	./Script.ps1 -computer SERVER01
.EXAMPLE
	./Script.ps1 -file SERVERLIST.TXT
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

<# Dependents

	None

#>

<# Dependencies

	Func_Get-Runtime_1.0.2.ps1
	Func_Check-Path_1.0.2.ps1
	Func_Cleanup_Jobs_1.0.0.ps1
	Func_Get-JobCount_1.0.2.ps1
	Func_Get-PSVersion_1.0.1.ps1
	Func_Watch-Jobs_1.0.1.ps1
	MultiFunc_StopWatch_1.0.0.ps1
	MultiFunc_Set-WinTitle.ps1
		# Set-WinTitle-Notice
		# Set-WinTitle-Base
		# Set-WinTitle-Input
		# Set-WinTitle-JobCount
		# Set-WinTitle-JobTimeout
		# Set-WinTitle-Completed
	MultiFunc_Out-ScriptLog_1.0.2.ps1
		# Out-ScriptLog-Header
		# Out-ScriptLog-Starttime
		# Out-ScriptLog-JobTimeout
		# Out-ScriptLog-Footer
	MultiFunc_Show-Script-Status_1.0.1.ps1
		# Show-ScriptStatus-StartInfo
		# Show-ScriptStatus-QueuingJobs
		# Show-ScriptStatus-JobsQueued
		# Show-ScriptStatus-JobMonitoring
		# Show-ScriptStatus-JobLoopTimeout
		# Show-ScriptStatus-RuntimeTotals
	Multi_Check-JobLoopScript-Parameters_1.0.0.ps1
		# Check-Parameters-MultipleInputItems
		# Check-Parameters-Logpath
		# Check-Parameters-Inputfile
		# Check-Parameters-Dependancies
		
#>

<# Sources

	Info Name
		http://

#>

<# Change Log

	1.0.0 - 12/30/2011
		Created.

	
#>


#endregion Notes

#region Parameters

	[CmdletBinding()]
	Param (
		[parameter(Mandatory=$false)][string]$computer,
		[parameter(Mandatory=$false)][string]$FileName,
		[parameter(Mandatory=$false)][array]$List,
		[parameter(Mandatory=$false)][string]$vCenter = 'gsvsphere4.gs.adinternal.com',
		[parameter(Mandatory=$false)][int]$maxjobs = '10', 
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
	[string]$ScriptTitle = "Zip-Files v$ScriptVersion by Levon Becker" # CHANGE

	# CLEAR VARIABLES
	[int]$TotalHosts = 0

	# LOCALHOST
	[string]$currenthost = Get-Content Env:\COMPUTERNAME
	[string]$UserDomain = Get-Content Env:\USERDOMAIN
	[string]$UserName = Get-Content Env:\USERNAME
	[string]$FileDateTime = Get-Date -UFormat "%m-%d%-%Y %H.%M.%S"
#	[string]$originaltitle = 'Windows PowerShell'

	# DIRECTORY PATHS
	[string]$scriptdir = 'C:\Scripts\Zip-Files'
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
			[string]$f = $List
			[string]$InputItem = $List
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
	[string]$failedfile = "Failed_($f)_($FileDateTime).txt"
	[string]$OutputTextLogfile = "Output_($f)_($FileDateTime).txt"
	[string]$OutputCSVLogfile = "Output_($f)_($FileDateTime).csv"
	[string]$ScriptLogfile = "ScriptData_($f)_($FileDateTime).log"
	[string]$JobLogfile = "JobData_($f)_($FileDateTime).log"

	# PATH + FILENAMES
	[string]$failedpath = Join-Path -Path $logpath -ChildPath 'Failed'
	[string]$FailedLog = Join-Path -Path $failedpath -ChildPath $failedfile
	[string]$OutputTextLog = Join-Path -Path $OutputPath -ChildPath $OutputTextLogfile
	[string]$OutputCSVLog = Join-Path -Path $OutputPath -ChildPath $OutputCSVLogfile
	[string]$ScriptLog = Join-Path -Path $ScriptLogpath -ChildPath $ScriptLogfile 
	[string]$JobLog = Join-Path -Path $JobLogpath -ChildPath $JobLogfile

#endregion Variables

#region Check Dependencies
	
	# Create Array of Paths to Dependancies to check
	CLEAR
	$depList = @(
		"$PubPSScripts\Func_Get-Runtime_1.0.2.ps1",
		"$PubPSScripts\Func_Cleanup_Jobs_1.0.0.ps1",
		"$PubPSScripts\Func_Get-JobCount_1.0.2.ps1",
		"$PubPSScripts\Func_Watch-Jobs_1.0.1.ps1",
		"$PubPSScripts\MultiFunc_StopWatch_1.0.0.ps1",
		"$PubPSScripts\MultiFunc_Set-WinTitle.ps1",
		"$PubPSScripts\MultiFunc_Out-ScriptLog_1.0.2.ps1",
		"$PubPSScripts\MultiFunc_Show-Script-Status_1.0.1.ps1",
		"$PubPSScripts\Multi_Check-JobLoopScript-Parameters_1.0.0.ps1",
		"$PubPSScripts\Func_Add-HostToLogFile_1.0.3.ps1",
		"$scriptdir",
		"$logpath",
		"$ScriptLogpath",
		"$JobLogpath",
		"$PubSubScripts",
		"$logpath\WIP",
		"$logpath\Failed",
		"$PubPSScripts",
		"$OutputPath"
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
	
	. "$PubPSScripts\Func_Add-HostToLogFile_1.0.3.ps1"
	. "$PubPSScripts\Func_Get-Runtime_1.0.2.ps1"
	. "$PubPSScripts\Func_Check-Path_1.0.2.ps1"
	. "$PubPSScripts\Func_Cleanup_Jobs_1.0.0.ps1"
	. "$PubPSScripts\Func_Get-JobCount_1.0.2.ps1"
	. "$PubPSScripts\Func_Watch-Jobs_1.0.1.ps1"
	. "$PubPSScripts\MultiFunc_StopWatch_1.0.0.ps1"
	. "$PubPSScripts\Func_Test-Permissions_1.0.7.ps1"
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

	Out-ScriptLog-Header -ScriptLog $ScriptLog

#endregion Add Scriptlog Header


#region Update Window Title

	Set-WinTitle-Input -wintitle_base $global:wintitle_base -InputItem $InputItem
	
#endregion Update Window Title


#region Tasks

	#region Test Permissions

			# Run Permission Test on each host
			Write-Host 'TESTING CLIENT PERMISSIONS' -ForegroundColor Yellow -NoNewline
			Sleep -Seconds 2
			Test-Permissions -arrayList $HostList -maxjobs $maxjobs

			# Add Hostname to Failed Logs if any
			If ($global:TestPermissions.FailedCount -gt '0') {
				$global:TestPermissions.FailedList | Foreach-Object {Add-HostToLogFile -ComputerName $_ -logfile $FailedLog}
				$global:TestPermissions.FailedList | Foreach-Object {Add-HostToLogFile -ComputerName $_ -logfile $connectFailedLog}
			}

			# If all failed; error and bail
			If ($global:TestPermissions.AllFailed -eq $true) {
				Write-Host "`r".padright(40,' ') -NoNewline
				Write-Host "`rERROR: ALL SYSTEMS FAILED PERMISSION TEST" -ForegroundColor White -BackgroundColor Red
				Write-Host ''
				# Remove empty output file before stopping script
				# ^Probably need more cleanup if going to break here
				If ((Test-Path -Path $OutputTextLog) -eq $true) {
					Remove-Item -Path $OutputTextLog -Force
				}
				Break
			}

			# If some but not all failed; then remove failed and continue.
			If ($global:TestPermissions.PartialPassed -eq $true) {
				Write-Host "`r".padright(40,' ') -NoNewline
				Write-Host "`rCONNECTION ERROR TO THE FOLLOWING SYSTEMS" -ForegroundColor White -BackgroundColor Red
				Write-Host '-----------------------------------------'
				$global:TestPermissions.FailedList | select
				Write-Host '-----------------------------------------'
				Write-Host ''

				#region Prompt to Continue

					$title = ''
					$message = 'REMOVE ABOVE LIST OF HOSTS AND CONTINUE?'

					$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
					    'Continue with patching the available ComputerNames in the List.'

					$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
					    'Stop the script.'

					$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

					$result = $host.ui.PromptForChoice($title, $message, $options, 0) 

					switch ($result)
					{
					    0 {$keepgoing = 'Yes'} 
					    1 {$keepgoing = 'No'} 
					}
					If ($keepgoing -eq 'No') {
						Write-Host ''
						Break
					}
				
				#endregion Prompt to Continue
			}

			# If all passed then update host console and continue.
			If ($global:TestPermissions.AllPassed -eq $true) {
				Write-Host "`r".padright(40,' ') -NoNewline
				Write-Host "`rPASSED PERMISSIONS TEST" -ForegroundColor Green -NoNewline
				Sleep -Seconds 2
			}

			Set-Header

		#endregion Test Permissions

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
		Add-Content -Path $OutputTextLog -Encoding ASCII -Value 'Hostname,Starttime,Endtime,Runtime,Complete Success,Admin Host,Admin'	
		
		$HostList = $global:TestPermissions.PassedList
		
		#region Job Loop
		
			Foreach ($ComputerName in $HostList) {

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
						$OutputTextLog = $args[4]

						$testcount = 1

						#endregion Job Variables

						#region Job Functions
						
						#. "$PubPSScripts\Func_Check-Path_1.0.2.ps1"

						#endregion Job Functions
						
						Write-Logs-JobStart -adminhistorylog $adminhistorylog -ComputerNamehistorylog $ComputerNamehistorylog -adminlatestlog $adminlatestlog -ScriptVersion $ScriptVersion -JobLog $JobLog -UserDomain $UserDomain -UserName $UserName -ScriptHost $ScriptHost -jobStartTime $jobStartTime -ComputerName $ComputerName
						Set-WinTitle-FileList-Testcount -wintitle_base $global:wintitle_base -rootfile $rootfile -fileList $fileList -testcount $testcount
						
						#region Job Task 1

							#	$processes = Get-Process -ComputerName $ComputerName
							#	$proccount = $processes.count
							#	Add-Content -Path $OutputTextLog -Value "$ComputerName,$proccount"

						#endregion Job Task 1
						
						Get-Runtime -StartTime $jobStartTime					
						Write-Logs-JobEnd -jobStartTime $jobStartTime -PubSubScripts $PubSubScripts	-adminlatestlog $adminlatestlog	-ComputerNamehistorylog $ComputerNamehistorylog -ScriptLog $ScriptLog -FailedLog $FailedLog	-patchingFailedLog $patchingFailedLog -connectFailedLog $connectFailedLog -rebootFailedLog $rebootFailedLog	-completesuccesslog $completesuccesslog -RunTime $global:GetRunTime.Runtime
						
						If ($failed -eq $false) {
							$completesuccess = $true
						}
						Else {
							$completesuccess = $false
						}
						$outstring = $ComputerName + ',' + $jobStartTime + ',' + $global:GetRunTime.Endtime + ',' + $global:GetRunTime.Runtime + ',' + $completesuccess + ',' + $currenthost + ',' + $UserName
						Add-Content -Path $OutputTextLog -Encoding Ascii -Value $outstring

					} -ArgumentList $ComputerName,$ScriptLog,$JobLog,$PubPSScripts,$OutputTextLog | Out-Null
					
				#endregion Background Job
					
				Show-Stopwatch
				Get-JobCount
				Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount

			} #/Foreach Loop
		
		#endregion Job Loop

		Stop-Stopwatch
		Set-Header 
		Get-JobCount 
		Show-ScriptStatus-JobsQueued -jobcount $global:getjobcount.JobCount
		
	#endregion Job Tasks

	#region Job Monitor

		Show-ScriptStatus-JobMonitoring -hostmethod $hostmethod
		Get-JobCount
		Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount
		
		# Job Monitoring Function Will Loop Until Timeout or All are Completed
		Watch-Jobs -JobLog $JobLog -PubPSScripts $PubPSScripts -timeout '3600' -wintitle_input $global:wintitle_input
		
		Set-Header 
		
		# Job Timeout Condition to End Script and Update UI
		If ($global:jobmonresults -eq $false) {
			Out-ScriptLog-JobTimeout -ScriptLog $ScriptLog
			Get-Runtime -StartTime $jobStartTime
			Show-ScriptStatus-RuntimeTotals -StartTimef $StartTimef
			Show-ScriptStatus-JobLoopTimeout
			Set-WinTitle-JobTimeout -wintitle_input $global:wintitle_input
			Return
		} #/If still jobs after timeout
		Else {
	#			Set-WinTitle-Input -wintitle_base $global:wintitle_base -InputItem $computer
		}
		
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
	[string]$scriptEndTimef = Get-Date -Format g
	Get-Runtime -StartTime $ScriptStartTime
	Out-ScriptLog-Footer -EndTime $global:GetRunTime.Endtime -RunTime $global:GetRunTime.Runtime -ScriptLog $ScriptLog
	Show-ScriptStatus-RuntimeTotals -StartTimef $ScriptStartTimef -EndTimef $global:GetRunTime.Endtimef -RunTime $global:GetRunTime.Runtime
	[int]$TotalHosts = $global:TestPermissions.PassedCount
	Show-ScriptStatus-TotalHosts -TotalHosts $TotalHosts
	Show-ScriptStatus-Completed
	Set-WinTitle-Completed -wintitle_input $global:wintitle_input

#endregion Script Completion Updates

#region Display Report

	$outfile | Out-GridView -Title "Windows Patching Results for $InputItem"

#endregion Display Report
