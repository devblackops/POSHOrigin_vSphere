function _GetVMFolderPath {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $VM
    )

    $parent = $VM.Folder
    $path = $VM.Folder.Name
    While ($parent.ExtensionData.MoRef.Type -eq 'Folder') {
        $parent = $parent.Parent
        if ($parent.Name -ne 'vm') {
            $path = $parent.Name + "/" + $path
        }
    }
    return $path
}
