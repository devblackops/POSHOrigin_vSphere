function _SetGuestDisks{
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
        Write-Debug -Message 'Starting _SetGuestDisks()'
    }

    process {
        try {
            $desiredDiskConfigMapping = _GeConfigDiskToVMDiskMapping -vm $vm -DiskSpec $DiskSpec

            $ip = _GetGuestVMIPAddress -VM $vm
            if ($ip) {

                # Let's do a sanity check first.
                # Make sure we passed in valid values for the block size
                # If we didn't, let's stop right here
                $blockSizes = @(
                    4096, 8192, 16386, 32768, 65536
                )
                $desiredDiskConfigMapping | foreach {
                    # Set default block size
                    if ($_.BlockSize -eq $null) {
                        $_.BlockSize = 4096
                    }
                    if ($blockSizes -notcontains $_.BlockSize) {
                        Write-Error -Message 'Invalid block size passed in. Aborting configuration the disks'
                        break
                    }
                }

                $cim = New-CimSession -ComputerName $ip -Credential $Credential -Verbose:$false
                $session = New-PSSession -ComputerName $ip -Credential $credential -Verbose:$false
                
                # Get mapped disks between the guest and VMware
                $guestDiskMapping = _GetGuestDiskToVMDiskMapping -VM $vm -cim $cim -Credential $Credential

                $disks = Invoke-Command -Session $session -ScriptBlock { Get-Disk } -Verbose:$false

                # Rename CDROM to Z:
                _RenameCDROM -cim $cim -DriveLetter 'Z'

                # Format each disk according to instructions
                foreach ($config in $desiredDiskConfigMapping) {

                    # Do we have a matching guest disk
                    $guestDisk = $guestDiskMapping |
                        Where-Object {$_.SCSIBus -eq $config.SCSIController -and $_.SCSIUnit -eq $config.SCSITarget} | 
                        Select-Object -First 1

                    if ($guestDisk) {

                        $disk = $disks | Where-Object {$_.Number -eq $guestDisk.WindowsDisk} | Select-Object -First 1

                        if ($disk) {

                            # Format / Initialize disk
                            $formatParams = @{
                                disk = $disk
                                Session = $session
                                PartitionStyle = 'GPT'
                                VolumeName = $config.VolumeName
                                VolumeLabel = $config.VolumeLabel
                                AllocationUnitSize = $config.BlockSize
                            }
                            _FormatGuestDisk @formatParams

                        } else {
                            Write-Verbose -Message "Could not find guest disk [$($guestDisk.WindowsDisk)]"
                        }
                    } else {
                        Write-Verbose -Message "Could not find disk $($config.SCSIController):$($config.SCSITarget)"
                    }
                }

                # Compare the formated guest volumes with the mapping configuration
                # if the matching volume from the mapping has a size greater
                # than what exists, then extend the volume to match the configuration
                # BIG ASSUMPTION
                # There is only one volume per disk

                # Get mapped disks between the guest and VMware
                $guestDiskMapping = _GetGuestDiskToVMDiskMapping -VM $vm -cim $cim -Credential $Credential

                # Get formated disks
                $gfd = @{
                    Session = $session
                    ScriptBlock = {
                        Get-Disk | Where-Object {$_.PartitionStyle -ne 'Raw'}
                    }
                }
                $formatedDisks = Invoke-Command @gfd

                foreach ($config in $desiredDiskConfigMapping) {

                    # Do we have a matching guest disk from our mapping?
                    $guestDisk = $guestDiskMapping |
                        Where-Object {$_.SCSIBus -eq $config.SCSIController -and $_.SCSIUnit -eq $config.SCSITarget} |
                        Select-Object -First 1

                    if ($guestDisk) {

                        $disk = $formatedDisks |
                            Where-Object {$_.SerialNumber -eq $guestDisk.SerialNumber} |
                            Select-Object -first 1

                        if ($null -ne $disk) {

                            # Get the partition
                            Write-Debug -Message "Looking at disk $($disk.Number)"
                            $gp = @{
                                Session = $session
                                ScriptBlock = {
                                    $args[0] |
                                        Get-Partition |
                                        Where-Object {$_.Type -ne 'Reserved' -and $_.IsSystem -eq $false} |
                                        Select-Object -First 1
                                }
                                ArgumentList = $disk
                                Verbose = $false
                            }
                            $partition = Invoke-Command @gp

                            # Get max parition size supported on this disk
                            $gpss = @{
                                Session = $session
                                ArgumentList = $partition
                                ScriptBlock = { $args[0] | Get-PartitionSupportedSize | Select-Object -Last 1 }
                                Verbose = $false
                            }
                            $sizes = Invoke-Command @gpss
                            
                            # The max partition size is greater than the current partition size
                            Write-Debug -Message "Partition size: $($partition.Size)"
                            Write-Debug -Message "Paritition max size: $($sizes.SizeMax)"
                            if ( [math]::round($partition.Size / 1GB) -lt [math]::round($sizes.SizeMax / 1GB)) {
                                Write-Verbose -Message "Resisizing disk $($partition.DiskNumber) partition $($partition.PartitionNumber) to $($config.DiskSizeGB) GB"
                                $rp = @{
                                    Session = $session
                                    ArgumentList = @($partition, $sizes.SizeMax)
                                    ScriptBlock = { $args[0] | Resize-Partition -Confirm:$false -Size $args[1] }
                                    Verbose = $false
                                }
                                Invoke-Command @rp
                            }

                            $gv = @{
                                Session = $session 
                                ArgumentList = $partition
                                ScriptBlock = { $args[0] | Get-Volume }
                                Verbose =$false
                            }
                            $volume = Invoke-Command @gv

                            # Drive letter
                            if ($Volume.DriveLetter -ne $config.VolumeName) {
                                Write-Verbose -Message "Setting drive letter to [$($config.VolumeName)]"
                                $sdl = @{
                                    Session = $session
                                    ArgumentList = @($partition, $config.VolumeName)
                                    ScriptBlock = { $args[0] | Set-Partition -NewDriveLetter $args[1] }
                                    Verbose = $false
                                }
                                Invoke-Command @sdl
                            }

                            # Volume label
                            if ($Volume.FileSystemLabel -ne $config.VolumeLabel) {
                                Write-Verbose -Message "Setting volume to [$($config.VolumeLabel)]"
                                $gld = @{
                                    CimSession = $cim
                                    ClassName = 'Win32_LogicalDisk'
                                    Filter = "deviceid='$($Volume.DriveLetter):'"
                                    Verbose = $false
                                }
                                $vol = Get-CimInstance @gld
                                $vol | Set-CimInstance -Property @{volumename=$config.VolumeLabel} -Verbose:$false
                            }
                        }
                    }
                }
                Remove-CimSession -CimSession $cim -ErrorAction SilentlyContinue
                Remove-PSSession -Session $session -ErrorAction SilentlyContinue
            } else {
                Write-Error -Message 'No valid IP address returned from VM view. Can not test guest disks'
            }  
        } catch {
            Write-Error -Message 'There was a problem configuring the guest disks'
            Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
            write-Error $_
        } finally {
            Remove-CimSession -CimSession $cim -ErrorAction SilentlyContinue
            Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        }
    }

    end {
        Write-Debug -Message 'Ending _SetGuestDisks()'
    }
}