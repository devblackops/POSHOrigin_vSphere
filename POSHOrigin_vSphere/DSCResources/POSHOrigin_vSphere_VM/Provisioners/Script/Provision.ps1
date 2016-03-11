[cmdletbinding()]
param(
    [parameter(mandatory)]
    $Options
)

begin {
    Write-Debug -Message 'Script provisioner: beginning'
}

process {
    $provisionerOptions = $Options.ProvOptions    
    Write-Verbose -Message $provisionerOptions
}

end {
    Write-Debug -Message 'Script provisioner: ending'
}