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
    
    if (($scriptPath.StartsWith('http://')) -or ($scriptPath.StartsWith('https://'))) {
        $filename = $scriptPath.Substring($scriptPath.LastIndexOf('/') + 1)
        $output = "$($ENV:Temp)\$filename"
        Invoke-WebRequest -Uri $scriptPath -OutFile $output
        $result = & $output -Options $Options -Mode 'Test'
        return $result
    } elseif (Test-Path -Path $scriptPath) {
        $result = & $scriptPath -Options $Options -Mode 'Test'
        return $result
    } else {         
        Write-Error -Message "Unable to find provisioner script [$scriptPath]"
    }
}

end {
    Write-Debug -Message 'Powershell script provisioner test: ending'
}