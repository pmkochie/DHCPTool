# Define File Paths
$WorkspaceDir  = "C:\Scripts\dhcp\DHCPTool"
$CsvFile       = "$WorkspaceDir\oui_trimmed.csv"
$LogFile       = "$WorkspaceDir\changelog.txt"

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "      DHCP Tool Dynamic EXE Builder     " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Pre-requisite Check: Ensure PS2EXE is installed
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "[*] PS2EXE module not found. Attempting to install from PowerShell Gallery..." -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-Module -Name ps2exe -Force -AllowClobber -Scope CurrentUser
    Write-Host "[*] PS2EXE installed successfully." -ForegroundColor Green
}

# 2. Dynamically Find the Newest Target Script (Ignoring temp builds)
Write-Host "[*] Searching for the latest source script..." -ForegroundColor Yellow
$SourceFile = Get-ChildItem "$WorkspaceDir" -Filter "Set DHCP Reservation*.ps1" | 
              Where-Object { $_.Name -notmatch "_Built" -and $_.Name -notlike "*_Temp.ps1" } | 
              Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $SourceFile) {
    Write-Host "[ERROR] Could not find any 'Set DHCP Reservation*.ps1' files in $WorkspaceDir" -ForegroundColor Red
    return
}

$TemplatePath =$SourceFile.FullName
Write-Host "[*] Found latest script: $($SourceFile.Name)" -ForegroundColor Green

# 3. Extract Version Number via Regex
if ($SourceFile.Name -match 'Set DHCP Reservation(\d+)') {
    $Version =$Matches[1]
    Write-Host "[*] Extracted Version: $Version" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Could not extract version number from filename: $($SourceFile.Name)" -ForegroundColor Red
    return
}

$InjectedScript = Get-Content "$TemplatePath" -Raw

# 4. Inject OUI CSV into Script Memory dynamically
Write-Host "[*] Injecting OUI Database ($CsvFile)..." -ForegroundColor Yellow
if (-not (Test-Path "$CsvFile")) {
    Write-Host "[ERROR] Could not find $CsvFile in$WorkspaceDir. Please ensure it is in the same folder." -ForegroundColor Red
    return
}
$RawCsv = Get-Content "$CsvFile" -Raw
$InjectedScript = $InjectedScript.Replace('# <INSERT_CSV_HERE>', $RawCsv)

# 5. Inject Changelog into Script Memory dynamically
Write-Host "[*] Injecting Changelog ($LogFile)..." -ForegroundColor Yellow
if (Test-Path "$LogFile") {
    $RawLog = Get-Content "$LogFile" -Raw
    $InjectedScript = $InjectedScript.Replace('# <INSERT_CHANGELOG_HERE>', $RawLog)
    Write-Host "[*] Changelog injected successfully." -ForegroundColor Green
} else {
    Write-Host "[!] Could not find $LogFile. About window will load empty." -ForegroundColor Yellow
    $InjectedScript =$InjectedScript.Replace('# <INSERT_CHANGELOG_HERE>', "Changelog file not found during compilation.")
}

# Save temporary injected script
$TempScriptPath = "$WorkspaceDir\Set DHCP Reservation$Version`_Temp.ps1"
Set-Content "$TempScriptPath" -Value $InjectedScript -Encoding UTF8

# Define Dynamic Output Paths
$ExePath = "$WorkspaceDir\DHCP_Tool.$Version.exe"

# 6. Compilation with Metadata
Write-Host "[*] Triggering PS2EXE Compiler..." -ForegroundColor Yellow
try {
    # Format version string to meet strict Windows 4-part requirement
    $FormattedVersion = "$Version.0.0.0"

    Invoke-PS2EXE -InputFile "$TempScriptPath" `
                  -OutputFile "$ExePath" `
                  -NoConsole `
                  -Title "DHCP Management Tool" `
                  -Description "DHCP Reservation & Lease Manager" `
                  -Product "DHCP Tool" `
                  -Company "IT Department" `
                  -Copyright "Created by Paul Kochie" `
                  -Version $FormattedVersion | Out-Null

    Write-Host "[*] EXE compiled successfully." -ForegroundColor Green
    
    # 7. Digital Signature / Authenticode Engine
    Write-Host "[*] Checking for Code Signing Certificate..." -ForegroundColor Yellow
    
    # Look for a specific publisher cert first, or fallback to any available code signing cert
    $Cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue | Where-Object { $_.Subject -match "DHCP Tool Publisher" } | Select-Object -First 1
    if (-not $Cert) {
        $Cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if (-not $Cert) {
        Write-Host "    [!] No Code Signing certificate found. Generating a self-signed certificate..." -ForegroundColor Yellow
        $Cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=DHCP Tool Publisher" -CertStoreLocation Cert:\CurrentUser\My -ErrorAction Stop
    }

    Write-Host "    [*] Applying Digital Signature using: $($Cert.Subject)" -ForegroundColor Yellow
    
    $SignResult = Set-AuthenticodeSignature -FilePath "$ExePath" -Certificate $Cert -TimestampServer "http://timestamp.digicert.com" -ErrorAction SilentlyContinue
    
    if ($SignResult.Status -eq "Valid") {
        Write-Host "    [*] Executable successfully signed and timestamped!" -ForegroundColor Green
    } else {
        Write-Host "    [!] Signature applied, but returned status: $($SignResult.Status). Sophos may still flag it." -ForegroundColor DarkYellow
    }

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "SUCCESS! Tool is ready for deployment." -ForegroundColor Green
    Write-Host "Output: $ExePath" -ForegroundColor Green
    Write-Host "File Version: $FormattedVersion" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green

} catch {
    Write-Host "[ERROR] Process Failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Clean up the massive temporary file after building
    if ($TempScriptPath -ne $TemplatePath -and (Test-Path "$TempScriptPath")) {
        Remove-Item "$TempScriptPath" -Force
    }
}