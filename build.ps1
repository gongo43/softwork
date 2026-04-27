<#
  Build script — compiles screen_assist.ps1 into ScreenAssist.exe
  Usage:  .\build.ps1
#>

$scriptDir = $PSScriptRoot

Invoke-ps2exe `
    -InputFile  (Join-Path $scriptDir "screen_assist.ps1") `
    -OutputFile (Join-Path $scriptDir "ScreenAssist.exe") `
    -IconFile   (Join-Path $scriptDir "screen_assist.ico") `
    -noConsole `
    -title       "Screen Assist" `
    -description "Screen Assist" `
    -noError
