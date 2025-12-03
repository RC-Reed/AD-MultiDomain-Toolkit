# AD Multi-Domain One-Click Unlock
# Clean version: typing works, no colors, stable for Citrix
# Features:
# - Multi-domain AD status check
# - Unlock in all domains where account is locked
# - Copy results to clipboard
# - Troubleshooting tab: Ping, FlushDNS, IPConfig /all,
#   Clear Teams cache, Restart Explorer, Fix Office apps
#
# NOTE: Domain names have been sanitized for public/portfolio use.
#       Replace the contoso-style FQDNs with your actual environment if adapting.

Import-Module ActiveDirectory

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------
# Domains to check (SANITIZED)
# ------------------------------
$Global:Domains = @(
    "corp-ad01.contoso.local",
    "med-ad01.contoso.local",
    "mgmt-ad01.contoso.local",
    "ext-ad01.contoso.local"
)

# ------------------------------
# Get multi-domain user status
# ------------------------------
function Get-AdUserMultiDomainStatus {
    param([string]$UserId)

    $now = Get-Date
    $results = @()

    foreach ($domain in $Global:Domains) {
        try {
            $user = Get-ADUser -Server $domain -Identity $UserId `
                -Properties LockedOut, Enabled, AccountExpirationDate -ErrorAction Stop

            $acctExpDate = $user.AccountExpirationDate
            $acctExpired = $false
            if ($acctExpDate -and $acctExpDate -le $now) {
                $acctExpired = $true
            }

            $results += [PSCustomObject]@{
                Domain            = $domain
                SamAccountName    = $user.SamAccountName
                Enabled           = $user.Enabled
                LockedOut         = $user.LockedOut
                AccountExpired    = $acctExpired
                AccountExpireDate = $acctExpDate
                Notes             = ""
            }
        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            $results += [PSCustomObject]@{
                Domain            = $domain
                SamAccountName    = $UserId
                Enabled           = $null
                LockedOut         = $null
                AccountExpired    = $null
                AccountExpireDate = $null
                Notes             = "User not found in this domain"
            }
        }
        catch {
            $results += [PSCustomObject]@{
                Domain            = $domain
                SamAccountName    = $UserId
                Enabled           = $null
                LockedOut         = $null
                AccountExpired    = $null
                AccountExpireDate = $null
                Notes             = "Error: $($_.Exception.Message)"
            }
        }
    }

    return $results
}

# ------------------------------
# Format status for display
# ------------------------------
function Format-StatusForDisplay {
    param($StatusObjects)

    $lines = @()

    foreach ($r in $StatusObjects) {
        $lines += "--------------------------------------------------"
        $lines += "Domain: $($r.Domain)"
        if ($r.Notes) {
            $lines += "User: $($r.SamAccountName)"
            $lines += "Notes: $($r.Notes)"
        }
        else {
            $lines += "User: $($r.SamAccountName)"
            $lines += "Enabled: $($r.Enabled)"
            $lines += "Locked: $($r.LockedOut)"
            $lines += "Expired: $($r.AccountExpired)"
            if ($r.AccountExpireDate) {
                $lines += "Account Expiration Date: $($r.AccountExpireDate)"
            }
        }
    }

    if ($lines.Count -eq 0) {
        $lines += "No results found."
    }

    return $lines
}

# ------------------------------
# GUI setup
# ------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "AD Multi-Domain One-Click Unlock"
$form.Size = New-Object System.Drawing.Size(600, 450)
$form.StartPosition = "CenterScreen"

# Tab control
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(10, 10)
$tabs.Size = New-Object System.Drawing.Size(560, 360)
$form.Controls.Add($tabs)

# ===== TAB 1: USER TOOLS =====
$tabUser = New-Object System.Windows.Forms.TabPage
$tabUser.Text = "User Tools"
$tabs.TabPages.Add($tabUser)

# User label
$labelUser = New-Object System.Windows.Forms.Label
$labelUser.Text = "User ID:"
$labelUser.Location = New-Object System.Drawing.Point(10, 15)
$labelUser.AutoSize = $true
$tabUser.Controls.Add($labelUser)

# User textbox (editable by default)
$textUser = New-Object System.Windows.Forms.TextBox
$textUser.Location = New-Object System.Drawing.Point(80, 12)
$textUser.Width = 200
$tabUser.Controls.Add($textUser)

# Check Status button
$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = "Check Status"
$btnCheck.Location = New-Object System.Drawing.Point(300, 10)
$btnCheck.Width = 110
$tabUser.Controls.Add($btnCheck)

# Unlock button
$btnUnlock = New-Object System.Windows.Forms.Button
$btnUnlock.Text = "Unlock (All Domains)"
$btnUnlock.Location = New-Object System.Drawing.Point(300, 45)
$btnUnlock.Width = 150
$tabUser.Controls.Add($btnUnlock)

# Copy to Clipboard button
$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = "Copy to Clipboard"
$btnCopy.Location = New-Object System.Drawing.Point(120, 45)
$btnCopy.Width = 150
$tabUser.Controls.Add($btnCopy)

# Output textbox
$textOutput = New-Object System.Windows.Forms.TextBox
$textOutput.Location = New-Object System.Drawing.Point(10, 80)
$textOutput.Multiline = $true
$textOutput.ScrollBars = "Vertical"
$textOutput.ReadOnly = $true
$textOutput.Width = 520
$textOutput.Height = 240
$tabUser.Controls.Add($textOutput)

# ===== TAB 2: TROUBLESHOOTING =====
$tabTools = New-Object System.Windows.Forms.TabPage
$tabTools.Text = "Troubleshooting"
$tabs.TabPages.Add($tabTools)

# Ping target label
$lblPing = New-Object System.Windows.Forms.Label
$lblPing.Text = "Ping target:"
$lblPing.Location = New-Object System.Drawing.Point(10, 15)
$lblPing.AutoSize = $true
$tabTools.Controls.Add($lblPing)

# Ping target textbox
$txtPingTarget = New-Object System.Windows.Forms.TextBox
$txtPingTarget.Location = New-Object System.Drawing.Point(100, 12)
$txtPingTarget.Width = 180
$tabTools.Controls.Add($txtPingTarget)

# Ping button
$btnPing = New-Object System.Windows.Forms.Button
$btnPing.Text = "Ping"
$btnPing.Location = New-Object System.Drawing.Point(300, 10)
$btnPing.Width = 80
$tabTools.Controls.Add($btnPing)

# Flush DNS button
$btnFlushDNS = New-Object System.Windows.Forms.Button
$btnFlushDNS.Text = "Flush DNS"
$btnFlushDNS.Location = New-Object System.Drawing.Point(10, 45)
$btnFlushDNS.Width = 100
$tabTools.Controls.Add($btnFlushDNS)

# IPConfig button
$btnIPConfig = New-Object System.Windows.Forms.Button
$btnIPConfig.Text = "IPConfig /all"
$btnIPConfig.Location = New-Object System.Drawing.Point(120, 45)
$btnIPConfig.Width = 100
$tabTools.Controls.Add($btnIPConfig)

# Clear Teams Cache button
$btnTeamsCache = New-Object System.Windows.Forms.Button
$btnTeamsCache.Text = "Clear Teams Cache"
$btnTeamsCache.Location = New-Object System.Drawing.Point(230, 45)
$btnTeamsCache.Width = 140
$tabTools.Controls.Add($btnTeamsCache)

# Restart Explorer button
$btnRestartExplorer = New-Object System.Windows.Forms.Button
$btnRestartExplorer.Text = "Restart Explorer"
$btnRestartExplorer.Location = New-Object System.Drawing.Point(380, 45)
$btnRestartExplorer.Width = 120
$tabTools.Controls.Add($btnRestartExplorer)

# Fix Office Apps button
$btnFixOffice = New-Object System.Windows.Forms.Button
$btnFixOffice.Text = "Fix Office Apps"
$btnFixOffice.Location = New-Object System.Drawing.Point(10, 80)
$btnFixOffice.Width = 120
$tabTools.Controls.Add($btnFixOffice)

# Troubleshooting output
$txtTroubleshoot = New-Object System.Windows.Forms.TextBox
$txtTroubleshoot.Location = New-Object System.Drawing.Point(10, 120)
$txtTroubleshoot.Multiline = $true
$txtTroubleshoot.ScrollBars = "Vertical"
$txtTroubleshoot.ReadOnly = $true
$txtTroubleshoot.Width = 520
$txtTroubleshoot.Height = 200
$tabTools.Controls.Add($txtTroubleshoot)

# Status bar
$statusBar = New-Object System.Windows.Forms.Label
$statusBar.Location = New-Object System.Drawing.Point(10, 380)
$statusBar.Width = 560
$statusBar.AutoSize = $false
$form.Controls.Add($statusBar)

# Keep last status for unlock
$Global:lastStatus = @()

# ------------------------------
# Button handlers
# ------------------------------

# Check Status
$btnCheck.Add_Click({
    $userId = $textUser.Text.Trim()
    if (-not $userId) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a user ID.","Missing Input")
        return
    }

    $statusBar.Text = "Checking status for $userId..."
    $form.Refresh()

    try {
        $status = Get-AdUserMultiDomainStatus -UserId $userId
        $Global:lastStatus = $status

        $textOutput.Lines = Format-StatusForDisplay $status
        $statusBar.Text = "Status check completed."
    }
    catch {
        $textOutput.Lines = @("Error checking user:", $_.Exception.Message)
        $statusBar.Text = "Error during status check."
    }
})

# Unlock (All Domains)
$btnUnlock.Add_Click({
    $userId = $textUser.Text.Trim()
    if (-not $userId) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a user ID first.","Missing Input")
        return
    }

    if (-not $Global:lastStatus -or $Global:lastStatus.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Run 'Check Status' first so we know where the account exists.","No Status")
        return
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Attempt to unlock '$userId' in all domains where it is locked?",
        "Confirm Unlock",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $statusBar.Text = "Unlocking (where locked)..."
    $form.Refresh()

    foreach ($r in $Global:lastStatus) {
        if ($r.Notes -eq "" -and $r.LockedOut -eq $true -and $r.Enabled -eq $true -and $r.AccountExpired -ne $true) {
            try {
                Unlock-ADAccount -Server $r.Domain -Identity $r.SamAccountName -ErrorAction SilentlyContinue
            }
            catch { }
        }
    }

    # Re-check after unlock
    $newStatus = Get-AdUserMultiDomainStatus -UserId $userId
    $Global:lastStatus = $newStatus
    $textOutput.Lines = Format-StatusForDisplay $newStatus
    $statusBar.Text = "Unlock attempt complete. Status refreshed."
})

# Copy to Clipboard
$btnCopy.Add_Click({
    if (-not [string]::IsNullOrWhiteSpace($textOutput.Text)) {
        [System.Windows.Forms.Clipboard]::SetText($textOutput.Text)
        $statusBar.Text = "Status copied to clipboard."
    }
    else {
        $statusBar.Text = "Nothing to copy."
    }
})

# Ping
$btnPing.Add_Click({
    $target = $txtPingTarget.Text.Trim()
    if (-not $target) {
        [System.Windows.Forms.MessageBox]::Show("Enter a hostname or IP to ping.","Missing Input")
        return
    }

    $statusBar.Text = "Pinging $target..."
    $form.Refresh()

    try {
        $txtTroubleshoot.Text = (Test-Connection -ComputerName $target -Count 4 -ErrorAction Stop | Out-String)
        $statusBar.Text = "Ping complete."
    }
    catch {
        $txtTroubleshoot.Text = "Ping failed: $($_.Exception.Message)"
        $statusBar.Text = "Ping failed."
    }
})

# Flush DNS
$btnFlushDNS.Add_Click({
    $statusBar.Text = "Flushing DNS..."
    $form.Refresh()
    $txtTroubleshoot.Text = (ipconfig /flushdns 2>&1 | Out-String)
    $statusBar.Text = "DNS cache flushed."
})

# IPConfig /all
$btnIPConfig.Add_Click({
    $statusBar.Text = "Running ipconfig /all..."
    $form.Refresh()
    $txtTroubleshoot.Text = (ipconfig /all 2>&1 | Out-String)
    $statusBar.Text = "ipconfig /all complete."
})

# Clear Teams Cache
$btnTeamsCache.Add_Click({
    $statusBar.Text = "Clearing Teams cache..."
    $form.Refresh()

    try {
        Stop-Process -Name "Teams","ms-teams" -ErrorAction SilentlyContinue

        $teamsAppData  = Join-Path $env:APPDATA     "Microsoft\Teams"
        $teamsLocalApp = Join-Path $env:LOCALAPPDATA "Microsoft\Teams"

        $paths = @(
            $teamsAppData,
            $teamsLocalApp
        )

        foreach ($p in $paths) {
            if (Test-Path $p) {
                Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        $txtTroubleshoot.Text = "Teams cache cleared. Ask user to relaunch Teams and sign in if prompted."
        $statusBar.Text = "Teams cache cleared."
    }
    catch {
        $txtTroubleshoot.Text = "Error clearing Teams cache: $($_.Exception.Message)"
        $statusBar.Text = "Error clearing Teams cache."
    }
})

# Restart Explorer
$btnRestartExplorer.Add_Click({
    $statusBar.Text = "Restarting Explorer..."
    $form.Refresh()
    Stop-Process -Name explorer -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    $txtTroubleshoot.Text = "Windows Explorer restarted."
    $statusBar.Text = "Explorer restarted."
})

# Fix Office Apps
$btnFixOffice.Add_Click({
    $statusBar.Text = "Closing Office apps..."
    $form.Refresh()

    $procs = "OUTLOOK","WINWORD","EXCEL","POWERPNT"
    foreach ($p in $procs) {
        Stop-Process -Name $p -ErrorAction SilentlyContinue
    }

    $txtTroubleshoot.Text = "Outlook/Word/Excel/PowerPoint processes closed. Ask user to reopen."
    $statusBar.Text = "Office apps closed."
})

# ------------------------------
# Run form
# ------------------------------
[void]$form.ShowDialog()

