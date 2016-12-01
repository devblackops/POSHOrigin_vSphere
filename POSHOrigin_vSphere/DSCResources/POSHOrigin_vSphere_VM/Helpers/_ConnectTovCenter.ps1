function _ConnectTovCenter {
    [cmdletbinding()]
    param(
        [string]$vCenter,
        
        [pscredential]$Credential
    )

    $mods = @(
        'VMware.VimAutomation.Core'
        'Vmware.VimAutomation.Sdk'
        'VMware.VimAutomation.Vds'        
    )

    if ($null -ne (Get-Module -Name VMware.VimAutomation* -ListAvailable -ErrorAction SilentlyContinue -Verbose:$false)) {
        $mods | foreach {
            Import-Module -Name $_ -ErrorAction Stop -Verbose:$false -Debug:$false
        }        
    } else {
        throw 'VMware PowerCLI modules do not appear to be installed on this system.'
    }

    try {
        Write-Debug -Message "Trying to connect to $vCenter"
        Connect-VIserver -Server $vCenter -Credential $Credential -Force -Verbose:$false -Debug:$false -WarningAction SilentlyContinue
        Write-Debug -Message "Connected to vCenter: $vCenter"
        return $true
    } catch {
        return $false
    }
}
