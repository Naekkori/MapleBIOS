# 0. NASM 이 있는지 확인 없으면 Winget 으로 설치
if (Get-Command "nasm" -ErrorAction SilentlyContinue) {
    Write-Host "✅ already install nasm" -ForegroundColor Green
    nasm -v
    exit
}else{
    Write-Host "ℹ️ can't find nasm, installing" -ForegroundColor Yellow
    winget install nasm
}
# 1. NASM 설치 경로 설정
$nasmPath = "$env:USERPROFILE\AppData\Local\bin\NASM"

# 2. 경로가 실제로 존재하는지 확인
if (Test-Path $nasmPath) {
    # 현재 세션(현재 열린 창)에 즉시 적용
    $env:Path += ";$nasmPath"
    
    # 영구적 환경 변수(User Path) 가져오기
    $oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
    
    # 중복 등록 방지 체크 후 등록
    if ($oldPath -notlike "*$nasmPath*") {
        $newPath = "$oldPath;$nasmPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "✅ nasm apply enviroment variable" -ForegroundColor Green
        Write-Host "📍 path: $nasmPath" -ForegroundColor Cyan
    } else {
        Write-Host "ℹ️ already apply enviroment variable" -ForegroundColor Yellow
    }
    
    Write-Host "⚠️ please restart vscode" -ForegroundColor White -BackgroundColor DarkRed
} else {
    Write-Host "❌ can't find path: $nasmPath" -ForegroundColor Red
}

# 3. 버전 확인 테스트
nasm -v