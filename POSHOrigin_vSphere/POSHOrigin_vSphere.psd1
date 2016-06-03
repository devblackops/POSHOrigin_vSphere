@{
RootModule = 'POSHOrigin_vSphere.psm1'
ModuleVersion = '1.2.0'
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
- Add support for deploying VMs into a resource pool, directly to a VM host, order to a vApp.
- Fix bug with testing IP connectivity prior to creating a VM, when that VM has multiple NICs defined."
        # External dependent modules of this module
        # ExternalModuleDependencies = ''
    }
 }
}
