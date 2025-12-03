# 📘 Version History

### *Detailed evolution of the AD Multi-Domain Toolkit from V0 → V6.*

This project demonstrates a full engineering lifecycle: starting from a minimal console script, expanding into a sophisticated multi-tab GUI, and refining features based on real-world constraints.

---

# 🔵 **V0 — Console-Only Version**

**(Initial Prototype)**
**Folder:** `/src/V0-Console/`

### ✔ Added

* Multi-domain user lookup
* Console-based status reporting (`Write-Host`)
* Basic logic for:

  * Enabled / Disabled
  * LockedOut
  * Account Expiration
* First implementation of “unlock across domains”

### 🎯 Purpose

Create a simple way to check/unlock AD accounts across multiple domains without manually switching domain controllers.

### 🧠 Skills Demonstrated

* Raw PowerShell AD querying
* Error handling
* Multi-domain identity search
* Unlock workflow shaping

---

# 🔵 **V1 — First GUI Prototype (WinForms)**

**Folder:** `/src/V1-GUI/`

### ✔ Added

* WinForms GUI (first UI)
* Textbox input for user ID
* Buttons: **Check Status** + **Unlock All Domains**
* Multi-line output window
* Basic status messages in GUI

### ❗ Not Yet Added

* Troubleshooting tools
* Tabs
* Color indicators
* Password info

### 🧠 Skills Demonstrated

* PowerShell WinForms basics
* GUI event handling
* Connecting backend logic to UI components

---

# 🔵 **V2 — Troubleshooting Tools + Tab Layout**

**Folder:** `/src/V2-GUI-Troubleshooting/`

### ✔ Added

* **New “Troubleshooting” Tab**

  * Ping test
  * DNS flush
  * Teams cache reset
  * Office app repair
  * Explorer restart
  * IPConfig /all

* Multi-tab interface

* Standardized output handling

### ❗ Feature Removed

* Remote Shell tool: **removed later** due to workplace restrictions (no WinRM/remote PS).

### 🧠 Skills Demonstrated

* Multi-tab GUIs
* Systems support automation
* PowerShell + WinForms integration
* Real-world tool design under policy constraints

---

# 🔵 **V3 — Visual Improvements + Status Color Coding**

**Folder:** `/src/V3-GUI-Color/`

### ✔ Added

* Status Color Indicator logic:

  * 🟢 Green → OK
  * 🟠 Orange → Not found in any domain
  * 🔴 Red → Errors, lockouts, expired accounts

* Improved formatted status output

* Cleaner UI layout

* Beginning of a more structured codebase

### 🧠 Skills Demonstrated

* UX considerations
* Improved error clarity
* Better presentation of data for technicians

---

# 🔵 **V4 — Password & Logon Information Module**

**Folder:** `/src/V4-Password-Info/`

### ✔ Added

* Additional AD attributes:

  * `badPwdCount`
  * `badPasswordTime`
  * `lastLogonTimestamp`
  * `lockoutTime`
* Domain-specific password attribute lookup

### ❗ Behavior Change

* Unlock button now checks password-related conditions before unlocking
* Helped prevent unnecessary or incorrect unlock attempts

### 🧠 Skills Demonstrated

* Understanding of AD logon attributes
* Accurate timestamp conversion
* Security-oriented account analysis

---

# 🔵 **V5 — Tools Launcher Tab (App Integrations)**

**Folder:** `/src/V5-Tools-Launcher/`

### ✔ Added

A new tab containing **launchers** for commonly used technician tools:

* RSA consoles (four domains)
* BigFix Remote
* Document share links
* Password manager
* Placeholder versions now used in sanitized repo

### ❗ Removed

* Remote Shell launcher (policy restraint)

### 🧠 Skills Demonstrated

* Cross-application integration
* Using PowerShell to launch executables/shortcuts
* UI expansion for technician workflows

---

# 🔵 **V6 — Full Domain Controller Scan (Advanced Version)**

**Folder:** `/src/V6-DC-Scan/`

### ✔ Added

**Authoritative multi-DC logon scanning**, pulling from:

* `Get-ADDomainController -Filter *`
* `lastLogon`
* `badPwdCount`
* `badPasswordTime`

This provides the **real, replicated-safe last logon**, not the timestamp approximation.

### ✔ Also Improved

* Output structuring
* Error resilience
* Final UI polish
* Stability improvements

### 🧠 Skills Demonstrated

* Deep AD domain controller knowledge
* Accurate directory attribute aggregation
* Enterprise-grade diagnostics
* Advanced PowerShell design patterns

---

# 🟣 Summary of Evolution

| Version | Focus                 | Outcome                                     |
| ------- | --------------------- | ------------------------------------------- |
| **V0**  | Console prototype     | Multi-domain AD checks + unlock in terminal |
| **V1**  | Initial GUI           | Basic user tools in WinForms                |
| **V2**  | Troubleshooting       | Full support toolkit, multi-tab GUI         |
| **V3**  | UX Improvements       | Color logic + cleaner UI                    |
| **V4**  | Logon/Password module | More accurate account insights              |
| **V5**  | Technician Tools      | Integrated launcher panel                   |
| **V6**  | Advanced Diagnostics  | Full DC scan for authoritative last logon   |

---

# 🟦 Notes on Sanitization

All versions in this repository:

* Use placeholder domain names
* Use replaced (sanitized) server names
* Exclude proprietary files and internal tool paths
* Reflect real engineering work without exposing protected data

Full redaction notes:
➡ `docs/Redaction-Notes.md`


