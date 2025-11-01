<#
================================================================================
browserArtifactCollector.ps1
--------------------------------------------------------------------------------
Purpose : Live forensic helper to collect browser artifacts (Chrome, Edge, Firefox),
          produce a single evidence .zip, compute a SHA256 forensic record with
          metadata, and keep a separate external transcript/log.

Author  : Khalil Z.
Repo    : https://github.com/eyesn1p3r/BrowserArtifactCollector.git
Created : 2025-10-31
Version : 1.0.0

Usage:
    - Edit configuration variables near the top of the script:
        $BasePath   - root path to user profiles (default: C:\Users)
        $OutputRoot - evidence staging directory (default: C:\Forensic_Artifacts)
    - Replace the placeholder "collection" block with your selective Copy-Item
      logic (only copy files you need for analysis).
    - Run PowerShell as Administrator and execute:
        .\browserArtifactCollector.ps1 -Live

Outputs:
    - Browsers_Artifacts_YYYYMMDD_HHMM.zip
    - Browsers_Artifacts_YYYYMMDD_HHMM.zip.sha256.txt  (forensic header + SHA256)
    - collection_log_YYYYMMDD_HHMM.txt               (external transcript, not compressed)

Forensic notes:
    - The transcript is intentionally kept outside the archive to maintain a clear
      audit trail. The script stops the transcript before compressing to free the
      logfile handle and then appends the computed hash to that log.
    - The script deletes the uncompressed artifact folder after successful zip + hash
      to avoid duplication and minimize alteration risk. If you want to keep the raw
      folder for debugging, implement a `-NoCleanup` flag (not provided in v1.0).

Precautions:
    - Live acquisition can change system state; prefer imaging (offline) when possible.
    - For locked DBs (SQLite / LevelDB) prefer VSS snapshot or other dumper tools.
    - Ensure you have legal authorization for live collection.

ChangeLog:
    1.0.0 - 2025-10-31 - Initial release: zip-only archive, SHA256 with forensic header,
                         external transcript, auto-cleanup.

#>


param(
    [switch]$Live,                                # Use live acquisition mode
    [string]$MountedImage = "E:\",                # Mounted image root (e.g., "E:\")
    [string]$Output = "C:\Browsers_Artifacts"     # Default output directory
)

# === INITIALIZATION ============================================================
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmm"
$OutputDir = Join-Path $Output "Browsers_Artifacts_$TimeStamp"
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Define log and summary file paths
$LogFile = Join-Path $OutputDir "collection_log.txt"
$CsvFile = Join-Path $OutputDir "collection_summary.csv"
"Timestamp,Browser,User,ArtifactType,SourcePath,DestinationPath" | Out-File -Encoding UTF8 $CsvFile

# Start PowerShell transcript for detailed logging
Start-Transcript -Path $LogFile -Append | Out-Null

# === MODE SELECTION ============================================================
if ($Live) {
    Write-Host "`n[MODE] Live acquisition selected" -ForegroundColor Yellow
    $UsersRoot = "C:\Users"
}
else {
    Write-Host "`n [MODE] Mounted image acquisition selected from $MountedImage" -ForegroundColor Green
    if ($MountedImage.EndsWith("\")) { $MountedImage = $MountedImage.TrimEnd('\') }
    $UsersRoot = Join-Path $MountedImage "Users"
}
Write-Host "[INFO] Users root: $UsersRoot`n"

# === ARTIFACT DEFINITIONS ======================================================
# Chrome and Edge share the Chromium architecture
$ChromiumFiles = @("History","Cookies","Login Data","Web Data","Bookmarks","Bookmarks.bak","Favicons","Preferences")
$ChromiumDirs  = @("Extensions","Local Storage","IndexedDB","Sessions")

# Firefox has a different structure
$FirefoxFiles  = @("places.sqlite","cookies.sqlite","logins.json","key4.db","formhistory.sqlite","favicons.sqlite","sessionstore.jsonlz4","extensions.json")
$FirefoxDirs   = @("extensions","browser-extension-data","storage\default")

# === FUNCTION: Copy only relevant artifacts ====================================
function Copy-SelectedArtifacts {
    param(
        [string]$Browser,     # Browser name (Chrome / Edge / Firefox)
        [string]$SourcePath,  # Source directory of browser profile
        [string[]]$Files,     # List of artifact files to copy
        [string[]]$Dirs,      # List of artifact directories to copy
        [string]$User         # Username owning the profile
    )

    # Skip if the browser profile path does not exist
    if (!(Test-Path $SourcePath)) { return }

    # Create destination folder: <Output>\<Browser>\<User>\
    $Dest = Join-Path $OutputDir "$Browser\$User"
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null

    Write-Host "[$Browser][$User] Found profile path: $SourcePath" -ForegroundColor Cyan

    # --- Copy relevant files ---
    foreach ($f in $Files) {
        $src = Join-Path $SourcePath $f
        if (Test-Path $src) {
            Write-Host "   Copying file: $f" -ForegroundColor Gray
            Copy-Item -Path $src -Destination $Dest -Force -ErrorAction SilentlyContinue
            $csv = "{0},{1},{2},File,{3},{4}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$Browser,$User,$src,$Dest
            Add-Content $CsvFile $csv
        }
    }

    # --- Copy relevant directories ---
    foreach ($d in $Dirs) {
        $src = Join-Path $SourcePath $d
        if (Test-Path $src) {
            Write-Host "   Copying directory: $d" -ForegroundColor Gray
            $dstDir = Join-Path $Dest $d
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            Copy-Item -Path $src -Destination $dstDir -Recurse -Force -ErrorAction SilentlyContinue
            $csv = "{0},{1},{2},Directory,{3},{4}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$Browser,$User,$src,$dstDir
            Add-Content $CsvFile $csv
        }
    }

    Write-Host "[$Browser][$User] Profile copied successfully.`n" -ForegroundColor Green
}

# === USER LOOP ================================================================
$Users = Get-ChildItem -Path $UsersRoot -Directory -ErrorAction SilentlyContinue
foreach ($User in $Users) {
    $UName = $User.Name
    Write-Host "Processing user: $UName" -ForegroundColor White

    # Expected browser profile locations
    $chrome = Join-Path $User.FullName "AppData\Local\Google\Chrome\User Data\Default"
    $edge   = Join-Path $User.FullName "AppData\Local\Microsoft\Edge\User Data\Default"
    $ffRoot = Join-Path $User.FullName "AppData\Roaming\Mozilla\Firefox\Profiles"

    # Chrome
    if (Test-Path $chrome) {
        Copy-SelectedArtifacts -Browser "Chrome" -SourcePath $chrome -Files $ChromiumFiles -Dirs $ChromiumDirs -User $UName
    }

    # Edge
    if (Test-Path $edge) {
        Copy-SelectedArtifacts -Browser "Edge" -SourcePath $edge -Files $ChromiumFiles -Dirs $ChromiumDirs -User $UName
    }

    # Firefox (may contain multiple profiles)
    if (Test-Path $ffRoot) {
        $Profiles = Get-ChildItem -Path $ffRoot -Directory -ErrorAction SilentlyContinue
        foreach ($P in $Profiles) {
            Write-Host "   Firefox profile detected: $($P.Name)" -ForegroundColor Magenta
            Copy-SelectedArtifacts -Browser "Firefox" -SourcePath $P.FullName -Files $FirefoxFiles -Dirs $FirefoxDirs -User $UName
        }
    }

    Write-Host "-------------------------------------------`n"
}

# === COMPLETION ===============================================================
Write-Host "`n Preparing compression phase..." -ForegroundColor Yellow
Write-Host " Logging compression phase..." -ForegroundColor DarkGray

# Stop transcript to unlock the log file
Stop-Transcript | Out-Null
Write-Host " Transcript stopped. Log file unlocked." -ForegroundColor DarkGray

# Move transcript log outside (will remain as standalone log file)
$FinalLog = Join-Path $Output "collection_log_$TimeStamp.txt"
Move-Item -Path $LogFile -Destination $FinalLog -Force
Write-Host " External log created: $FinalLog" -ForegroundColor Cyan

# === COMPRESSION PHASE ========================================================
$ZipFile = "$OutputDir.zip"
Write-Host " Compressing artifacts into: $ZipFile" -ForegroundColor Yellow
Compress-Archive -Path $OutputDir -DestinationPath $ZipFile -Force
Write-Host " Archive created successfully." -ForegroundColor Green

# === HASH GENERATION ==========================================================
Write-Host " Computing SHA256 hash of the archive..." -ForegroundColor Yellow
$Hash = (Get-FileHash -Path $ZipFile -Algorithm SHA256).Hash
$HashFile = "$ZipFile.sha256.txt"

# Write a detailed header comment inside the hash file
@"
# ==============================================================================
# FORENSIC HASH RECORD
# ------------------------------------------------------------------------------
# File Name : $(Split-Path $ZipFile -Leaf)
# Generated : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# Algorithm : SHA256
# Description: This hash value ensures the integrity and authenticity
#              of the forensic archive generated by browserCollector.ps1.
#              Any modification to the .zip file will change this hash.
# ==============================================================================
"@ | Out-File -FilePath $HashFile -Encoding ASCII -Force

# Append the actual hash value
"SHA256: $Hash" | Add-Content -Path $HashFile

Write-Host "Hash file created with metadata: $HashFile" -ForegroundColor Green
Write-Host "   SHA256: $Hash" -ForegroundColor White


# === CLEANUP: DELETE UNCOMPRESSED FOLDER ======================================
Write-Host "Cleaning up temporary uncompressed folder..." -ForegroundColor Yellow
Remove-Item -Path $OutputDir -Recurse -Force
Write-Host "️Folder removed: $OutputDir" -ForegroundColor DarkGray

# === FINAL SUMMARY ============================================================
Write-Host "`n [DONE] Forensic acquisition complete at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
Write-Host " Archive: $ZipFile" -ForegroundColor White
Write-Host " Hash file: $HashFile" -ForegroundColor White
Write-Host " Log file (external): $FinalLog`n" -ForegroundColor White