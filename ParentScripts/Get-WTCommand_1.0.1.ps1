#requires –version 2.0

Function Get-WTCommand {

#region Help

<#
.SYNOPSIS
	WindowsTools Module Help Script.
.DESCRIPTION
	Script to list WindowsTools Module commands.
.NOTES
	VERSION:    1.0.1
	AUTHOR:     Levon Becker
	EMAIL:      PowerShell.Guru@BonusBits.com 
	ENV:        Powershell v2.0, CLR 4.0+
	TOOLS:      PowerGUI Script Editor
.EXAMPLE
	Get-WTCommand
.EXAMPLE
	Get-WTCommand -Noun Jobs
.EXAMPLE
	Get-WTCommand -Verb Test
.PARAMETER Noun
	Gets cmdlets and functions with names that include the specified noun. 
	<String> represents one or more nouns or noun patterns, such as "process" or "*item*". 
	Wildcards are permitted.
.PARAMETER Verb
	Gets information about cmdlets and functions with names that include the specified verb.
	<String> represents one or more verbs or verb patterns, such as "remove" or *et".
	Wildcards are permitted.
#>

#endregion Help
 
    [CmdletBinding()] 
    Param (
		[parameter(Mandatory=$false)][string]$Noun = '*',
		[parameter(Mandatory=$false)][string]$Verb = '*'
	) 

    #List all WindowsTools functions available
    Get-Command -Module WindowsTools -Noun $Noun -Verb $Verb 
}

#region Notes

<# Dependents
#>

<# Dependencies
#>

<# TO DO
#>

<# Change Log
1.0.0 - 12/27/2012
	Created.
1.0.1 - 01/14/2013
	Added Verb and Noun parameters
#>


#endregion Notes
