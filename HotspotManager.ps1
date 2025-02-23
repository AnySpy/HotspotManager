Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow)
'

$consolePtr = [Console.Window]::GetConsoleWindow()

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { 
    $_.Name -eq 'AsTask' -and 
    $_.GetParameters().Count -eq 1 -and 
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' 
})[0]

$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()

$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile)

Function HideConsole() {
    [Console.Window]::ShowWindow($SCRIPT:consolePtr, 0)
}

Function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

function CheckAndStartTethering {
    try {
        $tetheringState = $tetheringManager.TetheringOperationalState

        Write-Output "Current Tethering State: $tetheringState"

        if ($tetheringState -eq [Windows.Networking.NetworkOperators.TetheringOperationalState]::Off) {
            Write-Output "Tethering is not active. Attempting to start..."

            $startResult = Await ($tetheringManager.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])

            Write-Output "Start Tethering Result: $($startResult.Status)"
        } else {
            Write-Output "Tethering is already active."
        }
    } catch {
        Write-Output "An error occurred: $_"
    }
}

while ($true) {
    CheckAndStartTethering

    Start-Sleep -Seconds 15
}