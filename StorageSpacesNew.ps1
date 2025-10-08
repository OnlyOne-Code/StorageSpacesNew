# StorageSpacesNew.ps1

# Переменные для создания
$SerialNumbers = @(
    "XXXXXXXXXXXXXXX-SSD1",
    "XXXXXXXXXXXXXXX-HDD1", 
    "XXXXXXXXXXXXXXX-HDD2"
)
$StoragePoolName = "Data StoragePool"
$VirtualDiskName = "Data VirtualDisk"
$DriveLetter = "H"
$VolumeName = "Data"
$WriteCacheSize = 24GB
$SSDTierMaxSize = 128GB
$SSDInterleave = 16KB
$HDDInterleave = 16KB
$FSClusterSize = 16KB

function Get-StatusColor {
    param([string]$Status)
    switch ($Status) {
        "Healthy" { "Green" }
        "OK" { "Green" }
        "Warning" { "Yellow" }
        "Unhealthy" { "Red" }
        "Error" { "Red" }
        "Degraded" { "Yellow" }
        default { "White" }
    }
}

function Get-StatusDescription {
    param([string]$Status)
    switch ($Status) {
        "Healthy" { "Норма" }
        "OK" { "Норма" }
        "Warning" { "Предупреждение" }
        "Unhealthy" { "Неисправен" }
        "Error" { "Ошибка" }
        "Degraded" { "Деградация" }
        "Read/Write" { "Чтение/Запись" }
        "Read-Only" { "Только чтение" }
        "None" { "Нет" }
        default { $Status }
    }
}

function Show-StorageInfo {
    # Storage Pool Information
    Write-Host "=== Storage Pool Information ===" -ForegroundColor Green

    $poolInfo = Get-StoragePool -FriendlyName $StoragePoolName -ErrorAction SilentlyContinue
    if ($poolInfo) {
        $healthColor = Get-StatusColor $poolInfo.HealthStatus
        $opStatusColor = Get-StatusColor $poolInfo.OperationalStatus
        
        Write-Host "Name: $($poolInfo.FriendlyName)" -ForegroundColor White
        Write-Host "Health Status: $($poolInfo.HealthStatus) ($(Get-StatusDescription $poolInfo.HealthStatus))" -ForegroundColor $healthColor
        Write-Host "Operational Status: $($poolInfo.OperationalStatus) ($(Get-StatusDescription $poolInfo.OperationalStatus))" -ForegroundColor $opStatusColor
        Write-Host "Physical Sector Size: $($poolInfo.PhysicalSectorSize) bytes" -ForegroundColor Gray
        Write-Host "Logical Sector Size: $($poolInfo.LogicalSectorSize) bytes" -ForegroundColor Gray
        
        # Физические диски в пуле
        $physicalDisks = $poolInfo | Get-PhysicalDisk
        Write-Host "`nPhysical Disks ($($physicalDisks.Count)):" -ForegroundColor Yellow
        foreach ($disk in $physicalDisks) {
            $diskHealthColor = Get-StatusColor $disk.HealthStatus
            $diskOpStatusColor = Get-StatusColor $disk.OperationalStatus
            
            Write-Host "  $($disk.FriendlyName)" -ForegroundColor White
            Write-Host "    Media Type: $($disk.MediaType)" -ForegroundColor Gray
            Write-Host "    Size: $([math]::Round($disk.Size / 1GB, 2)) GB" -ForegroundColor Gray
            Write-Host "    Physical Sector Size: $($disk.PhysicalSectorSize) bytes" -ForegroundColor Gray
            Write-Host "    Logical Sector Size: $($disk.LogicalSectorSize) bytes" -ForegroundColor Gray
            Write-Host "    Operational Status: $($disk.OperationalStatus) ($(Get-StatusDescription $disk.OperationalStatus))" -ForegroundColor $diskOpStatusColor
            Write-Host "    Health Status: $($disk.HealthStatus) ($(Get-StatusDescription $disk.HealthStatus))" -ForegroundColor $diskHealthColor
        }
    } else {
        Write-Host "Storage Pool '$StoragePoolName' not found" -ForegroundColor Red
    }

    Write-Host ""

    # Virtual Disk Information
    Write-Host "=== Virtual Disk Information ===" -ForegroundColor Green

    $vdInfo = Get-VirtualDisk -FriendlyName $VirtualDiskName -ErrorAction SilentlyContinue
    if ($vdInfo) {
        $healthColor = Get-StatusColor $vdInfo.HealthStatus
        $opStatusColor = Get-StatusColor $vdInfo.OperationalStatus
        $accessDescription = Get-StatusDescription $vdInfo.Access
        $detachedDescription = Get-StatusDescription $vdInfo.DetachedReason
        
        Write-Host "Name: $($vdInfo.FriendlyName)" -ForegroundColor White
        Write-Host "Health Status: $($vdInfo.HealthStatus) ($(Get-StatusDescription $vdInfo.HealthStatus))" -ForegroundColor $healthColor
        Write-Host "Operational Status: $($vdInfo.OperationalStatus) ($(Get-StatusDescription $vdInfo.OperationalStatus))" -ForegroundColor $opStatusColor
        Write-Host "Access: $($vdInfo.Access) ($accessDescription)" -ForegroundColor White
        Write-Host "Detached Reason: $($vdInfo.DetachedReason) ($detachedDescription)" -ForegroundColor $(if($vdInfo.DetachedReason -ne "None"){"Yellow"}else{"Gray"})
        Write-Host "Size: $([math]::Round($vdInfo.Size / 1GB, 2)) GB" -ForegroundColor White
        Write-Host "Write Cache Size: $([math]::Round($vdInfo.WriteCacheSize / 1GB, 2)) GB" -ForegroundColor White
        Write-Host "Is Tiered: $($vdInfo.IsTiered)" -ForegroundColor White
        
        # Проверка деградации через CIM
        $cimVD = Get-CimInstance -Namespace Root\Microsoft\Windows\Storage -ClassName MSFT_VirtualDisk -Filter "FriendlyName='$VirtualDiskName'" -ErrorAction SilentlyContinue
        if ($cimVD -and $cimVD.NumberOfAvailableCopies) {
            Write-Host "Number of Available Copies: $($cimVD.NumberOfAvailableCopies)" -ForegroundColor White
        }
        
        if ($vdInfo.IsTiered) {
            # Для tiered виртуальных дисков
            $storagePool = $vdInfo | Get-StoragePool
            Write-Host "Storage Pool: $($storagePool.FriendlyName)" -ForegroundColor White
            
            $allTiers = Get-StorageTier
            $relatedTiers = $allTiers | Where-Object { 
                $_.FriendlyName -like "*$VirtualDiskName*"
            }
            
            if ($relatedTiers) {
                Write-Host "`nДетальная информация по Tiers:" -ForegroundColor Yellow
                foreach ($tier in $relatedTiers) {
                    Write-Host "Tier: $($tier.FriendlyName)" -ForegroundColor White
                    Write-Host "  Media Type: $($tier.MediaType)" -ForegroundColor Gray
                    Write-Host "  Resiliency Setting: $($tier.ResiliencySettingName)" -ForegroundColor Gray
                    Write-Host "  Interleave: $($tier.Interleave)" -ForegroundColor Gray
                    Write-Host "  Physical Disk Redundancy: $($tier.PhysicalDiskRedundancy)" -ForegroundColor Gray
                    Write-Host "  Size: $([math]::Round($tier.Size / 1GB, 2)) GB" -ForegroundColor Gray
                    Write-Host "  Number of Columns: $($tier.NumberOfColumns)" -ForegroundColor Gray
                }
            }
        } else {
            # Для обычных виртуальных дисков
            Write-Host "Resiliency Setting: $($vdInfo.ResiliencySettingName)" -ForegroundColor White
            Write-Host "Provisioning Type: $($vdInfo.ProvisioningType)" -ForegroundColor White
            Write-Host "Interleave: $($vdInfo.Interleave)" -ForegroundColor White
            Write-Host "Physical Disk Redundancy: $($vdInfo.PhysicalDiskRedundancy)" -ForegroundColor White
            Write-Host "Number of Columns: $($vdInfo.NumberOfColumns)" -ForegroundColor White
        }
    } else {
        Write-Host "Virtual Disk '$VirtualDiskName' not found" -ForegroundColor Red
    }

    Write-Host ""

    # Volume Information
    Write-Host "=== Volume Information ===" -ForegroundColor Green

    $volumeInfo = Get-Volume -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
    if ($volumeInfo) {
        $clusterSizeBytes = $volumeInfo.AllocationUnitSize
        $clusterSizeKB = if ($clusterSizeBytes -gt 0) { $clusterSizeBytes / 1KB } else { $null }
        
        Write-Host "Drive Letter: $DriveLetter" -ForegroundColor White
        Write-Host "Volume Name: $($volumeInfo.FileSystemLabel)" -ForegroundColor White
        Write-Host "File System: $($volumeInfo.FileSystemType)" -ForegroundColor White
        Write-Host "Cluster Size: $(if($clusterSizeKB){ "$clusterSizeKB KB" } else { "N/A" })" -ForegroundColor White
        Write-Host "Total Size: $([math]::Round($volumeInfo.Size / 1GB, 2)) GB" -ForegroundColor White
        Write-Host "Free Space: $([math]::Round($volumeInfo.SizeRemaining / 1GB, 2)) GB" -ForegroundColor White
    } else {
        Write-Host "Volume $DriveLetter not found" -ForegroundColor Red
    }
}

function Create-Storage {
    Write-Host "Creating Storage Spaces..." -ForegroundColor Yellow
    
    # Получение физических дисков по серийным номерам
    $physicalDisks = Get-PhysicalDisk | Where-Object { $_.SerialNumber -in $SerialNumbers }
    
    if ($physicalDisks.Count -eq 0) {
        Write-Host "No physical disks found with specified serial numbers" -ForegroundColor Red
        return
    }

    Write-Host "Found $($physicalDisks.Count) disks" -ForegroundColor White

    # Разделение дисков по типам
    $ssdDisks = $physicalDisks | Where-Object { $_.MediaType -eq "SSD" }
    $hddDisks = $physicalDisks | Where-Object { $_.MediaType -eq "HDD" }

    Write-Host "SSD disks: $($ssdDisks.Count)" -ForegroundColor Cyan
    Write-Host "HDD disks: $($hddDisks.Count)" -ForegroundColor Cyan

    # Удаление существующих ресурсов
    Remove-VirtualDisk -FriendlyName $VirtualDiskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-StoragePool -FriendlyName $StoragePoolName -Confirm:$false -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5

    # Создание Storage Pool
    Write-Host "Creating Storage Pool..." -ForegroundColor Yellow
    $subSysName = (Get-StorageSubSystem).FriendlyName
    $storagePool = New-StoragePool -FriendlyName $StoragePoolName -PhysicalDisks $physicalDisks -StorageSubsystemFriendlyName $subSysName -ProvisioningType Fixed

    # Создание Storage Tiers
    Write-Host "Creating Storage Tiers..." -ForegroundColor Yellow
    $SSDTier = New-StorageTier -StoragePoolFriendlyName $StoragePoolName -FriendlyName "SSDTier" -MediaType "SSD" -ResiliencySettingName "Simple" -Interleave $SSDInterleave
    $HDDTier = New-StorageTier -StoragePoolFriendlyName $StoragePoolName -FriendlyName "HDDTier" -MediaType "HDD" -ResiliencySettingName "Mirror" -NumberOfColumns 1 -NumberOfDataCopies 1 -Interleave $HDDInterleave

    # Расчет размеров для уровней хранения
    $HDDTierSize = Get-StorageTierSupportedSize -FriendlyName "HDDTier" -ResiliencySettingName "Mirror"
    # Менять по мере необходимости на 0.98
    $HDDTierMaxSize = [Uint64]($HDDTierSize.TierSizeMax[0] * 1.00)

    # Создание виртуального диска с двумя tiers
    Write-Host "Creating Virtual Disk..." -ForegroundColor Yellow
    $virtualDisk = New-VirtualDisk -FriendlyName $VirtualDiskName -StoragePoolFriendlyName $StoragePoolName -StorageTiers @($SSDTier, $HDDTier) -StorageTierSizes @($SSDTierMaxSize, $HDDTierMaxSize) -WriteCacheSize $WriteCacheSize

    # Ожидание появления диска
    Start-Sleep -Seconds 10

    # Инициализация и форматирование диска
    Write-Host "Initializing and formatting disk..." -ForegroundColor Yellow
    Initialize-Disk -FriendlyName $VirtualDiskName -PartitionStyle GPT -Confirm:$false
    Stop-Service -Name ShellHWDetection -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    $diskNumber = (Get-Disk -FriendlyName $VirtualDiskName).DiskNumber
    $partition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -DriveLetter $DriveLetter
    Start-Sleep -Seconds 3

    Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -AllocationUnitSize $FSClusterSize -Force -Confirm:$false -NewFileSystemLabel $VolumeName
    Start-Sleep -Seconds 3
    Start-Service -Name ShellHWDetection -ErrorAction SilentlyContinue

    Write-Host "Storage creation completed successfully!" -ForegroundColor Green
}

# Выполнение создания хранилища
Create-Storage

# Показ информации о созданном хранилище
Show-StorageInfo
