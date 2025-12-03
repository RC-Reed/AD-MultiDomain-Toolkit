# AD Multi-Domain Toolkit

### *A modular PowerShell Active Directory toolkit with a multi-tab GUI for cross-domain account diagnostics and unlock workflows.*

---

## Overview

The **AD Multi-Domain Toolkit** is a PowerShell-based graphical utility designed to streamline troubleshooting and user account operations across **multiple Active Directory domains**.

Originally developed as a **console script**, the project evolved into a fully modular **WinForms GUI application** supporting:

* Multi-domain user status checks
* One-click unlocks
* Password & logon information
* Live domain controller scanning
* Built-in troubleshooting tools
* Launchers for commonly used support applications

This repository contains **sanitized versions (V0–V6)** rewritten using generic domain names and placeholder paths while preserving the structure, logic, and engineering work.

---

## Purpose

This toolkit represents a hybrid of:

### **🛡 Cybersecurity practices**

* Safely querying user status
* Validation logic to prevent unintended actions
* Accurate logon data pulled directly from domain controllers

### **🛠 IT Support / IAM workflow automation**

* Designed to assist first-level and IAM technicians
* Centralizes common troubleshooting steps
* Reduces repetitive manual AD tasks
* Provides clear and consistent diagnostic output

The result is a practical, real-world tool built to improve efficiency, accuracy, and support coverage in multi-domain enterprise environments.

---

## 🧱 Architecture Summary

Below is a high-level overview of how the toolkit is structured:

```
┌──────────────────────────────────────┐
│            WinForms GUI              │
│  ┌────────────┬──────────────┬──────┘
│  │ User Tools │  Tools Tab   │  DC Scan
└──┴────────────┴──────────────┴────────────────────┐

          Core PowerShell Logic
          • Multi-domain queries
          • Safe unlock operations
          • Error handling layers
          • Password/logon attributes
          • Domain controller enumeration

          Troubleshooting Module
          • Ping & network tests
          • DNS cache clearing
          • Teams cache reset
          • Office/Explorer repairs

          Launch Tools Module
          • Placeholder shortcuts
          • Placeholder file shares
          • Disabled remote shell tool (removed due to workplace policy)

          Sanitization Layer
          • Placeholder domains
          • Placeholder application paths
          • Removed proprietary references
```

More detail is available in:
➡ `docs/Architecture.md`

---

## 🗂 Repository Structure

```text
AD-MultiDomain-Toolkit/
├─ README.md
├─ src/
│  ├─ V0-Console/
│  ├─ V1-GUI/
│  ├─ V2-GUI-Troubleshooting/
│  ├─ V3-GUI-Color/
│  ├─ V4-Password-Info/
│  ├─ V5-Tools-Launcher/
│  └─ V6-DC-Scan/
└─ docs/
   ├─ Architecture.md
   ├─ Version-History.md
   ├─ Troubleshooting-Tools.md
   ├─ Redaction-Notes.md
   └─ Lessons-Learned.md
```

Each version folder contains one sanitized `.ps1` file representing that stage of development.

---

## 🕒 Evolution Timeline (High-Level)

This project includes **all major iterations**, from the earliest prototype to the final advanced version:

| Version                                  | Description                                                          |
| ---------------------------------------- | -------------------------------------------------------------------- |
| **V0 — Console Only**                    | Multi-domain status checks and unlocks using Write-Host output.      |
| **V1 — First GUI**                       | Basic WinForms interface with “Check Status” and “Unlock.”           |
| **V2 — GUI + Troubleshooting**           | Added ping, DNS flush, Teams repair, Office reset, Explorer restart. |
| **V3 — UI Stabilization + Color Coding** | Polish and status color logic.                                       |
| **V4 — Password & Logon Module**         | Added last bad password, lockout time, last logon timestamp.         |
| **V5 — Tools Launcher Tab**              | Added app launchers (RSA, BigFix, shares) using placeholder paths.   |
| **V6 — Domain Controller Scan**          | Added authoritative logon data by enumerating all DCs.               |

A full breakdown is provided in:
➡ `docs/Version-History.md`

---

## 🔐 Sanitization Notice

All sensitive or proprietary information has been removed, including:

* Domain names
* Server names
* Internal URLs
* File shares
* Vendor tool paths
* Company-specific strings

Generic placeholders are used instead.
A list of redaction rules is provided in:
➡ `docs/Redaction-Notes.md`

---

## 🚀 Future Enhancements

*(TBD)*

