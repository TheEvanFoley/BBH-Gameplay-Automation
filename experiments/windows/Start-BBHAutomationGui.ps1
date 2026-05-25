[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function ConvertTo-ArgumentString {
    param(
        [string[]]$Arguments
    )

    $escaped = foreach ($argument in $Arguments) {
        if ($null -eq $argument) {
            continue
        }

        if ($argument -match '[\s"]') {
            '"' + ($argument -replace '"', '\"') + '"'
        }
        else {
            $argument
        }
    }

    return ($escaped -join ' ')
}

function Add-LogLine {
    param(
        [string]$Text
    )

    if ($null -eq $Text) {
        return
    }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $logTextBox.AppendText("[$timestamp] $Text`r`n")
    $logTextBox.SelectionStart = $logTextBox.TextLength
    $logTextBox.ScrollToCaret()
}

function Set-StopButtonState {
    param(
        [bool]$Enabled
    )

    if ($Enabled) {
        $stopButton.Enabled = $true
        $stopButton.Text = "Stop Workflow (Esc)"
        $stopButton.UseVisualStyleBackColor = $false
        $stopButton.BackColor = [System.Drawing.Color]::FromArgb(192, 57, 43)
        $stopButton.ForeColor = [System.Drawing.Color]::White
    }
    else {
        $stopButton.Enabled = $false
        $stopButton.Text = "Stop Workflow"
        $stopButton.UseVisualStyleBackColor = $true
        $stopButton.ForeColor = [System.Drawing.SystemColors]::ControlText
    }
}

function Set-ActionButtonsEnabled {
    param(
        [bool]$Enabled
    )

    $launchButton.Enabled = $Enabled
    $routeButton.Enabled = $Enabled
    $recordSiteButton.Enabled = $Enabled
    $recordCurrentSetupButton.Enabled = $Enabled
    $recordTrekButton.Enabled = $Enabled
    $recordAdventureButton.Enabled = $Enabled
    $clearLogButton.Enabled = $Enabled
    $openRecordingsButton.Enabled = $true
    Set-StopButtonState -Enabled (-not $Enabled)
}

function Get-SelectedConfig {
    return [pscustomobject]@{
        StartingScreen = [string]$startingScreenCombo.SelectedItem
        Weapon = [string]$weaponCombo.SelectedItem
        Adventure = [string]$adventureCombo.SelectedItem
        Trek = [string]$trekCombo.SelectedItem
        Site = [int]$siteCombo.SelectedItem
        PlayerName = [string]$playerNameTextBox.Text
        Notes = [string]$notesTextBox.Text
        MaxRecordingSeconds = [int]$recordSecondsNumeric.Value
        SiteCycleSeconds = [int]$siteCycleNumeric.Value
        RepeatCount = [int]$repeatCountNumeric.Value
        DryRun = [bool]$dryRunCheckBox.Checked
    }
}

function Reset-RunState {
    $script:stopRequested = $false
    if ($script:stopHelperProcess) {
        try {
            if (-not $script:stopHelperProcess.HasExited) {
                $script:stopHelperProcess.Kill()
            }
        }
        catch {
        }

        try {
            $script:stopHelperProcess.Dispose()
        }
        catch {
        }

        $script:stopHelperProcess = $null
    }
}

function Start-WorkflowProcess {
    param(
        [string]$ActionName
    )

    if ($script:activeProcess -and -not $script:activeProcess.HasExited) {
        Add-LogLine "Another workflow is already running."
        return
    }

    $selection = Get-SelectedConfig
    $workflowScriptPath = Join-Path $PSScriptRoot "Invoke-BBHWorkflow.ps1"
    $argumentList = @(
        "-NoProfile"
        "-ExecutionPolicy"; "Bypass"
        "-File"; $workflowScriptPath
        "-Action"; $ActionName
        "-StartingScreen"; $selection.StartingScreen
        "-Weapon"; $selection.Weapon
        "-Adventure"; $selection.Adventure
        "-Trek"; $selection.Trek
        "-Site"; [string]$selection.Site
        "-PlayerName"; $selection.PlayerName
        "-MaxRecordingSeconds"; [string]$selection.MaxRecordingSeconds
        "-SiteCycleSeconds"; [string]$selection.SiteCycleSeconds
        "-RepeatCount"; [string]$selection.RepeatCount
    )

    if (-not [string]::IsNullOrWhiteSpace($selection.Notes)) {
        $argumentList += @("-Notes", $selection.Notes)
    }

    if ($selection.DryRun) {
        $argumentList += "-DryRun"
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "powershell.exe"
    $psi.Arguments = ConvertTo-ArgumentString -Arguments $argumentList
    $psi.WorkingDirectory = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $script:activeProcess = [System.Diagnostics.Process]::new()
    $script:activeProcess.StartInfo = $psi
    Reset-RunState

    Add-LogLine ("Starting workflow: {0}" -f $ActionName)
    Add-LogLine ("Arguments: {0}" -f $psi.Arguments)
    $null = $script:activeProcess.Start()
    Set-ActionButtonsEnabled -Enabled $false
    $pollTimer.Start()
}

function Stop-WorkflowProcess {
    if (-not $script:activeProcess -or $script:activeProcess.HasExited) {
        Add-LogLine "No active workflow to stop."
        return
    }

    if ($script:stopRequested) {
        Add-LogLine "Stop already requested. Waiting for the workflow to exit."
        return
    }

    $script:stopRequested = $true
    $stopButton.Enabled = $false
    Add-LogLine "Stopping active workflow..."

    try {
        $helperScriptPath = Join-Path $PSScriptRoot "Stop-BBHAutomationProcess.ps1"
        $captureConfigPath = Join-Path $PSScriptRoot "obs-capture.local.json"

        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = "powershell.exe"
        $psi.Arguments = ConvertTo-ArgumentString -Arguments @(
            "-NoProfile"
            "-ExecutionPolicy"; "Bypass"
            "-File"; $helperScriptPath
            "-WorkflowProcessId"; [string]$script:activeProcess.Id
            "-CaptureConfigPath"; $captureConfigPath
        )
        $psi.WorkingDirectory = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $script:stopHelperProcess = [System.Diagnostics.Process]::new()
        $script:stopHelperProcess.StartInfo = $psi
        $null = $script:stopHelperProcess.Start()
        Add-LogLine ("Stop helper started for workflow PID {0}" -f $script:activeProcess.Id)
    }
    catch {
        Add-LogLine ("ERROR: failed to start stop helper: " + $_.Exception.Message)
        $script:stopRequested = $false
        $stopButton.Enabled = $true
    }
}

$form = [System.Windows.Forms.Form]::new()
$form.Text = "BBH Automation Console"
$form.StartPosition = "CenterScreen"
$form.Size = [System.Drawing.Size]::new(980, 760)
$form.MinimumSize = [System.Drawing.Size]::new(980, 760)
$form.KeyPreview = $true

$titleLabel = [System.Windows.Forms.Label]::new()
$titleLabel.Text = "BBH Gameplay Automation"
$titleLabel.Font = [System.Drawing.Font]::new("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.AutoSize = $true
$titleLabel.Location = [System.Drawing.Point]::new(20, 16)
$form.Controls.Add($titleLabel)

$subtitleLabel = [System.Windows.Forms.Label]::new()
$subtitleLabel.Text = "Launch, route, and record site captures without using chat."
$subtitleLabel.AutoSize = $true
$subtitleLabel.Location = [System.Drawing.Point]::new(22, 48)
$form.Controls.Add($subtitleLabel)

$settingsGroup = [System.Windows.Forms.GroupBox]::new()
$settingsGroup.Text = "Run Settings"
$settingsGroup.Location = [System.Drawing.Point]::new(20, 80)
$settingsGroup.Size = [System.Drawing.Size]::new(930, 250)
$form.Controls.Add($settingsGroup)

function New-FieldLabel {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y
    )

    $label = [System.Windows.Forms.Label]::new()
    $label.Text = $Text
    $label.AutoSize = $true
    $label.Location = [System.Drawing.Point]::new($X, $Y)
    $settingsGroup.Controls.Add($label)
    return $label
}

function New-ComboBox {
    param(
        [string[]]$Items,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [string]$DefaultItem
    )

    $combo = [System.Windows.Forms.ComboBox]::new()
    $combo.DropDownStyle = "DropDownList"
    $combo.Location = [System.Drawing.Point]::new($X, $Y)
    $combo.Size = [System.Drawing.Size]::new($Width, 28)
    [void]$combo.Items.AddRange($Items)
    $combo.SelectedItem = $DefaultItem
    $settingsGroup.Controls.Add($combo)
    return $combo
}

New-FieldLabel -Text "Starting Screen" -X 20 -Y 32 | Out-Null
$startingScreenCombo = New-ComboBox -Items @("Game Closed", "Main Menu", "Adventure Selection", "Trek Selection", "Site Selection") -X 20 -Y 54 -Width 180 -DefaultItem "Site Selection"

New-FieldLabel -Text "Weapon" -X 220 -Y 32 | Out-Null
$weaponCombo = New-ComboBox -Items @("Gun", "Bow") -X 220 -Y 54 -Width 120 -DefaultItem "Gun"

New-FieldLabel -Text "Adventure" -X 360 -Y 32 | Out-Null
$adventureCombo = New-ComboBox -Items @(
    "Whitetail Deer",
    "Bighorn Sheep",
    "Caribou",
    "Elk",
    "Gemsbock",
    "Irish Elk",
    "Kudu",
    "Moose",
    "Wildebeest",
    "Buckzilla",
    "Zombie Deer"
) -X 360 -Y 54 -Width 180 -DefaultItem "Elk"

New-FieldLabel -Text "Trek" -X 560 -Y 32 | Out-Null
$trekCombo = New-ComboBox -Items @("Trek 1", "Trek 2", "Trek 3") -X 560 -Y 54 -Width 120 -DefaultItem "Trek 3"

New-FieldLabel -Text "Site / Start Site" -X 700 -Y 32 | Out-Null
$siteCombo = New-ComboBox -Items @("1", "2", "3", "4", "5") -X 700 -Y 54 -Width 120 -DefaultItem "1"

New-FieldLabel -Text "Player Name" -X 20 -Y 100 | Out-Null
$playerNameTextBox = [System.Windows.Forms.TextBox]::new()
$playerNameTextBox.Location = [System.Drawing.Point]::new(20, 122)
$playerNameTextBox.Size = [System.Drawing.Size]::new(180, 28)
$playerNameTextBox.Text = "CODEX"
$settingsGroup.Controls.Add($playerNameTextBox)

New-FieldLabel -Text "Recording Seconds" -X 220 -Y 100 | Out-Null
$recordSecondsNumeric = [System.Windows.Forms.NumericUpDown]::new()
$recordSecondsNumeric.Location = [System.Drawing.Point]::new(220, 122)
$recordSecondsNumeric.Size = [System.Drawing.Size]::new(120, 28)
$recordSecondsNumeric.Minimum = 5
$recordSecondsNumeric.Maximum = 300
$recordSecondsNumeric.Value = 35
$settingsGroup.Controls.Add($recordSecondsNumeric)

New-FieldLabel -Text "Trek Cycle Seconds" -X 360 -Y 100 | Out-Null
$siteCycleNumeric = [System.Windows.Forms.NumericUpDown]::new()
$siteCycleNumeric.Location = [System.Drawing.Point]::new(360, 122)
$siteCycleNumeric.Size = [System.Drawing.Size]::new(120, 28)
$siteCycleNumeric.Minimum = 10
$siteCycleNumeric.Maximum = 600
$siteCycleNumeric.Value = 45
$settingsGroup.Controls.Add($siteCycleNumeric)

New-FieldLabel -Text "Repeat Count" -X 500 -Y 100 | Out-Null
$repeatCountNumeric = [System.Windows.Forms.NumericUpDown]::new()
$repeatCountNumeric.Location = [System.Drawing.Point]::new(500, 122)
$repeatCountNumeric.Size = [System.Drawing.Size]::new(120, 28)
$repeatCountNumeric.Minimum = 1
$repeatCountNumeric.Maximum = 25
$repeatCountNumeric.Value = 1
$settingsGroup.Controls.Add($repeatCountNumeric)

$dryRunCheckBox = [System.Windows.Forms.CheckBox]::new()
$dryRunCheckBox.Text = "Dry run"
$dryRunCheckBox.AutoSize = $true
$dryRunCheckBox.Location = [System.Drawing.Point]::new(640, 124)
$settingsGroup.Controls.Add($dryRunCheckBox)

$startingScreenHint = [System.Windows.Forms.Label]::new()
$startingScreenHint.Text = "Only 'Game Closed' changes behavior directly. Other values document where you are before the workflow resumes."
$startingScreenHint.AutoSize = $true
$startingScreenHint.MaximumSize = [System.Drawing.Size]::new(860, 0)
$startingScreenHint.Location = [System.Drawing.Point]::new(20, 160)
$settingsGroup.Controls.Add($startingScreenHint)

New-FieldLabel -Text "Notes" -X 20 -Y 192 | Out-Null
$notesTextBox = [System.Windows.Forms.TextBox]::new()
$notesTextBox.Location = [System.Drawing.Point]::new(20, 214)
$notesTextBox.Size = [System.Drawing.Size]::new(860, 24)
$settingsGroup.Controls.Add($notesTextBox)

$actionsGroup = [System.Windows.Forms.GroupBox]::new()
$actionsGroup.Text = "Actions"
$actionsGroup.Location = [System.Drawing.Point]::new(20, 345)
$actionsGroup.Size = [System.Drawing.Size]::new(930, 125)
$form.Controls.Add($actionsGroup)

$launchButton = [System.Windows.Forms.Button]::new()
$launchButton.Text = "Launch Game"
$launchButton.Location = [System.Drawing.Point]::new(20, 35)
$launchButton.Size = [System.Drawing.Size]::new(130, 36)
$actionsGroup.Controls.Add($launchButton)

$routeButton = [System.Windows.Forms.Button]::new()
$routeButton.Text = "Route To Site"
$routeButton.Location = [System.Drawing.Point]::new(165, 35)
$routeButton.Size = [System.Drawing.Size]::new(130, 36)
$actionsGroup.Controls.Add($routeButton)

$recordSiteButton = [System.Windows.Forms.Button]::new()
$recordSiteButton.Text = "Record Site"
$recordSiteButton.Location = [System.Drawing.Point]::new(310, 35)
$recordSiteButton.Size = [System.Drawing.Size]::new(120, 36)
$actionsGroup.Controls.Add($recordSiteButton)

$recordCurrentSetupButton = [System.Windows.Forms.Button]::new()
$recordCurrentSetupButton.Text = "Record Current Setup"
$recordCurrentSetupButton.Location = [System.Drawing.Point]::new(445, 35)
$recordCurrentSetupButton.Size = [System.Drawing.Size]::new(155, 36)
$actionsGroup.Controls.Add($recordCurrentSetupButton)

$recordTrekButton = [System.Windows.Forms.Button]::new()
$recordTrekButton.Text = "Record Full Trek"
$recordTrekButton.Location = [System.Drawing.Point]::new(615, 35)
$recordTrekButton.Size = [System.Drawing.Size]::new(140, 36)
$actionsGroup.Controls.Add($recordTrekButton)

$recordAdventureButton = [System.Windows.Forms.Button]::new()
$recordAdventureButton.Text = "Record Adventure"
$recordAdventureButton.Location = [System.Drawing.Point]::new(165, 78)
$recordAdventureButton.Size = [System.Drawing.Size]::new(150, 36)
$actionsGroup.Controls.Add($recordAdventureButton)

$stopButton = [System.Windows.Forms.Button]::new()
$stopButton.Text = "Stop Workflow"
$stopButton.Location = [System.Drawing.Point]::new(330, 78)
$stopButton.Size = [System.Drawing.Size]::new(140, 36)
$stopButton.Enabled = $false
$actionsGroup.Controls.Add($stopButton)

$openRecordingsButton = [System.Windows.Forms.Button]::new()
$openRecordingsButton.Text = "Open Recordings"
$openRecordingsButton.Location = [System.Drawing.Point]::new(770, 35)
$openRecordingsButton.Size = [System.Drawing.Size]::new(125, 36)
$actionsGroup.Controls.Add($openRecordingsButton)

$clearLogButton = [System.Windows.Forms.Button]::new()
$clearLogButton.Text = "Clear Log"
$clearLogButton.Location = [System.Drawing.Point]::new(20, 78)
$clearLogButton.Size = [System.Drawing.Size]::new(120, 36)
$actionsGroup.Controls.Add($clearLogButton)

$logGroup = [System.Windows.Forms.GroupBox]::new()
$logGroup.Text = "Run Log"
$logGroup.Location = [System.Drawing.Point]::new(20, 485)
$logGroup.Size = [System.Drawing.Size]::new(930, 240)
$form.Controls.Add($logGroup)

$logTextBox = [System.Windows.Forms.TextBox]::new()
$logTextBox.Multiline = $true
$logTextBox.ReadOnly = $true
$logTextBox.ScrollBars = "Vertical"
$logTextBox.Font = [System.Drawing.Font]::new("Consolas", 9)
$logTextBox.Location = [System.Drawing.Point]::new(15, 28)
$logTextBox.Size = [System.Drawing.Size]::new(900, 195)
$logGroup.Controls.Add($logTextBox)

$script:activeProcess = $null
$script:stopHelperProcess = $null
$script:stopRequested = $false
$pollTimer = [System.Windows.Forms.Timer]::new()
$pollTimer.Interval = 300
$pollTimer.Add_Tick({
    if (-not $script:activeProcess) {
        $pollTimer.Stop()
        return
    }

    while ($script:activeProcess.StandardOutput -and -not $script:activeProcess.StandardOutput.EndOfStream) {
        Add-LogLine -Text $script:activeProcess.StandardOutput.ReadLine()
    }

    while ($script:activeProcess.StandardError -and -not $script:activeProcess.StandardError.EndOfStream) {
        Add-LogLine -Text ("ERROR: " + $script:activeProcess.StandardError.ReadLine())
    }

    if ($script:activeProcess.HasExited) {
        while ($script:activeProcess.StandardOutput -and -not $script:activeProcess.StandardOutput.EndOfStream) {
            Add-LogLine -Text $script:activeProcess.StandardOutput.ReadLine()
        }

        while ($script:activeProcess.StandardError -and -not $script:activeProcess.StandardError.EndOfStream) {
            Add-LogLine -Text ("ERROR: " + $script:activeProcess.StandardError.ReadLine())
        }

        Add-LogLine -Text ("Workflow exited with code {0}" -f $script:activeProcess.ExitCode)
        if ($script:stopRequested) {
            Add-LogLine -Text "Workflow stop completed."
        }
        $script:activeProcess.Dispose()
        $script:activeProcess = $null
        $pollTimer.Stop()
        Reset-RunState
        Set-ActionButtonsEnabled -Enabled $true
    }
})

$launchButton.Add_Click({ Start-WorkflowProcess -ActionName "LaunchGame" })
$routeButton.Add_Click({ Start-WorkflowProcess -ActionName "RouteToSiteSelection" })
$recordSiteButton.Add_Click({ Start-WorkflowProcess -ActionName "RecordSite" })
$recordCurrentSetupButton.Add_Click({ Start-WorkflowProcess -ActionName "RecordCurrentSetup" })
$recordTrekButton.Add_Click({ Start-WorkflowProcess -ActionName "RecordTrek" })
$recordAdventureButton.Add_Click({ Start-WorkflowProcess -ActionName "RecordAdventure" })
$stopButton.Add_Click({ Stop-WorkflowProcess })
$form.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape -and $script:activeProcess -and -not $script:activeProcess.HasExited) {
        Stop-WorkflowProcess
        $_.Handled = $true
    }
})
$clearLogButton.Add_Click({ $logTextBox.Clear() })
$openRecordingsButton.Add_Click({
    $captureConfigPath = Join-Path $PSScriptRoot "obs-capture.local.json"
    $captureConfig = Get-Content -LiteralPath $captureConfigPath -Raw | ConvertFrom-Json
    Start-Process explorer.exe ([string]$captureConfig.captureRoot)
})

$form.Add_FormClosing({
    if ($script:activeProcess -and -not $script:activeProcess.HasExited) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "A workflow is still running. Close the GUI anyway?",
            "Workflow Running",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($result -eq [System.Windows.Forms.DialogResult]::No) {
            $_.Cancel = $true
        }
        else {
            Stop-WorkflowProcess
        }
    }
})

Add-LogLine -Text "GUI ready."
Add-LogLine -Text "Use 'Launch Game' when BBH is closed, or go straight to route/record actions when the game is already running."
Add-LogLine -Text "Press Esc during an active workflow as an emergency stop shortcut."
[void]$form.ShowDialog()
