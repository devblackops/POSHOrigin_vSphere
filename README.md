[![Build status](https://ci.appveyor.com/api/projects/status/trhenhq5sll9jca1?svg=true)](https://ci.appveyor.com/project/devblackops/poshorigin-vsphere)

# POSHOrigin_vSphere
POSHOrigin_vSphere is a set of PowerShell 5 based DSC resources for managing VMware vSphere objects via DSC.

## Overview
POSHOrigin_vSphere is a set of PowerShell 5 based DSC resources for managing VMware vSphere objects via DSC. These resources are designed to be used with [POSHOrigin](https://github.com/devblackops/POSHOrigin) as a Infrastructure as Code framework, but can be used natively by standard DSC configurations as well. Integration with [POSHOrigin](https://github.com/devblackops/POSHOrigin) is accomplished via a separate 'Invoke.ps1' script included in the module.

## Resources
* **VM** Manages an virtual machine

### VM

Created, modifies, or deletes a virtual machine

Parameters
----------

| Name                  | Type         | Required | Description
| :---------------------|:-------------|:---------|:-----------|
| Name                  | string       | True     | Name of VM to create
| Ensure                | string       | False    | Denotes if resource should exist or not exist.
| vCenter               | string       | True     | FQDN of the vCenter to connect to
| VMTemplate            | string       | True     | Name of VM template to deploy from
| CustomizationSpec     | string       | True     | Name of customization specification to apply to VM
| TotalvCPU             | int          | True     | Total number of vCPUs
| CoresPerSocket        | int          | True     | Number of Cores per virtual socket
| vRAM                  | int          | True     | Total vRAM in GB
| Datacenter            | string       | True     | Name of virtual datacenter for VM
| Cluster               | string       | True     | Name of cluster to deploy VM into
| InitialDatastore      | string       | True     | Name of datastore or datastore cluster to deploy VM in
| PowerOnAfterCreation  | bool         | False    | Indicates if VM should be powered on after creation. Default is **True**
| IPAMFqdn              | string       | False    | InfoBlox FQDN to allocate IP from
| Disks                 | string       | False    | JSON string of disks to provision on VM [[see Disks](https://github.com/devblackops/POSHOrigin/wiki/vSphere:VM#disks)]
| Networks              | string       | True     | JSON string of NICs to apply to VM [[see Networks](https://github.com/devblackops/POSHOrigin/wiki/vSphere:VM#networks)]
| Provisioners          | string       | False    | JSON string of provisioners to apply on VM after deployment [[see provisioners](https://github.com/devblackops/POSHOrigin/wiki/vSphere:VM#provisioners)]
| vCenterCredentials    | pscredential | True     | vCenter credential with rights to manage VMs
| GuestCredentials      | pscredential | False    | Guest credentials for VM
| IPAMCredentials       | pscredential | False    | InfoBlox credentials with rights to allocate IPs
| DomainJoinCredentials | pscredential | False    | Active Directory credentials with rights to join machines to the domain


## POSHOrigin Example

This example shows how to use the **VM** resource within the context of a [POSHOrigin](https://github.com/devblackops/POSHOrigin) configuration file.

```PowerShell
resource 'vsphere:vm' 'VM01' @{
    ensure = 'present'
    description = 'Test VM'
    vCenter = 'vcenter01.local'
    datacenter = 'datacenter01'
    cluster = 'cluster01'
    vmTemplate = 'W2K12_R2_Std'
    customizationSpec = 'W2K12_R2'
    powerOnAfterCreation = $true
    totalvCPU = 2
    coresPerSocket = 1
    vRAM = 4
    initialDatastore = 'datastore01'
    networks = @{
        portGroup = 'VLAN_500'
        ipAssignment = 'Static'
        ipAddress = '192.168.100.100'
        subnetMask = '255.255.255.0'
        defaultGateway = '192.168.100.1'
        dnsServers = @('192.168.50.50','192.168.50.60')
    }
    disks = @(
        @{
            name = 'Hard disk 1'
            sizeGB = 50
            type = 'flat'
            format = 'Thick'
            volumeName = 'C'
            volumeLabel = 'NOS'
            blockSize = 4096
        }
    )
    secrets = @{
        vCenter = @{
            resolver = 'pscredential'
            options = @{
                username = '<your vcenter username>'
                password = '<your password here>'
            }
        }
        guest = @{
            resolver = 'pscredential'
            options = @{
                username = 'administrator'
                password = '<your password here>'
            }
        }
    }
    Provisioners = @(
        @{
            name = 'DomainJoin'
            options = @{
               domain = 'mydomain.com'
               oupath = 'ou=servers, dc=mydomain, dc=com'
           }
        }
        @{
            name = 'Chef'
            options = @{
                nodeName = 'vm01.mydomain.com'
                url = 'https://chefsvr.mydomain.com/organizations/myorg'
                source = '<URL to Chef MSI file>'
                validatorKey = '<URL to organization validator .pem file>'
                cert = '<URL to issuing CA .crt file>'
                runList = @(
                    @{ role = 'base::setup_base' }
                    @{ recipe = 'myapp::default' }
                )
                environment = 'prod'
                attributes = @{
                    'myapp.prop1' = 42
                    'myapp.prop2' = 'something'
                }
            }
        }
    )
}
```