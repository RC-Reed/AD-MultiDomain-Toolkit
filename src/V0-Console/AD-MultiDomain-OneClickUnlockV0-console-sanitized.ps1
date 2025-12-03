<#
.SYNOPSIS
    AD Multi-Domain One-Click Unlock (Console Version)

.DESCRIPTION
    Console-only version of the tool that:
    - Checks a user across multiple AD domains
    - Shows Enabled / LockedOut / AccountExpired status
    - Optionally unlocks the user in all domains where:
        - User exists
        - Account is enabled
        - Account is locked
        - Account is not expired

    NOTE: All domains are sanitized contoso-style placeholders for public sharing.
          Replace with your real domain controllers if you adapt this.

#>

Import-Module ActiveDirectory

# ------------------------------
# Config: Domains to check (SANITIZED)
# ------------------------------
$Domains = @(
    "corp-ad01.contoso.local",
    "med-ad01.contoso.local",
    "mgmt-ad01.contoso.local",
    "ext-ad01.contoso.local"
)

# ------------------------------
# Function: Get status in all domains
# ------------------------------
function Get-AdUserMultiDomainStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserId
    )

    $now = Get-Date
    $results = @()

    foreach ($domain in $Domains) {
        try {
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
# Function: Pretty-print status
# ------------------------------
function Show-AdUserMultiDomainStatus {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Status
    )

    foreach ($r in $Status) {
        Write-Host "--------------------------------------------------"
        Write-Host "Domain: $($r.Domain)"

        if ($r.Notes) {
            Write-Host "User:   $($r.SamAccountName)"
            Write-Host "Notes:  $($r.Notes)"
        }
        else {
            Write-Host "User:    $($r.SamAccountName)"
            Write-Host "Enabled: $($r.Enabled)"
            Write-Host "Locked:  $($r.LockedOut)"
            Write-Host "Expired: $($r.AccountExpired)"

            if ($r.AccountExpireDate) {
                Write-Host "Account Expiration Date: $($r.AccountExpireDate)"
            }
        }

        Write-Host ""
    }

    if (-not $Status -or $Status.Count -eq 0) {
        Write-Host "No results."
    }
}

# ------------------------------
# Function: Unlock in all domains
# ------------------------------
function Unlock-AdUserAllDomains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Status
    )

    Write-Host "Attempting unlock for user '$UserId' where appropriate..." -ForegroundColor Cyan
    Write-Host ""

    foreach ($r in $Status) {
        # Only try to unlock when:
        # - We actually found the user in that domain (no Notes)
        # - Enabled = True
        # - LockedOut = True
        # - Not expired
        if ($r.Notes -eq "" -and
            $r.Enabled -eq $true -and
            $r.LockedOut -eq $true -and
            $r.AccountExpired -ne $true) {

            try {
                Unlock-ADAccount -Server $r.Domain -Identity $r.SamAccountName -ErrorAction Stop
                Write-Host "[$($r.Domain)] Unlock command sent successfully." -ForegroundColor Green
            }
            catch {
                Write-Host "[$($r.Domain)] Unlock failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        else {
            # Explain why we are not unlocking in this domain
            if ($r.Notes -and $r.Notes -ne "") {
                Write-Host "[$($r.Domain)] Not unlocking: $($r.Notes)" -ForegroundColor Yellow
            }
            elseif ($r.Enabled -eq $false) {
                Write-Host "[$($r.Domain)] Not unlocking: account is disabled." -ForegroundColor Yellow
            }
            elseif ($r.AccountExpired -eq $true) {
                Write-Host "[$($r.Domain)] Not unlocking: account is expired." -ForegroundColor Yellow
            }
            elseif ($r.LockedOut -ne $true -and -not $r.Notes) {
                Write-Host "[$($r.Domain)] Not unlocking: account is not locked." -ForegroundColor DarkGray
            }
        }
    }
}

# ------------------------------
# Main interactive flow
# ------------------------------

# Get user ID
if (-not $UserId) {
    $UserId = Read-Host "Enter the user ID (sAMAccountName)"
}

if ([string]::IsNullOrWhiteSpace($UserId)) {
    Write-Host "No user ID provided. Exiting." -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "Checking multi-domain status for '$UserId'..." -ForegroundColor Cyan
Write-Host ""

$status = Get-AdUserMultiDomainStatus -UserId $UserId
Show-AdUserMultiDomainStatus -Status $status

Write-Host ""
$answer = Read-Host "Do you want to attempt unlock in all appropriate domains? (Y/N)"

if ($answer -match '^[Yy]') {
    Write-Host ""
    Unlock-AdUserAllDomains -UserId $UserId -Status $status

    Write-Host ""
    Write-Host "Re-checking status after unlock..." -ForegroundColor Cyan
    Write-Host ""
    $statusAfter = Get-AdUserMultiDomainStatus -UserId $UserId
    Show-AdUserMultiDomainStatus -Status $statusAfter
}
else {
    Write-Host "No unlock requested. Exiting." -ForegroundColor Yellow
}

