function _GetGuestOS{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $vm,
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $session,
        [Parameter(Mandatory)]
        [pscredential]$Credential
    )

    #Get guest operating system version
    try {
        $ip = _GetGuestVMIPAddress -VM $vm

        Write-Debug 'Quering system for OS version'
        if ($ip) {
            $os = Invoke-Command -Session $session -ScriptBlock { (Get-WmiObject -Class Win32_OperatingSystem -verbose:$false).Version }
            $os = $os.Split(".")
            $os = ($os[0] + $os[1]).ToInt32($Null)
            return $os
        } else {
            Write-Error -Message 'Error querying for OS version'
        }
    } catch {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        Write-Error -Message 'There was a problem querying for the system OS version'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error -Exception $_
    }
}