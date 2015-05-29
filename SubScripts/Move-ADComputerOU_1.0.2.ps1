#requires –version 2.0

Function Move-ADComputerOU {

#region Help

<#
.SYNOPSIS
	Move Active Directory Computer Object to another OU.
.DESCRIPTION
	Move Active Directory Computer Object to another OU.
.NOTES
	AUTHOR:  Levon Becker
	STATE:	 Stable
.EXAMPLE
	Set-ADComputerOU -TargetOU "ou=workstations,cn=domain,cn=com"
	If no parameters are specified you will be prompted to enter them individually.
.EXAMPLE
	Set-ADComputerOU server01 -TargetOU "ou=workstations,cn=domain,cn=com"
.EXAMPLE
	Set-ADComputerOU -List server01,server02 -TargetOU "ou=workstations,cn=domain,cn=com"
	Patch a list of hostnames comma seperated without spaces. (Shortnames)
.PARAMETER ComputerName
	Short name of Windows host to patch
	Do not use FQDN 
.PARAMETER List
	A PowerShell array List of servers to patch or comma separated list
	-List server01,server02
	@("server1", "server2") will work as well
	Do not use FQDN
.PARAMETER TargetOU
	Full LDAP syntax without spaces for the target location in AD
.PARAMETER KeepModLoaded
	Switch to keep the ActiveDirectory Module loaded after completion.
#>

#endregion Help

	Param (
		[parameter(Position=0,Mandatory=$true)][string]$ComputerName,
		[parameter(Mandatory=$true)][string]$DomainName,
		[parameter(Mandatory=$true)][string]$TargetOU,
		[parameter(Mandatory=$false)][switch]$KeepModLoaded
	)
	# STARTING VARIABLES
	[string]$Errors = ''
	[boolean]$Success = $false
	[datetime]$SubStartTime = Get-Date
	[string]$ComputerName = $ComputerName.ToUpper()
	[string]$DomainName = $DomainName.ToUpper()
	
	[Boolean]$ADModLoaded = $false
	
	# REMOVE EXISTING OUTPUT PSOBJECT	
	If ($Global:MoveADComputerOU) {
		Remove-Variable MoveADComputerOU -Scope "Global"
	}
	
	#region Tasks
	
		#region Load Active Directory Module
		
			# CHECK IF AD MODULE LOADED ALREADY
			If ((Get-Module | Select-Object -ExpandProperty Name | Out-String) -match "ActiveDirectory") {
				[Boolean]$ADModLoaded = $true
			}
			
			# IF AD MODULE NOT LOADED THEN CHECK IF ON SYSTEM
			If ($ADModLoaded -ne $true) {
				$ModuleList = Get-Module -ListAvailable | Select -ExpandProperty Name
				
				# IF AVAILABLE THEN LOAD ACTIVEDIRETORY MODULE
				If ($ModuleList -contains 'ActiveDirectory') {
					Try {
						Import-Module ActiveDirectory -ErrorAction Stop | Out-Null
						[Boolean]$ADModLoaded = $true
					}
					Catch {
						[Boolean]$ADModLoaded = $false
						$Errors += 'AD Module Load Error'
					}
				}
				Else {
					$Errors += 'AD Module Not on Local System'
				}
			}
		
		#endregion Load Active Directory Module

		#region Main Task

			If ($ADModLoaded -eq $true) {
			
				#region Get Target AD Object
				
					Try {
						$ComputerObject = Get-ADObject -Server $DomainName -Filter 'ObjectClass -eq "computer"' -Properties Name | Where-Object {$_.Name -eq "$ComputerName"} -ErrorAction Stop
					}
					Catch {
						$Errors += 'Get ADObject Error - '
					}
				
				#endregion Get Target AD Object
				
				#region Move Computer Object
				
					If ($ComputerObject) {
						[string]$DNBefore = ($ComputerObject.DistinguishedName | Out-String).Trim('')
						[string]$TargetDN = "CN=" + $ComputerName + ',' + $TargetOU
						If ($DNBefore -ne $TargetOU) {
							Try {
								Move-ADObject -Identity $ComputerObject -TargetPath $TargetOU -Server $DomainName -ErrorAction Stop
								[Boolean]$Success = $true
								[string]$DNAfter = Get-ADObject -Filter 'ObjectClass -eq "computer"' -Properties Name | Where-Object {$_.Name -eq "$ComputerName"} | Select-Object -ExpandProperty DistinguishedName
							}
							Catch {
								$Errors += 'Failed to Move AD Object - '
							}
						}
						Else {
							[Boolean]$Success = $true
						}
					}
					Else {
						$Errors += 'Computer Not Found - '
					}
				
				#endregion Move Computer Object
				
				If ($KeepModLoaded.IsPresent -eq $false) {
					Remove-Module -Name "ActiveDirectory" -Force | Out-Null
				}
			}
		
		#endregion Main Task
	
	#endregion Tasks
	
	#region Results
	
		If (!$Errors) {
			[string]$Errors = 'None'
		}
	
		Get-Runtime -StartTime $SubStartTime
		
		$Global:MoveADComputerOU = New-Object -TypeName PSObject -Property @{
			ComputerName= $ComputerName
			Success = $Success
			Errors = $Errors 
			Starttime = $SubStartTime
			Endtime = $global:GetRuntime.Endtime
			Runtime = $global:GetRuntime.Runtime
			DNBefore = $DNBefore
			DNAfter = $DNAfter
			DomainName = $DomainName
		}
	
	#endregion Results
}

#region Notes

<# Description
	This script can be used to move Active Directory Computer Object to another OU.
#>

<# Author
	Levon Becker
	powershell.guru@bonusbits.com
	http://www.bonusbits.com
#>

<# Dependents
	Move-ADComputer
#>

<# Dependencies
	Get-Runtime
#>

<# To Do List
	
#>

<# Change Log
1.0.0 - 10/29/2012
	Created
1.0.1 - 01/04/2013
	Removed SubScripts parameter
	Removed dot sourcing subscripts
1.0.2 - 01/14/2013
	Added DomainName parameter and logic to specify which domain the computer object is in.
	
#>

#endregion Notes
