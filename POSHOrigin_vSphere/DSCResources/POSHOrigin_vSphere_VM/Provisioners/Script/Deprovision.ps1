[cmdletbinding()]
param(
    [parameter(mandatory)]
    $Options
)

begin {
    Write-Debug -Message 'Script deprovisioner: beginning'
}

process {
    $provisionerOptions = $Options.ProvOptions    
    Write-Verbose -Message $provisionerOptions
}

end {
    Write-Debug -Message 'Script deprovisioner: ending'
}