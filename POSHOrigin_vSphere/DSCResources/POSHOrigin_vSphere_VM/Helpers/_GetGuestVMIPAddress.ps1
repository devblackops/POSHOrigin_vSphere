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

    # Sometimes vCenter has a problem returning us good information, particular after an operation
    # has been performed on a VM (like increasing RAM/CPU). Let's try to get the IP address a few
    # times before bailing out.
    if (-not $ips) {
        (1..3) | foreach {
            $t = Get-VM -Id $VM.Id -Verbose:$false -Debug:$false
            $ips = $t.Guest.IPAddress | Where-Object { ($_ -notlike '169.*') -and ( $_ -notlike '*:*') }
            if ($ips) {
                break
            }
            Start-Sleep -Seconds 10 -Verbose:$false
        }
    }

    if ($ips) {
        $goodIp = $null
        foreach ($ip in $ips) {
            # Try to ping this IP before returning it
            if (Test-Connection -ComputerName $ip -Count 1 -Quiet) {
                $goodIp = $ip
                Write-Debug -Message "IP [$goodIP] retrieved from VM tools"
                break
            }
        }
        return $goodIp
    } else {
        Write-Warning -Message 'Unable to retrieve a valid IP address from VM tools'
        return $null
    }
}