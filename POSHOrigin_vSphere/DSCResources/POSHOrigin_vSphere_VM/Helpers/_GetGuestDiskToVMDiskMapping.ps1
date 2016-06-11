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
        $os = _GetGuestOS -VM $VM -Credential $credential
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
        foreach ($virtualSCSIController in ($vmView.Config.Hardware.Device | where {$_.DeviceInfo.Label -match 'SCSI Controller'})) {
            foreach ($virtualDiskDevice in ($vmView.Config.Hardware.Device | where {$_.ControllerKey -eq $virtualSCSIController.Key})) {

                $mapping = new-object psobject
                Add-Member -InputObject $mapping -MemberType NoteProperty -Name SCSIController -Value $virtualSCSIController.DeviceInfo.Label
                Add-Member -InputObject $mapping -MemberType NoteProperty -Name DiskName -Value $virtualDiskDevice.DeviceInfo.Label
                Add-Member -InputObject $mapping -MemberType NoteProperty -Name SCSIId -Value "$($virtualSCSIController.BusNumber)`:$($virtualDiskDevice.UnitNumber)"
                Add-Member -InputObject $mapping -MemberType NoteProperty -Name SCSIBus -Value $($virtualSCSIController.BusNumber)
                Add-Member -InputObject $mapping -MemberType NoteProperty -Name SCSIUnit -Value $($virtualDiskDevice.UnitNumber)
                Add-Member -InputObject $mapping -MemberType NoteProperty -Name DiskFile -Value $virtualDiskDevice.Backing.FileName
                Add-Member -InputObject $mapping -MemberType NoteProperty -Name DiskSize -Value (($virtualDiskDevice.CapacityInKB * 1KB / 1GB)).ToInt32($Null)

                $match = $wmiDisks | Where-Object {([int]$_.SCSIPort - 2) -eq $virtualSCSIController.BusNumber -and [int]$_.SCSITargetID -eq $virtualDiskDevice.UnitNumber}
                if ($match) {
                    Add-Member -InputObject $mapping -MemberType NoteProperty -Name WindowsDisk -Value $match.Index
                    Add-Member -InputObject $mapping -MemberType NoteProperty -Name SerialNumber -Value $match.SerialNumber
                    if ($os -lt 63) {
                        $partitions = Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($match.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition" -CimSession $cim -verbose:$false | Select *

                        foreach($part in $partitions) {
                            $vols = Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($part.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition" -CimSession $cim -verbose:$false | Select *
                            foreach($vol in $vols) {
                               $tempVol = Get-CimInstance -ClassName Win32_Volume -CimSession $cim -verbose:$false | Select *
                               $tempMatch = $tempVol | Where-Object {$_.DriveLetter -eq $vol.DeviceID}
                                if ($tempMatch) {
                                    Add-Member -InputObject $mapping -MemberType NoteProperty -Name VolumeName -Value $tempMatch.DriveLetter.SubString(0,1)
                                    Add-Member -InputObject $mapping -MemberType NoteProperty -Name VolumeLabel -Value $tempMatch.Label
                                    Add-Member -InputObject $mapping -MemberType NoteProperty -Name BlockSize -Value $tempMatch.BlockSize
                                    Add-Member -InputObject $mapping -MemberType NoteProperty -Name Format -value $tempMatch.FileSystem
                                }
                            }
                        }
                    }
                    $diskInfo += $mapping   
                } else {
                    Write-Verbose -Message "No matching Windows disk found for SCSI ID [$($mapping.SCSIId)]"
                }        
            }
        }
        return $diskInfo
    } catch {
        Write-Error -Message 'There was a problem getting the guest disk mapping'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error $_
    }
}