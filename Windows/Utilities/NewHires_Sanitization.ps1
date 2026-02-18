# WELCOME TO Niujair-Man
# NewHires_Sanitization.ps1
#
# Purpose: Clean and format the raw Excel file coming from Workday for new hires.
#          Removes unnecessary columns, formats names, and prepares the data for import.
#          Uploads the sanitized file to a specified SharePoint document library.
#
# Usage:
#   The script is intended to be set up as a daily scheduled task, so it can actively monitor the "Downloads" folder for new raw files and move them to a different folder, where it then will sanitize and upload them.

#   ./NewHires_Sanitization.ps1
#
# Parameters:
#   - None. All configurations are set within the script.
#
# Output:
#   - .xlsx file with the sanitized content specific to the USE office and for upcoming new hires.
#   - New file uploaded to SharePoint library "New Hires Reports" in the "ElSalvador_Office_IT_Support" site.
#
# Features:
#   - It only needs to be configured once in the Windows scheduled tasks to run daily.
#   - Automatically detects and processes new raw files in the "Downloads" folder.
#   - Cleans and formats data for easy import into the New Hires Power App and associated Flow
#   - Uploads the sanitized file to SharePoint for easy access by the HR and IT teams.
#   - Will detect if another instance of this script is already running to avoid conflicts.
#

$Global:SanitizedReportsFolder = "$env:USERPROFILE\Downloads\NewHires-Reports"
$Global:RawReportsFolder = "$env:USERPROFILE\Downloads"
$Global:OneDriveLibraryShortcut = "$env:USERPROFILE\OneDrive - RSM\ElSalvador_Office_ITSupport - New Hires Reports"
$Global:SharePointSiteUrl = "https://rsmnet.sharepoint.com/sites/ES_Office_ITSupport"

# Sanitizes the raw Workday Excel file by:
#   1. Removing the first 9 rows (Workday report metadata/filters)
#   2. Using row 10 as headers (handling duplicates)
#   3. Filtering for El Salvador location ("SLV-San Salvador*")
#   4. Filtering for future hire dates only (Latest Hire Date > today)
#   5. Exporting to a clean, formatted Excel file
function New-NewHireReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    Write-Host "`nStarting sanitization of: $FilePath" -ForegroundColor Cyan

    # --------------------------------------------------------------------------
    # STEP 1: Read headers and make duplicates unique
    # --------------------------------------------------------------------------
    # Workday exports often have duplicate or empty column headers.
    # ImportExcel fails on duplicates, so we:
    #   1. Read row 10 without headers to get raw header names
    #   2. Make each header unique by appending _2, _3, etc. to duplicates
    #   3. Re-import using our unique header names

    # First, read just the header row (row 10) as data
    $headerRow = Import-Excel -Path $FilePath -StartRow 10 -EndRow 10 -NoHeader

    # Extract header values from the first (and only) row
    # NoHeader gives us properties like P1, P2, P3... so we get their values
    $originalHeaders = $headerRow.PSObject.Properties | ForEach-Object { $_.Value }

    # Make headers unique by tracking occurrences
    $headerCounts = @{}
    $uniqueHeaders = @()

    foreach ($header in $originalHeaders) {
        # Handle null/empty headers
        $headerName = if ([string]::IsNullOrWhiteSpace($header)) { "EmptyColumn" } else { $header.ToString().Trim() }

        if ($headerCounts.ContainsKey($headerName)) {
            $headerCounts[$headerName]++
            $uniqueHeaders += "$headerName`_$($headerCounts[$headerName])"
        }
        else {
            $headerCounts[$headerName] = 1
            $uniqueHeaders += $headerName
        }
    }

    Write-Host "  Found $($uniqueHeaders.Count) columns (duplicates made unique)" -ForegroundColor Gray

    # --------------------------------------------------------------------------
    # STEP 2: Import the data using our unique headers
    # --------------------------------------------------------------------------
    # -StartRow 11 skips the original header row (row 10) since we provide our own
    # -HeaderName uses our de-duplicated headers

    $rawData = Import-Excel -Path $FilePath -StartRow 11 -HeaderName $uniqueHeaders

    # Quick validation: ensure we got data
    if ($null -eq $rawData -or $rawData.Count -eq 0) {
        Write-Host "ERROR: No data found after removing metadata rows. Check the file structure." -ForegroundColor Red
        return $null
    }

    Write-Host "  Imported $($rawData.Count) rows of data" -ForegroundColor Gray

    # --------------------------------------------------------------------------
    # STEP 3: Filter by Location - keep only "SLV-San Salvador*"
    # --------------------------------------------------------------------------

    $filteredByLocation = $rawData | Where-Object {
        $_."Location Proposed" -like "SLV-San Salvador*"
    }

    Write-Host "  After location filter (SLV-San Salvador*): $($filteredByLocation.Count) rows" -ForegroundColor Gray

    # --------------------------------------------------------------------------
    # STEP 4: Filter by Date - keep only future hire dates
    # --------------------------------------------------------------------------
    # We compare "Latest Hire Date" against today's date.
    # The [datetime] cast converts the Excel date value to a comparable date.
    # We use .Date on both sides to compare dates without time components.

    $today = (Get-Date).Date

    $filteredData = $filteredByLocation | Where-Object {
        # Handle potential null/empty dates gracefully
        if ($_."Latest Hire Date") {
            try {
                $hireDate = [datetime]$_."Latest Hire Date"
                return $hireDate.Date -gt $today
            }
            catch {
                # If date parsing fails, exclude this row
                return $false
            }
        }
        return $false
    }

    Write-Host "  After date filter (future dates only): $($filteredData.Count) rows" -ForegroundColor Gray

    # --------------------------------------------------------------------------
    # STEP 5: Validate we have results
    # --------------------------------------------------------------------------
    if ($filteredData.Count -eq 0) {
        Write-Host "WARNING: No records match the filters. No output file created." -ForegroundColor Yellow
        return $null
    }

    # --------------------------------------------------------------------------
    # STEP 6: Strip time component from date columns
    # --------------------------------------------------------------------------
    # Excel/ImportExcel stores dates as DateTime objects which include midnight.
    # We convert them to date-only strings to prevent "0:00" from appearing.
    # Using .ToString("M/d/yyyy") ensures consistent formatting.

    $dateColumnsToFormat = @("Original Hire Date", "Latest Hire Date", "Hire Completed Date")

    foreach ($row in $filteredData) {
        foreach ($dateCol in $dateColumnsToFormat) {
            if ($row.PSObject.Properties.Name -contains $dateCol -and $row.$dateCol) {
                try {
                    $row.$dateCol = ([datetime]$row.$dateCol).ToString("M/d/yyyy")
                }
                catch {
                    # If conversion fails, leave the value as-is
                }
            }
        }
    }

    # --------------------------------------------------------------------------
    # STEP 7: Export to new sanitized Excel file
    # --------------------------------------------------------------------------
    # Build the output filename with today's date for easy identification
    $todayFormatted = Get-Date -Format "yyyy-MM-dd"
    $outputPath = "$global:SanitizedReportsFolder\NewHires_Sanitized_$todayFormatted.xlsx"

    # Export with table formatting for a clean, professional look
    # -AutoSize: Adjusts column widths to fit content
    # -TableName: Creates a formatted Excel table (enables sorting/filtering in Excel)
    # -TableStyle: Applies a predefined table style
    # Note: Date columns were already converted to strings in Step 6, so no
    #       post-export formatting is needed.
    $filteredData | Export-Excel -Path $outputPath `
        -AutoSize `
        -TableName "NewHires" `
        -TableStyle Medium2 `
        -FreezeTopRow

    Write-Host "`nSanitized file created: $outputPath" -ForegroundColor Green
    Write-Host "  Total records: $($filteredData.Count)" -ForegroundColor Green
    write-Host "  Raw file moved to archive: $archiveFolder" -ForegroundColor Cyan
    Write-Host "------------------------------------------" -ForegroundColor White

    return $outputPath
}

# Function to verify what sanitized files have been alreayd transferred to the OneDrive shortcut folder for SharePoint upload to avoid duplicates.
function Get-AllOneDriveSanitizedFiles {

    try {
        # Make sure the shortcut exists
        if (Confirm-OneDriveLibraryShortcutExists) {
            
            $allUploadedReports = Get-ChildItem -Path $Global:OneDriveLibraryShortcut -Filter "*.xlsx" | Select-Object -ExpandProperty Name
            
            return $allUploadedReports
        }
        else {
            Write-Host "OneDrive shortcut to SharePoint library not found. Cannot confirm sanitized files in OneDrive." -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "An error occurred while trying to retrieve sanitized files from OneDrive: $_" -ForegroundColor Red
    }
}

# Utility function to find the latest sanitized report in the "NewHires-Reports" folder
function Find-LatestSanitizedReport {
    
    try {
        
        $latestFile = Get-ChildItem -Path $Global:SanitizedReportsFolder -Filter "NewHires_Sanitized_*.xlsx" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        return $latestFile
    }
    catch {
        Write-Host "No files were found in the $($Global:SanitizedReportsFolder) folder." -ForegroundColor Yellow
        return $null
    }
    
}

# Utility function to find all sanitized reports in the "NewHires-Reports" folder to confirm that all the expected files are present and to get their dates for comparison with the raw files in the Downloads folder. 
function Find-AllLocalSanitizedReports { 
    
    try {
        $sanitizedLocal = Get-ChildItem -Path $Global:SanitizedReportsFolder -File -Filter "*.xlsx" | Select-Object -ExpandProperty Name
        
        return $sanitizedLocal
    }
    catch {
        Write-Host "An error occurred while trying to retrieve sanitized reports: $_" -ForegroundColor Red
        exit 1
    }
    
}

# Checks if the "NewHires-Reports" folder exists in the user's Downloads directory.
function Confirm-ReportsFolderExists {
    
    if (Test-Path $global:SanitizedReportsFolder) {
        return $true
    }
    else {
        Write-Host "The folder 'NewHires-Reports' does not exist in the Downloads directory. Creating..." -ForegroundColor Cyan
        
        New-Item -ItemType Directory -Path $global:SanitizedReportsFolder | Out-Null
        Write-Host "Folder created at: $global:SanitizedReportsFolder" -ForegroundColor Green
        return $true
    }
}

# Confirms that the OneDrive shortcut to the SharePoint document library exists
function Confirm-OneDriveLibraryShortcutExists {
    
    # Checks if the expected shortcut path exists in the user's OneDrive directory
    if (Test-Path $global:OneDriveLibraryShortcut) {
        # Ensures that OneDrive is running to sync the shortcut properly
        $oneDriveProcess = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
        if ($null -eq $oneDriveProcess) { 
            Write-Host "Warning: OneDrive is not running. Please start OneDrive to ensure the shortcut is synced properly." -ForegroundColor Red
            exit 1
        }
        
        return $true
        
    }
    else {
        # If the shortcut doesn't exist, provide clear instructions to the user on how to create it
        Write-Host "OneDrive shortcut to SharePoint library not found at: $global:OneDriveLibraryShortcut" -ForegroundColor Red
        Write-Host "Please create a shortcut to the 'New Hires Reports' library in your OneDrive and run the script again." -ForegroundColor Yellow
        
        Write-Host "`n1. Visit $($global:SharePointSiteUrl) in your web browser." -ForegroundColor Yellow
        Write-Host "2. Navigate to the 'New Hires Reports' document library." -ForegroundColor Yellow
        Write-Host "3. Click 'Add shortcut to OneDrive' to create a OneDrive shortcut to the library." -ForegroundColor Yellow
        Write-Host "4. After the shortcut is created, run this script again." -ForegroundColor Yellow
        
        Write-Host "`nOpen the SharePoint site now? (Y/N)" -ForegroundColor Cyan
        $response = Read-Host " "
        if ($response -eq "y" -or $response -eq "Y") {
            Start-Process $global:SharePointSiteUrl
        }
        exit 1
    }
}

# Once the sanitized file has been created, upload it to the "NewHires-Reports" library
function Add-ReportToSharePoint {
    
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $ReportsToUpload
    )
    
    
    # Confirm that there's at least one sanitized report available to upload
    if (Find-LatestSanitizedReport) {
                
        # Confirm the folder shortcut to the SharePoint library exists before attempting to upload
        if (Confirm-OneDriveLibraryShortcutExists) {
            
            if ($ReportsToUpload) {
                
                # Make sure the file doesn't already exist in the OneDrive shortcut
                if (Test-Path "$global:OneDriveLibraryShortcut\$(Split-Path $ReportsToUpload -Leaf)") {
                    Write-Host "Today's report is already in the OneDrive shortcut for the SharePoint library. Do you wish to overwrite it? (Y/N)" -ForegroundColor Green
                    $overwriteResponse = Read-Host " "
                    if ($overwriteResponse -ne "y" -and $overwriteResponse -ne "Y") {
                        exit 0
                    }
                }
            
                Write-Host "`n------------------------------------------" -ForegroundColor White
                Write-Host "Preparing to upload the specified report to the OneDrive shortcut for SharePoint upload... $(Split-Path $ReportsToUpload -Leaf)" -ForegroundColor Cyan
                Write-Host "`n------------------------------------------" -ForegroundColor White
                
                Copy-Item -Path $ReportsToUpload -Destination $global:OneDriveLibraryShortcut
            
                Start-Sleep -Seconds 3 # Wait a moment to ensure the file is copied before checking for it in OneDrive
            
                if (Test-Path "$global:OneDriveLibraryShortcut\$(Split-Path $ReportsToUpload -Leaf)") {
                    Write-Host "File successfully uploaded to the OneDrive shortcut. It should sync to SharePoint shortly." -ForegroundColor Green
                }
                else {
                    Write-Host "Error: File was not found in the OneDrive shortcut after copying. Please check your OneDrive sync status." -ForegroundColor Red
                    exit 1
                }
            }
            else {
                
                # No specific reports to upload were provided, so we will proceed to upload the latest sanitized report by default
                
                # Confirm that the file we're going to copy doesn't already exist in the OneDrive shortcut folder to avoid duplicates. If it does, we can skip copying and just inform the user that the file should already be syncing to SharePoint.
            
                $fileToUpload = Find-LatestSanitizedReport
                Write-Host "Latest sanitized report to upload: $($fileToUpload.FullName)" -ForegroundColor Cyan
            
                if (Test-Path "$global:OneDriveLibraryShortcut\$(Split-Path $fileToUpload -Leaf)") {
                    Write-Host "Today's report is already in the OneDrive shortcut for the SharePoint library. Do you wish to overwrite it? (Y/N)" -ForegroundColor Green
                    $overwriteResponse = Read-Host " "
                    if ($overwriteResponse -ne "y" -and $overwriteResponse -ne "Y") {
                        exit 0
                    }
                }
            
                Write-Host "`n------------------------------------------" -ForegroundColor White
                Write-Host "Preparing to upload the latest sanitized report: $fileToUpload" -ForegroundColor Cyan
                Write-Host "`n------------------------------------------" -ForegroundColor White

                # Take the latest sanitized file and copy it to the OneDrive shortcut folder
                Copy-Item -Path $fileToUpload -Destination $global:OneDriveLibraryShortcut
            
                Start-Sleep -Seconds 5 # Wait a moment to ensure the file is copied before checking for it in OneDrive
            
                if (Test-Path "$global:OneDriveLibraryShortcut\$(Split-Path $fileToUpload -Leaf)") {
                    Write-Host "File successfully uploaded to the OneDrive shortcut. It should sync to SharePoint shortly." -ForegroundColor Green
                    exit 0
                }
                else {
                    Write-Host "Error: File was not found in the OneDrive shortcut after copying. Please check your OneDrive sync status." -ForegroundColor Red
                    exit 1
                }
            }
            
        }
    }
}

# Find the latest raw report file in the Downloads folder based on the expected naming convention and process it. If no new raw file is found, check for existing sanitized reports to determine if the user needs to download today's raw file or if they just need to wait for it to be processed.
function Find-LatestRawReport {
    
    # The name with which all raw reports come from Workday
    $defaultFileName = "New Hire Onboarding - IT (Scheduled)"
    # Get today's date in the same format as the raw file naming convention to find today's file
    $todayDate = Get-Date -Format "yyyy-MM-dd"
    # The expected name pattern for today's raw file
    $todayFilePattern = "$defaultFileName $todayDate"
    Write-Host "Looking for today's raw report file with pattern: $todayFilePattern" -ForegroundColor Cyan
    
    # Check if the expected file is in the Downloads folder
    if (Test-Path "$global:RawReportsFolder\$todayFilePattern*.xlsx") {
        
        # If the file exists, get the latest one (in case there are multiple with similar names) and proceed to sanitize it
        $latestFile = Get-ChildItem -Path $global:RawReportsFolder -Filter "$todayFilePattern*.xlsx" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "Found today's raw report file: $($latestFile.FullName)" -ForegroundColor Green

        # Proceed to sanitize the file
        New-NewHireReport -FilePath $latestFile.FullName
        
        Start-Sleep -Seconds 2 # Wait a moment to ensure the sanitized file is created before attempting to upload
        Add-ReportToSharePoint
    }
    else {
        
        # If no file with today's date is found, check if there's already a sanitized file with today's date. If not, warn the user to download the raw file and run the script again. This handles the case where the raw file hasn't been downloaded yet but we want to avoid confusion if a sanitized file from a previous day exists.
        $latestSanitizedReport = Find-LatestSanitizedReport
        
        if ($latestSanitizedReport) {
            
            # Isolate the latest sanitized report's date from its filename to compare with today's date
            
            $sanitizedReportDate = Get-Date ($latestSanitizedReport.BaseName -split "_")[-1] -Format "yyyy-MM-dd"
            
            Write-Host "Sanitized report date found: $sanitizedReportDate" -ForegroundColor Gray
            # Check if the latest sanitized report is from a previous date, which would indicate that today's raw file hasn't been processed yet. If so, prompt the user to download the raw file and run the script again. If the latest sanitized report is already from today, inform the user that no new raw file has been detected yet.
            if ($sanitizedReportDate -lt $todayDate) {
                Write-Host "No raw report file found for today ($todayDate). The latest sanitized report is from $sanitizedReportDate." -ForegroundColor Yellow
                
                # In case there's no raw report for today, get ALL of the raw reports currently present in the Downloads folder
                $allMatchingFiles = Get-ChildItem -Path $global:RawReportsFolder -Filter "$defaultFileName*.xlsx" | Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty Name
                
                # Get the dates of the raw files present in the Downloads folder
                $allMatchingFilesDates = $allMatchingFiles | ForEach-Object { ($_ -split " ")[6] }
                
                # Get ALL of the already sanitized reports in the "NewHires-Reports" folder 
                $allLocalSanitizedReports = Find-AllLocalSanitizedReports
                
                # Get the dates to compare with the raw files in the Downloads folder
                $localSanitizedDates = $allLocalSanitizedReports | ForEach-Object { ($_ -split "_")[-1] -replace ".xlsx", ""
                }
                
                # Get the dates that are missing from NewHires-Reports compared to the raw files in the Downloads folder to confirm which raw files have not been sanitized yet
                $missingDatesLocal = $allMatchingFilesDates | Where-Object { $localSanitizedDates -notcontains $_ }
                
                # If the count is greater than 0, it means there are raw files in the Downloads folder that have not been sanitized and moved to the "NewHires-Reports" folder yet. If the count is 0, it means all raw files in the Downloads folder have corresponding sanitized reports in the "NewHires-Reports" folder
                if ($missingDatesLocal.Count -gt 0) {
                    
                    foreach ($missingDate in $missingDatesLocal) {
                        # Get the actual file name for the missing date to sanitize it
                        $fileToSanitize = Get-ChildItem -Path $global:RawReportsFolder -Filter "$defaultFileName $missingDate*.xlsx" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

                        # Sanitize the missing file
                        New-NewHireReport -FilePath $fileToSanitize.FullName
                    }
                }

                # Get ALL of the already sanitized reports in the OneDrive shortcut folder for SharePoint upload to confirm which files have already been uploaded to SharePoint
                $allOneDriveSanitizedReports = Get-AllOneDriveSanitizedFiles
                
                # Get the dates to compare with the local sanitized files 
                $oneDriveDates = $allOneDriveSanitizedReports | ForEach-Object { ($_ -split "_")[-1] -replace ".xlsx", ""
                }
                
                # Get all the sanitized report dates that are missing from the OneDrive shortcut for SharePoint upload to confirm which sanitized reports have not been uploaded to SharePoint yet
                $missingFilesOneDrive = $localSanitizedDates | Where-Object { $oneDriveDates -notcontains $_ }
                
                # If the count is greater than 0, it means there are sanitized reports in the "NewHires-Reports" folder that have not been uploaded to SharePoint yet. If the count is 0, it means all local sanitized report dates have corresponding files in the OneDrive shortcut for SharePoint upload.
                if ($missingFilesOneDrive.Count -gt 0) { 
                    
                    foreach ($missingFile in $missingFilesOneDrive) {
                        $fileToUpload = Get-ChildItem -Path $Global:SanitizedReportsFolder -Filter "*_$missingFile.xlsx" 
                        
                        Add-ReportToSharePoint -ReportsToUpload $fileToUpload.FullName
                    }
                }
                else {
                    Write-Host "All local sanitized report dates have corresponding files in the OneDrive shortcut for SharePoint upload." -ForegroundColor Green
                }
                
                Write-Host "Please ensure the new raw file is downloaded in the Downloads folder and run the script again." -ForegroundColor Yellow
                exit 1
            }
            elseif ($sanitizedReportDate -eq $todayDate) {
                Write-Host "No new raw report file detected for today ($todayDate), but a sanitized report from today already exists." -ForegroundColor Yellow
                
                Write-Host "Moving to confirm that the file has already been uploaded to SharePoint..." -ForegroundColor Yellow
                Add-ReportToSharePoint
            }
        }
        Write-Host "No raw report file found for today ($todayDate), and no existing sanitized reports exist. Please ensure today's raw report from Workday is downloaded in the Downloads folder." -ForegroundColor Red -BackgroundColor White
        Write-Host "`n"
    }
}

# -------------------------------------------------
# |          SCRIPT EXECUTION STARTS HERE         |
# -------------------------------------------------
$folderExists = Confirm-ReportsFolderExists

if ($folderExists) {
    Write-Host "Ready to process new hire files..." -ForegroundColor Green
    
    Find-LatestRawReport
}
else {
    Write-Host "Failed to confirm or create the 'NewHires-Reports' folder. Exiting script." -ForegroundColor Red
    exit 1
}
