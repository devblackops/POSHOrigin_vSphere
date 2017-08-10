function _RenameCDROM {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $CimSession,

        [string]$DriveLetter = 'Z'
    )

    $DriveLetter = "$DriveLetter`:"

    # If the VM has a cdrom, mount it as 'Z:'
    if (((Get-CimInstance -CimSession $CimSession -ClassName Win32_CDROMDrive -Verbose:$false) |
        Where-Object {$_.Caption -like "*vmware*"} | Select-Object -First 1).Drive -ne $DriveLetter) {

        Write-Verbose -Message 'Changing CDROM to Z:'
        $cd = (Get-CimInstance -CimSession $CimSession -ClassName Win32_CDROMDrive -Verbose:$false) | Where Caption -like "*vmware*"
        $oldLetter = $cd.Drive
        $cdVolume = Get-CimInstance -CimSession $CimSession -ClassName Win32_Volume -Filter "DriveLetter='$oldLetter'" -Verbose:$false
        Set-CimInstance -CimSession $CimSession -InputObject $cdVolume -Property @{DriveLetter=$DriveLetter} -Verbose:$false
    }
}
