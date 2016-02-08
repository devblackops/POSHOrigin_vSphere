# Based on https://communities.vmware.com/thread/528535?start=0&tstart=0

function _GetGuestDiskToVMDiskMapping {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $VM,

        [Parameter(Mandatory)]
        $cim,

        [Parameter(Mandatory)]
        [pscredential]$Credential
    )

    try {
        $vmView = $VM | Get-View -Verbose:$false -Debug:$false

        # Get the ESX host which the VM is currently running on
        $esxHost = Get-VMHost -Id $vmView.Summary.Runtime.Host -Verbose:$false

        $wmiDisks = Get-CimInstance -CimSession $cim -ClassName Win32_DiskDrive -Verbose:$false

        # Use 'Invoke-VMScript' to grab disk information WMI on the guest
        #$Out = Invoke-VMScript "wmic path win32_diskdrive get Index, SCSIPort, SCSITargetId /format:csv" -vm $VM -GuestCredential $guestCred -scripttype "bat"
        #$fileName = [System.IO.Path]::GetTempFileName()  
        #$out.Substring(2) > $fileName
        #$wmiDisks = Import-Csv -Path $fileName
        #Remove-Item $fileName

        # Match the guest disks to the VM disks by SCSI bus number and unit number
        $diskInfo = @()
        foreach ($virtualSCSIController in ($vmView.Config.Hardware.Device | where {$_.DeviceInfo.Label -match "SCSI Controller"})) {
            foreach ($virtualDiskDevice in ($vmView.Config.Hardware.Device | where {$_.ControllerKey -eq $virtualSCSIController.Key})) {
                $mapping = "" | Select SCSIController, DiskName, SCSIId, SCSIBus, SCSIUnit, DiskFile,  DiskSize, WindowsDisk, SerialNumber
                $mapping.SCSIController = $virtualSCSIController.DeviceInfo.Label
                $mapping.DiskName = $virtualDiskDevice.DeviceInfo.Label
                $mapping.SCSIId = "$($virtualSCSIController.BusNumber)`:$($virtualDiskDevice.UnitNumber)"
                $mapping.SCSIBus = $($virtualSCSIController.BusNumber)
                $mapping.SCSIUnit = $($virtualDiskDevice.UnitNumber)
                $mapping.DiskFile = $virtualDiskDevice.Backing.FileName
                $mapping.DiskSize = $virtualDiskDevice.CapacityInKB * 1KB / 1GB

                $match = $wmiDisks | Where-Object {([int]$_.SCSIPort – 2) -eq $virtualSCSIController.BusNumber -and [int]$_.SCSITargetID -eq $virtualDiskDevice.UnitNumber}
                if ($match) {
                    $mapping.WindowsDisk = $match.Index
                    $mapping.SerialNumber = $match.SerialNumber
                } else {
                    #Write-Verbose -Message "No matching Windows disk found for SCSI ID [$($mapping.SCSIId)]"
                }

                $diskInfo += $mapping
            }
        }
        Write-Debug -Message ($diskInfo | ft DiskName, SCSIId, DiskSize, WindowsDisk, SerialNumber  -AutoSize | out-string)
        return $diskInfo
    } catch {
        Write-Error -Message 'There was a problem getting the guest disk mapping'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error $_
    }
}