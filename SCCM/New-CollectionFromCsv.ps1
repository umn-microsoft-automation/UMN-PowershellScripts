<#
    .SYNOPSIS
        Creates or updates an SCCM collections direct membership rules from a csv file.
    .DESCRIPTION
        Creates or updates an SCCM collections direct membership rules from a csv file.
    .EXAMPLE
        .\New-CollectionFromCsv -CollectionName "MyCollection" -LimitingCollection "MyLimitingCollection" -CSVPath "C:\temp\mycsv.csv" -ComputerNameAttribute "ComputerName" -SiteCode "AAA"
    .PARAMETER CollectionName
        String name of the collection to create or update.
    .PARAMETER LimitingCollection
        String name of the limiting collection.
    .PARAMETER CSVPath
        String path to the csv to import and use to build the collection.
    .PARAMETER ComputerNameAttribute
        This is the name of the column in the csv which contains the computer name.
    .PARAMETER SiteCode
        This is the site code where the code should be run (ex. "AAA").
    .NOTES
        Written by: Jeff Bolduan
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$CollectionName,

    [Parameter(Mandatory=$true)]
    [string]$LimitingCollection,

    [Parameter(Mandatory=$true)]
    [string]$CSVPath,

    [Parameter(Mandatory=$true)]
    [string]$ComputerNameAttribute,

    [Parameter(Mandatory=$true)]
    [string]$SiteCode
)
begin {
    if((Get-CimInstance -ClassName Win32_ComputerSystem).SystemType -eq 'x64-based PC') {
        Import-Module -Name "$($env:SystemDrive)\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
    } else {
        Import-Module -Name "$($env:SystemDrive)\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
    }

    Push-Location
    Set-Location -Path $SiteCode + ":"
} process {
    $CSVContents = Import-Csv -Path $CSVPath
    $Collection = Get-CMDeviceCollection -Name $CollectionName

    if($Collection -eq $null) {
        $Collection = New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName $LimitingCollection
    }

    $CollectionMembers = Get-CMDevice -CollectionId $Collection.CollectionID -Fast

    $AlreadyAdded = New-Object -TypeName System.Collections.ArrayList
    foreach($Computer in $CSVContents) {
        $ComputerResource = Get-CMDevice -Name $Computer.$ComputerNameAttribute

        try {
            if(($Computer.$ComputerNameAttribute -ne $null -and ($CollectionMembers.Name.Contains($Computer.$ComputerNameAttribute) -or $AlreadyAdded.Contains($ComputerResource)))) {
                $null = Add-CMDeviceCollectionDirectMembershipRule -CollectionId $Collection.CollectionId -ResourceId $ComputerResource.ResourceId
                $null = $AlreadyAdded.Add($ComputerResource)
            }
        } catch {
            Write-Error "Error adding resource $($Computer.$ComputerNameAttribute) to collection."
        }
    }
} end {
    Pop-Location
}