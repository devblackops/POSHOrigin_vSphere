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
            $provJson = ConvertTo-Json -InputObject $Options.options.provisioners -Depth 999
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
                InitialDatastore = $Options.options.InitialDatastore
                Disks = ConvertTo-Json -InputObject $Options.options.disks -Depth 999
                CustomizationSpec = $Options.options.CustomizationSpec
                Networks = ConvertTo-Json -InputObject $Options.options.networks -Depth 999
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
            # Dashes (-) are not allowed in DSC configurations names
            $itemName = $Options.Name.Replace('-', '_')
            $confName = "$type" + '_' + $itemName
            Write-Verbose -Message "Returning configuration function for resource: $confName"
            Configuration $confName {
                Param (
                    [psobject]$ResourceOptions
                )

                Import-DscResource -Name VM -ModuleName POSHOrigin_vSphere

                $provJson = [string]::empty
                if ($ResourceOptions.options.provisioners) {
                    $provJson = ConvertTo-Json -InputObject $ResourceOptions.options.provisioners -Depth 999
                }

                if (-Not $provJson) {
                    $provJson = [string]::empty
                }

                $vc = $null
                $gc = $null
                $dj = $null
                $ipam = $null
                $ipamfqdn = $null

                # Credentials may be specified in line. Test for that
                if ($Options.Options.vCenterCredentials -is [pscredential]) {
                    $vc = $Options.Options.vCenterCredentials
                }
                if ($Options.Options.GuestCredentials -is [pscredential]) {
                    $gc = $Options.Options.GuestCredentials
                }
                if ($Options.Options.DomainJoinCredentials -is [pscredential]) {
                    $dj = $Options.Options.DomainJoinCredentials
                }
                if ($Options.Options.IPAMCredentials -is [pscredential]) {
                    $ipam = $Options.Options.IPAMCredentials
                }
                if ($Options.Options.IPAMFqdn -is [string]) {
                    $ipamfqdn = $Options.Options.IPAMFqdn
                }

                # Credentials may be listed under secrets. Test for that
                if ($Options.options.secrets.vCenter) {
                    $vc = $Options.options.secrets.vCenter.credential
                }
                if ($Options.options.secrets.guest) {
                    $gc = $Options.options.secrets.guest.credential
                }
                if ($Options.options.secrets.domainJoin) {
                    $dj = $Options.options.secrets.domainJoin.credential
                }
                if ($Options.options.secrets.ipam) {
                    $ipam = $Options.options.secrets.ipam.credential
                    $ipamfqdn = $Options.options.secrets.ipam.options.fqdn
                }

                VM $ResourceOptions.Name {
                    Ensure = $ResourceOptions.options.Ensure
                    Name = $ResourceOptions.Name
                    PowerOnAfterCreation = $ResourceOptions.options.PowerOnAfterCreation
                    vCenter = $ResourceOptions.options.vCenter
                    vCenterCredentials = $vc
                    VMTemplate = $ResourceOptions.options.VMTemplate
                    TotalvCPU = $ResourceOptions.options.TotalvCPU
                    CoresPerSocket = $ResourceOptions.options.CoresPerSocket
                    vRAM = $ResourceOptions.options.vRAM
                    Datacenter = $ResourceOptions.options.Datacenter
                    Cluster = $ResourceOptions.options.Cluster
                    InitialDatastore = $ResourceOptions.options.InitialDatastore
                    Disks = ConvertTo-Json -InputObject $ResourceOptions.options.disks
                    CustomizationSpec = $ResourceOptions.options.CustomizationSpec
                    GuestCredentials = $gc
                    IPAMCredentials = $ipam
                    IPAMFqdn = $ipamfqdn
                    DomainJoinCredentials = $dj
                    Networks = ConvertTo-Json -InputObject $ResourceOptions.options.networks
                    Provisioners = $provJson
                }
            }
        }
    }
}