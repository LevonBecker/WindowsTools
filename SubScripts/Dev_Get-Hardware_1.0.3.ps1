#requires –version 2.0

Function Get-Hardware {
	Param (
		[parameter(Position=0,Mandatory=$true)][string]$ComputerName,
		[parameter(Mandatory=$false)][string]$vCenter,
		[parameter(Mandatory=$false)][string]$StayConnected = $false,
		[parameter(Mandatory=$false)][switch]$SkipVimQuery
	)
	# Variables
	[string]$Notes = ''
	[boolean]$Success = $false
	[datetime]$SubStartTime = Get-Date
	[string]$ComputerName = $ComputerName.ToUpper()
	
	$WMIComputerSystem = $null
	[string]$WMIConnected = $false
	[string]$Model = 'Unknown'
	
	If ($Global:GetHardware) {
		Remove-Variable GetHardware -Scope "Global" | Out-Null
	}
	
	If ($ComputerName) {
		# WMI Query
		Try {
			$WMIComputerSystem = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop
			$WMIMemoryDevice = Get-WmiObject -Class Win32_MemoryDevice -ComputerName $ComputerName -ErrorAction Stop
			$WMIProcessor = Get-WmiObject -Class Win32_Processor -ComputerName $ComputerName -ErrorAction Stop
			[boolean]$WMIConnected = $true
		}
		Catch {
			$Notes += 'WMI Query Failed - '
			[boolean]$WMIConnected = $false
		}
		If ($WMIConnected -eq $true) {
		
			#region ComputerSystem
			
				[string]$Manufacturer = $WMIComputerSystem.Manufacturer
				[string]$Model = $WMIComputerSystem.Model
				[string]$BootupState = $WMIComputerSystem.BootupState
				[string]$NumberOfProcessors = $WMIComputerSystem.NumberOfProcessors
				[string]$NumberOfLogicalProcessors = $WMIComputerSystem.NumberOfLogicalProcessors
				[int]$TotalPhysicalMemoryMB = ($WMIComputerSystem.TotalPhysicalMemory / 1MB)
				
				# Determine if Physical or Virtual Platform
				If ($Model -eq 'VMware Virtual Platform') {
					[string]$Platform = 'Virtual'
				}
				[boolean]$Success = $true
				[string]$Notes += 'WMI Query Success - '
				Else {
					[string]$Platform = 'Physical'
				}
			
			#endregion ComputerSystem
			
			#region Processor
			
				[string]$ProcessorName = $WMIProcessor[0].Name
				If (($ProcessorName | Select-String -Pattern ',') -ne $null) {
				# Remove any commas in the OS Version
				[string]$ProcessorName = $ProcessorName.Replace(',', ' ')
				}
				If (($ProcessorName | Select-String -Pattern '®') -ne $null) {
					# Remove any commas in the OS Version
					[string]$ProcessorName = $ProcessorName.Replace('®', '')
				}
				If (($ProcessorName | Select-String -Pattern '(R)') -ne $null) {
					# Remove Registered Trademark
					[string]$ProcessorName = $ProcessorName.Replace('(R)', '') 
				}
				If (($ProcessorName | Select-String -Pattern '(TM)') -ne $null) {
					# Remove Registered Trademark
					[string]$ProcessorName = $ProcessorName.Replace('(TM)', '') 
				}
				If (($ProcessorName | Select-String -Pattern 'CPU') -ne $null) {
					# Remove Registered Trademark
					[string]$ProcessorName = $ProcessorName.Replace('CPU', '') 
				}
			
			#endregion Processor
			
			#region Memory
			
				
			
			#endregion Memory
		}
		
		# If WMI Fails Try vCenter Query If no SkipVimQuery switch
		If (($WMIConnected -eq $false) -and ($SkipVimQuery.IsPresent -eq $false)) {
			Get-VmGuestInfo -ComputerName $ComputerName -vCenter $vCenter
			If ($Global:GetVmGuestInfo.Success -eq $true) {
				$osver = $Global:GetVmGuestInfo.OSVersion
				$vimquerysuccess = $true
				$lookupmethod = 'VIM'
				[boolean]$Success = $true
				$Notes += 'VIM Query Success - '
			}
			Else {
				$vimquerysuccess = $false
				$Notes += 'VIM Query Failed - '
			}

		} #/If WMI Query failed try vCenter
	} #/If Client not blank
	Else {
		[string]$Notes = 'Missing Host'
	}
	Get-Runtime -StartTime $SubStartTime
	
	# Create Results Custom PS Object
	$Global:GetHardware = New-Object -TypeName PSObject -Property @{
		ComputerName = $ComputerName
		Success = $Success
		Notes = $Notes
		Starttime = $SubStartTime
		Endtime = $Global:GetRunTime.Endtime
		Runtime = $Global:GetRunTime.Runtime
		Platform = $Platform
		Manufacturer = $Manufacturer
		Model = $Model
		BootupState = $BootupState
		NumberOfProcessors = $NumberOfProcessors
		NumberOfLogicalProcessors = $NumberOfLogicalProcessors
		TotalPhysicalMemoryMB = $TotalPhysicalMemoryMB
		ProcessorName = $ProcessorName
	}
}

#region Notes

<# Description
	Query Windows System for Hardware Information.
#>

<# Author
	Levon Becker
	PowerShell.Guru@BonusBits.com
	http://www.bonusbits.com
#>

<# Dependents
	Get-HostInfo
#>

<# Dependencies
	Get-Runtime
#>

<# Change Log
	1.0.0 - 10/11/2011
		Created
	1.0.1 - 02/06/2012
		Added Model to output
#>

#endregion Notes
