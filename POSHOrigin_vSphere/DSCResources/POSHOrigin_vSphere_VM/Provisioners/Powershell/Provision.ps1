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
    
    if (($scriptPath.StartsWith('http://')) -or ($scriptPath.StartsWith('https://'))) {
        $filename = $scriptPath.Substring($scriptPath.LastIndexOf('/') + 1)
        $output = "$($ENV:Temp)\$filename"
        Invoke-WebRequest -Uri $scriptPath -OutFile $output
        & $output -Options $Options -Mode 'Provision'
    } elseif (Test-Path -Path $scriptPath) {
        & $scriptPath -Options $Options -Mode 'Provision'
    } else {
     
        Write-Error -Message "Unable to find provisioner script [$scriptPath]"
    }
}

end {
    Write-Debug -Message 'Powershell script provisioner: ending'
}