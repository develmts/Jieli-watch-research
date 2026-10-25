param([ValidateSet('battery','observe','inventory','hardware','identity','features','settings','faces','today','classic-address','alarms','custom-face','ota-identity')][string]$Query='battery')
if ($env:HRYFINE_WATCH_ADDRESS -notmatch '^[0-9A-Fa-f]{12}$') { throw 'Set HRYFINE_WATCH_ADDRESS to the target LE address (12 hex digits, no separators).' }
# A bounded research session: one allowlisted information request, battery gate,
# raw evidence and restoration of the original normal-channel CCCD.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -Path (Join-Path $PSScriptRoot 'WindowsNotificationQueue.dll')
[Windows.Devices.Bluetooth.BluetoothLEDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.BluetoothCacheMode,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattDeviceServicesResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattCharacteristicsResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattDescriptorsResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattReadResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattReadClientCharacteristicConfigurationDescriptorResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattClientCharacteristicConfigurationDescriptorValue,Windows.Devices.Bluetooth,ContentType=WindowsRuntime]|Out-Null
[Windows.Devices.Enumeration.DeviceAccessStatus,Windows.Devices.Enumeration,ContentType=WindowsRuntime]|Out-Null
function Await-WinRT($operation,[Type]$type,[int]$timeoutMs=10000){
    $method=[System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object{$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'}|Select-Object -First 1
    $task=$method.MakeGenericMethod($type).Invoke($null,@($operation))
    if(!$task.Wait($timeoutMs)){try{$operation.Cancel()}catch{};throw 'Windows Bluetooth timeout'}
    return $task.Result
}
function Get-Characteristics($service){
    $access=Await-WinRT ($service.RequestAccessAsync()) ([Windows.Devices.Enumeration.DeviceAccessStatus])
    if([string]$access -ne 'Allowed'){throw ('Service access: '+$access)}
    $found=Await-WinRT ($service.GetCharacteristicsAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCharacteristicsResult])
    if([string]$found.Status -ne 'Success'){throw ('Characteristics: '+$found.Status)}
    return @($found.Characteristics)
}
function Read-Battery($characteristic){
    $r=Await-WinRT ([WatchResearchNotificationQueue]::ReadCharacteristic($characteristic)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattReadResult])
    if([string]$r.Status -ne 'Success'){throw ('Battery unavailable: '+$r.Status)}
    [byte[]]$b=[WatchResearchNotificationQueue]::ResultBytes($r)
    if($b.Length -ne 1 -or $b[0] -gt 100){throw 'Invalid battery reading'}
    $entry=@{observedAt=[DateTime]::UtcNow.ToString('o');percent=[int]$b[0];hex=$b[0].ToString('x2')}
    $script:report.battery+=,$entry
    Write-Output $entry
}
function Write-Bytes([byte[]]$bytes){
    if(!$script:gatePassed){throw 'Battery gate closed'}
    $status=Await-WinRT ([WatchResearchNotificationQueue]::WriteBytes($script:tx,$bytes)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus])
    if([string]$status -ne 'Success'){throw ('Normal-channel write: '+$status)}
}
$definitions=@{
    hardware=@{command=10;key=16;source='Gadgetbridge LaxasFitDeviceSupport CMD_GET_HW_INFO; empty getter. HryFine names namespace FLASH_READ; no address, length or flash programming command sent.'}
    identity=@{command=243;key=0;source='GeneralUtils.requestDeviceInfo'}
    features=@{command=25;key=0;source='SettingIssuedUtils.getDeviceFeatures'}
    settings=@{command=9;key=0;source='GeneralUtils.requsetSettingInfo'}
    faces=@{command=15;key=1;source='NotifyWriteUtils.syncProcess watch-face status getter'}
    today=@{command=5;key=10;source='SportIssuedUtil.todayHistory; no live sensor or realTimeStep enable'}
    'classic-address'=@{command=14;key=3;source='NotifyWriteUtils synchronization getter; BleDataUtils.handleMountBTInfo; no classic pairing'}
    alarms=@{command=8;key=0;source='GeneralUtils.requsetAlarmClockInfo'}
    'custom-face'=@{command=15;key=4;source='NotifyWriteUtils.syncProcess custom-face getter'}
    'ota-identity'=@{command=19;key=1;source='GeneralUtils.requestOTAInfo, never 19/2'}
}
$report=[ordered]@{schemaVersion=1;source='windows-winrt-battery-guarded-research';startedAt=[DateTime]::UtcNow.ToString('o');device=@{name='Smartwatch';leAddress=$env:HRYFINE_WATCH_ADDRESS};policy='User: read and test, never modify. One allowlisted getter, normal request/ACK and temporary CCCD only. Battery <=15 or unknown stops work. No settings, clock, binding, live sensor switches, reset, OTA start, unknown writes or firmware upload.';queryId=$Query;services=@();battery=@();queries=@();errors=@();batteryThreshold=15}
$watch=$null;$services=@();$queue=$null;$rx=$null;$tx=$null;$batteryChar=$null;$changedCccd=$false;$gatePassed=$false;$oldCccd=$null
try{
    $watch=Await-WinRT ([Windows.Devices.Bluetooth.BluetoothLEDevice]::FromBluetoothAddressAsync([Convert]::ToUInt64($env:HRYFINE_WATCH_ADDRESS,16))) ([Windows.Devices.Bluetooth.BluetoothLEDevice])
    if(!$watch){throw 'Device unavailable'}
    $found=Await-WinRT ($watch.GetGattServicesAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattDeviceServicesResult])
    if([string]$found.Status -ne 'Success'){throw ('Services: '+$found.Status)}
    $services=@($found.Services);$report.services=@($services|ForEach-Object{@{uuid=[string]$_.Uuid}})
    $batteryService=$services|Where-Object{[string]$_.Uuid -eq '0000180f-0000-1000-8000-00805f9b34fb'}|Select-Object -First 1
    if(!$batteryService){throw 'Battery service unavailable; no query sent'}
    $batteryChar=Get-Characteristics $batteryService|Where-Object{[string]$_.Uuid -eq '00002a19-0000-1000-8000-00805f9b34fb'}|Select-Object -First 1
    if(!$batteryChar){throw 'Battery characteristic unavailable; no query sent'}
    $initial=Read-Battery $batteryChar
    if($initial.percent -le 15){$report.stopReason='battery-at-or-below-15';throw 'Battery <=15%; stopped before any functional request'}
    $gatePassed=$true
    if($Query -eq 'observe'){
        $report.observation='Thirty seconds of GATT battery reads every four seconds, no proprietary commands or subscriptions; poll connection status every 100ms'
        $report.connectionStates=@();$lastStatus='';$end=[DateTime]::UtcNow.AddSeconds(30);$nextRead=[DateTime]::UtcNow.AddSeconds(4)
        while([DateTime]::UtcNow -lt $end){
            $current=[string]$watch.ConnectionStatus
            if($current -ne $lastStatus){$report.connectionStates+=,@{at=[DateTime]::UtcNow.ToString('o');status=$current};$lastStatus=$current}
            if([DateTime]::UtcNow -ge $nextRead){
                $level=Read-Battery $batteryChar
                if($level.percent -le 15){$report.stopReason='battery-at-or-below-15';throw 'Observation stopped at battery threshold'}
                $nextRead=[DateTime]::UtcNow.AddSeconds(4)
            }
            Start-Sleep -Milliseconds 100
        }
        $report.connectionStatusAtEnd=[string]$watch.ConnectionStatus
    }elseif($Query -eq 'inventory'){
        foreach($service in $services){
            $level=Read-Battery $batteryChar
            if($level.percent -le 15){$report.stopReason='battery-at-or-below-15';throw 'Inventory stopped at battery threshold'}
            $item=$report.services|Where-Object{$_.uuid -eq [string]$service.Uuid}|Select-Object -First 1
            $item.attributeHandle=$service.AttributeHandle;$item.characteristics=@()
            foreach($c in (Get-Characteristics $service)){
                $char=@{uuid=[string]$c.Uuid;attributeHandle=$c.AttributeHandle;properties=[string]$c.CharacteristicProperties;descriptors=@()};$item.characteristics+=,$char
                if(([string]$c.CharacteristicProperties) -match '(^|, )Read(,|$)'){
                    $r=Await-WinRT ([WatchResearchNotificationQueue]::ReadCharacteristic($c)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattReadResult])
                    $char.read=@{status=[string]$r.Status}
                    if([string]$r.Status -eq 'Success'){
                        [byte[]]$value=@([WatchResearchNotificationQueue]::ResultBytes($r));$char.read.hex=[BitConverter]::ToString($value).Replace('-','').ToLowerInvariant()
                    }
                }
                $ds=Await-WinRT ($c.GetDescriptorsAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattDescriptorsResult])
                if([string]$ds.Status -eq 'Success'){
                    foreach($d in $ds.Descriptors){
                        $r=Await-WinRT ([WatchResearchNotificationQueue]::ReadDescriptor($d)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattReadResult])
                        $entry=@{uuid=[string]$d.Uuid;attributeHandle=$d.AttributeHandle;status=[string]$r.Status}
                        if([string]$r.Status -eq 'Success'){[byte[]]$value=@([WatchResearchNotificationQueue]::ResultBytes($r));$entry.hex=[BitConverter]::ToString($value).Replace('-','').ToLowerInvariant()}
                        $char.descriptors+=,$entry
                    }
                }
            }
        }
        $after=Read-Battery $batteryChar
        if($after.percent -le 15){$report.stopReason='battery-at-or-below-15'}
    }elseif($Query -ne 'battery'){
        $definition=$definitions[$Query]
        $normal=$services|Where-Object{[string]$_.Uuid -eq '6e400001-b5a3-f393-e0a9-e50e24dcca9f'}|Select-Object -First 1
        if(!$normal){throw 'Normal service absent'}
        $chars=Get-Characteristics $normal
        $rx=$chars|Where-Object{[string]$_.Uuid -eq '6e400003-b5a3-f393-e0a9-e50e24dcca9f'}|Select-Object -First 1
        $tx=$chars|Where-Object{[string]$_.Uuid -eq '6e400002-b5a3-f393-e0a9-e50e24dcca9f'}|Select-Object -First 1
        if(!$rx -or !$tx){throw 'Incomplete normal channel'}
        $original=Await-WinRT ($rx.ReadClientCharacteristicConfigurationDescriptorAsync()) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattReadClientCharacteristicConfigurationDescriptorResult])
        $report.cccdApiReadStatus=[string]$original.Status
        if([string]$original.Status -eq 'Success'){$oldCccd=$original.ClientCharacteristicConfigurationDescriptor}else{
            # Some Windows sessions reject the convenience API; read the actual
            # 2902 descriptor, as in the previously verified native inventory.
            $descriptors=Await-WinRT ($rx.GetDescriptorsAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattDescriptorsResult])
            if([string]$descriptors.Status -ne 'Success'){throw 'Original CCCD unavailable; no subscription changed'}
            $descriptor=$descriptors.Descriptors|Where-Object{[string]$_.Uuid -eq '00002902-0000-1000-8000-00805f9b34fb'}|Select-Object -First 1
            if(!$descriptor){throw 'Original CCCD descriptor absent'}
            $read=Await-WinRT ([WatchResearchNotificationQueue]::ReadDescriptor($descriptor)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattReadResult])
            if([string]$read.Status -ne 'Success'){throw ('Original CCCD unavailable: '+$read.Status)}
            [byte[]]$raw=[WatchResearchNotificationQueue]::ResultBytes($read)
            if($raw.Length -ne 2 -or $raw[1] -ne 0 -or $raw[0] -gt 3){throw 'Unexpected CCCD value'}
            $oldCccd=[Windows.Devices.Bluetooth.GenericAttributeProfile.GattClientCharacteristicConfigurationDescriptorValue][int]$raw[0]
            $report.cccdRawReadHex=[BitConverter]::ToString($raw).Replace('-','').ToLowerInvariant()
        }
        $report.originalCccd=[string]$oldCccd
        $queue=New-Object WatchResearchNotificationQueue($rx)
        # WinRT needs a local subscription even when the shared CCCD already
        # reads Notify from a previous client. Always register, then restore.
        $status=Await-WinRT ($rx.WriteClientCharacteristicConfigurationDescriptorAsync([Windows.Devices.Bluetooth.GenericAttributeProfile.GattClientCharacteristicConfigurationDescriptorValue]::Notify)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus])
        if([string]$status -ne 'Success'){throw ('Subscription: '+$status)};$changedCccd=$true
        # Check immediately before the functional write, not only before discovery.
        $before=Read-Battery $batteryChar
        if($before.percent -le 15){$gatePassed=$false;$report.stopReason='battery-at-or-below-15';throw 'Battery <=15%; query cancelled'}
        $trace=New-Object System.Collections.Generic.List[object]
        $q=[ordered]@{id=$Query;request=@{command=$definition.command;key=$definition.key;sent=$false;source=$definition.source};trace=$trace;frames=@();success=$false}
        $report.queries+=,$q
        [byte[]]$request=0xdf,0,5,0,([byte]$definition.command),1,([byte]$definition.key),0,0
        $request[3]=[byte](($request|Measure-Object -Sum).Sum -band 255)
        $q.request.hex=[BitConverter]::ToString($request).Replace('-','').ToLowerInvariant()
        Write-Bytes $request;$q.request.sent=$true;$trace.Add(@{at=[DateTime]::UtcNow.ToString('o');normalTx=$q.request.hex})
        $pending=New-Object System.Collections.Generic.List[byte];$deadline=[DateTime]::UtcNow.AddSeconds(7);$lastData=$null
        while([DateTime]::UtcNow -lt $deadline){
            if($lastData -and [DateTime]::UtcNow -gt $lastData.AddMilliseconds(900)){break}
            [byte[]]$chunk=$queue.Take()
            if($null -eq $chunk){Start-Sleep -Milliseconds 40;continue}
            $trace.Add(@{at=[DateTime]::UtcNow.ToString('o');normalRx=[BitConverter]::ToString($chunk).Replace('-','').ToLowerInvariant()});$pending.AddRange($chunk)
            while($pending.Count -ge 3){
                if($pending[0] -eq 0xfd){$length=9}elseif($pending[0] -eq 0xdf){$length=[int]$pending[1]*256+$pending[2]+4}else{throw 'Unexpected frame header; stopped'}
                if($length -lt 9 -or $length -gt 65539){throw 'Invalid outer length'}
                if($pending.Count -lt $length){break}
                [byte[]]$frame=$pending.GetRange(0,$length).ToArray();$pending.RemoveRange(0,$length)
                $sum=0;for($i=0;$i -lt $frame.Length;$i++){if($i -ne 3){$sum=($sum+$frame[$i])-band 255}}
                if($sum -ne $frame[3]){throw 'Checksum mismatch; stopped'}
                $q.frames+=,@{at=[DateTime]::UtcNow.ToString('o');hex=[BitConverter]::ToString($frame).Replace('-','').ToLowerInvariant()}
                if($frame[0] -eq 0xfd){continue}
                $declared=[int]$frame[7]*256+$frame[8]
                if($declared+9 -ne $frame.Length -and !($frame[4] -eq 15 -and $frame[6] -eq 5 -and $declared -eq 11 -and $frame.Length -eq 26)){throw 'Inner payload length mismatch'}
                [byte[]]$ack=0xfd,0,5,0,$frame[4],$frame[6],0,0,1;$ack[3]=[byte](($ack|Measure-Object -Sum).Sum -band 255)
                Write-Bytes $ack;$trace.Add(@{at=[DateTime]::UtcNow.ToString('o');normalAckTx=[BitConverter]::ToString($ack).Replace('-','').ToLowerInvariant()})
                if($frame[4] -eq $definition.command){$q.success=$true;$lastData=[DateTime]::UtcNow}
            }
        }
        if($pending.Count){$q.incompleteHex=[BitConverter]::ToString($pending.ToArray()).Replace('-','').ToLowerInvariant()}
        if(!$q.success){$q.error='No matching data response in bounded listening window; ACK alone is not data'}
        $after=Read-Battery $batteryChar
        if($after.percent -le 15){$report.stopReason='battery-at-or-below-15'}
    }
    if(!$report.stopReason){$report.stopReason='bounded-session-completed'}
}catch{
    $report.errors+=,$_.Exception.ToString()
    if(!$report.stopReason){$report.stopReason='error-stop-no-further-requests'}
}finally{
    $gatePassed=$false
    if($changedCccd){try{$restored=Await-WinRT ($rx.WriteClientCharacteristicConfigurationDescriptorAsync($oldCccd)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus]) 4000;$report.cccdRestore=[string]$restored}catch{$report.cccdRestoreError=$_.Exception.ToString()}}
    if($queue){try{$queue.Dispose()}catch{$report.errors+=,$_.Exception.ToString()}}
    foreach($service in $services){try{$service.Dispose()}catch{}}
    if($watch){try{$watch.Dispose()}catch{}}
    $report.finishedAt=[DateTime]::UtcNow.ToString('o')
    $directory=Join-Path (Get-Location) 'output/sessions';New-Item -ItemType Directory -Force $directory|Out-Null
    $file=Join-Path $directory ([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')+'_winrt_guarded_'+$Query+'.json')
    $report|ConvertTo-Json -Depth 20|Set-Content -Encoding UTF8 $file
    [pscustomobject]@{query=$Query;battery=($report.battery|ForEach-Object{$_.percent})-join ',';data=($report.queries|ForEach-Object{$_.success})-join ',';stopReason=$report.stopReason;report=$file;errors=$report.errors.Count}|ConvertTo-Json -Compress
}
