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
                $opt = New-CimSessionOption -Protocol DCOM
                $cim = New-CimSession -ComputerName $ip -Credential $Credential -SessionOption $opt -Verbose:$false
                $session = New-PSSession -ComputerName $ip -Credential $credential -Verbose:$false
                
                # Get mapped disks between the guest and VMware
                $guestDiskMapping = _GetGuestDiskToVMDiskMapping -VM $vm -cim $cim -Credential $Credential
                $os = _GetGuestOS -VM $vm -Credential $credential

                if ($os -ge 62) {
                    $disks = Invoke-Command -Session $session -ScriptBlock { Get-Disk } -Verbose:$false
                } else {
                    $disks = Get-CimInstance -ClassName CIM_DiskDrive -CimSession $cim -Verbose:$false | Select *
                }

                # Rename CDROM to Z:
                _RenameCDROM -cim $cim -DriveLetter 'Z'

                # Format each disk according to instructions
                foreach ($config in $desiredDiskConfigMapping) {

                    # Do we have a matching guest disk
                    $guestDisk = $guestDiskMapping |
                        Where-Object {$_.SerialNumber -eq $config.SerialNumber} | 
                        Select-Object -First 1

                    if ($guestDisk) {

                        if ($os -ge 62) {
                            $disk = $disks | Where-Object {$_.Number -eq $guestDisk.WindowsDisk} | Select-Object -First 1
                        } else {
                            $disk = $disks | Where-Object {$_.Index -eq $guestDisk.WindowsDisk} | Select-Object -First 1
                        }

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
                            if ($os -ge 62) {
                                _FormatGuestDisk @formatParams
                            } else {
                                $formatParams.Add('cim', $cim)
                                _FormatOldGuestDisk @formatParams
                            }
                            Write-Debug -Message "Formatting disk [$($guestDisk.WindowsDisk)]complete"
                        } else {
                            Write-Verbose -Message "Could not find guest disk [$($guestDisk.WindowsDisk)]"
                        }
                    } else {
                        Write-Verbose -Message "Could not find disk with SN $($config.SerialNumber)"
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
                if ($os -ge 62) {
                    $gfd = @{
                        Session = $session
                        ScriptBlock = {
                            Get-Disk | Where-Object {$_.PartitionStyle -ne 'Raw'}
                        }
                    }
                $formatedDisks = Invoke-Command @gfd
                } else {
                    $formatedDisks = $guestDiskMapping | where-object {$_.FileSystem -ne ''}
                }

                foreach ($config in $desiredDiskConfigMapping) {

                    # Do we have a matching guest disk from our mapping?
                    $guestDisk = $guestDiskMapping |
                        Where-Object {$_.SerialNumber -eq $config.SerialNumber} |
                        Select-Object -First 1

                    if ($guestDisk) {
                        $disk = $formatedDisks |
                            Where-Object {$_.SerialNumber -eq $guestDisk.SerialNumber} |
                            Select-Object -first 1

                        if ($null -ne $disk) {

                            # Get the partition
                            if ($os -ge 62) {
                                Write-Debug -Message "Looking at disk $($disk.Number)"
                                Write-Debug -Message "Using 2012 commands"
                                $gp = @{
                                    Session = $session  
                                    ScriptBlock = {
                                        $args[0] |
                                            Get-Partition |
                                            Where-Object {$_.Type -ne 'Reserved' -and $_.IsSystem -eq $false -and $_.Type -ne 'Unknown'} |
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
                            } else {
                                Write-Debug -Message "Looking at disk $($disk.WindowsDisk)"
                                Write-Debug -Message "Using 2008r2 commands"
                                $gs = @{
                                    Session = $session
                                    ArgumentList = $disk.WindowsDisk
                                    ScriptBlock = {
                                        $diskInfo = New-Object psobject
                                        $diskID = '  Disk ' + $($args[0]).ToString()
                                        $results = "list disk" | diskpart | ? {$_.startswith($diskID)}
                                        $results |% { 
                                            if ($_ -match 'Disk\s+(\d+)\s+\w+\s+(\d+)\s+\w+\s+(\d+)\s+(\w+)') {
                                                Add-Member -InputObject $diskInfo -MemberType Noteproperty -Name ExtraSpace -Value $($matches[3])
                                                Add-Member -InputObject $diskInfo -MemberType NoteProperty -Name DiskSize -Value $($matches[2])
                                                $command = "select disk $($matches[1])`r`nlist part"
                                                $x = $command |diskpart | where {($_ -notlike '*Reserved*') -and ($_ -notlike '*Unknown*') -and ($_ -match 'Partition\s\d')}
                                                if ($x.count -gt 1) {
                                                    throw "Not able to configure disk $($args[0]) because it has more than 1 primary partition"
                                                }
                                                $results2 = $command |diskpart | where {$_ -match 'Partition\s+(\d+)\s+\w+\s+(\d+)\s+\w+\s+(.*)'}
                                                Add-Member -InputObject $diskInfo -Membertype Noteproperty -Name PartNum -Value $($matches[1]).ToInt32($null)
                                                Add-Member -InputObject $diskInfo -Membertype Noteproperty -Name PartSize -Value $($matches[2]).ToDecimal($null)
                                                $offSet = $matches[3].replace(' ', '')
                                                $sizeInBytes = [scriptblock]::Create($offSet).Invoke()
                                                $sizeInGB = $sizeInBytes.ToInt32($null) / 1GB      
                                                Add-Member -InputObject $diskInfo -Membertype NoteProperty -Name Offset -Value $sizeInGB.ToDecimal($null)
                                            }
                                        }
                                        $diskInfo
                                    }
                                }

                                $diskInfo = Invoke-Command @gs
                                Write-Debug $diskInfo

                                $actualSize = [math]::ceiling($diskInfo.PartSize + $diskInfo.Offset)
                                if ($actualSize -lt $config.DiskSizeGB) {
                                    Write-Verbose "Extending partition for disk $($disk.WindowsDisk)"
                                    $ed = @{
                                        Session = $session
                                        ArgumentList = $disk.WindowsDisk, $diskInfo.PartNum
                                        ScriptBlock = {
                                            $diskID = $args[0].ToString()
                                            $partNum = $args[1].ToString()
                                            $x = "Select Disk $($diskID)", "Select Partition $($partNum)", "extend noerr" | diskpart | out-null
                                        }
                                    }
                                    $results = Invoke-Command @ed
                                }

                                # Drive letter
                                if ($disk.VolumeName -ne $config.VolumeName) {
                                    Write-Verbose -Message "Setting drive letter to [$($config.VolumeName)]"
                                    $sdl = @{
                                        Session = $session
                                        ArgumentList = $disk, $diskInfo.PartNum
                                        ScriptBlock = {
                                            $DiskID = $args[0].WindowsDisk.ToString()
                                            $VolName = $args[0].VolumeName.ToString()
                                            $PartNum = $args[1].ToString()
                                            $x = "Select Disk $($DiskID)", "Select Partition $($PartNum)", "assign letter=$($VolName)" | diskpart | Out-Null
                                        }
                                    }
                                }

                                # Volume label
                                if ($disk.VolumeLabel -ne $config.VolumeLabel) {
                                    Write-Verbose -Message "Setting volume to [$($config.VolumeLabel)]"
                                    $gld = @{
                                        CimSession = $cim
                                        ClassName = 'Win32_LogicalDisk'
                                        Filter = "deviceid='$($disk.VolumeName):'"
                                        Verbose = $false
                                    }
                                    $vol = Get-CimInstance @gld
                                    $vol | Set-CimInstance -Property @{volumename=$config.VolumeLabel} -Verbose:$false
                                }                                    
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