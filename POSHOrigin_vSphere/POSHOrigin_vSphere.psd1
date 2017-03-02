@{
RootModule = 'POSHOrigin_vSphere.psm1'
ModuleVersion = '1.4.3'
GUID = 'af4099cf-30a1-44eb-8c74-a10948245227'
Author = 'Brandon Olin'
Copyright = '(c) 2016 Brandon Olin. All rights reserved.'
Description = 'DSC resources to manage VMware vSphere with POSHOrigin.'
PowerShellVersion = '5.0'
ProcessorArchitecture = 'None'
DscResourcesToExport = @('VM')
PrivateData = @{
    PSData = @{
        Tags = 'VMware','vSphere','VM','Virtualmachine','POSHOrigin','InfrastructureasCode','IaC'
        LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
        ProjectUri = 'https://github.com/devblackops/POSHOrigin_vSphere'
        #IconUri = ''
        ReleaseNotes = "
## 1.4.0 (2016-11-03)
    * Features
        * Add the ability to define Chef Automate URL, token, and cert in the Chef provisioner options.

    * Improvements
        * Change how disk mapping is done between vSphere and Windows.
        * Change to quick disk formating on Windows 2008.

## 1.3.0
    * Add support for managing tags on VMs.
    * Add support for installing/updating VM tools if out of date or not installed.
    * Add support for legacy OS (server 2008R2) when managing guest disks.
    * Add support for specifying a URL to a script in the PowerShell provisioner.

## 1.2.0
    * Add support for deploying VMs into a resource pool, directly to a VM host, order to a vApp.
    * Fix bug with testing IP connectivity prior to creating a VM, when that VM has multiple NICs defined.

## 1.1.14
    * Fix bug in evaluating Chef provisioner attributes
    * If VM has more than one IP address as reported by VM tools, ping each one and return the first IP that responds.
      That will be used by subsequent functions when interacting with the guest OS.

## 1.1.13
    * Fix bug in evaluating Chef provisioner

## 1.1.12
    * Change ConvertTo-Json depth parameter to 100 when converting POSHOorigin object into DSC configuration

## 1.1.11
    * Fix bad test logic when evaluating DSC resource

## 1.1.10
    * Refresh VM power state before testing if VM is powered on
    * Fix bad logic when testing VM disk configurations
    * Display error message when failing to resolve datastore before VM creation
    * Display error message when failing to resolve VM folder before VM creation
    * Rename 'script' provisioner to 'powershell'

## 1.1.9
    * Add generic script provisioner

## 1.1.8
    * Fix bad test logic when comparing Chef attributes
    * Fix bug in testing VM disks.

## 1.1.7
    * Add support for VM folder placement
    * Force reboot upon domain join
"
        # External dependent modules of this module
        # ExternalModuleDependencies = ''
    }
 }
}
