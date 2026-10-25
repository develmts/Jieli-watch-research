param([ValidateSet('all','followup')][string]$Phase='all')
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

$watch=$null;$rx=$null;$services=@();$queue=$null;$subscribed=$false
$report=[ordered]@{schemaVersion=1;source='windows-winrt-research';startedAt=[DateTime]::UtcNow.ToString('o');device=@{name='Smartwatch';leAddress=$env:HRYFINE_WATCH_ADDRESS};services=@();queries=@();policy='Only known information getters from APK; normal-channel request and ACK. No binding, settings writes, reset, factory test, flash access or start-OTA.'}
$definitions=@(
    @{id='bt-connect-status';command=2;key=60;description='SettingIssuedUtils.requestBtConnectStatus: query Bluetooth connection state'},
    @{id='today-summary';command=5;key=10;description='SportIssuedUtil.todayHistory: request today summary without enabling live sensor streams'},
    @{id='watch-faces';command=15;key=1;description='Existing read-only watch-face status query, used as integrity check'},
    @{id='ota-info';command=19;key=1;description='GeneralUtils.requestOTAInfo: update identity, not requestStartOTA'},
    @{id='settings-info';command=9;key=0;description='GeneralUtils.requsetSettingInfo: current configuration'},
    @{id='alarms-info';command=8;key=0;description='GeneralUtils.requsetAlarmClockInfo: existing alarms'},
    @{id='custom-face-info';command=15;key=4;description='syncProcess: existing custom-face layout; expected response key 5'},
    @{id='drink-reminder-info';command=17;key=0;description='GeneralUtils.requestDrinkReminder'},
    @{id='notification-settings-info';command=18;key=0;description='GeneralUtils.requestNewMessageRemindSetting'},
    @{id='sedentary-reminder-info';command=20;key=0;description='GeneralUtils.requestSedentaryRemind'},
    @{id='medication-reminder-info';command=16;key=0;description='GeneralUtils.requestMedicationReminder; feature flag false, support not assumed'},
    @{id='power-save-info';command=26;key=7;description='GeneralUtils.reqeustPowerSaveSwitch; feature flag false, support not assumed'},
    @{id='social-code-types-info';command=26;key=3;description='GeneralUtils.requestSocialSupport; feature flag false, support not assumed'},
    @{id='payment-code-types-info';command=26;key=5;description='GeneralUtils.requestPaymentSupport; feature flag false, support not assumed'},
    @{id='product-identification';command=32;key=0;description='GeneralUtils.requestProductIdentification; extension flag absent, support unknown'}
)
try{
    $watch=Await-WinRT ([Windows.Devices.Bluetooth.BluetoothLEDevice]::FromBluetoothAddressAsync([Convert]::ToUInt64($env:HRYFINE_WATCH_ADDRESS,16))) ([Windows.Devices.Bluetooth.BluetoothLEDevice])
    if(!$watch){throw 'Device unavailable'}
    $found=Await-WinRT ($watch.GetGattServicesAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattDeviceServicesResult])
    if([string]$found.Status -ne 'Success'){throw ('Services: '+$found.Status)}
    $services=@($found.Services);$report.services=@($services|ForEach-Object{@{uuid=[string]$_.Uuid}})
    $normal=$services|Where-Object{[string]$_.Uuid -eq '6e400001-b5a3-f393-e0a9-e50e24dcca9f'}|Select-Object -First 1
    if(!$normal){throw 'Normal channel absent'}
    $access=Await-WinRT ($normal.RequestAccessAsync()) ([Windows.Devices.Enumeration.DeviceAccessStatus])
    if([string]$access -ne 'Allowed'){throw ('Service access: '+$access)}
    $chars=Await-WinRT ($normal.GetCharacteristicsAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCharacteristicsResult])
    if([string]$chars.Status -ne 'Success'){throw ('Characteristics: '+$chars.Status)}
    $rx=$chars.Characteristics|Where-Object{[string]$_.Uuid -eq '6e400003-b5a3-f393-e0a9-e50e24dcca9f'}|Select-Object -First 1
    $tx=$chars.Characteristics|Where-Object{[string]$_.Uuid -eq '6e400002-b5a3-f393-e0a9-e50e24dcca9f'}|Select-Object -First 1
    if(!$rx -or !$tx){throw 'Incomplete channel'}
    $queue=New-Object WatchResearchNotificationQueue($rx)
    $status=Await-WinRT ($rx.WriteClientCharacteristicConfigurationDescriptorAsync([Windows.Devices.Bluetooth.GenericAttributeProfile.GattClientCharacteristicConfigurationDescriptorValue]::Notify)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus])
    if([string]$status -ne 'Success'){throw ('Notify: '+$status)};$subscribed=$true
    if($Phase -eq 'followup'){$definitions=@($definitions|Where-Object{$_.id -in @('alarms-info','bt-connect-status','today-summary','watch-faces')})}
    foreach($definition in $definitions){
        $trace=New-Object System.Collections.Generic.List[object]
        $query=[ordered]@{id=$definition.id;description=$definition.description;startedAt=[DateTime]::UtcNow.ToString('o');request=@{command=$definition.command;key=$definition.key;sent=$false};trace=$trace;frames=@();success=$false}
        $report.queries+=,$query
        try{
            [byte[]]$request=0xdf,0,5,0,([byte]$definition.command),1,([byte]$definition.key),0,0
            $request[3]=[byte](($request|Measure-Object -Sum).Sum -band 255)
            $query.request.hex=[BitConverter]::ToString($request).Replace('-','').ToLowerInvariant()
            Write-Bytes $tx $request;$query.request.sent=$true
            $trace.Add(@{at=[DateTime]::UtcNow.ToString('o');normalTx=$query.request.hex})
            $pending=New-Object System.Collections.Generic.List[byte];$deadline=[DateTime]::UtcNow.AddSeconds(6);$responseAt=$null
            while([DateTime]::UtcNow -lt $deadline){
                if($responseAt -and [DateTime]::UtcNow -gt $responseAt.AddMilliseconds(700)){break}
                [byte[]]$chunk=$queue.Take()
                if($null -eq $chunk){Start-Sleep -Milliseconds 50;continue}
                $trace.Add(@{at=[DateTime]::UtcNow.ToString('o');normalRx=[BitConverter]::ToString($chunk).Replace('-','').ToLowerInvariant()})
                $pending.AddRange($chunk)
                while($pending.Count -ge 3){
                    if($pending[0] -eq 0xfd){$length=9}elseif($pending[0] -eq 0xdf){$length=[int]$pending[1]*256+$pending[2]+4}else{throw 'Unexpected frame header'}
                    if($length -lt 9 -or $length -gt 65539){throw 'Invalid frame length'}
                    if($pending.Count -lt $length){break}
                    [byte[]]$frame=$pending.GetRange(0,$length).ToArray();$pending.RemoveRange(0,$length)
                    $sum=0;for($i=0;$i -lt $frame.Length;$i++){if($i -ne 3){$sum=($sum+$frame[$i])-band 255}}
                    if($sum -ne $frame[3]){throw 'Invalid checksum'}
                    $query.frames+=,@{at=[DateTime]::UtcNow.ToString('o');hex=[BitConverter]::ToString($frame).Replace('-','').ToLowerInvariant();header=[int]$frame[0];command=[int]$frame[4];checksumValid=$true}
                    if($frame[0] -eq 0xfd){if($frame[4] -eq $definition.command){$query.ack=@{key=[int]$frame[5];status=[int]$frame[8];auxHex=[BitConverter]::ToString($frame[6..7]).Replace('-','').ToLowerInvariant()}};continue}
                    if([int]$frame[7]*256+$frame[8]+9 -ne $frame.Length){
                        if($frame[4] -eq 15 -and $frame[6] -eq 5 -and $frame.Length -eq 26 -and $frame[7] -eq 0 -and $frame[8] -eq 11){$query.payloadLengthWarning='Observed custom-face variant: declared 11 bytes, actual 17 bytes; outer length and checksum valid'}else{throw 'Inconsistent payload length'}
                    }
                    [byte[]]$ack=0xfd,0,5,0,$frame[4],$frame[6],0,0,1;$ack[3]=[byte](($ack|Measure-Object -Sum).Sum -band 255)
                    Write-Bytes $tx $ack;$trace.Add(@{at=[DateTime]::UtcNow.ToString('o');normalAckTx=[BitConverter]::ToString($ack).Replace('-','').ToLowerInvariant()})
                    if($frame[4] -eq $definition.command){
                        $payloadHex=if($frame.Length -gt 9){[BitConverter]::ToString([byte[]]$frame[9..($frame.Length-1)]).Replace('-','').ToLowerInvariant()}else{''}
                        $query.response=@{key=[int]$frame[6];payloadHex=$payloadHex};$query.success=$true;$responseAt=[DateTime]::UtcNow
                    }
                }
            }
            if(!$query.success){$query.error='No matching data response within 6 seconds; ACK alone is not data or proof of unsupported feature'}
            if($pending.Count){$query.incompleteHex=[BitConverter]::ToString($pending.ToArray()).Replace('-','').ToLowerInvariant()}
        }catch{$query.error=$_.Exception.Message}
        $query.finishedAt=[DateTime]::UtcNow.ToString('o')
        Write-Output ($query.id+': data='+$query.success+'; key='+$query.response.key+'; payload='+$query.response.payloadHex+'; error='+$query.error)
        Start-Sleep -Milliseconds 800
    }
}catch{$report.error=$_.Exception.Message}
finally{
    if($subscribed){try{Await-WinRT ($rx.WriteClientCharacteristicConfigurationDescriptorAsync([Windows.Devices.Bluetooth.GenericAttributeProfile.GattClientCharacteristicConfigurationDescriptorValue]::None)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattCommunicationStatus]) 5000|Out-Null}catch{}}
    if($queue){$queue.Dispose()};foreach($service in $services){$service.Dispose()};if($watch){$watch.Dispose()}
    $report.finishedAt=[DateTime]::UtcNow.ToString('o')
    $directory=Join-Path (Get-Location) 'output/sessions';New-Item -ItemType Directory -Force $directory|Out-Null
    $file=Join-Path $directory ([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')+'_winrt_information.json')
    $report|ConvertTo-Json -Depth 18|Set-Content -Encoding UTF8 $file
    Write-Output ('Report: '+$file)
}
