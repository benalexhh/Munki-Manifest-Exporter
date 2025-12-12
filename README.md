# Munki Manifest Exporter

A bash-based utility for macOS Administrators to audit Munki repositories. It parses all manifest files and exports software assignments into readable CSV files (Excel compatible).

## 🚀 Features

*   **Zero Dependencies:** Uses native macOS tools (`plutil`, `bash`). No Python or extra libraries required.
*   **Read-Only:** Does not modify any files in your repository.
*   **Interactive Menu:** Easy to use CLI with progress bars and configuration management.
*   **Smart Filtering:** Distinguishes between Applications (default prefix `app_`) and other objects (printers, settings).
*   **Comprehensive Export:** Generates 4 CSV files:
*   Full assignment list (Where is which app installed?)
*   Clean inventory list (Unique list of all apps)
*   Other objects lists (Configs, Printers, etc.)

## 📋 Prerequisites

*   macOS (tested on macOS 12+)
*   Read access to a Munki Repository (local folder or mounted volume)

## 🛠 Installation & Usage

1.  Clone the repository or download the script:
```bash
git clone https://github.com/YOUR-USERNAME/munki-manifest-exporter.git
cd munki-manifest-exporter
