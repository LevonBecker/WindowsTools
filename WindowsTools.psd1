#######################################################################################################################
# File:             WindowsTools.psd1                                                                                 #
# Author:           Levon Becker                                                                                      #
# Email:			PowerShell.Guru@BonusBits.com                                                                     #
# Web Link:			http://www.bonusbits.com/wiki/HowTo:Use_Windows_Tools_PowerShell_Module                           #
# Publisher:        Bonus Bits                                                                                        #
# Copyright:        © 2012 Bonus Bits. All rights reserved.                                                           #
# Usage:            To load this module in your Script Editor:                                                        #
#                   1. Open the Script Editor.                                                                        #
#                   2. Select "PowerShell Libraries" from the File menu.                                              #
#                   3. Check the WindowsTools module.                                                                 #
#                   4. Click on OK to close the "PowerShell Libraries" dialog.                                        #
#                   Alternatively you can load the module from the embedded console by invoking this:                 #
#                       Import-Module -Name WindowsTools                                                              #
#######################################################################################################################

@{

# Script module or binary module file associated with this manifest
ModuleToProcess = 'WindowsTools.psm1'

# Version number of this module.
ModuleVersion = '1.1.3'

# ID used to uniquely identify this module
GUID = '{d623b43f-d0d9-47ad-aef1-d23f87ff8a24}'

# Author of this module
Author = 'Levon Becker'

# Company or vendor of this module
CompanyName = 'Bonus Bits'

# Copyright statement for this module
Copyright = '© 2012 Bonus Bits. All rights reserved.'

# Description of the functionality provided by this module
Description = 'A PowerShell module with various PowerShell Tools'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '2.0'

# Minimum version of the .NET Framework required by this module
#DotNetFrameworkVersion = '2.0'
DotNetFrameworkVersion = '4.0'

# Minimum version of the common language runtime (CLR) required by this module
#CLRVersion = '2.0.50727'
CLRVersion = '4.0'

# Processor architecture (None, X86, Amd64, IA64) required by this module
ProcessorArchitecture = 'None'

# Modules that must be imported into the global environment prior to importing
# this module
RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to
# importing this module
ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = @()

# Modules to import as nested modules of the module specified in
# ModuleToProcess
NestedModules = @()

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all modules packaged with this module
ModuleList = @()

# List of all files packaged with this module
FileList = @(
	'.\WindowsTools.psm1'
	'.\WindowsTools.psd1'
)

# Private data to pass to the module specified in ModuleToProcess
PrivateData = ''

}
