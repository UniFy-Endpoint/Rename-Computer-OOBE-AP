<#
.SYNOPSIS
Renames a device using BIOS serial number during Autopilot Device Preparation (OOBE).

.DESCRIPTION
This script renames the computer during the OOBE phase using configurable naming options:
- Serial number only
- Prefix + Serial number
- Prefix + Random number

.PARAMETER TestMode
Shows what would happen if the script runs without making changes.

.EXAMPLE
.\Rename-Computer-OOBE-APv2_v2.4.ps1 -TestMode

.NOTES
    Author: Yoennis Olmo (updated & hardened)
    Version: v2.4
    Release Date: 08-12-2025

    Intune Info:
    Script type: Platform Script
    Assign to: (Devices) Autopilot Device Preparation - Just-In-Time Enrollment Devices Group.
    Script Settings:
    Run this script using the logged on credentials: No
    Enforce script signature check: No
    Run script in 64-bit PowerShell Host: Yes
#>

param(
    [switch]$TestMode
)

#region ========== ADMINISTRATOR CONFIGURATION ==========
# --------------------------------------------------------
# MODIFY THESE SETTINGS BEFORE PRODUCTION DEPLOYMENT
# --------------------------------------------------------

# NAMING MODE OPTIONS:
#   "SerialOnly"    - Use BIOS serial number only (e.g., "ABC123456")
#   "PrefixSerial"  - Use prefix + serial number (e.g., "ADP-ABC123456")
#   "PrefixRandom"  - Use prefix + random number (e.g., "ADP-7382915")
$NamingMode = "PrefixSerial"

# PREFIX SETTINGS (only used when NamingMode is "PrefixSerial" or "PrefixRandom")
# Keep prefix short to allow room for serial/random (max 15 chars total for NetBIOS)
$Prefix = "ADP"

# Include separator between prefix and serial/random? (e.g., "ADP-" vs "ADP")
$UseSeparator = $true
$Separator = "-"

# RANDOM NUMBER SETTINGS (only used when NamingMode is "PrefixRandom")
# Number of random digits to generate (will be adjusted if total exceeds 15 chars)
$RandomDigits = 8

# --------------------------------------------------------
# END OF ADMINISTRATOR CONFIGURATION
# --------------------------------------------------------
#endregion

#region ========== SCRIPT LOGIC (DO NOT MODIFY) ==========

# Create transcript for troubleshooting
$logPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
if (-not (Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}

$logFile = if ($TestMode) { "$logPath\Rename-Computer-OOBE-TEST.log" } else { "$logPath\Rename-Computer-OOBE.log" }
Start-Transcript -Path $logFile -Append

Write-Host "=== Computer Rename Script v2.4 Started ==="
Write-Host "Naming Mode: $NamingMode"
if ($TestMode) { 
    Write-Host "*** RUNNING IN TEST MODE - NO CHANGES WILL BE MADE ***" -ForegroundColor Yellow
}

$currentName = $env:COMPUTERNAME
Write-Host "Current Computer Name: $currentName"

# Calculate prefix length for truncation
$prefixPart = ""
if ($NamingMode -in @("PrefixSerial", "PrefixRandom")) {
    $prefixPart = if ($UseSeparator) { "$Prefix$Separator" } else { $Prefix }
    Write-Host "Using Prefix: $prefixPart"
}
$maxNamePartLength = 15 - $prefixPart.Length

# Validate prefix isn't too long
if ($maxNamePartLength -lt 4) {
    Write-Error "Prefix '$prefixPart' is too long. Maximum prefix length is 11 characters (including separator)."
    Stop-Transcript
    exit 1
}

# Function to generate random number string
function Get-RandomNumber {
    param([int]$Length)
    $chars = '0123456789'
    $random = -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $random
}

# Get BIOS serial number (needed for SerialOnly and PrefixSerial modes)
$serialNumber = $null
if ($NamingMode -in @("SerialOnly", "PrefixSerial")) {
    try {
        $serialNumber = (Get-CimInstance Win32_BIOS).SerialNumber
        Write-Host "BIOS Serial Number: $serialNumber"
    } catch {
        Write-Error "Failed to retrieve BIOS Serial Number: $_"
        Stop-Transcript
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($serialNumber)) {
        Write-Error "BIOS Serial Number is missing or empty."
        Stop-Transcript
        exit 1
    }
}

# Build the new computer name based on naming mode
switch ($NamingMode) {
    "SerialOnly" {
        # Sanitize: allow only letters and numbers
        $namePart = ($serialNumber.Trim() -replace '[^A-Za-z0-9]', '')

        # Truncate to 15 characters
        if ($namePart.Length -gt 15) {
            $namePart = $namePart.Substring(0, 15)
        }
        $newName = $namePart
    }

    "PrefixSerial" {
        # Sanitize: allow only letters and numbers
        $namePart = ($serialNumber.Trim() -replace '[^A-Za-z0-9]', '')

        # Truncate serial to fit within 15 chars total
        if ($namePart.Length -gt $maxNamePartLength) {
            $namePart = $namePart.Substring(0, $maxNamePartLength)
        }
        $newName = "$prefixPart$namePart"
    }

    "PrefixRandom" {
        # CHECK: If device already has the correct prefix, it was already renamed - SKIP
        if ($currentName -like "$prefixPart*") {
            Write-Host "Device already renamed with prefix '$prefixPart'. Current name: $currentName"
            Write-Host "No changes needed. Exiting."
            Stop-Transcript
            exit 0
        }

        # Generate new random name only if not already renamed
        $actualRandomDigits = [Math]::Min($RandomDigits, $maxNamePartLength)
        $namePart = Get-RandomNumber -Length $actualRandomDigits
        $newName = "$prefixPart$namePart"
        Write-Host "Generated random number: $namePart"
    }

    default {
        Write-Error "Invalid NamingMode: $NamingMode. Use 'SerialOnly', 'PrefixSerial', or 'PrefixRandom'."
        Stop-Transcript
        exit 1
    }
}

Write-Host "Generated Name: $newName (Length: $($newName.Length))"

# Ensure name is not empty
if ([string]::IsNullOrWhiteSpace($newName)) {
    Write-Error "Computer name is empty after processing."
    Stop-Transcript
    exit 1
}

# Validate final name length
if ($newName.Length -gt 15) {
    Write-Error "Generated name '$newName' exceeds 15 characters."
    Stop-Transcript
    exit 1
}

# Rename only if needed (for SerialOnly and PrefixSerial modes)
if ($newName -ieq $currentName) {
    Write-Host "Computer name is already set to $newName. No changes made."
    Stop-Transcript
    exit 0
}

try {
    Write-Host "Attempting to rename computer from '$currentName' to '$newName'..."

    if ($TestMode) {
        Write-Host "=======================================" -ForegroundColor Cyan
        Write-Host "TEST MODE RESULTS" -ForegroundColor Cyan
        Write-Host "=======================================" -ForegroundColor Cyan
        Write-Host "Naming Mode:   $NamingMode" -ForegroundColor Cyan
        Write-Host "Current Name:  $currentName" -ForegroundColor Cyan
        Write-Host "New Name:      $newName" -ForegroundColor Cyan
        Write-Host "Name Length:   $($newName.Length) / 15 characters" -ForegroundColor Cyan
        Write-Host "Name Valid:    $($newName -match '^[A-Za-z0-9-]+$')" -ForegroundColor Cyan
        Write-Host "=======================================" -ForegroundColor Cyan
        Write-Host "TEST MODE: No actual changes made" -ForegroundColor Green
    } else {
        Rename-Computer -NewName $newName -Force -ErrorAction Stop
        Write-Host "SUCCESS: Computer renamed to $newName." -ForegroundColor Green
        Write-Host "Note: Reboot required for change to take effect. Autopilot will handle the reboot."
    }

    Stop-Transcript
    exit 0
} catch {
    Write-Error "Rename failed: $_"
    Stop-Transcript
    exit 1
}

#endregion
