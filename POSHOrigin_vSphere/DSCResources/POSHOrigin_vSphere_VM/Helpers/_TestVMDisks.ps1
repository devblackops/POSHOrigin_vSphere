function _TestVMDisks {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $vm,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DiskSpec
    )

    begin {
        Write-Debug -Message '_TestVMDisks() starting'
        $vmDiskStorageFormat = [string]::Empty
        $diskStorageFormat = [string]::Empty

        $diskCount = $diskExist = $diskSCSI = $diskSize = $diskType = $diskFormat = $true
    }

    process {
        try {
            $configDisks = ConvertFrom-Json -InputObject $DiskSpec -Verbose:$false
            $vmDisks = @($vm | Get-HardDisk -Verbose:$false -Debug:$false)
            Write-Debug -Message "Desired VM disk count: $(@($configDisks).Count)"
            Write-Debug -Message "Current VM disk count: $(@($vmDisks).Count)"

            if ( @($configDisks).Count -ne @($vmDisks).Count) {
                Write-Verbose -Message 'Disk count does not match configuration'
                $diskCount = $false
                #return $pass
            }

            $scsiControllers = $vm | Get-SCSIController -Verbose:$false 

            foreach ($disk in $configDisks) {
                Write-Debug -Message "Validating VM disk [$($disk.Name)]"

                $vmDisk = $vmDisks | Where-Object {$_.Name.ToLower() -eq $disk.Name.ToLower() }
                if ($null -eq $vmDisk) {
                    Write-Verbose -Message "Disk [$($disk.Name)] does not exist on VM"
                    $diskExist = $false
                    #return $false
                }

                # TODO
                # Validate VM disk is on correct SCSI controller / bus number
                if ($disk.SCSI) {

                    # The SCSI Id the VM disk 'should' be on
                    $desiredSCSIControllerNumber = $disk.SCSI.Id.Split(':')[0]
                    $desiredBusNumber = $disk.SCSI.Id.Split(':')[1]

                    $actualSCSIController = $vmDisk | Get-SCSIController -Verbose:$false
                    $actualSCSIControllerNum = $actualSCSIController.Name.Split(' ')[2]
                    $actualSCSIBusNumber = ($vm.ExtensionData.Config.Hardware.Device |
                        where { $_.Key -eq $vmDisk.ExtensionData.Key} | Select -First 1).UnitNumber

                    Write-Verbose -Message "[$($vmDisk.Name)] is SCSI [$actualSCSIControllerNum : $actualSCSIBusNumber]"

                    # Does this VM disk match the desired SCSI ID?
                    if (($actualSCSIControllerNum -ne $desiredSCSIControllerNumber) -or
                        ($actualSCSIBusNumber -ne $desiredBusNumber)) {
                        Write-Verbose -Message "Disk [$($vmDisk.Name)] SCSI ID does not match [$actualSCSIControllerNum`:$actualSCSIBusNumber <> $desiredSCSIControllerNumber`:$desiredBusNumber]"
                        $diskSCSI = $false
                        #return $false
                    }


                }

                $vmDiskCap = [system.math]::round($vmDisk.CapacityGB, 0)
                if ($vmDiskCap -ne $disk.SizeGB) {

                    # Produce error if the desired disk size is less than the actual disk size
                    if ($vmDiskCap -gt $disk.SizeGB) {
                        Write-Warning -Message "The current disk size [$vmDiskCap GB] is greater than the desired disk size [$($disk.SizeGB) GB]. Can not shrink VM disks"
                    } else {
                        Write-Verbose -Message "Disk [$($disk.Name)] does not match configured size"
                        $diskSize = $false
                        #return $false
                    }
                }

                if ($null -ne $vmDisk.StorageFormat) {
                    $vmDiskStorageFormat = $vmDisk.StorageFormat
                }
                if ($null -ne $disk.Format) {
                    $diskStorageFormat = $disk.Format
                }
                if ($vmDiskStorageFormat.ToString().ToLower() -ne $diskStorageFormat.ToLower()) {
                    Write-Verbose -Message "Disk [$($disk.Name)] storage format [$($vmDiskStorageFormat.ToString().ToLower()) <> @($diskStorageFormat.ToLower()) )]"
                    $diskFormat = $false
                    #return $false
                }
                if ($vmDisk.DiskType.ToString().ToLower() -ne $disk.Type.ToLower()) {
                    Write-Verbose -Message "Disk [$($disk.Name)] type [$($vmDisk.DiskType.ToString().ToLower()) <> $($disk.Type.ToLower())]"
                    $diskType = $false
                    #return $false
                }
            }

            return ($diskCount -and $diskExist -and $diskSCSI -and $diskSize, $diskType, $diskFormat)
            #return $true
        } catch {
            Write-Error -Message 'There was a problem testing the disks.'
            Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
            Write-Error $_
        }
    }

    end {
        Write-Debug -Message '_TestVMDisks() ending'
    }
}