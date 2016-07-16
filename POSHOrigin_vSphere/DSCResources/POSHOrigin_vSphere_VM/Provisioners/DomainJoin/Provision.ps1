[cmdletbinding()]
param(
    [parameter(mandatory)]
    $Options
)

begin {
    Write-Debug -Message 'DomainJoin provisioner: beginning'
}

process {
    Write-Verbose -Message 'Running DomainJoin provisioner...'
    $provOptions = ConvertFrom-Json -InputObject $Options.Provisioners
    $djOptions = $provOptions | Where-Object {$_.name -eq 'DomainJoin'}

    $t = Get-VM -Id $Options.vm.Id -Verbose:$false -Debug:$false
    #$ip = $t.Guest.IPAddress | Where-Object { ($_ -notlike '169.*') -and ( $_ -notlike '*:*') } | Select-Object -First 1
    $ip = _GetGuestVMIPAddress -VM $t
    if ($null -ne $ip -and $ip -ne [string]::Empty) {
        $cmd = {
            $VerbosePreference = 'Continue'
            try {
                $params = @{
                    DomainCredential = $args[0]
                    DomainName = $args[1]
                    Force = $true
                }
                if ($null -ne $args[2]) { $params.OUPath = $args[2] }
                $str = $params | ConvertTo-Json
                Write-Debug -Message "DomainJoin options:`n$str"
                Write-Verbose -Message "Joining domain [$($args[1])]"
                Add-Computer @params -ErrorAction SilentlyContinue | Out-Null
                $params.Remove('OUPath')
                Add-Computer @params -ErrorAction SilentlyContinue | Out-Null
                #Restart-Computer -Delay 5 -Verbose:$false -Force -Confirm:$false
                return $true

                ## WMI Method
                #$djAccount = $args[0]
                #$domain = $args[1]
                #if ($null -ne $args[2]) { $ou = $args[2] }
                #$DomainJoin = 1
                #$CreateAccount = 2
                #$AllowJoinIfAlreadyJoined = 32
                #$options = $DomainJoin + $CreateAccount + $AllowJoinIfAlreadyJoined
                #$computer = Get-WmiObject -Class Win32_ComputerSystem
                #if ($null -ne $ou) {
                #    $result = $computer.JoinDomainOrWorkGroup($domain, $djAccount.Username, $djAccount.GetNetworkCredential().password, $ou, $options)
                #} else {
                #    $result = $computer.JoinDomainOrWorkGroup($domain, $djAccount.Username, $djAccount.GetNetworkCredential().password, $null, $options)
                #}
                #$retVal = $result.ReturnValue
                #if ($retVal -eq 0 ) {
                #    return $true
                #} else {
                #    Write-Error -Message "Domain join error. Returned: $retVal"
                #    return $false
                #}
                #return $true
            } catch {
                Write-Error -Message 'There was a problem running the DomainJoin provisioner'
                Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
                write-Error $_
                return $false
            }
        }

        if ($null -ne $Options.DomainJoinCredentials) {
            $params = @{
                ComputerName = $ip
                Credential = $Options.GuestCredentials
                ScriptBlock = $cmd
                ArgumentList = @(
                    $Options.DomainJoinCredentials,
                    $djOptions.options.domain,
                    $djOptions.options.OUPath
                )
            }
            $result = Invoke-Command @params

            if ($result) {
                Restart-Computer -ComputerName $ip -Force -Confirm:$false -Credential $Options.GuestCredentials
                # Wait for machine to reboot
                Write-Verbose -Message "Waiting for machine to become available..."
                Start-Sleep -Seconds 10
                $timeout = 5
                $sw = [diagnostics.stopwatch]::StartNew()
                while ($sw.elapsed.minutes -lt $timeout){
                    $vmView = $Options.vm | Get-View -Verbose:$false
                    if ($vmView.Guest.IpAddress -and $vmView.Guest.IpAddress -notlike '169.*') {
                        $p = Invoke-Command -ComputerName $vmView.Guest.IpAddress -Credential $Options.GuestCredentials -ScriptBlock { Get-Process } -ErrorAction SilentlyContinue
                        if ($null -ne $p) {

                            Write-Verbose -Message 'Running gpupdate /force...'
                            Invoke-Command -ComputerName $vmView.Guest.IpAddress -Credential $Options.GuestCredentials -ScriptBlock { gpupdate /force } -ErrorAction SilentlyContinue

                            break
                        }
                    }
                    Start-Sleep -Seconds 5
                    Write-Verbose -Message "Waiting for machine to become available..."
                }
            }
        } else {
            throw 'DomainJoin options were not found in provisioner options!'
        }
    }
}

end {
    Write-Debug -Message 'DomainJoin provisioner: ending'
}