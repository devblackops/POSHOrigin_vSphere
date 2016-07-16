#<#
#    This script expects to be passed a psobject with all the needed properties
#    in order to invoke a 'VirtualMachine' DSC resource.
##>
#param(
#    $Options,
#    [bool]$Direct = $true
#)

#$type = $Options.Resource.split(':')[1]

#switch ($type) {
#    'vm' {
#        $provJson = ''
#        if ($null -ne $Options.options.provisioners) {
#            $provJson = ConvertTo-Json -InputObject $Options.options.provisioners -Depth 999
#        }

#        if ($null -eq $provJson) {
#            $provJson = ''
#        }

#        if ($Direct) {
#            if ($null -eq $Options.options.Ensure) {
#                $Options.Options | Add-Member -MemberType NoteProperty -Name Ensure -Value 'Present' -Force
#            }
#            $hash = @{
#                Ensure = $Options.options.Ensure.ToString()
#                Name = $Options.Name
#                PowerOn = $Options.options.PowerOn
#                vCenter = $Options.options.vCenter
#                VMTemplate = $Options.options.VMTemplate
#                TotalvCPU = $Options.options.TotalvCPU
#                CoresPerSocket = $Options.options.CoresPerSocket
#                vRAM = $Options.options.vRAM
#                Datacenter = $Options.options.Datacenter
#                Cluster = $Options.options.Cluster
#                InitialDatastore = $Options.options.InitialDatastore
#                Disks = ConvertTo-Json -InputObject $Options.options.disks -Depth 999
#                CustomizationSpec = $Options.options.CustomizationSpec
#                Networks = ConvertTo-Json -InputObject $Options.options.networks -Depth 999
#                Provisioners = $provJson
#            }

#            # Credentials may be specified in line. Test for that
#            if ($Options.Options.vCenterCredentials -is [pscredential]) {
#                $hash.vCenterCredentials = $Options.Options.vCenterCredentials
#            }
#            if ($Options.Options.GuestCredentials -is [pscredential]) {
#                $hash.GuestCredentials = $Options.Options.GuestCredentials
#            }
#            if ($Options.Options.DomainJoinCredentials -is [pscredential]) {
#                $hash.DomainJoinCredentials = $Options.Options.DomainJoinCredentials
#            }
#            if ($Options.Options.IPAMCredentials -is [pscredential]) {
#                $hash.IPAMCredentials = $Options.Options.IPAMCredentials
#            }
#            if ($Options.Options.IPAMFqdn -is [string]) {
#                $hash.IPAMFqdn = $Options.Options.IPAMFqdn
#            }

#            # Credentials may be listed under secrets. Test for that
#            if ($Options.options.secrets.vCenter) {
#                $hash.vCenterCredentials = $Options.options.secrets.vCenter.credential
#            }
#            if ($Options.options.secrets.guest) {
#                $hash.GuestCredentials = $Options.options.secrets.guest.credential
#            }
#            if ($Options.options.secrets.domainJoin) {
#                $hash.DomainJoinCredentials = $Options.options.secrets.domainJoin.credential
#            }
#            if ($Options.options.secrets.ipam) {
#                $hash.IPAMCredentials = $Options.options.secrets.ipam.credential
#                $hash.IPAMFqdn = $Options.options.secrets.ipam.options.fqdn
#            }

#            # If the guest credential doesn't have a domain or computer name
#            # as part of the username, make sure to add it
#            if ($hash.GuestCredentials.UserName -notlike '*\*') {
#                $userName = "$($Options.Name)`\$($hash.GuestCredentials.UserName)"
#                $cred = New-Object System.Management.Automation.PSCredential -ArgumentList ($userName, $hash.GuestCredentials.Password)
#                $hash.GuestCredentials = $cred
#            }

#            return $hash 
#        } else {
#            Write-Verbose -Message 'Returning invoke string for resource: VM'

#            $cmd = 
#@'
#                $provJson = [string]::empty
#                if ($null -ne $_.options.provisioners) {
#                    $provJson = ConvertTo-Json -InputObject $_.options.provisioners -Depth 999
#                }

#                if ($null -eq $provJson) {
#                    $provJson = [string]::empty
#                }
#                VM $_.Name {
#                    Ensure = $_.options.Ensure
#                    Name = $_.Name
#                    PowerOnAfterCreation = $_.options.PowerOnAfterCreation
#                    vCenter = $_.options.vCenter
#                    vCenterCredentials = $_.options.secrets.vCenter.credential
#                    VMTemplate = $_.options.VMTemplate
#                    TotalvCPU = $_.options.TotalvCPU
#                    CoresPerSocket = $_.options.CoresPerSocket
#                    vRAM = $_.options.vRAM
#                    Datacenter = $_.options.Datacenter
#                    Cluster = $_.options.Cluster
#                    InitialDatastore = $_.options.InitialDatastore
#                    Disks = ConvertTo-Json -InputObject $_.options.disks
#                    CustomizationSpec = $_.options.CustomizationSpec
#                    GuestCredentials = $_.options.secrets.guest.credential
#                    IPAMCredentials = $_.options.secrets.ipam.credential
#                    IPAMFqdn = $_.options.secrets.ipam.options.fqdn
#                    DomainJoinCredentials = $_.options.secrets.domainJoin.credential
#                    Networks = ConvertTo-Json -InputObject $_.options.networks
#                    ChefRunlist = $_.options.ChefRunList
#                    Provisioners = $_
#                }
#'@
#            write-verbose $cmd
#            return $cmd
#        }
#    }
#}