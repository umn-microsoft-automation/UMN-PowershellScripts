<#
    .SYNOPSIS
        Simple script to enable Wake on Lan in Windows.
    .DESCRIPTION
        Simple script to enable Wake on Lan in Windows.
        You'll need to make sure BIOS and network level configuration is also complete.
        After the script completes.  The nic will be enabled to wake the computer with magic packets only and the computer will not be allowed to turn it off. 
    .EXAMPLE
        .\Enable-WakeOnLan.ps1
    .NOTES
        Created by: Warren Mason
        Converted by: Jeff Bolduan
#>
[CmdletBinding()]
param(

)
[array]$NetworkCards = Get-WmiObject "MSNdis_DeviceWakeOnMagicPacketOnly" -Namespace "root\wmi"

foreach($NetworkCard in $NetworkCards) {
    $EscapedPNPDevID = [regex]::Escape($NetworkCard.InstanceName)

    # WMI for "Allow this device to wake the computer" setting
    $NetworkCardPowerWake = Get-WmiObject "MSPower_DeviceWakeEnable" -Namespace "root\wmi" | Where-Object -FilterScript { $_.InstanceName -match $EscapedPNPDevID }

    # WMI for "Allow the computer to turn off this device to save power" setting
    $NetworkCardPower = Get-WmiObject "MSPower_DeviceEnable" -Namespace "root\wmi" | Where-Object -FilterScript { $_.InstanceName -match $EscapedPNPDevID }

    # Ensure the device existed in the previous classes
    if(($NetworkCardPowerWake -ne $null) -and ($NetworkCardPower -ne $null)) {
        # First we allow the nic to wake the machine if it isn't already allowed to do so.
        if($NetworkCardPowerWake.Enable -ne $true) {
            $NetworkCardPowerWake.Enable = $true
            $NetworkCardPowerWake.psbase.Put()
        }

        # Here we allow only magic packets to wake the computer.
        if($NetworkCard.EnableWakeOnMagicPacketOnly -ne $true) {
            $NetworkCard.EnableWakeOnMagicPacketOnly = $true
            $NetworkCard.psbase.Put()
        }

        # Finally, we disallow the computer from turning off the device to save power.
        if($NetworkCardPower.Enable -eq $true) {
            $NetworkCardPower.Enable = $false
            $NetworkCardPower.psbase.Put()
        }
    }
}