function _UpdateTools {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $VM
    )
    
    # VM must be powered on to upgrade tools
    if ($VM.PowerState -eq 'PoweredOn') {
        Write-Verbose -Message 'Updating tools with [NoReboot]'
        $VM | Update-Tools -NoReboot -Verbose:$false
    } else {
        Write-Error -Message 'VM must be powered on in order to update VM tools'
    }
}
