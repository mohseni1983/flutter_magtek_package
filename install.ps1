# Magtek Card Reader Plugin Windows Installation Script
# This script sets up the required dependencies for Windows development

param(
    [Switch]$SkipVcpkg,
    [Switch]$Force,
    [String]$VcpkgPath = "C:\vcpkg"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Magtek Card Reader Plugin Windows Installation ===" -ForegroundColor Green
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "This script should be run as Administrator for best results."
    Write-Host "Some operations may fail without administrator privileges."
    Write-Host ""
}

# Check Windows version
$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -lt 10) {
    Write-Error "Windows 10 or later is required. Current version: $($osVersion)"
    exit 1
}

Write-Host "Detected Windows version: $($osVersion)" -ForegroundColor Blue
Write-Host ""

# Check if Flutter is installed
try {
    $flutterVersion = flutter --version 2>$null | Select-String "Flutter" | Select-Object -First 1
    Write-Host "Flutter found: $($flutterVersion)" -ForegroundColor Green
} catch {
    Write-Error "Flutter is not installed or not in PATH. Please install Flutter first."
    exit 1
}

# Enable Flutter desktop support
Write-Host "Enabling Flutter Windows desktop support..." -ForegroundColor Yellow
try {
    flutter config --enable-windows-desktop
    Write-Host "Flutter Windows desktop support enabled." -ForegroundColor Green
} catch {
    Write-Warning "Failed to enable Flutter desktop support. You may need to do this manually."
}

Write-Host ""

# Check for Visual Studio or Build Tools
Write-Host "Checking for Visual Studio C++ tools..." -ForegroundColor Yellow
$vsInstallations = @()

# Check for Visual Studio 2022
$vs2022Path = "${env:ProgramFiles}\Microsoft Visual Studio\2022"
if (Test-Path $vs2022Path) {
    $editions = @("Enterprise", "Professional", "Community", "BuildTools")
    foreach ($edition in $editions) {
        $editionPath = Join-Path $vs2022Path $edition
        if (Test-Path $editionPath) {
            $vsInstallations += "Visual Studio 2022 $edition"
        }
    }
}

# Check for Visual Studio 2019
$vs2019Path = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019"
if (Test-Path $vs2019Path) {
    $editions = @("Enterprise", "Professional", "Community", "BuildTools")
    foreach ($edition in $editions) {
        $editionPath = Join-Path $vs2019Path $edition
        if (Test-Path $editionPath) {
            $vsInstallations += "Visual Studio 2019 $edition"
        }
    }
}

if ($vsInstallations.Count -eq 0) {
    Write-Error @"
Visual Studio 2019 or later with C++ development tools is required.
Please install one of the following:
- Visual Studio 2022 Community (free)
- Visual Studio 2019 Community (free)
- Visual Studio Build Tools

Download from: https://visualstudio.microsoft.com/downloads/
Make sure to include the 'Desktop development with C++' workload.
"@
    exit 1
} else {
    Write-Host "Found Visual Studio installations:" -ForegroundColor Green
    $vsInstallations | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }
}

Write-Host ""

# HIDAPI Installation via vcpkg
if (-not $SkipVcpkg) {
    Write-Host "Setting up HIDAPI via vcpkg..." -ForegroundColor Yellow
    
    # Check if vcpkg is already installed
    if (-not (Test-Path $VcpkgPath) -or $Force) {
        Write-Host "Installing vcpkg to $VcpkgPath..." -ForegroundColor Yellow
        
        if (Test-Path $VcpkgPath) {
            Write-Host "Removing existing vcpkg installation..." -ForegroundColor Yellow
            Remove-Item -Recurse -Force $VcpkgPath
        }
        
        try {
            git clone https://github.com/Microsoft/vcpkg.git $VcpkgPath
            Set-Location $VcpkgPath
            .\bootstrap-vcpkg.bat
            
            # Integrate with Visual Studio
            .\vcpkg integrate install
            
            Write-Host "vcpkg installed successfully." -ForegroundColor Green
        } catch {
            Write-Error "Failed to install vcpkg: $_"
            exit 1
        }
    } else {
        Write-Host "vcpkg already installed at $VcpkgPath" -ForegroundColor Green
        Set-Location $VcpkgPath
    }
    
    # Install HIDAPI
    Write-Host "Installing HIDAPI for x64 architecture..." -ForegroundColor Yellow
    try {
        .\vcpkg install hidapi:x64-windows
        Write-Host "HIDAPI installed successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to install HIDAPI via vcpkg. The plugin will use Windows HID APIs directly."
    }
    
    # Set environment variable for CMake
    $cmakeToolchain = Join-Path $VcpkgPath "scripts\buildsystems\vcpkg.cmake"
    [Environment]::SetEnvironmentVariable("CMAKE_TOOLCHAIN_FILE", $cmakeToolchain, "User")
    Write-Host "Set CMAKE_TOOLCHAIN_FILE environment variable." -ForegroundColor Green
    
    Write-Host ""
}

# Device Driver Information
Write-Host "Device Driver Information:" -ForegroundColor Yellow
Write-Host @"
Windows 10+ should automatically install HID drivers for Magtek devices.
If your device is not recognized:
1. Connect your Magtek card reader
2. Open Device Manager (devmgmt.msc)
3. Look for unrecognized devices under 'Other devices'
4. Right-click and select 'Update driver'
5. Choose 'Search automatically for drivers'

If automatic driver installation fails, download drivers from:
https://www.magtek.com/support/software-drivers
"@ -ForegroundColor Cyan

Write-Host ""

# Project setup
$currentDir = Get-Location
Write-Host "Setting up Flutter project..." -ForegroundColor Yellow

try {
    # Check if we're in the correct directory
    if (-not (Test-Path "pubspec.yaml")) {
        Write-Warning "pubspec.yaml not found. Make sure you're running this script from the plugin root directory."
    } else {
        flutter pub get
        Write-Host "Flutter dependencies installed." -ForegroundColor Green
    }
} catch {
    Write-Warning "Failed to install Flutter dependencies: $_"
}

Write-Host ""

# Build test
Write-Host "Testing Windows build..." -ForegroundColor Yellow
try {
    if (Test-Path "example") {
        Set-Location "example"
        flutter build windows --debug
        Write-Host "Windows build test successful!" -ForegroundColor Green
        Set-Location $currentDir
    }
} catch {
    Write-Warning "Windows build test failed: $_"
    Write-Host "You may need to resolve build dependencies manually."
}

Write-Host ""

# Verification
Write-Host "Installation Verification:" -ForegroundColor Yellow

# Check Flutter
Write-Host "✓ Flutter installed and configured" -ForegroundColor Green

# Check Visual Studio
Write-Host "✓ Visual Studio C++ tools available" -ForegroundColor Green

# Check vcpkg
if (-not $SkipVcpkg -and (Test-Path $VcpkgPath)) {
    Write-Host "✓ vcpkg installed and configured" -ForegroundColor Green
    
    # Check HIDAPI
    $hidapiInstalled = & "$VcpkgPath\vcpkg" list | Select-String "hidapi"
    if ($hidapiInstalled) {
        Write-Host "✓ HIDAPI available via vcpkg" -ForegroundColor Green
    } else {
        Write-Host "⚠ HIDAPI not found, will use Windows HID APIs" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ vcpkg skipped, will use Windows HID APIs directly" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Connect your Magtek card reader" -ForegroundColor White
Write-Host "2. Verify device recognition in Device Manager" -ForegroundColor White
Write-Host "3. Run the example app: flutter run -d windows" -ForegroundColor White
Write-Host "4. Test card reading functionality" -ForegroundColor White
Write-Host ""
Write-Host "For detailed setup instructions, see WINDOWS_SETUP.md" -ForegroundColor Cyan
Write-Host "For troubleshooting, see README.md" -ForegroundColor Cyan

# Pause to show results
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
