function _CreateVM {
    [cmdletbinding(DefaultParameterSetName='cluster')]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$VMTemplate,

        [Parameter(Mandatory, ParameterSetName ='cluster')]
        [ValidateNotNullOrEmpty()]
        [string]$Cluster,
        
        [Parameter(Mandatory, ParameterSetName = 'resourcepool')]
        [ValidateNotNullOrEmpty()]
        [string]$ResourcePool,
        
        [Parameter(Mandatory, ParameterSetName = 'vmhost')]
        [ValidateNotNullOrEmpty()]
        [string]$VMHost,
        
        [Parameter(Mandatory, ParameterSetName = 'vapp')]
        [ValidateNotNullOrEmpty()]
        [string]$vApp,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$InitialDatastore,

        [Parameter(Mandatory)]
        [ValidateSet('Thick','Thin','EagerZeroedThick')]
        [string]$DiskFormat,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NICSpec,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CustomizationSpec,

        [string]$Folder = [string]::Empty

        <#
        [string]$IPAMFqdn,

        [pscredential]$IPAMCredentials
        #>
    )

    try {
        $continue = $true
        $sdrs = $false

        # Resolve VM template
        $template = Get-Template -Name $VMTemplate -verbose:$false | Select-Object -First 1
        if ($template -ne $null) { 
            Write-Debug -Message "Template: $($template.Name)"
        } else {
            Write-Error -Message "Unable to resolve template $VMTemplate"
            $continue = $false
        }
        
        switch ($PSCmdlet.ParameterSetName) {
            'cluster' {
                # Resolve cluster
                $viContainer = Get-Cluster -Name $Cluster -Verbose:$false -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($viContainer -ne $null) { 
                    Write-Debug -Message "Cluster: $($viContainer.Name)"
                } else {
                    Write-Error -Message "Unable to resolve cluster [$Cluster]"
                    $continue = $false
                }
            }
            'vmhost' {
                # Resolve VM host
                $viContainer = Get-VMHost -Name $VMHost -Verbose:$false -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($null -ne $viContainer) {
                    Write-Debug -Message "VMHost: $($viContainer.Name)"
                } else {
                    Write-Error -Message "Unable to resolve VM host [$VMHost]"
                    $continue = $false
                }
            }
            'resourcepool' {
                # Resolve VM host
                $viContainer = Get-ResourcePool -Name $ResourcePool -Verbose:$false -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($null -ne $viContainer) {
                    Write-Debug -Message "Resource Pool: $($viContainer.Name)"
                } else {
                    Write-Error -Message "Unable to resolve resource pool [$ResourcePool]"
                    $continue = $false
                }
            }
            'vapp' {
                # Resolve vApp
                $viContainer = Get-VApp -Name $vApp -Verbose:$false -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($null -ne $viContainer) {
                    Write-Debug -Message "vApp: $($viContainer.Name)"
                } else {
                    Write-Error -Message "Unable to resolve vApp [$vApp]"
                    $continue = $false
                }
            }
        }

        # Resolve datastore / datastore cluster
        $datastore = Get-Datastore -Name $InitialDatastore -verbose:$false -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($datastore -ne $null) {
            Write-Debug -Message "Datastore: $($datastore.Name)"
        } else {
            $datastore = Get-DatastoreCluster -Name $InitialDatastore -verbose:$false -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($datastore -ne $null) {
                $sdrs = $true
                Write-Debug -Message "Datastore cluster: $InitialDatastore"
            } else {
                Write-Error -Message "Unable to resolve datastore or datastore cluster [$InitialDatastore]"
                $continue = $false
            }
        }

        # Resolve folder to put VM into
        if ($Folder -ne [string]::Empty) {
            $vmFolder = _GetVMFolderByPath -Path $Folder -ErrorAction SilentlyContinue
            if (!$vmFolder) {
                Write-Error -Message "Unable to resolve folder [$Folder]"
                $continue = $false
            }
        } else {
            $vmFolder = $null
        }

        # Verify any IP addresses defined in configuration are not already in use
        # and resolve network portgroups
        $netConfigs = $NICSpec | ConvertFrom-Json
        foreach ($netConfig in $netConfigs) {
            
            # Verify the IP address(s) that we're about to set are not already in use
            if ($netConfig.IPAddress) {                
                Write-Debug -Message "Pinging $($netConfig.IPAddress)"                
                $pingable = Test-Connection -ComputerName $netConfig.IPAddress -Count 2 -Quiet
                if ($pingable) {
                    Write-Error -Message "$($netConfig.IPAddress) appears to already be in use."
                    $continue = $false
                }
            }

            if ($null -eq (Get-VDPortGroup -Name $netConfig.PortGroup -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false)) {
                if ($null -eq (Get-VirtualPortGroup -Name $netConfig.PortGroup -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false)) {
                    Write-Error -Message "Unable to resolve portgroup $($netConfig.PortGroup)"
                    $continue = $false
                }
            }
        }

        # Resolve OS customization spec
        $custSpec = Get-OSCustomizationSpec -Name $CustomizationSpec -Type Persistent -Verbose:$false -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $custSpec) {
            Write-Error -Message "Unable to resolve OS customization spec $CustomizationSpec"
            $continue = $false
        }

        <#
        # If the configuration says to get an IP from IPAM
        # let's try to resolve that first before creating the VM
        $netConfigs = @(ConvertFrom-Json -InputObject $NICSpec)
        $custSpecInstr = @()
        foreach ($netConfig in $netConfigs) {
            if ($netConfig.IPAssignment -eq 'IPAMNextAvailable') {
                Write-Verbose -Message 'Attempting to reserve IP in IPAM..'
                $IPInfo = _RequestInfoBloxIP -Name $VM.Name -Network $netConfig.Network -GridServer $IPAMFqdn -Credential $IPAMCredentials
                $custSpecInstr += @{
                    OSCustomizationSpec = $null
                    IpMode = 'UseStaticIp'
                    IpAddress = $IPInfo.ipv4addr 
                    SubnetMask = $netInfo.subnetMask
                    DefaultGateway = $netInfo.gateway 
                    Dns = $netConfig.DNSServers
                }
            }
        }
        #>

        $vm = $null
        # Do we have all the information we need to provision the VM?
        if ($continue) {
            Write-Verbose "Creating VM [$Name]"
            
            # Create VM asynchronously and get task object
            $t = $null
            $params = @{
                Name = $Name
                Template = $template
                Datastore = $datastore
                #DiskStorageFormat = $diskFormat
                ResourcePool = $viContainer
                OSCustomizationSpec = $custSpec
                RunAsync = $true
                Verbose = $false
                Confirm = $false
            }
            if (-not $sdrs) {
                $params.DiskStorageFormat = $diskFormat
            }
            if ($null -ne $vmFolder) {
                $params.Location = $vmFolder
            }
            $t = New-VM @params

            #if ($sdrs) {
            #    $t = New-VM -Name $Name -Template $template -Datastore $datastore -ResourcePool $clus -RunAsync -Verbose:$false -Confirm:$false
            #} else {
            #    $t = New-VM -Name $Name -Template $template -Datastore $datastore -ResourcePool $clus -DiskStorageFormat $diskFormat -RunAsync -Verbose:$false -Confirm:$false
            #}

            # Wait for task to complete
            while ($t.State.ToString().ToLower() -eq 'running') {
                Write-Verbose -Message "VM creation $($t.PercentComplete)% complete"
                Start-Sleep -Seconds 10
                $t = Get-Task -Id $t.Id -Verbose:$false -Debug:$false
            }
            $t = Get-Task -Id $t.Id -Verbose:$false -Debug:$false

            if ($t.State.ToString().ToLower() -eq 'success') {
                #$vm = Get-VM -Id $t.Result.Vm -Verbose:$false -Debug:$false
                $vm = Get-VM -Name $Name -Verbose:$false -Debug:$false
            }

            if ($null -eq $vm) {
                throw 'VM failed to create'
            }
        } else {
            Write-Error 'Could not resolve required VMware objects needed to create this VM'
        }
    } catch {
        Write-Error 'There was a problem creating the VM'
        Write-Error "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        Write-Error $_
    }
    return $vm
}