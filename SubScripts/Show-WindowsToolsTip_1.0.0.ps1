#requires –version 2.0

Function Show-WindowsToolsTip {
	
	#region Tips
	
#		$a = {
#			Write-Host 'TIP: ' -ForegroundColor Green -NoNewline
#			Write-Host 'The ' -NoNewline
#			Write-Host '-FileBrowser ' -ForegroundColor Yellow -NoNewline
#			Write-host 'switch for Add-NFSDS will show a poppup window to chose your host list file from the local system.'
#			Write-Host ''
#			Write-Host '  EXAMPLE: ' -NoNewline
#			Write-Host 'Add-NFSDS -FileBrowser' -ForegroundColor Yellow -NoNewline
#			Write-Host ' <enter>'
#			Write-Host ''
#		}
		
#		$b = {
#			Write-Host 'TIP: ' -ForegroundColor Green -NoNewline
#			Write-Host 'The ' -NoNewline
#			Write-Host '-UseAltViCreds ' -ForegroundColor Yellow -NoNewline
#			Write-host 'switch for Add-NFSDS can be used to give alternate credentials for the ViHost / vCenter instead of using the credentials loaded with PowerShell.'
#			Write-Host ''
#			Write-Host '  EXAMPLE: ' -NoNewline
#			Write-Host 'Add-NFSDS -FileBrowser -UseAltViCreds' -ForegroundColor Yellow -NoNewline
#			Write-Host ' <enter>'
#			Write-Host ''
#		}
#		
#		$c = {
#			Write-Host 'TIP: ' -ForegroundColor Green -NoNewline
#			Write-Host 'The ' -NoNewline
#			Write-Host '-List ' -ForegroundColor Yellow -NoNewline
#			Write-Host 'parameter for Switch-Content can be used to input multiple hosts from the command line.'
#			Write-Host ''
#			Write-Host '  EXAMPLE: ' -NoNewline
#			Write-Host 'Install-Patches -List server01,server02,server03' -ForegroundColor Yellow -NoNewline
#			Write-Host ' <enter>'
#			Write-Host ''
#		}
#		
#		$d = {
#			Write-Host 'TIP: ' -ForegroundColor Green -NoNewline
#			Write-Host 'The ' -NoNewline
#			Write-Host '-List ' -ForegroundColor Yellow -NoNewline
#			Write-host 'parameter for Switch-Content also excepts a PowerShell array variable to input multiple hosts from the command line.'
#			Write-Host ''
#			Write-Host '  EXAMPLE: ' -NoNewline
#			Write-Host '$mylist = @("server01","server02","server03")' -ForegroundColor Yellow -NoNewline
#			Write-Host ' <enter>'
#			Write-Host '           Install-Patches -List $mylist' -ForegroundColor Yellow -NoNewline
#			Write-Host ' <enter>'
#			Write-Host ''
#		}
#		
#		$e = {
#			Write-Host 'TIP: ' -ForegroundColor Green -NoNewline
#			Write-Host 'The ' -NoNewline
#			Write-Host '-SkipOutGrid ' -ForegroundColor Yellow -NoNewline
#			Write-Host 'switch for Switch-Content can be used to skip the Out-GridView Results (Spreadsheet Poppup) at the end.'
#			Write-Host ''
#			Write-Host '  EXAMPLE: ' -NoNewline
#			Write-Host 'Install-Patches -FileName hostlist01.txt -SkipOutGrid' -ForegroundColor Yellow -NoNewline
#			Write-Host ' <enter>'
#			Write-Host ''
#		}
#		
#		$f = {
#			Write-Host 'TIP: ' -ForegroundColor Green -NoNewline
#			Write-Host 'The ' -NoNewline
#			Write-Host '-MaxJobs ' -ForegroundColor Yellow -NoNewline
#			Write-Host 'switch for Switch-Content can be used to throttle the background jobs. The default value is high so if system resources start to pose an issue use this to set a lower number of jobs that can run simultaneously.'
#			Write-Host ''
#			Write-Host '  EXAMPLE: ' -NoNewline
#			Write-Host 'Install-Patches -FileName hostlist01.txt -MaxJobs 50' -ForegroundColor Yellow -NoNewline
#			Write-Host ' <enter>'
#			Write-Host ''
#		}
		
	#endregion Tips
	
	#region Pick Random Tip
		
		# CREATE OBJECT OF SCRIPT BLOCKS
#		$TipList = New-Object -TypeName PSObject -Property @{
#			a = $a
#			b = $b
#			c = $c
#			d = $d
#			e = $e
#			f = $f
#		}
		
		# CREATE ARRAY TO BE USED TO PICK A RANDOM TIP
		## Get-Random doesn't work on PSObject
#		$PickList = @(
#			"a",
#			"b",
#			"c",
#			"d",
#			"e",
#			"f"
#		)
		
		# SELECT RANDOM FROM PICKLIST
#		$Selected = Get-Random -InputObject $PickList
		
		# DISPLAY RANDOM SELECTED TIP SCRIPT BLOCK
#		. $TipList.$Selected
	
	#region Pick Random Tip
}

#region Notes

<# Dependents
	
#>

<# Dependencies
	Func_Get-Runtime
#>

<# To Do List
	
#>

<# Change Log
	1.0.0 - 05/03/2012
		Created
#>

#endregion Notes
