<#
    .SYNOPSIS
        Searches for all required software updates in Windows Updates.
    .DESCRIPTION
        Uses com objects to search and install updates from Windows Update.
    .EXAMPLE
        .\Install-AllWindowsUpdates
    .OUTPUTS
        Hashtable of update results
    .NOTES
        Created by: Aaron Miller, Craig Woodford and Jeff Bolduan
#>
[CmdletBinding()]
param(

)
$SearchCriteria = "IsInstalled=0 and Type='Software'"

# Create the Windows Update Searcher
$Searcher = New-Object -ComObject Microsoft.Update.Searcher
$Searcher.ServerSelection()
$SearchResult = $Searcher.Search($SearchCriteria)

# Download all the updates
$Session = New-Object -ComObject Microsoft.Update.Session
$Downloader = $Session.CreateUpdateDownloader()
$Downloader.Updates = $SearchResult
$Downloader.Download()

# Install all the updates
$Installer = New-Object -ComObject Microsoft.Update.Installer
$Installer.Updates = $SearchResult
$Result = $Installer.Install()

$TotalNotStarted = 0
$TotalInProgress = 0
$TotalSucceeded = 0
$TotalSucceededWithErrors = 0
$TotalFailed = 0
$TotalAborted = 0
$TotalUnknown = 0
$TotalRebootRequired = 0
for($i = 0; $i -lt $SearchResult.Count; $i++) {
    Write-Verbose -Message "ResultCode $($Result.GetUpdateResult($i)) for update $($SearchResult[$i].Title)"
    if($Result.GetUpdateResult($i).RebootRequired) {
        $TotalRebootRequired++
    }

    if($Result.GetUpdateResult($i).ResultCode -eq 0) {
        $TotalNotStarted++
    } elseif($Result.GetUpdateResult($i).ResultCode -eq 1) {
        $TotalInProgress++
    } elseif($Result.GetUpdateResult($i).ResultCode -eq 2) {
        $TotalSucceeded++
    } elseif($Result.GetUpdateResult($i).ResultCode -eq 3) {
        $TotalSucceededWithErrors++
    } elseif($Result.GetUpdateResult($i).ResultCode -eq 4) {
        $TotalFailed++
    } elseif($Result.GetUpdateResult($i).ResultCode -eq 5) {
        $TotalAborted++
    } else {
        $TotalUnknown++
    }
}

return @{
    "TotalNotStarted" = $TotalNotStarted
    "TotalInProgress" = $TotalInProgress
    "TotalSucceeded" = $TotalSucceeded
    "TotalSucceededWithErrors" = $TotalSucceededWithErrors
    "TotalFailed" = $TotalFailed
    "TotalAborted" = $TotalAborted
    "TotalUnknown" = $TotalUnknown
    "TotalRebootRequired" = $TotalRebootRequired
}