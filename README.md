# PocketPrefs

[![build](https://github.com/DawnLiExp/PocketPrefs/actions/workflows/cl.yml/badge.svg?branch=main)](https://github.com/DawnLiExp/PocketPrefs/actions/workflows/cl.yml)
[![Swift-6](https://img.shields.io/badge/Swift-6-orange?logo=swift&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-MIT-blue)](https://opensource.org/licenses/MIT)

[English](README.md) | [中文](docs/README_zh.md)

PocketPrefs is a configuration management tool for macOS applications. It enables users to easily back up, restore, and manage application configurations and data, simplifying setup when migrating to a new device or reinstalling macOS.

<div style="display: flex; justify-content: space-between; gap: 20px; margin-bottom: 20px;">
  <img src="docs/screenshot1.png" style="border: none; width: 48%;" />
  <img src="docs/screenshot2.png" style="border: none; width: 48%;" />
</div>
<div style="display: flex; justify-content: space-between; gap: 20px;">
  <img src="docs/screenshot3.png" style="border: none; width: 48%;" />
  <img src="docs/screenshot4.png" style="border: none; width: 48%;" />
</div>

💡 Besides app settings, you can back up any file via custom paths.

## Features

- Backup and restore macOS application configurations and specified data
- Add and manage custom application configuration paths
- Import and export custom application configuration lists
- Incremental backup mode support

## 📦 Configuration Sharing

Here's my custom configs JSON (importable): <a href="https://github.com/DawnLiExp/PocketPrefs/discussions/1" target="_blank">discussion</a>

## Data Security ⚠️

PocketPrefs uses the following strategy to protect existing configurations when restoring files:

### Design Principles

- **Data integrity:** Before restoring configuration files, PocketPrefs first renames any existing configuration in the target directory to `[original_name].pocketprefs_backup` to preserve the original state.

### Operation Details

When performing a restore operation, PocketPrefs intelligently handles existing files or directories at the target path:

1. **Existing configuration backup:** If a file or directory with the same name already exists at the target path (for example, `~/Library/Application Support/Code/User/settings.json` or `~/Library/Application Support/Code/User/`), PocketPrefs renames it to `[original_name].pocketprefs_backup`.  
   - **Example:** `settings.json` becomes `settings.json.pocketprefs_backup`.  
   - **Example:** `User/` directory becomes `User.pocketprefs_backup/`.

2. **New configuration restoration:** The file or directory from the backup is then restored to the original target path.

**Important Note:**

- `.pocketprefs_backup` files or directories only preserve the configuration state from the **most recent restore operation**. Each new restore operation will overwrite this backup.

## System Requirements

- macOS 14+

## Building

- Xcode 16+
- Swift 6
