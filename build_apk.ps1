# Build and rename Flutter APK script
# Usage: .\build_apk.ps1

Write-Host "📱 Building NeuroPlay-Guardian APK..." -ForegroundColor Cyan
Write-Host ""

# Build the APK
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Build successful!" -ForegroundColor Green
    
    # Default APK path
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    $newName = "NeuroPlay-Guardian.apk"
    
    if (Test-Path $apkPath) {
        # Copy to root directory with new name
        Copy-Item $apkPath $newName -Force
        Write-Host "✅ APK renamed to: $newName" -ForegroundColor Green
        
        $fileInfo = Get-Item $newName
        Write-Host ""
        Write-Host "File Details:" -ForegroundColor Cyan
        Write-Host "  Name: $($fileInfo.Name)" -ForegroundColor White
        Write-Host "  Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor White
        Write-Host "  Location: $($fileInfo.FullName)" -ForegroundColor White
    } else {
        Write-Host "⚠️  APK file not found at expected location: $apkPath" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "❌ Build failed. Please check errors above." -ForegroundColor Red
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "  1. Android SDK not configured - Set ANDROID_HOME" -ForegroundColor White
    Write-Host "  2. Android licenses not accepted - Run: flutter doctor --android-licenses" -ForegroundColor White
    Write-Host "  3. Missing dependencies - Run: flutter pub get" -ForegroundColor White
}
