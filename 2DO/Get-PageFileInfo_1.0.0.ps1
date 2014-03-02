function Get-PageFileInfo { 
 
#Requires -Version 2.0 
[CmdletBinding()] 
 Param  
   ( 
    [Parameter(Mandatory=$true, 
               Position = 1, 
               ValueFromPipeline=$true, 
               ValueFromPipelineByPropertyName=$true)] 
    [Alias("computers")] 
    #[Array] 
    $ComputerNames 
#    [Parameter(Mandatory=$false, 
#               Position=2, 
#               ValueFromPipeline=$true, 
#               ValueFromPipelineByPropertyName=$true)] 
#    $Creds = (Receive-Credential -DomainA)     
    # See save credentials script for the Receive-Credential usage. 
    # Othewise replace (Receive-Credential -DomainA) with (get-credential). 
    # http://gallery.technet.microsoft.com/scriptcenter/en-us/2ff11fd5-67f6-44e4-8816-28edb984d63a         
   )#End Param  
 
Begin 
{ 
 Write-Host ''
 Write-Host "Retrieving PageFile Info . . ."
}#Begin 
Process { 
	$ErrorActionPreference = 0
	Foreach ($ComputerName in $ComputerNames) {
		$ComputerName = $ComputerName.ToUpper()
#		Write-Host " ($ComputerName)"
		$PageFileSettingsObjects = Get-WmiObject Win32_PageFileSetting -ComputerName $ComputerName
#		$PageFileObjects = Get-WmiObject Win32_PageFile -ComputerName $ComputerName
		Foreach ($PageFile in $PageFileSettingsObjects) {
			$Output = @{
				Hostname=$ComputerName 
				InitialSize=$PageFile.InitialSize 
				MaximumSize=$PageFile.MaximumSize 
				Path=$PageFile.Name 
			}
			$GetPageInfo = New-Object -TypeName PSOBJECT -Property $Output
		}
		$GetPageInfo | Select Hostname,Path,InitialSize,MaximumSize
	}
}#Process 
End 
{ 
 
}#End 
 
}# Get-PageFileInfo