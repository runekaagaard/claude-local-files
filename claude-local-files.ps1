# claude-local-files.ps1
# Windows PowerShell script to set up a local file server with SSL certificates

# Configuration
$DOMAIN = "cdn.jsdelivr.net"
$HOSTS_MARKER = "# claude-local-files"
$HOSTS_FILE = "$env:windir\System32\drivers\etc\hosts"

# Check dependencies
function Check-Dependencies {
    $missing_deps = @()
    
    if (-not (Get-Command "mkcert" -ErrorAction SilentlyContinue)) {
        $missing_deps += "mkcert"
    }
    
    if (-not (Get-Command "caddy" -ErrorAction SilentlyContinue)) {
        $missing_deps += "caddy"
    }
    
    if ($missing_deps.Count -ne 0) {
        Write-Error "Missing required dependencies: $($missing_deps -join ', ')"
        Write-Error "Please install them and try again"
        Write-Error "You can install mkcert with: winget install FiloSottile.mkcert"
        Write-Error "You can install Caddy with: winget install CaddyServer.Caddy"
        exit 1
    }
}

# Manage hosts file entry
function Setup-HostsFile {
    $hostsContent = Get-Content -Path $HOSTS_FILE -ErrorAction Stop
    
    if (-not ($hostsContent -match "$HOSTS_MARKER$")) {
        Write-Host "Adding $DOMAIN to hosts file..."
        
        # Need to run as administrator to modify hosts file
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Error "This script needs to be run as Administrator to modify the hosts file."
            exit 1
        }
        
        Add-Content -Path $HOSTS_FILE -Value "127.0.0.1 $DOMAIN $HOSTS_MARKER" -ErrorAction Stop
    }
}

function Cleanup-HostsFile {
    Write-Host "Removing $DOMAIN from hosts file..."
    
    # Top-level script should already check for admin.
    # This check is a safeguard; avoid 'exit' in cleanup functions.
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Administrator privileges are required to modify the hosts file. Cleanup might fail."
        # Allow the operation to proceed; it will fail with an access denied error from Get/Set-Content if permissions are insufficient.
    }

    $maxRetries = 5
    $retryDelaySeconds = 1
    $cleanedSuccessfully = $false

    for ($attempt = 1; $attempt -le ${maxRetries}; $attempt++) {
        try {
            $currentLines = Get-Content -Path $HOSTS_FILE -ErrorAction Stop
            
            $escapedMarker = [regex]::Escape($HOSTS_MARKER)
            $updatedLines = $currentLines | Where-Object { $_ -notmatch $escapedMarker }

            $entryExists = $currentLines | Where-Object { $_ -match $escapedMarker }
            if (-not $entryExists) {
                Write-Host "Hosts file entry for '$DOMAIN' with marker '$HOSTS_MARKER' not found or already removed."
                $cleanedSuccessfully = $true
                break 
            }
            
            if ($currentLines.Count -eq $updatedLines.Count -and $entryExists) {
                 Write-Warning "Marker '$HOSTS_MARKER' found, but line count did not change after filtering. Attempting rewrite to ensure removal."
            }

            Set-Content -Path $HOSTS_FILE -Value $updatedLines -Force -ErrorAction Stop 
            
            Write-Host "$DOMAIN was successfully removed from the hosts file."
            $cleanedSuccessfully = $true
            break 
        }
        catch [System.IO.IOException] {
            $exceptionMessage = $_.Exception.Message
            Write-Warning "Attempt $attempt/${maxRetries}: Failed to access/modify hosts file. Error: $exceptionMessage"
            if ($attempt -lt ${maxRetries}) {
                Write-Host "Retrying in $retryDelaySeconds second(s)..."
                Start-Sleep -Seconds $retryDelaySeconds
            } else {
                Write-Error "Failed to clean up hosts file after ${maxRetries} attempts. Manual cleanup might be required for the entry: '127.0.0.1 $DOMAIN $HOSTS_MARKER'"
            }
        }
        catch {
            Write-Error "An unexpected error occurred during hosts file cleanup: $($_.Exception.Message)"
            break 
        }
    }

    if (-not $cleanedSuccessfully) {
        Write-Warning "Cleanup of hosts file entry for $DOMAIN may not have completed successfully."
    }
}

# Setup certificates if needed
function Setup-Certificates {
    if (-not (Test-Path "$DOMAIN.pem") -or -not (Test-Path "$DOMAIN-key.pem")) {
        Write-Host "Setting up certificates..."
        & mkcert -install
        & mkcert $DOMAIN
    }
}

# Create Caddyfile if it doesn't exist
function Setup-Caddyfile {
    if (-not (Test-Path "Caddyfile")) {
        Write-Host "Creating Caddyfile..."
        @"
$DOMAIN {
    root * .
    file_server browse
    tls $DOMAIN.pem $DOMAIN-key.pem
}
"@ | Out-File -FilePath "Caddyfile" -Encoding utf8
    }
}

# Main function
function Main {
    Check-Dependencies
    Setup-HostsFile
    Setup-Certificates
    Setup-Caddyfile
    
    Write-Host "Starting Caddy server..."
    
    # Register cleanup function to run on exit using PowerShell's built-in trap mechanism
    trap {
        Write-Host "Script interrupted, cleaning up..."
        Cleanup-HostsFile
        exit
    }
    
    # Also handle CTRL+C with a custom handler
    $null = [Console]::TreatControlCAsInput = $true
    
    # Start Caddy in a job so we can monitor for exit
    $job = Start-Job -ScriptBlock { caddy run }
    
    Write-Host "Caddy server running. Press CTRL+C to stop and clean up."
    
    try {
        # Keep script running and watch for CTRL+C
        while ($true) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if (($key.Modifiers -band [ConsoleModifiers]::Control) -and ($key.Key -eq 'C')) {
                    Write-Host "CTRL+C detected, stopping server and cleaning up..."
                    break
                }
            }
            
            # Check if Caddy job is still running
            $jobState = $job | Get-Job | Select-Object -ExpandProperty State
            if ($jobState -ne "Running") {
                Write-Host "Caddy server stopped unexpectedly."
                break
            }
            
            Start-Sleep -Milliseconds 500
        }
    }
    finally {
        # Stop the Caddy job if it's still running
        if (($job | Get-Job).State -eq "Running") {
            Stop-Job -Job $job
            Remove-Job -Job $job -Force
        }
        
        # Clean up hosts file
        Cleanup-HostsFile
    }
}

# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script needs to be run as Administrator to modify the hosts file and run Caddy."
    Write-Host "Please restart this script with administrator privileges."
    exit 1
}

# Run the main function
Main
