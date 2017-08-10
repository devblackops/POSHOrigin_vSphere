function _FormatOldGuestDisk {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $disk,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $PSSession,

        [ValidateSet('GPT', 'MBR')]
        [string]$PartitionStyle = 'GPT',

        [Parameter(Mandatory)]
        [string]$VolumeName,

        [string]$VolumeLabel = [string]::empty,

        [ValidateSet(4096, 8192, 16386, 32768, 65536)]
        [int]$AllocationUnitSize = 4096
    )

    Write-Debug -Message ($disk | fl * | Out-String)
    Write-Debug -Message "Looking at disk $($disk.Index)"

    try {

        #Test if disk is online or offline
        Write-Verbose -Message "Testing if disk [$($disk.Index)] is online"
        $diskID = $disk.Index
        $isOnlineParams = @{
            Session = $PSSession
            ArgumentList = $diskID
            Verbose = $false
            ScriptBlock = {
                $gstatus = $null
                $diskID = $args[0].ToString()
                $temp = "Select Disk $($diskID)", "detail disk" | diskpart
                $gstatus = ($temp | Select-String -Pattern 'Status : ').ToString().Substring(9)
                $gstatus
            }
        }
        $isOnline = Invoke-Command @isOnlineParams

        # Online the disk
        if ($isOnline -ne 'Online') {
            Write-Verbose -Message "Onlining disk [$($disk.Index)]"
            $onlineDiskParams = @{
                Session = $PSSession
                ArgumentList = $diskID
                Verbose = $false
                ScriptBlock = {
                    $diskID = $args[0].ToString()
                    $x = "Select Disk $($diskID)", "online disk noerr" | diskpart | Out-Null
                }
            }
            Invoke-Command @onlineDiskParams
        } else {
            Write-Debug -Message "Disk $($disk.Index) is already online"
        }

        $isReadOnlyParams = @{
            Session = $PSSession
            ArgumentList = $diskID
            Verbose = $false
            ScriptBlock = {
                $gronly = $null
                $diskID = $args[0].ToString()
                $temp = "Select Disk $($diskID)", "detail disk" | diskpart
                $gronly = ($temp | Select-String -Pattern 'Read-only  : ').ToString().Substring(13)
                $gronly
            }
        }
        $isReadOnly = Invoke-Command @isReadOnlyParams

        # Set Readonly to no
        if ($isReadOnly -ne 'No') {
            Write-Verbose -Message "Setting disk [$($disk.Index)] to Readonly = no"
            $readOnlyParams = @{
                Session = $PSSession
                ArgumentList = $diskID
                Verbose = $false
                ScriptBlock = {
                    $diskID = $args[0].ToString()
                    $x = "Select Disk $($diskID)", "attributes disk clear readonly" | diskpart | Out-Null
                }
            }
            Invoke-Command @readOnlyParams
        } else {
            Write-Debug -Message "Disk $($disk.Index) is already not ReadOnly"
        }


        if ($disk.Partitions -eq 0) {

            # Format the disk
            $formatParams = @{
                Session = $PSSession
                ArgumentList = @($disk.Index, $VolumeName, $VolumeLabel, $AllocationUnitSize, $PartitionStyle )
                ScriptBlock = {
                    $verbosePreference = $using:VerbosePreference
                    $diskID = $args[0].ToString()
                    $VolName = $args[1].ToString()
                    $VolLabel = $args[2].ToString()
                    $AlloSize = $args[3].ToString()
                    $PartStyle = $args[4].ToString()

                    # Initialize disk
                    Write-Verbose -Message "Initializing disk [$($diskID)] with [$($PartStyle)]"
                    $x = "Select Disk $($diskID)", "convert $($PartStyle)" | diskpart | Out-Null

                    # Create partition and format volume
                    Write-Verbose -Message "Creating partition [$($VolName)] on disk [$($diskID)]"
                    $x = "Select Disk $($diskID)", "create partition primary", "assign letter=$($VolName)", "format FS=NTFS quick label=$($VolLabel) Unit=$($AlloSize)" | diskpart | Out-Null
                }
            }
            Invoke-Command @formatParams
        } else {
            Write-Debug -Message "Disk [$($disk.Index)]is already initialized"
        }
    } catch {
        Write-Error -Message 'There was a problem configuring the guest disks'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error $_
    }
}