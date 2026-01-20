function Write-Step {
    param([string]$Message)
    Write-Host "`n▶ $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Update-EnvironmentPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + 
    [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-NodeTools {
    Write-Step "Checking Node.js installation"
    
    if (!(Test-CommandExists "node")) {
        Write-Failure "Node.js not found. Please install Node.js 22 first."
        Write-Host "Visit: https://nodejs.org/" -ForegroundColor Yellow
        exit 1
    }
    
    $nodeVersion = node --version
    Write-Success "Node.js $nodeVersion found"
}

function Install-GlobalPackages {
    Write-Step "Installing global npm packages"
    
    try {
        # Install Yeoman
        Write-Host "  Installing Yeoman..." -NoNewline
        npm install -g yo 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success " Done"
        }
        else {
            throw "Yeoman installation failed"
        }
        
        # Install SPFx Generator
        Write-Host "  Installing SPFx Generator..." -NoNewline
        npm install -g @microsoft/generator-sharepoint 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success " Done"
        }
        else {
            throw "SPFx Generator installation failed"
        }
        
        # Install Heft
        Write-Host "  Installing Heft..." -NoNewline
        npm install -g @rushstack/heft 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success " Done"
        }
        else {
            throw "Heft installation failed"
        }
        
        # Install CLI for M365
        Write-Host "  Installing CLI for Microsoft 365..." -NoNewline
        npm install -g @pnp/cli-microsoft365 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success " Done"
        }
        else {
            throw "CLI installation failed"
        }
        
        # Refresh PATH
        Update-EnvironmentPath
        
        Write-Success "All packages installed successfully"
    }
    catch {
        Write-Failure "Installation failed: $_"
        exit 1
    }
}

function Install-DevCertificate {
    Write-Step "Installing development certificate"
    
    try {
        npx @rushstack/heft trust-dev-cert
        Write-Success "Development certificate installed"
    }
    catch {
        Write-Failure "Certificate installation failed: $_"
    }
}

function Confirm-Installation {
    Write-Step "Verifying installation"
    
    $allGood = $true
    
    # Node
    if (Test-CommandExists "node") {
        Write-Success "Node.js: $(node --version)"
    }
    else {
        Write-Failure "Node.js: Not found"
        $allGood = $false
    }
    
    # npm
    if (Test-CommandExists "npm") {
        Write-Success "npm: v$(npm --version)"
    }
    else {
        Write-Failure "npm: Not found"
        $allGood = $false
    }
    
    # Yeoman
    if (Test-CommandExists "yo") {
        Write-Success "Yeoman: v$(yo --version)"
    }
    else {
        Write-Failure "Yeoman: Not found"
        $allGood = $false
    }
    
    # Heft
    if (Test-CommandExists "heft") {
        Write-Success "Heft: v$(heft --version)"
    }
    else {
        Write-Failure "Heft: Not found"
        $allGood = $false
    }
    
    # SPFx Generator
    $npmList = npm list -g @microsoft/generator-sharepoint --depth=0 2>&1 | Out-String
    if ($npmList -match '@microsoft/generator-sharepoint@([\d.]+)') {
        Write-Success "SPFx Generator: v$($matches[1])"
    }
    else {
        Write-Failure "SPFx Generator: Not found"
        $allGood = $false
    }
    
    # CLI for M365
    if (Test-CommandExists "m365") {
        Write-Success "CLI for Microsoft 365: v$(m365 --version)"
    }
    else {
        Write-Failure "CLI for Microsoft 365: Not found"
        $allGood = $false
    }
    
    if ($allGood) {
        Write-Host "`n🎉 All tools installed successfully!" -ForegroundColor Green
        Write-Host "You're ready to build SPFx apps!" -ForegroundColor Green
    }
    else {
        Write-Host "`n⚠ Some tools are missing. Please check the errors above." -ForegroundColor Yellow
    }
}

# Main execution
Write-Host "=== SPFx Development Environment Setup ===" -ForegroundColor Magenta

Install-NodeTools
Install-GlobalPackages
Install-DevCertificate
Confirm-Installation

Write-Host "`nSetup complete! 🚀" -ForegroundColor Green
