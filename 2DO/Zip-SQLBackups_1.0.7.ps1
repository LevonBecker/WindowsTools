#requires –version 2.0

#region Help

<#
.SYNOPSIS
	Compress SQL flat file backups in a given path.
.DESCRIPTION
	This Powershell script will zip up all the files in a directory based on a given file extension.
.NOTES
	AUTHOR:  Levon Becker
	TITLE:   Zip-SQLBackups
	VERSION: 1.0.7
	ENV:     Powershell v2
	REQUIREMENTS:
	1)	7-Zip v9.20 or higher installed
	2)	PowerShell Set-ExecutionPolicy to RemoteSigned or Unrestricted
	CHANGE LOG:
	01/05/2012:  Created
.EXAMPLE
	.\Zip-SQLBackups.ps1
	Defaults are .bak files in this path C:\Program Files\Microsoft SQL Server\MSSQL.1\MSSQL\Backup
.EXAMPLE
	.\Zip-SQLBackups.ps1 -filepath "D:\SQL Backups" -fileextension ".trn" -7zip "C:\Program Files (x86)\7-zip\7z.exe"
	Different path, file extension and 7-zip executable location set.
.PARAMETER filepath
	Full path to SQL Backup files.
.PARAMETER fileextension
	File extension to search for and select for compression.
.PARAMETER 7zip
	Full path including executable for 7-zip CLI application.
.PARAMETER ScriptLog
	Full path and filename for script log.
.PARAMETER retention
	Number of days to retain zip files. Meaning it will remove zip files in the filepath that are older than the days given.
.LINK
	http://wiki.bonusbits.com/wiki/How_to_Zip_SQL_Backup_Files_with_Scheduled_Task_and_PowerShell_Script
#>

#endregion Help

#region Parameters

	[CmdletBinding()]
	Param (
		[parameter(Mandatory=$false)][string]$filepath = 'C:\Program Files\Microsoft SQL Server\MSSQL.1\MSSQL\Backup',
		[parameter(Mandatory=$false)][string]$fileextension = '.bak',
		[parameter(Mandatory=$false)][string]$7zip = 'C:\Program Files\7-Zip\7z.exe',
		[parameter(Mandatory=$false)][string]$ScriptLog = (Join-Path -Path $filepath -ChildPath 'Zip-SQLBackups.log'),
		[parameter(Mandatory=$false)][boolean]$removeold = $false,
		[parameter(Mandatory=$false)][int]$retention = '60'
	)
		
#endregion Parameters

#region Variables
	
	# SCRIPT
	[datetime]$StartTime = Get-Date
	[string]$ScriptVersion = '1.0.7'
	$files = $null
	
	# LOCALHOST
	[string]$ComputerNamename = Get-Content Env:\COMPUTERNAME
	[string]$UserDomain = Get-Content Env:\USERDOMAIN
	[string]$UserName = Get-Content Env:\USERNAME

#endregion Variables

#region Functions

	Function Get-Runtime {
		Param (
			$StartTime
		)
		
		# Clear old psobject if present
		If ($global:GetRunTime) {
			Remove-Variable GetRunTime -Scope Global
		}
		
		$success = $false
		$Notes = $null
		$EndTime = $null
		$EndTimef = $null
		$timespan = $null
		$mins = $null
		$hrs = $null
		$sec = $null
		$RunTime = $null
		
		$EndTime = Get-Date
		$EndTimef = Get-Date -Format g
		$timespan = New-TimeSpan -Start $StartTime -End $EndTime
		$mins = ($timespan).Minutes
		$hrs = ($timespan).Hours
		$sec = ($timespan).Seconds
		$RunTime = [String]::Format("{0:00}:{1:00}:{2:00}", $hrs, $mins, $sec)
		
		If ($RunTime) {
			$success = $true
			$Notes = 'Completed'
		}
		
		# Create Results PSObject
		$global:GetRunTime = New-Object -TypeName PSObject -Property @{
			Startime = $StartTime
			Endtime = $EndTime
			Endtimef = $EndTimef
			Runtime = $RunTime
			Success = $success
			Notes = $Notes
		}
	}
	
	Function Run-Process {
		[CmdletBinding()]
		Param (
	        [parameter(Mandatory=$true)][string]$FilePath,
	        [parameter(Mandatory=$true)][string]$ArgumentList
	    )
		If ($global:procoutput) {
			Remove-Variable procoutput -Scope "Global"
		}
		$pinfo = New-Object System.Diagnostics.ProcessStartInfo
		$pinfo.FileName = $FilePath
		$pinfo.RedirectStandardError = $true
		$pinfo.RedirectStandardOutput = $true
		$pinfo.UseShellExecute = $false
		$pinfo.Arguments = $ArgumentList
		$p = New-Object System.Diagnostics.Process
		$p.StartInfo = $pinfo
		$p.Start() | Out-Null
		$p.WaitForExit()
		$global:procoutput = $p.StandardOutput.ReadToEnd()
	}

#endregion Functions

#region Log Header

	$datetime = Get-Date -format g
	$logdata = $null
	$logdata = @(
	'',
	'##############################################################################################################',
	"JOB STARTED:     $datetime" ,
	"SCRIPT VER:      $ScriptVersion",
	"ADMINUSER:       $UserDomain\$UserName",
	"LOCALHOST:       $ComputerNamename",
	"FILEPATH:        $filepath",
	"FILE EXT:        $fileextension",
	"7ZIPPATH:        $7zip",
	"REMOVEOLD:       $removeold",
	"RETENTION:       $retention Days"
	)
	Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
	
#endregion Log Header

#region Tasks

	#region Zip Files
			
		# GET BACKUP FILE LIST
		[array]$files = Get-Childitem -Path $filepath -recurse | Where-Object {$_.extension -match $fileextension}
		[int]$totalfiles = $files.Count
		$logdata = $null
		$logdata = @(
		'',
		"FILES SELECTED TO ZIP: $totalzipfile",
		'----------------------------'
		)
		Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
		$files | Select -ExpandProperty FullName | Add-Content -Path $ScriptLog -Encoding ASCII
		
		
		# IF FILE LIST NOT EMPTY CONTINUE PROCESS
		If ($files) {
			[int]$zipsuccesscount = '0'
			[int]$zipfailedcount = '0'

			Foreach ($file in $files) {
				[datetime]$SubStartTime = Get-Date
				# SET ZIP FILE NAME
				$zipfile = $null
				$zipfullname = $null
				$filefullname = $null
				[string]$filefullname = $file.FullName
				[string]$zipfile = ($file -replace 'bak','zip')
				[string]$zipfullname = ($filefullname -replace 'bak','zip')
				[boolean]$zipsuccess = $false
				
				# IF ZIP FILE NAME SET CONTINUE
				If ($zipfullname) {
					# UPDATE LOG
					$datetime = Get-Date -format g
					$logdata = $null
					$logdata = @(
					'',
					"START:           $datetime"
					)
					Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
					
					# REMOVE EXISTING ZIP WITH SAME NAME IF PRESENT (Maybe it didn't finish and would rather start fresh)
					If ((Test-Path -Path $zipfullname) -eq $true) {
						$logdata = $null
						$logdata = @(
						'',
						"DELETING:        $zipfile"
						)
						Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
						Remove-Item -Path $zipfullname -Force
					}
					
					# COMPRESS FILE
					Add-Content -Path $ScriptLog -Encoding ASCII -Value "COMPRESSING:     $file to $zipfile"
					$runerror = $null
					Try {
						$eapbefore = $ErrorActionPreference
						$ErrorActionPreference = 'Stop'
						. $7zip a -tzip $zipfullname $filefullname
						$ErrorActionPreference = $eapbefore
						$zipsuccesscount++
						[boolean]$runerror = $false
					}
					Catch {
						$zipfailedcount++
						[boolean]$runerror = $true
						# UPDATE LOG
						$logdata = $null
						$logdata = @(
						'',
						"RUNTIME ERROR:   $zipfile"
						)
						Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
					}
					
					If ($runerror -eq $false) {
						# SET TIMESTAMP TO MATCH ORIGINAL FILE (So SQL Maintenance Plan can remove based on date)
						$creationtime = $null
						$creationtimeutc = $null
						$lastwritetime = $null
						$lastwritetimeutc = $null
						$creationtime = $file.CreationTime
						$creationtimeutc = $file.CreationTimeUtc
						$lastwritetime = $file.LastWriteTime
						$lastwritetimeutc = $file.LastWriteTimeUtc
						# IF GET ORIGINAL FILE TIMESTAMP THE SET ON ZIP FILE ELSE SKIP
						If ($creationtime -and $creationtimeutc -and $lastwritetime -and $lastwritetimeutc) {
							Set-ItemProperty -Path $zipfullname -Name CreationTime -Value $creationtime
							Set-ItemProperty -Path $zipfullname -Name CreationTimeUtc -Value $creationtimeutc
							Set-ItemProperty -Path $zipfullname -Name LastWriteTime -Value $lastwritetime
							Set-ItemProperty -Path $zipfullname -Name LastWriteTimeUtc -Value $lastwritetimeutc
							# LastAccessTime
							# LastAccessTimeUtc
						}
					}
				
					#region Determine Success
					
						If (((Test-Path -Path $zipfullname) -eq $true) -and ($runerror -eq $false)) {
							# TEST ZIP
							Add-Content -Path $ScriptLog -Encoding ASCII -Value "TESTING ZIP:     $zipfile"
							$runerror = $null
							Try {
								$eapbefore = $ErrorActionPreference
								$ErrorActionPreference = 'Stop'
								$testzip = . $7zip t -tzip $zipfullname
								$ErrorActionPreference = $eapbefore
								$zipsuccesscount++
								[boolean]$runerror = $false
							}
							Catch { Write-Host 'ERROR'} {
								$zipfailedcount++
								[boolean]$runerror = $true
								# UPDATE LOG
								$logdata = $null
								$logdata = @(
								'',
								"RUNTIME ERROR:   $zipfile"
								)
								Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
							}
							# DELETE BAK FILE
							Add-Content -Path $ScriptLog -Encoding ASCII -Value "DELETING:        $file" 
							Remove-Item -Path $file.FullName -Force
							
							[boolean]$zipsuccess = $true
						}
						Else {
							[boolean]$zipsuccess = $false
						}
					
					#endregion Determine Success
					
					#region Add Sub Footer
					
						# CALCULATE RUNTIME FOR SUBTASK
						Get-Runtime -StartTime $SubStartTime
						$RunTime = $global:GetRunTime.Runtime
						
						$datetime = Get-Date -format g
						$logdata = $null
						$logdata = @(
						"END:             $datetime",
						"SUCCESS:         $zipsuccess",
						"RUNTIME:         $RunTime"
						)
						Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
					
					#endregion Add Sub Footer
					
				} # IF ZIP FILE NAME SET
				Else {
					# UPDATE LOG
					$logdata = $null
					$logdata = @(
					'',
					'ERROR:           Zip File Name Blank'
					)
					Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
				}
			}
		} # If not empty
		Else {
			# UPDATE LOG
			$logdata = $null
			$logdata = @(
			'',
			'ERROR:           NO FILES FOUND'
			)
			Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
		}
		
	#endregion Zip Files
	
	#region Remove Old Zip Files
	
		If ($removeold -eq $true) {
			[int]$delsuccesscount = '0'
			[int]$delfailedcount = '0'
			# GET LIST OF ZIP FILES OLDER THAN THE RETENTION PARAMETER IN DAYS TO REMOVE
			[array]$oldfiles = Get-Childitem -Path $filepath -recurse | Where-Object {($_.extension -match '.zip') -and ($_.CreationTime -lt (Get-Date).AddDays(-$retention))}
			[int]$totaloldfiles = $files.Count
			# UPDATE LOG
			$logdata = $null
			$logdata = @(
			'',
			'FILES SELECTED FOR REMOVEL: $totaloldfiles',
			'-------------------------------'
			)
			Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
			$oldfiles | Select -ExpandProperty FullName | Add-Content -Path $ScriptLog -Encoding ASCII
			
			# REMOVE ZIP FILES
			Foreach ($oldfile in $oldfiles) {
				$oldfilefullname = $null
				[string]$oldfilefullname = $oldfile.FullName
				# IF THE FILE EXISTS THEN TRY TO REMOVE IT
				If ((Test-Path -Path $oldfilefullname) -eq $true) {
					# UPDATE LOG
					$logdata = $null
					$logdata = @(
					'',
					"DELETING:        $oldfilefullname"
					)
					Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
					Try {
						Remove-Item -Path $oldfilefullname -Force -ErrorAction Stop
						$runerror = $false
					}
					Catch {
						$delfailedcount++
						$runerror = $true
						# UPDATE LOG
						$logdata = $null
						$logdata = @(
						'',
						"RUNTIME ERROR:   $oldfilefullname"
						)
						Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
					}
					# IF NO RUNTIME ERROR THEN CHECK IF FILE IS REMOVED
					If ($runerror -eq $false) {
						If ((Test-Path -Path $oldfilefullname) -eq $false) {
							# UPDATE LOG
							$logdata = $null
							$logdata = @(
							'',
							"DELETE SUCCESS:  $oldfilefullname"
							)
							Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
							$delsuccesscount++
						}
						Else {
							$delfailedcount++
							# UPDATE LOG
							$logdata = $null
							$logdata = @(
							'',
							"DELETE FAILED:   $oldfilefullname"
							)
							Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
						}
					}
				}
				Else {
					$delfailedcount++
					# UPDATE LOG
					$logdata = $null
					$logdata = @(
					'',
					"FILE MISSING:   $oldfilefullname"
					)
					Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata
				}
			}
		}
	
	#endregion Remove Old Zip Files	
	
#endregion Tasks

#region Log Footer

	# CALCULATE TOTAL RUNTIME
	Get-Runtime -StartTime $StartTime
	$RunTime = $global:GetRunTime.Runtime
	
	# WRITE LOG FOOTER
	$datetime = Get-Date -format g
	$logdata = $null
	$logdata = @(
	'',
	"JOB ENDED:       $datetime",
	"RUNTIME:         $RunTime",
	"TOTAL $fileextension:      $totalfiles",
	"TOTAL OLDFILES:  $totaloldfiles",
	"ZIP SUCCESS:     $zipsuccesscount",
	"ZIP FAILED:      $zipfailedcount",
	"DEL SUCCESS:     $delsuccesscount",
	"DEL FAILED:      $delfailedcount",
	'-----------------------------------------------------------------------------------------------------------------',
	''
	)
	Add-Content -Path $ScriptLog -Encoding ASCII -Value $logdata

#endregion Log Footer

#region Notes

<# Change Log
	1.0.0 - 01/05/2012
		Created
	1.0.6 - 01/06/2012
		Stable
	1.0.7 - 04/02/2012
		Change script logging to arrays so it only had to touch the file once for each iternation and less code.
		Adding retension section
#>

#endregion Notes
