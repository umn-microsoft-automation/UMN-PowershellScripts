<# 
    .SYNOPSIS
	    This script reads a CSV file containing registry settings and writes those settings to the computer.
    .DESCRIPTION
	    This script reads registry settings from a CSV file formatted with the following headers:
            Key -> The registry key path in the form: HKEY_LOCAL_MACHINE\SOFTWARE\testing
            ValueName -> The name of the property to set.
            ValueData -> The value of the property to set.
            ValueType -> The type of registry property which must be one of the following: 
                String, ExpandString, Binary, DWord, MultiString, Qword, Unknown
        The script will log errors for each line of the CSV file and continue.
    .PARAMETER csvPath
	    The path to the CSV file.
    .PARAMETER logFolder
	    The path to the folder where the log file will be created.
    .NOTES
	    Name: Set-RegistryFromCSV
	    Author: Craig Woodford
	    Last Edit: 8/23/2018
    .EXAMPLE
	    Set-RegistryFromCSV.ps1 -csvPath C:\registry-settings.csv -logFolder C:\Logs
#>

param(
    [parameter(Mandatory=$true)][string]$csvPath,
    [parameter(Mandatory=$false)][string]$logFolder="$env:systemdrive\Windows\Temp\"
)


Function Write-Log {
	<#
		.SYNOPSIS
			This function is used to pass messages to a ScriptLog.  It can also be leveraged for other purposes if more complex logging is required.
		.DESCRIPTION
			Write-Log function is setup to write to a log file in a format that can easily be read using CMTrace.exe. Variables are setup to adjust the output.
		.PARAMETER Message
			The message you want to pass to the log.
		.PARAMETER Path
			The full path to the script log that you want to write to.
		.PARAMETER Severity
			Manual indicator (highlighting) that the message being written to the log is of concern. 1 - No Concern (Default), 2 - Warning (yellow), 3 - Error (red).
		.PARAMETER Component
			Provide a non null string to explain what is being worked on.
		.PARAMETER Context
			Provide a non null string to explain why.
		.PARAMETER Thread
			Provide a optional thread number.
		.PARAMETER Source
			What was the root cause or action.
		.PARAMETER Console
			Adjusts whether output is also directed to the console window.
		.NOTES
			Name: Write-Log
			Author: Aaron Miller
			LASTEDIT: 01/23/2013 10:09:00
		.EXAMPLE
			Write-Log -Message $exceptionMsg -Path $ScriptLog -Severity 3
			Writes the content of $exceptionMsg to the file at $ScriptLog and marks it as an error highlighted in red
	#>

	PARAM(
		[Parameter(Mandatory=$True)][String]$Message,
		[Parameter(Mandatory=$False)][String]$Path = "$env:TEMP\CMTrace.Log",
		[Parameter(Mandatory=$False)][int]$Severity = 1,
		[Parameter(Mandatory=$False)][string]$Component = " ",
		[Parameter(Mandatory=$False)][string]$Context = " ",
		[Parameter(Mandatory=$False)][string]$Thread = "1",
		[Parameter(Mandatory=$False)][string]$Source = "",
		[Parameter(Mandatory=$False)][switch]$Console
	)
				
	# Setup the log message
		
		$time = Get-Date -Format "HH:mm:ss.fff"
		$date = Get-Date -Format "MM-dd-yyyy"
		$LogMsg = '<![LOG['+$Message+']LOG]!><time="'+$time+'+000" date="'+$date+'" component="'+$Component+'" context="'+$Context+'" type="'+$Severity+'" thread="'+$Thread+'" file="'+$Source+'">'
				
	# Write out the log file using the ComObject Scripting.FilesystemObject
		
		$ForAppending = 8
		$oFSO = New-Object -ComObject scripting.filesystemobject
		$oFile = $oFSO.OpenTextFile($Path, $ForAppending, $True)
		$oFile.WriteLine($LogMsg)
		$oFile.Close()
		Remove-Variable oFSO
		Remove-Variable oFile
			
	# Write to the console if $Console is set to True
		
		if ($Console -eq $True) {Write-Host $Message}
			
}

# Set the log file path.
$timeStamp = Get-Date -Format yyyyMMDDThhmmss
$logpath = $logFolder + "\Set-RegistryFromCSV_log_" + $timeStamp + ".log"

Write-Log -Message "Starting Set-RegistryFromCSV.ps1" -Path $logpath 

# Import the CSV file.
try {
    Write-Log -Message "Importing CSV: $csvPath" -Path $logpath 
    $reglist = Import-Csv -Path $csvPath
}
catch {
    Write-Log -Message "Error importing CSV!" -Path $logpath 
    Write-Log -Message "Error message: $_" -Path $logpath 
    throw $_
}

# Loop through each entry from the CSV file.
foreach ($regentry in $reglist) {

    try {
        $regKey = "Registry::" + $regentry.Key
        $valName = $regentry.ValueName
        $valData = $regentry.ValueData
        $valType = $regentry.ValueType

        if(-not (Test-Path -Path $regKey)) {
            Write-Log -Message "Creating new registry key: $regKey" -Path $logpath 
            $null = New-Item -Path $regKey -Force
        }

        # Get the contents of the registry key.
        $currentKey = Get-Item -LiteralPath $regKey -Force

        if($currentKey.GetValue($valName) -eq $null) {
            Write-Log -Message "New Value: Key: $regKey ValueName: $valName ValueData: $valData ValueType: $valType" -Path $logpath 
            $null = New-ItemProperty -Path $regKey -Name $valName -Value $valData -PropertyType $valType -Force
        }
        elseif($currentKey.GetValue($valName) -ne $valData) {
            Write-Log -Message "Set Value: in Key: $regKey ValueName: $valName ValueData: $valData ValueType: $valType" -Path $logpath 
            $null = Set-ItemProperty -Path $regKey -Name $valName -Value $valData -Type $valType -Force
        }
        else {
            Write-Log -Message "No Action: Key: $regKey ValueName: $valName ValueData: $valData ValueType: $valType" -Path $logpath 
        }

    }
    catch {
        Write-Log -Message "Error processing element: $regentry" -Path $logpath 
        Write-Log -Message "Error was: $_" -Path $logpath 
    }
}

Write-Log -Message "Set-RegistryFromCSV finished." -Path $logpath 