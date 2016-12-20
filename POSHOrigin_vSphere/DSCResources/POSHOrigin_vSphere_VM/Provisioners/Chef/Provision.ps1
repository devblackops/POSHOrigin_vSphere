[cmdletbinding()]
param(
    [parameter(mandatory)]
    $Options
)

begin {
    Write-Debug -Message 'Chef provisioner: beginning'
}

process {
    try {
        Write-Verbose -Message 'Configuring Chef client...'
        $provOptions = ConvertFrom-Json -InputObject $Options.Provisioners
        $chefOptions = ($provOptions | Where-Object {$_.name -eq 'chef'}).options

        $t = Get-VM -Id $Options.vm.Id -Verbose:$false -Debug:$false
        #$ip = $t.Guest.IPAddress | Where-Object { ($_ -notlike '169.*') -and ( $_ -notlike '*:*') } | Select-Object -First 1
        $ip = _GetGuestVMIPAddress -VM $t
        if ($null -ne $ip -and $ip -ne [string]::Empty) {

            $chefSvc = Invoke-Command -ComputerName $ip -Credential $Options.GuestCredentials -ScriptBlock { Get-Service -Name chef-client -ErrorAction SilentlyContinue } -Verbose:$false
            if (-Not $chefSvc) {
                # Invoke a local command on the target to install Chef
                $cmd = {
                    $VerbosePreference = $Using:VerbosePreference
                    Write-Verbose -Message 'Installing Chef client...'
                    try {
                        $options = $args[0]
                        $provOptions = $args[1]
                        $source = $provOptions.source
                        $sourceName = 'chef-client.msi'
                        $validatorKey = $provOptions.validatorKey
                        $validatorName = $validatorKey.split('/') | Select-Object -Last 1
                        $cert = $provOptions.cert
                        $certName = $cert.split('/') | Select-Object -Last 1
                        $runList = $provOptions.runList
                        $automateUrl = $provOptions.automateUrl
                        $automateToken = $provOptions.automateToken
                        $automateCert = $provOptions.automateCert
                        if ($automateCert) {
                            $automateCertName = $automateCert.split('/') | Select-Object -Last 1
                        }

                        # Ensure Chef node name is always lowercase
                        $fqdnlower = $provOptions.nodeName.ToLower()

                        # Copy Chef items locally
                        New-Item -Path "C:\Windows\Temp\ChefClient" -ItemType Directory -Force
                        Invoke-WebRequest -Uri $source -OutFile "c:\windows\temp\ChefClient\$sourceName"
                        Invoke-WebRequest -Uri $validatorKey -OutFile "c:\windows\temp\ChefClient\validator.pem"
                        Invoke-WebRequest -Uri $cert -OutFile "c:\windows\temp\ChefClient\$certName"
                        if ($automateCert) {
                            Invoke-WebRequest -Uri $automateCert -OutFile "C:\Windows\Temp\ChefClient\$automateCertName"
                        }

                        # Install Chef MSI
                        $params = @{
                            FilePath = 'msiexec'
                            ArgumentList = '/qn /i c:\windows\temp\ChefClient\' + $sourceName + ' ADDLOCAL="ChefClientFeature,ChefServiceFeature"'
                            Wait = $true
                        }
                        Start-Process @params

                        # Add Chef to env vars
                        If ($env:Path -notmatch 'C:\\opscode\\chef\\bin' -and $env:Path -notmatch 'c:\\opscode\\chef\\embedded\\bin') {
                            [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin", [System.EnvironmentVariableTarget]::Machine)
                            $env:Path = $env:Path + ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"
                        }

                        # Create knife.rb
                        $url = $provOptions.url
                        $validatorClientName = $validatorName.split('.')[0]
                        $knifeRB= @"
current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "$fqdnlower"
client_key               "c:\\chef\\client.pem"
validation_client_name   "$validatorClientName"
validation_key           "c:\\chef\\validator.pem"
chef_server_url          "$url"
cookbook_path            ["C:\\chef_cookbooks"]
"@
                        if ($automateUrl) {
                        $clientRB = @"
chef_server_url             "$url"
validation_client_name      "$validatorClientName"
validation_key              "c:\\chef\\validator.pem"
client_key                  "c:\\chef\\client.pem"
node_name                   '$fqdnlower'
data_collector.server_url   "$automateUrl"
data_collector.token        "$automateToken"
"@
                        } else {
                        $clientRB = @"
chef_server_url         "$url"
validation_client_name  "$validatorClientName"
validation_key          "c:\\chef\\validator.pem"
client_key              "c:\\chef\\client.pem"
node_name               '$fqdnlower'
"@
                }
                        New-Item -Path "$HOME\.chef" -ItemType Directory -ErrorAction SilentlyContinue -Force
                        $knifeRB | Out-File -FilePath "$HOME\.chef\knife.rb" -Encoding ascii -Force
                        $clientRB | Out-File -FilePath 'c:\chef\client.rb' -Encoding ascii -Force

                        # Copy certs
                        New-Item -Path "$HOME\.chef\trusted_certs" -ItemType Directory -ErrorAction SilentlyContinue
                        New-Item -Path 'c:\chef\trusted_certs' -Type Directory -Force -ErrorAction SilentlyContinue
                        Copy-Item -Path "c:\windows\temp\ChefClient\$certName" -Destination 'c:\chef\trusted_certs' -Force
                        Copy-Item -Path "c:\windows\temp\ChefClient\$certName" -Destination "$HOME\.chef\trusted_certs" -Force
                        Copy-Item -Path "c:\windows\temp\ChefClient\validator.pem" -Destination 'c:\chef' -Force
                        if ($automateCert) {
                            Copy-Item -Path "c:\windows\temp\ChefClient\$automateCertName" -Destination 'c:\chef\trusted_certs' -Force
                        }

                        # Start Chef as service
                        Start-Process -FilePath 'chef-service-manager' -ArgumentList '-a install' -NoNewWindow -Wait
                        Start-Process -FilePath 'chef-service-manager' -ArgumentList '-a start' -NoNewWindow -Wait
                        Start-Process -FilePath 'chef-client' -NoNewWindow -Wait

                        # Cleanup
                        Remove-Item -Path "c:\chef\validator.pem" -Force
                        Remove-Item -Path 'c:\windows\temp\chefclient\' -Recurse -Force

                        Write-Verbose -Message 'Chef installed. Sleeping...'
                        Start-Sleep -Seconds 5
                        return $true
                    } catch {
                        Write-Error -Message 'There was a problem installing the Chef client'
                        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
                        write-Error $_
                        return $false
                    }
                }
                $params = @{
                    ComputerName = $ip
                    Credential = $Options.GuestCredentials
                    ScriptBlock = $cmd
                    ArgumentList = @($Options, $chefOptions)
                }
                $chefInstallResult = Invoke-Command @params
            }

            # Chef is already installed or was just installed
            if ($chefSvc -or $chefInstallResult) {
            
                # Check automate settings if any, and update if needed
                $automateCmd = {
                    $VerbosePreference = $Using:VerbosePreference
                    $chefOptions = $args[0]
                    $automateUrl = $chefOptions.automateUrl
                    $automateToken = $chefOptions.automateToken
                    $automateCert = $chefOptions.automateCert
                    $automateCertName = $automateCert.split('/') | Select-Object -Last 1
                    $testExists = Test-Path "C:\chef\trusted_certs\$automateCertName"
                    if (!($testExists)) {
                        Invoke-WebRequest -Uri "$automateCert" -OutFile "C:\chef\trusted_certs\$automateCertName" | Out-Null
                    } else {
                        Invoke-WebRequest -Uri "$automateCert" -OutFile "C:\chef\$automateCertName" | Out-Null
                        $serverVersion = Get-Content "C:\chef\trusted_certs\$automateCertName"
                        $currentVersion = Get-Content "C:\chef\$automateCertName"
                        $compare = Compare-Object $serverVersion $currentVersion
                        Start-Sleep -Seconds 1
                        if ($compare) {
                            Write-Verbose -Message "Updated chef automate cert"
                            Move-Item -Path "C:\chef\$automateCertName" -Destination "C:\chef\trusted_certs\$automateCertName" -Force -Confirm:$false
                        } else {
                            Remove-Item -Path "C:\chef\$automateCertName" -Force -Confirm:$false
                        }
                    }
                    $clientRB = Get-Content C:\chef\client.rb -ErrorAction SilentlyContinue | Out-String
                        $autoUrl = "(.*)data_collector.server_url\s+'$automateUrl(.*)'"
                        $autoToken = "(.*)data_collector.token\s+'$automateToken(.*)'"
                    if ($clientRB -notmatch $autoUrl) {
                        if ($clientRB -like "*data_collector.server_url*") {
                            $clientRB = Get-Content C:\chef\client.rb -ErrorAction SilentlyContinue
                            $clientRB | foreach-Object {$_ -replace "^.*data_collector.server_url.*$","data_collector.server_url`t'$automateUrl'"} | set-content C:\chef\client.rb
                            Write-Verbose 'Updated chef client.rb for automate url'
                        } else {
                            Add-Content C:\chef\client.rb -Value "`r`ndata_collector.server_url`t'$automateUrl'"
                            Write-Verbose 'Created entry in client.rb for automate url'
                        }
                    }

                    $clientRB = Get-Content C:\chef\client.rb -ErrorAction SilentlyContinue | Out-String
                    if ($clientRB -notmatch $autoToken) {
                        if ($clientRB -like "*data_collector.token*") {
                            $clientRB = Get-Content C:\chef\client.rb -ErrorAction SilentlyContinue
                            $clientRB | foreach-Object {$_ -replace "^.*data_collector.token.*$","data_collector.token`t'$automateToken'"} | set-content C:\chef\client.rb
                            Write-Verbose 'Updated chef client.rb for automate token'
                        } else {
                            Add-Content C:\chef\client.rb -Value "`r`ndata_collector.token`t'$automateToken'"
                            Write-Verbose 'Created entry in client.rb for automate token'
                        }
                    }
                }
                $automateParams = @{
                    ComputerName = $ip
                    Credential = $Options.GuestCredentials
                    ScriptBlock = $automateCmd
                    ArgumentList = $chefOptions
                }

                if ($chefOptions.automateUrl) {
                    Invoke-Command @automateParams
                }

                # Get the node from Chef
                $getParams = @{
                    Method = 'GET'
                    OrgUri = $chefOptions.url
                    Path = "/nodes/$($chefOptions.NodeName)"
                    UserItem = (Split-Path -Path $chefOptions.clientKey -Leaf).Split('.')[0]
                    KeyPath = $chefOptions.clientKey
                }
                $chefNode = & "$PSScriptRoot\Helpers\_InvokeChefQuery.ps1" @getParams

                if ($chefNode) {
                    # Verify run list
                    if (@($chefNode.run_list).Count -ne @($chefOptions.runlist).Count) {
                        Write-Verbose -Message "Chef run list does not match"

                        # Update the run list on the node
                        $chefNode.run_List = @(@($chefOptions.runlist) | ForEach-Object {
                            if ($_.recipe) {
                                "recipe[$($_.recipe)]"
                            } elseif ($_.role) {
                                "role[$($_.role)]"
                            }
                        })

                        # Send the json to the Chef API
                        $newRunList = $chefNode.Run_List -join ','
                        Write-Verbose -Message "Assigning run list: $newRunList"
                        $putParams = @{
                            Method = 'PUT'
                            OrgUri = $chefOptions.url
                            Path = "/nodes/$($chefOptions.NodeName)"
                            UserItem = (Split-Path -Path $chefOptions.clientKey -Leaf).Split('.')[0]
                            KeyPath = $chefOptions.clientKey
                            data = $ChefNode | ConvertTo-Json
                        }
                        $putResult = & "$PSScriptRoot\Helpers\_InvokeChefQuery.ps1" @putParams
                    }

                    # Verify environment
                    if ($chefOptions.environment) {
                        if ($chefNode.chef_environment.ToLower() -ne $chefOptions.environment.ToLower()) {
                            $chefNode.chef_environment = $chefOptions.environment.ToLower()
                            Write-Verbose -Message "Changing environment to [$($chefNode.chef_environment.ToLower())]"
                            $putParams = @{
                                Method = 'PUT'
                                OrgUri = $chefOptions.url
                                Path = "/nodes/$($chefOptions.NodeName)"
                                UserItem = (Split-Path -Path $chefOptions.clientKey -Leaf).Split('.')[0]
                                KeyPath = $chefOptions.clientKey
                                data = $ChefNode | ConvertTo-Json
                            }
                            $putResult = & "$PSScriptRoot\Helpers\_InvokeChefQuery.ps1" @putParams
                        }
                    }

                    # Assign attributes if needed
                    # If we didn't specify any desired attributes, create an empty set
                    # so we can compare it against Chef
                    # Chef node attributes usually have an empty tags attributes by default
                    # so add that to the reference if isn't doesn't already exist
                    if (-Not $ChefOptions.attributes) {
                        $chefOptions | Add-Member -MemberType NoteProperty -Name attributes -Value @{tags = @()}
                    } else {
                        if (-Not $ChefOptions.attributes.tags) {
                            $chefOptions.attributes | Add-Member -MemberType NoteProperty -Name tags -Value @()
                        }
                    }
                    $refJson = $chefOptions.attributes | ConvertTo-Json
                    $diffJson = $chefNode.normal | ConvertTo-Json
                    if ($diffJson -ne $refJson) {
                        # Attributes don't match so update them
                        Write-Verbose -Message "Setting node attributes to `n $refJson"
                        $chefNode.normal = $chefOptions.attributes
                        $putParams = @{
                            Method = 'PUT'
                            OrgUri = $chefOptions.url
                            Path = "/nodes/$($chefOptions.NodeName)"
                            UserItem = (Split-Path -Path $chefOptions.clientKey -Leaf).Split('.')[0]
                            KeyPath = $chefOptions.clientKey
                            data = $chefNode | ConvertTo-Json
                        }
                        $putResult = & "$PSScriptRoot\Helpers\_InvokeChefQuery.ps1" @putParams
                    }
                } else {
                    Write-Error -Message "Unable to get find node $chefOptions.NodeName"
                }
            } else {
                Write-Error -Message 'There was a problem installing the Chef client. No validation of the Chef client will be done.'
            }
        } else {
           Write-Error -Message 'No valid IP address returned from VM view. Can not configure the Chef client'
        }
    } catch {
        Write-Error -Message 'There was a problem running the Chef provisioner'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error $_
        return $false
    }
}

end {
    Write-Debug -Message 'Chef provisioner: ending'
}