function _RefreshHostStorageCache {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $vm,

        [Parameter(Mandatory)]
        [pscredential]$Credential
    )

    try {
        $ip = _GetGuestVMIPAddress -VM $vm
        $os = _GetGuestOS -VM $vm -Credential $credential
        if ($ip) {
            $session = New-PSSession -ComputerName $ip -Credential $credential -Verbose:$false

            Write-Debug 'Refreshing disks on guest'
            if ($os -ge 63) {
                Invoke-Command -Session $session -ScriptBlock { Update-HostStorageCache } -Verbose:$false
                Remove-PSSession -Session $session -ErrorAction SilentlyContinue
            } else {
                Invoke-Command -Session $session -ScriptBlock { $x = "rescan" | diskpart } -Verbose:$false
                Remove-PSSession -session $session -ErrorAction SilentlyContinue
            }
        } else {
            Write-Error -Message 'No valid IP address returned from VM view. Can not update guest storage cache'
        }
    } catch {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        Write-Error -Message 'There was a problem updating the guest storage cache'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error -Exception $_
    }
}