if ($env:HRYFINE_WATCH_ADDRESS -notmatch '^[0-9A-Fa-f]{12}$') { throw 'Set HRYFINE_WATCH_ADDRESS to the target LE address (12 hex digits, no separators).' }
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -Path (Join-Path $PSScriptRoot 'WindowsNotificationQueue.dll')
[Windows.Devices.Bluetooth.BluetoothLEDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.BluetoothCacheMode,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattDeviceServicesResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattCharacteristicsResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattDescriptorsResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattReadResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Enumeration.DeviceAccessStatus,Windows.Devices.Enumeration,ContentType=WindowsRuntime] | Out-Null
function Await-WinRT($operation,[Type]$type,[int]$timeoutMs=10000){
    $method=[System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object{$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'}|Select-Object -First 1
    $task=$method.MakeGenericMethod($type).Invoke($null,@($operation))
    if(!$task.Wait($timeoutMs)){try{$operation.Cancel()}catch{};throw 'Windows Bluetooth operation timeout'}
    return $task.Result
}
function Decode-ReadResult($result){
    $value=[ordered]@{status=[string]$result.Status;observedAt=[DateTime]::UtcNow.ToString('o')}
    if([string]$result.Status -eq 'Success'){
        [byte[]]$bytes=[WatchResearchNotificationQueue]::ResultBytes($result)
        $value.hex=[BitConverter]::ToString($bytes).Replace('-','').ToLowerInvariant();$value.bytes=$bytes.Length
        try{$utf8=New-Object System.Text.UTF8Encoding($false,$true);$text=$utf8.GetString($bytes).TrimEnd([char]0);if($text.Length -gt 0 -and $text -notmatch '[\x00-\x1f\x7f]'){$value.text=$text}}catch{}
    } else {$value.protocolError=$result.ProtocolError}
    return $value
}
$report=[ordered]@{schemaVersion=1;source='windows-winrt-inventory';startedAt=[DateTime]::UtcNow.ToString('o');device=@{leAddress=$env:HRYFINE_WATCH_ADDRESS};services=@();queries=@();errors=@();policy='GATT reads only, including descriptors; no characteristic or descriptor writes, no notifications'}
$watch=$null;$services=@()
try{
    $watch=Await-WinRT ([Windows.Devices.Bluetooth.BluetoothLEDevice]::FromBluetoothAddressAsync([Convert]::ToUInt64($env:HRYFINE_WATCH_ADDRESS,16))) ([Windows.Devices.Bluetooth.BluetoothLEDevice])
    if($null -eq $watch){throw 'No device returned by Windows'}
    $report.device.name=$watch.Name;$report.device.addressType=[string]$watch.BluetoothAddressType;$report.device.deviceId=$watch.DeviceId;$report.device.connectionStatus=[string]$watch.ConnectionStatus;try{$report.device.appearance=@{rawValue=$watch.Appearance.RawValue;category=$watch.Appearance.Category;subCategory=$watch.Appearance.SubCategory}}catch{$report.device.appearanceError=$_.Exception.Message}
    $found=Await-WinRT ($watch.GetGattServicesAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattDeviceServicesResult])
    if([string]$found.Status -ne 'Success'){throw ('Services: '+$found.Status)}
    $services=@($found.Services)
    foreach($service in $services){
        $item=[ordered]@{uuid=[string]$service.Uuid;attributeHandle=$service.AttributeHandle;characteristics=@()};$report.services+=,$item
        try{
            try{$item.session=@{maxPduSize=$service.Session.MaxPduSize;status=[string]$service.Session.SessionStatus;canMaintainConnection=$service.Session.CanMaintainConnection;maintainConnection=$service.Session.MaintainConnection}}catch{$item.sessionError=$_.Exception.Message}
            $item.access=[string](Await-WinRT ($service.RequestAccessAsync()) ([Windows.Devices.Enumeration.DeviceAccessStatus]))
            $chars=Await-WinRT ($service.GetCharacteristicsAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCharacteristicsResult])
            $item.status=[string]$chars.Status
            if($item.status -ne 'Success'){continue}
            foreach($c in $chars.Characteristics){
                $properties=[string]$c.CharacteristicProperties
                $char=[ordered]@{uuid=[string]$c.Uuid;attributeHandle=$c.AttributeHandle;properties=$properties;descriptors=@()};$item.characteristics+=,$char
                if($properties -match '(^|, )Read(,|$)'){
                    try{$r=Await-WinRT ([WatchResearchNotificationQueue]::ReadCharacteristic($c)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattReadResult]);$char.read=Decode-ReadResult $r}catch{$char.read=@{status='Exception';error=$_.Exception.Message}}
                }else{$char.read=@{status='NotReadable'}}
                try{
                    $descriptors=Await-WinRT ($c.GetDescriptorsAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattDescriptorsResult])
                    $char.descriptorStatus=[string]$descriptors.Status
                    if([string]$descriptors.Status -eq 'Success'){
                        foreach($d in $descriptors.Descriptors){
                            $desc=[ordered]@{uuid=[string]$d.Uuid;attributeHandle=$d.AttributeHandle};$char.descriptors+=,$desc
                            try{$r=Await-WinRT ([WatchResearchNotificationQueue]::ReadDescriptor($d)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattReadResult]);$desc.read=Decode-ReadResult $r}catch{$desc.read=@{status='Exception';error=$_.Exception.Message}}
                        }
                    }
                }catch{$char.descriptorError=$_.Exception.Message}
            }
        }catch{$item.error=$_.Exception.Message}
    }
}catch{$report.errors+=,$_.Exception.Message}
finally{
    foreach($service in $services){$service.Dispose()};if($watch){$watch.Dispose()}
    $report.finishedAt=[DateTime]::UtcNow.ToString('o')
    $directory=Join-Path (Get-Location) 'output/sessions';New-Item -ItemType Directory -Force $directory|Out-Null
    $file=Join-Path $directory ([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')+'_winrt_inventory.json')
    $report|ConvertTo-Json -Depth 18|Set-Content -Encoding UTF8 $file
    Write-Output ('Report: '+$file)
    $report.services|ForEach-Object{[PSCustomObject]@{Service=$_.uuid;Characteristics=$_.characteristics.Count;MaxPduSize=$_.session.maxPduSize;Status=$_.status}}|Format-Table -AutoSize
}
