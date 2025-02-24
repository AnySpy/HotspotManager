Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Windows.Forms
Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0)

$logFilePath = "$env:TEMP\HotspotManager.log"
$settingsFilePath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "HotspotManager.Settings.json"

try {
    if (Test-Path $settingsFilePath) {
        $settings = Get-Content -Path $settingsFilePath | ConvertFrom-Json
    } else {
        $settings = [PSCustomObject]@{
            TimerInterval = 15000
        }
        $settings | ConvertTo-Json | Set-Content -Path $settingsFilePath
    }
}
catch {
    Write-Output "Failed to load settings: $_"
    exit 1
}

try {
    $streamWriter = [System.IO.StreamWriter]::new($logFilePath, $false)
    $streamWriter.AutoFlush = $true
} catch {
    Write-Output "Failed to initialize StreamWriter: $_"
    exit 1
}

Function LogMessage($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    $streamWriter.WriteLine($logEntry)
    Write-Output $logEntry
}

Function Await($WinRtTask, $ResultType) {
    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { 
        $_.Name -eq 'AsTask' -and 
        $_.GetParameters().Count -eq 1 -and 
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' 
    })[0]
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

function CheckAndStartTethering {
    try {
        $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()
        if ($null -eq $connectionProfile) {
            LogMessage "No internet connection profile found."
            return
        }
        $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile)
        $tetheringState = $tetheringManager.TetheringOperationalState
        if ($tetheringState -eq [Windows.Networking.NetworkOperators.TetheringOperationalState]::Off) {
            LogMessage "Tethering is not active. Attempting to start..."
            $startResult = Await ($tetheringManager.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
            LogMessage "Start Tethering Result: $($startResult.Status)"
        }
    } catch {
        LogMessage "An error occurred: $_"
    }
}

function SaveSettings {
    try {
        $settings | ConvertTo-Json | Set-Content -Path $settingsFilePath
        LogMessage "Settings saved successfully."
    } catch {
        LogMessage "Failed to save settings: $_"
    }
}

function ShowSettings {
    Add-Type -AssemblyName System.Windows.Forms

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Hotspot Manager Settings"
    $form.Width = 300
    $form.Height = 200

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Timer Interval (ms):"
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(20, 50)
    $textBox.Width = 240
    $textBox.Text = $settings.TimerInterval
    $form.Controls.Add($textBox)

    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "Save"
    $saveButton.Location = New-Object System.Drawing.Point(100, 100)
    $saveButton.Add_Click({
        $settings.TimerInterval = [int]$textBox.Text
        SaveSettings
        $form.Close()
    })
    $form.Controls.Add($saveButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Location = New-Object System.Drawing.Point(180, 100)
    $cancelButton.Add_Click({
        $form.Close()
    })
    $form.Controls.Add($cancelButton)

    $form.ShowDialog()
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 15000
$timer.Add_Tick({
    CheckAndStartTethering
})
$timer.Start()

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
$notifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$menuItemSettings = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemSettings.Text = "Settings"
$menuItemSettings.Add_Click({
    ShowSettings
    $timer.Interval = $settings.TimerInterval
})
$contextMenu.Items.Add($menuItemSettings)

$menuItemExit = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemExit.Text = "Exit"
$menuItemExit.Add_Click({
    $notifyIcon.Visible = $false
    $timer.Stop()
    if ($streamWriter) {
        $streamWriter.Close()
    }
    [System.Windows.Forms.Application]::Exit()
})
$contextMenu.Items.Add($menuItemExit)

$notifyIcon.ContextMenuStrip = $contextMenu

$notifyIcon.Text = "Hotspot Manager"

[System.Windows.Forms.Application]::Run()

if($streamWriter) {
    $streamWriter.Close()
}