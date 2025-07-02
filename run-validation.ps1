# Run Quick Validation to ensure tests are working

Write-Host "`n🚀 Running Quick Bulletproof Validation..." -ForegroundColor Cyan
Write-Host "This will validate that our testing infrastructure is working correctly" -ForegroundColor Gray

# Run quick validation
try {
    ./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick -CI
    Write-Host "`n✅ Quick validation completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "`n❌ Validation failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ Testing infrastructure verified - ready for release!" -ForegroundColor Green