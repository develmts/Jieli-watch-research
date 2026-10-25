if ($env:HRYFINE_WATCH_ADDRESS -notmatch '^[0-9A-Fa-f]{12}$') { throw 'Set HRYFINE_WATCH_ADDRESS to the target LE address (12 hex digits, no separators).' }
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -Path (Join-Path $PSScriptRoot 'WindowsNotificationQueue.dll')
[Windows.Devices.Bluetooth.BluetoothLEDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.BluetoothCacheMode,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattDeviceServicesResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Enumeration.DeviceAccessStatus,Windows.Devices.Enumeration,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattCharacteristicsResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattClientCharacteristicConfigurationDescriptorValue,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattWriteOption,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.Streams.DataReader,Windows.Storage.Streams,ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.Streams.DataWriter,Windows.Storage.Streams,ContentType=WindowsRuntime] | Out-Null
function Await-WinRT($operation, [Type]$resultType, [int]$timeoutMs = 15000) {
    $method = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
    $task = $method.MakeGenericMethod($resultType).Invoke($null, @($operation))
    if (-not $task.Wait($timeoutMs)) { try { $operation.Cancel() } catch {}; throw 'Timed out waiting for Windows Bluetooth.' }
    return $task.Result
}
function Write-Bytes($characteristic, [byte[]]$bytes) {
    $result = Await-WinRT ([WatchResearchNotificationQueue]::WriteBytes($characteristic,$bytes)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus])
    if ([string]$result -ne 'Success') { throw ('Bluetooth write: ' + $result) }
}
$watch = $null; $rx = $null; $services = @(); $registered = $false; $subscribed = $false
$eventId = 'WatchResearchF3-' + [guid]::NewGuid().ToString()
$trace = New-Object System.Collections.Generic.List[object]
$report = [ordered]@{schemaVersion=1;source='windows-winrt-research';startedAt=[DateTime]::UtcNow.ToString('o');device=@{name='Smartwatch';leAddress=$env:HRYFINE_WATCH_ADDRESS};services=@();queries=@()}
$query = [ordered]@{id='device-info';name='Read firmware identity';startedAt=[DateTime]::UtcNow.ToString('o');request=@{command=243;key=0};trace=$trace;success=$false}
try {
    $watch = Await-WinRT ([Windows.Devices.Bluetooth.BluetoothLEDevice]::FromBluetoothAddressAsync([Convert]::ToUInt64($env:HRYFINE_WATCH_ADDRESS,16))) ([Windows.Devices.Bluetooth.BluetoothLEDevice])
    if ($null -eq $watch) { throw 'Watch unavailable.' }
    $found = Await-WinRT ($watch.GetGattServicesAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattDeviceServicesResult])
    if ([string]$found.Status -ne 'Success') { throw ('Services: '+$found.Status) }
    $services = @($found.Services)
    $report.services = @($services | ForEach-Object { @{uuid=[string]$_.Uuid} })
    $normal = $services | Where-Object { [string]$_.Uuid -eq '6e400001-b5a3-f393-e0a9-e50e24dcca9f' } | Select-Object -First 1
    if (!$normal) { throw 'Normal HryFine channel is absent.' }
    $access = Await-WinRT ($normal.RequestAccessAsync()) ([Windows.Devices.Enumeration.DeviceAccessStatus])
    $query.accessStatus = [string]$access
    if ([string]$access -ne 'Allowed') { throw ('Normal service access: ' + $access) }
    $chars = Await-WinRT ($normal.GetCharacteristicsAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCharacteristicsResult])
    if ([string]$chars.Status -ne 'Success') { throw ('Characteristics: '+$chars.Status) }
    $rx = $chars.Characteristics | Where-Object { [string]$_.Uuid -eq '6e400003-b5a3-f393-e0a9-e50e24dcca9f' } | Select-Object -First 1
    $tx = $chars.Characteristics | Where-Object { [string]$_.Uuid -eq '6e400002-b5a3-f393-e0a9-e50e24dcca9f' } | Select-Object -First 1
    if (!$rx -or !$tx) { throw 'Incomplete query channel.' }
    $notificationQueue = New-Object WatchResearchNotificationQueue($rx)
    $registered = $true
    $notify = Await-WinRT ($rx.WriteClientCharacteristicConfigurationDescriptorAsync([Windows.Devices.Bluetooth.GenericAttributeProfile.GattClientCharacteristicConfigurationDescriptorValue]::Notify)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus])
    if ([string]$notify -ne 'Success') { throw ('Subscription: '+$notify) }
    $subscribed = $true
    [byte[]]$request = 0xdf,0,5,0,0xf3,1,0,0,0
    $request[3] = [byte](($request | Measure-Object -Sum).Sum -band 255)
    $query.request.hex = [BitConverter]::ToString($request).Replace('-','').ToLowerInvariant()
    $trace.Add(@{at=[DateTime]::UtcNow.ToString('o');normalTx=$query.request.hex})
    Write-Bytes $tx $request
    $pending = New-Object System.Collections.Generic.List[byte]
    $deadline = [DateTime]::UtcNow.AddSeconds(12)
    while ([DateTime]::UtcNow -lt $deadline -and !$query.success) {
        $chunk = $notificationQueue.Take()
        if ($null -eq $chunk) { Start-Sleep -Milliseconds 50; continue }
        try {
            $trace.Add(@{at=[DateTime]::UtcNow.ToString('o');normalRx=[BitConverter]::ToString($chunk).Replace('-','').ToLowerInvariant()})
            $pending.AddRange([byte[]]$chunk)
            while ($pending.Count -ge 3) {
                if ($pending[0] -eq 0xfd) { $length=9 } elseif ($pending[0] -eq 0xdf) { $length=([int]$pending[1]*256)+$pending[2]+4 } else { throw 'Unexpected frame header.' }
                if ($length -lt 9 -or $length -gt 65539) { throw 'Invalid frame length.' }
                if ($pending.Count -lt $length) { break }
                [byte[]]$frame=$pending.GetRange(0,$length).ToArray(); $pending.RemoveRange(0,$length)
                $sum=0;for($i=0;$i -lt $frame.Length;$i++){if($i -ne 3){$sum=($sum+$frame[$i])-band 255}}
                if($sum -ne $frame[3]){throw 'Invalid response checksum.'}
                if($frame[0] -eq 0xfd){continue}
                if((([int]$frame[7]*256)+$frame[8]+9) -ne $frame.Length){throw 'Payload inconsistent.'}
                [byte[]]$ack=0xfd,0,5,0,$frame[4],$frame[6],0,0,1
                $ack[3]=[byte](($ack|Measure-Object -Sum).Sum -band 255)
                $trace.Add(@{at=[DateTime]::UtcNow.ToString('o');normalAckTx=[BitConverter]::ToString($ack).Replace('-','').ToLowerInvariant()})
                Write-Bytes $tx $ack
                if($frame[4] -eq 0xf3){$payload=if($frame.Length -gt 9){[byte[]]$frame[9..($frame.Length-1)]}else{[byte[]]@()};$query.response=@{key=[int]$frame[6];payloadHex=[BitConverter]::ToString($payload).Replace('-','').ToLowerInvariant()};$query.success=$true}
            }
        } finally { }
    }
    if(!$query.success){throw 'F3/00 returned no data within 12 seconds.'}
} catch { $query.error=$_.Exception.Message }
finally {
    if($subscribed -and $null -ne $rx){try{Await-WinRT ($rx.WriteClientCharacteristicConfigurationDescriptorAsync([Windows.Devices.Bluetooth.GenericAttributeProfile.GattClientCharacteristicConfigurationDescriptorValue]::None)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus]) 5000 | Out-Null}catch{}}
    if($registered){$notificationQueue.Dispose()}
    foreach($service in $services){$service.Dispose()}
    if($null -ne $watch){$watch.Dispose()}
    $query.finishedAt=[DateTime]::UtcNow.ToString('o');$report.queries=@($query);$report.finishedAt=$query.finishedAt
    $directory=Join-Path (Get-Location) 'output/sessions';New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $file=Join-Path $directory ([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')+'_winrt_f3.json')
    $report|ConvertTo-Json -Depth 15|Set-Content -Encoding UTF8 -Path $file
    Write-Output ('Report: '+$file);$query|ConvertTo-Json -Depth 12
}
