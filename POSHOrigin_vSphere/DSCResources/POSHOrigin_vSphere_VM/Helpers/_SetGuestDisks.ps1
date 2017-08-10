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
        [Microsoft.Management.Infrastructure.CimSession]$CimSession,

        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$PSSession
    )

    begin {
        Write-Debug -Message 'Starting _SetGuestDisks()'
    }

    process {
        try {
            $desiredDiskConfigMapping = _GeConfigDiskToVMDiskMapping -vm $vm -DiskSpec $DiskSpec

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
            # $opt = New-CimSessionOption -Protocol DCOM
            # $cim = New-CimSession -ComputerName $ip -Credential $Credential -SessionOption $opt -Verbose:$false
            # $session = New-PSSession -ComputerName $ip -Credential $credential -Verbose:$false

            # Get mapped disks between the guest and VMware
            $guestDiskMapping = _GetGuestDiskToVMDiskMapping -VM $vm -CimSession $CimSession
            $os = _GetGuestOS -CimSession $CimSession

            if ($os -ge 62) {
                $disks = Invoke-Command -Session $PSSession -ScriptBlock { Get-Disk } -Verbose:$false
            } else {
                $disks = Get-CimInstance -ClassName CIM_DiskDrive -CimSession $CimSession -Verbose:$false | Select -Property *
            }

            # Rename CDROM to Z:
            _RenameCDROM -CimSession $CimSession -DriveLetter 'Z'

            # Format each disk according to instructions
            foreach ($config in $desiredDiskConfigMapping) {

                # Do we have a matching guest disk
                $guestDisk = $guestDiskMapping |
                 Where-Object {(($_.HasSN) -and ($_.SerialNumber -eq $config.SerialNumber)) -or ((!$_.HasSN) -and ($_.SCSIBus -eq $config.SCSIController -and $_.SCSIUnit -eq $config.SCSITarget))} |
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
                            Disk = $disk
                            PSSession = $PSSession
                            PartitionStyle = 'GPT'
                            VolumeName = $config.VolumeName
                            VolumeLabel = $config.VolumeLabel
                            AllocationUnitSize = $config.BlockSize
                        }
                        if ($os -ge 62) {
                            _FormatGuestDisk @formatParams
                        } else {
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
            $guestDiskMapping = _GetGuestDiskToVMDiskMapping -VM $vm -CimSession $CimSession

            # Get formated disks
            if ($os -ge 62) {
                $gfd = @{
                    Session = $PSSession
                    ScriptBlock = {
                        Get-Disk | Where-Object {$_.PartitionStyle -ne 'Raw'}
                    }
                }
            $formatedDisks = Invoke-Command @gfd
            } else {
                $formatedDisks = $guestDiskMapping | where-object {$_.Format -ne ''}
            }

            foreach ($config in $desiredDiskConfigMapping) {

                # Do we have a matching guest disk from our mapping?
                $guestDisk = $guestDiskMapping |
                    Where-Object {(($_.HasSN) -and ($_.SerialNumber -eq $config.SerialNumber)) -or ((!$_.HasSN) -and ($_.SCSIBus -eq $config.SCSIController -and $_.SCSIUnit -eq $config.SCSITarget))} |
                    Select-Object -First 1 

                if ($guestDisk) {
                    if ($os -ge 62) {
                        $disk = $formatedDisks |
                            Where-Object {$_.Number -eq $guestDisk.WindowsDisk} |
                            Select-Object -first 1
                    } else {
                        $disk = $formatedDisks |
                            Where-Object {$_.WindowsDisk -eq $guestDisk.WindowsDisk} |
                            Select-Object -first 1
                    }

                    if ($null -ne $disk) {

                        # Get the partition
                        if ($os -ge 62) {
                            Write-Debug -Message "Looking at disk $($disk.Number)"
                            Write-Debug -Message "Using 2012 commands"
                            $gp = @{
                                Session = $PSSession
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
                                Session = $PSSession
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
                                    Session = $PSSession
                                    ArgumentList = @($partition, $sizes.SizeMax)
                                    ScriptBlock = { $args[0] | Resize-Partition -Confirm:$false -Size $args[1] }
                                    Verbose = $false
                                }
                                Invoke-Command @rp
                            }

                            $gv = @{
                                Session = $PSSession
                                ArgumentList = $partition
                                ScriptBlock = { $args[0] | Get-Volume }
                                Verbose =$false
                            }
                            $volume = Invoke-Command @gv

                            # Drive letter
                            if ($Volume.DriveLetter -ne $config.VolumeName) {
                                Write-Verbose -Message "Setting drive letter to [$($config.VolumeName)]"
                                $sdl = @{
                                    Session = $PSSession
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
                                    CimSession = $CimSession
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
                                Session = $PSSession
                                ArgumentList = $disk.WindowsDisk
                                ScriptBlock = {
                                    $diskInfo = New-Object psobject
                                    $windowsDisk = [int]$($args[0])
                                    $primaryPart = Get-WMIObject win32_diskpartition | where {($_.DiskIndex -eq $windowsDisk) -and ($_.PrimaryPartition -eq $true)}
                                    if ($primaryPart.count -gt 1) {
                                                $pass = $false
                                                $diskError = "Not able to configure $windowsDisk because it has more than 1 primary partition"
                                                Write-Error $diskError
                                                throw                                       
                                    }
                                    $diskID = '  Disk ' + $windowsDisk.ToString()
                                    $results = "list disk" | diskpart | ? {$_.startswith($diskID)}
                                    $results |% { 
                                        if ($_ -match 'Disk\s+(\d+)\s+\w+\s+(\d+)\s+\w+\s+(\d+)\s+(\w+)') {
                                            Add-Member -InputObject $diskInfo -MemberType Noteproperty -Name ExtraSpace -Value $($matches[3])
                                            Add-Member -InputObject $diskInfo -MemberType NoteProperty -Name DiskSize -Value $($matches[2])
                                            $command = "select disk $($matches[1])`r`nlist part"
                                            $x = $command |diskpart | where {($_ -notlike '*Reserved*') -and ($_ -notlike '*Unknown*') -and ($_ -match 'Partition\s\d')}
                                            if ($x.count -gt 1) {
                                                $pass = $false
                                                $diskError = "Not able to configure $windowsDisk because it has more than 1 primary partition"
                                                Write-Error $diskError
                                                throw
                                            }
                                            $results2 = $x | where {$_ -match 'Partition\s+(\d+).*\s+(\d+\s+\w+)\s+(.*)'}
                                            Add-Member -InputObject $diskInfo -Membertype Noteproperty -Name PartNum -Value ([convert]::ToInt32($matches[1], 10))
                                            #$tempSize = $matches[2].replace(' ', '')
                                            #$diskInBytes = [scriptblock]::Create($tempSize).Invoke()
                                            #$diskInGB = ([convert]::ToInt64($diskInBytes, 10) / 1GB)
                                            $diskInGB = ($primaryPart.size / 1GB)
                                            Add-Member -InputObject $diskInfo -Membertype Noteproperty -Name PartSize -Value $diskInGB
                                            #Lots of type casting magic to get the correct offset size in GB based on given type(KB, MB, or GB)
                                            #$offSet = $matches[3].replace(' ', '')
                                            #$sizeInBytes = [scriptblock]::Create($offSet).Invoke()
                                            #$sizeInGB = ([convert]::ToInt32($sizeInBytes, 10) / 1GB)
                                            $sizeInGB = ($primaryPart.StartingOffset / 1GB) 
                                            Add-Member -InputObject $diskInfo -Membertype NoteProperty -Name Offset -Value ([convert]::ToDecimal($sizeInGB))
                                        }
                                    }
                                    $diskInfo
                                }
                            }

                            $diskInfo = Invoke-Command @gs
                            Write-Debug $diskInfo

                            $actualSize = [math]::round($diskInfo.PartSize + $diskInfo.Offset)
                            if ($actualSize -lt $config.DiskSizeGB) {
                                Write-Verbose "Extending partition for disk $($disk.WindowsDisk)"
                                $ed = @{
                                    Session = $PSSession
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
                                    Session = $PSSession
                                        ArgumentList = $disk.WindowsDisk, $config.VolumeName, $diskInfo.PartNum
                                        ScriptBlock = {
                                            $DiskID = $args[0].ToString()
                                            $VolName = $args[1].ToString()
                                            $PartNum = $args[2].ToString()
                                            $x = "Select Disk $($DiskID)", "Select Partition $($PartNum)", "assign letter=$($VolName)" | diskpart | Out-Null
                                        }
                                    }
                                    $results = Invoke-Command @sdl
                            }

                            # Volume label
                            if ($disk.VolumeLabel -ne $config.VolumeLabel) {
                                Write-Verbose -Message "Setting volume to [$($config.VolumeLabel)]"
                                $gld = @{
                                    CimSession = $CimSession
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
        } catch {
            Write-Error -Message 'There was a problem configuring the guest disks'
            Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
            write-Error $_
        }
    }

    end {
        Write-Debug -Message 'Ending _SetGuestDisks()'
    }
}