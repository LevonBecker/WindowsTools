﻿#requires –version 2.0

Function Get-HostIP {
	Param (
		[parameter(Position=0,Mandatory=$true)][string]$ComputerName,
		[parameter(Mandatory=$false)][switch]$StayConnected,
		[parameter(Mandatory=$false)][string]$vCenter,
		[parameter(Mandatory=$false)][boolean]$UseAltViCreds,
		[parameter(Mandatory=$false)]$ViCreds,
		[parameter(Mandatory=$false)][switch]$SkipVimQuery
	)
	# CLEAR VARIBLES
	[boolean]$Success = $false
	[string]$Notes = $null
	[datetime]$SubStartTime = Get-Date
	[string]$hostip = 'Unknown'
	[string]$lookupmethod = 'All Failed'
	[boolean]$dnsquerysuccess = $false
	[boolean]$wmiquerysuccess = $false
	[boolean]$vimquerysuccess = $false
		
	If ($global:GetHostIP) {
		Remove-Variable GetHostIP -Scope "Global"
	}
	
	#region Tasks
	
		# Try DNS lookup first
		$ErrorActionPreference = 'Stop'
		Try {
			[array]$dnsquery = [System.Net.Dns]::GetHostAddresses($ComputerName)
			[string]$hostip = $dnsquery | Select -ExpandProperty IPAddressToString
			[boolean]$dnsquerysuccess = $true
			[boolean]$Success = $true
			[string]$lookupmethod = 'DNS'
			[string]$Notes += 'DNS Query Success '
		}
		Catch {
			[boolean]$dnsquerysuccess = $false
			[string]$Notes += 'DNS Query Failed '
		}
		$ErrorActionPreference = 'SilentlyContinue'
		
		# If DNS Lookup Fails try WMI (WINS)
		If ($dnsquerysuccess -eq $false) {
			$wmiquery = $null
			Try {
				[array]$wmiquery = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ComputerName -ErrorAction Stop
				[string]$Notes += "WMI Query Success "
				[boolean]$wmiquerysuccess = $true
				[string]$lookupmethod = 'WMI'
				[boolean]$Success = $true
			}
			Catch {
				[boolean]$wmiquerysuccess = $false
			}
			If ($wmiquerysuccess -eq $true) {
				[Management.ManagementObject]$adapter = $wmiquery | Where-Object {$_.IPAddress -match "(\b([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\b)"}
				[string]$hostip = $adapter.IPAddress
			}
			Else {
				[string]$hostip = 'Unknown'
				[boolean]$wmiquerysuccess = $false
				[string]$Notes += 'WMI Query Failed '
			}
		}
		
		# If DNS and WMI Fail Check vCenter
		If (($dnsquerysuccess -eq $false) -and ($wmiquerysuccess -eq $false) -and ($SkipVimQuery.IsPresent -eq $false)) {
			Get-VmGuestInfo -ComputerName $ComputerName -vCenter $vCenter -UseAltViCreds $UseAltViCreds -ViCreds $ViCreds
			If ($global:GetVmGuestInfo.Success -eq $true) {
				[string]$hostip = $global:GetVmGuestInfo.VMIP
				[boolean]$vimquerysuccess = $true
				[string]$lookupmethod = 'VIM'
				[boolean]$Success = $true
				[string]$Notes += 'VIM Query Success '
			}
			Else {
				[boolean]$vimquerysuccess = $false
				[string]$Notes += 'VIM Query Failed '
			}
		}
	
	#endregion Tasks
	
	Get-Runtime -StartTime $SubStartTime
	
	# Create Results Custom PS Object
	$global:GetHostIP = New-Object -TypeName PSObject -Property @{
		Hostname = $ComputerName
		Success = $Success
		Notes = $Notes
		Starttime = $SubStartTime
		Endtime = $global:GetRunTime.Endtime
		Runtime = $global:GetRunTime.Runtime
		HostIP = $hostip
		LookupMethod = $lookupmethod
	}
}

#region Notes


<# Description
	To get the IP Address from Hostname
#>

<# Author
	Levon Becker
	PowerShell.Guru@BonusBits.com
	http://www.bonusbits.com
#>

<# Dependents
	Install-Patches
	Test-WSUSClient
	Get-HostInfo
#>

<# Dependencies
	Get-Runtime
#>

<# Change Log
1.0.0 - 10/11/2011 
	Created.
1.0.1 - 11/10/2011
	Added more parameter settings
	Added $UseAltViCreds and $ViCreds
1.0.2 - 11/11/2011
	Changed to use Connect-ViHost_1.0.7.ps1
	Changed to use Get-VmGuestInfo_1.0.4.ps1
1.0.3 - 04/23/2012
	Moved Notes to bottom
	Renamed client to computername
	Changed StayConnected and SkipVimQuery to switch
1.0.4 - 05/03/2012
	Renames
	SkipVIMQuery changed to switch
1.0.5 - 05/08/2012
	Cleaned up code
1.0.6 - 12/14/2012
	Moved Get VMInfo dot source so it doesn't load if not needed.
1.0.7 - 01/04/2013
	Removed -SubScript parameter from all subfunction calls.
	Removed dot sourcing subscripts because all are loaded when the module is imported now.
#>

#endregion Notes
