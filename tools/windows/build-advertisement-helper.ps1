$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Devices.Bluetooth.BluetoothLEDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
$compiler = Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$metadata = Join-Path $env:windir 'System32\WinMetadata'
$arguments = @('/nologo','/target:library',('/out:' + (Join-Path $PSScriptRoot 'WindowsAdvertisementQueue.dll')))
foreach ($name in @('Windows.Devices.winmd','Windows.Foundation.winmd','Windows.Storage.winmd')) { $arguments += '/r:' + (Join-Path $metadata $name) }
foreach ($name in @('System.Runtime','System.Runtime.InteropServices.WindowsRuntime','System.Runtime.WindowsRuntime')) {
    $assembly = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq $name } | Select-Object -First 1
    if ($null -eq $assembly) { throw ('Referenced assembly unavailable: ' + $name) }
    $arguments += '/r:' + $assembly.Location
}
$arguments += Join-Path $PSScriptRoot 'WindowsAdvertisementQueue.cs'
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw 'Native Bluetooth helper compilation failed.' }
