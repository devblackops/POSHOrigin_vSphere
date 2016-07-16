[cmdletbinding()]
param(
    [parameter(mandatory)]
    $Options
)

begin {
    Write-Debug -Message 'Chef deprovisioner: beginning'
}

process {
    try {
        Write-Verbose -Message 'Deleting node from Chef...'
        $provOptions = ConvertFrom-Json -InputObject $Options.Provisioners
        $chefOptions = ($provOptions | Where-Object {$_.name -eq 'chef'}).Options
        
        $params = @{
            Method = 'DELETE'
            OrgUri = $chefOptions.url
            Path = "/nodes/$($chefOptions.NodeName)"
            UserItem = (Split-Path -Path $chefOptions.clientKey -Leaf).Split('.')[0]
            KeyPath = $chefOptions.clientKey
        }
        
        # Delete the "node"
        & "$PSScriptRoot\Helpers\_InvokeChefQuery.ps1" @params
        
        # Delete the "client"
        $params.Path = "/clients/$($chefOptions.NodeName)"
        & "$PSScriptRoot\Helpers\_InvokeChefQuery.ps1" @params
    } catch {
        Write-Error -Message 'There was a problem running the Chef provisioner'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error $_
        return $false
    }
}

end {
    Write-Debug -Message 'Chef deprovisioner: ending'
}