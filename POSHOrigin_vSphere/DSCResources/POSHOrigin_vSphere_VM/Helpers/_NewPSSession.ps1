
function _NewPSSession {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [string]$IPAddress,

        [Parameter(Mandatory)]
        [pscredential]$Credential
    )

    try {
        $session = New-PSSession -ComputerName $IPAddress -Credential $Credential -Verbose:$false
        return $session
    } catch {
        Write-Error -Message 'Unable to establish PowerShell Remoting session.'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error -ErrorRecord $_
    }
}
