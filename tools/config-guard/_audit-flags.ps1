. "$PSScriptRoot\_paths.ps1"
$d = $ZL2Repo
$files = Get-ChildItem "$d\src" -Filter '*.swift'

Write-Output "=== 标志-监听配对检查 ==="
Write-Output ""

$issues = @()

foreach ($f in $files) {
    $text = Get-Content $f.FullName -Raw -Encoding UTF8
    # 找所有 @State ... var showXxx / isXxx / presentXxx = false
    $stateVars = [regex]::Matches($text, '@State(?:\([^)]*\))?\s+private\s+var\s+([A-Za-z_][A-Za-z0-9_]*)\s*[:=]') |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

    foreach ($v in $stateVars) {
        # 只关心看起来像「弹层开关」的
        if ($v -notmatch '^(show|is[A-Z]|present|alert|confirm)') { continue }

        # 赋值点：`v = true` 或 `v.toggle()`
        $assign = ([regex]::Matches($text, ('(?<![A-Za-z0-9_.])' + [regex]::Escape($v) + '\s*=\s*(true|!false)'))).Count +
                  ([regex]::Matches($text, ('(?<![A-Za-z0-9_.])' + [regex]::Escape($v) + '\.toggle\(\)'))).Count

        if ($assign -eq 0) { continue }   # 从没置 true，不算问题

        # 监听点：.sheet(isPresented: $v) / .alert(isPresented: $v) / .fullScreenCover / .confirmationDialog / .popover
        $listen = ([regex]::Matches($text, ('\.(sheet|alert|fullScreenCover|confirmationDialog|popover)\s*\(\s*isPresented:\s*\$' + [regex]::Escape($v)))).Count +
                  ([regex]::Matches($text, ('\.overlay[^\(]*\([^)]*' + [regex]::Escape($v)))).Count

        if ($listen -eq 0) {
            $issues += ("{0,-46} {1,-26} 赋值{2}次 监听0次" -f $f.Name, $v, $assign)
        }
    }
}

if ($issues.Count -eq 0) {
    Write-Output "  没有发现「设了标志但没人监听」的情况"
} else {
    Write-Output ("  发现 " + $issues.Count + " 处：")
    $issues | ForEach-Object { Write-Output ("    " + $_) }
}
