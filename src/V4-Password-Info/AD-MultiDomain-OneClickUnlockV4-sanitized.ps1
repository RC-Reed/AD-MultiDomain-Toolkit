Import-Module ActiveDirectory

# ---------------- CONFIG ----------------
# NOTE:
# - Domain names are sanitized for public sharing.
# - Replace with your real environment if adapting this.
$Global:ADDomains = @(
    "corp-ad01.contoso.local",
    "med-ad01.contoso.local",
    "mgmt-ad01.contoso.local",
    "ext-ad01.contoso.local"
)

# Primary domain to use for password info lookups (sanitized)
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
            # user not found in this domain
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
            # other error
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
        # Only attempt unlock where we actually found the user and had no error note
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

# ---------------- TROUBLESHOOTING FUNCTIONS ----------------

function Run-Ping {
    param(
        [string]$Target
    )

    $lines = @()

    if (-not $Target) {
        $lines += "Please enter a ping target."
        return $lines
    }

    try {
        $result = Test-Connection -ComputerName $Target -Count 4 -ErrorAction Stop
        $avg = ($result | Measure-Object -Property ResponseTime -Average).Average
        $lines += "Ping to " + $Target + " succeeded."
        $lines += "Average response time (ms): " + [math]::Round($avg, 2)
    }
    catch {
        $lines += "Ping to " + $Target + " failed: " + $_.Exception.Message
    }

    return $lines
}

function Run-FlushDNS {
    $output = ipconfig /flushdns 2>&1
    $lines = @("Ran ipconfig /flushdns:", "")
    $lines += $output
    return $lines
}

function Run-IPConfigAll {
    $output = ipconfig /all 2>&1
    $lines = @("ipconfig /all output:", "")
    $lines += $output
    return $lines
}

function Clear-TeamsCacheDetailed {
    $lines = @()
    $lines += "Starting Teams cache clear..."

    # Kill Teams processes (classic + new)
    $procNames = @("Teams", "ms-teams")

    foreach ($name in $procNames) {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($procs) {
            $count = $procs.Count
            Try {
                $procs | Stop-Process -Force -ErrorAction Stop
                $lines += "Stopped " + $count + " instance(s) of process '" + $name + "'."
            }
            Catch {
                $lines += "Failed to stop process '" + $name + "': " + $_.Exception.Message
            }
        }
        else {
            $lines += "No running processes named '" + $name + "' found."
        }
    }

    # Common Teams cache locations
    $paths = @(
        "$env:APPDATA\Microsoft\Teams",
        "$env:LOCALAPPDATA\Microsoft\Teams",
        "$env:LOCALAPPDATA\Microsoft\Microsoft Teams"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            $lines += "Clearing cache under: " + $path
            try {
                # Count files/folders (best-effort)
                $countBefore = 0
                try {
                    $countBefore = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
                } catch {}

                Remove-Item (Join-Path $path "*") -Recurse -Force -ErrorAction SilentlyContinue
                $lines += " Attempted to delete contents. Items before (approx): " + $countBefore
            }
            catch {
                $lines += " Error clearing: " + $_.Exception.Message
            }
        }
        else {
            $lines += "Path not found (skipped): " + $path
        }
    }

    $lines += "Teams cache clear complete. Have the user sign out/in or restart Teams."
    return $lines
}

function Fix-OfficeAppsDetailed {
    $lines = @()
    $lines += "Checking for running Office apps to close..."

    $apps = @("OUTLOOK", "WINWORD", "EXCEL", "POWERPNT", "ONENOTE")

    foreach ($app in $apps) {
        $procs = Get-Process -Name $app -ErrorAction SilentlyContinue
        if ($procs) {
            $count = $procs.Count
            try {
                $procs | Stop-Process -Force -ErrorAction Stop
                $lines += "Closed " + $count + " instance(s) of " + $app + ".exe"
            }
            catch {
                $lines += "Error closing " + $app + ".exe: " + $_.Exception.Message
            }
        }
        else {
            $lines += "No running processes found for " + $app + ".exe"
        }
    }

    $lines += "Office apps check complete."
    return $lines
}

function Restart-ExplorerShell {
    $lines = @()
    $lines += "Restarting Windows Explorer..."

    $procs = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
    if ($procs) {
        try {
            $procs | Stop-Process -Force -ErrorAction Stop
            Start-Process "explorer.exe"
            $lines += "Explorer restarted."
        }
        catch {
            $lines += "Error restarting Explorer: " + $_.Exception.Message
        }
    }
    else {
        try {
            Start-Process "explorer.exe"
            $lines += "Explorer process was not running. Started a new instance."
        }
        catch {
            $lines += "Error starting Explorer: " + $_.Exception.Message
        }
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

# Tab control
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(10, 10)
$tabs.Size = New-Object System.Drawing.Size(610, 440)
$form.Controls.Add($tabs)

# ---- TAB 1: USER TOOLS ----
$tabUser = New-Object System.Windows.Forms.TabPage
$tabUser.Text = "User Tools"
$tabs.TabPages.Add($tabUser)

# User ID label
$labelUser = New-Object System.Windows.Forms.Label
$labelUser.Text = "User ID:"
$labelUser.Location = New-Object System.Drawing.Point(15, 20)
$labelUser.AutoSize = $true
$tabUser.Controls.Add($labelUser)

# User ID textbox
$textUser = New-Object System.Windows.Forms.TextBox
$textUser.Location = New-Object System.Drawing.Point(80, 18)
$textUser.Width = 200
$tabUser.Controls.Add($textUser)

# Copy to clipboard button
$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = "Copy to Clip"
$btnCopy.Location = New-Object System.Drawing.Point(300, 16)
$btnCopy.Width = 100
$tabUser.Controls.Add($btnCopy)

# Check status button
$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = "Check Status"
$btnCheck.Location = New-Object System.Drawing.Point(420, 16)
$btnCheck.Width = 120
$tabUser.Controls.Add($btnCheck)

# Unlock button
$btnUnlock = New-Object System.Windows.Forms.Button
$btnUnlock.Text = "Unlock (All Domains)"
$btnUnlock.Location = New-Object System.Drawing.Point(420, 50)
$btnUnlock.Width = 120
$tabUser.Controls.Add($btnUnlock)

# Password info button
$btnPwdInfo = New-Object System.Windows.Forms.Button
$btnPwdInfo.Text = "Password Info"
$btnPwdInfo.Location = New-Object System.Drawing.Point(300, 50)
$btnPwdInfo.Width = 100
$tabUser.Controls.Add($btnPwdInfo)

# User output textbox
$textUserOutput = New-Object System.Windows.Forms.TextBox
$textUserOutput.Location = New-Object System.Drawing.Point(15, 90)
$textUserOutput.Multiline = $true
$textUserOutput.ScrollBars = "Vertical"
$textUserOutput.ReadOnly = $true
$textUserOutput.Width = 560
$textUserOutput.Height = 300
$tabUser.Controls.Add($textUserOutput)

# ---- TAB 2: TROUBLESHOOTING ----
$tabTrouble = New-Object System.Windows.Forms.TabPage
$tabTrouble.Text = "Troubleshooting"
$tabs.TabPages.Add($tabTrouble)

# Ping label
$labelPing = New-Object System.Windows.Forms.Label
$labelPing.Text = "Ping target:"
$labelPing.Location = New-Object System.Drawing.Point(15, 20)
$labelPing.AutoSize = $true
$tabTrouble.Controls.Add($labelPing)

# Ping textbox
$textPing = New-Object System.Windows.Forms.TextBox
$textPing.Location = New-Object System.Drawing.Point(90, 18)
$textPing.Width = 200
$tabTrouble.Controls.Add($textPing)

# Ping button
$btnPing = New-Object System.Windows.Forms.Button
$btnPing.Text = "Ping"
$btnPing.Location = New-Object System.Drawing.Point(310, 16)
$btnPing.Width = 80
$tabTrouble.Controls.Add($btnPing)

# Flush DNS button
$btnFlush = New-Object System.Windows.Forms.Button
$btnFlush.Text = "Flush DNS"
$btnFlush.Location = New-Object System.Drawing.Point(15, 55)
$btnFlush.Width = 100
$tabTrouble.Controls.Add($btnFlush)

# IPConfig /all button
$btnIPAll = New-Object System.Windows.Forms.Button
$btnIPAll.Text = "IPConfig /all"
$btnIPAll.Location = New-Object System.Drawing.Point(130, 55)
$btnIPAll.Width = 100
$tabTrouble.Controls.Add($btnIPAll)

# Clear Teams cache button
$btnTeamsClear = New-Object System.Windows.Forms.Button
$btnTeamsClear.Text = "Clear Teams Cache"
$btnTeamsClear.Location = New-Object System.Drawing.Point(245, 55)
$btnTeamsClear.Width = 130
$tabTrouble.Controls.Add($btnTeamsClear)

# Fix Office apps button
$btnFixOffice = New-Object System.Windows.Forms.Button
$btnFixOffice.Text = "Fix Office Apps"
$btnFixOffice.Location = New-Object System.Drawing.Point(390, 55)
$btnFixOffice.Width = 120
$tabTrouble.Controls.Add($btnFixOffice)

# Restart Explorer button
$btnRestartExplorer = New-Object System.Windows.Forms.Button
$btnRestartExplorer.Text = "Restart Explorer"
$btnRestartExplorer.Location = New-Object System.Drawing.Point(390, 18)
$btnRestartExplorer.Width = 120
$tabTrouble.Controls.Add($btnRestartExplorer)

# Troubleshooting output textbox
$textTroubleOutput = New-Object System.Windows.Forms.TextBox
$textTroubleOutput.Location = New-Object System.Drawing.Point(15, 100)
$textTroubleOutput.Multiline = $true
$textTroubleOutput.ScrollBars = "Vertical"
$textTroubleOutput.ReadOnly = $true
$textTroubleOutput.Width = 560
$textTroubleOutput.Height = 290
$tabTrouble.Controls.Add($textTroubleOutput)

# ---------------- EVENT HANDLERS ----------------

# Check status
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

# Unlock across domains
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

# Copy to clipboard
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

# Password info
$btnPwdInfo.Add_Click({
    $userId = $textUser.Text.Trim()
    if (-not $userId) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a user ID.","Missing input") | Out-Null
        return
    }

    $lines = Get-PasswordInfo -UserId $userId
    $textUserOutput.Lines = $lines
})

# Ping
$btnPing.Add_Click({
    $target = $textPing.Text.Trim()
    $textTroubleOutput.Lines = Run-Ping -Target $target
})

# Flush DNS
$btnFlush.Add_Click({
    $textTroubleOutput.Lines = Run-FlushDNS
})

# IPConfig /all
$btnIPAll.Add_Click({
    $textTroubleOutput.Lines = Run-IPConfigAll
})

# Clear Teams cache
$btnTeamsClear.Add_Click({
    $textTroubleOutput.Lines = Clear-TeamsCacheDetailed
})

# Fix Office apps
$btnFixOffice.Add_Click({
    $textTroubleOutput.Lines = Fix-OfficeAppsDetailed
})

# Restart Explorer
$btnRestartExplorer.Add_Click({
    $textTroubleOutput.Lines = Restart-ExplorerShell
})

# ---------------- SHOW FORM ----------------
[void]$form.ShowDialog()

