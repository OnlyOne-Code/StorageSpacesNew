
# Storage Spaces Creator

PowerShell script for automated creation and monitoring of Windows Storage Spaces with tiered storage configuration and SSD write cache.

## Features

- **Automated Storage Creation**: Creates tiered storage pool with SSD and HDD tiers
- **SSD Write Cache**: Configures 24GB write cache on SSD for improved performance
- **Health Monitoring**: Comprehensive status monitoring with color-coded indicators
- **Tiered Configuration**: SSD (Simple) + HDD (Mirror) storage tiers
- **Customizable Parameters**: Easily configurable disk selection and storage settings

## Storage Architecture

```text
┌───────────────────────────────────────────────────────────┐
│                    STORAGE SPACES POOL                    │
│                  "Data StoragePool"                       │
├───────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   SSD Disk  │  │   HDD Disk  │  │   HDD Disk  │        │
│  │ Serial: SSD1│  │ Serial: HDD1│  │ Serial: HDD2│        │
│  │  128 GB     │  │   X TB      │  │   X TB      │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└───────────────────────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────┐
│                  VIRTUAL DISK                             │
│              "Data VirtualDisk"                           │
├─────────────────┬─────────────────────────────────────────┤
│   SSD TIER      │              HDD TIER                   │
│                 │                                         │
│ ┌─────────────┐ │ ┌─────────────────────────────────────┐ │
│ │   SIMPLE    │ │ │               MIRROR                │ │
│ │ Resiliency  │ │ │  (Data duplicated across 2 disks)   │ │
│ │             │ │ │                                     │ │
│ │ • 128 GB    │ │ │ • Full HDD capacity                 │ │
│ │ • 16KB      │ │ │ • 16KB interleave                   │ │
│ │   interleave│ │ │ • 1 redundancy copy                 │ │
│ │ • Max speed │ │ │ • Data protection                   │ │
│ └─────────────┘ │ └─────────────────────────────────────┘ │
│                 │                                         │
│   24 GB         │              Auto-sized                 │
│   WRITE CACHE   │              HDD capacity               │
│   (on SSD)      │                                         │
└─────────────────┴─────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────┐
│                    VOLUME "H:\"                           │
│                  File System: NTFS                        │
│                  Cluster Size: 16KB                       │
│                  Label: "Data"                            │
└───────────────────────────────────────────────────────────┘
```

## Data Flow

```
Application Writes
        ↓
    Write Cache (24GB on SSD) ←─ Fast temporary storage
        ↓
Tier Optimization → "Hot" data stays on SSD tier
                    "Cold" data moves to HDD tier
        ↓
    SSD Tier (Simple) ←───────────┐
        │                         │
        ↓ (Auto-tiering)          │
    HDD Tier (Mirror) ←───────────┘
        │                         
        └→ Data mirrored across 2 HDDs for redundancy
```

## Storage Configuration

Creates a two-tier storage system with SSD write cache:
- **SSD Tier**: Simple resiliency (max performance) + 24GB write cache
- **HDD Tier**: Mirror resiliency (data redundancy)

## Configuration

Edit these variables at the top of the script:

```powershell
$SerialNumbers = @(
    "XXXXXXXXXXXXXXX-SSD1",  # Your SSD serial numbers
    "XXXXXXXXXXXXXXX-HDD1",  # Your HDD serial numbers
    "XXXXXXXXXXXXXXX-HDD2"   # Your HDD serial numbers
)
$StoragePoolName = "Data StoragePool"
$VirtualDiskName = "Data VirtualDisk" 
$DriveLetter = "H"
$VolumeName = "Data"
```

## Key Settings

- **Write Cache**: 24GB on SSD
- **SSD Tier**: 128GB, 16KB interleave, Simple resiliency
- **HDD Tier**: Automatic sizing, 16KB interleave, Mirror resiliency  
- **File System**: NTFS with 16KB cluster size

## Usage

1. Update serial numbers in `$SerialNumbers` array
2. Run the script as Administrator:
```powershell
.\StorageSpacesNew.ps1
```

## What It Does

- Identifies disks by serial numbers
- Creates storage pool with specified disks  
- Configures SSD (Simple) tier with 24GB write cache
- Configures HDD (Mirror) tier for data redundancy
- Creates virtual disk with both tiers and write cache
- Formats volume with optimal settings
- Displays comprehensive status report

## Requirements

- Windows 10/11 with Storage Spaces
- PowerShell 5.0+
- Administrative privileges
- Physical disks with known serial numbers

## Status Indicators

- 🟢 **Green**: Healthy/OK (Норма)
- 🟡 **Yellow**: Warning/Degraded (Предупреждение/Деградация)
- 🔴 **Red**: Unhealthy/Error (Неисправен/Ошибка)
