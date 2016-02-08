function _DisconnectFromvCenter {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [string]$vCenter
    )

    try {
        Write-Debug -Message "Disconnecting from vCenter [$vCenter]"
        Disconnect-VIServer -Server $vCenter -Force -Verbose:$false
        Write-Debug -Message "Disconnected from vCenter [$vCenter]"
    } catch {
        Write-Error -Message 'There was a problem disconnecting from vCenter'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        Write-Error -Exception $_
    }
}