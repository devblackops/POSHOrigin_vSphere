function _GetGuestOS{
    [cmdletbinding()]
    param(
        # [Parameter(Mandatory)]
        # [ValidateNotNull()]
        # $vm,

        # [Parameter(Mandatory)]
        # [pscredential]$Credential

        [Parameter(Mandatory)]
        [Microsoft.Management.Infrastructure.CimSession]$CimSession
    )

    #Get guest operating system version
    try {
        #$ip = _GetGuestVMIPAddress -VM $vm

        Write-Debug 'Quering system for OS version'
        #if ($ip) {
            #$opt = New-CimSessionOption -Protocol DCOM
            #$cim = New-CimSession -ComputerName $ip -Credential $Credential -SessionOption $opt -Verbose:$false
            $os = (Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $CimSession -Verbose:$false).Version
            $os = $os.Split('.')
            $os = ($os[0] + $os[1]).ToInt32($Null)
            #Remove-CimSession -CimSession $cim -ErrorAction SilentlyContinue
            return $os
        #} else {
        #    Write-Error -Message 'Error querying for OS version'
        #}
    } catch {
        Remove-CimSession -CimSession $cim -ErrorAction SilentlyContinue
        Write-Error -Message 'There was a problem querying for the system OS version'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error -Exception $_
    }
}