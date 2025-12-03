# AD Multi-Domain One-Click Unlock Tool (GUI)
# Now with:
# - Copy to Clipboard
# - Color-coded status
# - Troubleshooting Tools tab
#
# NOTE:
#   Domain names below are sanitized (contoso.local lab-style).
#   Replace with your real environment if you adapt this.

Import-Module ActiveDirectory

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------
# Config: Domains to check
# ------------------------------
$Global:Domains = @(
"corp-ad01.contoso.local",
"med-ad01.contoso.local",
"mgmt-ad01.contoso.local",
"ext-ad01.contoso.local"
)

# ------------------------------
# Function: Multi-domain status
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
$user = Get-ADUser -Server $domain -Identity $UserId -Properties LockedOut, Enabled, AccountExpirationDate -ErrorAction Stop

$acctExpDate = $user.AccountExpirationDate
$acctExpired = $false
if ($acctExpDate -and $acctExpDate -le $now) {
$acctExpired = $true
}

$results += [PSCustomObject]@{
Domain = $domain
SamAccountName = $user.SamAccountName
Enabled = $user.Enabled
LockedOut = $user.LockedOut
AccountExpired = $acctExpired
AccountExpireDate = $acctExpDate
Notes = ""
}
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
# User not found
$results += [PSCustomObject]@{
Domain = $domain
SamAccountName = $UserId
Enabled = $null
LockedOut = $null
AccountExpired = $null
AccountExpireDate = $null
Notes = "User not found in this domain"
}
}
catch {
# Other AD/server error
$results += [PSCustomObject]@{
Domain = $domain
SamAccountName = $UserId
Enabled = $null
LockedOut = $null
AccountExpired = $null
AccountExpireDate = $null
Notes = "Error: $($_.Exception.Message)"
}
}
}

return $results
}

# ------------------------------
# Function: Format status text
# ------------------------------
function Format-StatusForDisplay {
param(
[System.Collections.IEnumerable]$Results
)

$lines = @()

foreach ($r in $Results) {
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
# Function: Set color based on status
# ------------------------------
function Set-StatusColor {
param(
[System.Windows.Forms.TextBox]$OutputBox,
[System.Collections.IEnumerable]$Results
)

# Default color
$OutputBox.ForeColor = [System.Drawing.Color]::Black

$hasError = $false
$hasLockedOrExpired = $false
$hasFoundUser = $false

foreach ($r in $Results) {
if ($r.Notes) {
# Errors or 'user not found' still might be non-critical
if ($r.Notes -like "Error:*") {
$hasError = $true
}
}
else {
$hasFoundUser = $true
if ($r.LockedOut -eq $true -or $r.AccountExpired -eq $true -or $r.Enabled -eq $false) {
$hasLockedOrExpired = $true
}
}
}

if ($hasError) {
$OutputBox.ForeColor = [System.Drawing.Color]::Red
}
elseif ($hasLockedOrExpired) {
# Orange if we have user(s) but there are locked/expired/disabled
$OutputBox.ForeColor = [System.Drawing.Color]::OrangeRed
}
elseif ($hasFoundUser) {
# All good: user(s) found and no errors or lock/expire/disable
$OutputBox.ForeColor = [System.Drawing.Color]::Green
}
else {
# No results
$OutputBox.ForeColor = [System.Drawing.Color]::Black
}
}

# ------------------------------
# GUI setup
# ------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "AD Multi-Domain One-Click Unlock (V2)"
$form.Size = New-Object System.Drawing.Size(600, 450)
$form.StartPosition = "CenterScreen"

# TabControl
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(10, 10)
$tabs.Size = New-Object System.Drawing.Size(560, 360)
$form.Controls.Add($tabs)

# ==============================
# TAB 1: USER TOOLS
# ==============================
$tabUser = New-Object System.Windows.Forms.TabPage
$tabUser.Text = "User Tools"
$tabs.TabPages.Add($tabUser)

# User label
$labelUser = New-Object System.Windows.Forms.Label
$labelUser.Text = "User ID:"
$labelUser.Location = New-Object System.Drawing.Point(10, 15)
$labelUser.AutoSize = $true
$tabUser.Controls.Add($labelUser)

# User textbox
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

# Copy to clipboard button
$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = "Copy to Clipboard"
$btnCopy.Location = New-Object System.Drawing.Point(120, 45)
$btnCopy.Width = 150
$tabUser.Controls.Add($btnCopy)

# Output textbox (User Tools)
$textOutput = New-Object System.Windows.Forms.TextBox
$textOutput.Location = New-Object System.Drawing.Point(10, 80)
$textOutput.Multiline = $true
$textOutput.ScrollBars = "Vertical"
$textOutput.ReadOnly = $true
$textOutput.Width = 520
$textOutput.Height = 240
$tabUser.Controls.Add($textOutput)

# ==============================
# TAB 2: TROUBLESHOOTING
# ==============================
$tabTools = New-Object System.Windows.Forms.TabPage
$tabTools.Text = "Troubleshooting Tools"
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

# Troubleshooting output textbox
$txtTroubleshoot = New-Object System.Windows.Forms.TextBox
$txtTroubleshoot.Location = New-Object System.Drawing.Point(10, 80)
$txtTroubleshoot.Multiline = $true
$txtTroubleshoot.ReadOnly = $true
$txtTroubleshoot.ScrollBars = "Vertical"
$txtTroubleshoot.Width = 520
$txtTroubleshoot.Height = 240
$tabTools.Controls.Add($txtTroubleshoot)

# Status bar label
$statusBar = New-Object System.Windows.Forms.Label
$statusBar.Location = New-Object System.Drawing.Point(10, 380)
$statusBar.Width = 560
$statusBar.AutoSize = $false
$form.Controls.Add($statusBar)

# Store last status for unlock
$Global:lastStatus = @()

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

$textOutput.Lines = Format-StatusForDisplay $status
Set-StatusColor -OutputBox $textOutput -Results $status

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
Set-StatusColor -OutputBox $textOutput -Results $newStatus

$statusBar.Text = "Unlock attempt complete. Status refreshed."
}
catch {
$textOutput.ForeColor = [System.Drawing.Color]::Red
$textOutput.Lines = @("Error during unlock flow:", $_.Exception.Message)
$statusBar.Text = "Error during unlock."
}
})

# ------------------------------
# Button: Copy to Clipboard
# ------------------------------
$btnCopy.Add_Click({
if (-not [string]::IsNullOrWhiteSpace($textOutput.Text)) {
[System.Windows.Forms.Clipboard]::SetText($textOutput.Text)
$statusBar.Text = "Status text copied to clipboard."
}
else {
$statusBar.Text = "Nothing to copy."
}
})

# ------------------------------
# Troubleshooting: Ping
# ------------------------------
$btnPing.Add_Click({
$target = $txtPingTarget.Text.Trim()
if (-not $target) {
[System.Windows.Forms.MessageBox]::Show("Enter a hostname or IP to ping.","Missing Input")
return
}

$statusBar.Text = "Pinging $target..."
$form.Refresh()

try {
$result = Test-Connection -ComputerName $target -Count 4 -ErrorAction Stop
$avg = ($result | Measure-Object -Property ResponseTime -Average).Average
$txtTroubleshoot.ForeColor = [System.Drawing.Color]::Black
$txtTroubleshoot.Lines = @(
"Ping to $target succeeded.",
"Average response time (ms): " + [math]::Round($avg,2)
)
$statusBar.Text = "Ping complete."
}
catch {
$txtTroubleshoot.ForeColor = [System.Drawing.Color]::Red
$txtTroubleshoot.Lines = @("Ping to $target failed:", $_.Exception.Message)
$statusBar.Text = "Ping failed."
}
})

# ------------------------------
# Troubleshooting: Flush DNS
# ------------------------------
$btnFlushDNS.Add_Click({
$statusBar.Text = "Flushing DNS cache..."
$form.Refresh()

try {
$output = ipconfig /flushdns 2>&1
$txtTroubleshoot.ForeColor = [System.Drawing.Color]::Black
$txtTroubleshoot.Text = $output -join "`r`n"
$statusBar.Text = "DNS cache flushed."
}
catch {
$txtTroubleshoot.ForeColor = [System.Drawing.Color]::Red
$txtTroubleshoot.Text = "Error flushing DNS: $($_.Exception.Message)"
$statusBar.Text = "Error flushing DNS."
}
})

# ------------------------------
# Troubleshooting: IPConfig /all
# ------------------------------
$btnIPConfig.Add_Click({
$statusBar.Text = "Running ipconfig /all..."
$form.Refresh()

try {
$output = ipconfig /all 2>&1
$txtTroubleshoot.ForeColor = [System.Drawing.Color]::Black
$txtTroubleshoot.Text = $output
$statusBar.Text = "ipconfig /all complete."
}
catch {
$txtTroubleshoot.ForeColor = [System.Drawing.Color]::Red
$txtTroubleshoot.Text = "Error running ipconfig: $($_.Exception.Message)"
$statusBar.Text = "Error running ipconfig."
}
})

# ------------------------------
# Show form
# ------------------------------
[void]$form.ShowDialog()

