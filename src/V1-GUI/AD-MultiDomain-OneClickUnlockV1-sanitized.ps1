# AD Multi-Domain One-Click Unlock Tool (GUI)
# V1 — Initial version
# - Checks multiple AD domains
# - Shows Enabled, LockedOut, AccountExpired
# - Can unlock in any domain where the account exists & is locked
#
# NOTE:
#   Domain names below are sanitized for public/portfolio use.
#   Replace contoso-style domains with your real environment if you adapt this.

Import-Module ActiveDirectory

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------
# Config: Domains to check (SANITIZED)
# ------------------------------
$Global:Domains = @(
    "corp-ad01.contoso.local",
    "med-ad01.contoso.local",
    "mgmt-ad01.contoso.local",
    "ext-ad01.contoso.local"
)

# Store last status so we can use it during unlock
$Global:lastStatus = @()

# ------------------------------
# Function: Get status in all domains
# ------------------------------
function Get-AdUserMultiDomainStatus {
    param(
        [string]$UserId
    )

    $now = Get-Date
    $results = @()

    foreach ($domain in $Global:Domains) {
        try {
            # Try to get user in this domain
            $user = Get-ADUser -Server $domain -Identity $UserId `
                -Properties LockedOut, Enabled, AccountExpirationDate `
                -ErrorAction Stop

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
            # User not found in this domain
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
            # Other AD/server error
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
# Function: Format status for display
# ------------------------------
function Format-StatusForDisplay {
    param(
        [System.Collections.IEnumerable]$Status
    )

    $lines = @()

    foreach ($r in $Status) {
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
        $lines += "No results."
    }

    return $lines
}

# ------------------------------
# GUI setup
# ------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "AD Multi-Domain One-Click Unlock (V1)"
$form.Size = New-Object System.Drawing.Size(600, 430)
$form.StartPosition = "CenterScreen"

# User label
$labelUser = New-Object System.Windows.Forms.Label
$labelUser.Text = "User ID:"
$labelUser.Location = New-Object System.Drawing.Point(10, 15)
$labelUser.AutoSize = $true
$form.Controls.Add($labelUser)

# User textbox
$textUser = New-Object System.Windows.Forms.TextBox
$textUser.Location = New-Object System.Drawing.Point(80, 12)
$textUser.Width = 200
$form.Controls.Add($textUser)

# Check Status button
$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = "Check Status"
$btnCheck.Location = New-Object System.Drawing.Point(300, 10)
$btnCheck.Width = 120
$form.Controls.Add($btnCheck)

# Unlock button
$btnUnlock = New-Object System.Windows.Forms.Button
$btnUnlock.Text = "Unlock (All Domains)"
$btnUnlock.Location = New-Object System.Drawing.Point(300, 45)
$btnUnlock.Width = 150
$form.Controls.Add($btnUnlock)

# Output textbox
$textOutput = New-Object System.Windows.Forms.TextBox
$textOutput.Location = New-Object System.Drawing.Point(10, 90)
$textOutput.Multiline = $true
$textOutput.ScrollBars = "Vertical"
$textOutput.ReadOnly = $true
$textOutput.Width = 560
$textOutput.Height = 260
$form.Controls.Add($textOutput)

# Status bar
$statusBar = New-Object System.Windows.Forms.Label
$statusBar.Location = New-Object System.Drawing.Point(10, 360)
$statusBar.Width = 560
$statusBar.AutoSize = $false
$form.Controls.Add($statusBar)

# ------------------------------
# Button: Check Status
# ------------------------------
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

        $textOutput.ForeColor = [System.Drawing.Color]::Black
        $textOutput.Lines = Format-StatusForDisplay $status

        $statusBar.Text = "Status check completed."
    }
    catch {
        $textOutput.ForeColor = [System.Drawing.Color]::Red
        $textOutput.Lines = @("Error checking user:", $_.Exception.Message)
        $statusBar.Text = "Error during status check."
    }
})

# ------------------------------
# Button: Unlock (All Domains)
# ------------------------------
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

    try {
        foreach ($r in $Global:lastStatus) {
            # Only unlock if we found the user in that domain, with no error note
            if ($r.Notes -eq "" -and $r.LockedOut -eq $true -and $r.Enabled -eq $true -and $r.AccountExpired -ne $true) {
                try {
                    Unlock-ADAccount -Server $r.Domain -Identity $r.SamAccountName -ErrorAction SilentlyContinue
                }
                catch {
                    # Swallow individual domain errors; overall flow continues
                }
            }
        }

        # Re-check status after unlock
        $newStatus = Get-AdUserMultiDomainStatus -UserId $userId
        $Global:lastStatus = $newStatus

        $textOutput.ForeColor = [System.Drawing.Color]::Black
        $textOutput.Lines = Format-StatusForDisplay $newStatus

        $statusBar.Text = "Unlock attempt complete. Status refreshed."
    }
    catch {
        $textOutput.ForeColor = [System.Drawing.Color]::Red
        $textOutput.Lines = @("Error during unlock flow:", $_.Exception.Message)
        $statusBar.Text = "Error during unlock."
    }
})

# ------------------------------
# Show form
# ------------------------------
[void]$form.ShowDialog()

