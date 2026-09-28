<#
.SYNOPSIS
    DHCP Reservation & Lease Manager (v176 - Foolproof Syntax & Native Functions).
.DESCRIPTION
    Creates DHCP reservations and views full lease/reservation tables across target DHCP servers.
    V176: Refactored all helper scriptblocks to native functions to eliminate pipeline '&' closure crashes. Wrapped all loop collections and parameters in parentheses to physically prevent clipboard space-stripping errors.
#>

param([switch]$Authenticated)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Data

$appFont = New-Object System.Drawing.Font("Segoe UI", 16)
$boxFont = New-Object System.Drawing.Font("Segoe UI", 20) 
$btnFont = New-Object System.Drawing.Font("Segoe UI", 16) 
$gridFont = New-Object System.Drawing.Font("Segoe UI", 12) 

if (-not $Authenticated) {
    $loginForm = New-Object System.Windows.Forms.Form
    $loginForm.Text = "DHCP Tool (v176) — AD Admin Login"
    $loginForm.Size = New-Object System.Drawing.Size(640, 320)
    $loginForm.StartPosition = "CenterScreen"
    $loginForm.FormBorderStyle = "FixedDialog"
    $loginForm.MaximizeBox = $false
    $loginForm.MinimizeBox = $false
    $loginForm.Font = New-Object System.Drawing.Font("Segoe UI", 13)
    $loginForm.TopMost = $true

    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Text = "AD Admin Username:"
    $lblUser.Location = New-Object System.Drawing.Point(25, 45)
    $lblUser.Size = New-Object System.Drawing.Size(210, 35)
    $loginForm.Controls.Add($lblUser)

    $txtUser = New-Object System.Windows.Forms.TextBox
    $txtUser.Font = New-Object System.Drawing.Font("Segoe UI", 16)
    $txtUser.Location = New-Object System.Drawing.Point(245, 38)
    $txtUser.Size = New-Object System.Drawing.Size(345, 38)
    $loginForm.Controls.Add($txtUser)

    $lblPass = New-Object System.Windows.Forms.Label
    $lblPass.Text = "Account Password:"
    $lblPass.Location = New-Object System.Drawing.Point(25, 115)
    $lblPass.Size = New-Object System.Drawing.Size(210, 35)
    $loginForm.Controls.Add($lblPass)

    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Font = New-Object System.Drawing.Font("Segoe UI", 16)
    $txtPass.Location = New-Object System.Drawing.Point(245, 108)
    $txtPass.Size = New-Object System.Drawing.Size(345, 38)
    $txtPass.UseSystemPasswordChar = $true
    $loginForm.Controls.Add($txtPass)

    $btnLogin = New-Object System.Windows.Forms.Button
    $btnLogin.Text = "Login"
    $btnLogin.Font = $btnFont
    $btnLogin.Size = New-Object System.Drawing.Size(120, 42)
    $btnLogin.Location = New-Object System.Drawing.Point(335, 195)
    $btnLogin.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $loginForm.Controls.Add($btnLogin)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Font = $btnFont
    $btnCancel.Size = New-Object System.Drawing.Size(120, 42)
    $btnCancel.Location = New-Object System.Drawing.Point(470, 195)
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $loginForm.Controls.Add($btnCancel)

    $loginForm.AcceptButton = $btnLogin
    $loginForm.CancelButton = $btnCancel

    $loginLoop = $true
    while ($loginLoop) {
        $loginResult = $loginForm.ShowDialog()
        
        if ($loginResult -eq [System.Windows.Forms.DialogResult]::OK -and -not [string]::IsNullOrWhiteSpace($txtUser.Text)) {
            $inputUser = $txtUser.Text.Trim()
            $finalUPN = ""

            if ($inputUser -match '^([^\\]+)\\(.+)$') {
                $finalUPN = "$($Matches[2])@$($Matches[1])"
            } elseif ($inputUser -match '@') {
                $finalUPN = $inputUser
            } else {
                $localDomain = $env:USERDNSDOMAIN
                if ([string]::IsNullOrWhiteSpace($localDomain)) {
                    $localDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
                }
                $finalUPN = "$inputUser@$localDomain"
            }

            $rawPassword = $txtPass.Text
            $secPass = New-Object System.Security.SecureString
            foreach ($char in ($rawPassword.ToCharArray())) { $secPass.AppendChar($char) }

            $appDir = Join-Path $env:PUBLIC "DHCPTool"
            if (-not (Test-Path $appDir)) {
                $null = New-Item -ItemType Directory -Path $appDir -Force
            }

            Import-Module DhcpServer -ErrorAction SilentlyContinue
            while (-not (Get-Command Get-DhcpServerv4Scope -ErrorAction SilentlyContinue)) {
                
                $rsatForm = New-Object System.Windows.Forms.Form
                $rsatForm.Text = "RSAT DHCP Component Required"
                $rsatForm.Size = New-Object System.Drawing.Size(750, 400)
                $rsatForm.StartPosition = "CenterScreen"
                $rsatForm.FormBorderStyle = "FixedDialog"
                $rsatForm.MaximizeBox = $false
                $rsatForm.MinimizeBox = $false
                $rsatForm.TopMost = $true

                $lblMsg = New-Object System.Windows.Forms.Label
                $lblMsg.Text = "The RSAT DHCP Management Tools are required on this workstation.`n`nClick the button below to securely download and install them directly from Microsoft."
                $lblMsg.Font = New-Object System.Drawing.Font("Segoe UI", 12)
                $lblMsg.Location = New-Object System.Drawing.Point(30, 30)
                $lblMsg.Size = New-Object System.Drawing.Size(670, 160)
                $rsatForm.Controls.Add($lblMsg)

                $btnLaunch = New-Object System.Windows.Forms.Button
                $btnLaunch.Text = "Install RSAT DHCP Tools"
                $btnLaunch.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
                $btnLaunch.Location = New-Object System.Drawing.Point(30, 200)
                $btnLaunch.Size = New-Object System.Drawing.Size(340, 50)
                $rsatForm.Controls.Add($btnLaunch)

                $btnExit = New-Object System.Windows.Forms.Button
                $btnExit.Text = "Exit Application"
                $btnExit.Font = New-Object System.Drawing.Font("Segoe UI", 11)
                $btnExit.Location = New-Object System.Drawing.Point(400, 205)
                $btnExit.Size = New-Object System.Drawing.Size(160, 42)
                $btnExit.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
                $rsatForm.Controls.Add($btnExit)

                $btnLaunch.Add_Click({
                    $btnLaunch.Enabled = $false
                    $btnLaunch.Text = "Installing... Please wait"
                    
                    $startTimeStr = (Get-Date).ToString("hh:mm tt")

                    $lblMsg.Text = "Working... Please monitor the blue terminal window.`n`nInstallation started at: $startTimeStr`n`nThe terminal window shows live progress (downloading, installing, etc.) and an elapsed timer, so you can tell it's still working even if the percentage pauses for a bit.`n`nDO NOT CLOSE THE BLUE TERMINAL."
                    $lblMsg.ForeColor = [System.Drawing.Color]::MediumBlue
                    $rsatForm.Refresh()

                    try {
                        $inMemoryScript = @'
$host.UI.RawUI.WindowTitle = "RSAT DISM Installer - DO NOT CLOSE"
$host.UI.RawUI.BackgroundColor = "DarkBlue"
Clear-Host

$startTime = Get-Date
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "          RSAT DHCP Component Installer                 " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Install Task Started: $($startTime.ToString('hh:mm tt'))" -ForegroundColor Green
Write-Host ""

$dismArgs = "/Online /Add-Capability /CapabilityName:Rsat.DHCP.Tools~~~~0.0.1.0"

Write-Host "Applying WSUS Bypasses to force direct Microsoft connection..." -ForegroundColor Yellow
$auPath  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$wuPath  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$svcPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing"

if (-not (Test-Path $auPath))  { $null = New-Item -Path $auPath -Force -ErrorAction SilentlyContinue }
if (-not (Test-Path $wuPath))  { $null = New-Item -Path $wuPath -Force -ErrorAction SilentlyContinue }
if (-not (Test-Path $svcPath)) { $null = New-Item -Path $svcPath -Force -ErrorAction SilentlyContinue }

Set-ItemProperty -Path $auPath  -Name "UseWUServer" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $wuPath  -Name "DoNotConnectToWindowsUpdateInternetLocations" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $svcPath -Name "RepairContentServerSource" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $svcPath -Name "LimitAccess" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

& netsh.exe winhttp import proxy source=ie >$null 2>&1

Get-Process -Name wuauserv,BITS -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Service wuauserv,BITS -ErrorAction SilentlyContinue

Write-Host "Fetching directly from Windows Update. Please wait..." -ForegroundColor Green
Write-Host ""

function Get-PhaseLabel([double]$pct) {
    if     ($pct -lt 5)  { "Preparing installation..." }
    elseif ($pct -lt 85) { "Downloading component files..." }
    elseif ($pct -lt 99) { "Installing component..." }
    else                 { "Finalizing..." }
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = "dism.exe"
$psi.Arguments              = $dismArgs
$psi.RedirectStandardOutput = $true
$psi.UseShellExecute        = $false
$psi.CreateNoWindow         = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$null = $proc.Start()

$reader = $proc.StandardOutput
$lineBuf = New-Object System.Text.StringBuilder
$lastRenderedLen = 0

while (-not $reader.EndOfStream) {
    $chInt = $reader.Read()
    if ($chInt -lt 0) { break }
    $ch = [char]$chInt
    if ($ch -eq "`r" -or $ch -eq "`n") {
        $line = $lineBuf.ToString()
        $null = $lineBuf.Clear()
        if ($line -match '(\d+(?:\.\d+)?)\s*%') {
            $pct     = [double]$Matches[1]
            $phase   = Get-PhaseLabel $pct
            $elapsed = "{0:mm\:ss}" -f $stopwatch.Elapsed
            $status  = "$phase $pct% (elapsed $elapsed)"
            $host.UI.RawUI.WindowTitle = "RSAT DISM Installer - $status"
            Write-Host ("`r" + $status.PadRight($lastRenderedLen)) -NoNewline -ForegroundColor White
            $lastRenderedLen = $status.Length
        } elseif ($line.Trim()) {
            Write-Host ""
            Write-Host "  $line" -ForegroundColor DarkGray
            $lastRenderedLen = 0
        }
    } else {
        $null = $lineBuf.Append($ch)
    }
}
$proc.WaitForExit()
$stopwatch.Stop()
Write-Host ""

$finalElapsed = "{0:mm\:ss}" -f $stopwatch.Elapsed
if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
    $host.UI.RawUI.WindowTitle = "RSAT DISM Installer - Completed in $finalElapsed"
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host "RSAT Installation Finished Successfully! ($finalElapsed)" -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Green
} else {
    $host.UI.RawUI.WindowTitle = "RSAT DISM Installer - FAILED after $finalElapsed"
    Write-Host "========================================================" -ForegroundColor Red
    Write-Host "DISM returned an error code: $($proc.ExitCode) after $finalElapsed" -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Red
}

Write-Host ""
Write-Host "Closing terminal and resuming application in 5 seconds..." -ForegroundColor Gray
Start-Sleep -Seconds 5
'@
                        $bytes = [System.Text.Encoding]::Unicode.GetBytes($inMemoryScript)
                        $encodedCommand = [Convert]::ToBase64String($bytes)

                        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand" -Verb RunAs -PassThru
                        $proc.WaitForExit()

                        $rsatForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
                        $rsatForm.Close()
                    } catch {
                        [System.Windows.Forms.MessageBox]::Show("Failed to trigger elevated terminal:`n`n$($_.Exception.Message)", "Elevation Error")
                        $btnLaunch.Enabled = $true
                        $btnLaunch.Text = "Install RSAT DHCP Tools"
                    }
                })
                
                $guideResult = $rsatForm.ShowDialog()
                $rsatForm.Dispose()

                if ($guideResult -ne [System.Windows.Forms.DialogResult]::OK) {
                    $loginForm.Dispose()
                    Exit
                }

                $env:PSModulePath = [Environment]::GetEnvironmentVariable("PSModulePath","Machine") + ";" + [Environment]::GetEnvironmentVariable("PSModulePath","User")
                Get-Module -ListAvailable -Refresh | Out-Null
                Import-Module DhcpServer -Force -ErrorAction SilentlyContinue

                if (-not (Get-Command Get-DhcpServerv4Scope -ErrorAction SilentlyContinue)) {
                    $null = [System.Windows.Forms.MessageBox]::Show(
                        "RSAT DHCP Management Tools are still not detected on this system.`n`nPlease ensure the DISM command completed successfully in the terminal window before attempting again.",
                        "Verification Failed",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    )
                }
            }

            $currentModule = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.UserName = $finalUPN
            $processInfo.Domain   = "" 
            $processInfo.Password = $secPass
            $processInfo.UseShellExecute = $false
            $processInfo.WorkingDirectory = $appDir

            if ($currentModule -match "powershell") {
                $scriptPath = $MyInvocation.MyCommand.Path
                $processInfo.FileName = "powershell.exe"
                $processInfo.Arguments = "-NoProfile -WindowStyle Hidden -File `"$scriptPath`" -Authenticated"
            } else {
                $stagedExe = Join-Path $appDir "DHCP_Tool.exe"
                try {
                    if ($currentModule -ne $stagedExe -and (Test-Path $currentModule)) {
                        Copy-Item -Path $currentModule -Destination $stagedExe -Force
                    }
                } catch {
                    $null = [System.Windows.Forms.MessageBox]::Show("Failed to update staged executable. Please close any background instances of the DHCP Tool.`n`n$($_.Exception.Message)", "File Lock Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    $loginLoop = $false
                    $loginForm.Dispose()
                    Exit
                }
                $processInfo.FileName = $stagedExe
                $processInfo.Arguments = "-Authenticated"
            }

            try {
                $null = [System.Diagnostics.Process]::Start($processInfo)
                $loginLoop = $false
                $loginForm.Dispose()
                Exit 
            } catch {
                $null = [System.Windows.Forms.MessageBox]::Show("User authentication failed. Please check your password and try again.", "Authentication Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                $txtPass.Clear()
                [void]$txtPass.Focus()
            }
        } else {
            $loginLoop = $false
            $loginForm.Dispose()
            Exit 
        }
    }
}

Import-Module DhcpServer -ErrorAction SilentlyContinue

# -------------------------------------------------------------
# Native Helper Functions
# -------------------------------------------------------------
function Launch-Browser {
    param([string]$url)
    $browsers = @("chrome.exe", "msedge.exe", "firefox.exe", "iexplore.exe")
    $success = $false
    foreach ($b in ($browsers)) {
        try {
            $null = Start-Process $b -ArgumentList ($url) -ErrorAction Stop
            $success = $true
            break
        } catch {}
    }
    if (-not $success) {
        try { 
            $null = Start-Process $url -ErrorAction Stop 
        } catch { 
            [System.Windows.Forms.MessageBox]::Show("Could not automatically detect a browser.`n`nPlease manually navigate to: $url", "Browser Error", 0, 16) 
        }
    }
}

function Get-MacVendor {
    param([string]$mac)
    if ([string]::IsNullOrWhiteSpace($mac) -or $mac -eq "—") { return "—" }
    
    $cleanMac = $mac -replace '[^a-fA-F0-9]', ''
    if ($cleanMac.Length -eq 14) { $cleanMac = $cleanMac.Substring(2) }
    
    if ($cleanMac.Length -ge 9) {
        $ouiPrefix9 = $cleanMac.Substring(0,9).ToUpper()
        if ($script:OUICache.ContainsKey($ouiPrefix9)) { return $script:OUICache[$ouiPrefix9] }
    }
    if ($cleanMac.Length -ge 7) {
        $ouiPrefix7 = $cleanMac.Substring(0,7).ToUpper()
        if ($script:OUICache.ContainsKey($ouiPrefix7)) { return $script:OUICache[$ouiPrefix7] }
    }
    if ($cleanMac.Length -ge 6) {
        $ouiPrefix6 = $cleanMac.Substring(0,6).ToUpper()
        if ($script:OUICache.ContainsKey($ouiPrefix6)) { return $script:OUICache[$ouiPrefix6] }
    }
    return "Unknown"
}

function Format-MacAddress {
    param([string]$mac)
    if ([string]::IsNullOrWhiteSpace($mac) -or $mac -eq "—") { return $mac }
    $clean = $mac -replace '[^a-fA-F0-9]', ''
    if ($clean.Length -ne 12) { return $mac } 
    $clean = $clean.ToUpper()
    
    switch ($script:MacFormat) {
        "AA-BB-CC-DD-EE-FF" { return ($clean -replace '(..)(?!$)', '$1-') }
        "AA BB CC DD EE FF" { return ($clean -replace '(..)(?!$)', '$1 ') }
        "AABBCC-DDEEFF" { return $clean.Substring(0,6) + "-" + $clean.Substring(6,6) }
        "AABBCC:DDEEFF" { return $clean.Substring(0,6) + ":" + $clean.Substring(6,6) }
        "AABBCCDDEEFF" { return $clean }
        "AABB.CCDD.EEFF" { return $clean.Substring(0,4) + "." + $clean.Substring(4,4) + "." + $clean.Substring(8,4) }
        "AA:BB:CC:DD:EE:FF" { return ($clean -replace '(..)(?!$)', '$1:') }
        default { return ($clean -replace '(..)(?!$)', '$1:') }
    }
}

function Get-CidrNotation {
    param($maskStr)
    try {
        $bytes = [System.Net.IPAddress]::Parse($maskStr).GetAddressBytes()
        $bitLength = 0
        foreach ($b in ($bytes)) {
            $bitLength += [System.Convert]::ToString($b, 2).Replace('0', '').Length
        }
        return "/$bitLength"
    } catch { return "" }
}

# -------------------------------------------------------------
# STEP 2: Embedded MAC OUI Local Cache Initialization
# -------------------------------------------------------------
$script:OUICache = New-Object System.Collections.Hashtable

# EMBEDDED OUI DATA - Dynamically Injected by Build Script
$embeddedCSV = @"
# <INSERT_CSV_HERE>
"@

function Initialize-OUICache {
    try {
        $csv = $embeddedCSV | ConvertFrom-Csv -ErrorAction SilentlyContinue
        foreach ($row in ($csv)) {
            if ($row.Assignment) {
                $script:OUICache[$row.Assignment.Trim().ToUpper()] = $row.("Organization Name")
            }
        }
    } catch {}
}
Initialize-OUICache

# -------------------------------------------------------------
# STEP 3: Dynamic AD Discovery & File-Based Settings Engine
# -------------------------------------------------------------
[System.Collections.ArrayList]$script:DhcpServers = New-Object System.Collections.ArrayList
[string]$script:SavedColumnOrder = ""
[string]$script:MacFormat = "AA:BB:CC:DD:EE:FF"
$script:CancelLoad = $false
$script:IsFirstRun = $false

$SettingsFile = Join-Path $env:PUBLIC "DHCPTool\settings.conf"

function Load-Settings {
    if (Test-Path $SettingsFile) {
        $lines = Get-Content -Path $SettingsFile -ErrorAction SilentlyContinue
        foreach ($line in ($lines)) {
            if ($line -match "^Servers=(.*)") {
                $script:DhcpServers.Clear()
                foreach ($s in ($Matches[1] -split ",")) {
                    if (-not [string]::IsNullOrWhiteSpace($s)) { $null = $script:DhcpServers.Add($s) }
                }
            }
            if ($line -match "^Columns=(.*)") {
                $script:SavedColumnOrder = $Matches[1]
            }
            if ($line -match "^MacFormat=(.*)") {
                $script:MacFormat = $Matches[1]
            }
        }
        if ($script:DhcpServers.Count -gt 0) { return $true }
    }
    return $false
}

function Save-Settings {
    $parent = Split-Path $SettingsFile
    if (-not (Test-Path $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
    $out = @()
    $out += "Servers=" + ($script:DhcpServers -join ",")
    if (-not [string]::IsNullOrWhiteSpace($script:SavedColumnOrder)) {
        $out += "Columns=" + $script:SavedColumnOrder
    }
    $out += "MacFormat=" + $script:MacFormat
    Set-Content -Path $SettingsFile -Value $out -Force
}

function Restore-Defaults {
    if (Test-Path $SettingsFile) { Remove-Item -Path $SettingsFile -Force -ErrorAction SilentlyContinue }
    $script:SavedColumnOrder = ""
    $script:MacFormat = "AA:BB:CC:DD:EE:FF"
    $script:DhcpServers.Clear()
}

if (-not (Load-Settings)) {
    $script:IsFirstRun = $true
}

function Enable-GridCopy {
    param($grid)
    $grid.ClipboardCopyMode = [System.Windows.Forms.DataGridViewClipboardCopyMode]::EnableWithoutHeaderText
    $grid.MultiSelect = $true
    $grid.AllowUserToOrderColumns = $true

    $ctxMenu = New-Object System.Windows.Forms.ContextMenuStrip

    $miCopyCell = New-Object System.Windows.Forms.ToolStripMenuItem "Copy Cell"
    $miCopyCell.Add_Click({
        if ($grid.CurrentCell -and $grid.CurrentCell.Value) {
            [System.Windows.Forms.Clipboard]::SetText($grid.CurrentCell.Value.ToString())
        }
    }.GetNewClosure())
    $null = $ctxMenu.Items.Add($miCopyCell)

    $miCopyRow = New-Object System.Windows.Forms.ToolStripMenuItem "Copy Row"
    $miCopyRow.Add_Click({
        if ($grid.CurrentRow) {
            $vals = @()
            foreach ($cell in ($grid.CurrentRow.Cells)) { $vals += ($(if ($cell.Value) { $cell.Value.ToString() } else { "" })) }
            [System.Windows.Forms.Clipboard]::SetText(($vals -join "`t"))
        }
    }.GetNewClosure())
    $null = $ctxMenu.Items.Add($miCopyRow)

    $miCopyAll = New-Object System.Windows.Forms.ToolStripMenuItem "Copy All (with headers)"
    $miCopyAll.Add_Click({
        $lines = New-Object System.Collections.Generic.List[string]
        $headers = @()
        foreach ($col in ($grid.Columns)) { if ($col.Visible) { $headers += $col.HeaderText } }
        $lines.Add(($headers -join "`t"))
        foreach ($row in ($grid.Rows)) {
            if ($row.IsNewRow) { continue }
            $vals = @()
            foreach ($cell in ($row.Cells)) { if ($cell.OwningColumn.Visible) { $vals += ($(if ($cell.Value) { $cell.Value.ToString() } else { "" })) } }
            $lines.Add(($vals -join "`r`n"))
        }
        [System.Windows.Forms.Clipboard]::SetText(($lines -join "`r`n"))
    }.GetNewClosure())
    $null = $ctxMenu.Items.Add($miCopyAll)

    $grid.ContextMenuStrip = $ctxMenu

    $grid.Add_CellMouseDown({
        param($s, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right -and $e.RowIndex -ge 0) {
            $s.CurrentCell = $s.Rows[$e.RowIndex].Cells[$e.ColumnIndex]
        }
    })

    $grid.Add_ColumnDividerDoubleClick({
        param($s, $e)
        if ($s.Rows.Count -gt 0) {
            if ($s.AutoSizeColumnsMode -ne [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::None) {
                $s.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::None
            }
            $totalCells = $s.Rows.Count * $s.Columns.Count
            $selectedCells = $s.GetCellCount([System.Windows.Forms.DataGridViewElementStates]::Selected)
            if ($selectedCells -eq $totalCells -or ($s.SelectedRows.Count -gt 0 -and $s.SelectedRows.Count -eq $s.Rows.Count)) {
                $s.AutoResizeColumns([System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::DisplayedCells)
            } else {
                $s.AutoResizeColumn($e.ColumnIndex, [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::DisplayedCells)
            }
            $e.Handled = $true
        }
    }.GetNewClosure())

    $grid.Add_RowDividerDoubleClick({
        param($s, $e)
        if ($s.Rows.Count -gt 0) {
            if ($s.AutoSizeRowsMode -ne [System.Windows.Forms.DataGridViewAutoSizeRowsMode]::None) {
                $s.AutoSizeRowsMode = [System.Windows.Forms.DataGridViewAutoSizeRowsMode]::None
            }
            $s.AutoResizeRow($e.RowIndex, [System.Windows.Forms.DataGridViewAutoSizeRowMode]::AllCells)
            $e.Handled = $true
        }
    }.GetNewClosure())
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "DHCP Tool - New Reservation (v176)"
$form.Size = New-Object System.Drawing.Size(800, 460) 
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.Font = $appFont
$form.TopMost = $true 

$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Text = "Provide information for a reserved client."
$lblInfo.Location = New-Object System.Drawing.Point(20, 20)
$lblInfo.Size = New-Object System.Drawing.Size(580, 30)
$form.Controls.Add($lblInfo)

$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = "≡"
$btnSettings.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$btnSettings.Location = New-Object System.Drawing.Point(740, 15)
$btnSettings.Size = New-Object System.Drawing.Size(40, 40)
$btnSettings.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSettings.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnSettings)

$ttSettings = New-Object System.Windows.Forms.ToolTip
$ttSettings.SetToolTip($btnSettings, "Settings")

$lblName = New-Object System.Windows.Forms.Label
$lblName.Text = "Reservation name:"
$lblName.Location = New-Object System.Drawing.Point(20, 75) 
$lblName.Size = New-Object System.Drawing.Size(230, 30)
$form.Controls.Add($lblName)

$txtName = New-Object System.Windows.Forms.TextBox
$txtName.Font = $boxFont 
$txtName.Location = New-Object System.Drawing.Point(260, 70) 
$txtName.Size = New-Object System.Drawing.Size(510, 35) 
$form.Controls.Add($txtName)

$lblIP = New-Object System.Windows.Forms.Label
$lblIP.Text = "IP address:"
$lblIP.Location = New-Object System.Drawing.Point(20, 130)
$lblIP.Size = New-Object System.Drawing.Size(230, 30)
$form.Controls.Add($lblIP)

$txtIP = New-Object System.Windows.Forms.TextBox
$txtIP.Font = $boxFont
$txtIP.Location = New-Object System.Drawing.Point(260, 125)
$txtIP.Size = New-Object System.Drawing.Size(510, 35) 
$form.Controls.Add($txtIP)

$lblMAC = New-Object System.Windows.Forms.Label
$lblMAC.Text = "MAC address:"
$lblMAC.Location = New-Object System.Drawing.Point(20, 185)
$lblMAC.Size = New-Object System.Drawing.Size(230, 30)
$form.Controls.Add($lblMAC)

$txtMAC = New-Object System.Windows.Forms.TextBox
$txtMAC.Font = $boxFont
$txtMAC.Location = New-Object System.Drawing.Point(260, 180)
$txtMAC.Size = New-Object System.Drawing.Size(510, 35) 
$form.Controls.Add($txtMAC)

$lblMacVendorDisplay = New-Object System.Windows.Forms.Label
$lblMacVendorDisplay.Location = New-Object System.Drawing.Point(260, 222)
$lblMacVendorDisplay.Size = New-Object System.Drawing.Size(510, 20)
$lblMacVendorDisplay.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblMacVendorDisplay.ForeColor = [System.Drawing.Color]::DimGray
$lblMacVendorDisplay.Text = ""
$form.Controls.Add($lblMacVendorDisplay)

$txtMAC.Add_TextChanged({
    $mac = $txtMAC.Text
    if ([string]::IsNullOrWhiteSpace($mac)) {
        $lblMacVendorDisplay.Text = ""
    } else {
        $clean = $mac -replace '[^a-fA-F0-9]', ''
        if ($clean.Length -ge 6) {
            $vendor = Get-MacVendor -mac $clean
            if ($vendor -eq "Unknown") {
                $lblMacVendorDisplay.Text = "Manufacturer: Unknown"
            } elseif ($vendor -match "^Download") {
                $lblMacVendorDisplay.Text = $vendor
            } else {
                $lblMacVendorDisplay.Text = "Manufacturer: $vendor"
            }
        } else {
            $lblMacVendorDisplay.Text = ""
        }
    }
})

$txtMAC.Add_Leave({ $txtMAC.Text = Format-MacAddress -mac $txtMAC.Text })

$lblDesc = New-Object System.Windows.Forms.Label
$lblDesc.Text = "Description:"
$lblDesc.Location = New-Object System.Drawing.Point(20, 255)
$lblDesc.Size = New-Object System.Drawing.Size(230, 30)
$form.Controls.Add($lblDesc)

$txtDesc = New-Object System.Windows.Forms.TextBox
$txtDesc.Font = $boxFont
$txtDesc.Location = New-Object System.Drawing.Point(260, 250)
$txtDesc.Size = New-Object System.Drawing.Size(510, 35) 
$form.Controls.Add($txtDesc)

$btnGlobalSearch = New-Object System.Windows.Forms.Button
$btnGlobalSearch.Text = "Global Search"
$btnGlobalSearch.Font = $btnFont
$btnGlobalSearch.Location = New-Object System.Drawing.Point(20, 335) 
$btnGlobalSearch.Size = New-Object System.Drawing.Size(150, 40)
$form.Controls.Add($btnGlobalSearch)

$btnViewScope = New-Object System.Windows.Forms.Button
$btnViewScope.Text = "View Scope"
$btnViewScope.Font = $btnFont
$btnViewScope.Location = New-Object System.Drawing.Point(180, 335) 
$btnViewScope.Size = New-Object System.Drawing.Size(140, 40)
$form.Controls.Add($btnViewScope)

$btnImportCsv = New-Object System.Windows.Forms.Button
$btnImportCsv.Text = "Import CSV"
$btnImportCsv.Font = $btnFont
$btnImportCsv.Location = New-Object System.Drawing.Point(330, 335) 
$btnImportCsv.Size = New-Object System.Drawing.Size(140, 40)
$form.Controls.Add($btnImportCsv)

$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Text = "Add"
$btnAdd.Font = $btnFont
$btnAdd.Location = New-Object System.Drawing.Point(480, 335) 
$btnAdd.Size = New-Object System.Drawing.Size(130, 40)
$form.Controls.Add($btnAdd)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Font = $btnFont
$btnClose.Location = New-Object System.Drawing.Point(620, 335)
$btnClose.Size = New-Object System.Drawing.Size(150, 40)
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

$btnImportCsv.Add_Click({
    $btnImportCsv.Enabled = $false
    try {
        $importForm = New-Object System.Windows.Forms.Form
        $importForm.Text = "Bulk Import Reservations"
        $importForm.Size = New-Object System.Drawing.Size(700, 500)
        $importForm.StartPosition = "CenterParent"
        $importForm.FormBorderStyle = "FixedDialog"
        $importForm.MaximizeBox = $false
        $importForm.MinimizeBox = $false
        $importForm.Font = New-Object System.Drawing.Font("Segoe UI", 12)

        $lblImportInfo = New-Object System.Windows.Forms.Label
        $lblImportInfo.Text = "Import multiple reservations from a CSV file. The CSV must contain the columns:`nName, IPAddress, MACAddress, Description"
        $lblImportInfo.Location = New-Object System.Drawing.Point(20, 20)
        $lblImportInfo.Size = New-Object System.Drawing.Size(640, 50)
        $importForm.Controls.Add($lblImportInfo)

        $btnDownloadTpl = New-Object System.Windows.Forms.Button
        $btnDownloadTpl.Text = "Download Template"
        $btnDownloadTpl.Location = New-Object System.Drawing.Point(20, 80)
        $btnDownloadTpl.Size = New-Object System.Drawing.Size(200, 40)
        $importForm.Controls.Add($btnDownloadTpl)

        $btnSelectCsv = New-Object System.Windows.Forms.Button
        $btnSelectCsv.Text = "Select && Import CSV"
        $btnSelectCsv.Location = New-Object System.Drawing.Point(230, 80)
        $btnSelectCsv.Size = New-Object System.Drawing.Size(200, 40)
        $importForm.Controls.Add($btnSelectCsv)

        $chkOverwrite = New-Object System.Windows.Forms.CheckBox
        $chkOverwrite.Text = "Force overwrite existing conflicting leases/reservations"
        $chkOverwrite.Location = New-Object System.Drawing.Point(20, 130)
        $chkOverwrite.Size = New-Object System.Drawing.Size(640, 30)
        $importForm.Controls.Add($chkOverwrite)

        $txtImportLog = New-Object System.Windows.Forms.TextBox
        $txtImportLog.Multiline = $true
        $txtImportLog.ScrollBars = "Vertical"
        $txtImportLog.ReadOnly = $true
        $txtImportLog.Font = New-Object System.Drawing.Font("Consolas", 10)
        $txtImportLog.Location = New-Object System.Drawing.Point(20, 170)
        $txtImportLog.Size = New-Object System.Drawing.Size(640, 230)
        $importForm.Controls.Add($txtImportLog)

        $btnCloseImport = New-Object System.Windows.Forms.Button
        $btnCloseImport.Text = "Close"
        $btnCloseImport.Location = New-Object System.Drawing.Point(540, 410)
        $btnCloseImport.Size = New-Object System.Drawing.Size(120, 40)
        $btnCloseImport.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $importForm.Controls.Add($btnCloseImport)

        $importForm.CancelButton = $btnCloseImport

        $btnDownloadTpl.Add_Click({
            $sfd = New-Object System.Windows.Forms.SaveFileDialog
            $sfd.Filter = "CSV File (*.csv)|*.csv"
            $sfd.FileName = "DHCP_Reservation_Template.csv"
            $importForm.TopMost = $false
            if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $templateData = "Name,IPAddress,MACAddress,Description`nPrinter-01,10.20.30.40,AA:BB:CC:DD:EE:FF,Front Office Printer"
                Set-Content -Path ($sfd.FileName) -Value $templateData -Encoding UTF8
                [System.Windows.Forms.MessageBox]::Show("Template saved successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
            $importForm.TopMost = $true
        })

        $btnSelectCsv.Add_Click({
            if ($script:DhcpServers.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("No target database nodes are currently available. Please check Settings.", "Process Blocked", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            $ofd = New-Object System.Windows.Forms.OpenFileDialog
            $ofd.Filter = "CSV File (*.csv)|*.csv"
            $importForm.TopMost = $false
            if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { $importForm.TopMost = $true; return }
            $importForm.TopMost = $true

            $csvData = Import-Csv -Path ($ofd.FileName) -ErrorAction SilentlyContinue
            if (-not $csvData) {
                $txtImportLog.Text += "[ERROR] Failed to read CSV or file is empty.`r`n"
                return
            }

            $headers = $csvData[0].psobject.properties.name
            $missingHeaders = @()
            foreach ($req in @('Name', 'IPAddress', 'MACAddress', 'Description')) {
                if ($headers -notcontains $req) { $missingHeaders += $req }
            }
            
            if ($missingHeaders.Count -gt 0) {
                $txtImportLog.Text += "[ERROR] Invalid CSV format. Missing required columns: $($missingHeaders -join ', ')`r`n"
                $txtImportLog.Text += "[INFO] Any extra columns (like those from a Scope Export) are allowed and will be ignored, but the base columns must exist.`r`n"
                return
            }

            $btnSelectCsv.Enabled = $false
            $chkOverwrite.Enabled = $false
            $importForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

            $txtImportLog.Text += "[INFO] Discovering scope routing paths across target servers...`r`n"
            [System.Windows.Forms.Application]::DoEvents()
            
            $globalScopeCache = @{}
            foreach ($server in ($script:DhcpServers)) {
                try { 
                    $globalScopeCache[$server] = Get-DhcpServerv4Scope -ComputerName ($server) -ErrorAction Stop 
                } catch {}
            }
            
            $successes = 0
            $failures = 0

            foreach ($row in ($csvData)) {
                $rowName = $row.Name
                $rowIP = $row.IPAddress
                $rowRawMAC = $row.MACAddress
                $rowDesc = $row.Description

                if ([string]::IsNullOrWhiteSpace($rowName) -or [string]::IsNullOrWhiteSpace($rowIP) -or [string]::IsNullOrWhiteSpace($rowRawMAC)) {
                    $txtImportLog.Text += "[SKIP] Missing required fields for row: $($row | ConvertTo-Json -Compress)`r`n"
                    $failures++
                    continue
                }

                if ($rowIP -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.$') { $rowIP = $rowIP + "0" }
                $parsedIP = $null
                if (-not [System.Net.IPAddress]::TryParse($rowIP, [ref]$parsedIP) -or $parsedIP.AddressFamily -ne 'InterNetwork') {
                    $txtImportLog.Text += "[SKIP] Invalid IP format: $rowIP`r`n"
                    $failures++
                    continue
                }

                $rowMAC = $rowRawMAC -replace '[^a-fA-F0-9]', ''
                if ($rowMAC -notmatch '^[0-9a-fA-F]{12}$') {
                    $txtImportLog.Text += "[SKIP] Invalid MAC format: $rowRawMAC`r`n"
                    $failures++
                    continue
                }

                $TargetScopeId = $null
                if ($globalScopeCache[$script:DhcpServers[0]]) {
                    $exactMatch = $globalScopeCache[$script:DhcpServers[0]] | Where-Object { $_.ScopeId.ToString() -eq $rowIP }
                    if ($exactMatch) { $TargetScopeId = $exactMatch[0].ScopeId.ToString() } else {
                        try {
                            $ipBytes = [System.Net.IPAddress]::Parse($rowIP).GetAddressBytes()
                            foreach ($s in ($globalScopeCache[$script:DhcpServers[0]])) {
                                $maskBytes = [System.Net.IPAddress]::Parse($s.SubnetMask).GetAddressBytes()
                                $scopeBytes = [System.Net.IPAddress]::Parse($s.ScopeId).GetAddressBytes()
                                $isMatch = $true
                                for ($i=0; $i -lt 4; $i++) { if (($ipBytes[$i] -band $maskBytes[$i]) -ne $scopeBytes[$i]) { $isMatch = $false; break } }
                                if ($isMatch) { $TargetScopeId = $s.ScopeId.ToString(); break }
                            }
                        } catch {}
                    }
                }

                if ([string]::IsNullOrWhiteSpace($TargetScopeId)) {
                    $txtImportLog.Text += "[SKIP] No valid network scope found for IP: $rowIP`r`n"
                    $failures++
                    continue
                }

                $ValidServers = @()
                foreach ($server in ($script:DhcpServers)) {
                    if ($globalScopeCache[$server] | Where-Object { $_.ScopeId.ToString() -eq $TargetScopeId }) {
                        $ValidServers += $server
                    }
                }
                
                if ($ValidServers.Count -eq 0) {
                     $txtImportLog.Text += "[SKIP] Target scope $TargetScopeId offline for IP: $rowIP`r`n"
                     $failures++
                     continue
                }

                $foundConflicts = @()
                foreach ($server in ($ValidServers)) {
                    try {
                        $resIP = Get-DhcpServerv4Reservation -ComputerName ($server) -IPAddress ($rowIP) -ErrorAction Stop
                        if ($resIP) { $foundConflicts += [PSCustomObject]@{ Server = $server; Type = "Reservation"; TargetIP = $resIP.IPAddress } }
                    } catch {}

                    try {
                        $leaseIP = Get-DhcpServerv4Lease -ComputerName ($server) -IPAddress ($rowIP) -ErrorAction Stop
                        if ($leaseIP) { $foundConflicts += [PSCustomObject]@{ Server = $server; Type = "Lease"; TargetIP = $leaseIP.IPAddress } }
                    } catch {}

                    try {
                        $allReservations = Get-DhcpServerv4Reservation -ComputerName ($server) -ScopeId ($TargetScopeId) -ErrorAction Stop
                        foreach ($res in ($allReservations)) {
                            if (($res.ClientId -replace '[^a-fA-F0-9]', '') -eq $rowMAC -and $res.IPAddress -ne $rowIP) {
                                $foundConflicts += [PSCustomObject]@{ Server = $server; Type = "Reservation"; TargetIP = $res.IPAddress }
                            }
                        }
                    } catch {}

                    try {
                        $allLeases = Get-DhcpServerv4Lease -ComputerName ($server) -ScopeId ($TargetScopeId) -ErrorAction Stop
                        foreach ($lease in ($allLeases)) {
                            if ((($lease.ClientId -replace '[^a-fA-F0-9]', '') -eq $rowMAC) -and ($lease.IPAddress -ne $rowIP)) {
                                $foundConflicts += [PSCustomObject]@{ Server = $server; Type = "Lease"; TargetIP = $lease.IPAddress }
                            }
                        }
                    } catch {}
                }

                if ($foundConflicts.Count -gt 0) {
                    if ($chkOverwrite.Checked) {
                        foreach ($conflict in ($foundConflicts)) {
                            try {
                                if ($conflict.Type -eq "Reservation") { Remove-DhcpServerv4Reservation -ComputerName ($conflict.Server) -IPAddress ($conflict.TargetIP) -ErrorAction Stop } 
                                else { Remove-DhcpServerv4Lease -ComputerName ($conflict.Server) -IPAddress ($conflict.TargetIP) -ErrorAction Stop }
                            } catch {}
                        }
                        $txtImportLog.Text += "[WARN] Overwrote database conflict(s) for $rowIP ($rowMAC)`r`n"
                    } else {
                        $txtImportLog.Text += "[SKIP] Conflict detected for $rowIP ($rowMAC) - skipped`r`n"
                        $failures++
                        continue
                    }
                }

                $rowSuccess = 0
                foreach ($server in ($ValidServers)) {
                    try {
                        Add-DhcpServerv4Reservation -ComputerName ($server) -ScopeId ($TargetScopeId) -IPAddress ($rowIP) -ClientId ($rowMAC) -Name ($rowName) -Description ($rowDesc) -Type "Dhcp" -ErrorAction Stop
                        $rowSuccess++
                    } catch {}
                }

                if ($rowSuccess -eq $ValidServers.Count) {
                    $txtImportLog.Text += "[OK] Pushed $rowIP ($rowName)`r`n"
                    $successes++
                } else {
                    $txtImportLog.Text += "[ERROR] Server rejection for $rowIP ($rowName)`r`n"
                    $failures++
                }

                $txtImportLog.SelectionStart = $txtImportLog.Text.Length
                $txtImportLog.ScrollToCaret()
                [System.Windows.Forms.Application]::DoEvents()
            }

            $txtImportLog.Text += "`r`n--- IMPORT BATCH COMPLETE ---`r`nSuccessfully Provisioned: $successes`r`nSkipped/Failed: $failures`r`n"
            $txtImportLog.SelectionStart = $txtImportLog.Text.Length
            $txtImportLog.ScrollToCaret()
            
            $btnSelectCsv.Enabled = $true
            $chkOverwrite.Enabled = $true
            $importForm.Cursor = [System.Windows.Forms.Cursors]::Default
        })

        $form.TopMost = $false
        $null = $importForm.ShowDialog($form)
        $importForm.Dispose()
    } finally {
        $btnImportCsv.Enabled = $true
        $form.TopMost = $true
    }
})

function Launch-DisplayGrid {
    param($TitleText, $RecordsArray, $TargetScopeId, $LiveLoadBlock)

    $gridForm = New-Object System.Windows.Forms.Form
    $gridForm.Text = $TitleText
    $gridForm.Size = New-Object System.Drawing.Size(1480, 850)
    $gridForm.StartPosition = "CenterParent"
    $gridForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $gridForm.MaximizeBox = $true
    $gridForm.MinimizeBox = $false
    
    $lblFilter = New-Object System.Windows.Forms.Label
    $lblFilter.Text = "Filter:"
    $lblFilter.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $lblFilter.Location = New-Object System.Drawing.Point(20, 22)
    $lblFilter.Size = New-Object System.Drawing.Size(70, 30)
    $gridForm.Controls.Add($lblFilter)

    $txtFilter = New-Object System.Windows.Forms.TextBox
    $txtFilter.Font = $gridFont
    $txtFilter.Location = New-Object System.Drawing.Point(95, 17)
    $txtFilter.Size = New-Object System.Drawing.Size(320, 35)
    $gridForm.Controls.Add($txtFilter)

    $cmbCriteria = New-Object System.Windows.Forms.ComboBox
    $cmbCriteria.Font = $gridFont
    $cmbCriteria.Location = New-Object System.Drawing.Point(435, 17)
    $cmbCriteria.Size = New-Object System.Drawing.Size(200, 35)
    $cmbCriteria.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $null = $cmbCriteria.Items.AddRange(@("Add criteria", "Type", "ScopeId", "ScopeName", "CIDR", "SubnetMask", "Server", "Name", "IPAddress", "MACAddress", "MACVendor", "Description", "PingStatus"))
    $cmbCriteria.SelectedIndex = 0
    $gridForm.Controls.Add($cmbCriteria)

    $btnClearAll = New-Object System.Windows.Forms.Button
    $btnClearAll.Text = "Clear All"
    $btnClearAll.Font = $gridFont
    $btnClearAll.Location = New-Object System.Drawing.Point(650, 16)
    $btnClearAll.Size = New-Object System.Drawing.Size(110, 36)
    $gridForm.Controls.Add($btnClearAll)

    $btnCloseGrid = New-Object System.Windows.Forms.Button
    $btnCloseGrid.Text = "Close"
    $btnCloseGrid.Font = $gridFont
    $btnCloseGrid.Location = New-Object System.Drawing.Point(770, 16)
    $btnCloseGrid.Size = New-Object System.Drawing.Size(110, 36)
    $btnCloseGrid.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $gridForm.Controls.Add($btnCloseGrid)
    
    $gridForm.CancelButton = $btnCloseGrid

    $pnlCriteria = New-Object System.Windows.Forms.FlowLayoutPanel
    $pnlCriteria.Location = New-Object System.Drawing.Point(20, 65)
    $pnlCriteria.Size = New-Object System.Drawing.Size(1420, 110) 
    $pnlCriteria.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $pnlCriteria.WrapContents = $false
    $pnlCriteria.AutoScroll = $true
    $pnlCriteria.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 235) 
    $pnlCriteria.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $gridForm.Controls.Add($pnlCriteria)

    $btnPingSelected = New-Object System.Windows.Forms.Button
    $btnPingSelected.Text = "Ping Selected"
    $btnPingSelected.Font = $gridFont
    $btnPingSelected.Location = New-Object System.Drawing.Point(20, 185)
    $btnPingSelected.Size = New-Object System.Drawing.Size(160, 38)
    $gridForm.Controls.Add($btnPingSelected)

    $btnPingAll = New-Object System.Windows.Forms.Button
    $btnPingAll.Text = "Ping All"
    $btnPingAll.Font = $gridFont
    $btnPingAll.Location = New-Object System.Drawing.Point(190, 185)
    $btnPingAll.Size = New-Object System.Drawing.Size(130, 38)
    $gridForm.Controls.Add($btnPingAll)

    $btnStopPing = New-Object System.Windows.Forms.Button
    $btnStopPing.Text = "Stop Ping"
    $btnStopPing.Font = $gridFont
    $btnStopPing.Location = New-Object System.Drawing.Point(330, 185)
    $btnStopPing.Size = New-Object System.Drawing.Size(140, 38)
    $btnStopPing.Enabled = $false
    $gridForm.Controls.Add($btnStopPing)

    if (-not [string]::IsNullOrWhiteSpace($TargetScopeId)) {
        $btnScopeOptions = New-Object System.Windows.Forms.Button
        $btnScopeOptions.Text = "View Scope/Server Options"
        $btnScopeOptions.Font = $gridFont
        $btnScopeOptions.Location = New-Object System.Drawing.Point(480, 185)
        $btnScopeOptions.Size = New-Object System.Drawing.Size(240, 38)
        $gridForm.Controls.Add($btnScopeOptions)

        $btnScopeOptions.Add_Click({
            $btnScopeOptions.Enabled = $false
            try {
                $optForm = New-Object System.Windows.Forms.Form
                $optForm.Text = "DHCP Options Hierarchy — Scope ID: $TargetScopeId & Server Level"
                $optForm.Size = New-Object System.Drawing.Size(900, 500)
                $optForm.StartPosition = "CenterParent"
                $optForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
                $optForm.MaximizeBox = $true
                $optForm.MinimizeBox = $false

                $optGrid = New-Object System.Windows.Forms.DataGridView
                $optGrid.Location = New-Object System.Drawing.Point(20, 20)
                $optGrid.Size = New-Object System.Drawing.Size(840, 410)
                $optGrid.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
                $optGrid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
                $optGrid.ReadOnly = $true
                $optGrid.AllowUserToAddRows = $false
                $optGrid.Font = $gridFont
                $optGrid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
                $optGrid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
                $optGrid.RowTemplate.Height = 32
                Enable-GridCopy -grid $optGrid
                $optForm.Controls.Add($optGrid)

                $optTable = New-Object System.Data.DataTable
                $null = $optTable.Columns.Add("Level")
                $null = $optTable.Columns.Add("Option ID")
                $null = $optTable.Columns.Add("Option Name")
                $null = $optTable.Columns.Add("Value")

                $fetchedScopeOptions = @()
                foreach ($srv in ($script:DhcpServers)) {
                    try {
                        $fetchedScopeOptions = Get-DhcpServerv4OptionValue -ComputerName ($srv) -ScopeId ($TargetScopeId) -ErrorAction Stop
                        if ($fetchedScopeOptions) { break }
                    } catch {}
                }

                $fetchedServerOptions = @()
                foreach ($srv in ($script:DhcpServers)) {
                    try {
                        $fetchedServerOptions = Get-DhcpServerv4OptionValue -ComputerName ($srv) -ErrorAction Stop
                        if ($fetchedServerOptions) { break }
                    } catch {}
                }

                foreach ($opt in ($fetchedScopeOptions)) {
                    $r = $optTable.NewRow()
                    $r["Level"]       = "Scope"
                    $r["Option ID"]   = "Option $($opt.OptionId.ToString().PadLeft(3, '0'))"
                    $r["Option Name"] = $opt.Name
                    $r["Value"]       = if ($opt.Value) { $opt.Value -join ", " } else { "" }
                    $optTable.Rows.Add($r)
                }

                foreach ($opt in ($fetchedServerOptions)) {
                    $r = $optTable.NewRow()
                    $r["Level"]       = "Server"
                    $r["Option ID"]   = "Option $($opt.OptionId.ToString().PadLeft(3, '0'))"
                    $r["Option Name"] = $opt.Name
                    $r["Value"]       = if ($opt.Value) { $opt.Value -join ", " } else { "" }
                    $optTable.Rows.Add($r)
                }

                $optGrid.DataSource = $optTable

                $gridForm.TopMost = $false
                $null = $optForm.ShowDialog($gridForm)
                $optForm.Dispose()
            } finally {
                $btnScopeOptions.Enabled = $true
                $gridForm.TopMost = $true
            }
        })
    }

    $btnExportCsv = New-Object System.Windows.Forms.Button
    $btnExportCsv.Text = "Export to CSV"
    $btnExportCsv.Font = $gridFont
    $btnExportCsv.Size = New-Object System.Drawing.Size(160, 38)
    if (-not [string]::IsNullOrWhiteSpace($TargetScopeId)) {
        $btnExportCsv.Location = New-Object System.Drawing.Point(730, 185)
    } else {
        $btnExportCsv.Location = New-Object System.Drawing.Point(480, 185)
    }
    $gridForm.Controls.Add($btnExportCsv)

    $dataGridView = New-Object System.Windows.Forms.DataGridView
    $dataGridView.Location = New-Object System.Drawing.Point(20, 235) 
    $dataGridView.Size = New-Object System.Drawing.Size(1420, 550)     
    $dataGridView.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $dataGridView.ReadOnly = $true
    $dataGridView.AllowUserToAddRows = $false
    $dataGridView.RowTemplate.Height = 32
    $dataGridView.Font = $gridFont
    $dataGridView.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $dataGridView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $dataGridView.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
    Enable-GridCopy -grid $dataGridView

    $targetServersSnapshot = @($script:DhcpServers)

    $dataTable = New-Object System.Data.DataTable
    $null = $dataTable.Columns.Add("Type")
    $null = $dataTable.Columns.Add("ScopeId")
    $null = $dataTable.Columns.Add("ScopeName")
    $null = $dataTable.Columns.Add("CIDR")
    $null = $dataTable.Columns.Add("SubnetMask")
    $null = $dataTable.Columns.Add("Server")
    $null = $dataTable.Columns.Add("Name")
    $null = $dataTable.Columns.Add("IPAddress")
    $null = $dataTable.Columns.Add("IPAddress_Sort") 
    $null = $dataTable.Columns.Add("SubnetMask_Sort")
    $null = $dataTable.Columns.Add("ScopeId_Sort")
    $null = $dataTable.Columns.Add("MACAddress")
    $null = $dataTable.Columns.Add("MACAddress_Raw")
    $null = $dataTable.Columns.Add("MACVendor")
    $null = $dataTable.Columns.Add("Description") 
    $null = $dataTable.Columns.Add("PingStatus") 

    $miConvertSep = New-Object System.Windows.Forms.ToolStripSeparator
    $null = $dataGridView.ContextMenuStrip.Items.Add($miConvertSep)

    $miConvert = New-Object System.Windows.Forms.ToolStripMenuItem "Convert Lease to Reservation"
    $miConvert.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    
    $miConvert.Add_Click({
        if (-not $dataGridView.CurrentRow) { return }
        $row = $dataGridView.CurrentRow

        $entryType   = $row.Cells["Type"].Value
        $targetIP    = $row.Cells["IPAddress"].Value
        $targetMAC   = $row.Cells["MACAddress"].Value
        $targetScope = $row.Cells["ScopeId"].Value
        $currName    = $row.Cells["Name"].Value
        $currDesc    = $row.Cells["Description"].Value
        $rowServer   = $row.Cells["Server"].Value

        if ($entryType -eq "Reservation") {
            [System.Windows.Forms.MessageBox]::Show("This entry is already a Reservation.", "Already Reserved", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }

        if ([string]::IsNullOrWhiteSpace($targetIP) -or $targetIP -eq "—") {
            [System.Windows.Forms.MessageBox]::Show("Invalid IP address selected.", "Action Blocked", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $activeServers = if ($targetServersSnapshot.Count -gt 0) { $targetServersSnapshot } else { @($rowServer) }
        if ($activeServers.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($rowServer)) { $activeServers = @($rowServer) }

        $ValidServers = @()
        foreach ($srv in ($activeServers)) {
            try {
                $chk = Get-DhcpServerv4Scope -ComputerName ($srv) -ScopeId ($targetScope) -ErrorAction Stop
                if ($chk) { $ValidServers += $srv }
            } catch {}
        }
        if ($ValidServers.Count -eq 0) { $ValidServers = @($rowServer) }

        $convForm = New-Object System.Windows.Forms.Form
        $convForm.Text = "Convert Lease to Reservation — $targetIP"
        $convForm.Size = New-Object System.Drawing.Size(600, 360)
        $convForm.StartPosition = "CenterParent"
        $convForm.FormBorderStyle = "FixedDialog"
        $convForm.MaximizeBox = $false
        $convForm.MinimizeBox = $false
        $convForm.Font = New-Object System.Drawing.Font("Segoe UI", 11)

        $lblDetail = New-Object System.Windows.Forms.Label
        $lblDetail.Text = "Convert Lease ($targetIP / $targetMAC) on Scope $targetScope"
        $lblDetail.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $lblDetail.Location = New-Object System.Drawing.Point(20, 15)
        $lblDetail.Size = New-Object System.Drawing.Size(540, 30)
        $convForm.Controls.Add($lblDetail)

        $lblConvName = New-Object System.Windows.Forms.Label
        $lblConvName.Text = "Reservation Name:"
        $lblConvName.Location = New-Object System.Drawing.Point(20, 65)
        $lblConvName.Size = New-Object System.Drawing.Size(160, 28)
        $convForm.Controls.Add($lblConvName)

        $txtConvName = New-Object System.Windows.Forms.TextBox
        $txtConvName.Text = if ($currName -and $currName -ne "—") { $currName } else { "" }
        $txtConvName.Location = New-Object System.Drawing.Point(190, 60)
        $txtConvName.Size = New-Object System.Drawing.Size(370, 32)
        $convForm.Controls.Add($txtConvName)

        $lblConvDesc = New-Object System.Windows.Forms.Label
        $lblConvDesc.Text = "Description:"
        $lblConvDesc.Location = New-Object System.Drawing.Point(20, 115)
        $lblConvDesc.Size = New-Object System.Drawing.Size(160, 28)
        $convForm.Controls.Add($lblConvDesc)

        $txtConvDesc = New-Object System.Windows.Forms.TextBox
        $txtConvDesc.Text = if ($currDesc -and $currDesc -notmatch '^State:') { $currDesc } else { "Converted from active lease" }
        $txtConvDesc.Location = New-Object System.Drawing.Point(190, 110)
        $txtConvDesc.Size = New-Object System.Drawing.Size(370, 32)
        $convForm.Controls.Add($txtConvDesc)

        $btnDoConvert = New-Object System.Windows.Forms.Button
        $btnDoConvert.Text = "Create Reservation"
        $btnDoConvert.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $btnDoConvert.Location = New-Object System.Drawing.Point(190, 175)
        $btnDoConvert.Size = New-Object System.Drawing.Size(200, 40)
        $btnDoConvert.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $convForm.Controls.Add($btnDoConvert)

        $btnCancelConv = New-Object System.Windows.Forms.Button
        $btnCancelConv.Text = "Cancel"
        $btnCancelConv.Location = New-Object System.Drawing.Point(400, 175)
        $btnCancelConv.Size = New-Object System.Drawing.Size(110, 40)
        $btnCancelConv.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $convForm.Controls.Add($btnCancelConv)

        $convForm.AcceptButton = $btnDoConvert
        $convForm.CancelButton = $btnCancelConv

        $gridForm.TopMost = $false
        $dlgRes = $convForm.ShowDialog($gridForm)
        $gridForm.TopMost = $true

        if ($dlgRes -eq [System.Windows.Forms.DialogResult]::OK) {
            $newName = $txtConvName.Text.Trim()
            $newDesc = $txtConvDesc.Text.Trim()

            if ([string]::IsNullOrWhiteSpace($newName)) {
                [System.Windows.Forms.MessageBox]::Show("Reservation Name cannot be empty.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                $convForm.Dispose()
                return
            }

            $cleanMAC = $targetMAC -replace '[:.-]', ''
            $statusLog = ""
            $successes = 0

            foreach ($server in ($activeServers)) {
                try {
                    Add-DhcpServerv4Reservation -ComputerName ($server) -ScopeId ($targetScope) -IPAddress ($targetIP) -ClientId ($cleanMAC) -Name ($newName) -Description ($newDesc) -Type "Dhcp" -ErrorAction Stop
                    $successes++
                    $statusLog += "• $server : Success`n"
                } catch {
                    try {
                        Remove-DhcpServerv4Lease -ComputerName ($server) -IPAddress ($targetIP) -ErrorAction Stop
                        Add-DhcpServerv4Reservation -ComputerName ($server) -ScopeId ($targetScope) -IPAddress ($targetIP) -ClientId ($cleanMAC) -Name ($newName) -Description ($newDesc) -Type "Dhcp" -ErrorAction Stop
                        $successes++
                        $statusLog += "• $server : Success (Cleared active lease)`n"
                    } catch {
                        $statusLog += "• $server : FAILED ($($_.Exception.Message))`n"
                    }
                }
            }

            if ($successes -gt 0) {
                $row.Cells["Type"].Value = "Reservation"
                $row.Cells["Name"].Value = $newName
                $row.Cells["Description"].Value = $newDesc
                [System.Windows.Forms.MessageBox]::Show("Lease successfully converted to Reservation across $successes server(s)!`n`n$statusLog", "Conversion Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            } else {
                [System.Windows.Forms.MessageBox]::Show("Failed to convert lease on any server target:`n`n$statusLog", "Conversion Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
        $convForm.Dispose()
    }.GetNewClosure())

    $null = $dataGridView.ContextMenuStrip.Items.Add($miConvert)

    $miDelete = New-Object System.Windows.Forms.ToolStripMenuItem "Delete Reservation / Lease"
    $miDelete.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $miDelete.ForeColor = [System.Drawing.Color]::DarkRed

    $miDelete.Add_Click({
        if (-not $dataGridView.CurrentRow) { return }
        $row = $dataGridView.CurrentRow

        $entryType   = $row.Cells["Type"].Value
        $targetIP    = $row.Cells["IPAddress"].Value
        $targetMAC   = $row.Cells["MACAddress"].Value
        $targetScope = $row.Cells["ScopeId"].Value
        $currName    = $row.Cells["Name"].Value
        $rowServer   = $row.Cells["Server"].Value

        if ([string]::IsNullOrWhiteSpace($targetIP) -or $targetIP -eq "—") {
            [System.Windows.Forms.MessageBox]::Show("Invalid IP address selected.", "Action Blocked", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $activeServers = if ($targetServersSnapshot.Count -gt 0) { $targetServersSnapshot } else { @($rowServer) }
        if ($activeServers.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($rowServer)) { $activeServers = @($rowServer) }

        $ValidServers = @()
        foreach ($srv in ($activeServers)) {
            try {
                $chk = Get-DhcpServerv4Scope -ComputerName ($srv) -ScopeId ($targetScope) -ErrorAction Stop
                if ($chk) { $ValidServers += $srv }
            } catch {}
        }
        if ($ValidServers.Count -eq 0) { $ValidServers = @($rowServer) }

        $confirmMsg = "Are you sure you want to delete this $entryType entry from active target servers?`n`nName: $currName`nIP: $targetIP`nMAC: $targetMAC`nScope ID: $targetScope"
        $confirmResult = [System.Windows.Forms.MessageBox]::Show($confirmMsg, "Confirm $entryType Deletion", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)

        if ($confirmResult -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        $statusLog = ""
        $successes = 0

        foreach ($server in ($ValidServers)) {
            try {
                if ($entryType -eq "Reservation") {
                    Remove-DhcpServerv4Reservation -ComputerName ($server) -IPAddress ($targetIP) -ErrorAction Stop
                } else {
                    Remove-DhcpServerv4Lease -ComputerName ($server) -IPAddress ($targetIP) -ErrorAction Stop
                }
                $successes++
                $statusLog += "• $server : Removed successfully`n"
            } catch {
                $statusLog += "• $server : FAILED ($($_.Exception.Message))`n"
            }
        }

        if ($successes -gt 0) {
            $dataGridView.Rows.Remove($row)
            [System.Windows.Forms.MessageBox]::Show("$entryType entry for $targetIP successfully deleted across $successes server(s)!`n`n$statusLog", "Deletion Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            [System.Windows.Forms.MessageBox]::Show("Failed to delete $entryType on any server target:`n`n$statusLog", "Deletion Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }.GetNewClosure())

    $null = $dataGridView.ContextMenuStrip.Items.Add($miDelete)
    
    $miMigrate = New-Object System.Windows.Forms.ToolStripMenuItem "Copy / Move Selected..."
    $miMigrate.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $miMigrate.Add_Click({
        if ($dataGridView.SelectedRows.Count -eq 0) { return }
        $selRows = $dataGridView.SelectedRows

        $migForm = New-Object System.Windows.Forms.Form
        $migForm.Text = "Bulk Migration Tool"
        $migForm.Size = New-Object System.Drawing.Size(650, 480)
        $migForm.StartPosition = "CenterParent"
        $migForm.FormBorderStyle = "FixedDialog"
        $migForm.MaximizeBox = $false
        $migForm.MinimizeBox = $false
        $migForm.Font = New-Object System.Drawing.Font("Segoe UI", 11)

        $lblDetail = New-Object System.Windows.Forms.Label
        $lblDetail.Text = "Migrating $($selRows.Count) selected record(s)"
        $lblDetail.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $lblDetail.Location = New-Object System.Drawing.Point(20, 15)
        $lblDetail.Size = New-Object System.Drawing.Size(540, 30)
        $migForm.Controls.Add($lblDetail)

        $gbAction = New-Object System.Windows.Forms.GroupBox
        $gbAction.Text = "Operation Type"
        $gbAction.Location = New-Object System.Drawing.Point(20, 55)
        $gbAction.Size = New-Object System.Drawing.Size(600, 65)
        $migForm.Controls.Add($gbAction)

        $rbCopy = New-Object System.Windows.Forms.RadioButton
        $rbCopy.Text = "Copy (Keep original intact)"
        $rbCopy.Location = New-Object System.Drawing.Point(20, 25)
        $rbCopy.Size = New-Object System.Drawing.Size(250, 25)
        $rbCopy.Checked = $true
        $gbAction.Controls.Add($rbCopy)

        $rbMove = New-Object System.Windows.Forms.RadioButton
        $rbMove.Text = "Move (Delete original after successful push)"
        $rbMove.Location = New-Object System.Drawing.Point(280, 25)
        $rbMove.Size = New-Object System.Drawing.Size(310, 25)
        $gbAction.Controls.Add($rbMove)

        $lblDestScope = New-Object System.Windows.Forms.Label
        $lblDestScope.Text = "Destination Scope ID:"
        $lblDestScope.Location = New-Object System.Drawing.Point(20, 135)
        $lblDestScope.Size = New-Object System.Drawing.Size(180, 28)
        $migForm.Controls.Add($lblDestScope)

        $txtDestScope = New-Object System.Windows.Forms.TextBox
        $txtDestScope.Text = $selRows[0].Cells["ScopeId"].Value.ToString()
        $txtDestScope.Location = New-Object System.Drawing.Point(200, 130)
        $txtDestScope.Size = New-Object System.Drawing.Size(200, 32)
        $migForm.Controls.Add($txtDestScope)

        $lblDestIPNote = New-Object System.Windows.Forms.Label
        $lblDestIPNote.Text = "*If scope differs, new free IPs will be auto-allocated."
        $lblDestIPNote.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
        $lblDestIPNote.ForeColor = [System.Drawing.Color]::DimGray
        $lblDestIPNote.Location = New-Object System.Drawing.Point(200, 165)
        $lblDestIPNote.Size = New-Object System.Drawing.Size(350, 20)
        $migForm.Controls.Add($lblDestIPNote)

        $lblDestSrv = New-Object System.Windows.Forms.Label
        $lblDestSrv.Text = "Destination Server(s):"
        $lblDestSrv.Location = New-Object System.Drawing.Point(20, 195)
        $lblDestSrv.Size = New-Object System.Drawing.Size(180, 28)
        $migForm.Controls.Add($lblDestSrv)

        $lbMigSrv = New-Object System.Windows.Forms.ListBox
        $lbMigSrv.Location = New-Object System.Drawing.Point(200, 195)
        $lbMigSrv.Size = New-Object System.Drawing.Size(420, 150)
        $lbMigSrv.SelectionMode = [System.Windows.Forms.SelectionMode]::MultiExtended
        foreach ($srv in ($targetServersSnapshot)) { 
            if (-not [string]::IsNullOrWhiteSpace($srv)) { $null = $lbMigSrv.Items.Add($srv) }
        }
        $migForm.Controls.Add($lbMigSrv)

        $btnMigExec = New-Object System.Windows.Forms.Button
        $btnMigExec.Text = "Execute Migration"
        $btnMigExec.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $btnMigExec.Location = New-Object System.Drawing.Point(200, 360)
        $btnMigExec.Size = New-Object System.Drawing.Size(200, 40)
        $migForm.Controls.Add($btnMigExec)

        $btnMigCancel = New-Object System.Windows.Forms.Button
        $btnMigCancel.Text = "Cancel"
        $btnMigCancel.Location = New-Object System.Drawing.Point(410, 360)
        $btnMigCancel.Size = New-Object System.Drawing.Size(110, 40)
        $btnMigCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $migForm.Controls.Add($btnMigCancel)

        $btnMigExec.Add_Click({
            $btnMigExec.Enabled = $false
            try {
                if ($lbMigSrv.SelectedItems.Count -eq 0) {
                    [System.Windows.Forms.MessageBox]::Show("Select at least one destination server.", "Error", 0, 48)
                    return
                }
                
                $targetScope = $txtDestScope.Text.Trim()
                if (-not ($targetScope -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')) {
                    [System.Windows.Forms.MessageBox]::Show("Invalid Target Scope format.", "Error", 0, 48)
                    return
                }

                $targetServers = @($lbMigSrv.SelectedItems)
                $isMove = $rbMove.Checked
                $migForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

                $newIpMapping = @{} 
                $needsNewIP = $false
                foreach ($r in ($selRows)) { 
                    if ($r.Cells["ScopeId"].Value.ToString() -ne $targetScope) { $needsNewIP = $true; break } 
                }

                if ($needsNewIP) {
                    try {
                        $freeIPs = Get-DhcpServerv4FreeIPaddress -ComputerName ($targetServers[0]) -ScopeId ($targetScope) -Num $selRows.Count -ErrorAction Stop
                        if ($selRows.Count -eq 1) { $freeIPs = @($freeIPs) }
                        if ($freeIPs.Count -lt $selRows.Count) { 
                            [System.Windows.Forms.MessageBox]::Show("Destination scope does not have enough free IP addresses to accommodate $($selRows.Count) records.", "Allocation Failed", 0, 16)
                            return 
                        }
                        $i = 0
                        foreach ($r in ($selRows)) {
                            $m = $r.Cells["MACAddress_Raw"].Value.ToString()
                            if (-not $m) { $m = ($r.Cells["MACAddress"].Value.ToString() -replace '[^a-fA-F0-9]','') }
                            $newIpMapping[$m] = $freeIPs[$i].IPAddress
                            $i++
                        }
                    } catch {
                        [System.Windows.Forms.MessageBox]::Show("Failed to allocate new IPs: $($_.Exception.Message)", "Allocation Error", 0, 16)
                        return
                    }
                }

                $migSuccess = 0
                $migFail = 0
                $rowsToRemove = @()

                foreach ($r in ($selRows)) {
                    $oldIP = $r.Cells["IPAddress"].Value.ToString()
                    $oldMAC = $r.Cells["MACAddress_Raw"].Value.ToString()
                    if(-not $oldMAC) { $oldMAC = ($r.Cells["MACAddress"].Value.ToString() -replace '[^a-fA-F0-9]','') }
                    $oldName = $r.Cells["Name"].Value.ToString()
                    $oldDesc = $r.Cells["Description"].Value.ToString()
                    $oldServer = $r.Cells["Server"].Value.ToString()
                    $oldScope = $r.Cells["ScopeId"].Value.ToString()
                    $entryType = $r.Cells["Type"].Value.ToString()

                    $pushIP = if ($oldScope -eq $targetScope) { $oldIP } else { $newIpMapping[$oldMAC] }

                    $pushedAny = $false
                    foreach ($tsrv in ($targetServers)) {
                        try {
                            Add-DhcpServerv4Reservation -ComputerName ($tsrv) -ScopeId ($targetScope) -IPAddress ($pushIP) -ClientId ($oldMAC) -Name ($oldName) -Description ($oldDesc) -ErrorAction Stop
                            $pushedAny = $true
                        } catch {}
                    }

                    if ($pushedAny) {
                        $migSuccess++
                        if ($isMove) {
                            try {
                                if ($entryType -eq "Reservation") { Remove-DhcpServerv4Reservation -ComputerName ($oldServer) -IPAddress ($oldIP) -ErrorAction Stop }
                                else { Remove-DhcpServerv4Lease -ComputerName ($oldServer) -IPAddress ($oldIP) -ErrorAction Stop }
                                $rowsToRemove += $r
                            } catch {}
                        }
                    } else {
                        $migFail++
                    }
                }
                
                foreach ($rr in ($rowsToRemove)) { $dataGridView.Rows.Remove($rr) }

                $migForm.Cursor = [System.Windows.Forms.Cursors]::Default
                [System.Windows.Forms.MessageBox]::Show("Migration Complete.`nSuccessful: $migSuccess`nFailed: $migFail", "Complete", 0, 64)
                $migForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
            } finally {
                $btnMigExec.Enabled = $true
                $migForm.Cursor = [System.Windows.Forms.Cursors]::Default
            }
        })

        $migForm.AcceptButton = $btnMigExec
        $migForm.CancelButton = $btnMigCancel
        
        $gridForm.TopMost = $false
        $null = $migForm.ShowDialog($gridForm)
        $migForm.Dispose()
        $gridForm.TopMost = $true
    }.GetNewClosure())

    $null = $dataGridView.ContextMenuStrip.Items.Add($miMigrate)
    $null = $dataGridView.ContextMenuStrip.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $miEdit = New-Object System.Windows.Forms.ToolStripMenuItem "Edit Reservation"
    $miEdit.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

    $miEdit.Add_Click({
        if (-not $dataGridView.CurrentRow) { return }
        $row = $dataGridView.CurrentRow

        $entryType   = $row.Cells["Type"].Value
        $targetIP    = $row.Cells["IPAddress"].Value
        $currMAC     = $row.Cells["MACAddress"].Value
        $currName    = $row.Cells["Name"].Value
        $currDesc    = $row.Cells["Description"].Value
        $rowServer   = $row.Cells["Server"].Value
        $targetScope = $row.Cells["ScopeId"].Value

        if ($entryType -ne "Reservation") {
            [System.Windows.Forms.MessageBox]::Show("Only Reservations can be edited. To modify a lease, convert it to a reservation first.", "Action Blocked", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }

        if ([string]::IsNullOrWhiteSpace($targetIP) -or $targetIP -eq "—") {
            [System.Windows.Forms.MessageBox]::Show("Invalid IP address selected.", "Action Blocked", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $activeServers = if ($targetServersSnapshot.Count -gt 0) { $targetServersSnapshot } else { @($rowServer) }
        if ($activeServers.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($rowServer)) { $activeServers = @($rowServer) }

        $ValidServers = @()
        foreach ($server in ($activeServers)) {
            try {
                if (Get-DhcpServerv4Scope -ComputerName ($server) -ScopeId ($targetScope) -ErrorAction Stop) {
                    $ValidServers += $server
                }
            } catch {}
        }
        if ($ValidServers.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("The scope '$targetScope' could not be found on any active server targets you have permission to query.", "Scope Offline", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $editForm = New-Object System.Windows.Forms.Form
        $editForm.Text = "Edit Reservation — $targetIP"
        $editForm.Size = New-Object System.Drawing.Size(600, 420)
        $editForm.StartPosition = "CenterParent"
        $editForm.FormBorderStyle = "FixedDialog"
        $editForm.MaximizeBox = $false
        $editForm.MinimizeBox = $false
        $editForm.Font = New-Object System.Drawing.Font("Segoe UI", 11)

        $lblDetail = New-Object System.Windows.Forms.Label
        $lblDetail.Text = "Modifying Reservation for $targetIP"
        $lblDetail.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $lblDetail.Location = New-Object System.Drawing.Point(20, 15)
        $lblDetail.Size = New-Object System.Drawing.Size(540, 30)
        $editForm.Controls.Add($lblDetail)

        $lblEditName = New-Object System.Windows.Forms.Label
        $lblEditName.Text = "Reservation Name:"
        $lblEditName.Location = New-Object System.Drawing.Point(20, 65)
        $lblEditName.Size = New-Object System.Drawing.Size(160, 28)
        $editForm.Controls.Add($lblEditName)

        $txtEditName = New-Object System.Windows.Forms.TextBox
        $txtEditName.Text = if ($currName -and $currName -ne "—") { $currName } else { "" }
        $txtEditName.Location = New-Object System.Drawing.Point(190, 60)
        $txtEditName.Size = New-Object System.Drawing.Size(370, 32)
        $editForm.Controls.Add($txtEditName)

        $lblEditMAC = New-Object System.Windows.Forms.Label
        $lblEditMAC.Text = "MAC Address:"
        $lblEditMAC.Location = New-Object System.Drawing.Point(20, 115)
        $lblEditMAC.Size = New-Object System.Drawing.Size(160, 28)
        $editForm.Controls.Add($lblEditMAC)

        $txtEditMAC = New-Object System.Windows.Forms.TextBox
        $txtEditMAC.Text = if ($currMAC -and $currMAC -ne "—") { $currMAC } else { "" }
        $txtEditMAC.Location = New-Object System.Drawing.Point(190, 110)
        $txtEditMAC.Size = New-Object System.Drawing.Size(370, 32)
        $txtEditMAC.Add_Leave({ $txtEditMAC.Text = Format-MacAddress -mac $txtEditMAC.Text })
        $editForm.Controls.Add($txtEditMAC)

        $lblEditDesc = New-Object System.Windows.Forms.Label
        $lblEditDesc.Text = "Description:"
        $lblEditDesc.Location = New-Object System.Drawing.Point(20, 165)
        $lblEditDesc.Size = New-Object System.Drawing.Size(160, 28)
        $editForm.Controls.Add($lblEditDesc)

        $txtEditDesc = New-Object System.Windows.Forms.TextBox
        $txtEditDesc.Text = if ($currDesc -and $currDesc -ne "—") { $currDesc } else { "" }
        $txtEditDesc.Location = New-Object System.Drawing.Point(190, 160)
        $txtEditDesc.Size = New-Object System.Drawing.Size(370, 32)
        $editForm.Controls.Add($txtEditDesc)

        $btnDoEdit = New-Object System.Windows.Forms.Button
        $btnDoEdit.Text = "Save Changes"
        $btnDoEdit.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $btnDoEdit.Location = New-Object System.Drawing.Point(190, 225)
        $btnDoEdit.Size = New-Object System.Drawing.Size(200, 40)
        $btnDoEdit.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $editForm.Controls.Add($btnDoEdit)

        $btnCancelEdit = New-Object System.Windows.Forms.Button
        $btnCancelEdit.Text = "Cancel"
        $btnCancelEdit.Location = New-Object System.Drawing.Point(400, 225)
        $btnCancelEdit.Size = New-Object System.Drawing.Size(110, 40)
        $editForm.Controls.Add($btnCancelEdit)

        $editForm.AcceptButton = $btnDoEdit
        $editForm.CancelButton = $btnCancelEdit

        $gridForm.TopMost = $false
        $dlgRes = $editForm.ShowDialog($gridForm)
        $gridForm.TopMost = $true

        if ($dlgRes -eq [System.Windows.Forms.DialogResult]::OK) {
            $newName = $txtEditName.Text.Trim()
            $newMAC = $txtEditMAC.Text.Trim()
            $newDesc = $txtEditDesc.Text.Trim()

            if ([string]::IsNullOrWhiteSpace($newName)) {
                [System.Windows.Forms.MessageBox]::Show("Reservation Name cannot be empty.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                $editForm.Dispose()
                return
            }

            $cleanMAC = $newMAC -replace '[^a-fA-F0-9]', ''
            if ($cleanMAC -notmatch '^[0-9a-fA-F]{12}$') {
                [System.Windows.Forms.MessageBox]::Show("The MAC Address format is unrecognized.", "Invalid MAC Address", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                $editForm.Dispose()
                return
            }

            $statusLog = ""
            $successes = 0

            foreach ($server in ($ValidServers)) {
                try {
                    Set-DhcpServerv4Reservation -ComputerName ($server) -IPAddress ($targetIP) -Name ($newName) -ClientId ($cleanMAC) -Description ($newDesc) -ErrorAction Stop
                    $successes++
                    $statusLog += "• $server : Success`n"
                } catch {
                    $statusLog += "• $server : FAILED ($($_.Exception.Message))`n"
                }
            }

            if ($successes -gt 0) {
                $row.Cells["Name"].Value = $newName
                $row.Cells["MACAddress"].Value = Format-MacAddress -mac $cleanMAC
                $row.Cells["MACAddress_Raw"].Value = $cleanMAC.ToUpper()
                $row.Cells["MACVendor"].Value = Get-MacVendor -mac $cleanMAC
                $row.Cells["Description"].Value = $newDesc
                [System.Windows.Forms.MessageBox]::Show("Reservation successfully updated across $successes server(s)!`n`n$statusLog", "Update Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            } else {
                [System.Windows.Forms.MessageBox]::Show("Failed to update reservation on any server target:`n`n$statusLog", "Update Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
        $editForm.Dispose()
    }.GetNewClosure())

    $null = $dataGridView.ContextMenuStrip.Items.Add($miEdit)

    $miOpenHttp = New-Object System.Windows.Forms.ToolStripMenuItem "Open Web GUI (HTTP)"
    $miOpenHttp.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $miOpenHttp.Add_Click({
        if (-not $dataGridView.CurrentRow) { return }
        $targetIP = $dataGridView.CurrentRow.Cells["IPAddress"].Value.ToString()
        if (-not [string]::IsNullOrWhiteSpace($targetIP) -and $targetIP -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            Launch-Browser -url "http://$targetIP"
        }
    }.GetNewClosure())

    $miOpenHttps = New-Object System.Windows.Forms.ToolStripMenuItem "Open Web GUI (HTTPS)"
    $miOpenHttps.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $miOpenHttps.Add_Click({
        if (-not $dataGridView.CurrentRow) { return }
        $targetIP = $dataGridView.CurrentRow.Cells["IPAddress"].Value.ToString()
        if (-not [string]::IsNullOrWhiteSpace($targetIP) -and $targetIP -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            Launch-Browser -url "https://$targetIP"
        }
    }.GetNewClosure())

    $null = $dataGridView.ContextMenuStrip.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $null = $dataGridView.ContextMenuStrip.Items.Add($miOpenHttp)
    $null = $dataGridView.ContextMenuStrip.Items.Add($miOpenHttps)

    foreach ($row in ($RecordsArray)) {
        $dataRow = $dataTable.NewRow()
        $dataRow["Type"]       = $row.Type
        $dataRow["ScopeId"]    = $row.ScopeId
        $dataRow["ScopeName"]  = $row.ScopeName
        $dataRow["CIDR"]       = $row.CIDR
        $dataRow["SubnetMask"] = $row.SubnetMask
        $dataRow["Server"]     = $row.Server
        $dataRow["Name"]       = $row.Name
        $dataRow["IPAddress"]  = $row.IPAddress
        $dataRow["MACAddress"] = Format-MacAddress -mac $row.MACAddress
        $dataRow["MACAddress_Raw"] = ($row.MACAddress -replace '[^a-fA-F0-9]', '').ToUpper()
        $dataRow["MACVendor"]  = $row.MACVendor
        $dataRow["Description"]= $row.Description
        $dataRow["PingStatus"] = if ($row.PingStatus) { $row.PingStatus } else { "Untested" }

        if ($row.IPAddress -match "^(\d+)\.(\d+)\.(\d+)\.(\d+)$") {
            $dataRow["IPAddress_Sort"] = "{0:D3}.{1:D3}.{2:D3}.{3:D3}" -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4]
        } else { $dataRow["IPAddress_Sort"] = $row.IPAddress }

        if ($row.SubnetMask -match "^(\d+)\.(\d+)\.(\d+)\.(\d+)$") {
            $dataRow["SubnetMask_Sort"] = "{0:D3}.{1:D3}.{2:D3}.{3:D3}" -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4]
        } else { $dataRow["SubnetMask_Sort"] = $row.SubnetMask }

        if ($row.ScopeId -match "^(\d+)\.(\d+)\.(\d+)\.(\d+)$") {
            $dataRow["ScopeId_Sort"] = "{0:D3}.{1:D3}.{2:D3}.{3:D3}" -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4]
        } else { $dataRow["ScopeId_Sort"] = $row.ScopeId }

        $dataTable.Rows.Add($dataRow)
    }
    $dataGridView.DataSource = $dataTable
    $gridForm.Controls.Add($dataGridView)

    $gridForm.Add_Shown({
        
        $hiddenCols = @("IPAddress_Sort", "SubnetMask_Sort", "ScopeId_Sort", "MACAddress_Raw")
        foreach ($c in ($hiddenCols)) {
            if ($dataGridView.Columns.Contains($c)) {
                $dataGridView.Columns[$c].Visible = $false
            }
        }

        $progCols = @("IPAddress", "SubnetMask", "ScopeId")
        foreach ($c in ($progCols)) {
            if ($dataGridView.Columns.Contains($c)) {
                $dataGridView.Columns[$c].SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::Programmatic
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($script:SavedColumnOrder)) {
            $colNames = $script:SavedColumnOrder -split ","
            $idx = 0
            foreach ($cName in ($colNames)) {
                if ($dataGridView.Columns.Contains($cName)) {
                    $dataGridView.Columns[$cName].DisplayIndex = $idx
                    $idx++
                }
            }
        }

        if ($LiveLoadBlock) {
            $gridForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            & $LiveLoadBlock $dataTable $gridForm
        }
    }.GetNewClosure())

    $dataGridView.Add_ColumnHeaderMouseClick({
        param($sender, $e)
        $clickedCol = $sender.Columns[$e.ColumnIndex]
        if ($clickedCol.SortMode -eq [System.Windows.Forms.DataGridViewColumnSortMode]::Programmatic) {
            $sortCol = $clickedCol.Name + "_Sort"
            
            if ($clickedCol.HeaderCell.SortGlyphDirection -eq [System.Windows.Forms.SortOrder]::Ascending) {
                $newSort = "DESC"
                $newGlyph = [System.Windows.Forms.SortOrder]::Descending
            } else {
                $newSort = "ASC"
                $newGlyph = [System.Windows.Forms.SortOrder]::Ascending
            }
            
            foreach ($c in ($sender.Columns)) { $c.HeaderCell.SortGlyphDirection = [System.Windows.Forms.SortOrder]::None }
            $dataTable.DefaultView.Sort = "$sortCol $newSort"
            $clickedCol.HeaderCell.SortGlyphDirection = $newGlyph
        }
    }.GetNewClosure())

    $gridForm.Add_FormClosing({
        $script:CancelLoad = $true
        if ($dataGridView.Columns.Count -gt 0) {
            $orderedCols = $dataGridView.Columns | Sort-Object DisplayIndex | Select-Object -ExpandProperty Name
            $script:SavedColumnOrder = ($orderedCols | Where-Object { $_ -notmatch "_Sort" }) -join ","
            Save-Settings
        }
    }.GetNewClosure())

    $btnExportCsv.Add_Click({
        $btnExportCsv.Enabled = $false
        try {
            if ($dataTable.DefaultView.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("There are no records in the current view to export.", "Export Empty", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                return
            }

            $sfd = New-Object System.Windows.Forms.SaveFileDialog
            $sfd.Filter = "CSV File (*.csv)|*.csv|All Files (*.*)|*.*"
            $sfd.Title = "Export DHCP Records to CSV"
            $cleanTitle = ($TitleText -replace '[^a-zA-Z0-9_-]', '_').Trim('_')
            $sfd.FileName = "$cleanTitle.csv"

            $gridForm.TopMost = $false
            $dialogRes = $sfd.ShowDialog($gridForm)
            $gridForm.TopMost = $true

            if ($dialogRes -eq [System.Windows.Forms.DialogResult]::OK -and -not [string]::IsNullOrWhiteSpace($sfd.FileName)) {
                try {
                    $exportTable = $dataTable.DefaultView.ToTable()
                    if ($exportTable.Columns.Contains("IPAddress_Sort")) { $exportTable.Columns.Remove("IPAddress_Sort") }
                    if ($exportTable.Columns.Contains("SubnetMask_Sort")) { $exportTable.Columns.Remove("SubnetMask_Sort") }
                    if ($exportTable.Columns.Contains("ScopeId_Sort")) { $exportTable.Columns.Remove("ScopeId_Sort") }
                    if ($exportTable.Columns.Contains("MACAddress_Raw")) { $exportTable.Columns.Remove("MACAddress_Raw") }
                    $exportTable | Export-Csv -Path $sfd.FileName -NoTypeInformation -Encoding UTF8
                    [System.Windows.Forms.MessageBox]::Show("Exported $($exportTable.Rows.Count) row(s) successfully to:`n`n$($sfd.FileName)", "Export Successful", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to export to CSV:`n`n$($_.Exception.Message)", "Export Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
        } finally {
            $btnExportCsv.Enabled = $true
        }
    })

    $script:CancelPing = $false

    $btnStopPing.Add_Click({
        $script:CancelPing = $true
        $btnStopPing.Enabled = $false
        $btnStopPing.Text = "Stopping..."
    })

    $ExecuteConcurrentPing = {
        param($targetRows)

        $script:CancelPing = $false
        $btnStopPing.Enabled = $true
        $btnStopPing.Text = "Stop Ping"
        $btnPingSelected.Enabled = $false
        $btnPingAll.Enabled = $false

        $tasks = [System.Collections.Generic.List[PSCustomObject]]::new()

        foreach ($row in ($targetRows)) {
            if ($script:CancelPing) { break }

            $ipStr = $row.Cells["IPAddress"].Value
            if (-not [string]::IsNullOrWhiteSpace($ipStr) -and $ipStr -ne "—") {
                $row.Cells["PingStatus"].Value = "Pinging..."
                $row.Cells["PingStatus"].Style.ForeColor = [System.Drawing.Color]::Black

                try {
                    $p = New-Object System.Net.NetworkInformation.Ping
                    $task = $p.SendPingAsync($ipStr, 750)
                    $tasks.Add([PSCustomObject]@{
                        Row  = $row
                        Task = $task
                        Ping = $p
                    })
                } catch {
                    $row.Cells["PingStatus"].Value = "Offline"
                    $row.Cells["PingStatus"].Style.ForeColor = [System.Drawing.Color]::Red
                }
            }
        }

        while ($tasks.Count -gt 0) {
            if ($script:CancelPing) {
                foreach ($item in ($tasks)) {
                    if (-not $item.Task.IsCompleted) {
                        $item.Row.Cells["PingStatus"].Value = "Stopped"
                        $item.Row.Cells["PingStatus"].Style.ForeColor = [System.Drawing.Color]::Gray
                    }
                    try { $item.Ping.Dispose() } catch {}
                }
                $tasks.Clear()
                break
            }

            $completedList = @($tasks | Where-Object { $_.Task.IsCompleted })

            foreach ($item in ($completedList)) {
                try {
                    if ($item.Task.IsFaulted -or $item.Task.IsCanceled) {
                        $item.Row.Cells["PingStatus"].Value = "Offline"
                        $item.Row.Cells["PingStatus"].Style.ForeColor = [System.Drawing.Color]::Red
                    } else {
                        $reply = $item.Task.Result
                        if ($reply.Status -eq 'Success') {
                            $item.Row.Cells["PingStatus"].Value = "Online ($($reply.RoundtripTime) ms)"
                            $item.Row.Cells["PingStatus"].Style.ForeColor = [System.Drawing.Color]::DarkGreen
                            $item.Row.Cells["PingStatus"].Style.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
                        } else {
                            $item.Row.Cells["PingStatus"].Value = "Offline"
                            $item.Row.Cells["PingStatus"].Style.ForeColor = [System.Drawing.Color]::Red
                        }
                    }
                } catch {
                    $item.Row.Cells["PingStatus"].Value = "Offline"
                    $item.Row.Cells["PingStatus"].Style.ForeColor = [System.Drawing.Color]::Red
                } finally {
                    try { $item.Ping.Dispose() } catch {}
                }
                [void]$tasks.Remove($item)
            }

            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 15
        }

        $btnStopPing.Enabled = $false
        $btnStopPing.Text = "Stop Ping"
        $btnPingSelected.Enabled = $true
        $btnPingAll.Enabled = $true
    }

    $btnPingSelected.Add_Click({
        if ($dataGridView.SelectedRows.Count -eq 0) {
            $null = [System.Windows.Forms.MessageBox]::Show("Please select at least one row in the grid table to ping.", "Selection Required")
            return
        }
        & $ExecuteConcurrentPing -targetRows $dataGridView.SelectedRows
    })

    $btnPingAll.Add_Click({
        & $ExecuteConcurrentPing -targetRows $dataGridView.Rows
    })

    [System.Collections.ArrayList]$gridFilters = New-Object System.Collections.ArrayList

    $UpdateCompoundFilter = {
        $subFilters = New-Object System.Collections.ArrayList

        $globalText = $txtFilter.Text -replace "'", "''"
        if (-not [string]::IsNullOrWhiteSpace($globalText)) {
            $macGlobal = $globalText -replace '[^a-zA-Z0-9]', ''
            $macGlobalCondition = ""
            if ($macGlobal.Length -gt 0) {
                $macGlobalCondition = " OR MACAddress_Raw LIKE '*$macGlobal*'"
            }
            $null = $subFilters.Add("(Type LIKE '*$globalText*' OR ScopeId LIKE '*$globalText*' OR ScopeName LIKE '*$globalText*' OR CIDR LIKE '*$globalText*' OR SubnetMask LIKE '*$globalText*' OR Server LIKE '*$globalText*' OR Name LIKE '*$globalText*' OR IPAddress LIKE '*$globalText*' OR MACAddress LIKE '*$globalText*' OR MACVendor LIKE '*$globalText*' OR Description LIKE '*$globalText*' OR PingStatus LIKE '*$globalText*'$macGlobalCondition)")
        }

        $finalFilter = ""
        if ($subFilters.Count -gt 0) { $finalFilter = $subFilters[0] }

        foreach ($filterRow in ($gridFilters)) {
            $col = $filterRow.Column
            $op = $filterRow.OpCombo.SelectedItem.ToString()
            $logic = $filterRow.LogicCombo.SelectedItem.ToString()
            $rawText = $filterRow.TextBox.Text -replace "'", "''"

            if ([string]::IsNullOrWhiteSpace($rawText)) { continue }

            $targetCol = $col
            if ($col -eq "MACAddress") { $targetCol = "MACAddress_Raw" }

            $vals = $rawText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
            if ($vals.Count -eq 0) { continue }

            $valConditions = @()
            foreach ($v in ($vals)) {
                $cleanV = $v
                if ($col -eq "MACAddress") { $cleanV = $v -replace '[^a-zA-Z0-9]', '' }
                
                switch ($op) {
                    "Contains"            { $valConditions += "$targetCol LIKE '*$cleanV*'" }
                    "Does not contain"    { $valConditions += "$targetCol NOT LIKE '*$cleanV*'" }
                    "Begins with"         { $valConditions += "$targetCol LIKE '$cleanV*'" }
                    "Does not begin with" { $valConditions += "$targetCol NOT LIKE '$cleanV*'" }
                    "Ends with"           { $valConditions += "$targetCol LIKE '*$cleanV'" }
                    "Does not end with"   { $valConditions += "$targetCol NOT LIKE '*$cleanV'" }
                    "Equals"              { $valConditions += "$targetCol = '$cleanV'" }
                    "Does not equal"      { $valConditions += "$targetCol <> '$cleanV'" }
                }
            }

            $groupFilter = "(" + ($valConditions -join " OR ") + ")"

            if ($finalFilter -eq "") {
                $finalFilter = $groupFilter
            } else {
                $finalFilter = "$finalFilter $logic $groupFilter"
            }
        }
        
        $dataTable.DefaultView.RowFilter = $finalFilter
    }

    $btnClearAll.Add_Click({
        $pnlCriteria.Controls.Clear()
        $gridFilters.Clear()
        $txtFilter.Clear()
        & $UpdateCompoundFilter
    })

    $txtFilter.Add_TextChanged($UpdateCompoundFilter)

    $cmbCriteria.Add_SelectedIndexChanged({
        if ($cmbCriteria.SelectedIndex -le 0) { return } 
        $colName = $cmbCriteria.SelectedItem.ToString()
        $cmbCriteria.SelectedIndex = 0 

        $rowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
        $rowPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
        $rowPanel.Size = New-Object System.Drawing.Size(1000, 36)
        $rowPanel.Margin = New-Object System.Windows.Forms.Padding(5, 2, 5, 2)
        $rowPanel.BackColor = [System.Drawing.Color]::Transparent

        $cmbLogic = New-Object System.Windows.Forms.ComboBox
        $cmbLogic.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        $null = $cmbLogic.Items.AddRange(@("AND", "OR"))
        $cmbLogic.SelectedIndex = 0
        $cmbLogic.Font = New-Object System.Drawing.Font("Segoe UI", 11)
        $cmbLogic.Size = New-Object System.Drawing.Size(70, 30)
        $cmbLogic.Margin = New-Object System.Windows.Forms.Padding(0, 2, 5, 2)
        if ($gridFilters.Count -eq 0) { $cmbLogic.Visible = $false }

        $lblCol = New-Object System.Windows.Forms.Label
        $lblCol.Text = $colName
        $lblCol.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $lblCol.Size = New-Object System.Drawing.Size(120, 30)
        $lblCol.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        if ($gridFilters.Count -eq 0) { $lblCol.Margin = New-Object System.Windows.Forms.Padding(75, 2, 5, 2) }

        $cmbOp = New-Object System.Windows.Forms.ComboBox
        $cmbOp.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        $null = $cmbOp.Items.AddRange(@("Contains", "Does not contain", "Begins with", "Does not begin with", "Ends with", "Does not end with", "Equals", "Does not equal"))
        $cmbOp.SelectedIndex = 0
        $cmbOp.Font = New-Object System.Drawing.Font("Segoe UI", 11)
        $cmbOp.Size = New-Object System.Drawing.Size(160, 30)

        $rowTextBox = New-Object System.Windows.Forms.TextBox
        $rowTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 11)
        $rowTextBox.Size = New-Object System.Drawing.Size(260, 28)

        $btnDelete = New-Object System.Windows.Forms.Button
        $btnDelete.Text = "X"
        $btnDelete.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $btnDelete.Size = New-Object System.Drawing.Size(30, 28)
        $btnDelete.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnDelete.ForeColor = [System.Drawing.Color]::Red
        $btnDelete.FlatAppearance.BorderSize = 0

        $rowPanel.Controls.Add($cmbLogic)
        $rowPanel.Controls.Add($lblCol)
        $rowPanel.Controls.Add($cmbOp)
        $rowPanel.Controls.Add($rowTextBox)
        $rowPanel.Controls.Add($btnDelete)
        $pnlCriteria.Controls.Add($rowPanel)

        $filterToken = [PSCustomObject]@{ Column = $colName; TextBox = $rowTextBox; LogicCombo = $cmbLogic; OpCombo = $cmbOp; Panel = $rowPanel }
        $null = $gridFilters.Add($filterToken)

        $rowTextBox.Add_TextChanged($UpdateCompoundFilter)
        $cmbLogic.Add_SelectedIndexChanged($UpdateCompoundFilter)
        $cmbOp.Add_SelectedIndexChanged($UpdateCompoundFilter)

        $btnDelete.Add_Click({
            $parentRow = $this.Parent
            $pnlCriteria.Controls.Remove($parentRow)
            $targetToken = $gridFilters | Where-Object { $_.Panel -ne $parentRow }
            $gridFilters.Clear()
            
            $idx = 0
            if ($targetToken) { 
                foreach ($tok in ($targetToken)) { 
                    if ($idx -eq 0) {
                        $tok.LogicCombo.Visible = $false
                        $tok.Panel.Controls[1].Margin = New-Object System.Windows.Forms.Padding(75, 2, 5, 2)
                    }
                    $null = $gridFilters.Add($tok) 
                    $idx++
                } 
            }
            $parentRow.Dispose() 
            & $UpdateCompoundFilter
        })

        $rowTextBox.Focus()
        & $UpdateCompoundFilter
    })
    
    $form.TopMost = $false
    $null = $gridForm.ShowDialog($form)
    $gridForm.Dispose()
    $form.TopMost = $true
}


$btnGlobalSearch.Add_Click({
    $btnGlobalSearch.Enabled = $false
    try {
        if ($script:DhcpServers.Count -eq 0) { 
            $null = [System.Windows.Forms.MessageBox]::Show("No target database nodes are currently available. Please check the Settings menu.", "Process Blocked", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $script:CancelLoad = $false

        $LiveLoadBlock = {
            param($dt, $guiForm)
            
            $originalTitle = "DHCP Omnidirectional Global Search — All Active Network Scopes"
            $guiForm.Text = "$originalTitle (Starting background discovery...)"

            $sharedQueue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
            $sharedStatus = [System.Collections.Hashtable]::Synchronized(@{ Status = "Starting..."; IsDone = $false })

            $ps = [powershell]::Create()
            $null = $ps.AddScript({
                param($servers, $ouiCache, $queue, $statusObj)
                
                Import-Module DhcpServer -ErrorAction SilentlyContinue

                $GetMacVendor = {
                    param([string]$mac)
                    if ([string]::IsNullOrWhiteSpace($mac) -or $mac -eq "—") { return "—" }
                    
                    $cleanMac = $mac -replace '[^a-fA-F0-9]', ''
                    if ($cleanMac.Length -eq 14) { $cleanMac = $cleanMac.Substring(2) }
                    
                    if ($cleanMac.Length -ge 9) {
                        $ouiPrefix9 = $cleanMac.Substring(0,9).ToUpper()
                        if ($ouiCache.ContainsKey($ouiPrefix9)) { return $ouiCache[$ouiPrefix9] }
                    }
                    
                    if ($cleanMac.Length -ge 7) {
                        $ouiPrefix7 = $cleanMac.Substring(0,7).ToUpper()
                        if ($ouiCache.ContainsKey($ouiPrefix7)) { return $ouiCache[$ouiPrefix7] }
                    }
                    
                    if ($cleanMac.Length -ge 6) {
                        $ouiPrefix6 = $cleanMac.Substring(0,6).ToUpper()
                        if ($ouiCache.ContainsKey($ouiPrefix6)) { return $ouiCache[$ouiPrefix6] }
                    }

                    return "Unknown"
                }

                $GetCidr = {
                    param($maskStr)
                    try {
                        $bytes = [System.Net.IPAddress]::Parse($maskStr).GetAddressBytes()
                        $bitLength = 0
                        foreach ($b in ($bytes)) { $bitLength += [System.Convert]::ToString($b, 2).Replace('0', '').Length }
                        return "/$bitLength"
                    } catch { return "" }
                }

                foreach ($server in ($servers)) {
                    try {
                        $statusObj.Status = "Scanning Server: $server (Fetching Scopes...)"
                        $serverScopes = Get-DhcpServerv4Scope -ComputerName ($server) -ErrorAction Stop
                        if (-not $serverScopes) { continue }
                        
                        $scopeMap = @{}
                        foreach ($s in ($serverScopes)) {
                            $cidrVal = & $GetCidr -maskStr $s.SubnetMask
                            $scopeMap[$s.ScopeId.ToString()] = @{ SubnetMask = $s.SubnetMask; CIDR = $cidrVal; ScopeName = $s.Name }
                        }

                        $ipTracker = New-Object System.Collections.Generic.HashSet[string]
                        $scopeCounter = 0
                        $totalScopes = $serverScopes.Count

                        foreach ($s in ($serverScopes)) {
                            $scopeCounter++
                            $statusObj.Status = "Scanning Server: $server (Scope $scopeCounter of $totalScopes)..."
                            
                            $scopeIdStr = $s.ScopeId.ToString()
                            $mapInfo = $scopeMap[$scopeIdStr]
                            if (-not $mapInfo) { continue }

                            $res = Get-DhcpServerv4Reservation -ComputerName ($server) -ScopeId ($s.ScopeId) -ErrorAction SilentlyContinue
                            if ($res) {
                                foreach ($item in ($res)) {
                                    $ipStr = $item.IPAddress.ToString()
                                    $vendor = & $GetMacVendor -mac $item.ClientId
                                    
                                    $queue.Enqueue([PSCustomObject]@{
                                        Type        = "Reservation"
                                        ScopeId     = $scopeIdStr
                                        ScopeName   = $mapInfo.ScopeName
                                        CIDR        = $mapInfo.CIDR
                                        SubnetMask  = $mapInfo.SubnetMask
                                        Server      = $server
                                        Name        = $item.Name
                                        IPAddress   = $ipStr
                                        MACAddress  = $item.ClientId
                                        MACVendor   = $vendor
                                        Description = $item.Description
                                        PingStatus  = "Untested"
                                    })
                                    $null = $ipTracker.Add($ipStr)
                                }
                            }

                            $leases = Get-DhcpServerv4Lease -ComputerName ($server) -ScopeId ($s.ScopeId) -ErrorAction SilentlyContinue
                            if ($leases) {
                                foreach ($lease in ($leases)) {
                                    $ipStr = $lease.IPAddress.ToString()
                                    if ($ipTracker.Contains($ipStr)) { continue }

                                    $entryType = if ($lease.AddressState -match "Reservation") { "Reservation" } else { "Lease" }
                                    $vendor = & $GetMacVendor -mac $lease.ClientId
                                    
                                    $queue.Enqueue([PSCustomObject]@{
                                        Type        = $entryType
                                        ScopeId     = $scopeIdStr
                                        ScopeName   = $mapInfo.ScopeName
                                        CIDR        = $mapInfo.CIDR
                                        SubnetMask  = $mapInfo.SubnetMask
                                        Server      = $server
                                        Name        = if ($lease.HostName) { $lease.HostName } else { "—" }
                                        IPAddress   = $ipStr
                                        MACAddress  = $lease.ClientId
                                        MACVendor   = $vendor
                                        Description = if ($lease.Description) { $lease.Description } else { "State: $($lease.AddressState)" }
                                        PingStatus  = "Untested"
                                    })
                                    $null = $ipTracker.Add($ipStr)
                                }
                            }
                        }
                    } catch {}
                }
                $statusObj.IsDone = $true
            })

            $null = $ps.AddArgument($script:DhcpServers)
            $null = $ps.AddArgument($script:OUICache)
            $null = $ps.AddArgument($sharedQueue)
            $null = $ps.AddArgument($sharedStatus)

            $asyncResult = $ps.BeginInvoke()

            $ProcessItem = {
                param($item, $dt)
                $r = $dt.NewRow()
                $r["Type"]       = $item.Type
                $r["ScopeId"]    = $item.ScopeId
                $r["ScopeName"]  = $item.ScopeName
                $r["CIDR"]       = $item.CIDR
                $r["SubnetMask"] = $item.SubnetMask
                $r["Server"]     = $item.Server
                $r["Name"]       = $item.Name
                $r["IPAddress"]  = $item.IPAddress
                $r["MACAddress"] = Format-MacAddress -mac $item.MACAddress
                $r["MACAddress_Raw"] = ($item.MACAddress -replace '[^a-fA-F0-9]', '').ToUpper()
                $r["MACVendor"]  = $item.MACVendor
                $r["Description"]= $item.Description
                $r["PingStatus"] = $item.PingStatus

                if ($item.IPAddress -match "^(\d+)\.(\d+)\.(\d+)\.(\d+)$") {
                    $r["IPAddress_Sort"] = "{0:D3}.{1:D3}.{2:D3}.{3:D3}" -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4]
                } else { $r["IPAddress_Sort"] = $item.IPAddress }
        
                if ($item.SubnetMask -match "^(\d+)\.(\d+)\.(\d+)\.(\d+)$") {
                    $r["SubnetMask_Sort"] = "{0:D3}.{1:D3}.{2:D3}.{3:D3}" -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4]
                } else { $r["SubnetMask_Sort"] = $item.SubnetMask }

                if ($item.ScopeId -match "^(\d+)\.(\d+)\.(\d+)\.(\d+)$") {
                    $r["ScopeId_Sort"] = "{0:D3}.{1:D3}.{2:D3}.{3:D3}" -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4]
                } else { $r["ScopeId_Sort"] = $item.ScopeId }

                $dt.Rows.Add($r)
            }

            $timer = New-Object System.Windows.Forms.Timer
            $timer.Interval = 200 
            $timer.Add_Tick({
                if ($script:CancelLoad -or $guiForm.IsDisposed) {
                    $timer.Stop()
                    try { $ps.Stop() } catch {}
                    try { $ps.Dispose() } catch {}
                    $guiForm.Cursor = [System.Windows.Forms.Cursors]::Default
                    if (-not $guiForm.IsDisposed) { $guiForm.Close() }
                    return
                }

                $itemsProcessed = 0
                $dt.BeginLoadData()
                while ($sharedQueue.Count -gt 0 -and $itemsProcessed -lt 200) {
                    $item = $sharedQueue.Dequeue()
                    & $ProcessItem $item $dt
                    $itemsProcessed++
                }
                $dt.EndLoadData()

                if (-not $sharedStatus.IsDone) {
                    $guiForm.Text = "$originalTitle — $($sharedStatus.Status)"
                } else {
                    $dt.BeginLoadData()
                    while ($sharedQueue.Count -gt 0) {
                        $item = $sharedQueue.Dequeue()
                        & $ProcessItem $item $dt
                    }
                    $dt.EndLoadData()

                    $guiForm.Text = "$originalTitle (Loaded $($dt.Rows.Count) Records)"
                    $timer.Stop()
                    try { $ps.Dispose() } catch {}
                    $guiForm.Cursor = [System.Windows.Forms.Cursors]::Default
                }
            }.GetNewClosure())

            $timer.Start()
        }

        Launch-DisplayGrid -TitleText "DHCP Omnidirectional Global Search — Initializing..." -RecordsArray @() -TargetScopeId $null -LiveLoadBlock $LiveLoadBlock
    } finally {
        $btnGlobalSearch.Enabled = $true
    }
})


$btnViewScope.Add_Click({
    $btnViewScope.Enabled = $false
    try {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

        if ($script:DhcpServers.Count -eq 0) { 
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            $null = [System.Windows.Forms.MessageBox]::Show("No target database nodes are currently available. Please check the Settings menu.", "Process Blocked", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $allScopesList = @()
        foreach ($server in ($script:DhcpServers)) {
            try { 
                $srvScopes = Get-DhcpServerv4Scope -ComputerName ($server) -ErrorAction Stop 
                if ($srvScopes) {
                    foreach ($s in ($srvScopes)) {
                        $allScopesList += [PSCustomObject]@{
                            Server      = $server
                            ScopeId     = $s.ScopeId.ToString()
                            Name        = $s.Name
                            SubnetMask  = $s.SubnetMask.ToString()
                            State       = $s.State
                            Description = $s.Description
                        }
                    }
                }
            } catch {}
        }

        if ($allScopesList.Count -eq 0) {
            Start-Sleep -Milliseconds 1500
            foreach ($server in ($script:DhcpServers)) {
                try { 
                    $srvScopes = Get-DhcpServerv4Scope -ComputerName ($server) -ErrorAction Stop 
                    if ($srvScopes) {
                        foreach ($s in ($srvScopes)) {
                            $allScopesList += [PSCustomObject]@{
                                Server      = $server
                                ScopeId     = $s.ScopeId.ToString()
                                Name        = $s.Name
                                SubnetMask  = $s.SubnetMask.ToString()
                                State       = $s.State
                                Description = $s.Description
                            }
                        }
                    }
                } catch {}
            }
        }

        $form.Cursor = [System.Windows.Forms.Cursors]::Default

        if ($allScopesList.Count -eq 0) {
            $null = [System.Windows.Forms.MessageBox]::Show("Could not fetch the scope browse index tree. Defined inventory nodes are offline.", "Connection Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        $browseForm = New-Object System.Windows.Forms.Form
        $browseForm.Text = "Browse and Select DHCP Scope"
        $browseForm.Size = New-Object System.Drawing.Size(950, 500) 
        $browseForm.StartPosition = "CenterParent"
        $browseForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
        $browseForm.MaximizeBox = $true
        $browseForm.MinimizeBox = $false

        $lblBrowseFilter = New-Object System.Windows.Forms.Label
        $lblBrowseFilter.Text = "Search Scopes:"
        $lblBrowseFilter.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $lblBrowseFilter.Location = New-Object System.Drawing.Point(20, 22)
        $lblBrowseFilter.Size = New-Object System.Drawing.Size(140, 30)
        $browseForm.Controls.Add($lblBrowseFilter)

        $txtBrowseFilter = New-Object System.Windows.Forms.TextBox
        $txtBrowseFilter.Font = $gridFont
        $txtBrowseFilter.Location = New-Object System.Drawing.Point(165, 17)
        $txtBrowseFilter.Size = New-Object System.Drawing.Size(650, 35)
        $txtBrowseFilter.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
        $browseForm.Controls.Add($txtBrowseFilter)

        $browseGrid = New-Object System.Windows.Forms.DataGridView
        $browseGrid.Location = New-Object System.Drawing.Point(20, 70)
        $browseGrid.Size = New-Object System.Drawing.Size(895, 300)
        $browseGrid.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
        $browseGrid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
        $browseGrid.ReadOnly = $true
        $browseGrid.AllowUserToAddRows = $false
        $browseGrid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
        $browseGrid.RowTemplate.Height = 28
        $browseGrid.Font = $gridFont
        $browseGrid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $browseGrid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
        Enable-GridCopy -grid $browseGrid
        $browseForm.Controls.Add($browseGrid)

        $scopeTable = New-Object System.Data.DataTable
        $null = $scopeTable.Columns.Add("Server")
        $null = $scopeTable.Columns.Add("ScopeId")
        $null = $scopeTable.Columns.Add("Name")
        $null = $scopeTable.Columns.Add("CIDR") 
        $null = $scopeTable.Columns.Add("SubnetMask")
        $null = $scopeTable.Columns.Add("State")
        $null = $scopeTable.Columns.Add("Description")

        foreach ($s in ($allScopesList)) {
            $r = $scopeTable.NewRow()
            $r["Server"]     = $s.Server
            $r["ScopeId"]    = $s.ScopeId
            $r["Name"]       = $s.Name
            $r["CIDR"]       = Get-CidrNotation -maskStr $s.SubnetMask 
            $r["SubnetMask"] = $s.SubnetMask
            $r["State"]      = $s.State
            $r["Description"] = $s.Description
            $scopeTable.Rows.Add($r)
        }
        $browseGrid.DataSource = $scopeTable

        $serverSnapshot = @($script:DhcpServers)

        $miEditScope = New-Object System.Windows.Forms.ToolStripMenuItem "Edit Scope Name / Description"
        $miEditScope.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $miEditScope.Add_Click({
            if (-not $browseGrid.CurrentRow) { return }
            $row = $browseGrid.CurrentRow
            
            $targetScopeId = $row.Cells["ScopeId"].Value.ToString()
            $currName      = $row.Cells["Name"].Value.ToString()
            $currDesc      = $row.Cells["Description"].Value.ToString()
            $currServer    = $row.Cells["Server"].Value.ToString()

            $editScopeForm = New-Object System.Windows.Forms.Form
            $editScopeForm.Text = "Edit Scope Metadata — $targetScopeId"
            $editScopeForm.Size = New-Object System.Drawing.Size(550, 420)
            $editScopeForm.StartPosition = "CenterParent"
            $editScopeForm.FormBorderStyle = "FixedDialog"
            $editScopeForm.MaximizeBox = $false
            $editScopeForm.MinimizeBox = $false
            $editScopeForm.Font = New-Object System.Drawing.Font("Segoe UI", 11)

            $lblScopeName = New-Object System.Windows.Forms.Label
            $lblScopeName.Text = "Scope Name:"
            $lblScopeName.Location = New-Object System.Drawing.Point(20, 35)
            $lblScopeName.Size = New-Object System.Drawing.Size(160, 28)
            $editScopeForm.Controls.Add($lblScopeName)

            $txtScopeName = New-Object System.Windows.Forms.TextBox
            $txtScopeName.Text = $currName
            $txtScopeName.Location = New-Object System.Drawing.Point(190, 30)
            $txtScopeName.Size = New-Object System.Drawing.Size(320, 32)
            $editScopeForm.Controls.Add($txtScopeName)

            $lblScopeDesc = New-Object System.Windows.Forms.Label
            $lblScopeDesc.Text = "Description:"
            $lblScopeDesc.Location = New-Object System.Drawing.Point(20, 85)
            $lblScopeDesc.Size = New-Object System.Drawing.Size(160, 28)
            $editScopeForm.Controls.Add($lblScopeDesc)

            $txtScopeDesc = New-Object System.Windows.Forms.TextBox
            $txtScopeDesc.Text = $currDesc
            $txtScopeDesc.Location = New-Object System.Drawing.Point(190, 80)
            $txtScopeDesc.Size = New-Object System.Drawing.Size(320, 32)
            $editScopeForm.Controls.Add($txtScopeDesc)

            $lblSync = New-Object System.Windows.Forms.Label
            $lblSync.Text = "Deployment Target:"
            $lblSync.Location = New-Object System.Drawing.Point(20, 140)
            $lblSync.Size = New-Object System.Drawing.Size(500, 28)
            $lblSync.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
            $editScopeForm.Controls.Add($lblSync)

            $rbSyncAll = New-Object System.Windows.Forms.RadioButton
            $rbSyncAll.Text = "Synchronize across ALL servers hosting this scope"
            $rbSyncAll.Location = New-Object System.Drawing.Point(30, 170)
            $rbSyncAll.Size = New-Object System.Drawing.Size(480, 28)
            $rbSyncAll.Checked = $true
            $editScopeForm.Controls.Add($rbSyncAll)

            $rbSyncOne = New-Object System.Windows.Forms.RadioButton
            $rbSyncOne.Text = "Apply strictly to $currServer"
            $rbSyncOne.Location = New-Object System.Drawing.Point(30, 200)
            $rbSyncOne.Size = New-Object System.Drawing.Size(480, 28)
            $editScopeForm.Controls.Add($rbSyncOne)

            $btnScopeSave = New-Object System.Windows.Forms.Button
            $btnScopeSave.Text = "Save Changes"
            $btnScopeSave.Location = New-Object System.Drawing.Point(190, 260)
            $btnScopeSave.Size = New-Object System.Drawing.Size(200, 40)
            $btnScopeSave.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
            $btnScopeSave.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $editScopeForm.Controls.Add($btnScopeSave)
            
            $btnScopeCancel = New-Object System.Windows.Forms.Button
            $btnScopeCancel.Text = "Cancel"
            $btnScopeCancel.Location = New-Object System.Drawing.Point(400, 260)
            $btnScopeCancel.Size = New-Object System.Drawing.Size(110, 40)
            $btnScopeCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $editScopeForm.Controls.Add($btnScopeCancel)

            $editScopeForm.AcceptButton = $btnScopeSave
            $editScopeForm.CancelButton = $btnScopeCancel

            $browseForm.TopMost = $false
            $dlgRes = $editScopeForm.ShowDialog($browseForm)
            $browseForm.TopMost = $true

            if ($dlgRes -eq [System.Windows.Forms.DialogResult]::OK) {
                $newName = $txtScopeName.Text.Trim()
                $newDesc = $txtScopeDesc.Text.Trim()
                
                $targets = @()
                if ($rbSyncAll.Checked) {
                    foreach ($node in ($serverSnapshot)) { 
                        if (-not [string]::IsNullOrWhiteSpace($node)) { $targets += $node }
                    }
                } else {
                    $targets += $currServer
                }
                
                $statusLog = ""
                $successes = 0
                $browseForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
                foreach ($srv in ($targets)) {
                    if ([string]::IsNullOrWhiteSpace($srv)) { continue }
                    try {
                        Set-DhcpServerv4Scope -ComputerName ($srv) -ScopeId ($targetScopeId) -Name ($newName) -Description ($newDesc) -ErrorAction Stop
                        $successes++
                        $statusLog += "• $srv : Success`n"
                    } catch {
                        $statusLog += "• $srv : FAILED ($($_.Exception.Message))`n"
                    }
                }
                $browseForm.Cursor = [System.Windows.Forms.Cursors]::Default
                
                if ($successes -gt 0) {
                    $scopeTable.BeginLoadData()
                    foreach ($r in ($scopeTable.Rows)) {
                        if ($r["ScopeId"] -eq $targetScopeId -and $targets -contains $r["Server"]) {
                            $r["Name"] = $newName
                            $r["Description"] = $newDesc
                        }
                    }
                    $scopeTable.EndLoadData()
                    [System.Windows.Forms.MessageBox]::Show("Scope metadata successfully updated across $successes server(s)!`n`n$statusLog", "Update Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                } else {
                    [System.Windows.Forms.MessageBox]::Show("Failed to update scope metadata:`n`n$statusLog", "Update Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
            $editScopeForm.Dispose()
        }.GetNewClosure())

        $null = $browseGrid.ContextMenuStrip.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
        $null = $browseGrid.ContextMenuStrip.Items.Add($miEditScope)


        $btnSelectScope = New-Object System.Windows.Forms.Button
        $btnSelectScope.Text = "Select"
        $btnSelectScope.Font = $btnFont
        $btnSelectScope.Size = New-Object System.Drawing.Size(120, 40)
        $btnSelectScope.Location = New-Object System.Drawing.Point(675, 395)
        $btnSelectScope.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
        $btnSelectScope.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $browseForm.Controls.Add($btnSelectScope)

        $btnCancelScope = New-Object System.Windows.Forms.Button
        $btnCancelScope.Text = "Cancel"
        $btnCancelScope.Font = $btnFont
        $btnCancelScope.Size = New-Object System.Drawing.Size(120, 40)
        $btnCancelScope.Location = New-Object System.Drawing.Point(795, 395)
        $btnCancelScope.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
        $btnCancelScope.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $browseForm.Controls.Add($btnCancelScope)

        $browseForm.AcceptButton = $btnSelectScope
        $browseForm.CancelButton = $btnCancelScope

        $txtBrowseFilter.Text = ""
        $currentInput = $txtIP.Text.Trim()
        if ($currentInput -match '^(\d{1,3}\.\d{1,3}\.)') { $txtBrowseFilter.Text = $Matches[1] }

        $txtBrowseFilter.Add_TextChanged({
            $cleanTxt = $txtBrowseFilter.Text -replace "'", "''"
            if ([string]::IsNullOrWhiteSpace($cleanTxt)) { $scopeTable.DefaultView.RowFilter = "" } 
            else { $scopeTable.DefaultView.RowFilter = "Server LIKE '*$cleanTxt*' OR ScopeId LIKE '*$cleanTxt*' OR Name LIKE '*$cleanTxt*' OR CIDR LIKE '*$cleanTxt*' OR Description LIKE '*$cleanTxt*'" }
        })

        $browseGrid.Add_CellDoubleClick({
            if ($browseGrid.SelectedRows.Count -gt 0) {
                $browseForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
                $browseForm.Close()
            }
        })

        $form.TopMost = $false
        $browseResult = $browseForm.ShowDialog($form)
        $form.TopMost = $true

        if ($browseResult -eq [System.Windows.Forms.DialogResult]::OK -and $browseGrid.SelectedRows.Count -gt 0) {
            $TargetScope  = $browseGrid.SelectedRows[0].Cells["ScopeId"].Value.ToString()
            $SelectedMask = $browseGrid.SelectedRows[0].Cells["SubnetMask"].Value.ToString()
            $SelectedName = $browseGrid.SelectedRows[0].Cells["Name"].Value.ToString() 
            $SelectedCidr = $browseGrid.SelectedRows[0].Cells["CIDR"].Value.ToString()
        } else {
            $browseForm.Dispose(); return 
        }
        $browseForm.Dispose()

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $ScopeRecords = @()

        $script:CancelLoad = $false

        foreach ($server in ($script:DhcpServers)) {
            $ipTracker = New-Object System.Collections.Generic.HashSet[string]

            try {
                $res = Get-DhcpServerv4Reservation -ComputerName ($server) -ScopeId ($TargetScope) -ErrorAction SilentlyContinue
                if ($res) {
                    foreach ($item in ($res)) {
                        $ipStr = $item.IPAddress.ToString()
                        $vendor = Get-MacVendor -mac $item.ClientId
                        
                        $ScopeRecords += [PSCustomObject]@{
                            Type        = "Reservation"
                            ScopeId     = $TargetScope
                            ScopeName   = $SelectedName
                            CIDR        = $SelectedCidr
                            SubnetMask  = $SelectedMask
                            Server      = $server
                            Name        = $item.Name
                            IPAddress   = $ipStr
                            MACAddress  = $item.ClientId
                            MACVendor   = $vendor
                            Description = $item.Description
                            PingStatus  = "Untested"
                        }
                        $null = $ipTracker.Add($ipStr)
                    }
                }
            } catch {}

            try {
                $leases = Get-DhcpServerv4Lease -ComputerName ($server) -ScopeId ($TargetScope) -ErrorAction SilentlyContinue
                if ($leases) {
                    foreach ($lease in ($leases)) {
                        $ipStr = $lease.IPAddress.ToString()
                        
                        if ($ipTracker.Contains($ipStr)) { continue }

                        $entryType = if ($lease.AddressState -match "Reservation") { "Reservation" } else { "Lease" }
                        $vendor = Get-MacVendor -mac $lease.ClientId
                        
                        $ScopeRecords += [PSCustomObject]@{
                            Type        = $entryType
                            ScopeId     = $TargetScope
                            ScopeName   = $SelectedName
                            CIDR        = $SelectedCidr
                            SubnetMask  = $SelectedMask
                            Server      = $server
                            Name        = if ($lease.HostName) { $lease.HostName } else { "—" }
                            IPAddress   = $ipStr
                            MACAddress  = $lease.ClientId
                            MACVendor   = $vendor
                            Description = if ($lease.Description) { $lease.Description } else { "State: $($lease.AddressState)" }
                            PingStatus  = "Untested"
                        }
                        $null = $ipTracker.Add($ipStr)
                    }
                }
            } catch {}
        }

        $form.Cursor = [System.Windows.Forms.Cursors]::Default

        if ($ScopeRecords.Count -eq 0) {
            $null = [System.Windows.Forms.MessageBox]::Show("No active leases or reservations were found inside scope '$TargetScope'.", "No Records Discovered", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            Launch-DisplayGrid -TitleText "DHCP Scope Overview — Scope ID: $TargetScope ($SelectedName)" -RecordsArray $ScopeRecords -TargetScopeId $TargetScope -LiveLoadBlock $null
        }
    } finally {
        $btnViewScope.Enabled = $true
    }
})

$btnSettings.Add_Click({
    $btnSettings.Enabled = $false
    try {
        $settingsForm = New-Object System.Windows.Forms.Form
        $settingsForm.Text = "DHCP Tool Settings"
        $settingsForm.Size = New-Object System.Drawing.Size(650, 530)
        $settingsForm.StartPosition = "CenterParent"
        $settingsForm.FormBorderStyle = "FixedDialog"
        $settingsForm.MaximizeBox = $false
        $settingsForm.MinimizeBox = $false
        $settingsForm.Font = New-Object System.Drawing.Font("Segoe UI", 12)

        $lblList = New-Object System.Windows.Forms.Label
        $lblList.Text = "Persistent DHCP Server Targets:"
        $lblList.Location = New-Object System.Drawing.Point(20, 20)
        $lblList.Size = New-Object System.Drawing.Size(300, 25)
        $settingsForm.Controls.Add($lblList)

        $listBox = New-Object System.Windows.Forms.ListBox
        $listBox.Location = New-Object System.Drawing.Point(20, 50)
        $listBox.Size = New-Object System.Drawing.Size(320, 320)
        $listBox.SelectionMode = [System.Windows.Forms.SelectionMode]::MultiExtended
        foreach ($srv in ($script:DhcpServers)) { [void]$listBox.Items.Add($srv) }
        $settingsForm.Controls.Add($listBox)

        $lblAdd = New-Object System.Windows.Forms.Label
        $lblAdd.Text = "New Server Name / IP:"
        $lblAdd.Location = New-Object System.Drawing.Point(365, 50)
        $lblAdd.Size = New-Object System.Drawing.Size(240, 25)
        $settingsForm.Controls.Add($lblAdd)

        $txtNewServer = New-Object System.Windows.Forms.TextBox
        $txtNewServer.Location = New-Object System.Drawing.Point(365, 80)
        $txtNewServer.Size = New-Object System.Drawing.Size(240, 32)
        $settingsForm.Controls.Add($txtNewServer)

        $btnAddServer = New-Object System.Windows.Forms.Button
        $btnAddServer.Text = "Add Server"
        $btnAddServer.Location = New-Object System.Drawing.Point(365, 125)
        $btnAddServer.Size = New-Object System.Drawing.Size(240, 35)
        $settingsForm.Controls.Add($btnAddServer)

        $btnRemoveServer = New-Object System.Windows.Forms.Button
        $btnRemoveServer.Text = "Remove Selected"
        $btnRemoveServer.Location = New-Object System.Drawing.Point(365, 175)
        $btnRemoveServer.Size = New-Object System.Drawing.Size(240, 35)
        $btnRemoveServer.ForeColor = [System.Drawing.Color]::DarkRed
        $settingsForm.Controls.Add($btnRemoveServer)

        $lblMacFormat = New-Object System.Windows.Forms.Label
        $lblMacFormat.Text = "Preferred MAC Format:"
        $lblMacFormat.Location = New-Object System.Drawing.Point(365, 220)
        $lblMacFormat.Size = New-Object System.Drawing.Size(240, 25)
        $settingsForm.Controls.Add($lblMacFormat)

        $cmbMacFormat = New-Object System.Windows.Forms.ComboBox
        $cmbMacFormat.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        $null = $cmbMacFormat.Items.AddRange(@("AA:BB:CC:DD:EE:FF", "AA-BB-CC-DD-EE-FF", "AA BB CC DD EE FF", "AABBCC-DDEEFF", "AABBCC:DDEEFF", "AABBCCDDEEFF", "AABB.CCDD.EEFF"))
        $cmbMacFormat.Location = New-Object System.Drawing.Point(365, 250)
        $cmbMacFormat.Size = New-Object System.Drawing.Size(240, 32)
        if ($cmbMacFormat.Items.Contains($script:MacFormat)) {
            $cmbMacFormat.SelectedItem = $script:MacFormat
        } else {
            $cmbMacFormat.SelectedIndex = 0
        }
        $settingsForm.Controls.Add($cmbMacFormat)

        $btnApplySettings = New-Object System.Windows.Forms.Button
        $btnApplySettings.Text = "Save Settings"
        $btnApplySettings.Location = New-Object System.Drawing.Point(365, 305)
        $btnApplySettings.Size = New-Object System.Drawing.Size(240, 42)
        $btnApplySettings.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $settingsForm.Controls.Add($btnApplySettings)

        $btnCancelSettings = New-Object System.Windows.Forms.Button
        $btnCancelSettings.Text = "Cancel"
        $btnCancelSettings.Location = New-Object System.Drawing.Point(365, 355)
        $btnCancelSettings.Size = New-Object System.Drawing.Size(240, 35)
        $btnCancelSettings.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $settingsForm.Controls.Add($btnCancelSettings)
        
        $settingsForm.CancelButton = $btnCancelSettings

        $btnLoadAD = New-Object System.Windows.Forms.Button
        $btnLoadAD.Text = "Auto-Discover AD Servers"
        $btnLoadAD.Location = New-Object System.Drawing.Point(20, 415)
        $btnLoadAD.Size = New-Object System.Drawing.Size(320, 35)
        $settingsForm.Controls.Add($btnLoadAD)

        $btnRestoreDefaults = New-Object System.Windows.Forms.Button
        $btnRestoreDefaults.Text = "Restore Defaults"
        $btnRestoreDefaults.Location = New-Object System.Drawing.Point(365, 415)
        $btnRestoreDefaults.Size = New-Object System.Drawing.Size(240, 35)
        $settingsForm.Controls.Add($btnRestoreDefaults)

        $btnAbout = New-Object System.Windows.Forms.Button
        $btnAbout.Text = "About"
        $btnAbout.Location = New-Object System.Drawing.Point(20, 460)
        $btnAbout.Size = New-Object System.Drawing.Size(585, 35)
        $btnAbout.Add_Click({
            $aboutForm = New-Object System.Windows.Forms.Form
            $aboutForm.Text = "About DHCP Tool"
            $aboutForm.Size = New-Object System.Drawing.Size(600, 500)
            $aboutForm.StartPosition = "CenterParent"
            $aboutForm.FormBorderStyle = "FixedDialog"
            $aboutForm.MaximizeBox = $false
            $aboutForm.MinimizeBox = $false
            $aboutForm.Font = New-Object System.Drawing.Font("Segoe UI", 12)

            $lblTitle = New-Object System.Windows.Forms.Label
            $lblTitle.Text = "DHCP Management Tool"
            $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
            $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
            $lblTitle.Size = New-Object System.Drawing.Size(540, 35)
            $aboutForm.Controls.Add($lblTitle)

            $lblAuthor = New-Object System.Windows.Forms.Label
            $lblAuthor.Text = "Created by Paul Kochie`nVersion 176"
            $lblAuthor.Location = New-Object System.Drawing.Point(20, 60)
            $lblAuthor.Size = New-Object System.Drawing.Size(540, 50)
            $aboutForm.Controls.Add($lblAuthor)

            $txtLog = New-Object System.Windows.Forms.TextBox
            $txtLog.Multiline = $true
            $txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
            $txtLog.ReadOnly = $true
            $txtLog.TabStop = $false 
            $txtLog.Font = New-Object System.Drawing.Font("Consolas", 10)
            $txtLog.Location = New-Object System.Drawing.Point(20, 120)
            $txtLog.Size = New-Object System.Drawing.Size(545, 270)
            
            $logText = @"
# <INSERT_CHANGELOG_HERE>
"@
            $txtLog.Text = $logText
            $txtLog.SelectionStart = 0
            $txtLog.SelectionLength = 0
            $aboutForm.Controls.Add($txtLog)

            $btnCloseAbout = New-Object System.Windows.Forms.Button
            $btnCloseAbout.Text = "Close"
            $btnCloseAbout.Location = New-Object System.Drawing.Point(445, 405)
            $btnCloseAbout.Size = New-Object System.Drawing.Size(120, 35)
            $btnCloseAbout.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $aboutForm.Controls.Add($btnCloseAbout)

            $aboutForm.ActiveControl = $btnCloseAbout
            $aboutForm.CancelButton = $btnCloseAbout

            $settingsForm.TopMost = $false
            $null = $aboutForm.ShowDialog($settingsForm)
            $aboutForm.Dispose()
            $settingsForm.TopMost = $true
        })
        $settingsForm.Controls.Add($btnAbout)

        $btnAddServer.Add_Click({
            $entry = $txtNewServer.Text.Trim().ToUpper()
            if ([string]::IsNullOrWhiteSpace($entry)) { return }
            if ($listBox.Items.Contains($entry)) {
                $null = [System.Windows.Forms.MessageBox]::Show("This server target is already registered.", "Duplicate Intercepted")
                return
            }
            [void]$listBox.Items.Add($entry)
            $txtNewServer.Clear(); $txtNewServer.Focus()
        })

        $btnRemoveServer.Add_Click({
            if ($listBox.SelectedItems.Count -eq 0) { return }
            $itemsToRemove = @($listBox.SelectedItems)
            foreach ($item in ($itemsToRemove)) {
                $listBox.Items.Remove($item)
            }
        })

        $btnLoadAD.Add_Click({
            $settingsForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            $tempList = New-Object System.Collections.ArrayList
            try {
                $dcServers = Get-DhcpServerInDC -ErrorAction Stop
                foreach ($srv in ($dcServers)) {
                    $dnsName = $srv.DnsName.Trim().ToUpper()
                    if ($dnsName -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                        $dnsName = $dnsName.Split('.')[0]
                    }

                    if (-not [string]::IsNullOrEmpty($dnsName) -and -not $tempList.Contains($dnsName)) {
                        $null = $tempList.Add($dnsName)
                    }
                }
            } catch {}
            
            if ($tempList.Count -gt 0) {
                foreach ($s in ($tempList)) {
                    if (-not $listBox.Items.Contains($s)) { $null = $listBox.Items.Add($s) }
                }
                [System.Windows.Forms.MessageBox]::Show("Discovered $($tempList.Count) AD DHCP Servers and added them to the list.", "Discovery Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            } else {
                [System.Windows.Forms.MessageBox]::Show("Could not discover any servers in AD.", "Discovery Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            }
            $settingsForm.Cursor = [System.Windows.Forms.Cursors]::Default
        })

        $btnRestoreDefaults.Add_Click({
            $confirm = [System.Windows.Forms.MessageBox]::Show("This will clear your saved settings, reset your custom column layout, and empty the server list. Continue?", "Confirm Restore", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
                $settingsForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
                Restore-Defaults
                $listBox.Items.Clear()
                foreach ($srv in ($script:DhcpServers)) { [void]$listBox.Items.Add($srv) }
                if ($cmbMacFormat.Items.Contains($script:MacFormat)) { $cmbMacFormat.SelectedItem = $script:MacFormat }
                $settingsForm.Cursor = [System.Windows.Forms.Cursors]::Default
                [System.Windows.Forms.MessageBox]::Show("Settings restored to defaults.", "Restored", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
        })

        $btnApplySettings.Add_Click({
            if ($listBox.Items.Count -eq 0) {
                $null = [System.Windows.Forms.MessageBox]::Show("You must preserve at least one active target server node for this session.", "Validation Failure", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            $script:DhcpServers.Clear()
            foreach ($item in ($listBox.Items)) { $null = $script:DhcpServers.Add($item.ToString()) }
            $script:MacFormat = $cmbMacFormat.SelectedItem.ToString()

            Save-Settings

            $null = [System.Windows.Forms.MessageBox]::Show("DHCP Settings saved successfully!", "Session Synchronized", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $settingsForm.Close()
        })

        $form.TopMost = $false
        $null = $settingsForm.ShowDialog($form)
        $settingsForm.Dispose()
    } finally {
        $btnSettings.Enabled = $true
        $form.TopMost = $true
    }
})

$form.Add_Shown({
    if ($script:IsFirstRun) {
        $btnSettings.PerformClick()
    }
}.GetNewClosure())

$btnAdd.Add_Click({
    $btnAdd.Enabled = $false
    try {
        if ($script:DhcpServers.Count -eq 0) { 
            $null = [System.Windows.Forms.MessageBox]::Show("No target database nodes are currently available. Please check the Settings menu.", "Process Blocked", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $Name   = $txtName.Text.Trim()
        $IP     = $txtIP.Text.Trim()
        $RawMAC = $txtMAC.Text.Trim()
        $Desc   = $txtDesc.Text.Trim()
        $Type   = "Dhcp"

        if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($IP) -or [string]::IsNullOrWhiteSpace($RawMAC)) {
            $null = [System.Windows.Forms.MessageBox]::Show("Please complete the Reservation Name, IP Address, and MAC Address fields.", "Missing Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        if ($IP -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.$') { $IP = $IP + "0" }

        $parsedIP = $null
        if (-not [System.Net.IPAddress]::TryParse($IP, [ref]$parsedIP) -or $parsedIP.AddressFamily -ne 'InterNetwork') {
            $null = [System.Windows.Forms.MessageBox]::Show("The entry '$IP' is not a valid IPv4 format.", "Invalid IP Address", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        $MAC = $RawMAC -replace '[^a-fA-F0-9]', ''
        if ($MAC -notmatch '^[0-9a-fA-F]{12}$') {
            $null = [System.Windows.Forms.MessageBox]::Show("The MAC Address format is unrecognized.", "Invalid MAC Address", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        $ScopeId = $null
        $scopesList = @()
        
        foreach ($server in ($script:DhcpServers)) {
            try { $scopesList = Get-DhcpServerv4Scope -ComputerName ($server) -ErrorAction Stop; if ($scopesList) { break } } catch {}
        }

        if (-not $scopesList) {
            Start-Sleep -Milliseconds 1500
            foreach ($server in ($script:DhcpServers)) {
                try { $scopesList = Get-DhcpServerv4Scope -ComputerName ($server) -ErrorAction Stop; if ($scopesList) { break } } catch {}
            }
        }

        if ($scopesList) {
            $exactMatch = $scopesList | Where-Object { $_.ScopeId.ToString() -eq $IP }
            if ($exactMatch) { $ScopeId = $exactMatch.ScopeId.ToString() } else {
                try {
                    $ipBytes = [System.Net.IPAddress]::Parse($IP).GetAddressBytes()
                    foreach ($s in ($scopesList)) {
                        $maskBytes = [System.Net.IPAddress]::Parse($s.SubnetMask).GetAddressBytes()
                        $scopeBytes = [System.Net.IPAddress]::Parse($s.ScopeId).GetAddressBytes()
                        $isMatch = $true
                        for ($i=0; $i -lt 4; $i++) { if (($ipBytes[$i] -band $maskBytes[$i]) -ne $scopeBytes[$i]) { $isMatch = $false; break } }
                        if ($isMatch) { $ScopeId = $s.ScopeId.ToString(); break }
                    }
                } catch {}
            }
        }

        if ([string]::IsNullOrWhiteSpace($ScopeId)) {
            $null = [System.Windows.Forms.MessageBox]::Show("Could not discover an active scope on your network containing the IP address '$IP'.", "Scope Routing Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        $ValidServers = @()
        foreach ($server in ($script:DhcpServers)) {
            try {
                if (Get-DhcpServerv4Scope -ComputerName ($server) -ScopeId ($ScopeId) -ErrorAction Stop) {
                    $ValidServers += $server
                }
            } catch {}
        }
        
        if ($ValidServers.Count -eq 0) {
            $null = [System.Windows.Forms.MessageBox]::Show("Scope container '$ScopeId' was not found on any active server targets.", "Scope Verification Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        if ($IP -eq $ScopeId) {
            try {
                $FreeIPPool = Get-DhcpServerv4FreeIPaddress -ComputerName ($ValidServers[0]) -ScopeId ($ScopeId) -Num 5 -ErrorAction Stop
                $MutuallyFreeIP = $null

                foreach ($candidate in ($FreeIPPool)) {
                    $isFreeEverywhere = $true
                    for ($i = 1; $i -lt $ValidServers.Count; $i++) {
                        $s = $ValidServers[$i]
                        $checkLease = $null
                        $checkRes = $null
                        try { $checkLease = Get-DhcpServerv4Lease -ComputerName ($s) -IPAddress ($candidate) -ErrorAction Stop } catch {}
                        try { $checkRes = Get-DhcpServerv4Reservation -ComputerName ($s) -IPAddress ($candidate) -ErrorAction Stop } catch {}
                        
                        if ($checkLease -or $checkRes) { $isFreeEverywhere = $false; break }
                    }
                    if ($isFreeEverywhere) { $MutuallyFreeIP = $candidate; break }
                }

                if ([string]::IsNullOrWhiteSpace($MutuallyFreeIP)) { throw "No available free IP addresses found synchronized cleanly across cluster profile." }

                $confirmPrompt = "The next available IP address discovered in scope $ScopeId is:`n`n      $MutuallyFreeIP`n`nWould you like to assign this address to the new reservation?"
                $userChoice = [System.Windows.Forms.MessageBox]::Show($confirmPrompt, "Next Available IP Allocated", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
                if ($userChoice -ne [System.Windows.Forms.DialogResult]::Yes) { return }

                $IP = $MutuallyFreeIP
            } catch {
                $null = [System.Windows.Forms.MessageBox]::Show("Failed to query next available free IP address from scope:`n`n$($_.Exception.Message)", "IP Allocation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }
        }

        $foundConflicts = @()
        foreach ($server in ($ValidServers)) {
            try {
                $resIP = Get-DhcpServerv4Reservation -ComputerName ($server) -IPAddress ($IP) -ErrorAction Stop
                if ($resIP) { $foundConflicts += [PSCustomObject]@{ Server = $server; Type = "Reservation"; TargetIP = $resIP.IPAddress; Msg = "Existing Reservation on IP Match (`n   Name: $($resIP.Name) | IP: $($resIP.IPAddress) | MAC: $($resIP.ClientId))" } }
            } catch {}

            try {
                $leaseIP = Get-DhcpServerv4Lease -ComputerName ($server) -IPAddress ($IP) -ErrorAction Stop
                if ($leaseIP) {$foundConflicts += [PSCustomObject]@{ Server = $server; Type = "Lease"; TargetIP = $leaseIP.IPAddress; Msg = "Existing Active Lease on IP Match (`n   Host: $($leaseIP.HostName) | IP: $($leaseIP.IPAddress) | MAC: $($leaseIP.ClientId) | State: $($leaseIP.AddressState))" } }
            } catch {}

            try {
                $allReservations = Get-DhcpServerv4Reservation -ComputerName ($server) -ScopeId ($ScopeId) -ErrorAction Stop
                foreach ($res in ($allReservations)) {
                    if (($res.ClientId -replace '[:.-]', '') -eq $MAC -and $res.IPAddress -ne $IP) {
                        $foundConflicts += [PSCustomObject]@{ Server = $server; Type = "Reservation"; TargetIP = $res.IPAddress; Msg = "Existing Reservation on MAC Match (`n   Name: $($res.Name) | IP: $($res.IPAddress) | MAC: $($res.ClientId))" }
                    }
                }
            } catch {}

            try {
                $allLeases = Get-DhcpServerv4Lease -ComputerName ($server) -ScopeId ($ScopeId) -ErrorAction Stop
                foreach ($lease in ($allLeases)) {
                    if ((($lease.ClientId -replace '[:.-]', '') -eq $MAC) -and ($lease.IPAddress -ne $IP)) {$foundConflicts += [PSCustomObject]@{ Server = $server; Type = "Lease"; TargetIP = $lease.IPAddress; Msg = "Existing Active Lease on MAC Match (`n   Host: $($lease.HostName) | IP: $($lease.IPAddress) | MAC: $($lease.ClientId) | State: $($lease.AddressState))" }
                    }
                }
            } catch {}
        }

        if ($foundConflicts.Count -gt 0) {
            $promptMessage = "The following conflicting database entries were detected BEFORE writing to the servers:`n`n"
            foreach ($conflict in ($foundConflicts)) { $promptMessage += "[Server: $($conflict.Server)] $($conflict.Msg)`n`n" }
            $promptMessage += "Would you like to force-clear all listed database conflicts and proceed with applying the new reservation?"

            $decision = [System.Windows.Forms.MessageBox]::Show($promptMessage, "DHCP Database Conflict Detected", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($decision -ne [System.Windows.Forms.DialogResult]::Yes) { return }

            foreach ($conflict in ($foundConflicts)) {
                try {
                    if ($conflict.Type -eq "Reservation") { Remove-DhcpServerv4Reservation -ComputerName ($conflict.Server) -IPAddress ($conflict.TargetIP) -ErrorAction Stop } 
                    else { Remove-DhcpServerv4Lease -ComputerName ($conflict.Server) -IPAddress ($conflict.TargetIP) -ErrorAction Stop }
                } catch {}
            }
        }

        $StatusReport = ""
        $SuccessCount = 0

        foreach ($server in ($ValidServers)) {
            try {
                Add-DhcpServerv4Reservation -ComputerName ($server) -ScopeId ($ScopeId) -IPAddress ($IP) -ClientId ($MAC) -Name ($Name) -Description ($Desc) -Type $Type -ErrorAction Stop
                $SuccessCount++
                $StatusReport += "• $server : Success`n"
            } catch {
                $StatusReport += "• $server : FAILED (`n  Reason: $($_.Exception.Message) )`n"
            }
        }

        if ($SuccessCount -eq $ValidServers.Count) {$null = [System.Windows.Forms.MessageBox]::Show("Reservation successfully configured on all target systems!`n`n$StatusReport", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $txtName.Clear(); $txtIP.Clear();$txtMAC.Clear(); $txtDesc.Clear();$txtName.Focus()
        } else {
            $null = [System.Windows.Forms.MessageBox]::Show("One or more server targets encountered configuration issues during push operation:`n`n$StatusReport", "Deployment Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    } finally {
        $btnAdd.Enabled =$true
    }
})

$null =$form.ShowDialog()