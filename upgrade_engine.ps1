# Upgrade engine v1.0.0
# Author: AuxGrep
# Date: 2025-02-16
# Email: mranonymoustz@tutanota.com

# LETS START CODING.................
# lets start with the variables
$fileSharePath = "\\<PLEASE_ENTER_THE_PATH_TO_THE_ISO_FILE>" # path to the ISO file on the file share eg: \\192.168.1.10\Users\HP\Desktop\script\windows-11-24h2.iso
$localIsoPath = "$env:USERPROFILE\Downloads\windows-11-24h2.iso"
$mountPoint = "$env:USERPROFILE\Downloads\windows-11-Mount"
$installFolder = "C:\Windows11_Install"  
$logFile = "$env:USERPROFILE\Downloads\WindowsUpgrade_Log.txt"
$setupConfigPath = "$installFolder\SetupConfig.ini"

# Function to log messages
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -Append -FilePath $logFile
    Write-Host $message
}

# Function to check Windows version
function Test-Windows10 {
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem
    $osVersion = [System.Environment]::OSVersion.Version
    $osCaption = $osInfo.Caption

    # Check if it's Windows 10
    if ($osCaption -like "*Windows 10*" -and $osVersion.Major -eq 10) {
        return $true
    }
    return $false
}

# My code header hii hapa
Write-Log "Upgrade Engine v1.0.0 || Author: AuxGrep || Email: mranonymoustz@tutanota.com"

# Check if running on Windows 10
if (-not (Test-Windows10)) {
    Write-Log "ERROR: This upgrade script is designed for Windows 10 only. Current OS is not Windows 10. Exiting..."
    exit 1
}

# Additional OS checks
$osInfo = Get-WmiObject -Class Win32_OperatingSystem
$buildNumber = [int]($osInfo.BuildNumber)
$minBuildNumber = 19041  # Minimum Windows 10 build number (2004)

if ($buildNumber -lt $minBuildNumber) {
    Write-Log "ERROR: Your Windows 10 version is too old. Minimum required version is 2004 (build 19041). Please update Windows 10 first. Exiting..."
    exit 1
}

# Check if system is domain-joined
$computerSystem = Get-WmiObject -Class Win32_ComputerSystem
if (-not $computerSystem.PartOfDomain) {
    Write-Log "ERROR: This computer is not domain-joined. The upgrade script is intended for domain computers only. Exiting..."
    exit 1
}

# Check for pending reboots
$pendingReboot = $false
if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { $pendingReboot = $true }
if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { $pendingReboot = $true }
if ($pendingReboot) {
    Write-Log "ERROR: System has pending reboot. Please restart the computer before running the upgrade. Exiting..."
    exit 1
}

# Check disk space
$systemDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
$freeSpaceGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
if ($freeSpaceGB -lt 40) {
    Write-Log "ERROR: Insufficient disk space. At least 40 GB free space required. Current free space: $freeSpaceGB GB. Exiting..."
    exit 1
}

# Upgrade nyingi za Win 11 zinahitaji TPM Compatibility, lets bypass its illegal but no way out.
Write-Log "Checking system requirements..."
$sysInfo = Get-ComputerInfo
$tpmVersion = Get-WmiObject -Namespace "root\CIMV2\Security\MicrosoftTpm" -Class Win32_Tpm | Select-Object -ExpandProperty SpecVersion
if ($sysInfo.CsProcessors.NumberOfCores -lt 2 -or $sysInfo.CsPhyicallyInstalledMemory/1MB -lt 4096 -or [version]$tpmVersion -lt [version]"2.0") {
    Write-Log "WARNING: System may not meet Windows 11 requirements. Proceeding anyway..."
}

# Tunaweka ISO kwenye share file, so lets make sure the file share is accessible
if (!(Test-Path -Path $fileSharePath)) {
    Write-Log "ERROR: File share path $fileSharePath is not accessible. Exiting..."
    exit 1
}
# Copy ISO kwenye fileshare kwenda kwenye Download folder ya user
Write-Log "Copying Windows 11 ISO to local system..."
Copy-Item -Path $fileSharePath -Destination $localIsoPath -Force -ErrorAction Stop
Write-Log "ISO copied successfully."

# Tutamount ISO file ila kabla lets check if the mount point directory exists
if (-not (Test-Path $mountPoint)) {
    New-Item -ItemType Directory -Path $mountPoint -ErrorAction Stop | Out-Null
    Write-Log "Created mount point directory: $mountPoint"
}

# Now lets mount the ISO
try {
    Write-Log "Mounting Windows 11 ISO..."
    $mountResult = Mount-DiskImage -ImagePath $localIsoPath -PassThru -ErrorAction Stop
    Start-Sleep -Seconds 5  

    # Get drive letter of the mounted ISO
    $driveLetter = ($mountResult | Get-Volume).DriveLetter
    if (-not $driveLetter) {
        Write-Log "ERROR: Could not get the drive letter of the mounted ISO. Exiting..."
        Dismount-DiskImage -ImagePath $localIsoPath
        exit 1
    }

    Write-Log "ISO mounted at drive $driveLetter."

    # lET'S Ensure install folder exists
    if (-not (Test-Path $installFolder)) {
        New-Item -ItemType Directory -Path $installFolder -ErrorAction Stop | Out-Null
        Write-Log "Created installation folder: $installFolder"
    }

    # Create SetupConfig.ini for better control
    Write-Log "Creating SetupConfig.ini..."
    @"
[SetupConfig]
Bitlocker=Allow
Priority=Normal
DynamicUpdate=Disable
ShowOOBE=None
Telemetry=Disable
InstallMode=Auto
"@ | Out-File -FilePath $setupConfigPath -Encoding utf8

    # Enhanced copy process with verification
    Write-Log "Copying installation files with verification..."
    $robocopyResult = robocopy "$driveLetter`:\" "$installFolder" /E /Z /W:1 /R:1 /MT:8 /V /NP
    if ($LASTEXITCODE -ge 8) {
        throw "Robocopy failed with exit code $LASTEXITCODE"
    }

    # Verify critical files
    $requiredFiles = @(
        "$installFolder\setup.exe",
        "$installFolder\sources\install.wim",
        "$installFolder\sources\boot.wim"
    )
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            throw "Critical file missing: $file"
        }
    }

    # Create registry keys for compatibility
    Write-Log "Configuring compatibility settings..."
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators",
        "HKLM:\SYSTEM\Setup\MoSetup"
    )
    foreach ($path in $regPaths) {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
    }
    Set-ItemProperty -Path $regPaths[0] -Name "NI22H2" -Value "RedReason=None" -Type String
    Set-ItemProperty -Path $regPaths[1] -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -Type DWord

    # Start Windows 11 upgrade with enhanced parameters
    Write-Log "Starting Windows 11 setup with optimized parameters..."
    $setupArgs = @(
        "/auto upgrade",
        "/quiet",
        "/noreboot",
        "/compat IgnoreWarning",
        "/migratedrivers all",
        "/showoobe none",
        "/telemetry disable",
        "/copylogs $env:USERPROFILE\Downloads\UpgradeLogs",
        "/eula accept"
    )
    
    $setupProcess = Start-Process -FilePath "$installFolder\setup.exe" `
        -ArgumentList ($setupArgs -join " ") `
        -Wait -PassThru -NoNewWindow

    # error handling
    switch ($setupProcess.ExitCode) {
        0 { 
            Write-Log "Windows 11 upgrade preparation completed successfully."
            # Schedule the actual upgrade
            $action = New-ScheduledTaskAction -Execute "$installFolder\setup.exe" -Argument "/auto upgrade /quiet"
            $trigger = New-ScheduledTaskTrigger -AtLogon
            Register-ScheduledTask -TaskName "Windows11Upgrade" -Action $action -Trigger $trigger -RunLevel Highest -Force
            
            # Show notification
            [System.Windows.MessageBox]::Show(
                "Windows 11 upgrade has been prepared successfully. The system will upgrade at next login. Please save all work and restart your computer.",
                "Windows 11 Upgrade Ready",
                "OK",
                "Information"
            )
        }
        default {
            Write-Log "ERROR: Setup failed with exit code $($setupProcess.ExitCode)"
            throw "Setup failed with exit code $($setupProcess.ExitCode)"
        }
    }

} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    # Cleanup on error
    if (Test-Path $installFolder) {
        Remove-Item -Path $installFolder -Recurse -Force
    }
} finally {
    # Cleanup
    Write-Log "Performing cleanup..."
    Dismount-DiskImage -ImagePath $localIsoPath -ErrorAction SilentlyContinue
    Write-Log "Script execution completed."
}
