$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Devices.Bluetooth.BluetoothLEDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Enumeration.DeviceInformation,Windows.Devices.Enumeration,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Enumeration.DeviceInformationCollection,Windows.Devices.Enumeration,ContentType=WindowsRuntime] | Out-Null
$selector = [Windows.Devices.Bluetooth.BluetoothLEDevice]::GetDeviceSelector()
$operation = [Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($selector)
$method = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
$task = $method.MakeGenericMethod([Windows.Devices.Enumeration.DeviceInformationCollection]).Invoke($null, @($operation))
if (-not $task.Wait(15000)) { throw 'Timed out enumerating Bluetooth devices.' }
$task.Result | Select-Object Name,Id,@{Name='Paired';Expression={$_.Pairing.IsPaired}} | ConvertTo-Json -Depth 3
