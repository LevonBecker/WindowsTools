Function Get-FSMORoleHolders {            

 if(!(get-module activedirectory)) {
  Write-Host "Importing AD Module.." -fore Blue
  Import-Module activedirectory }            

 $Domain = Get-ADDomain
 $Forest = Get-ADForest             

 $obj = New-Object PSObject -Property @{
  PDC = $domain.PDCEmulator
  RID = $Domain.RIDMaster
  Infrastructure = $Domain.InfrastructureMaster
  Schema = $Forest.SchemaMaster
  DomainNaming = $Forest.DomainNamingMaster
  }
 $obj            

 }