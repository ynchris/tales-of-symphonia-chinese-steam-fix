param(
    [ValidateSet('Install','Uninstall')][string]$Action = 'Install',
    [switch]$NoPrompt
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($PSScriptRoot)
$originalHash = '01CAD33820C383B938452ACB60EED21262152B9F85F29BFBBCEE04D51D3A7104'
$patchedHash = '63BBED2A473EF67CED744800B2C8E6C375196D11ACD02B4642255587F3459A56'
$payload = [ordered]@{
    '3dmgame.dll' = '565EFB61F44ACA20AF65EAFD70F6AC84F88891975B9810CFF002E921E8EE8A77'
    '3dm32.dll' = 'C1442077462AA0D6F2000AA7590CF5D2116C49D7750B97142C12049537A22E04'
    '3dmtex.dll' = '3E4199FB88D55E1F56CC7B0CFA621E2C3503A7D2977A581A55ADCBBAFE280CE4'
    '3DMGAME\3dm.dds' = '3B64B53508CAA5BDCB436B491F1E2E9A19BAE6F322438B03CFCDB66A861AB29F'
    '3DMGAME\3dm.fnt' = 'CA57DD210A85FD192F816A03FD585FBE5E714C0A9DB4BA734694B922E7AA9FCC'
    '3DMGAME\3DM_TEXT.BIN' = 'F48A8E6096486A20A4310B0DED0032B89E1F807BEED5D53A5B7F75C742ED5B93'
}
function Hash([string]$path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
function AssertRegular([string]$path) {
    $item = Get-Item -LiteralPath $path -Force
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Expected a regular file: $path"
    }
}
$exe = Join-Path $root 'TOS.exe'
$backup = Join-Path $root 'TOS.exe.chs-original'
$staged = Join-Path $root 'TOS.exe.chs-staging'
$result = 0
try {
    AssertRegular $exe
    foreach ($process in @(Get-Process -Name TOS -ErrorAction SilentlyContinue)) {
        if ($process.Path -and [string]::Equals($process.Path, $exe, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Close this copy of Tales of Symphonia before installing or uninstalling.'
        }
    }
    if (-not $NoPrompt) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Action ' + $Action
            $child = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $arguments -Verb RunAs -PassThru -Wait
            exit $child.ExitCode
        }
    }
    $currentHash = Hash $exe
    if ($Action -eq 'Install') {
        if (Test-Path -LiteralPath (Join-Path $root '3DMGAME')) {
            $resourceDirectory = Get-Item -LiteralPath (Join-Path $root '3DMGAME') -Force
            if ($resourceDirectory.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Resource directory must not be a link.' }
        }
        foreach ($entry in $payload.GetEnumerator()) {
            $path = Join-Path $root $entry.Key
            AssertRegular $path
            if ((Hash $path) -ne $entry.Value) { throw "Missing or modified patch file: $($entry.Key). Extract v0.5 again." }
        }
        if ($currentHash -eq $patchedHash) {
            AssertRegular $backup
            if ((Hash $backup) -ne $originalHash) { throw 'Original backup does not match.' }
            Write-Host 'v0.5 is already installed.'
        } else {
            if ($currentHash -ne $originalHash) { throw "Unsupported or previously modified TOS.exe: $currentHash" }
            if (Test-Path -LiteralPath $backup) {
                AssertRegular $backup
                if ((Hash $backup) -ne $originalHash) { throw 'Existing backup does not match; it will not be overwritten.' }
            } else { Copy-Item -LiteralPath $exe -Destination $backup }
            if (Test-Path -LiteralPath $staged) { throw 'Staging file already exists. No executable changes made.' }
            $bytes = [IO.File]::ReadAllBytes($exe)
            $offset = 22550528
            $before = [Text.Encoding]::ASCII.GetBytes("steam_api.dll`0")
            $after = [Text.Encoding]::ASCII.GetBytes("3dmgame.dll`0`0`0")
            for ($i=0; $i -lt $before.Length; $i++) {
                if ($bytes[$offset+$i] -ne $before[$i]) { throw 'Import bytes do not match.' }
                $bytes[$offset+$i] = $after[$i]
            }
            try {
                [IO.File]::WriteAllBytes($staged, $bytes)
                if ((Hash $staged) -ne $patchedHash) { throw 'Patched executable verification failed.' }
                Copy-Item -LiteralPath $staged -Destination $exe -Force
                if ((Hash $exe) -ne $patchedHash) { throw 'Installed executable verification failed.' }
            } catch {
                Copy-Item -LiteralPath $backup -Destination $exe -Force
                throw
            } finally {
                if (Test-Path -LiteralPath $staged) { Remove-Item -LiteralPath $staged }
            }
            Write-Host 'v0.5 installed. Start the game through Steam.' -ForegroundColor Green
        }
    } else {
        AssertRegular $backup
        if ((Hash $backup) -ne $originalHash) { throw 'Backup verification failed. Restore cancelled.' }
        if ($currentHash -ne $patchedHash -and $currentHash -ne $originalHash) {
            throw 'TOS.exe has changed since installation. Restore cancelled to preserve it.'
        }
        Copy-Item -LiteralPath $backup -Destination $exe -Force
        if ((Hash $exe) -ne $originalHash) { throw 'Restored executable verification failed.' }
        Remove-Item -LiteralPath $backup
        foreach ($entry in $payload.GetEnumerator()) {
            $path = Join-Path $root $entry.Key
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                # Preserve modified files, directory links, and all saves/unknown files.
                $parent = Get-Item -LiteralPath (Split-Path -Parent $path) -Force
                $file = Get-Item -LiteralPath $path -Force
                if (($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
                if ((Hash $path) -eq $entry.Value) { Remove-Item -LiteralPath $path }
                else { Write-Host "Preserved changed file: $($entry.Key)" }
            }
        }
        Write-Host 'Original TOS.exe restored. Saves and unrelated files were preserved.' -ForegroundColor Green
    }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    $result = 1
}
if (-not $NoPrompt) { [void](Read-Host 'Press Enter to close') }
exit $result
