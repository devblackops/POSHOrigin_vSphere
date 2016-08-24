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

    # If we didn't get a valid IP, let's keep trying a few times. Sometimes vCenter takes awhile
    # to report back the IP address after an operation is performed on the VM.
    if (-not $ips) {
        (1..6) | % {
            Start-Sleep -Seconds 10
            $t = Get-VM -Id $VM.Id -Verbose:$false -Debug:$false
            $ips = $t.Guest.IPAddress | Where-Object { ($_ -notlike '169.*') -and ( $_ -notlike '*:*') }
            if ($ips) { break }
        }
    }

    # Looks for a pingable IP address and return it if found
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
        Write-Error -Message 'Unable to retrieve a valid IP address from VM'
        return $null
    }
}
