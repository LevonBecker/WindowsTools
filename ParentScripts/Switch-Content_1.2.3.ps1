#requires -version 2.0

Function Switch-Content {

#region Help

<#
.SYNOPSIS
	A Find and Replace Cmdlet for replacing text in multiple files.
.DESCRIPTION
	This Powershell script can be used to replace text in such files
	as PS1 to quickly change a variable setting to something else.
	BEWARE: If you have this script in the path of the changes it
			will get changed as well.
.NOTES
	AUTHOR:  Levon Becker
	TITLE:   Switch-Content
	VERSION: 1.2.3
.EXAMPLE
	Switch-Content
	If no parameters are specified you will be prompted to enter them individually.
.EXAMPLE
	Switch-Content -Path C:\Scripts -File "*.ps1" -Find "oldvCenter.domain.com" -ReplaceWith newvCenter.domain.com -Recursive
	Check all the PS1 files in the C:\Scripts folder and subfolders for string oldvCenter.domain.com and replace with newvCenter.domain.com.
.PARAMETER Find
	String to Find.
	Leave blank and you will be prompted to make a selection.
.PARAMETER ReplaceWith
	String replacement.
	Leave blank and you will be prompted to make a selection.
.PARAMETER Path
	Root directory to search.
	Leave blank and you will be prompted to make a selection.
.PARAMETER File
	File extension to query.
	Leave blank and you will be prompted to make a selection.
.PARAMETER Backup
	Switch parameter that if present indicates to make a backup copy of each file that is changed.
.PARAMETER Recursive
	Switch parameter that if present indicates to do a recursive search of the path.
.PARAMETER Quiet
	Switch parameter that if present indicates to not prompt for confirmations.
.PARAMETER Encoding
	File character set encoding type.
	Options are ASCII, Unicode, or UTF8
	Leave blank and you will be prompted to make a selection.
.LINK
	http://wiki.bonusbits.com/main/PSScript:Switch-Content
	http://blogs.technet.com/b/heyscriptingguy/archive/2011/06/30/use-parameter-sets-to-simplify-powershell-commands.aspx
#>

#endregion Help

[CmdletBinding()]
Param (
    [parameter(Mandatory=$false)][string]$Path,
	[parameter(Mandatory=$false)][string]$File,
	[parameter(Mandatory=$false)][string]$Find,
	[parameter(Mandatory=$false)][string]$ReplaceWith,
	[parameter(Mandatory=$false)][switch]$Recursive,
	[parameter(Mandatory=$false)][switch]$Backup,
	[parameter(Mandatory=$false)][switch]$Quiet,
	[parameter(Mandatory=$false)][ValidateSet("ASCII", "Unicode", "UTF8")][string]$Encoding
)

#region Top Variables

	If (!$Global:WindowsToolsDefaults) {
		Show-WindowsToolsDefaultsMissingError
	}

	# GET STARTING GLOBAL VARIABLE LIST
	New-Variable -Name StartupVariables -Force -Value (Get-Variable -Scope Global | Select -ExpandProperty Name)
	
	# CAPTURE CURRENT TITLE
	[string]$StartingWindowTitle = $Host.UI.RawUI.WindowTitle
	
#endregion Top Variables

#region Prompt: Missing Inputs

	Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
	
	#region Prompt: Path
	
	If (!$Path) {
		Do {
			[boolean]$pathfail = $false
			Write-Host ''
			Write-Host 'Enter Root Path to Search.' -ForegroundColor Yellow
			[string]$Path = $(Read-Host 'Path')
			If ((Test-Path -Path $Path) -eq $false) {
				Write-Host "ERROR:	PATH NOT FOUND ($Path)" -BackgroundColor Red -ForegroundColor White
				[boolean]$pathfail = $true
			}		
		}
		Until ($pathfail -eq $false)
		
		#region Prompt: Recursive Search
		
			If ($Recursive.IsPresent -eq $false) {
				Write-Host ''
				$title = ''
				$message = 'Search Sub Folders?'

				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
				    'Select Yes if you would like to search all the sub directories for a match.'

				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
				    'Select No if you do not want search all the sub directories for a match.'

				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

				$result = $host.ui.PromptForChoice($title, $message, $options, 0) 

				switch ($result)
				{
				    0 {[switch]$Recursive = $true} 
				    1 {[switch]$Recursive = $false} 
				}
			}
			
		#endregion Prompt: Recursive Search
	}
	
	#endregion Prompt: Path
	
	#region Prompt: File
	
	If (!$File) {
		Do {
			Write-Host ''
			Write-Host 'Enter Filename or Wildcard Extension.' -ForegroundColor Yellow
			[string]$File = $(Read-Host 'File')
		}
		Until ($File)
	
		#region Prompt: Backup Option
		
			If ($Backup.IsPresent -eq $false) {
				Write-Host ''
				$title = ''
				$message = 'Backup Files?'

				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
				    'Select Yes if you would like .BAK files created of the orignal files.'

				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
				    'Select No if you do not want .BAK files created of the orignal files.'

				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

				$result = $host.ui.PromptForChoice($title, $message, $options, 0) 

				switch ($result)
				{
				    0 {[switch]$Backup = $true} 
				    1 {[switch]$Backup = $false} 
				}
			}
			
		#endregion Prompt: Backup Option
	
	} #File
	
	#endregion Prompt: File
	
	#region Prompt: Find
	
	If (!$Find) {
		Do {
			Write-Host ''
			Write-Host 'Enter String to Find.' -ForegroundColor Yellow
			[string]$Find = $(Read-Host 'Find')
		}
		Until ($Find)
	}
	
	#endregion Prompt: Find
	
	#region Prompt: ReplaceWith
	
	If (!$ReplaceWith) {
		Do {
			Write-Host ''
			Write-Host 'Enter Replacement String.' -ForegroundColor Yellow
			[string]$ReplaceWith = $(Read-Host 'Replace')
		}
		Until ($ReplaceWith)
	}
	
	#endregion Prompt: ReplaceWith
	
	#region Prompt: File Encoding
	
		If (!$Encoding) {
			Write-Host ''
			$title = ''
			$message = 'Select File Encoding Type'

			$a = New-Object System.Management.Automation.Host.ChoiceDescription "&ASCII", `
			    'Select for ASCII / ANSI Encoded output file.'

			$b = New-Object System.Management.Automation.Host.ChoiceDescription "&Unicode", `
			    'Select for Unicode Encoded output file.'
						
			$c = New-Object System.Management.Automation.Host.ChoiceDescription "UTF&8", `
			    'Select for UTF8 Encoded output file.'

			$d = New-Object System.Management.Automation.Host.ChoiceDescription "E&xit", `
			    'Select to Exit the Script'

			$options = [System.Management.Automation.Host.ChoiceDescription[]]($a, $b, $c, $d)

			$result = $host.ui.PromptForChoice($title, $message, $options, 2) 

			switch ($result)
			{
			    0 {$Encoding = 'ASCII'} 
			    1 {$Encoding = 'Unicode'}
				2 {$Encoding = 'UTF8'}
				3 {
					Clear
					Reset-WindowsToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SkipPrompt
					Break
				}
			}
		}
		
	#endregion Prompt: File Encoding

#endregion Prompt: Missing Inputs

#region Variables

	# DEBUG
	$ErrorActionPreference = "Inquire"
	
	# SET ERROR MAX LIMIT
	$MaximumErrorCount = '1000'
	$Error.Clear()

	# SCRIPT INFO
	[string]$ScriptVersion = '1.2.3'
	[string]$ScriptTitle = "Find and Replace File Content Script v$ScriptVersion by Levon Becker"
	[int]$DashCount = '60'

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
	
	#region  Set Input Name
	
		If ($Find.Length -gt 15) {
			[string]$InputDesc = $Find.SubString('0','15') + '...'
			[string]$InputItem = $Find.SubString('0','15') + '...'
		}
		Else {
			[string]$InputDesc = $Find
			[string]$InputItem = $Find
		}
	
	#endregion Set Input Name
	
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
	[string]$ResultsTempFolder = $FileDateTime + $TimeZoneString + "_($InputDesc)"
	[string]$ResultsTempPath = Join-Path -Path $ResultsPath -ChildPath $ResultsTempFolder
	[string]$WIPTempFolder = $FileDateTime + $TimeZoneString + "_($InputDesc)"
	[string]$WIPPath = Join-Path -Path $LogPath -ChildPath 'WIP'
	[string]$WIPTempPath = Join-Path -Path $WIPPath -ChildPath $WIPTempFolder
	
	# FILENAMES
	[string]$ResultsTextFileName = "Move-ADComputer_Results_" + $FileDateTime + $TimeZoneString + "_($InputDesc).log"
	[string]$ResultsCSVFileName = "Move-ADComputer_Results_" + $FileDateTime + $TimeZoneString + "_($InputDesc).csv"
	[string]$JobLogFileName = "JobData_" + $FileDateTime + $TimeZoneString + "_($InputDesc).log"

	# PATH + FILENAMES
	[string]$ResultsTextFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsTextFileName
	[string]$ResultsCSVFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsCSVFileName
	[string]$JobLogFullName = Join-Path -Path $JobLogPath -ChildPath $JobLogFileName
	
	#endregion Set Filenames and Paths

#endregion Variables

#region Tasks

	If (($Path) -and ($File) -and ($Find) -and ($ReplaceWith)) {
		
	#region Prompt: Verify Input and Continue

		If ($Quiet.IsPresent -eq $false) {
			Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
			Write-Host "PATH:           $Path"
			Write-Host "FILE:           $File"
			Write-Host "FIND:           $Find"
			Write-Host "REPLACEWITH:    $ReplaceWith"
			Write-Host "RECURSIVE:      $Recursive"
			Write-Host "BACKUP:         $Backup"
			Write-Host "ENCODING:       $Encoding"
			Write-Host ''
			$title = ''
			$message = 'Continue Search Step?'

			$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
			    'If the information entered is correct select Yes to continue.'

			$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
			    'If the information entered is not correct select No to Exit'

			$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

			$result = $host.ui.PromptForChoice($title, $message, $options, 0) 

			switch ($result)
			{
			    0 {[boolean]$continue = $true} 
			    1 {[boolean]$continue = $false} 
			}
			If ($continue -eq $false) {
				Clear
				Reset-WindowsToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SkipPrompt
				Break
			}
		}

	#endregion Prompt: Verify Input and Continue
		
	#region Search

		## Recursive
		[array]$FileList = @()
		If ($Recursive.IsPresent -eq $true) {
			[array]$FileList = Get-ChildItem -Path $Path -Filter $File -Recurse
		}
		# Not Recursive
		Else {
			[array]$FileList = Get-ChildItem -Path $Path -Filter $File
		}
		
		# TOTAL FILES FOUND
		$FilesFoundCount = $FileList.Count
		
		# Remove Any Duplicates (Bad idea, it skips files)
	#	$FileList = $FileList | Select -Unique
		
		# Check Each File for the targeted string to replace and add to selected List if found
		## $SelectedFiles is an Array of System.IO.FileInfo Objects
		[array]$SelectedFiles = @()
		$FileInfo = $null
		Foreach ($FileInfo in $FileList) {
			If ((Select-String -Path $FileInfo.FullName -Pattern $Find -Quiet) -eq $true) {
				$SelectedFiles += $FileInfo
			}
		}
		
		# Get Count of File Selected to be Replaced
		[int]$ReplaceWithTotal = $SelectedFiles.Count
		
	#endregion Search
		
		# IF Files Found with the Targeted String to replace Continue Replacement Process
		If ($SelectedFiles) {
		
	#region Prompt: Continue with Replacement

		If ($Quiet.IsPresent -eq $false) {
			Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
			Write-Host "Files Found Matching Filter in Path: "-ForegroundColor Yellow -NoNewline
			Write-Host $FilesFoundCount
			Write-Host "Files Found with Content to Replace: "-ForegroundColor Yellow -NoNewline
			Write-Host $ReplaceWithTotal
			Write-Host ''
			$title = ''
			$message = 'Continue with Replacement?'

			$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
			    'If the information entered is correct select Yes to continue.'

			$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
			    'If the information entered is not correct select No to Exit'

			$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

			$result = $host.ui.PromptForChoice($title, $message, $options, 0) 

			switch ($result)
			{
			    0 {[boolean]$continue = $true} 
			    1 {[boolean]$continue = $false} 
			}
			If ($continue -eq $false) {
				Clear
				Break
			}
		}

	#endregion Prompt: Continue with Replacement
		
	#region Replace

		Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
		Write-Host 'PROCESSING FILES' -ForegroundColor Yellow
		Write-Host ''
		$FileInfo = $null
		[int]$count = '0'
		Foreach ($FileInfo in $SelectedFiles) {
			$count++
			
			# Get File Time Stamp Information
			$CreationTime = $null
			$CreationTimeUtc = $null
			$LastWriteTime = $null
			$LastWriteTimeUtc = $null
			$CreationTime = ($FileInfo.CreationTime)
			$CreationTimeUtc = ($FileInfo.CreationTimeUtc)
			$LastWriteTime = ($FileInfo.LastWriteTime)
			$LastWriteTimeUtc = ($FileInfo.LastWriteTimeUtc)
			
			# Make backup of file if Selected
			If ($Backup.IsPresent -eq $true) {
				$backupfile = Join-Path -Path $FileInfo.DirectoryName -Childpath ($FileInfo.BaseName + '.bak')
				Copy-Item -Path $FileInfo.FullName -Destination $backupfile -Force
			}
			
			# Get File Contents
			[array]$filecontent = Get-Content -Path $FileInfo.FullName -Encoding $Encoding
			
			# $filecontent is an array so each value or line must be checked
			[array]$datareplaced = ($filecontent | ForEach-Object {$_.Replace("$Find","$ReplaceWith")})
			
			# Replace file with corrected character set
			Out-File -filepath $FileInfo.FullName -InputObject $datareplaced -Encoding $Encoding -Force
			
			# Set original time stamp information on new file
			Set-ItemProperty -Path $FileInfo.FullName -Name CreationTime -Value $CreationTime
			Set-ItemProperty -Path $FileInfo.FullName -Name CreationTimeUtc -Value $CreationTimeUtc
			Set-ItemProperty -Path $FileInfo.FullName -Name LastWriteTime -Value $LastWriteTime
			Set-ItemProperty -Path $FileInfo.FullName -Name LastWriteTimeUtc -Value $LastWriteTimeUtc
			
			# Write file including full path to UI
			Write-Host $FileInfo.FullName
		}
		
	#endregion Replace

		} #/If Matches found
		Else {
			Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
			Write-Host "PATH:           $Path"
			Write-Host "FILE:           $File"
			Write-Host "FIND:           $Find"
			Write-Host "REPLACEWITH:    $ReplaceWith"
			Write-Host "RECURSIVE:      $Recursive"
			Write-Host "BACKUP:         $Backup"
			Write-Host "ENCODING:       $Encoding"
			Write-Host ''
			Write-Host 'No Matches Found' -ForegroundColor Yellow
			Write-Host ''
			Break
		}
	} #/If input parameters not empty
	Else {
		Write-Host 'Missing Input' -ForegroundColor White -BackgroundColor Red
		Break
	}

#endregion Tasks

#region Display Results

	Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
	Write-Host "PATH:           $Path"
	Write-Host "FILE:           $File"
	Write-Host "FIND:           $Find"
	Write-Host "REPLACEWITH:    $ReplaceWith"
	Write-Host "RECURSIVE:      $Recursive"
	Write-Host "BACKUP:         $Backup"
	Write-Host "ENCODING:       $Encoding"
	Write-Host ''
	Write-Host '------------------------------------------------------------'
	Write-Host ''
	Write-Host "Total Files Changed: " -ForegroundColor Green -NoNewline
	Write-Host $count
	Write-Host ''
	Write-Host '-------------' -ForegroundColor Green
	Write-Host '| COMPLETED |' -ForegroundColor Green
	Write-Host '-------------' -ForegroundColor Green
	Write-Host ''

#endregion Display Results

} #Function end

#region Notes

<# Dependants
#>

<# Dependencies
	Func_Show-ScriptHeader
#>

<# Change Log
1.0.0 - 05/11/2011 (Beta)
	Created
1.0.1 - 05/23/2011 (WIP)
	Finished Find logic
1.0.2 - 05/23/2011 (WIP)
	Added Prompts for input if missing
	Add file backup
1.0.3 - 05/23/2011 (Stable)
	Added continue prompts
	Moved vars to top again
	Fixed some var renames missed
1.0.4 - 05/23/2011 (Stable)
	Cleaned up Help section
1.0.5 - 05/24/2011
	Removed prompt if none found
	Added None found statement
1.0.6 - 06-02-2011
	Added Do/Until loops to force data entry, or for accidentally hitting enter.
1.0.7 - 06-02-2011
	Added Encoding selection prompt.
1.0.8 - 06-08-2011
	Finished Encoding selection prompt.
	Added Show-ScriptHeader Function and usage
	Added End-Script Function and usage
1.0.9 - 10/10/2011
	Troubleshooting issues where not working for '$' varible names
1.1.0 - 02/24/2012
	Cleaned up code
	Added Backup or not Option
	Added Show-ScriptHeader instead of Clear for several of the prompts
1.1.1 - 02/24/2012
	Changed replace and path parameters because ComputerName variables
	Added backupfiles parameter
	Added recursive parameter
	Added Silent parameter
	Rewrote Replace section
		Fixed time stamping
		Changed so not to transform fileinfo object (keep it throughout)
		Added Last Written capture and set Itemproperties
	Moved Backup Option to Missing Inputs section
	Create recursive section in Missing Inputs
	Added Silent options to bypass prompts
	Changed Missing inputs sections to IF NOT
	Renamed $f and $fp to $FileInfo
	Moved clearing variable to just before being set
	Added stric [boolean] to prompt varibles
	Added strict [array] variables for selected and filsearchList
1.1.2 02/24/2012
	Fixed Recursive prompt UI messages
	Removed Show-ScriptHeader from Recursive and Backup prompt
	Added characterset parameter
1.1.3 02/27/2012
	Code Cleanup and rename
1.1.4 - 04/13/2012
	Added characterset parameter info to help section
	Working out why Backup file prompts even if you pass a boolean input to the parameters
	Working out why some recursive directories or files were missed (_PubSubScripts\PS1\*.ps1)
1.1.9 - 04/16/2012
	Switched to new version scheme.
	Figured out how to use switch parameters correctly and fixed most of the logic to work with them.
	Added Func_Show-ScriptHeader
1.2.1 - 05/03/2012
	Fixed recursive and backup prompt. had backwards logic for switch.
	Removed Log Directory Until it's actually used.
	Copied subscripts and setup to be self contained.
1.2.2 - 05/10/2012
	Moved to LBTools Module
#>

#endregion Notes
