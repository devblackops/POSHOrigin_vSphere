function _FormatOldGuestDisk {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $disk,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $session,

        [ValidateSet('GPT', 'MBR')]
        [string]$PartitionStyle = 'GPT',

        [Parameter(Mandatory)]
        [string]$VolumeName,

        [string]$VolumeLabel = [string]::empty,

        [ValidateSet(4096, 8192, 16386, 32768, 65536)]
        [int]$AllocationUnitSize = 4096,

        [Parameter(Mandatory)]
        $cim
    )

    Write-Debug -Message ($disk | fl * | Out-String)
    Write-Debug -Message "Looking at disk $($disk.Index)"
    
    try {
        # Online the disk
        Write-Verbose -Message "Onlining disk [$($disk.Number)]"
        $diskID = $disk.Index
        $onlineDiskParams = @{
            Session = $session
            ArgumentList = $diskID
            Verbose = $false
            ScriptBlock = {
                "Select Disk $($args[0])", "online disk noerr", "attributes disk clear readonly" | diskpart | Out-Null
            }
        }
        Invoke-Command @onlineDiskParams
        
        if ($disk.Partitions -eq 0) {

            # Format the disk
            $formatParams = @{
                Session = $session
                ArgumentList = @($disk, $VolumeName, $VolumeLabel, $AllocationUnitSize, $PartitionStyle )
                ScriptBlock = {
                    $verbosePreference = $using:VerbosePreference

                    # Initialize disk
                    Write-Verbose -Message "Initializing disk [$($args[0].Index)] with [$($args[4])]"
                    "Select Disk $($args[0].Index)", "convert $($args[4])" | diskpart | Out-Null

                    # Create partition and format volume
                    Write-Verbose -Message "Creating partition [$($args[1])] on disk [$($args[0].Index)]"
                    "Select Disk $($args[0].Index)", "create partition primary", "assign letter=$($args[1])", "format FS=NTFS label=$($args[2]) Unit=$($args[3])" | diskpart | Out-Null
                }
            }
            Invoke-Command @formatParams
        }
    } catch {
        Write-Error -Message 'There was a problem configuring the guest disks'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error $_
    }
}