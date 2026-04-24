<#
  Screen Assist — PowerShell + Windows Forms
  Keeps the PC awake by moving the mouse after 30 s of inactivity.

  Double-click screen_assist.ps1 → right-click → "Run with PowerShell"
  Or from a terminal:  powershell -ExecutionPolicy Bypass -File screen_assist.ps1
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ── Win32 helpers ────────────────────────────────────────────────────
Add-Type @"
using System;
using System.Runtime.InteropServices;

public struct POINT { public int X; public int Y; }

public class Win32Mouse {
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT pt);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
}

public class AppId {
    [DllImport("shell32.dll", SetLastError = true)]
    public static extern void SetCurrentProcessExplicitAppUserModelID(
        [MarshalAs(UnmanagedType.LPWStr)] string AppID);
}
"@

# Set unique App ID so Windows taskbar shows our icon, not PowerShell's
[AppId]::SetCurrentProcessExplicitAppUserModelID("ScreenAssist.1")

# ── Settings ─────────────────────────────────────────────────────────
$idleTimeout  = 60     # seconds before jiggle
$jiggleRange  = 1      # max pixels per jiggle
$pollMs       = 500    # timer tick interval

# ── State ────────────────────────────────────────────────────────────
$script:lastX         = 0
$script:lastY         = 0
$script:lastMoveTime  = [DateTime]::UtcNow
$script:running       = $false
$script:stopTime      = $null

# ── Form ─────────────────────────────────────────────────────────────
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Screen Assist"
$form.Size            = New-Object System.Drawing.Size(300, 220)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false
$form.TopMost         = $true
$form.Font            = New-Object System.Drawing.Font("Segoe UI", 10)

# Icon — try embedded exe icon first, then fall back to .ico file
try {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exePath)
} catch {
    $icoPath = Join-Path $PSScriptRoot "screen_assist.ico"
    if (Test-Path $icoPath) { $form.Icon = New-Object System.Drawing.Icon($icoPath) }
}
$form.ShowInTaskbar   = $true

# Status label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text      = "Stopped"
$lblStatus.Font      = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblStatus.AutoSize  = $true
$lblStatus.Location  = New-Object System.Drawing.Point(90, 12)
$form.Controls.Add($lblStatus)

# Timer countdown label
$lblTimer = New-Object System.Windows.Forms.Label
$lblTimer.Text      = "Idle: --"
$lblTimer.Font      = New-Object System.Drawing.Font("Segoe UI", 11)
$lblTimer.AutoSize  = $true
$lblTimer.Location  = New-Object System.Drawing.Point(90, 45)
$form.Controls.Add($lblTimer)

# Duration dropdown
$lblDuration = New-Object System.Windows.Forms.Label
$lblDuration.Text     = "Duration:"
$lblDuration.AutoSize = $true
$lblDuration.Location = New-Object System.Drawing.Point(20, 82)

$cmbDuration = New-Object System.Windows.Forms.ComboBox
$cmbDuration.DropDownStyle = "DropDownList"
$cmbDuration.Size     = New-Object System.Drawing.Size(130, 28)
$cmbDuration.Location = New-Object System.Drawing.Point(100, 78)
$cmbDuration.Items.AddRange(@("Unlimited", "10 minutes", "30 minutes", "1 hour", "2 hours", "4 hours"))
$cmbDuration.SelectedIndex = 0

$form.Controls.AddRange(@($lblDuration, $cmbDuration))

# Remaining-time label
$lblRemaining = New-Object System.Windows.Forms.Label
$lblRemaining.Text     = ""
$lblRemaining.AutoSize = $true
$lblRemaining.Location = New-Object System.Drawing.Point(90, 110)
$form.Controls.Add($lblRemaining)

# Buttons
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text     = "Start"
$btnStart.Size     = New-Object System.Drawing.Size(75, 32)
$btnStart.Location = New-Object System.Drawing.Point(20, 138)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text     = "Stop"
$btnStop.Size     = New-Object System.Drawing.Size(75, 32)
$btnStop.Location = New-Object System.Drawing.Point(108, 138)

$btnQuit = New-Object System.Windows.Forms.Button
$btnQuit.Text     = "Quit"
$btnQuit.Size     = New-Object System.Drawing.Size(75, 32)
$btnQuit.Location = New-Object System.Drawing.Point(196, 138)

$form.Controls.AddRange(@($btnStart, $btnStop, $btnQuit))

# ── Poll timer ───────────────────────────────────────────────────────
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $pollMs

$timer.Add_Tick({
    $pt = New-Object POINT
    [Win32Mouse]::GetCursorPos([ref]$pt) | Out-Null

    if ($pt.X -ne $script:lastX -or $pt.Y -ne $script:lastY) {
        $script:lastX        = $pt.X
        $script:lastY        = $pt.Y
        $script:lastMoveTime = [DateTime]::UtcNow
    }

    $idle = ([DateTime]::UtcNow - $script:lastMoveTime).TotalSeconds
    $remaining = [Math]::Max(0, $idleTimeout - $idle)
    $lblTimer.Text = "Idle: $([Math]::Floor($remaining))s left"

    if ($idle -ge $idleTimeout) {
        $rng  = New-Object System.Random
        $dx   = $rng.Next(-$jiggleRange, $jiggleRange + 1)
        $dy   = $rng.Next(-$jiggleRange, $jiggleRange + 1)
        $newX = [Math]::Max(0, $pt.X + $dx)
        $newY = [Math]::Max(0, $pt.Y + $dy)
        [Win32Mouse]::SetCursorPos($newX, $newY) | Out-Null

        $script:lastX        = $newX
        $script:lastY        = $newY
        $script:lastMoveTime = [DateTime]::UtcNow
    }

    # Auto-stop when duration expires (skip if Unlimited)
    if ($null -ne $script:stopTime) {
        $left = ($script:stopTime - [DateTime]::UtcNow).TotalSeconds
        if ($left -le 0) {
            $timer.Stop()
            $script:running      = $false
            $script:stopTime     = $null
            $lblStatus.Text      = "Stopped"
            $lblStatus.ForeColor = [System.Drawing.Color]::Black
            $lblTimer.Text       = "Idle: --"
            $lblRemaining.Text   = "Timer finished"
            $cmbDuration.Enabled = $true
        } else {
            $ts = [TimeSpan]::FromSeconds([Math]::Ceiling($left))
            $lblRemaining.Text = "Stops in: $($ts.ToString('hh\:mm\:ss'))"
        }
    }
})

# ── Button handlers ──────────────────────────────────────────────────
$btnStart.Add_Click({
    if (-not $script:running) {
        $pt = New-Object POINT
        [Win32Mouse]::GetCursorPos([ref]$pt) | Out-Null
        $script:lastX        = $pt.X
        $script:lastY        = $pt.Y
        $script:lastMoveTime = [DateTime]::UtcNow
        $script:running      = $true

        # Calculate stop time from dropdown
        if ($cmbDuration.SelectedItem -eq "Unlimited") {
            $script:stopTime = $null
        } else {
            $durationMinutes = switch ($cmbDuration.SelectedItem) {
                "10 minutes" { 10 }
                "30 minutes" { 30 }
                "1 hour"     { 60 }
                "2 hours"    { 120 }
                "4 hours"    { 240 }
            }
            $script:stopTime = [DateTime]::UtcNow.AddMinutes($durationMinutes)
        }
        $cmbDuration.Enabled = $false

        $timer.Start()
        $lblStatus.Text      = "Running"
        $lblStatus.ForeColor = [System.Drawing.Color]::Green
    }
})

$btnStop.Add_Click({
    $timer.Stop()
    $script:running      = $false
    $script:stopTime     = $null
    $lblStatus.Text      = "Stopped"
    $lblStatus.ForeColor = [System.Drawing.Color]::Black
    $lblTimer.Text       = "Idle: --"
    $lblRemaining.Text   = ""
    $cmbDuration.Enabled = $true
})

$btnQuit.Add_Click({
    $timer.Stop()
    $form.Close()
})

$form.Add_FormClosing({ $timer.Stop() })

# ── Auto-start on launch ────────────────────────────────────────────
$form.Add_Shown({ $btnStart.PerformClick() })

# ── Go ───────────────────────────────────────────────────────────────
[System.Windows.Forms.Application]::Run($form)
