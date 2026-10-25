if ($env:HRYFINE_WATCH_ADDRESS -notmatch '^[0-9A-Fa-f]{12}$') { throw 'Set HRYFINE_WATCH_ADDRESS to the target LE address (12 hex digits, no separators).' }
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Devices.Bluetooth.BluetoothLEDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.BluetoothCacheMode,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.GenericAttributeProfile.GattDeviceServicesResult,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
function Await-WinRT($operation, [Type]$resultType, [int]$timeoutMs = 15000) {
    $method = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
    $task = $method.MakeGenericMethod($resultType).Invoke($null, @($operation))
    if (-not $task.Wait($timeoutMs)) { try { $operation.Cancel() } catch {}; throw 'Timed out waiting for the Windows Bluetooth response.' }
    return $task.Result
}
$watch = $null
try {
    $address = [Convert]::ToUInt64($env:HRYFINE_WATCH_ADDRESS, 16)
    $watch = Await-WinRT ([Windows.Devices.Bluetooth.BluetoothLEDevice]::FromBluetoothAddressAsync($address)) ([Windows.Devices.Bluetooth.BluetoothLEDevice])
    if ($null -eq $watch) { throw 'Windows did not return a device for the specified LE address.' }
    Write-Output ('Windows device: ' + $watch.Name + '; state: ' + $watch.ConnectionStatus)
    $result = Await-WinRT ($watch.GetGattServicesAsync([Windows.Devices.Bluetooth.BluetoothCacheMode]::Uncached)) ([Windows.Devices.Bluetooth.GenericAttributeProfile.GattDeviceServicesResult])
    [PSCustomObject]@{Name=$watch.Name;ConnectionStatus=[string]$watch.ConnectionStatus;Status=[string]$result.Status;Services=@($result.Services | ForEach-Object { [string]$_.Uuid })} | ConvertTo-Json -Depth 4
} finally { if ($null -ne $watch) { $watch.Dispose() } }
