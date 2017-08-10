function _RefreshHostStorageCache {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$PSSession
    )

    try {
        Write-Debug 'Refreshing disks on guest'
        if ($os -ge 63) {
            Invoke-Command -Session $PSSession -ScriptBlock { Update-HostStorageCache } -Verbose:$false
        } else {
            Invoke-Command -Session $PSSession -ScriptBlock { $x = 'rescan' | diskpart } -Verbose:$false
        }
    } catch {
        Remove-PSSession -Session $PSsession -ErrorAction SilentlyContinue
        Write-Error -Message 'There was a problem updating the guest storage cache'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error -Exception $_
    }
}