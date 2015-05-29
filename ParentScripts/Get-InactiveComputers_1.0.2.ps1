#requires –version 2.0

Function Get-InactiveComputers {

#region Help

<#
.SYNOPSIS
	Get list of AD Computer Objects that are inactive.
.DESCRIPTION
	Get list of AD Computer Objects that are inactive.
.NOTES
	VERSION:    1.0.2
	AUTHOR:     Levon Becker
	EMAIL:      PowerShell.Guru@BonusBits.com 
	ENV:        Powershell v2.0, CLR 2.0+
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
	%USERPROFILE%\Documents\Results\Get-InactiveComputers
	
	LOGS
	%USERPROFILE%\Documents\Logs\Get-InactiveComputers
	+---History
	+---JobData
	+---Latest
	+---WIP
.EXAMPLE
	Get-InactiveComputers -Domain "domain.com" 
	Get List of Inactive Computer Objects that have not changed
	since last changed the computer password in the default of 90 days.
.EXAMPLE
	Get-InactiveComputers -Domain "domain.com" -Days 60
	Get List of Inactive Computer Objects that have not changed
	since last changed the computer password in 60 days.
.EXAMPLE
	Get-InactiveComputers -Domain "domain.com" -Days 60 -SkipPing -SkipOutGrid
	Get List of Inactive Computer Objects that have not changed
	since last changed the computer password in 60 days.
	Skip doing a connection test to the list of hosts.
	Skip displaying the end results that uses Out-GridView.
.PARAMETER Domain
	Active Directory Domain Name to query.
.PARAMETER Days
	Number of days backup from when the script is ran that a computer object 
	has not changed it's computer password with Active Directory.
.PARAMETER SkipOutGrid
	This switch will skip displaying the end results that uses Out-GridView.
.PARAMETER SkipPing
	This switch will skip the computer connection test.
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
		[parameter(Mandatory=$true,Position=0)][string]$Domain,
		[parameter(Mandatory=$false)][int]$Days = '90',
		[parameter(Mandatory=$false)][switch]$SkipOutGrid,
		[parameter(Mandatory=$false)][switch]$SkipPing
	)

#endregion Parameters

	If (!$Global:WindowsToolsDefaults) {
		Show-WPMDefaultsMissingError
	}

	# GET STARTING GLOBAL VARIABLE LIST
	New-Variable -Name StartupVariables -Force -Value (Get-Variable -Scope Global | Select -ExpandProperty Name)
	
	# CAPTURE CURRENT TITLE
	[string]$StartingWindowTitle = $Host.UI.RawUI.WindowTitle
	
	# PATHS NEEDED AT TOP
	[string]$HostListPath = ($Global:WindowsPatchingDefaults.HostListPath)
	
#region Variables

	# DEBUG
	$ErrorActionPreference = "Inquire"
	
	# SET ERROR MAX LIMIT
	$MaximumErrorCount = '1000'
	$Error.Clear()

	# SCRIPT INFO
	[string]$ScriptVersion = '1.0.2'
	[string]$ScriptTitle = "Get List of Inactive Computers from Active Directory by Levon Becker"
	[int]$DashCount = '68'

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
#	[string]$LogPath = ($Global:WindowsToolsDefaults.GetWSUSClientsLogPath)
#	[string]$ScriptLogPath = Join-Path -Path $LogPath -ChildPath 'ScriptLogs'
	[string]$ResultsPath = ($Global:WindowsToolsDefaults.GetInactiveComputersResultsPath)
	
	[string]$ModuleRootPath = $Global:WindowsToolsModulePath
	[string]$SubScripts = Join-Path -Path $ModuleRootPath -ChildPath 'SubScripts'
	[string]$Assets = Join-Path -Path $ModuleRootPath -ChildPath 'Assets'
	
	#region  Set Logfile Name
	
		[string]$HostInputDesc = $Domain.ToUpper()
		# Inputitem is also used at end for Outgrid
		[string]$InputItem = $Domain.ToUpper() #needed so the WinTitle will be uppercase
			
#		[array]$Groups = $Groups | ForEach-Object {$_.ToUpper()}
#		[string]$f = "GROUPS - " + ($Groups | Select -First 2) + " ..."
#		[string]$InputItem = "GROUPS: " + ($Groups | Select -First 2) + " ..."
#		[array]$GroupList = $Groups
		
		# Remove Duplicates in Array + Get Host Count
#		[array]$GroupList = $GroupList | Select -Unique
#		[int]$GroupCount = $GroupList.Count
	
	#endregion Set Logfile Name
	
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

	# FILENAMES
	[string]$ResultsTextFileName = "Get-InactiveComputers_Results_" + $FileDateTime + $Timezone + "_($HostInputDesc).log"
	[string]$ResultsCSVFileName = "Get-InactiveComputers_Results_" + $FileDateTime + $Timezone + "_($HostInputDesc).csv"

	# PATH + FILENAMES
	[string]$ResultsTextFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsTextFileName
	[string]$ResultsCSVFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsCSVFileName

	# MISSING PARAMETERS
#	If (!$UpdateServer) {
#		[string]$UpdateServer = ($Global:WindowsToolsDefaults.UpdateServer)
#	}


#endregion Variables

#region Check Dependencies
	
	[int]$depmissing = 0
	$depmissingList = $null
	# Create Array of Paths to Dependancies to check
	CLEAR
	$depList = @(
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

#region Show Window Title

	Set-WinTitleStart -title $ScriptTitle
	Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle

#endregion Show Window Title

#region Console Start Statements
	
	Show-ScriptHeader -blanklines '4' -DashCount $DashCount -ScriptTitle $ScriptTitle
	# Get PowerShell Version with External Script
	Set-WinTitleBase -ScriptVersion $ScriptVersion 
	[datetime]$ScriptStartTime = Get-Date
	[string]$ScriptStartTimeF = Get-Date -Format g

#endregion Console Start Statements

#region Update Window Title

	Set-WinTitleInput -WinTitleBase $Global:WinTitleBase -InputItem $InputItem
	Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
	
#endregion Update Window Title

#region Tasks

	#region Create Results Header
	
		Add-Content -Path $ResultsTextFullName -Encoding ASCII -Value 'ComputerName,Ping,Password Last Set,Distinguished Name,Number Of Days,Script Version,Script Host,User Account'
	
	#endregion Create Results Header

	#region Load ActiveDirectory Module
	
		# CHECK IF MODULE LOADED ALREADY
		If ((Get-Module | Select-Object -ExpandProperty Name | Out-String) -match "ActiveDirectory") {
			[Boolean]$ModLoaded = $true
		}
		Else {
			[Boolean]$ModLoaded = $false
		}
		
		# IF MODULE NOT LOADED THEN CHECK IF ON SYSTEM
		If ($ModLoaded -ne $true) {
			Try {
				Import-Module -Name ActiveDirectory -ErrorAction Stop | Out-Null
				[Boolean]$ModLoaded = $true
			}
			Catch {
				[Boolean]$ModLoaded = $false
				$ScriptErrors += 'Module Load Error'
				Break # ^temp
			}
		}
	
	#endregion Load ActiveDirectory Module
	
	#region Connect to Domain
	
#		If ($ModLoaded -eq $true) {
#			Try {
#				Connect-WSUSServer -WsusServer $UpdateServer -ErrorAction Stop | Out-Null
#				[Boolean]$WSUSConnected = $true
#			}
#			Catch {
#				[Boolean]$WSUSConnected = $false
#			}
#		}
	
	#endregion Connect to Domain
	
		
	#region Get Inactive Computers
	
#		If ($WSUSConnected -eq $true) {
			# TASK VARIBLES
#			[boolean]$Failed = $false
#			[boolean]$CompleteSuccess = $false
#			[int]$GroupCount = $GroupList.Count
#			$i = 0
#			[int]$TotalHosts = 0
#			Foreach ($WSUSGroup in $GroupList) {
#				$taskprogress = [int][Math]::Ceiling((($i / $GroupCount) * 100))
				# Progress Bar
#				Write-Progress -Activity "STARTING INACTIVE COMPUTERS LOOKUP ON - ($Domain)" -PercentComplete $taskprogress -Status "OVERALL PROGRESS - $taskprogress%"
			
		[int]$InactiveCount = 0
		$LastSetDate = [DateTime]::Now - [TimeSpan]::Parse("$Days")
		$InactiveList = Get-ADComputer -Server $Domain -Filter {PasswordLastSet -le $LastSetDate} -Properties passwordLastSet -ResultSetSize $null
		# | Select-Object -Property Name,PasswordLastSet,DistinguishedName
		#| Format-List Name,PasswordLastSet
		[int]$InactiveCount = $InactiveList.Count
			
		#region Results
				
#						If (!$ScriptErrors) {
#							[string]$ScriptErrors = 'None'
#						}
#						If ($Failed -eq $false) {
#							[boolean]$CompleteSuccess = $true
#						}
#						Else {
#							[boolean]$CompleteSuccess = $false
#						}
			$i = 0
			Foreach ($ComputerObject in $InactiveList) {
				$taskprogress = [int][Math]::Ceiling((($i / $InactiveCount) * 100))
				# Progress Bar
				[string]$ComputerName = $ComputerObject.Name.ToUpper()
				$PasswordLastSet = $ComputerObject.PasswordLastSet
				[string]$ComputerDN = $ComputerObject.DistinguishedName.Replace(",",' ')
				[string]$DNSHostName = $ComputerObject.DNSHostName

				Write-Progress -Activity "PING TEST ON - ($ComputerName)" -PercentComplete $taskprogress -Status "OVERALL PROGRESS - $taskprogress%"

				If ($SkipPing.IsPresent -ne $true) {
					If ($DNSHostName) {
						If ((Test-Connection -ComputerName $DNSHostName -Count 1 -Quiet) -eq $true) {
							$PingTest = $true
						}
						Else {
							$PingTest = $false
						}
					}
					ElseIf ($ComputerName) {
						If ((Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) -eq $true) {
							$PingTest = $true
						}
						Else {
							$PingTest = $false
						}
					}
					Else {
						$PingTest = 'Error'
					}
		}
				Else {
					$PingTest = 'Skipped'
				}
				
				If (($PingTest -ne $true) -and ($PingTest -ne $false) -and ($PingTest -ne 'Skipped')) {
						$PingTest = 'Unknown'
				}
					
				[string]$TaskResults = $ComputerName + ',' + $PingTest + ',' + $PasswordLastSet + ',' + $ComputerDN + ',' + $Days + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName
			
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
				# PROGRESS COUNTER
				$i++
			} # Foreach ComputerObject	
			Write-Progress -Activity "PING TEST" -Status "COMPLETED" -Completed 
			
		#endregion Results
#				} #/Foreach Client
				# PROGRESS COUNTER
#				$i++
#			} #/Foreach Group
#			Write-Progress -Activity "STARTING WSUS CLIENT LOOKUP" -Status "COMPLETED" -Completed 
#		}
	
	#endregion Get Inactive Computers

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
	Show-ScriptStatusRuntimeTotals -StartTimeF $ScriptStartTimeF -EndTimeF $Global:GetRuntime.EndTimeF -Runtime $Global:GetRuntime.Runtime
	Write-Host ''
	Write-Host 'DOMAIN:           ' -ForegroundColor Green -NoNewline
	Write-Host $Domain.ToUpper()
	Write-Host 'NUMBER OF DAYS:   ' -ForegroundColor Green -NoNewline
	Write-Host $Days
	Write-Host 'TOTAL INACTIVE:   ' -ForegroundColor Green -NoNewline
	Write-Host $InactiveCount
#	Show-ScriptStatusFiles -ResultsPath $ResultsPath -ResultsFileName $ResultsCSVFileName -LogPath $LogPath
	Write-Host ''
	Write-Host 'Results Path:     '  -ForegroundColor Green -NoNewline
	Write-Host "$ResultsPath"
	Write-Host 'Results FileName: '  -ForegroundColor Green -NoNewline
	Write-Host "$ResultsCSVFileName"
#	Write-Host 'Log Path:         '  -ForegroundColor Green -NoNewline
#	Write-Host "$LogPath"
	
	Show-ScriptStatusCompleted
	Set-WinTitleCompleted -WinTitleInput $Global:WinTitleInput

#endregion Script Completion Updates

#region Display Report
	
	If ($SkipOutGrid.IsPresent -eq $false) {
		$outfile | Out-GridView -Title "Get Inactive AD Computers for $InputItem"
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
	Func_Get-TimeZone
	Func_Reset-WindowsToolsUI
	Func_Show-ScriptHeader
	MultiFunc_Set-WinTitle
	MultiFunc_Show-Script-Status
#>

<# TO DO
#>

<# Change Log
1.0.0 - 11/08/2012
	Created.

#>


#endregion Notes
