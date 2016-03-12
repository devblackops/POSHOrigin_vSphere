[cmdletbinding()]
param(
    [parameter(mandatory)]
    $Options
)

begin {
    Write-Debug -Message 'Powershell script deprovisioner: beginning'
}

process {
    $provisionerOptions = $Options.ProvOptions    
    Write-Verbose -Message $provisionerOptions
}

end {
    Write-Debug -Message 'Powershell script deprovisioner: ending'
}