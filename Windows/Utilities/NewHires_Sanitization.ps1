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
        
        # # Proceed to sanitize the file
        # Sanitize-NewHireReport -filePath $latestFile.FullName
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
