param([switch]$SkipAdvertisements,[switch]$MaintainConnection)
if ($env:HRYFINE_WATCH_ADDRESS -notmatch '^[0-9A-Fa-f]{12}$') { throw 'Set HRYFINE_WATCH_ADDRESS to the target LE address (12 hex digits, no separators).' }
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -Path (Join-Path $PSScriptRoot 'WindowsAdvertisementQueue.dll')
Add-Type -Path (Join-Path $PSScriptRoot 'WindowsNotificationQueue.dll')
[Windows.Devices.Bluetooth.BluetoothLEDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.BluetoothCacheMode,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattDeviceServicesResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattCharacteristicsResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattClientCharacteristicConfigurationDescriptorValue,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
function Await-WinRT($operation,[Type]$type,[int]$timeoutMs=10000){
    $method=[System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object{$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'}|Select-Object -First 1
    $task=$method.MakeGenericMethod($type).Invoke($null,@($operation));if(!$task.Wait($timeoutMs)){try{$operation.Cancel()}catch{};throw 'Windows Bluetooth timeout'};return $task.Result
}
$report=[ordered]@{schemaVersion=1;source='windows-winrt-passive';startedAt=[DateTime]::UtcNow.ToString('o');device=@{name='Smartwatch';leAddress=$env:HRYFINE_WATCH_ADDRESS};services=@();queries=@();advertisements=@();notifications=@();errors=@();policy='Target-only passive advertisement capture then 20 seconds of battery, FF14 and normal notifications; no application commands, no OTA subscription'}
$advertisementQueue=$null;$watch=$null;$services=@();$subscriptions=@()
try{
    if(!$SkipAdvertisements){
    $advertisementQueue=New-Object WatchResearchAdvertisementQueue([Convert]::ToUInt64($env:HRYFINE_WATCH_ADDRESS,16))
    $deadline=[DateTime]::UtcNow.AddSeconds(20)
    while([DateTime]::UtcNow -lt $deadline){$item=$advertisementQueue.Take();if($item){$report.advertisements+=,$item}else{Start-Sleep -Milliseconds 100}}
    }
}catch{$report.errors+=,@{phase='advertisements';error=$_.Exception.Message}}
finally{if($advertisementQueue){$advertisementQueue.Dispose()}}
try{
    $watch=Await-WinRT ([Windows.Devices.Bluetooth.BluetoothLEDevice]::FromBluetoothAddressAsync([Convert]::ToUInt64($env:HRYFINE_WATCH_ADDRESS,16))) ([Windows.Devices.Bluetooth.BluetoothLEDevice]);if(!$watch){throw 'Watch not available'}
    $found=Await-WinRT ($watch.GetGattServicesAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattDeviceServicesResult]);if([string]$found.Status -ne 'Success'){throw ('Services: '+$found.Status)}
    $services=@($found.Services)
    if($MaintainConnection){$connectionSession=$services[0].Session;$previousMaintain=$connectionSession.MaintainConnection;$connectionSession.MaintainConnection=$true;$report.windowsMaintainConnection=@{requested=$true;previous=$previousMaintain}}
    foreach($service in $services){
        if([string]$service.Uuid -notin @('0000180f-0000-1000-8000-00805f9b34fb','0000ff12-0000-1000-8000-00805f9b34fb','6e400001-b5a3-f393-e0a9-e50e24dcca9f')){continue}
        try{
            $chars=Await-WinRT ($service.GetCharacteristicsAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCharacteristicsResult]);if([string]$chars.Status -ne 'Success'){throw ('Characteristics: '+$chars.Status)}
            foreach($c in $chars.Characteristics){
                if([string]$c.Uuid -notin @('00002a19-0000-1000-8000-00805f9b34fb','0000ff14-0000-1000-8000-00805f9b34fb','6e400003-b5a3-f393-e0a9-e50e24dcca9f')){continue}
                $queue=New-Object WatchResearchNotificationQueue($c)
                try{$status=Await-WinRT ($c.WriteClientCharacteristicConfigurationDescriptorAsync([Windows.Devices.Bluetooth.GenericAttributeProfile.GattClientCharacteristicConfigurationDescriptorValue]::Notify)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus]);if([string]$status -ne 'Success'){throw ('Notify: '+$status)};$subscriptions+=,@{queue=$queue;characteristic=$c;service=[string]$service.Uuid};$report.services+=,@{uuid=[string]$service.Uuid;characteristics=@(@{uuid=[string]$c.Uuid;subscribed=$true})}}catch{$queue.Dispose();throw}
            }
        }catch{$report.errors+=,@{phase='subscription';service=[string]$service.Uuid;error=$_.Exception.Message}}
    }
    $report.connectionStates=@(@{at=[DateTime]::UtcNow.ToString('o');status=[string]$watch.ConnectionStatus});$lastConnectionStatus=[string]$watch.ConnectionStatus
    $report.listenStartedAt=[DateTime]::UtcNow.ToString('o');$deadline=[DateTime]::UtcNow.AddSeconds(20)
    while([DateTime]::UtcNow -lt $deadline){
        $currentStatus=[string]$watch.ConnectionStatus;if($currentStatus -ne $lastConnectionStatus){$report.connectionStates+=,@{at=[DateTime]::UtcNow.ToString('o');status=$currentStatus};$lastConnectionStatus=$currentStatus}
        foreach($sub in $subscriptions){[byte[]]$chunk=$sub.queue.Take();if($null -ne $chunk){$report.notifications+=,@{at=[DateTime]::UtcNow.ToString('o');service=$sub.service;characteristic=[string]$sub.characteristic.Uuid;hex=[BitConverter]::ToString($chunk).Replace('-','').ToLowerInvariant()}}}
        Start-Sleep -Milliseconds 50
    }
    $report.listenFinishedAt=[DateTime]::UtcNow.ToString('o');$report.connectionStatusAtEnd=[string]$watch.ConnectionStatus
}catch{$report.errors+=,@{phase='notifications';error=$_.Exception.Message}}
finally{
    foreach($sub in $subscriptions){try{Await-WinRT ($sub.characteristic.WriteClientCharacteristicConfigurationDescriptorAsync([Windows.Devices.Bluetooth.GenericAttributeProfile.GattClientCharacteristicConfigurationDescriptorValue]::None)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus]) 5000|Out-Null}catch{$report.errors+=,@{phase='cleanup';error=$_.Exception.ToString()}};$sub.queue.Dispose()}
    if($connectionSession){try{$connectionSession.MaintainConnection=$previousMaintain}catch{$report.errors+=,@{phase='restore-windows-session';error=$_.Exception.ToString()}}}
    foreach($service in $services){$service.Dispose()};if($watch){$watch.Dispose()}
    $report.finishedAt=[DateTime]::UtcNow.ToString('o')
    $directory=Join-Path (Get-Location) 'output/sessions';New-Item -ItemType Directory -Force $directory|Out-Null;$file=Join-Path $directory ([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')+'_winrt_passive.json')
    $report|ConvertTo-Json -Depth 18|Set-Content -Encoding UTF8 $file
    Write-Output ('Report: '+$file);Write-Output ('Advertisements: '+$report.advertisements.Count+'; notifications: '+$report.notifications.Count+'; channels: '+$subscriptions.Count)
    $report.errors|ConvertTo-Json -Depth 5
}
