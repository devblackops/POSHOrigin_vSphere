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
        #$ip = $t.Guest.IPAddress | Where-Object { ($_ -notlike '169.*') -and ( $_ -notlike '*:*') } | Select-Object -First 1
        $ip = _GetGuestVMIPAddress -VM $t

        if ($null -ne $ip -and $ip -ne [string]::Empty) {
            $chefSvc = Invoke-Command -ComputerName $ip -Credential $Options.GuestCredentials -ScriptBlock { Get-Service -Name chef-client -ErrorAction SilentlyContinue } -Verbose:$false
            $chefSvcResult = $true
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
                $chefNodeResult = $true
                if ($chefNode) {
                    # Verify environment
                    $envResult = $true
                    if ($chefOptions.environment) {
                        if ($chefNode.chef_environment.ToLower() -ne $chefOptions.environment.ToLower()) {
                            Write-Verbose -Message "Chef environment: MISMATCH [$($chefNode.chef_environment.ToLower()) <> $($chefOptions.environment.ToLower()))]"
                            $envResult = $false
                        }
                    }
                    if ($envResult) {
                        Write-Verbose -Message "Chef environment: MATCH"
                    }

                    # Verify run list matches
                    $runlistResult = $true
                    if (-not $chefOptions.runlist -and $chefOptions.runList.Count -ne 0) {
                        $chefOptions | Add-Member -MemberType NoteProperty -Name runlist -Value @()
                    }
                    if ($chefOptions.runlist.Count -gt 0) {
                        # Create a string array of our runlist so we can easily compare it
                        # to what we get back from the Chef API
                        $refRunList = @($chefOptions.runlist) | ForEach-Object {
                            if ($_.recipe) {
                                "recipe[$($_.recipe)]"
                            } elseif ($_.role) {
                                "role[$($_.role)]"
                            }
                        }
                        $diffRunList = @($chefNode.run_list)
                        if ($diffRunList.Count -gt 0) {
                            # Compare the Chef node runlist to what our desired runlist is
                            if (Compare-Object -ReferenceObject $refRunList -DifferenceObject $diffRunList) {
                                $runlistResult = $false
                            }
                        } else {
                            # The Chef node has no runlist but should
                            $runlistResult = $false
                        }
                    } else {
                        # Our desired runlist is nothing. Check if Chef node has a run list
                        if ($chefNode.run_list.count -gt 0) {
                            $runlistResult = $false
                        }
                    }
                    if (-Not $runListResult) {
                        Write-Verbose -Message "Chef runlist: MISMATCH"
                    } else {
                        Write-Verbose -Message "Chef runlist: MATCH"
                    }

                    # Verify attributes
                    # If we didn't specify any desired attributes, create an empty set
                    # so we can compare it against Chef
                    # Chef node attributes usually have an empty tags attributes by default
                    # so add that to the reference if isn't doesn't already exist
                    $attributeResult = $true
                    if (-Not $ChefOptions.attributes) {
                        $chefOptions | Add-Member -MemberType NoteProperty -Name attributes -Value @{tags = @()}
                    } else {
                        if (-Not $ChefOptions.attributes.tags) {
                            $chefOptions.attributes | Add-Member -MemberType NoteProperty -Name tags -Value @()
                        }
                    }
                    $refJson = $chefOptions.attributes | ConvertTo-Json
                    $diffJson = $chefNode.normal | ConvertTo-Json

                    Write-Debug -Message 'Ref'
                    Write-Debug -Message $refJson
                    Write-Debug -Message 'Diff'
                    Write-Debug -Message $diffJson

                    if ($diffJson -ne $refJson) {
                        Write-Verbose -Message "Chef attributes: MISMATCH"
                        $attributeResult = $false
                    } else {
                        Write-Verbose -Message "Chef attributes: MATCH"
                    }
                } else {
                    $chefNodeResult = $false
                    Write-Verbose -Message 'Chef client: installed but node could not be found on Chef server'
                }
            } else {
                Write-Verbose -Message 'Chef client: not found'
                $chefSvcResult = $false
            }
        } else {
            throw 'No valid IP address returned from VM view. Can not test for Chef client'
        }

        $result = ($chefSvcResult -and $chefNodeResult -and $envResult -and $runlistResult -and $attributeResult)
        $match = if ($result) { 'MATCH' } else { 'MISMATCH' }
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