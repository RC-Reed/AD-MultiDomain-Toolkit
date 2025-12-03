# 🔐 Redaction Notes

### *How sensitive information was sanitized while preserving technical accuracy.*

This repository is a **sanitized portfolio version** of a real PowerShell Active Directory tool used in a multi-domain enterprise environment.
All sensitive identifiers, systems, and paths have been removed or replaced to comply with security best practices and employer confidentiality policies.

This document outlines **exactly what has been redacted** and **how the code was safely transformed** for public presentation.

---

# 🔷 1. Domains & Forest Structure

### **Original:**

Real enterprise Active Directory domain names, forest names, and server hostnames.

### **Sanitized To:**

Generic AD-safe placeholders:

```
corp-ad01.contoso.local
med-ad01.contoso.local
mgmt-ad01.contoso.local
ext-ad01.contoso.local
```

### **Reason:**

Domain names and server FQDNs often reveal internal architecture, naming conventions, or network segmentation.

---

# 🔷 2. Server Names, Controller Names, and Internal Hosts

### **Original:**

* Domain controllers
* Application servers
* Internal troubleshooting servers
* Other infrastructure nodes

### **Sanitized To:**

All references are replaced with generic labels:

```
<AD-Domain-Controller>
<Placeholder-Server>
<Sanitized-Host>
```

### **Reason:**

Server naming schemes can expose network topology or internal security layout.

---

# 🔷 3. Internal Application Paths & Executables

### **Original:**

Paths pointing to:

* RSA Console
* Internal tools
* Remote management apps
* Enterprise diagnostic utilities
* Shared drive shortcuts

### **Sanitized To:**

All paths use safe pseudo examples such as:

```
"C:\Tools\RSA-Console.exe"
"C:\Program Files\SupportTools\Tool.exe"
"\\fileshare\support\docs"
```

### **Reason:**

Real UNC paths or internal apps may allow inference of internal resources or vendor partnerships.

---

# 🔷 4. Removed Feature — Remote Shell Tool

### **Original:**

The early version included a button for opening a remote shell into another machine using PowerShell Remoting (WinRM).

### **What Happened:**

* organization **did not enable WinRM** (security policy)

### **Reason:**

Remote execution tools can appear risky, and including them may give recruiters the wrong idea about scope.

---

# 🔷 5. Internal URLs & Web-Based Tools

### **Original:**

* Password Manager portal links
* ITSM tools
* Company login pages
* Web-based admin tools

### **Sanitized To:**

Generic placeholder URLs:

```
https://contoso-tools.local
https://support.contoso.local
```

### **Reason:**

Internal URLs could expose information about internal authentication or SSO tools.

---

# 🔷 6. File Shares / Network Paths

### **Original:**

UNC paths used for:

* Standards documents
* Shared support tools
* Team resources

### **Sanitized To:**

```
\\contoso\shared\support
```

### **Reason:**

UNC shares often directly map to sensitive storage infrastructure.

---

# 🔷 7. Usernames, Groups, Admin Units

**None** of your real usernames or group names appear in this repo.
Your own workstation details or accounts were intentionally excluded.

---

# 🔷 8. Logon Data & Password Timestamps

The code preserves the **logic** but not the **real data**.

Exposed AD attributes include only **publicly documented, non-sensitive fields**, such as:

* `Enabled`
* `LockedOut`
* `lastLogon`
* `badPwdCount`
* `badPasswordTime`
* `AccountExpirationDate`

These attributes are safe to use in demos and do not expose proprietary information.

---

# 🔷 9. Removed / Sanitized Error Messages

### **Original:**

Some versions contained real environment-specific AD errors.

### **Sanitized:**

All messages standardized to safe forms like:

```
"Error: <error message>"
"User not found in this domain."
```

This avoids leakage of internal AD structure.

---

# 🔷 10. Removed Comments & Internal Notes

Any internal troubleshooting notes, team names, or workflow-specific comments have been:

* Removed
* Replaced
* Generalized

Examples sanitized:

```
# Check Domain 1 instead of <real domain>
# Launch support tool (placeholder)
```

---

# 🔷 11. Security Impact Summary

All sanitized code:

* Is **safe for public display**
* Does **not** reveal internal company information
* Follows security best practices for redaction
* Preserves your engineering work for portfolio purposes
* Demonstrates PowerShell, AD, GUI, and IAM skill without risk


