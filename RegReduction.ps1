# 定义基础路径（支持运行时输入或手动修改）
param(
    [string]$basePath = (Read-Host "请输入 .reg 文件所在目录路径（例如：D:\SAM）")
)

# 定义 .reg 文件列表
$regFiles = @(
    "$basePath\sam.reg",
    "$basePath\system.reg",
    "$basePath\security.reg"
)

# 定义对应的配置单元名称
$hives = @("SAM", "SECURITY", "SYSTEM")

# 检查 .reg 文件是否存在
Write-Output "检查 .reg 文件..."
foreach ($filePath in $regFiles) {
    if (-not (Test-Path -Path $filePath)) {
        Write-Error "[-] 文件不存在: $filePath"
        exit 1
    }
    Write-Output "`t[+] 找到文件: $filePath"
}

# 将 HKLM\ 替换为 HKCU\AABYSS，以避免覆盖虚拟机的注册表配置单元
Write-Output "`n正在将 .reg 文件中的 HKLM\ 替换为 HKCU\AABYSS..."
$replacement = [char[]] "HKEY_CURRENT_USER\AABYSS" -join ''
foreach ($filePath in $regFiles) {
    $content = Get-Content -Path $filePath -Raw -Encoding Unicode
    $updatedContent = $content -replace "HKEY_LOCAL_MACHINE", $replacement
    Set-Content -Path $filePath -Value $updatedContent -Encoding Unicode
    Write-Output "`t[+] 已更新文件: $filePath"
}

# 将修改后的 .reg 文件导入到虚拟机的 HKCU\AABYSS 配置单元中
Write-Output "`n正在将修改后的 .reg 文件导入到 HKCU\AABYSS..."
foreach ($filePath in $regFiles) {
    reg import "$filePath"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "[-] 导入失败: $filePath"
        exit 1
    }
    Write-Output "`t[+] 已导入: $filePath"
}

# 使用 reg save 将配置单元保存为正确格式的 .hive 文件
Write-Output "`n正在将配置单元保存为 .hive 文件..."
for ($i = 0; $i -lt $hives.Length; $i++) {
    $hivePath = "HKEY_CURRENT_USER\AABYSS\$($hives[$i])"
    $outputPath = "$basePath\$($hives[$i]).hive"
    
    reg save $hivePath "$outputPath"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "[-] 保存失败: $hivePath -> $outputPath"
        exit 1
    }
    Write-Output "`t[+] 已保存: $outputPath"
}

# 删除临时的 HKCU\AABYSS 配置单元
Write-Output "`n正在删除临时的 HKCU\AABYSS 配置单元..."
reg delete HKEY_CURRENT_USER\AABYSS /f
if ($LASTEXITCODE -ne 0) {
    Write-Warning "[-] 删除临时配置单元失败，请手动清理"
} else {
    Write-Output "`t[+] 已清理临时配置单元"
}

Write-Output "`n========================================"
Write-Output "处理完成！生成的 .hive 文件："
foreach ($hive in $hives) {
    Write-Output "`t[+] $basePath\$hive.hive"
}
Write-Output "========================================"
