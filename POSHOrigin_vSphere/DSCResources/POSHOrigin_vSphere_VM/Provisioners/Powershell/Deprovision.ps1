[cmdletbinding()]
param(
    [parameter(mandatory)]
    $Options
)

begin {
    Write-Debug -Message 'Powershell script deprovisioner: beginning'
}

process {
    $scriptPath = $Options.ProvOptions.Path
    
    if (($scriptPath.StartsWith('http://')) -or ($scriptPath.StartsWith('https://'))) {
        $filename = $scriptPath.Substring($scriptPath.LastIndexOf('/') + 1)
        $output = "$($ENV:Temp)\$filename"
        Invoke-WebRequest -Uri $scriptPath -OutFile $output | Out-Null
        & $output -Options $Options -Mode 'Deprovision'
    } elseif (Test-Path -Path $scriptPath) {
        & $scriptPath -Options $Options -Mode 'Deprovision'
    } else {
     
        Write-Error -Message "Unable to find provisioner script [$scriptPath]"
    }
}

end {
    Write-Debug -Message 'Powershell script deprovisioner: ending'
}