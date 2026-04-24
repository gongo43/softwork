<#
  Mouse Jiggler — PowerShell + Windows Forms
  Keeps the PC awake by moving the mouse after 30 s of inactivity.

  Double-click mouse_jiggler.ps1 → right-click → "Run with PowerShell"
  Or from a terminal:  powershell -ExecutionPolicy Bypass -File mouse_jiggler.ps1
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
"@

# ── Settings ─────────────────────────────────────────────────────────
$idleTimeout  = 30     # seconds before jiggle
$jiggleRange  = 1      # max pixels per jiggle
$pollMs       = 500    # timer tick interval

# ── State ────────────────────────────────────────────────────────────
$script:lastX         = 0
$script:lastY         = 0
$script:lastMoveTime  = [DateTime]::UtcNow
$script:running       = $false

# ── Form ─────────────────────────────────────────────────────────────
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Mouse Jiggler"
$form.Size            = New-Object System.Drawing.Size(300, 180)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false
$form.TopMost         = $true
$form.Font            = New-Object System.Drawing.Font("Segoe UI", 10)

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

# Buttons
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text     = "Start"
$btnStart.Size     = New-Object System.Drawing.Size(75, 32)
$btnStart.Location = New-Object System.Drawing.Point(20, 90)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text     = "Stop"
$btnStop.Size     = New-Object System.Drawing.Size(75, 32)
$btnStop.Location = New-Object System.Drawing.Point(108, 90)

$btnQuit = New-Object System.Windows.Forms.Button
$btnQuit.Text     = "Quit"
$btnQuit.Size     = New-Object System.Drawing.Size(75, 32)
$btnQuit.Location = New-Object System.Drawing.Point(196, 90)

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
        $timer.Start()
        $lblStatus.Text = "Running"
        $lblStatus.ForeColor = [System.Drawing.Color]::Green
    }
})

$btnStop.Add_Click({
    $timer.Stop()
    $script:running   = $false
    $lblStatus.Text   = "Stopped"
    $lblStatus.ForeColor = [System.Drawing.Color]::Black
    $lblTimer.Text    = "Idle: --"
})

$btnQuit.Add_Click({
    $timer.Stop()
    $form.Close()
})

$form.Add_FormClosing({ $timer.Stop() })

# ── Go ───────────────────────────────────────────────────────────────
[System.Windows.Forms.Application]::Run($form)
