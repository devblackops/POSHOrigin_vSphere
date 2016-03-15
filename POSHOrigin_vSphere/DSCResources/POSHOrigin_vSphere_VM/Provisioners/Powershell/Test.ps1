[cmdletbinding()]
param(
    [parameter(mandatory)]
    $Options
)

begin {
    Write-Debug -Message 'Powershell script provisioner test: beginning'
}

process {
    $scriptPath = $Options.ProvOptions.Path
    
    if (Test-Path -Path $scriptPath) {
        $result = & $scriptPath -Options $Options -Mode 'Test'
        return $result
    } else {
        Write-Error -Message "Unable to find provisioner script [$scriptPath]"
    }
}

end {
    Write-Debug -Message 'Powershell script provisioner test: ending'
}