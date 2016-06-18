# Load helpers
Get-ChildItem -Path "$psscriptroot\Helpers" | ForEach-Object {
    Write-Debug -Message "Loading helper function $($_.Name)"
    . $_.FullName
}

$script:VCConnected = $false

function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.Boolean]
        $PowerOnAfterCreation,

        [System.Management.Automation.PSCredential]
        $vCenterCredentials,

        [System.Int32]
        $TotalvCPU,

        [System.Int32]
        $CoresPerSocket,

        [System.Int32]
        $vRAM,

        [System.String]
        $Disks,

        [System.String]
        $Networks,

        [System.String]
        $VMTemplate,

        [System.String]
        $VMFolder,

        [System.String]
        $CustomizationSpec,
        
        [System.String]
        $Tags,
        
        [System.Boolean]
        $UpdateTools = $false,

        [System.Management.Automation.PSCredential]
        $GuestCredentials,

        [System.Management.Automation.PSCredential]
        $IPAMCredentials,

        [System.Management.Automation.PSCredential]
        $DomainJoinCredentials,

        [System.String]
        $IPAMFqdn,

        [System.String]
        $vCenter,

        [System.String]
        $Datacenter,

        [System.String]
        $InitialDatastore,

        [System.String]
        $Cluster,
        
        [System.String]
        $ResourcePool,

        [System.String]
        $VMHost,
        
        [System.String]
        $vApp,

        [System.String]
        $Provisioners
    )

    $returnValue = @{
        Name = $Name
        Ensure = $Ensure
        PowerOnAfterCreation = $PowerOnAfterCreation
        vCenterCredentials = $vCenterCredentials
        TotalvCPU = $TotalvCPU
        CoresPerSocket = $CoresPerSocket
        vRAM = $vRAM
        Disks = $Disks
        Networks = $Networks
        VMTemplate = $VMTemplate
        CustomizationSpec = $CustomizationSpec
        GuestCredentials = $GuestCredentials
        IPAMCredentials = $IPAMCredentials
        IPAMFqdn = $IPAMFqdn
        vCenter = $vCenter
        Datacenter =$Datacenter
        InitialDatastore = $InitialDatastore
        Cluster = $Cluster
        ResourcePool = $ResourcePool
        VMHost = $VMHost
        Tags = $Tags
        UpdateTools = $UpdateTools
        vApp = $vApp
        Provisioners = $Provisioners
    }

    $returnValue
}

function Set-TargetResource {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.Boolean]
        $PowerOnAfterCreation,

        [System.Management.Automation.PSCredential]
        $vCenterCredentials,

        [System.Int32]
        $TotalvCPU,

        [System.Int32]
        $CoresPerSocket,

        [System.Int32]
        $vRAM,

        [System.String]
        $Disks,

        [System.String]
        $Networks,

        [System.String]
        $VMTemplate,

        [System.String]
        $VMFolder,

        [System.String]
        $CustomizationSpec,
        
        [System.String]
        $Tags,
        
        [System.Boolean]
        $UpdateTools = $false,

        [System.Management.Automation.PSCredential]
        $GuestCredentials,

        [System.Management.Automation.PSCredential]
        $IPAMCredentials,

        [System.Management.Automation.PSCredential]
        $DomainJoinCredentials,

        [System.String]
        $IPAMFqdn,

        [System.String]
        $vCenter,

        [System.String]
        $Datacenter,

        [System.String]
        $InitialDatastore,

        [System.String]
        $Cluster,
        
        [System.String]
        $ResourcePool,
        
        [System.String]
        $VMHost,
        
        [System.String]
        $vApp,

        [System.String]
        $Provisioners
    )

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1

    try {
        # Connect to vCenter
        $script:VCConnected = _ConnectTovCenter -vCenter $vCenter -Credential $vCenterCredentials

        $newVM = $false
        $vm = Get-VM -Name $Name -Verbose:$false -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($Ensure -eq 'Present') {

            # Create the VM if needed
            if ($null -eq $vm) {

                $diskSpec = ConvertFrom-Json -InputObject $Disks
                $format = $diskSpec[0].Format
                
                $continue = $true
                
                # Let's validate that only ONE of the following options was specified for the VM location
                # Cluster, ResourcePool, VMHost, vApp                
                $search = @('Cluster', 'ResourcePool', 'VMHost', 'vApp')
                if (($PSBoundParameters.Keys | Where-Object {$_ -in $search}).Count -gt 1) {
                    $continue = $false
                    $msg = "More than one option was specified for VM location. Please choose ONE of the following options"
                    $msg += "Cluster, ResourcePool, VMHost, or vApp"
                    Write-Error -Message $msg   
                }
                                              
                if ($continue) {
                    $params = @{
                        Name = $Name
                        VMTemplate = $VMTemplate
                        InitialDatastore = $InitialDatastore
                        DiskFormat = $format
                        NICSpec = $Networks
                        CustomizationSpec = $CustomizationSpec
                        #IPAMFqdn = $IPAMFqdn
                        #IPAMCredentials =  $IPAMCredentials
                    }
                    if ($PSBoundParameters.ContainsKey('VMFolder')) {
                        $params.Folder = $VMFolder
                    }                    
                    if ($PSBoundParameters.ContainsKey('Cluster')) {
                        $params.Cluster = $Cluster
                    }
                    if ($PSBoundParameters.ContainsKey('ResourcePool')) {
                        $params.ResourcePool = $ResourcePool
                    }
                    if ($PSBoundParameters.ContainsKey('VMHost')) {
                        $params.VMHost = $VMHost
                    }
                    if ($PSBoundParameters.ContainsKey('vApp')) {
                        $params.vApp = $vApp
                    }
                     
                    $vm = _CreateVM @params
                    if ($null -ne $vm) {
                        Write-Verbose -Message 'VM created successfully'
                        $newVm = $true
                    } else {
                        return
                    }

                    # Set NICs
                    $setNICResult = $false
                    $setNICResult = _SetVMNICs -vm $vm -NICSpec $Networks -CustomizationSpec $CustomizationSpec -IPAMFqdn $IPAMFqdn -IPAMCredentials $IPAMCredentials

                    if ($setNICResult -eq $false) {
                        throw 'Failed to set NICs after VM creation. Aborting...'
                    }
                }
            }
            
            if ($vm) {
                # Set RAM
                if (-not (_TestVMRAM -vm $vm -RAM $vRAM)) {
                    _SetVMRAM -vm $vm -RAM $vRAM
                }

                # Set vCPU
                if (-not (_TestVMCPU -vm $vm -TotalvCPU $TotalvCPU -CoresPerSocket $CoresPerSocket)) {
                    _SetVMCPU -vm $vm -TotalvCPU $TotalvCPU -CoresPerSocket $CoresPerSocket
                }
                
                # Set VM Folder
                if ($PSBoundParameters.ContainsKey('VMFolder')) {
                    if (-Not (_TestVMFolder -VM $VM -VMFolder $VMFolder)) {
                        _MoveVM -VM $VM -VMFolder $VMFolder
                    }
                }
                
                # Set tags
                if ($PSBoundParameters.ContainsKey('Tags')) {                    
                    if (-not (_TestTags -VM $VM -Tags $Tags)) {                        
                        _SetTags -VM $VM -Tags $Tags
                    }
                }

                # Set disks
                if (-not (_TestVMDisks -vm $vm -DiskSpec $Disks)) {
                    $updatedVMDisks = _SetVMDisks -vm $vm -DiskSpec $Disks
                }
                
                # Set NICS
                # TODO

                # Power on VM and wait for OS customization to complete
                if (-not (_TestVMPowerState -vm $vm -PowerOnAfterCreation $PowerOnAfterCreation)) {
                    _SetVMPowerState -vm $vm

                    # Wait for OS customization to complete if this is a newly created VM
                    if ($newVM -eq $true) {
                        _WaitForGuestCustomization -vm $vm
                    }

                    _WaitForVMTools -vm $vm -Credential $GuestCredentials
                }
                
                # Guest disks
                $vm = Get-VM -Name $Name -Verbose:$false -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($VM.PowerState -eq 'PoweredOn') {
                    if ($updatedVMDisks -eq $true) {
                        _refreshHostStorageCache -vm $vm -Credential $GuestCredentials
                    }

                    # Set guest disks
                    if (-not (_TestGuestDisks -vm $vm -DiskSpec $Disks -Credential $GuestCredentials)) {
                        _SetGuestDisks -vm $vm -DiskSpec $Disks -Credential $GuestCredentials
                    }
                } else {
                    Write-Warning -Message 'VM is powered off. Skipping guest check'
                }

                # Set guest disks
                if (-not (_TestGuestDisks -vm $vm -DiskSpec $Disks -Credential $GuestCredentials)) {
                    _SetGuestDisks -vm $vm -DiskSpec $Disks -Credential $GuestCredentials
                }
            } else {
                Write-Warning -Message 'VM is powered off. Skipping guest check'
            }

            # Set VM Folder
            if ($VMFolder -ne [string]::empty) {
                if (-Not (_TestVMFolder -VM $VM -VMFolder $VMFolder)) {
                    _MoveVM -VM $VM -VMFolder $VMFolder
                }
            }

            # VM Tools
            if ($UpdateTools) {
                if (-not (_TestVMTools -VM $VM)) {
                    _UpdateTools -VM $VM
                }    
            }   

            # Run any provisioners
            if ($Provisioners -ne [string]::Empty) {
                foreach ($p in (ConvertFrom-Json -InputObject $Provisioners)) {
                    $testPath = "$PSScriptRoot\Provisioners\$($p.name)\Test.ps1"
                    if (Test-Path -Path $testPath) {

                        $params = $PSBoundParameters
                        $params.vm = $vm
                        $params.ProvOptions = $p.options

                        $provisionerResult = (& $testPath $params)
                        if ($provisionerResult -ne $true) {
                            $provPath = "$PSScriptRoot\Provisioners\$($p.name)\Provision.ps1"
                            if (Test-Path -Path $testPath) {
                                $params = $PSBoundParameters
                                $params.vm = $vm
                                (& $provPath $params)
                            }
                        }
                    }
                }
            }
        } else {
            Write-Verbose '[Ensure == Absent] Beginning deprovisioning process'

            # Run through any provisioners we have defined and execute the 'deprovision' script
            if ($PSBoundParameters.ContainsKey('Provisioners')) {
                foreach ($p in (ConvertFrom-Json -InputObject $Provisioners)) {
                    $testPath = "$PSScriptRoot\Provisioners\$($p.name)\Test.ps1"
                    if (Test-Path -Path $testPath) {
                        $params = $PSBoundParameters
                        $params.vm = $vm
                        $params.ProvOptions = $p.options
                        $provisionerResult = (& $testPath $params)
                        if ($provisionerResult -eq $true) {
                            $provPath = "$PSScriptRoot\Provisioners\$($p.name)\Deprovision.ps1"
                            if (Test-Path -Path $testPath) {
                                $params = $PSBoundParameters
                                $params.vm = $vm
                                (& $provPath $params)
                            }
                        }
                    }
                }
            }

            # Connect to vCenter
            $script:VCConnected = _ConnectTovCenter -vCenter $vCenter -Credential $vCenterCredentials

            # Stop and delete VM
            $vm = Get-VM -Name $Name -Verbose:$false -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -ne $vm) {
                try {
                    if ($vm.PowerState -eq 'PoweredOn') {
                        Write-Verbose -Message 'Stopping VM'
                        $stopResult = $vm | Stop-VM -Confirm:$false -Verbose:$false
                        Write-Verbose -Message 'VM stopped'
                    }
                    if ($vm.PowerState -eq 'PoweredOff' -or $stopResult.PowerState -eq 'PoweredOff') {
                        $delResult = $vm | Remove-VM -DeletePermanently -Confirm:$false -Verbose:$false
                        Write-Verbose -Message 'VM deleted'
                    } else {
                        throw 'Unable to stop VM'
                    }
                } catch {
                    throw $_
                }
            }
        }
    } catch {
        Write-Error 'There was a problem setting the resource'
        Write-Error "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        Write-Error $_
    }
    _DisconnectFromvCenter -vCenter $vCenter
}

function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.Boolean]
        $PowerOnAfterCreation,

        [System.Management.Automation.PSCredential]
        $vCenterCredentials,

        [System.Int32]
        $TotalvCPU,

        [System.Int32]
        $CoresPerSocket,

        [System.Int32]
        $vRAM,

        [System.String]
        $Disks,

        [System.String]
        $Networks,

        [System.String]
        $VMTemplate,

        [System.String]
        $VMFolder,

        [System.String]
        $CustomizationSpec,
        
        [System.String]
        $Tags,
        
        [System.Boolean]
        $UpdateTools = $false,

        [System.Management.Automation.PSCredential]
        $GuestCredentials,

        [System.Management.Automation.PSCredential]
        $IPAMCredentials,

        [System.Management.Automation.PSCredential]
        $DomainJoinCredentials,

        [System.String]
        $IPAMFqdn,

        [System.String]
        $vCenter,

        [System.String]
        $Datacenter,

        [System.String]
        $InitialDatastore,

        [System.String]
        $Cluster,
        
        [System.String]
        $ResourcePool,
        
        [System.String]
        $VMHost,
        
        [System.String]
        $vApp,

        [System.String]
        $Provisioners
    )

    # Connect to vCenter
    $script:VCConnected = _ConnectTovCenter -vCenter $vCenter -Credential $vCenterCredentials

    $result = $true

    # Check if VM exists
    $vm = Get-VM -Name $Name -verbose:$false -ErrorAction SilentlyContinue | select -First 1
    if ($vm -ne $null) {
        Write-Verbose -Message "VM exists"
    } else {
        Write-Verbose -Message "VM does not exist"
    }

    # If VM exists, is it supposed to?
    if ($Ensure -eq 'Present') {
        if (-Not $vm) {
            Write-Information -Message "$Name should exist but doesn't"
            return $false
        }
    } else {
        if (-Not $vm) {
            Write-Information -Message "$Name doesn't exist and should not"
            return $true
        } else {
            Write-Information -Message "$Name shouldn't exist but does"
            return $false
        }
    }

    #region Run through tests
    # RAM
    $ramResult = _TestVMRAM -VM $vm -RAM $vRAM
    $match = if ( $ramResult) { 'MATCH' } else { 'MISMATCH' }
    Write-Verbose -Message "RAM: $match"

    # CPU
    $cpuResult = _TestVMCPU -vm $vm -TotalvCPU $TotalvCPU -CoresPerSocket $CoresPerSocket
    $match = if ( $cpuResult) { 'MATCH' } else { 'MISMATCH' }
    Write-Verbose -Message "vCPU: $match"
    
    # Test VM folder
    $folderResult = $true
    if ($PSBoundParameters.ContainsKey('VMFolder')) {
        $folderResult = _TestVMFolder -VM $vm -VMFolder $VMFolder
        $match = if ( $folderResult) { 'MATCH' } else { 'MISMATCH' }
        Write-Verbose -Message "VM Folder: $match"
    }
    
    # Tags
    $tagResult = $true
    if ($PSBoundParameters.ContainsKey('Tags')) {
        $tagResult = _TestTags -VM $VM -Tags $Tags
    }
    $match = if ( $tagResult) { 'MATCH' } else { 'MISMATCH' }
    Write-Verbose -Message "Tags: $match"    

    # Disks
    $vmDiskResult = _TestVMDisks -vm $vm -DiskSpec $Disks
    $match = if ( $vmDiskResult) { 'MATCH' } else { 'MISMATCH' }
    Write-Verbose -Message "VM Disks: $match"
    
    # NICs
    # TODO
    
    # Power state
    $powerResult = _TestVMPowerState -vm $vm -PowerOnAfterCreation $PowerOnAfterCreation
    $match = if ( $powerResult) { 'MATCH' } else { 'MISMATCH' }
    Write-Verbose -Message "Power state: $match"

    # Guest disks
    $guestDiskResult = $true
    if ($VM.PowerState -eq 'PoweredOn') {
        _refreshHostStorageCache -vm $vm -Credential $GuestCredentials
        $guestDiskResult = _TestGuestDisks -vm $vm -DiskSpec $Disks -Credential $GuestCredentials
        $match = if ( $guestDiskResult) { 'MATCH' } else { 'MISMATCH' }
        Write-Verbose -Message "Guest disks: $match"
    } else {
        Write-Warning -Message 'VM is powered off. Skipping guest disk check'
    }

    # NICs
    # TODO

    # Test VM folder
    $folderResult = $true
    if ($VMFolder -ne [string]::Empty) {
        $folderResult = _TestVMFolder -VM $vm -VMFolder $VMFolder
        $match = if ( $folderResult) { 'MATCH' } else { 'MISMATCH' }
        Write-Verbose -Message "VM Folder: $match"
    }

    # Power state
    $powerResult = _TestVMPowerState -vm $vm -PowerOnAfterCreation $PowerOnAfterCreation
    $match = if ( $powerResult) { 'MATCH' } else { 'MISMATCH' }
    Write-Verbose -Message "Power state: $match"

    #endregion
    
    # VM Tools
    if ($UpdateTools) {
        $toolsResult = _TestVMTools -VM $VM
        $match = if ( $toolsResult) { 'Current' } else { 'OUT OF DATE/NOT INSTALLED' }
        Write-Verbose -Message "VM Tools: $match"    
    } else {
        $toolsResult = $true
    }    

    # Test provisioners
    $provisionerResults = @()
    if ($PSBoundParameters.ContainsKey('Provisioners')) {
        foreach ($p in (ConvertFrom-Json -InputObject $Provisioners)) {
            $provPath = "$PSScriptRoot\Provisioners\$($p.name)\Test.ps1"
            if (Test-Path -Path $provPath) {
                $params = $PSBoundParameters
                $params.vm = $vm
                $params.ProvOptions = $p.options
                $provisionerPassed = (& $provPath $params)
                $provisionerResults += $provisionerPassed
                #if (-not $provisionerPassed) {
                #    return $false
                #}
            }
        }
    }

    _DisconnectFromvCenter -vCenter $vCenter
    
    if (-not ($ramResult -and $cpuResult -and $vmDiskResult -and $guestDiskResult -and $powerResult -and $folderResult -and $tagResult -and $toolsResult)) {
        Write-Debug -Message "One or more tests failed"
        return $false
    }
    
    Write-Debug -Message 'Provisioner results:'
    Write-Debug -Message ($provisionerResults | Format-List | Out-String)  
    
    if (($provisionerResults | Where-Object {$_ -ne $true }).Count -gt 0) {
        Write-Verbose -Message "One or more provisioners failed tests"
        return $false
    }
    
    return $true
}

Export-ModuleMember -Function *-TargetResource
