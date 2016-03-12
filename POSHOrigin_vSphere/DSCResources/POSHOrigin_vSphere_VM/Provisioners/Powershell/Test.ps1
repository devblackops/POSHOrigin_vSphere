[cmdletbinding()]
param(
    [parameter(mandatory)]
    $Options
)

begin {
    Write-Debug -Message 'Powershell script provisioner test: beginning'
}

process {
    $provisionerOptions = $Options.ProvOptions    
    Write-Verbose -Message $provisionerOptions
}

end {
    Write-Debug -Message 'Powershell script provisioner test: ending'
}