$finished = $false

Connect-PnPOnline -Url https://rsmnet.sharepoint.com/sites/$baseURL -clientId f6666fe0-04e6-419a-b4bb-4025060af8f5 -interactive

$groupName = "National Tax PMO Owners"
$userEmail = "Thor.Rektorli@rsmus.com"

$groupMembers = Get-PnPGroupMember -Identity $groupName
$userExists = $groupMembers | Where-Object { $_.Email -eq $userEmail }

if ($userExists) {
    Write-Host "User already in group - skipping" -ForegroundColor Yellow
}
else {
    Write-Host "User not in group - safe to add" -ForegroundColor Green
}






# Clear-Host

# $optionsMenu = @'

# +--------------------------------------------------+
# |                                                  |
# |  Press [Enter] to begin or type 'Exit' to quit.  |
# |                                                  |
# +--------------------------------------------------+
# '@

# do {
#     Write-Host $optionsMenu -ForegroundColor Cyan
#     $enteredOption = Read-Host "Your choice? "
#     if ($enteredOption.ToLower() -eq "exit") {
#             Write-Host "Exiting Permissions-Man. Powodzenia!" -ForegroundColor Yellow
#             $finished = $true
#             exit
#     }
    
# } while ($finished)