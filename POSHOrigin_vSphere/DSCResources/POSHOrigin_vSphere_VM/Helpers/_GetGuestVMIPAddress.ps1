function _GetGuestVMIPAddress{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $VM
    )

    # Get the VM again to ensure we have the latest information about it
    # because the IP address will only get populated once VMware Tools is running
    $t = Get-VM -Id $VM.Id -Verbose:$false -Debug:$false
    $ip = $t.Guest.IPAddress | Where-Object { ($_ -notlike '169.*') -and ( $_ -notlike '*:*') } | Select-Object -First 1
    if ($ip -ne [string]::Empty) {
        return $ip
    } else {
        return $null
    }
}