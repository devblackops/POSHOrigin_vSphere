<#
    This script expects to be passed a psobject with all the needed properties
    in order to invoke a 'VirtualMachine' DSC resource.
#>
[cmdletbinding()]
param(
    [parameter(mandatory)]
    [psobject]$Options,

    [bool]$Direct = $false
)

# Ensure we have a valid 'ensure' property
if ($null -eq $Options.options.Ensure) {
    $Options.Options | Add-Member -MemberType NoteProperty -Name Ensure -Value 'Present' -Force
}

# Get the resource type
$type = $Options.Resource.split(':')[1]

switch ($type) {
    'vm' {
        $provJson = ''
        if ($null -ne $Options.options.provisioners) {
            $provJson = ConvertTo-Json -InputObject $Options.options.provisioners -Depth 100
        }

        if ($null -eq $provJson) {
            $provJson = ''
        }

        if ($Direct) {
            $hash = @{
                Ensure = $Options.options.Ensure.ToString()
                Name = $Options.Name
                PowerOnAfterCreation = $Options.options.PowerOnAfterCreation
                vCenter = $Options.options.vCenter
                VMTemplate = $Options.options.VMTemplate
                TotalvCPU = $Options.options.TotalvCPU
                CoresPerSocket = $Options.options.CoresPerSocket
                vRAM = $Options.options.vRAM
                Datacenter = $Options.options.Datacenter
                Cluster = $Options.options.Cluster
                ResourcePool = $Options.options.ResourcePool
                VMHost = $Options.options.VMHost
                vApp = $Options.options.vApp
                VMFolder = $Options.options.VMFolder
                Tags = $Options.options.Tags
                UpdateTools = $Options.options.UpdateTools
                InitialDatastore = $Options.options.InitialDatastore
                Disks = ConvertTo-Json -InputObject $Options.options.disks -Depth 100
                CustomizationSpec = $Options.options.CustomizationSpec
                Networks = ConvertTo-Json -InputObject $Options.options.networks -Depth 100
                Provisioners = $provJson
            }

            # Credentials may be specified in line. Test for that
            if ($Options.Options.vCenterCredentials -is [pscredential]) {
                $hash.vCenterCredentials = $Options.Options.vCenterCredentials
            }
            if ($Options.Options.GuestCredentials -is [pscredential]) {
                $hash.GuestCredentials = $Options.Options.GuestCredentials
            }
            if ($Options.Options.DomainJoinCredentials -is [pscredential]) {
                $hash.DomainJoinCredentials = $Options.Options.DomainJoinCredentials
            }
            if ($Options.Options.IPAMCredentials -is [pscredential]) {
                $hash.IPAMCredentials = $Options.Options.IPAMCredentials
            }
            if ($Options.Options.IPAMFqdn -is [string]) {
                $hash.IPAMFqdn = $Options.Options.IPAMFqdn
            }

            # Credentials may be listed under secrets. Test for that
            if ($Options.options.secrets.vCenter) {
                $hash.vCenterCredentials = $Options.options.secrets.vCenter.credential
            }
            if ($Options.options.secrets.guest) {
                $hash.GuestCredentials = $Options.options.secrets.guest.credential
            }
            if ($Options.options.secrets.domainJoin) {
                $hash.DomainJoinCredentials = $Options.options.secrets.domainJoin.credential
            }
            if ($Options.options.secrets.ipam) {
                $hash.IPAMCredentials = $Options.options.secrets.ipam.credential
                $hash.IPAMFqdn = $Options.options.secrets.ipam.options.fqdn
            }

            # If the guest credential doesn't have a domain or computer name
            # as part of the username, make sure to add it
            if ($hash.GuestCredentials.UserName -notlike '*\*') {
                $userName = "$($Options.Name)`\$($hash.GuestCredentials.UserName)"
                $cred = New-Object System.Management.Automation.PSCredential -ArgumentList ($userName, $hash.GuestCredentials.Password)
                $hash.GuestCredentials = $cred
            }

            return $hash
        } else {
            $configName = $Options.Name.Replace('-', '')
            $confName = "$type" + '_' + $configName
            #Write-Verbose -Message "Returning configuration function for resource: $confName"
            Configuration $confName {
                Param (
                    [psobject]$ResourceOptions
                )

                Import-DscResource -Name VM -ModuleName POSHOrigin_vSphere

                # Credentials may be specified in line. Test for that
                if ($ResourceOptions.Options.vCenterCredentials -is [pscredential]) {
                    $vcCred = $ResourceOptions.Options.vCenterCredentials
                }
                if ($ResourceOptions.Options.GuestCredentials -is [pscredential]) {
                    $guestCred = $ResourceOptions.Options.GuestCredentials
                }
                if ($ResourceOptions.Options.IPAMCredentials -is [pscredential]) {
                    $ipamCred = $ResourceOptions.Options.IPAMCredentials
                }
                if ($ResourceOptions.Options.DomainJoinCredentials -is [pscredential]) {
                    $djCred = $ResourceOptions.Options.DomainJoinCredentials
                }

                # Credentials may be listed under secrets. Test for that
                if ($ResourceOptions.options.secrets.vCenter -or $ResourceOptions.options.secrets.vCenterCredentials ) {
                    if ($ResourceOptions.options.secrets.vCenter) {
                        $vcCred = $ResourceOptions.options.secrets.vCenter.credential
                    } else {
                        $vcCred = $ResourceOptions.options.secrets.vCenterCredentials.credential
                    }
                }
                if ($ResourceOptions.options.secrets.guest -or $ResourceOptions.options.secrets.GuestCredentials ) {
                    if ($ResourceOptions.options.secrets.guest) {
                        $guestCred = $ResourceOptions.options.secrets.guest.credential
                    } else {
                        $guestCred = $ResourceOptions.options.secrets.guestCredentials.credential
                    }
                }
                if ($ResourceOptions.options.secrets.ipam -or $ResourceOptions.options.secrets.IPAMCredentials ) {
                    if ($ResourceOptions.options.secrets.ipam) {
                        $ipamCred = $ResourceOptions.options.secrets.ipam.credential
                    } else {
                        $ipamCred = $ResourceOptions.options.secrets.IPAMCredentials.credential
                    }
                }
                if ($ResourceOptions.options.secrets.domainjoin -or $ResourceOptions.options.secrets.DomainJoinCredentials ) {
                    if ($ResourceOptions.options.secrets.domainjoin) {
                        $djCred = $ResourceOptions.options.secrets.domainjoin.credential
                    } else {
                        $djCred = $ResourceOptions.options.secrets.DomainJoinCredentials.credential
                    }
                }

                $provJson = [string]::empty
                if ($ResourceOptions.options.provisioners) {
                    $provJson = ConvertTo-Json -InputObject $ResourceOptions.options.provisioners -Depth 100
                }

                if (-Not $provJson) {
                    $provJson = [string]::empty
                }
                VM $ResourceOptions.Name {
                    Ensure = $ResourceOptions.options.Ensure
                    Name = $ResourceOptions.Name
                    PowerOnAfterCreation = $ResourceOptions.options.PowerOnAfterCreation
                    vCenter = $ResourceOptions.options.vCenter
                    vCenterCredentials = $vcCred
                    VMTemplate = $ResourceOptions.options.VMTemplate
                    TotalvCPU = $ResourceOptions.options.TotalvCPU
                    CoresPerSocket = $ResourceOptions.options.CoresPerSocket
                    vRAM = $ResourceOptions.options.vRAM
                    Datacenter = $ResourceOptions.options.Datacenter
                    Cluster = $ResourceOptions.options.Cluster
                    VMHost = $ResourceOptions.options.VMHost
                    ResourcePool = $ResourceOptions.options.ResourcePool
                    vApp = $ResourceOptions.options.vApp
                    VMFolder = $ResourceOptions.options.VMFolder
                    UpdateTools = $ResourceOptions.options.UpdateTools
                    Tags = ConvertTo-Json -InputObject $ResourceOptions.options.Tags
                    InitialDatastore = $ResourceOptions.options.InitialDatastore
                    Disks = ConvertTo-Json -InputObject $ResourceOptions.options.disks
                    CustomizationSpec = $ResourceOptions.options.CustomizationSpec
                    GuestCredentials = $guestCred
                    IPAMCredentials = $ipamCred
                    IPAMFqdn = $ResourceOptions.options.secrets.ipam.options.fqdn
                    DomainJoinCredentials = $djCred
                    Networks = ConvertTo-Json -InputObject $ResourceOptions.options.networks
                    Provisioners = $provJson
                }
            }
        }
    }
}
