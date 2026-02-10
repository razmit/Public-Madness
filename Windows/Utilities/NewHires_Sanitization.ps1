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

# Sanitizes the raw Workday Excel file by:
#   1. Removing the first 9 rows (Workday report metadata/filters)
#   2. Using row 10 as headers (handling duplicates)
#   3. Filtering for El Salvador location ("SLV-San Salvador*")
#   4. Filtering for future hire dates only (Latest Hire Date > today)
#   5. Exporting to a clean, formatted Excel file
function Sanitize-NewHireReport {
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
        } else {
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
    # The -like operator with wildcard (*) matches any string starting with
    # "SLV-San Salvador" regardless of what comes after.

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
    # STEP 6: Export to new sanitized Excel file
    # --------------------------------------------------------------------------
    # Build the output filename with today's date for easy identification
    $outputFolder = "$env:USERPROFILE\Downloads\NewHires-Reports"
    $todayFormatted = Get-Date -Format "yyyy-MM-dd"
    $outputPath = "$outputFolder\NewHires_Sanitized_$todayFormatted.xlsx"

    # Export with table formatting for a clean, professional look
    # -AutoSize: Adjusts column widths to fit content
    # -TableName: Creates a formatted Excel table (enables sorting/filtering in Excel)
    # -TableStyle: Applies a predefined table style
    # -PassThru: Returns the Excel package object so we can apply additional formatting
    $excelPackage = $filteredData | Export-Excel -Path $outputPath `
        -AutoSize `
        -TableName "NewHires" `
        -TableStyle Medium2 `
        -FreezeTopRow `
        -PassThru

    # --------------------------------------------------------------------------
    # STEP 7: Format date columns to show date only (no time)
    # --------------------------------------------------------------------------
    # When ImportExcel reads dates, they become DateTime objects with a time
    # component (midnight). We need to apply a date-only format to these columns
    # so Excel displays them correctly without the "0:00" time suffix.

    $worksheet = $excelPackage.Workbook.Worksheets["NewHires"]

    # Find the column positions for date fields by checking the header row
    # (Row 1 contains headers after export)
    $dateColumns = @("Original Hire Date", "Latest Hire Date")

    for ($col = 1; $col -le $worksheet.Dimension.Columns; $col++) {
        $headerValue = $worksheet.Cells[1, $col].Value
        if ($dateColumns -contains $headerValue) {
            # Apply date format to entire column (from row 2 to last row)
            # "M/d/yyyy" matches the original Workday format without time
            $lastRow = $worksheet.Dimension.Rows
            $worksheet.Cells[2, $col, $lastRow, $col].Style.Numberformat.Format = "M/d/yyyy"
        }
    }

    # Save and close the Excel package
    Close-ExcelPackage $excelPackage

    Write-Host "`nSanitized file created: $outputPath" -ForegroundColor Green
    Write-Host "  Total records: $($filteredData.Count)" -ForegroundColor Green

    return $outputPath
}


# Checks if the "NewHires-Reports" folder exists in the user's Downloads directory.
function Confirm-ReportsFolderExists {
    
    $folderPath = "$env:USERPROFILE\Downloads\NewHires-Reports"
    
    if(Test-Path $folderPath) {
        return $true
    } else {
        Write-Host "The folder 'NewHires-Reports' does not exist in the Downloads directory. Creating..." -ForegroundColor Cyan
        
        New-Item -ItemType Directory -Path $folderPath | Out-Null
        Write-Host "Folder created at: $folderPath" -ForegroundColor Green
        return $true
    }
}


function Find-LatestRawReport {

    $downloadsPath = "$env:USERPROFILE\Downloads"
    $defaultFileName = "New Hire Onboarding - IT (Scheduled)"
    $todayDate = Get-Date -Format "yyyy-MM-dd"
    $todayFilePattern = "$defaultFileName $todayDate"
    Write-Host "Looking for today's raw report file with pattern: $todayFilePattern" -ForegroundColor Cyan
    
    if(Test-Path "$downloadsPath\$todayFilePattern*.xlsx") {
        $latestFile = Get-ChildItem -Path $downloadsPath -Filter "$todayFilePattern*.xlsx" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "Found today's raw report file: $($latestFile.FullName)" -ForegroundColor Green

        # Proceed to sanitize the file
        Sanitize-NewHireReport -FilePath $latestFile.FullName
    } else {
        Write-Host "No raw report file found for today ($todayDate). Please ensure the file is downloaded in the Downloads folder." -ForegroundColor Red
    }
}



# -------------------------------------------------
# |          SCRIPT EXECUTION STARTS HERE         |
# -------------------------------------------------
$folderExists = Confirm-ReportsFolderExists

if ($folderExists) {
    Write-Host "Ready to process new hire files..." -ForegroundColor Green
    
    Find-LatestRawReport
} else {
    Write-Host "Failed to confirm or create the 'NewHires-Reports' folder. Exiting script." -ForegroundColor Red
    exit 1
}
