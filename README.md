# Rename-Computer-OOBE-APv2

## Overview

PowerShell script that automatically renames Windows devices during the Autopilot Device Preparation (OOBE) process. Supports multiple naming conventions that administrators can configure before deployment.

## Features

-  Multiple naming modes (Serial, Prefix+Serial, Prefix+Random)
-  Configurable prefix and separator
-  NetBIOS compliant naming (max 15 characters)
-  Automatic sanitization (removes special characters)
-  **Rename once only** - Device will not be renamed on subsequent script runs
-  Comprehensive logging for troubleshooting
-  Test mode for validation before deployment
-  Idempotent (safe to run multiple times)
-  Compatible with Autopilot Device Preparation

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Microsoft Intune
- Autopilot Device Preparation enabled
- Script must run as SYSTEM

---

## How the Script Handles Multiple Runs

The script is designed to rename the device **only once**. If the script runs again after the device has been renamed, it will detect this and skip the rename.

### Behavior by Naming Mode

| Mode | First Run | Second Run | Third Run |
|------|-----------|------------|-----------|
| `SerialOnly` | Rename to `493789065345` | Skip ✅ | Skip ✅ |
| `PrefixSerial` | Rename to `ADP-49378906` | Skip ✅ | Skip ✅ |
| `PrefixRandom` | Rename to `ADP-73829154` | Skip ✅ | Skip ✅ |

### How It Works

**SerialOnly & PrefixSerial modes:**
- The script compares the current computer name with the expected name
- If they match, the script exits without making changes

**PrefixRandom mode:**
- The script checks if the current computer name starts with the configured prefix
- If the prefix matches (e.g., `ADP-`), the device was already renamed → script exits
- If the prefix doesn't match, a new random number is generated and the device is renamed

This ensures that:
- ✅ Devices are renamed only once during Autopilot Device Preparation
- ✅ Subsequent script runs do not change the device name
- ✅ Random names remain stable after initial assignment

---

## Administrator Configuration Guide

### Before Uploading to Intune

Administrators **must** configure the script before uploading it to Intune. Follow these steps:

### Step 1: Open the Script

Open `Rename-Computer-OOBE-APv2_v2.4.ps1` in a text editor (Notepad, VS Code, or PowerShell ISE).

### Step 2: Locate the Configuration Section

Find this section near the top of the script (around lines 33-54):

```powershell
#region ========== ADMINISTRATOR CONFIGURATION ==========
# --------------------------------------------------------
# MODIFY THESE SETTINGS BEFORE PRODUCTION DEPLOYMENT
# --------------------------------------------------------

# NAMING MODE OPTIONS:
#   "SerialOnly"    - Use BIOS serial number only (e.g., "ABC123456")
#   "PrefixSerial"  - Use prefix + serial number (e.g., "ADP-ABC123456")
#   "PrefixRandom"  - Use prefix + random number (e.g., "ADP-7382915")
$NamingMode = "SerialOnly"

# PREFIX SETTINGS (only used when NamingMode is "PrefixSerial" or "PrefixRandom")
$Prefix = "ADP"

# Include separator between prefix and serial/random?
$UseSeparator = $true
$Separator = "-"

# RANDOM NUMBER SETTINGS (only used when NamingMode is "PrefixRandom")
$RandomDigits = 8

# --------------------------------------------------------
# END OF ADMINISTRATOR CONFIGURATION
# --------------------------------------------------------
#endregion
```

### Step 3: Choose Your Naming Mode

Change the `$NamingMode` value to one of the following options:

| Value | Description | Example Result |
|-------|-------------|----------------|
| `"SerialOnly"` | BIOS serial number only | `493789065345` |
| `"PrefixSerial"` | Prefix + serial number | `ADP-493789065` |
| `"PrefixRandom"` | Prefix + random number | `ADP-73829154` |

### Step 4: Configure Prefix (Optional)

If using `PrefixSerial` or `PrefixRandom`, configure these settings:

| Setting | Description | Default |
|---------|-------------|---------|
| `$Prefix` | Text before the serial/random number | `"ADP"` |
| `$UseSeparator` | Add separator after prefix | `$true` |
| `$Separator` | Character between prefix and number | `"-"` |
| `$RandomDigits` | Number of random digits (PrefixRandom only) | `8` |

### Step 5: Save the Script

Save the modified script file.

### Step 6: Test Before Deployment

Run the script in test mode to verify your configuration:

```powershell
.\Rename-Computer-OOBE-APv2_v2.4.ps1 -TestMode
```

### Step 7: Upload to Intune

Once testing is successful, upload the script to Intune.

---

## Configuration Examples

### Example 1: Serial Number Only (Default)

**Goal:** Name devices using only the BIOS serial number  
**Result:** `493789065345`

```powershell
$NamingMode = "SerialOnly"
```

No other changes needed.

---

### Example 2: Prefix + Serial Number with Dash

**Goal:** Name devices like `ADP-493789065`

```powershell
$NamingMode = "PrefixSerial"
$Prefix = "ADP"
$UseSeparator = $true
$Separator = "-"
```

---

### Example 3: Prefix + Serial Number without Separator

**Goal:** Name devices like `LAP493789065`

```powershell
$NamingMode = "PrefixSerial"
$Prefix = "LAP"
$UseSeparator = $false
```

---

### Example 4: Prefix + Random Number

**Goal:** Name devices like `PC-83729461`

```powershell
$NamingMode = "PrefixRandom"
$Prefix = "PC"
$UseSeparator = $true
$Separator = "-"
$RandomDigits = 8
```

---

### Example 5: Department-Based Naming

**Goal:** Name devices for different departments

**For IT Department:** `IT-493789065`
```powershell
$NamingMode = "PrefixSerial"
$Prefix = "IT"
$UseSeparator = $true
$Separator = "-"
```

**For Sales Department:** `SALES-4937890`
```powershell
$NamingMode = "PrefixSerial"
$Prefix = "SALES"
$UseSeparator = $true
$Separator = "-"
```

---

## Quick Reference Table

| What You Want | $NamingMode | $Prefix | $UseSeparator | Result |
|---------------|-------------|---------|---------------|--------|
| `493789065345` | `"SerialOnly"` | - | - | Serial only |
| `ADP-493789065` | `"PrefixSerial"` | `"ADP"` | `$true` | Prefix + dash + serial |
| `ADP493789065` | `"PrefixSerial"` | `"ADP"` | `$false` | Prefix + serial (no dash) |
| `PC-73829154` | `"PrefixRandom"` | `"PC"` | `$true` | Prefix + dash + random |
| `LAP73829154` | `"PrefixRandom"` | `"LAP"` | `$false` | Prefix + random (no dash) |

---

## NetBIOS 15-Character Limit

Windows computer names have a maximum of 15 characters. The script automatically truncates names to fit this limit.

### Maximum Serial/Random Length by Prefix

| Prefix | Separator | Total Prefix Length | Max Serial/Random |
|--------|-----------|---------------------|-------------------|
| None | None | 0 | 15 |
| `ADP` | `-` | 4 | 11 |
| `PC` | `-` | 3 | 12 |
| `LAP` | `-` | 4 | 11 |
| `SALES` | `-` | 6 | 9 |
| `CONTOSO` | `-` | 8 | 7 |

**Important:** Keep your prefix short (max 11 characters including separator) to allow room for the serial/random number.

---

## Deployment in Intune

### Script Settings

| Setting | Value |
|---------|-------|
| **Script type** | Platform Script |
| **Assign to** | Autopilot Device Preparation - Just-In-Time Enrollment Devices Group |
| **Run this script using the logged on credentials** | No |
| **Enforce script signature check** | No |
| **Run script in 64-bit PowerShell Host** | Yes |

### Deployment Steps

1. Configure the script using the steps above
2. Navigate to **Microsoft Intune admin center**
3. Go to **Devices** > **Scripts** > **Add** > **Windows 10 and later**
4. Upload the configured `Rename-Computer-OOBE-APv2_v2.4.ps1` script
5. Configure settings as per the table above
6. Assign to your Autopilot Device Preparation device group
7. Save and deploy

---

## Testing

### Test Mode (Recommended Before Production)

Always test your configuration before deploying to production:

```powershell
.\Rename-Computer-OOBE-APv2_v2.4.ps1 -TestMode
```

### Expected Test Output (First Run)

```
=== Computer Rename Script v2.4 Started ===
Naming Mode: PrefixSerial
*** RUNNING IN TEST MODE - NO CHANGES WILL BE MADE ***
Current Computer Name: DESKTOP-ABC123
BIOS Serial Number: 4937-8906-5345-
Using Prefix: ADP-
Generated Name: ADP-49378906 (Length: 12)
=======================================
TEST MODE RESULTS
=======================================
Naming Mode:   PrefixSerial
Current Name:  DESKTOP-ABC123
New Name:      ADP-49378906
Name Length:   12 / 15 characters
Name Valid:    True
=======================================
TEST MODE: No actual changes made
```

### Expected Output (Already Renamed - PrefixRandom Mode)

```
=== Computer Rename Script v2.4 Started ===
Naming Mode: PrefixRandom
Current Computer Name: ADP-73829154
Using Prefix: ADP-
Device already renamed with prefix 'ADP-'. Current name: ADP-73829154
No changes needed. Exiting.
```

### Expected Output (Already Renamed - SerialOnly/PrefixSerial Mode)

```
=== Computer Rename Script v2.4 Started ===
Naming Mode: PrefixSerial
Current Computer Name: ADP-49378906
BIOS Serial Number: 4937-8906-5345-
Using Prefix: ADP-
Generated Name: ADP-49378906 (Length: 12)
Computer name is already set to ADP-49378906. No changes made.
```

### Production Mode

Run without parameters to actually rename:

```powershell
.\Rename-Computer-OOBE-APv2_v2.4.ps1
```

---

## Log Locations

| Log Type | Path |
|----------|------|
| **Test Mode** | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Rename-Computer-OOBE-TEST.log` |
| **Production** | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Rename-Computer-OOBE.log` |

### View Logs

```powershell
Get-Content "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Rename-Computer-OOBE.log"
```

---

## Troubleshooting

### Device Not Renamed

1. **Check the logs** for error messages
2. **Verify script ran** in Intune device status
3. **Confirm device rebooted** after script execution
4. **Check BIOS serial number** is not empty

### Verify BIOS Serial Number

```powershell
(Get-CimInstance Win32_BIOS).SerialNumber
```

### Invalid Naming Mode Error

Ensure `$NamingMode` is exactly one of:
- `"SerialOnly"`
- `"PrefixSerial"`
- `"PrefixRandom"`

### Prefix Too Long Error

If you see "Prefix is too long" error, shorten your prefix. Maximum prefix length (including separator) is 11 characters.

### Name Already Set

If the device already has the correct name, the script will skip renaming and exit successfully. This is expected behavior.

### Device Renamed Multiple Times (PrefixRandom)

If you're using v2.3 or earlier with PrefixRandom mode, upgrade to v2.4 which includes a fix to prevent multiple renames.

---

## Version History

### v2.4 (2025-12-08)
- ✅ **Fixed PrefixRandom mode** - Device now only renamed once (checks if prefix already exists)
- ✅ Added prefix detection for PrefixRandom to prevent multiple renames
- ✅ Improved logging for "already renamed" scenarios

### v2.3 (2025-12-08)
- ✅ Added configurable naming modes (SerialOnly, PrefixSerial, PrefixRandom)
- ✅ Added configurable prefix and separator options
- ✅ Added random number generation option
- ✅ Improved administrator configuration section
- ✅ Enhanced test mode output

### v2.2 (2025-12-08)
- ✅ Fixed regex to remove hyphens from serial numbers
- ✅ Changed `[^A-Za-z0-9-]` to `[^A-Za-z0-9]`

### v2.1 (2025-12-01)
- ✅ Removed OOBE registry check
- ✅ Removed forced reboot
- ✅ Added comprehensive logging
- ✅ Fixed truncation to 15 characters
- ✅ Added test mode parameter

### v2.0 (2025-10-02)
- Initial hardened version

---

## Best Practices

1. **Always test first** - Use `-TestMode` before production deployment
2. **Keep prefixes short** - Leave room for serial/random numbers
3. **Document your choice** - Record which naming mode you're using
4. **Use consistent naming** - Use the same configuration across all devices
5. **Monitor logs** - Check logs after deployment to verify success
6. **Use v2.4 or later** - Ensures devices are only renamed once

---

## Known Limitations

- Maximum 15 characters due to NetBIOS limitation
- Requires valid BIOS serial number (for SerialOnly and PrefixSerial modes)
- Some VMs may have generic serial numbers
- Name change requires reboot to take effect
- PrefixRandom: Very small chance of duplicate names across devices

---

## Support

For issues or questions:
- Check the troubleshooting section above
- Review logs for detailed error messages
- Verify Intune deployment settings
- Test on a single device before mass deployment

## Info

**Version:** v2.4  
**Author:** Yoennis Olmo  
**Release Date:** 2025-12-08

---

**Note:** This script is specifically designed for Autopilot Device Preparation. For traditional Autopilot or manual deployments, modifications may be required.
