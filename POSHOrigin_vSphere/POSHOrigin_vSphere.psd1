@{
RootModule = 'POSHOrigin_vSphere.psm1'
ModuleVersion = '1.1.6'
GUID = 'af4099cf-30a1-44eb-8c74-a10948245227'
Author = 'Brandon Olin'
CompanyName = 'Unknown'
Copyright = '(c) 2016 Brandon Olin. All rights reserved.'
Description = 'DSC resources to manage VMware vSphere with POSHOrigin.'
PowerShellVersion = '5.0'
ProcessorArchitecture = 'None'
DscResourcesToExport = @('VM')
PrivateData = @{
    PSData = @{
        Tags = 'VMware','vSphere','VM','Virtual machine','Virtualmachine','POSHOrigin','Infrastructure as Code','IaC'
        LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
        ProjectUri = 'https://github.com/devblackops/POSHOrigin_vSphere'
        #IconUri = ''
        ReleaseNotes = 'Fix environment check bug in chef provisioner test script. Fix bug in DomainJoin provisioner script. 
        Repeatedly rebuilding a VM and rejoining to the same domain should now work.'
        # External dependent modules of this module
        # ExternalModuleDependencies = ''
    }
 }
}
