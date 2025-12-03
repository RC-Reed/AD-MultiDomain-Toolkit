Import-Module ActiveDirectory

# NOTE:
# - All domain names, hostnames, URLs, UNC paths, and shortcut names here
#   are generic placeholders for public sharing.
# - Replace them with your own environment details if you adapt this for real use.

# ---------------- CONFIG ----------------
$Global:ADDomains = @(
    "corp-ad01.contoso.local",
    "med-ad01.contoso.local",
    "mgmt-ad01.contoso.local",
    "ext-ad01.contoso.local"
)

# Primary domain to use for password info lookups
$Global:PrimaryDomainForPwdInfo = "corp-ad01.contoso.local"

# Last AD status results (for unlock reuse)
$Global:LastStatusResults = $null

# ---------------- CORE FUNCTIONS ----------------

function Get-UserStatusMultiDomain {
    param(
        [string]$UserId
    )

    $results = @()
    $now = Get-Date

    foreach ($domain in $Global:ADDomains) {
        try {
            $user = Get-ADUser -Server $domain -Identity $UserId `
                -Properties LockedOut, Enabled, AccountExpirationDate `
                -ErrorAction Stop

            $acctExpired = $false
            $acctExpireDate = $null

            if ($user.AccountExpirationDate) {
                $acctExpireDate = $user.AccountExpirationDate
                if ($acctExpireDate -le $now) { $acctExpired = $true }
            }

            $results += [PSCustomObject]@{
                Domain            = $domain
                SamAccountName    = $user.SamAccountName
                Enabled           = $user.Enabled
                LockedOut         = $user.LockedOut
                AccountExpired    = $acctExpired
                AccountExpireDate = $acctExpireDate
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
                Notes             = "Error: " + $_.Exception.Message
            }
        }
    }

    return $results
}

function Format-UserStatus {
    param(
        [System.Collections.IEnumerable]$Results
    )

    $lines = @()

    foreach ($r in $Results) {
        $lines += "Domain: " + $r.Domain

        if ($r.SamAccountName) {
            $lines += "User: " + $r.SamAccountName
        }

        if ($r.Enabled -ne $null) {
            $lines += "Enabled: " + $r.Enabled
            $lines += "Locked: " + $r.LockedOut
            $lines += "Expired: " + $r.AccountExpired

            if ($r.AccountExpireDate) {
                $lines += "Account Expiration Date: " + $r.AccountExpireDate
            }
        }

        if ($r.Notes) {
            $lines += "Notes: " + $r.Notes
        }

        $lines += "" # blank line between domains
    }

    if ($lines.Count -eq 0) {
        $lines += "No results."
    }

    $lines += "Status check completed."
    return $lines
}

function Unlock-UserAllDomains {
    param(
        [string]$UserId,
        [System.Collections.IEnumerable]$CurrentResults
    )

    $lines = @()

    foreach ($r in $CurrentResults) {
        if (-not $r.SamAccountName) { continue }
        if ($r.Notes -and $r.Notes -ne "") { continue }

        try {
            Unlock-ADAccount -Identity $UserId -Server $r.Domain -ErrorAction Stop
            $lines += "[" + $r.Domain + "] unlock command sent successfully."
        }
        catch {
            $lines += "[" + $r.Domain + "] unlock failed: " + $_.Exception.Message
        }
    }

    if ($lines.Count -eq 0) {
        $lines += "No domains contained a matching user to unlock."
    }

    return $lines
}

function Convert-ADFileTime {
    param($Value)

    if (-not $Value -or $Value -eq 0) {
        return ""
    }

    try {
        return [DateTime]::FromFileTimeUtc([int64]$Value).ToLocalTime()
    }
    catch {
        return $Value
    }
}

function Get-PasswordInfo {
    param(
        [string]$UserId
    )

    $domain = $Global:PrimaryDomainForPwdInfo
    $lines = @()

    try {
        $u = Get-ADUser -Identity $UserId -Server $domain `
            -Properties badPwdCount,badPasswordTime,lockoutTime,lastLogonTimestamp `
            -ErrorAction Stop

        $lines += "Password / logon info for user " + $u.SamAccountName + " (domain " + $domain + "):"
        $lines += "Bad password count: " + $u.badPwdCount
        $lines += "Last bad password time: " + (Convert-ADFileTime $u.badPasswordTime)
        $lines += "Lockout time: " + (Convert-ADFileTime $u.lockoutTime)
        $lines += "Last logon (approx): " + (Convert-ADFileTime $u.lastLogonTimestamp)
    }
    catch {
        $lines += "Error retrieving password info from domain " + $domain + ": " + $_.Exception.Message
    }

    return $lines
}

# ---------------- GUI SETUP ----------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "AD Multi-Domain One-Click Unlock"
$form.Size = New-Object System.Drawing.Size(650, 500)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Tab control
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(10, 10)
$tabs.Size = New-Object System.Drawing.Size(610, 440)
$form.Controls.Add($tabs)

# ---- TAB 1: USER TOOLS ----
$tabUser = New-Object System.Windows.Forms.TabPage
$tabUser.Text = "User Tools"
$tabs.TabPages.Add($tabUser)

$labelUser = New-Object System.Windows.Forms.Label
$labelUser.Text = "User ID:"
$labelUser.Location = New-Object System.Drawing.Point(15, 20)
$labelUser.AutoSize = $true
$tabUser.Controls.Add($labelUser)

$textUser = New-Object System.Windows.Forms.TextBox
$textUser.Location = New-Object System.Drawing.Point(80, 18)
$textUser.Width = 200
$tabUser.Controls.Add($textUser)

$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = "Copy to Clip"
$btnCopy.Location = New-Object System.Drawing.Point(300, 16)
$btnCopy.Width = 100
$tabUser.Controls.Add($btnCopy)

$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = "Check Status"
$btnCheck.Location = New-Object System.Drawing.Point(420, 16)
$btnCheck.Width = 120
$tabUser.Controls.Add($btnCheck)

$btnUnlock = New-Object System.Windows.Forms.Button
$btnUnlock.Text = "Unlock (All Domains)"
$btnUnlock.Location = New-Object System.Drawing.Point(420, 50)
$btnUnlock.Width = 120
$tabUser.Controls.Add($btnUnlock)

$btnPwdInfo = New-Object System.Windows.Forms.Button
$btnPwdInfo.Text = "Password Info"
$btnPwdInfo.Location = New-Object System.Drawing.Point(300, 50)
$btnPwdInfo.Width = 100
$tabUser.Controls.Add($btnPwdInfo)

$textUserOutput = New-Object System.Windows.Forms.TextBox
$textUserOutput.Location = New-Object System.Drawing.Point(15, 90)
$textUserOutput.Multiline = $true
$textUserOutput.ScrollBars = "Vertical"
$textUserOutput.ReadOnly = $true
$textUserOutput.Width = 560
$textUserOutput.Height = 300
$tabUser.Controls.Add($textUserOutput)

# ---- TAB 2: TOOLS ----
$tabTools = New-Object System.Windows.Forms.TabPage
$tabTools.Text = "Tools"
$tabs.TabPages.Add($tabTools)

# Group: RSA Consoles
$grpRSA = New-Object System.Windows.Forms.GroupBox
$grpRSA.Text = "RSA Consoles"
$grpRSA.Location = New-Object System.Drawing.Point(15, 15)
$grpRSA.Size = New-Object System.Drawing.Size(280, 140)
$tabTools.Controls.Add($grpRSA)

$btnRSA_VDI_EDE = New-Object System.Windows.Forms.Button
$btnRSA_VDI_EDE.Text = "RSA VDI"
$btnRSA_VDI_EDE.Location = New-Object System.Drawing.Point(15, 30)
$btnRSA_VDI_EDE.Width = 110
$grpRSA.Controls.Add($btnRSA_VDI_EDE)

$btnRSA_ADEXT = New-Object System.Windows.Forms.Button
$btnRSA_ADEXT.Text = "RSA EXT"
$btnRSA_ADEXT.Location = New-Object System.Drawing.Point(145, 30)
$btnRSA_ADEXT.Width = 110
$grpRSA.Controls.Add($btnRSA_ADEXT)

$btnRSA_ADOM = New-Object System.Windows.Forms.Button
$btnRSA_ADOM.Text = "RSA CORP"
$btnRSA_ADOM.Location = New-Object System.Drawing.Point(15, 75)
$btnRSA_ADOM.Width = 110
$grpRSA.Controls.Add($btnRSA_ADOM)

$btnRSA_ADMED = New-Object System.Windows.Forms.Button
$btnRSA_ADMED.Text = "RSA MED"
$btnRSA_ADMED.Location = New-Object System.Drawing.Point(145, 75)
$btnRSA_ADMED.Width = 110
$grpRSA.Controls.Add($btnRSA_ADMED)

# Group: Web Tools
$grpWeb = New-Object System.Windows.Forms.GroupBox
$grpWeb.Text = "Web Tools"
$grpWeb.Location = New-Object System.Drawing.Point(315, 15)
$grpWeb.Size = New-Object System.Drawing.Size(260, 80)
$tabTools.Controls.Add($grpWeb)

$btnPasswordManager = New-Object System.Windows.Forms.Button
$btnPasswordManager.Text = "Password Manager"
$btnPasswordManager.Location = New-Object System.Drawing.Point(15, 30)
$btnPasswordManager.Width = 220
$grpWeb.Controls.Add($btnPasswordManager)

# Group: File Shares
$grpShares = New-Object System.Windows.Forms.GroupBox
$grpShares.Text = "File Shares"
$grpShares.Location = New-Object System.Drawing.Point(15, 175)
$grpShares.Size = New-Object System.Drawing.Size(280, 110)
$tabTools.Controls.Add($grpShares)

$btnImportantDocs = New-Object System.Windows.Forms.Button
$btnImportantDocs.Text = "Important Docs"
$btnImportantDocs.Location = New-Object System.Drawing.Point(15, 30)
$btnImportantDocs.Width = 240
$grpShares.Controls.Add($btnImportantDocs)

$btnStandards = New-Object System.Windows.Forms.Button
$btnStandards.Text = "Standards"
$btnStandards.Location = New-Object System.Drawing.Point(15, 65)
$btnStandards.Width = 240
$grpShares.Controls.Add($btnStandards)

# Group: Local Tools
$grpLocal = New-Object System.Windows.Forms.GroupBox
$grpLocal.Text = "Local Tools"
$grpLocal.Location = New-Object System.Drawing.Point(315, 115)
$grpLocal.Size = New-Object System.Drawing.Size(260, 90)
$tabTools.Controls.Add($grpLocal)

$btnBigFix = New-Object System.Windows.Forms.Button
$btnBigFix.Text = "Remote Mgmt Tool"
$btnBigFix.Location = New-Object System.Drawing.Point(15, 30)
$btnBigFix.Width = 220
$grpLocal.Controls.Add($btnBigFix)

# ---------------- EVENT HANDLERS ----------------

$btnCheck.Add_Click({
    $userId = $textUser.Text.Trim()
    if (-not $userId) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a user ID.","Missing input") | Out-Null
        return
    }

    $textUserOutput.Lines = @("Checking status for user " + $userId + "...")

    try {
        $results = Get-UserStatusMultiDomain -UserId $userId
        $Global:LastStatusResults = $results
        $lines = Format-UserStatus -Results $results
        $textUserOutput.Lines = $lines
    }
    catch {
        $textUserOutput.Lines = @("Error checking status: " + $_.Exception.Message)
    }
})

$btnUnlock.Add_Click({
    $userId = $textUser.Text.Trim()
    if (-not $userId) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a user ID first.","Missing input") | Out-Null
        return
    }

    if (-not $Global:LastStatusResults) {
        [System.Windows.Forms.MessageBox]::Show("Run 'Check Status' before unlocking.","No status data") | Out-Null
        return
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Unlock user '" + $userId + "' in all found domains?",
        "Confirm Unlock",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    try {
        $unlockLines = Unlock-UserAllDomains -UserId $userId -CurrentResults $Global:LastStatusResults
        $newResults  = Get-UserStatusMultiDomain -UserId $userId
        $Global:LastStatusResults = $newResults
        $statusLines = Format-UserStatus -Results $newResults

        $textUserOutput.Lines = $unlockLines + "" + $statusLines
    }
    catch {
        $textUserOutput.Lines = @("Error during unlock: " + $_.Exception.Message)
    }
})

$btnCopy.Add_Click({
    $text = $textUserOutput.Text
    if ($text -and $text.Trim().Length -gt 0) {
        [System.Windows.Forms.Clipboard]::SetText($text)
        [System.Windows.Forms.MessageBox]::Show("Output copied to clipboard.","Copied") | Out-Null
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("Nothing to copy yet.","No Output") | Out-Null
    }
})

$btnPwdInfo.Add_Click({
    $userId = $textUser.Text.Trim()
    if (-not $userId) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a user ID.","Missing input") | Out-Null
        return
    }

    $lines = Get-PasswordInfo -UserId $userId
    $textUserOutput.Lines = $lines
})

# ---------- TOOLS TAB HANDLERS ----------

# Helper to open a desktop shortcut (URL or LNK) safely
function Open-DesktopShortcut {
    param(
        [string]$ShortcutName # e.g. 'RSA_Console_VDI.url'
    )

    $path = Join-Path $env:USERPROFILE ("Desktop\" + $ShortcutName)

    if (-not (Test-Path $path)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Shortcut not found:`n$path",
            "Shortcut Missing",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    Start-Process $path
}

# RSA via existing desktop shortcuts
$btnRSA_VDI_EDE.Add_Click({
    Open-DesktopShortcut -ShortcutName 'RSA_Console_VDI.url'
})

$btnRSA_ADEXT.Add_Click({
    Open-DesktopShortcut -ShortcutName 'RSA_Console_EXT.url'
})

$btnRSA_ADOM.Add_Click({
    Start-Process 'https://rsa-console.corp.contoso.local:7004/console-ims'
})

$btnRSA_ADMED.Add_Click({
    Open-DesktopShortcut -ShortcutName 'RSA_Console_MED.url'
})

# Password Manager direct URL
$btnPasswordManager.Add_Click({
    Start-Process 'https://passwordreset.contoso.local/'
})

# Network shares
$btnImportantDocs.Add_Click({
    Start-Process '\\fileserver01.corp.contoso.local\VDI\Support\Important Documents & Links'
})

$btnStandards.Add_Click({
    Start-Process '\\fileserver02.corp.contoso.local\Standards'
})

# Remote management console via shortcut
$btnBigFix.Add_Click({
    Open-DesktopShortcut -ShortcutName 'Remote_Management.lnk'
})

# ---------------- SHOW FORM ----------------
[void]$form.ShowDialog()

