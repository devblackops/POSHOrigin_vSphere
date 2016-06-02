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

## 1.1.6

## Previous

This changelog is inspired by the
[Pester](https://github.com/pester/Pester/blob/master/CHANGELOG.md) file.
