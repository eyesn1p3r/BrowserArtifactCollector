# BrowserArtifactCollector

**Live Forensic Helper for Browser Artifacts Collection**

[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/eyesn11p3r/BrowserArtifactCollector/blob/main/LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-green.svg)](https://github.com/eyesn11p3r/BrowserArtifactCollector)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue)](https://docs.microsoft.com/en-us/powershell/)

---

## **Purpose**
This PowerShell script is designed for **live forensic acquisition** of browsers artifacts (Chrome, Edge, Firefox). It:
- Collects artifacts for **all users and profiles**.
- Produces a **single evidence `.zip`** file.
- Computes a **SHA256 forensic hash** with metadata.
- Maintains a **separate external transcript/log** for audit purposes.

---

## **Features**
- **Artifacts Collected**:
  - Browsing history
  - Cookies
  - Login data
  - Bookmarks
  - Favicons
  - Local Storage
  - Autofill data
  - Extensions
  - IndexedDB
  - Sessions
- **Outputs**:
  - `Browsers_Artifacts_YYYYMMDD_HHMM.zip` (compressed evidence)
  - `Browsers_Artifacts_YYYYMMDD_HHMM.zip.sha256.txt` (forensic hash record)
  - `collection_log_YYYYMMDD_HHMM.txt` (external transcript)

---

## **Script Parameters**
The script supports the following parameters:

| Parameter       | Type    | Description                                                                                     | Example Usage                          |
|-----------------|---------|-------------------------------------------------------------------------------------------------|----------------------------------------|
| `-Live`         | Switch  | Use **live acquisition mode** (default: enabled if no `-MountedImage` is specified).            | `.\browserArtifactCollector.ps1 -Live` |
| `-MountedImage` | String  | Specify the **root path of a mounted image** (e.g., `"E:\"`). Disables live mode.               | `.\browserArtifactCollector.ps1 -MountedImage "E:\"` |
| `-Output`       | String  | Set the **output directory** for forensic artifacts (default: `"C:\Browsers_Artifacts"`).      | `.\browserArtifactCollector.ps1 -Output "D:\Evidence"` |

---

## **Usage**

### **Prerequisites**
- **Windows 10/11**
- **PowerShell 5.1+**
- **Administrator privileges** (required for live acquisition)

### **Steps**
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/eyesn1p3r/BrowserArtifactCollector.git
   cd BrowserArtifactCollector
   

2. **Run the script (Default Mode)**:  
   Collect browser artifacts from a live system (default output directory: C:\Browsers_Artifacts):
   ```bash
   .\browserArtifactCollector.ps1 -Live