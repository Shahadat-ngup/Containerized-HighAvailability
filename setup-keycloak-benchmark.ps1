# Keycloak Official Benchmark - Quick Setup (PowerShell)
# Download: https://github.com/keycloak/keycloak-benchmark/releases/download/0.19/keycloak-benchmark-0.19.zip

$KEYCLOAK_URL = "https://keycloak.ipb.pt"
$REALM = "master"
$VERSION = "0.7"

Write-Host "=========================================" -ForegroundColor Green
Write-Host "Keycloak Official Benchmark Setup" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Download
$url = "https://github.com/keycloak/keycloak-benchmark/releases/download/$VERSION/kcb-$VERSION.zip"
$output = "kcb-$VERSION.zip"

Write-Host "Downloading from GitHub..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $url -OutFile $output

# Extract
Write-Host "Extracting..." -ForegroundColor Yellow
Expand-Archive -Path $output -DestinationPath . -Force

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Quick Start Commands:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Run default benchmark (ClientSecret scenario):" -ForegroundColor White
Write-Host "   cd kcb-$VERSION"
Write-Host "   .\bin\kcb.bat --server-url=$KEYCLOAK_URL --realm-name=$REALM"
Write-Host ""
Write-Host "2. Run Authorization Code scenario (user login):" -ForegroundColor White
Write-Host "   .\bin\kcb.bat --scenario=keycloak.scenario.authentication.AuthorizationCode --server-url=$KEYCLOAK_URL --realm-name=$REALM --users-per-second=10 --measurement-time=60"
Write-Host ""
Write-Host "3. Results will be in: kcb-$VERSION\results\" -ForegroundColor White
