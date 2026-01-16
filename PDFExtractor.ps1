# Dependencies
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path

$dlls = @(
  "$basePath\BouncyCastle.Crypto.dll",
  "$basePath\itextsharp.dll"
)

foreach ($dll in $dlls) {
  if (-not (Test-Path $dll)) {
    Write-Host "❌ Missing DLL: $dll" -ForegroundColor Red
    exit 1
  }

  try {
    [Reflection.Assembly]::LoadFrom($dll) | Out-Null
    Write-Host "✅ Loaded: $([System.IO.Path]::GetFileName($dll))" -ForegroundColor Green
  } catch {
    Write-Host "❌ Failed to load $dll" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
  }
}

# File picker
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = "PDF Files (*.pdf)|*.pdf"
$dialog.Title  = "Select a SAAR to Extract"

$resultDlg = $dialog.ShowDialog()
if ($resultDlg -ne [System.Windows.Forms.DialogResult]::OK -or [string]::IsNullOrWhiteSpace($dialog.FileName)) {
  Write-Host "❌ No SAAR selected. Bye, Bye " -ForegroundColor Red
  exit 1
}

$pdfPath = $dialog.FileName
if (-not (Test-Path $pdfPath)) {
  Write-Host "❌ Couldnt find it here: $pdfPath" -ForegroundColor Red
  exit 1
}

$outputCsv = [System.IO.Path]::ChangeExtension($pdfPath, ".csv")

# Mapping 
$fieldMap = [ordered]@{
  "User ID"                = "User ID."
  "Name"                   = "Requestor Name (last, first, middle initial)."
  "Office"                 = "4. Office symbol/department."
  "Phone"                  = "5. Phone (DSN or commercial)."
  "Job Title"              = "7. Job title and grade/rank."
  "Citizenship"            = "8. Citizenship"
  "Designation"            = "9. Designation of person"
  "Access Expiration Date" = "16a. ACCESS EXPIRATION DATE"
}

$reader = $null
try {
  $reader = New-Object iTextSharp.text.pdf.PdfReader -ArgumentList $pdfPath
  $fields = $reader.AcroFields

  # dump field names for troubleshooting
    # $fields.Fields.Keys | Sort-Object | Out-File (Join-Path $basePath "pdf_field_names.txt") -Force

  $out = [ordered]@{}
  $missing = New-Object System.Collections.Generic.List[string]

  foreach ($key in $fieldMap.Keys) {
    $fieldName = $fieldMap[$key]

    # If the field doesn't exist, track it
    if (-not $fields.Fields.ContainsKey($fieldName)) {
      $missing.Add("$key -> '$fieldName'")
      $out[$key] = ""
      continue
    }

    $value = $fields.GetField($fieldName)

    # Whitespace/newlines
    $value = ($value -replace "\r\n|\r|\n", " ").Trim()

    $out[$key] = $value
  }

  $psobj = [PSCustomObject]$out

  $psobj | Export-Csv -Path $outputCsv -NoTypeInformation -Force
  Write-Host "✅ CSV saved to: $outputCsv" -ForegroundColor Cyan

  if ($missing.Count -gt 0) {
    Write-Host "⚠️ Oops check SAAR for missing fields:" -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
  }

} catch {
  Write-Host "❌ Extraction failed :( " -ForegroundColor Red
  Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
  exit 1
} finally {
  if ($reader) { $reader.Close() }
}
