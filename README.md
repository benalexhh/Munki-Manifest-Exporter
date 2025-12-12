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
```

2.  Make the script executable:
```bash
chmod +x munki_audit_en.sh
```

3.  Run the tool:
```bash
./munki_audit_en.sh
```

4.  Follow the on-screen instructions. On first run, select **Settings (2)** and enter the path to your Munki Repository **root** folder.

## 📂 Output

The script generates the following files in the current directory:

| Filename | Description |
| :--- | :--- |
| `Export_Apps_Complete.csv` | List of every app assignment, linked to its manifest path. |
| `Export_Apps_Unique_Clean.csv` | A simple list of unique app names (prefix removed). Ideal for inventory. |
| `Export_Others_Complete.csv` | List of non-app objects (configs, included_manifests). |
| `Export_Others_Unique.csv` | Unique list of non-app objects. |

**Note for Excel Users:** The CSV files use a semicolon `;` delimiter to ensure correct formatting in European Excel versions. If your Excel uses commas, you might need to use "Data -> Import from Text/CSV".

## ⚙️ Configuration

The script saves your repository path in a hidden file in your home directory: `~/.munki_audit.conf`. You can change the path anytime via the script menu.

To change the Application Prefix (Default: `app_`), edit the top of the script:
```bash
PREFIX="app_"
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
