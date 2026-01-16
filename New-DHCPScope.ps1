# Defaults, change CSV path to match yours
$CsvPath    = ".\scopes.csv"
$Server     = "DHCP01"
$Domain     = "scrubbed.domain"
$DnsServers = @("10.10.10.10", "10.10.10.11")
$LeaseDays  = 31

# DHCP scope check before creation
function Test-DhcpScopeExists {
  param(
    [string]$Server = $script:Server,
    [Parameter(Mandatory)][string]$ScopeId
  )
  try {
    Get-DhcpServerv4Scope -ComputerName $Server -ScopeId $ScopeId -ErrorAction Stop | Out-Null
    $true
  } catch {
    $false
  }
}

# Find CSV in path or exit
if (-not (Test-Path -Path $CsvPath)) {
  Write-Host "Uh-oh CSV not found here: $CsvPath" -ForegroundColor Red
  exit 1
}

# Import CSV
$rows = Import-Csv -Path $CsvPath
if (-not $rows) {
  Write-Host "CSV is empty: $CsvPath" -ForegroundColor Red
  exit 1
}

# Process each row & trim whitespace from values
foreach ($r in $rows) {
  $name    = ([string]$r.ScopeName).Trim()
  $scopeId = ([string]$r.ScopeId).Trim()
  $router  = ([string]$r.Router).Trim()

  try {
    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($scopeId)) {
      throw "ScopeName and ScopeId are required."
    }

    if (Test-DhcpScopeExists -Server $Server -ScopeId $scopeId) {
      Write-Host "SKIP $name ($scopeId) - already exists" -ForegroundColor Yellow
      continue
    }

    Add-DhcpServerv4Scope -ComputerName $Server -Name $name `
      -StartRange $r.StartIP -EndRange $r.EndIP -SubnetMask $r.SubnetMask `
      -Description $r.Description -ErrorAction Stop | Out-Null

    Set-DhcpServerv4OptionValue -ComputerName $Server -ScopeId $scopeId `
      -DnsDomain $Domain -DnsServer $DnsServers -ErrorAction Stop | Out-Null

    if (-not [string]::IsNullOrWhiteSpace($router)) {
      Set-DhcpServerv4OptionValue -ComputerName $Server -ScopeId $scopeId `
        -Router $router -ErrorAction Stop | Out-Null
    }

    Set-DhcpServerv4Scope -ComputerName $Server -ScopeId $scopeId `
      -LeaseDuration (New-TimeSpan -Days $LeaseDays) -State Active -ErrorAction Stop | Out-Null

    Write-Host "Created: $name ($scopeId) on $Server" -ForegroundColor Green
  }
  catch {
    Write-Host "Oops $name ($scopeId) $($_.Exception.Message)" -ForegroundColor Red
  }
}