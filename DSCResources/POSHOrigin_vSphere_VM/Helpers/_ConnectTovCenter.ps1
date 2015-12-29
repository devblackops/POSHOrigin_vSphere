function _ConnectTovCenter {
    [cmdletbinding()]
    param(
        [string]$vCenter,
        [pscredential]$Credential
    )

    if ($null -ne (Get-Module -Name VMware.VimAutomation* -ListAvailable -ErrorAction SilentlyContinue -Verbose:$false)) {
        Import-Module Vmware.VimAutomation.Sdk -Verbose:$false
        Import-Module VMware.VimAutomation.Core -Verbose:$false
        Import-Module VMware.VimAutomation.Vds -Verbose:$false
    } else {
        Throw 'VMware PowerCLI modules do not appear to be installed on this system.'
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