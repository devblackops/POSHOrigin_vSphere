
function _NewCIMSession {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $VM,

        [Parameter(Mandatory)]
        [pscredential]$Credential
    )

    $ip = _GetGuestVMIPAddress -VM $VM

    if ($ip) {

        # Establish a CIM session
        $sessionParams = @{
            ComputerName = $ComputerName
            Credential = $Credential
            Verbose = $false
        }
        $cim = New-CimSession @sessionParams

        if ($cim) {

            $ciParams = @{
                ClassName = 'Win32_OperatingSystem'
                Verbose = $false
                ErrorAction = 'SilentlyContinue'
            }
            # Verify this session works by executing a query.
            $os = Get-CimInstance -CimSession $cim @ciParams

            if ($os) {
                # This CIM session works
                Write-Debug -Message 'Successfully established CIM session'
                return $cim
            } else {
                Write-Debug -Message 'Unable to establish CIM session. Trying again using DCOM'
                # On Windows 2008, we may have to use the DCOM session option
                $cim | Remove-CimSession -Verbose:$false
                $sessionParams.SessionOption = New-CimSessionOption -Protocol Dcom
                $cim = New-CimSession @sessionParams
                if ($cim) {
                    $os = Get-CimInstance -CimSession $cim @ciParams
                    if ($os) {
                        Write-Debug -Message 'Successfully established CIM session using DCOM option'
                        return $cim
                    } else {
                        $cim | Remove-CimSession -Verbose:$false
                        Write-Error -Message 'Unable to establish CIM session with DCOM option'
                    }
                } else {
                    Write-Error -Message 'Unable to establish CIM session with DCOM option'
                }
            }
        } else {
            Write-Error -Message 'Unable to establish CIM session'
        }
    } else {
        Write-Error -Message 'Unable to retrieve guest VM IP address. Can not establish CIM session.'
    }
}
