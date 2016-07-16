
function _SetVMDiskSCSIController {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        $VM,

        [parameter(Mandatory)]
        $Disk,

        [ValidateRange(0, 3)]
        [parameter(Mandatory)]
        [int]$ControllerId,

        # Missing BusNumber 7 on purpose
        [ValidateSet(0,1,2,3,4,5,6,8,9,10,11,12,13,14,15)]
        [parameter(Mandatory)]
        [int]$BusNumber,

        [ValidateSet('Default', 'ParaVirtual', 'VirtualBusLogic', 'VirtualLsiLogic', 'VirtualLsiLogicSAS')]
        [string]$ControllerType = 'Default'
    )
    
    Write-Warning -Message 'This is a test warning for iponew parsing to find'

    # Get the SCSI controller key
    $scsiController = $VM | Get-SCSIController -Name "SCSI controller $ControllerId" -Verbose:$false -ErrorAction SilentlyContinue

    # Add a new controller if needed
    if (-Not $scsiController) {
        Write-Verbose -Message "Adding [$($Disk.name)] to new controller"
        New-ScsiController -Type $ControllerType -HardDisk $Disk -Verbose:$false -Confirm:$false
        $Disk = $Disk | Get-HardDisk
    }

    # TODO
    # Validate that the bus number is not already in use

    # Set disk to correct bus number
    Write-Verbose -Message "Setting [$($Disk.name)] to SCSI $ControllerId`:$BusNumber"
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $spec.deviceChange[0].operation = "edit"
    $spec.deviceChange[0].device = $Disk.ExtensionData
    $spec.deviceChange[0].device.unitNumber = $BusNumber

    try {
        $t = $vm.ExtensionData.ReconfigVM_Task($spec)
        
        # Wait for the task to complete
        while ($t.State.ToString().ToLower() -eq 'running') {
            Start-Sleep -Seconds 5
            $t = Get-Task -Id $t.Id -Verbose:$false -Debug:$false
        }
        $t = Get-Task -Id $t.Id -Verbose:$false -Debug:$false
        if ($t.State.ToString().ToLower() -ne 'success') {
            Write-Verbose -Message ($t | fl * | out-string)
            #Write-Error -Message $t.Result
        }
    } catch {
        Write-Error -Message 'There was a problem setting the disk SCSI ID'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        Write-Error -Exception $_
    }
}
