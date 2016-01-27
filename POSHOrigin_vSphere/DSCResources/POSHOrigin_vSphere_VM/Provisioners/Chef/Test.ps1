[cmdletbinding()]
param(
    [parameter(mandatory)]
    $Options
)

begin {
    Write-Debug -Message 'Chef provisioner test: beginning'
}

process {
    # Test to see if the Chef client is already installed

    $provOptions = ConvertFrom-Json -InputObject $Options.Provisioners
    $chefOptions = ($provOptions | Where-Object {$_.name -eq 'chef'}).options

    $result = $false
    try {

        # Get target IP address
        $t = Get-VM -Id $options.vm.Id -Verbose:$false -Debug:$false
        $ip = $t.Guest.IPAddress | Where-Object { ($_ -notlike '169.*') -and ( $_ -notlike '*:*') } | Select-Object -First 1

        if ($null -ne $ip -and $ip -ne [string]::Empty) {
            $chefSvc = Invoke-Command -ComputerName $ip -Credential $Options.GuestCredentials -ScriptBlock { Get-Service -Name chef-client -ErrorAction SilentlyContinue } -Verbose:$false
            $result = $true
            if ($chefSvc) {

                # Get the node
                $params = @{
                    Method = 'GET'
                    OrgUri = $chefOptions.url
                    Path = "/nodes/$($chefOptions.NodeName)"
                    UserItem = (Split-Path -Path $chefOptions.clientKey -Leaf).Split('.')[0]
                    KeyPath = $chefOptions.clientKey
                }
                $chefNode = & "$PSScriptRoot\Helpers\_InvokeChefQuery.ps1" @params

                # If we found a node in Chef, do extra validation
                if ($chefNode) {
                    # Verify environment
                    if ($chefOptions.environment) {
                        if ($chefNode.chef_environment.ToLower() -ne $chefOptions.environment.ToLower()) {
                            Write-Verbose -Message "Chef environment doesn't match [$($chefNode.chef_environment.ToLower()) <> $($chefOptions.environment.ToLower()))]"
                            $result = $false
                        }
                    }

                    # Verify run list matches
                    if (@($chefNode.run_list).Count -ne @($chefOptions.runlist).Count) {
                        $currList = @($chefNode.run_list) | Sort
                        $currList = @($chefNode.run_list) | Sort
                        $configList = @($chefOptions.runlist) | ForEach-Object {
                            if ($_.recipe) {
                                "recipe[$($_.recipe)]"
                            } elseif ($_.role) {
                                "role[$($_.role)]"
                            }
                        }
                        if ($null -eq $configList) { $configList = @()}
                        $configList = $configList | sort

                        if (Compare-Object -ReferenceObject $configList -DifferenceObject $currList) {
                            Write-Verbose -Message "Chef run list does not match"
                            $result = $false
                        }
                    }

                    # Verify attributes
                    # If we didn't specify any desired attributes, create an empty set
                    # so we can compare it against Chef
                    # Chef node attributes usually have an empty tags attributes by default
                    # so add that to the reference if isn't doesn't already exist
                    if (-Not $ChefOptions.attributes) {
                        $chefOptions | Add-Member -MemberType NoteProperty -Name attributes -Value @{tags = @{}}
                    } else {
                        if (-Not $ChefOptions.attributes.tags) {
                            $chefOptions.attributes | Add-Member -MemberType NoteProperty -Name tags -Value @{}
                        }
                    }
                    $refJson = $chefOptions.attributes | ConvertTo-Json
                    $diffJson = $chefNode.normal | ConvertTo-Json
                    if ($diffJson -ne $refJson) {
                        Write-Verbose -Message "Chef attributes do not match"
                        $result = $false
                    }
                } else {
                    Write-Verbose -Message 'Chef client is installed but node could not be found on Chef server'
                    $result = $false
                }
            } else {
                Write-Verbose -Message 'Chef client not found'
                $result = $false
            }
        } else {
            throw 'No valid IP address returned from VM view. Can not test for Chef client'
        }

        $match = if ( $result) { 'MATCH' } else { 'MISMATCH' }
        Write-Verbose -Message "Chef provisioner: $match"
        return $result
    } catch {
        Write-Error -Message 'There was a problem testing for the Chef client'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error $_
        return $false
    }
}

end {
    Write-Debug -Message 'Chef provisioner test: ending'
}