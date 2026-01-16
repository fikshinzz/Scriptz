# Password gen
function Get-RandomPassword {
    param(
        [int]$Length = 16
    )

    # Character sets using ASCII ranges
    $upper   = [char[]](65..90)    # A-Z
    $lower   = [char[]](97..122)   # a-z
    $numbers = [char[]](48..57)    # 0-9
    $symbols = @('!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '-', '_', '+', '=')

    # Combine characters into a single pool
    $allChars = $upper + $lower + $numbers + $symbols

    # Build password
    $password = -join ((1..$Length) | ForEach-Object { $allChars | Get-Random })
    
    return $password
}

# Gen & display
$password = Get-RandomPassword -Length 20
Write-Host "Generated Password: " -NoNewline
Write-Host $password -ForegroundColor Cyan
