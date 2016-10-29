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
            $os = _GetGuestOS -VM $vm -Credential $credential
            $opt = New-CimSessionOption -Protocol DCOM
            $cim = New-CimSession -ComputerName $ip -Credential $Credential -SessionOption $opt -Verbose:$false
            $session = New-PSSession -ComputerName $ip -Credential $credential -Verbose:$false

            # Test Server 2012 or higher #
            if ($os -ge 62) {
                Write-Verbose -message 'Running 2012 disk tests'
                if ($ip) {

                    # Get mapped disks between the guest and VMware
                    $guestDiskMapping = _GetGuestDiskToVMDiskMapping -VM $vm -cim $cim -Credential $Credential

                    $disks = Invoke-Command -Session $session -ScriptBlock { Get-Disk }

                    # Compare the mapping to what is configured
                    foreach($config in $desiredDiskConfigMapping) {

                        # Do we have a matching guest disk
                        $guestDisk = $guestDiskMapping | Where-Object {$_.SerialNumber -eq $config.SerialNumber} | Select-Object -First 1

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
                                    if (($volume.FileSystemLabel -ne $config.VolumeLabel) -and ($config.VolumeLabel -ne $null)) {
                                        Write-Verbose -Message "Volume label [$($Volume.FileSystemLabel)] does not match configuration [$($config.VolumeLabel)]"
                                        $pass = $false
                                    }
                                } else {
                                    Write-Verbose -Message "Could not find partition for disk with SN [$($config.SerialNumber)]"
                                    $pass = $false
                                }
                            } else {
                                Write-Verbose -Message "Could not find matching formated disk with SN [$($guestDisk.SerialNumber)]"
                                $pass = $false
                            }
                        } else {
                            Write-Verbose -Message "Could not find disk with SN [$($config.SerialNumber)]"
                            $pass = $false
                        }
                    }
                } else {
                    Write-Error -Message 'No valid IP address returned from VM view. Can not test guest disks'
                    $pass = $true
                }
            } else {
                Write-verbose -Message 'Running 2008r2 disk tests'
                # Test Server 2008R2 or lower #
                if ($ip) {
                    $opt = New-CimSessionOption -Protocol DCOM
                    $cim = New-CimSession -ComputerName $ip -Credential $Credential -SessionOption $opt -Verbose:$false
                    $session = New-PSSession -ComputerName $ip -Credential $credential -Verbose:$false

                    # Get mapped disks between the guest and VMware
                    $guestDiskMapping = _GetGuestDiskToVMDiskMapping -VM $vm -cim $cim -Credential $Credential

                    $disks = Get-CimInstance -ClassName CIM_DiskDrive -CimSession $cim -verbose:$false | Select *


                    # Compare the mapping to what is configured
                    foreach($config in $desiredDiskConfigMapping) {

                        # Do we have a matching guest disk
                        $guestDisk = $guestDiskMapping | Where-Object {$_.SerialNumber -eq $config.SerialNumber} | Select-Object -First 1

                        if ($guestDisk) {

                            $disk = $disks | Where-Object {$_.SerialNumber -eq $guestDisk.SerialNumber} | Select-Object -First 1
                            if ($disk) {

                                Write-Debug -Message "Testing guest disk configuration [$($config.DiskName)]"                         
                                $diskInfo = $null
                                $gs = @{
                                    Session = $session
                                    ArgumentList = $guestdisk.WindowsDisk
                                    ScriptBlock = {
                                        $diskSize = New-Object psobject
                                        $tempString = '  Disk ' + $($args[0]).ToString()
                                        $results = "list disk" | diskpart | ? {$_.startswith($tempString)}
                                        $results |% { 
                                            if ($_ -match 'Disk\s+(\d+)\s+\w+\s+(\d+)\s+\w+\s+(\d+)\s+(\w+)') {
                                                Add-Member -InputObject $diskSize -MemberType Noteproperty -Name ExtraSpace -Value $($matches[3])
                                                Add-Member -InputObject $diskSize -MemberType NoteProperty -Name DiskSize -Value $($matches[2])
                                                $command = "select disk $($matches[1])`r`nlist part"
                                                $x = $command |diskpart | where {($_ -notlike '*Reserved*') -and ($_ -notlike '*Unknown*') -and ($_ -match 'Partition\s\d')}
                                                if ($x.count -gt 1) {
                                                    $pass = $false
                                                    $diskError = "Not able to configure$tempString because it has more than 1 primary partition"
                                                    Write-Error $diskError
                                                    throw
                                                }
                                                $results2 = $x | where {$_ -match 'Partition\s+(\d+)\s+\w+\s+(\d+)\s+\w+\s+(.*)'}
                                                Add-Member -InputObject $diskSize -Membertype Noteproperty -Name PartNum -Value $($matches[1]).ToInt32($null)
                                                Add-Member -InputObject $diskSize -Membertype Noteproperty -Name PartSize -Value $($matches[2]).ToDecimal($null)
                                                #Lots of type casting magic to get the correct offset size in GB based on given type(KB, MB, or GB)
                                                $offSet = $matches[3].replace(' ', '')
                                                $sizeInBytes = [scriptblock]::Create($offSet).Invoke()
                                                $sizeInGB = $sizeInBytes.ToInt32($null) / 1GB      
                                                Add-Member -InputObject $diskSize -Membertype NoteProperty -Name Offset -Value $sizeInGB.ToDecimal($null)
                                            }
                                        }
                                        $diskSize
                                    }
                                }
                                $diskInfo = Invoke-Command @gs
                                Write-Debug $diskInfo
                                $actualSize = [math]::ceiling($diskInfo.PartSize + $diskInfo.Offset)
                                if ($actualSize -ne $config.DiskSizeGB) {
                                    Write-Verbose -Message "Disk [$($guestdisk.WindowsDisk)] does not match configuration [$($actualSize) GB <> $($config.DiskSizeGB) GB]"
                                    $pass = $false
                                }

                                # Drive letter
                                if ($guestdisk.VolumeName -ne $config.VolumeName) {
                                    Write-Verbose -Message "Volume [$($guestDisk.VolumeName)] does not match configuration [$($config.VolumeName)]"
                                    $pass = $false
                                }

                                # Volume label
                                if (($guestdisk.VolumeLabel -ne $config.VolumeLabel) -and ($config.VolumeLabel -ne $null)) {
                                    Write-Verbose -Message "Volume label [$($guestdisk.VolumeLabel)] does not match configuration [$($config.VolumeLabel)]"
                                    $pass = $false
                                }                               
                            } else {
                                Write-Verbose -Message "Could not find matching formated disk with SN [$($guestDisk.SerialNumber)]"
                                $pass = $false
                            }
                        } else {
                            Write-Verbose -Message "Could not find disk [$($config.SerialNumber)]"
                            $pass = $false
                        }
                    }
                } else {
                        Write-Error -Message 'No valid IP address returned from VM view. Can not test guest disks'
                        $pass = $true
                }                  
            }
            Remove-CimSession -CimSession $cim -ErrorAction SilentlyContinue
            Remove-PSSession -Session $session -ErrorAction SilentlyContinue

            return $pass
        } catch {
            Write-Error -Message 'There was a problem testing the guest disks'
            Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
            write-Error -ErrorRecord $_
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