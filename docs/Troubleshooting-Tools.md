# 🛠 Troubleshooting Tools

### *Detailed explanation of the auxiliary support tools built into the AD Multi-Domain Toolkit.*

Starting in **Version 2**, the toolkit added a dedicated *Troubleshooting* tab designed to address frequent workstation issues encountered by first-level support, IAM technicians, or helpdesk analysts.

This document explains each function, its purpose, and the technical approach.
All functions have been sanitized for safe public use.

---

# 🔷 1. Overview

The troubleshooting module acts as a **local support utility**, allowing technicians to quickly run system repairs without leaving the toolkit.

It includes:

* Network testing
* DNS repairs
* Client application resets
* Cache cleanup tools
* Explorer / shell restarts
* Generic system diagnostics

Each tool uses native PowerShell + built-in Windows utilities to avoid external dependencies.

---

# 🔷 2. Design Principles

The troubleshooting suite was built around four principles:

### **1. Quick Access**

Important commands are wrapped into single-button functions.

### **2. Safety**

All commands operate at user-level or safe admin-level functionality.

### **3. Clarity**

Output is routed into the GUI’s text window with consistent formatting.

### **4. Independence**

Troubleshooting actions cannot affect AD unlock logic or domain queries.

---

# 🔷 3. Tools Included in the Toolkit

Below is a breakdown of each tool, including its real-life purpose and how it’s implemented internally.

---

# 🟦 3.1 Ping Test

**Purpose:**
Quickly determine if the workstation can reach a given server, domain controller, or external host.

**Implementation:**

```powershell
Test-Connection -Count 4
```

* Uses native ICMP echo requests
* Helps diagnose network isolation, VPN issues, or outages

---

# 🟦 3.2 DNS Flush

**Purpose:**
Clear DNS resolver cache to fix issues where machines are resolving stale or incorrect IP addresses.

**Implementation:**

```powershell
ipconfig /flushdns
```

Common issues this resolves:

* Can't reach internal servers
* Login to apps timing out
* Name resolution failures
* VPN or Wi-Fi network transitions

---

# 🟦 3.3 IPConfig /All

**Purpose:**
Display the full network configuration for quick diagnostics.

**Implementation:**

```powershell
ipconfig /all
```

This is commonly used to identify:

* Wrong DNS servers
* Expired DHCP leases
* Multiple NICs conflicting
* Incorrect network routes

---

# 🟦 3.4 Microsoft Teams Cache Reset

**Purpose:**
Fixes cases where Teams will not launch, login, or loads a blank screen.

**Implementation:**
(Sanitized path)

```powershell
Stop-Process -Name "Teams" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:APPDATA\Microsoft\Teams\*" -Recurse -Force
```

This resolves:

* Login loop issues
* “White screen” on launch
* Frozen UI
* Update glitches

---

# 🟦 3.5 Office Applications Repair

**Purpose:**
Restarts Office apps & clears certain temp states to resolve:

* Stuck authentication
* “Something went wrong” messages
* Frozen Office apps

**Implementation (sanitized):**

```powershell
Get-Process | Where-Object { $_.Name -like "WINWORD" -or $_.Name -like "EXCEL" -or $_.Name -like "OUTLOOK" } |
    Stop-Process -Force
```

More advanced repairs were kept out of the repo for security reasons.

---

# 🟦 3.6 Windows Explorer Restart

**Purpose:**
Fixes UI issues such as:

* Frozen File Explorer
* Missing taskbar icons
* Context menu lag
* Shell errors

**Implementation:**

```powershell
Stop-Process -Name "explorer" -Force
Start-Process "explorer.exe"
```

Safe and fast recovery tool.

---

# 🟦 3.7 Local Cache Cleanup (General)

**Purpose:**
Certain versions included cache cleanup for apps with known issues.
(This is fully sanitized and high-level only.)

Used to resolve:

* Corrupted config files
* Authentication loops
* Temporary file corruption

No sensitive or workplace-specific paths are included in this repository.

---

# ❗ 3.8 Removed Tool — Remote Shell Launcher

**Purpose (original in V2/V3):**
Open a remote PowerShell session for deeper diagnostics.

Removed because:

*  employer **did not enable or permit WinRM remote shell**

**This removal was intentional.**

---

# 🔷 4. Technical Notes

### ✔ All tools run locally

No domain-level changes.
No remote system actions.
No elevated privilege operations without user permission.

### ✔ Commands are wrapped with:

* Error handling
* Output redirection
* GUI-safe updates

### ✔ Troubleshooting tools are isolated

They cannot affect AD-focused modules.
This maintains safety & stability.

---

# 🔷 5. Why These Tools Matter (Professional Impact)

These tools:

* Reduce average handling time for tickets
* Remove the need to memorize dozens of commands
* Ensure consistent troubleshooting across a team
* Make helpdesk technicians significantly more efficient
* Show ability to build **full workflow support tools**, not just scripts

