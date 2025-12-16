# ========================================
# Mass Add People to SharePoint Permission Groups
# ========================================
# This script adds users to SharePoint site permission groups
# Input: Excel file OR manual entry
# Output: Summary of additions with success/failure status
# ========================================

Import-Module -Name ImportExcel

# ========================================
# Configuration
# ========================================
$clientId = "f6666fe0-04e6-419a-b4bb-4025060af8f5"
$tenantUrl = "https://rsmnet.sharepoint.com"

# Define target groups (can be modified as needed)
$targetGroups = @("National Tax PMO Owners", "Tax Services Project Owners")

# Initialize result tracking
$results = @()
$totalAttempts = 0
$successfulAdds = 0
$skippedUsers = 0
$failedAdds = 0

# ========================================
# Functions
# ========================================

function Show-Menu {
    Clear-Host
    $menu = @'

+----------------------------------------------------------+
|                                                          |
|     Mass Add People to SharePoint Permission Groups     |
|                                                          |
+----------------------------------------------------------+
|                                                          |
|  [1] Import from Excel file                             |
|  [2] Manual entry (Terminal)                            |
|  [Exit] Quit the script                                 |
|                                                          |
+----------------------------------------------------------+

'@
    Write-Host $menu -ForegroundColor Cyan
}

function Get-ExcelData {
    Write-Host "`nExcel Import Mode" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan

    $excelPath = Read-Host "`nEnter the full path to your Excel file"

    if (-not (Test-Path $excelPath)) {
        Write-Host "✗ File not found: $excelPath" -ForegroundColor Red
        return $null
    }

    try {
        $excelData = Import-Excel -Path $excelPath

        # Validate required columns
        $firstRow = $excelData | Select-Object -First 1
        $columns = $firstRow.PSObject.Properties.Name

        if (-not ($columns -contains "New Users")) {
            Write-Host "✗ Excel file must contain a 'New Users' column" -ForegroundColor Red
            return $null
        }

        if (-not ($columns -contains "Site URL")) {
            Write-Host "✗ Excel file must contain a 'Site URL' column" -ForegroundColor Red
            return $null
        }

        Write-Host "✓ Excel file loaded successfully" -ForegroundColor Green
        Write-Host "  Found $($excelData.Count) row(s)" -ForegroundColor Gray

        return $excelData

    } catch {
        Write-Host "✗ Error reading Excel file: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-ManualData {
    Write-Host "`nManual Entry Mode" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan

    # Collect site URLs
    $siteUrls = @()
    Write-Host "`nEnter Site URLs (one at a time, press Enter with empty input to finish):" -ForegroundColor Yellow

    $counter = 1
    do {
        $url = Read-Host "  Site URL #$counter"
        if ($url.Trim() -ne "") {
            $siteUrls += $url.Trim()
            Write-Host "    ✓ Added: $url" -ForegroundColor Green
            $counter++
        }
    } while ($url.Trim() -ne "")

    if ($siteUrls.Count -eq 0) {
        Write-Host "✗ No site URLs entered" -ForegroundColor Red
        return $null
    }

    # Collect user emails
    $userEmails = @()
    Write-Host "`nEnter User Emails (one at a time, press Enter with empty input to finish):" -ForegroundColor Yellow

    $counter = 1
    do {
        $email = Read-Host "  User Email #$counter"
        if ($email.Trim() -ne "") {
            $userEmails += $email.Trim()
            Write-Host "    ✓ Added: $email" -ForegroundColor Green
            $counter++
        }
    } while ($email.Trim() -ne "")

    if ($userEmails.Count -eq 0) {
        Write-Host "✗ No user emails entered" -ForegroundColor Red
        return $null
    }

    # Create data structure matching Excel format
    $manualData = @()
    foreach ($url in $siteUrls) {
        foreach ($email in $userEmails) {
            $manualData += [PSCustomObject]@{
                "Site URL" = $url
                "New Users" = $email
            }
        }
    }

    Write-Host "`n✓ Manual data prepared: $($siteUrls.Count) site(s) x $($userEmails.Count) user(s) = $($manualData.Count) operation(s)" -ForegroundColor Green

    return $manualData
}

function Extract-UrlFromHyperlink {
    param([string]$urlString)

    # Check if it's a hyperlink format (Excel sometimes stores as "DisplayText#URL")
    if ($urlString -match '#') {
        $parts = $urlString -split '#'
        if ($parts.Count -gt 1) {
            return $parts[1]
        }
    }

    return $urlString
}

function Process-UserAdditions {
    param([array]$data)

    if ($null -eq $data -or $data.Count -eq 0) {
        Write-Host "`n✗ No data to process" -ForegroundColor Red
        return
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Processing User Additions" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total operations to perform: $($data.Count)" -ForegroundColor Gray
    Write-Host ""

    # Group data by site URL for efficient processing
    $groupedBySite = $data | Group-Object -Property "Site URL"

    foreach ($siteGroup in $groupedBySite) {
        $rawSiteUrl = $siteGroup.Name
        $siteUrl = Extract-UrlFromHyperlink -urlString $rawSiteUrl

        # Clean and validate URL
        if ($siteUrl -notmatch "^https://") {
            $siteUrl = "$tenantUrl/sites/$siteUrl"
        }

        Write-Host "`n----------------------------------------" -ForegroundColor Cyan
        Write-Host "Site: $siteUrl" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor Cyan

        # Connect to the site
        try {
            Write-Host "Connecting to site..." -ForegroundColor Gray
            Connect-PnPOnline -Url $siteUrl -ClientId $clientId -Interactive
            Write-Host "✓ Connected successfully" -ForegroundColor Green
        } catch {
            Write-Host "✗ Failed to connect: $($_.Exception.Message)" -ForegroundColor Red

            # Mark all users for this site as failed
            foreach ($row in $siteGroup.Group) {
                $script:totalAttempts++
                $script:failedAdds++
                $script:results += [PSCustomObject]@{
                    Site = $siteUrl
                    User = $row.'New Users'
                    Status = "Failed - Connection Error"
                    Message = $_.Exception.Message
                }
            }
            continue
        }

        # Process each target group
        foreach ($groupName in $targetGroups) {
            Write-Host "`n  Target Group: $groupName" -ForegroundColor Yellow

            # Verify group exists
            try {
                $group = Get-PnPGroup -Identity $groupName -ErrorAction Stop
                Write-Host "  ✓ Group found" -ForegroundColor Green
            } catch {
                Write-Host "  ✗ Group '$groupName' not found on this site - skipping" -ForegroundColor Red
                continue
            }

            # Get current group members
            try {
                $groupMembers = Get-PnPGroupMember -Identity $groupName
            } catch {
                Write-Host "  ✗ Failed to retrieve group members: $($_.Exception.Message)" -ForegroundColor Red
                continue
            }

            # Add each user
            foreach ($row in $siteGroup.Group) {
                $userEmail = $row.'New Users'

                if ([string]::IsNullOrWhiteSpace($userEmail)) {
                    continue
                }

                $script:totalAttempts++

                Write-Host "`n    Processing user: $userEmail" -ForegroundColor Gray

                # Check if user already exists in group
                $userExists = $groupMembers | Where-Object { $_.Email -eq $userEmail }

                if ($userExists) {
                    Write-Host "    ⊘ User already in group - skipping" -ForegroundColor Yellow
                    $script:skippedUsers++
                    $script:results += [PSCustomObject]@{
                        Site = $siteUrl
                        Group = $groupName
                        User = $userEmail
                        Status = "Skipped"
                        Message = "User already in group"
                    }
                } else {
                    # Add user to group
                    try {
                        Add-PnPGroupMember -Identity $groupName -EmailAddress $userEmail
                        Write-Host "    ✓ User added successfully to $groupName" -ForegroundColor Green
                        $script:successfulAdds++
                        $script:results += [PSCustomObject]@{
                            Site = $siteUrl
                            Group = $groupName
                            User = $userEmail
                            Status = "Success"
                            Message = "Added successfully"
                        }
                    } catch {
                        Write-Host "    ✗ Failed to add user: $($_.Exception.Message)" -ForegroundColor Red
                        $script:failedAdds++
                        $script:results += [PSCustomObject]@{
                            Site = $siteUrl
                            Group = $groupName
                            User = $userEmail
                            Status = "Failed"
                            Message = $_.Exception.Message
                        }
                    }
                }
            }
        }
    }
}

function Show-Summary {
    Write-Host "`n`n========================================" -ForegroundColor Cyan
    Write-Host "SUMMARY REPORT" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    Write-Host "`nTotal Operations:    $totalAttempts" -ForegroundColor White
    Write-Host "✓ Successful Adds:   $successfulAdds" -ForegroundColor Green
    Write-Host "⊘ Skipped (Existing): $skippedUsers" -ForegroundColor Yellow
    Write-Host "✗ Failed:            $failedAdds" -ForegroundColor Red

    # Show detailed results
    if ($results.Count -gt 0) {
        Write-Host "`n----------------------------------------" -ForegroundColor Cyan
        Write-Host "Detailed Results:" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor Cyan

        $results | Format-Table -Property Site, Group, User, Status, Message -AutoSize
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Script completed!" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

# ========================================
# Main Script Execution
# ========================================

Show-Menu

$choice = Read-Host "Select an option [1, 2, or Exit]"

switch ($choice.ToLower()) {
    "1" {
        # Excel Import Mode
        $data = Get-ExcelData
        if ($null -ne $data) {
            Process-UserAdditions -data $data
            Show-Summary
        }
    }
    "2" {
        # Manual Entry Mode
        $data = Get-ManualData
        if ($null -ne $data) {
            Process-UserAdditions -data $data
            Show-Summary
        }
    }
    "exit" {
        Write-Host "`nExiting script. Goodbye!" -ForegroundColor Yellow
        exit
    }
    default {
        Write-Host "`n✗ Invalid option. Please run the script again." -ForegroundColor Red
    }
}
