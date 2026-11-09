. "$PSScriptRoot\_paths.ps1"
﻿$d = $ZL2Repo
Write-Output "=== 文档内部链接检查 ==="
$docs = Get-ChildItem "$d\docs" -Filter '*.md'
$root = Get-ChildItem $d -Filter '*.md'
$all = @($docs) + @($root)
$broken = 0
$checked = 0

foreach ($f in $all) {
    $raw = Get-Content $f.FullName -Raw -Encoding UTF8
    # 先剥掉代码块（``` ... ```），代码里的 [xxx](yyy) 不是链接
    $text = [regex]::Replace($raw, '(?s)```.*?```', '')
    # 再剥掉行内代码（`xxx`）
    $text = [regex]::Replace($text, '`[^`]*`', '')
    # 匹配 markdown 链接 [文本](路径)  排除 http 开头和锚点
    $matches2 = [regex]::Matches($text, '\[([^\]]+)\]\(([^)]+)\)')
    foreach ($m in $matches2) {
        $target = $m.Groups[2].Value
        if ($target -match '^https?://' -or $target -match '^#') { continue }
        # 去掉锚点
        $path = ($target -split '#')[0]
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        $checked++

        # 解析相对路径
        $base = Split-Path $f.FullName -Parent
        $full = Join-Path $base $path
        $full = $full -replace '/', '\'
        if (-not (Test-Path $full)) {
            # 也试试从项目根解析
            $full2 = Join-Path $d $path
            $full2 = $full2 -replace '/', '\'
            if (-not (Test-Path $full2)) {
                Write-Output ("  死链 " + $f.Name + " -> " + $target)
                $broken++
            }
        }
    }
}

Write-Output ""
Write-Output ("检查 " + $checked + " 个内部链接，死链 " + $broken + " 个")
