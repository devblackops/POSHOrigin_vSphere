function _TestGuestDisks {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $vm,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DiskSpec,

        [Parameter(Mandatory)]
        [pscredential]$Credential
    )

    begin {
        Write-Debug -Message '_TestGuestDisks() starting'
    }

    process {

        $pass = $true

        try {
            $desiredDiskConfigMapping = _GeConfigDiskToVMDiskMapping -vm $vm -DiskSpec $DiskSpec

            $ip = _GetGuestVMIPAddress -VM $vm
            if ($ip) {
            
                $cim = New-CimSession -ComputerName $ip -Credential $Credential -Verbose:$false
                $session = New-PSSession -ComputerName $ip -Credential $credential -Verbose:$false

                # Get mapped disks between the guest and VMware
                $guestDiskMapping = _GetGuestDiskToVMDiskMapping -VM $vm -cim $cim -Credential $Credential

                $disks = Invoke-Command -Session $session -ScriptBlock { Get-Disk }

                # Compare the mapping to what is configured
                foreach($config in $desiredDiskConfigMapping) {

                    # Do we have a matching guest disk
                    $guestDisk = $guestDiskMapping | Where-Object {$_.SCSIBus -eq $config.SCSIController -and $_.SCSIUnit -eq $config.SCSITarget} | Select-Object -First 1

                    if ($guestDisk) {

                        $disk = $disks | Where-Object {$_.SerialNumber -eq $guestDisk.SerialNumber} | Select-Object -First 1
                        if ($disk) {

                            Write-Debug -Message "Testing guest disk configuration [$($config.DiskName)]"

                            $diskSize = $disk.Size / 1GB
                            $partition = Invoke-Command -Session $session -ScriptBlock { 
                                $args[0] | Get-Partition -Verbose:$false |
                                    Where-Object {$_.Type -ne 'Reserved' -and $_.Type -ne 'Unknown' -and $_.IsSystem -eq $false} |
                                    Select-Object -Last 1
                            } -ArgumentList $disk

                            if ($partition) {

                                $sizes = Invoke-Command -Session $session -ScriptBlock {
                                    $args[0] | Get-PartitionSupportedSize
                                } -ArgumentList $partition

                                # The max partition size is greater than the current partition size
                                if ( [math]::round($partition.Size / 1GB) -lt [math]::round($sizes.SizeMax / 1GB)) {
                                    $partSize = [Math]::Round($partition.Size / 1GB)
                                    Write-Verbose -Message "Disk [$($disk.Number)] does not match configuration [$partSize GB <> $($config.DiskSizeGB) GB]"
                                    $pass = $false
                                }

                                $volume = Invoke-Command -Session $session -ScriptBlock { 
                                    $args[0] | Get-Volume -Verbose:$false | Select-Object -last 1
                                } -ArgumentList $partition

                                # Drive letter
                                if ($volume.DriveLetter -ne $config.VolumeName) {
                                    Write-Verbose -Message "Volume [$($volume.DriveLetter)] does not match configuration [$($config.VolumeName)]"
                                    $pass = $false
                                }

                                # Volume label
                                if ($volume.FileSystemLabel -ne $config.VolumeLabel) {
                                    Write-Verbose -Message "Volume label [$($Volume.FileSystemLabel)] does not match configuration [$($config.VolumeLabel)]"
                                    $pass = $false
                                }
                            } else {
                                Write-Verbose -Message "Could not find partition for disk [$($config.SCSIController):$($config.SCSITarget)]"
                                $pass = $false
                            }
                        } else {
                            Write-Verbose -Message "Could not find matching formated disk with SCSI ID [$($guestDisk.SCSIId)]"
                            $pass = $false
                        }
                    } else {
                        Write-Verbose -Message "Could not find disk [$($config.SCSIController):$($config.SCSITarget)]"
                        $pass = $false
                    }
                }
                Remove-CimSession -CimSession $cim -ErrorAction SilentlyContinue
                Remove-PSSession -Session $session -ErrorAction SilentlyContinue
            } else {
                Write-Error -Message 'No valid IP address returned from VM view. Can not test guest disks'
                $pass = $true
            }
            return $pass
        } catch {
            Write-Error -Message 'There was a problem testing the guest disks'
            Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
            write-Error -Exception $_
        } finally {
            Remove-CimSession -CimSession $cim -ErrorAction SilentlyContinue
            Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        }

        return $pass
    }

    end {
        Write-Debug -Message '_TestGuestDisks() ending'
    }
}