[cmdletbinding()]
param(
    [parameter(mandatory)]
    $Options
)

begin {
    Write-Debug -Message 'Powershell script provisioner: beginning'
}

process {
    $scriptPath = $Options.ProvOptions.Path
    
    if (Test-Path -Path $scriptPath) {
        & $scriptPath -Options $Options -Mode 'Provision'
    } else {
        Write-Error -Message "Unable to find provisioner script [$scriptPath]"
    }
}

end {
    Write-Debug -Message 'Powershell script provisioner: ending'
}