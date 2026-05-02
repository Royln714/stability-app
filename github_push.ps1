# GitHub API push script - no git required
param(
  [string]$Token,
  [string]$Username,
  [string]$RepoName = "stability-test-manager"
)

$headers = @{
  Authorization = "token $Token"
  Accept        = "application/vnd.github.v3+json"
  "User-Agent"  = "stability-app-deploy"
}

$appDir = $PSScriptRoot

# ── Create repo ──────────────────────────────────────────────────────────────
Write-Host "`n[1/3] Creating GitHub repository '$RepoName'..." -ForegroundColor Cyan
$body = @{ name = $RepoName; description = "Stability Test Result Manager"; private = $false; auto_init = $false } | ConvertTo-Json
try {
  $repo = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method POST -Headers $headers -Body $body -ContentType "application/json"
  Write-Host "     Created: $($repo.html_url)" -ForegroundColor Green
} catch {
  Write-Host "     Repo already exists (or creation skipped), will update files." -ForegroundColor Yellow
}

# ── Files to upload ───────────────────────────────────────────────────────────
$include = @(
  "package.json",
  "server.js",
  ".gitignore",
  ".node-version",
  "render.yaml",
  "client\package.json",
  "client\vite.config.js",
  "client\tailwind.config.js",
  "client\postcss.config.js",
  "client\index.html",
  "client\src\main.jsx",
  "client\src\App.jsx",
  "client\src\index.css",
  "client\src\api.js",
  "client\src\pdfReport.js",
  "client\src\pages\Dashboard.jsx",
  "client\src\pages\SampleDetail.jsx",
  "client\src\pages\Formulations.jsx",
  "client\src\pages\FormulationSheet.jsx",
  "client\src\pages\LoginPage.jsx",
  "client\src\pages\ResetPasswordPage.jsx",
  "client\src\pages\AdminPanel.jsx",
  "client\src\pages\ComparisonPage.jsx",
  "client\src\components\DataEntryModal.jsx",
  "client\src\components\Charts.jsx",
  "client\src\ingredientDB.js"
)

# Also collect dist files dynamically
$distDir = Join-Path $appDir "client\dist"
if (Test-Path $distDir) {
  Get-ChildItem -Path $distDir -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($appDir.Length + 1)
    $include += $rel
  }
  Write-Host "     Added $((Get-ChildItem -Path $distDir -Recurse -File).Count) dist files" -ForegroundColor Cyan
}

Write-Host "`n[2/3] Uploading $($include.Count) files..." -ForegroundColor Cyan

function UploadFile($rel) {
  $localPath = Join-Path $appDir $rel
  $githubPath = $rel -replace "\\", "/"

  if (-not (Test-Path $localPath)) {
    Write-Host "     SKIP (not found): $rel" -ForegroundColor Yellow
    return
  }

  $content = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($localPath))

  $sha = $null
  try {
    $existing = Invoke-RestMethod -Uri "https://api.github.com/repos/$Username/$RepoName/contents/$githubPath" -Headers $headers -ErrorAction SilentlyContinue
    $sha = $existing.sha
  } catch {}

  $fileBody = @{ message = "deploy: $githubPath"; content = $content }
  if ($sha) { $fileBody.sha = $sha }

  try {
    Invoke-RestMethod -Uri "https://api.github.com/repos/$Username/$RepoName/contents/$githubPath" -Method PUT -Headers $headers -Body ($fileBody | ConvertTo-Json) -ContentType "application/json" | Out-Null
    Write-Host "     OK  $githubPath" -ForegroundColor Green
    return $true
  } catch {
    Write-Host "     ERR $githubPath : $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

$ok = 0; $fail = 0
foreach ($rel in $include) {
  $result = UploadFile $rel
  if ($result) { $ok++ } else { $fail++ }
}

Write-Host "`n[3/3] Done! $ok uploaded, $fail failed." -ForegroundColor Cyan
Write-Host "`n  GitHub repo: https://github.com/$Username/$RepoName" -ForegroundColor White
Write-Host "  Trigger a Manual Deploy on Render to apply changes." -ForegroundColor White
Write-Host ""
