# 1. NASM 설치 경로 설정 (Winget 기본 설치 경로 확인)
$nasmPath = "$env:USERPROFILE\AppData\Local\bin\NASM"
if (-not (Test-Path $nasmPath)) {
    # 다른 일반적인 설치 경로 확인 (예: Program Files)
    $alternativePath = "${env:ProgramFiles}\NASM"
    if (Test-Path $alternativePath) { $nasmPath = $alternativePath }
}

# 0. NASM 이 있는지 확인 없으면 Winget 으로 설치
if (-not (Get-Command "nasm" -ErrorAction SilentlyContinue)) {
    Write-Host "ℹ️ can't find nasm, installing" -ForegroundColor Yellow
    winget install nasm --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "✅ nasm is accessible" -ForegroundColor Green
}

# 2. 경로가 실제로 존재하는지 확인
if (Test-Path $nasmPath) {
    # 영구적 환경 변수(User Path) 가져오기
    $oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
    
    # 중복 등록 방지 체크 후 등록
    if ($oldPath -split ';' -notcontains $nasmPath) {
        $newPath = $oldPath.TrimEnd(';') + ";$nasmPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path += ";$nasmPath" # 현재 세션에도 즉시 적용
        Write-Host "✅ nasm apply enviroment variable" -ForegroundColor Green
        Write-Host "📍 path: $nasmPath" -ForegroundColor Cyan
        Write-Host "⚠️ please restart vscode or terminal to apply changes permanently" -ForegroundColor White -BackgroundColor DarkRed
    } else {
        Write-Host "ℹ️ already apply enviroment variable" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ can't find path: $nasmPath" -ForegroundColor Red
}

# 3. 버전 확인 테스트
nasm -v