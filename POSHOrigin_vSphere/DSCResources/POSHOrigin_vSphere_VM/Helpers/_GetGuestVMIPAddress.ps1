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
    $ips = $t.Guest.IPAddress | Where-Object { ($_ -notlike '169.*') -and ( $_ -notlike '*:*') }
    if ($ips) {
        $goodIp = $null
        foreach ($ip in $ips) {
            if (Test-Connection -ComputerName $ip -Count 1 -Quiet) {
                $goodIp = $ip
                break
            }
        }
        return $goodIp
    } else {
        return $null
    }

    if ($ip -ne [string]::Empty) {
        return $ip
    } else {
        return $null
    }
}