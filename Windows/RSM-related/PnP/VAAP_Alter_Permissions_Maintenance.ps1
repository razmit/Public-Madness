Connect-pnpOnline -Url https://rsmnet.sharepoint.com/sites/RolinForgeworld -clientId f6666fe0-04e6-419a-b4bb-4025060af8f5 -interactive

# Get all groups except Owners groups
$groups = Get-PnPGroup | Where-Object { $_.Title -notlike "*Owners*" }

# Array to hold original permissions
$originalPermissions = @()

foreach ($group in $groups) {
    
    $roleAssignments = Get-PnPGroupPermissions -Identity $group.Title
    
    $originalPermissions += [PSCustomObject]@{
        GroupName   = $group.Title
        Permissions = $roleAssignments.Name -join ","
    }
    
    # Set to read-only
    # Set-pnpgrouppermissions -Identity $group.Title -RemoveRole $roleAssignments.Name
    # Set-pnpgrouppermissions -Identity $group.Title -AddRole "Read"
}

# Export original permissions to CSV just in case I wrote this wrong
$originalPermissions | Export-Csv "PermissionsBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation

$originalPermissions | Format-Table

####### REVERT PERMISSIONS #########
$backup = Import-Csv "PermissionsBackup_20240620_153045.csv"  
foreach ($item in $backup) {
    Set-PnPGroupPermissions -Identity $item.GroupName -RemoveRole "Read"
    Set-PnPGroupPermissions -Identity $item.GroupName -AddRole ($item.Permissions -split ",")
}