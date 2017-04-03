function _GetGuestVMIPAddress {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $VM
    )

    begin {
        Write-Debug -Message '_GetGuestVMIPAddress() starting'
    }

    process {
        # Get the VM again to ensure we have the latest information about it
        # because the IP address will only get populated once VMware Tools is running
        $t = Get-VM -Id $VM.Id -Verbose:$false -Debug:$false
        $ips = @($t.Guest.IPAddress | Where-Object { ($_ -notlike '169.*') -and ( $_ -notlike '*:*') })
        Write-Debug -Message "VM IP addresses: $($ips -join ', ')"

        # Sometimes vCenter has a problem returning us good information, particular after an operation
        # has been performed on a VM (like increasing RAM/CPU). Let's try to get the IP address a few
        # times before bailing out.
        if ($ips.Count -eq 0) {
            (1..3) | ForEach-Object {
                $t = Get-VM -Id $VM.Id -Verbose:$false -Debug:$false
                $ips = @($t.Guest.IPAddress | Where-Object { ($_ -notlike '169.*') -and ( $_ -notlike '*:*') })
                if ($ips.Count -gt 0) {
                    break
                }
                Start-Sleep -Seconds 10 -Verbose:$false
            }
        }

        if ($ips.Count -gt 0) {
            foreach ($ip in $ips) {
                # Try to ping this IP before returning it
                if (Test-Connection -ComputerName $ip -Count 1 -Quiet) {
                    Write-Verbose -Message "IP [$ip] retrieved from VM tools"
                    $ip
                    break
                } else {
                    if (Test-WSMan -ComputerName $ip -ErrorAction SilentlyContinue) {
                        Write-Verbose -Message "IP [$ip] retrieved from VM tools"
                        $ip
                        break
                    }
                }
            }
        } else {
            Write-Warning -Message 'Unable to retrieve a valid IP address from VM tools'
        }
    }

    end {
        Write-Debug -Message '_GetGuestVMIPAddress() ending'
    }
}