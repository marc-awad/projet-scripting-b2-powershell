# Active Directory User Management Tool

A PowerShell script for managing Active Directory users based on CSV data.

## Requirements

- Windows Server with Active Directory Domain Services
- PowerShell with AD module
- Administrative privileges

## Setup

Before running the script:

1. Set the required environment variables:
   ```powershell
   $env:CSV_FILE_PATH = "C:\Path\to\your\users.csv"
   ```

2. Make sure you have the Active Directory PowerShell module installed:
   ```powershell
   Install-WindowsFeature -Name RSAT-AD-PowerShell
   ```

3. Ensure you have write permissions to `C:\PerfLogs\` for log files

## CSV File Format

The CSV file should use the pipe character (`|`) as delimiter and contain:
```
Name|ID|Position|Country
John|001|Developer|France
Jane|002|Manager|Germany
```

## Features

### 1. Create User Accounts from CSV
- Creates Organizational Units (OUs) based on Country and Position
- Creates user accounts with secure passwords
- Places users in appropriate OUs
- Logs all operations

### 2. Disable User Accounts
- Allows disabling specific users by SAM account name
- Updates logs with disabled account information

### 3. Remove Inactive Accounts
- Automatically removes accounts disabled for more than 90 days
- Includes logging functionality

## Usage

Run the script and select from the menu options:
```powershell
.\ADUserManagement.ps1
```

Menu options:
1. Create users from CSV file
2. Disable a user
3. Delete users disabled for more than 90 days
4. View user management log
5. View error log
6. Exit

## Logs

The script maintains two log files:
- User creation/management: `C:\PerfLogs\user_creation_log.txt`
- Error logs: `C:\PerfLogs\error_log.txt`

## Notes

- Default password for new users is "P@ssw0rd!" with forced change at first logon
- The script creates a base OU called "ScriptingLocal" under your domain
