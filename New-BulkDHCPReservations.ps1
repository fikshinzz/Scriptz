# Bulk Import DHCP Reservations from CSV
$csvPath    = "./dhcp_reservations.csv"
$dhcpServer = "localhost"

if (-not (Test-Path $csvPath)) {
    Write-Error "Uh-oh CSV file not found here: $csvPath"
    exit 1
}

function ConvertTo-ClientId {
    param([string]$Mac)
    ($Mac -replace '[^0-9A-Fa-f]', '').ToUpper()
}

$reservations = Import-Csv $csvPath

foreach ($entry in $reservations) {
    try {
        if (-not $entry.ScopeId -or -not $entry.IPAddress -or -not $entry.ClientMAC -or -not $entry.ClientName) {
            Write-Warning ("Oops field missing for entry: {0}" -f ($entry | Out-String))
            continue
        }

        $ipAddress = [System.Net.IPAddress]::Parse($entry.IPAddress)
        $scopeId   = [System.Net.IPAddress]::Parse($entry.ScopeId)
        $clientId  = ConvertTo-ClientId $entry.ClientMAC

        $existingReservations = Get-DhcpServerv4Reservation -ComputerName $dhcpServer -ScopeId $scopeId -ErrorAction SilentlyContinue

        $ipExists  = $existingReservations | Where-Object { $_.IPAddress.IPAddressToString -eq $ipAddress.IPAddressToString }
        $macExists = $existingReservations | Where-Object { (ConvertTo-ClientId $_.ClientId) -eq $clientId }

        if ($ipExists) {
            Write-Warning "IP $($entry.IPAddress) already reserved in scope $($entry.ScopeId). Skipping."
            continue
        }

        if ($macExists) {
            Write-Warning "MAC $($entry.ClientMAC) already reserved in scope $($entry.ScopeId). Skipping."
            continue
        }

        $desc = ""
        if ($null -ne $entry.Description) {
            $desc = ($entry.Description -replace '[^\x20-\x7E]', '')
        }

        Add-DhcpServerv4Reservation `
            -ComputerName $dhcpServer `
            -ScopeId $scopeId `
            -IPAddress $ipAddress `
            -ClientId $clientId `
            -Name $entry.ClientName `
            -Description $desc

        Write-Host "Added: $($entry.ClientName) - $($entry.IPAddress)"
    }
    catch {
        Write-Warning ("Failed for {0} - {1}: {2}" -f $entry.ClientName, $entry.IPAddress, $_.Exception.Message)
    }
}