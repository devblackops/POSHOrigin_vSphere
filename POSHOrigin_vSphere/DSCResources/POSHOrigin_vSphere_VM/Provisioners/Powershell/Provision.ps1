[cmdletbinding()]
param(
    [parameter(mandatory)]
    $Options
)

begin {
    Write-Debug -Message 'Powershell script provisioner: beginning'
}

process {
    $provisionerOptions = $Options.ProvOptions    
    Write-Verbose -Message $provisionerOptions
}

end {
    Write-Debug -Message 'Powershell script provisioner: ending'
}