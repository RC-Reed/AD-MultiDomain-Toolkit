# 🏗 Architecture

### *Technical breakdown of the AD Multi-Domain Toolkit components and flow.*

This document provides a high-level overview of how the toolkit works, how its modules interact, and why each part exists.
It is intentionally sanitized and avoids referencing any proprietary systems.

---

# 🔷 1. Architectural Goals

The toolkit was designed to solve a common enterprise problem:

> **Technicians must check and unlock user accounts across multiple Active Directory domains quickly, safely, and consistently.**

The architecture focuses on:

* **Speed** (faster than GUI-based consoles)
* **Accuracy** (pulling authoritative AD data)
* **Consistency** (same workflow across domains)
* **Safety** (guardrails preventing dangerous actions)
* **Ease of use** (simple GUI for first-level support)

---

# 🔷 2. High-Level System Diagram

```
                    ┌────────────────────────────────────┐
                    │            WinForms GUI             │
                    │────────────────────────────────────│
                    │  User Tools   | Troubleshooting | Tools | DC Scan │
                    └────────────────────────────────────┘
                                   │
                                   ▼
                   ┌────────────────────────────────────┐
                   │       Core Script Logic Layer       │
                   │────────────────────────────────────│
                   │  • Multi-domain querying           │
                   │  • Unified status model            │
                   │  • Unlock operations (guarded)     │
                   │  • Error handling                  │
                   └────────────────────────────────────┘
                                   │
                                   ▼
                   ┌────────────────────────────────────┐
                   │     Active Directory Interaction    │
                   │────────────────────────────────────│
                   │  • Get-ADUser                      │
                   │  • Unlock-ADAccount                │
                   │  • Domain controller scanning      │
                   │  • Password/logon timestamps       │
                   └────────────────────────────────────┘
```

---

# 🔷 3. Core Components

Below are the 6 major architectural components and what each does.

---

## **3.1 WinForms GUI Layer**

Implemented using:

```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
```

The GUI has multiple tabs (depending on the version):

### ✔ User Tools

* Username input
* Check Status button
* Unlock button
* Output text area
* Status color indicator

### ✔ Troubleshooting Tools (V2+)

* Ping test
* DNS flush
* Teams cache reset
* Office reset
* Explorer restart

### ✔ Tools Launcher (V5+)

* External shortcut launchers (sanitized in repo)

### ✔ Domain Controller Scan Tab (V6+)

* Per-DC last logon retrieval
* Replication-safe logon data

The GUI layer sends user actions to the **Core Script Logic Layer**.

---

## **3.2 Core Logic Layer (Backend Engine)**

This is the “brain” of the application.

It handles:

* Multi-domain user search
* Status model creation
* Unlock logic
* Formatting results
* Interpreting AD attributes
* Error handling

Every domain lookup returns a standardized status object:

```powershell
[PSCustomObject]@{
    Domain            = $domain
    SamAccountName    = $user.SamAccountName
    Enabled           = $user.Enabled
    LockedOut         = $user.LockedOut
    AccountExpired    = $acctExpired
    AccountExpireDate = $acctExpDate
    Notes             = ""
}
```

This ensures the GUI always receives clean, consistent data.

---

## **3.3 Multi-Domain Search Engine**

At the heart of the tool lies this loop:

```powershell
foreach ($domain in $Domains) {
    Get-ADUser -Server $domain -Identity $UserId -Properties ...
}
```

Each domain is queried independently, which provides:

* Parallel logic (fast)
* Fault tolerance (one domain outage doesn’t break the tool)
* Clear “found/not found” mapping
* Locked/expired/disabled detection per domain

This structure is consistent across **all versions**.

---

## **3.4 Unlock Guardrail System**

Unlocking is never blind.
The operation only runs if all conditions are met:

### ✔ User exists in that domain

### ✔ `Enabled = $true`

### ✔ `LockedOut = $true`

### ✔ Account is not expired

### ✔ No notes (errors) present

Example logic:

```powershell
if ($r.Notes -eq "" -and 
    $r.Enabled -eq $true -and 
    $r.LockedOut -eq $true -and 
    $r.AccountExpired -ne $true) {
        Unlock-ADAccount ...
}
```

This ensures:

* No unlock attempts against non-existent accounts
* No unlocks on disabled accounts
* No unlocks on expired accounts
* No unlocks on error states

This design mirrors real-world IAM safety requirements.

---

## **3.5 Troubleshooting Module (V2+)**

A dedicated module that runs local machine fixes technicians need often:

* `Test-Connection`
* `ipconfig /flushdns`
* Teams cleanup
* Office reset
* Explorer restart

This module is isolated so troubleshooting tools never interfere with AD operations.

---

## **3.6 Domain Controller Scan Module (V6)**

The most advanced architectural piece.

### How it works:

1. Finds all domain controllers:

   ```powershell
   Get-ADDomainController -Filter *
   ```

2. Polls each DC directly for attributes:

   * `lastLogon` (most accurate)
   * `badPwdCount`
   * `badPasswordTime`

3. Aggregates results and identifies:

   * Most recent logon
   * Most recent bad password
   * Cross-DC mismatches (replication timing)

This gives an IAM technician **true, authoritative logon insight**, which the standard `lastLogonTimestamp` alone cannot provide.

---

# 🔷 4. Data Flow Diagram

```
        User Input (username)
                  │
                  ▼
         ┌───────────────────┐
         │   User Tools Tab  │
         └───────────────────┘
                  │
                  ▼
        ┌──────────────────────┐
        │   Core Logic Layer   │
        └──────────────────────┘
                  │
                  ▼
     ┌──────────────────────────────┐
     │ Multi-Domain Query Engine    │
     │  for each $Domain in $Domains│
     └──────────────────────────────┘
                  │
                  ▼
   ┌─────────────────────────────────────┐
   │ Standardized Status Objects (array) │
   └─────────────────────────────────────┘
                  │
                  ▼
     ┌──────────────────────────┐
     │ GUI Output Formatter     │
     └──────────────────────────┘
                  │
                  ▼
     ┌──────────────────────────┐
     │ User Sees Structured Data│
     └──────────────────────────┘
```

---

# 🔷 5. Security & Redaction Architecture

This repo uses:

* **Placeholder domains**
* **Placeholder paths**
* **Removed proprietary URLs**
* **No internal system references**
* **No remote shell or sensitive tools**

Original design concepts are preserved without exposing:

* Internal infrastructure
* Vendor-specific integrations
* Privileged tools
* Business logic tied to your employer

---

# 🔷 6. Why This Architecture Matters

This project demonstrates:

### ✔ Real-world IT/IAM engineering

Not just a school or lab script — iterative upgrades to support a team.

### ✔ Understanding of AD internals

DC replication behavior, account lockout mechanics, and password attributes.

### ✔ Solid PowerShell engineering

Modules, UI separation, formatted output, custom objects, safe logic.

### ✔ Professional software evolution

From prototype → product-level tool.


