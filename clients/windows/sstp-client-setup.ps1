# Windows SSTP Client Setup Script
# This PowerShell script helps configure SSTP client on Windows

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerIP,
    
    [Parameter(Mandatory=$true)]
    [string]$Username,
    
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [string]$ConnectionName = "SSTP-VPN",
    [int]$Port = 443
)

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to create SSTP connection
function New-SSTPConnection {
    param(
        [string]$Name,
        [string]$Server,
        [int]$Port,
        [string]$User,
        [string]$Pass
    )
    
    try {
        Write-ColorOutput "Creating SSTP connection: $Name" "Green"
        
        # Create VPN connection
        Add-VpnConnection -Name $Name -ServerAddress $Server -TunnelType "Sstp" -EncryptionLevel "Required" -AuthenticationMethod "MSChapv2"
        
        # Set connection properties
        Set-VpnConnection -Name $Name -ServerAddress $Server -TunnelType "Sstp" -EncryptionLevel "Required" -AuthenticationMethod "MSChapv2"
        
        # Create credential object
        $SecurePassword = ConvertTo-SecureString $Pass -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential($User, $SecurePassword)
        
        Write-ColorOutput "SSTP connection '$Name' created successfully!" "Green"
        Write-ColorOutput "Server: $Server" "Cyan"
        Write-ColorOutput "Port: $Port" "Cyan"
        Write-ColorOutput "Username: $User" "Cyan"
        
        return $true
    }
    catch {
        Write-ColorOutput "Error creating SSTP connection: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to connect to VPN
function Connect-SSTPVPN {
    param(
        [string]$Name,
        [string]$User,
        [string]$Pass
    )
    
    try {
        Write-ColorOutput "Connecting to SSTP VPN: $Name" "Green"
        
        # Create credential object
        $SecurePassword = ConvertTo-SecureString $Pass -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential($User, $SecurePassword)
        
        # Connect to VPN
        rasdial $Name $User $Pass
        
        Write-ColorOutput "Successfully connected to SSTP VPN!" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Error connecting to SSTP VPN: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to disconnect from VPN
function Disconnect-SSTPVPN {
    param(
        [string]$Name
    )
    
    try {
        Write-ColorOutput "Disconnecting from SSTP VPN: $Name" "Yellow"
        rasdial $Name /disconnect
        Write-ColorOutput "Disconnected from SSTP VPN" "Yellow"
        return $true
    }
    catch {
        Write-ColorOutput "Error disconnecting from SSTP VPN: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to check VPN status
function Get-SSTPStatus {
    param(
        [string]$Name
    )
    
    try {
        $connections = Get-VpnConnection -Name $Name -ErrorAction SilentlyContinue
        if ($connections) {
            Write-ColorOutput "VPN Connection Status:" "Cyan"
            Write-ColorOutput "  Name: $($connections.Name)" "White"
            Write-ColorOutput "  Server: $($connections.ServerAddress)" "White"
            Write-ColorOutput "  Tunnel Type: $($connections.TunnelType)" "White"
            Write-ColorOutput "  Connection Status: $($connections.ConnectionStatus)" "White"
        } else {
            Write-ColorOutput "VPN connection '$Name' not found" "Red"
        }
    }
    catch {
        Write-ColorOutput "Error checking VPN status: $($_.Exception.Message)" "Red"
    }
}

# Main execution
Write-ColorOutput "=== Windows SSTP Client Setup ===" "Blue"
Write-ColorOutput "Server IP: $ServerIP" "Cyan"
Write-ColorOutput "Username: $Username" "Cyan"
Write-ColorOutput "Connection Name: $ConnectionName" "Cyan"
Write-ColorOutput "Port: $Port" "Cyan"
Write-ColorOutput ""

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-ColorOutput "This script requires administrator privileges. Please run as administrator." "Red"
    exit 1
}

# Create SSTP connection
$success = New-SSTPConnection -Name $ConnectionName -Server $ServerIP -Port $Port -User $Username -Pass $Password

if ($success) {
    Write-ColorOutput ""
    Write-ColorOutput "=== Connection Commands ===" "Blue"
    Write-ColorOutput "To connect:    Connect-VpnConnection -Name '$ConnectionName'" "Green"
    Write-ColorOutput "To disconnect: Disconnect-VpnConnection -Name '$ConnectionName'" "Yellow"
    Write-ColorOutput "To check status: Get-VpnConnection -Name '$ConnectionName'" "Cyan"
    Write-ColorOutput ""
    
    # Ask if user wants to connect now
    $connectNow = Read-Host "Do you want to connect now? (y/N)"
    if ($connectNow -eq "y" -or $connectNow -eq "Y") {
        Connect-SSTPVPN -Name $ConnectionName -User $Username -Pass $Password
    }
} else {
    Write-ColorOutput "Failed to create SSTP connection" "Red"
    exit 1
}

Write-ColorOutput ""
Write-ColorOutput "Setup completed!" "Green"


