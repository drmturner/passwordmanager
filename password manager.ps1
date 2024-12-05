<#

Future ideas for improvements:
1. Add a check with Azure to ensure that only members of the department using the program can run it. Connect to Azure, check if user is member of the correct group, and either continue if yes or exit if no.
2. I would recommend using full network paths instead of the Drive letter for the $baseDirectory unless W will always be mapped to the Infosec Office folder.

To compile to an exe file:
1. Open and run ps2exe.ps1 in PowerShell ISE.
2. Switch back to the password manager.ps1 file window.
3. Ensure that the icon.ico file is in the same directory.
4. Run this command: Invoke-ps2exe -inputFile "password manager.ps1" -outputfile "CyberPassMan.exe" -noConsole -title "Cyber Office Password Manager" -company "City of Virginia Beach" -copyright "2024" -version "3.0" -description "A secure password manager that encrypts credentials, validates access via Azure group membership, and supports multi-user collaboration through a shared network environment." -Verbose -iconFile "icon.ico"
5. CyberPassMan.exe will be created. It can be run from anywhere since the file paths in the program are hard-coded in.

CAVEAT: This script will need to be updated if the $BaseDirectory path becomes invalid.

#>

# Add Assembly Types
Add-Type -AssemblyName PresentationFramework, WindowsBase

# Set to single-threading execution
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "Switching to STA mode..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-STA", "-File `"$PSCommandPath`"" -NoNewWindow -Wait
    exit
}

# Set Execution Policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

<#
# Check AzureAD module
if (-not (Get-Module -ListAvailable -Name AzureAD)) {
    try {
        Install-Module AzureAD -Force -Scope CurrentUser -ErrorAction Stop
    } catch {
        Write-Error "Failed to install AzureAD module. Please install it manually."
        exit
    }
}

Import-Module AzureAD

# Connect to AzureAD
try {
    Connect-AzureAD -ErrorAction Stop
} catch {
    Write-Error "Failed to connect to AzureAD."
    exit
}

# Get current user's UPN
$currentUserUPN = (Get-AzureADContext).Account

$GroupName = "YourGroupName" # Replace with the actual group name

# Get the group
$group = Get-AzureADGroup -Filter "DisplayName eq '$GroupName'"

if (-not $group) {
    Write-Error "Group '$GroupName' not found."
    exit
}

# Get group members
$members = Get-AzureADGroupMember -ObjectId $group.ObjectId -All $true

# Get member UPNs
$memberUPNs = $members | Select-Object -ExpandProperty UserPrincipalName

if ($memberUPNs -contains $currentUserUPN) {
    Write-Host "User is a member of the group. Proceeding..."
} else {
    Write-Host "You are not a member of the required group. Exiting..."
    exit
}
#>

# Define paths
$BaseDirectory = "$env:USERPROFILE\Desktop"
$CredentialStorePath = Join-Path $BaseDirectory "Credentials"
$KeyFilePath = Join-Path $BaseDirectory "encryptionKey.key"

# Ensure the Credentials folder exists
if (-not (Test-Path -Path $CredentialStorePath)) {
    New-Item -ItemType Directory -Path $CredentialStorePath | Out-Null }

# Function to get or create the encryption key 
function Get-EncryptionKey {
    if (-not (Test-Path -Path $KeyFilePath)) {
        # Generate a 16-byte encryption key
        $key = (1..16 | ForEach-Object { [byte](Get-Random -Minimum 0 -Maximum 256) })
        [System.IO.File]::WriteAllBytes($KeyFilePath, $key)
    } else {
        # Load the existing key as a byte array
        $key = [System.IO.File]::ReadAllBytes($KeyFilePath)
    }
    return $key
}

# Load the encryption key
$EncryptionKey = Get-EncryptionKey

# Credential class
class CredentialItem {
    [string] $Solution
    [string] $Service # Renamed to 'Use' in the GUI
    [string] $Username
    [string] $Password
    [string] $Notes # New property for Custom Notes
    [string] $Identifier

    CredentialItem([string] $Solution, [string] $Service, [string] $Username, [string] $Password, [string] $Notes, [string] $Identifier) {
        $this.Solution = $Solution
        $this.Service = $Service
        $this.Username = $Username
        $this.Password = $Password
        $this.Notes = $Notes
        $this.Identifier = $Identifier
    }
}

# Load credentials from JSON files
function Load-Credentials {
    $global:CredentialsData = @{}

    Get-ChildItem -Path $CredentialStorePath -Filter "*.json" | ForEach-Object {
        $credential = Get-Content -Path $_.FullName | ConvertFrom-Json
        # Decrypt password for display
        $encryptedPassword = $credential.Password
        $securePassword = ConvertTo-SecureString -String $encryptedPassword -Key $EncryptionKey
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
        $maskedPassword = "**************"
        $item = [PSCUSTOMObject]@{
            Solution = $credential.Solution
            Service = $credential.Service
            Username = $credential.Username
            Password = $maskedPassword # Masked password
            Notes = $credential.Notes
            Identifier = $_.BaseName
            PlainPassword = $plainPassword # Store for sorting if needed
        }
        $global:CredentialsData[$item.Identifier] = $item
    }
}

# Refresh ListView
function Refresh-CredentialsList {
    $CredentialsListView.ItemsSource = $global:CredentialsData.Values }

# Add credential
function Add-Credential {
    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Add Credential" Height="400" Width="400" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel Orientation="Vertical" Grid.Row="0" HorizontalAlignment="Left" Margin="0,0,0,10">
            <TextBlock Text="Solution:"/>
            <TextBox x:Name="SolutionBox" Width="300" Margin="0,10,0,10"/>
            <TextBlock Text="Use:"/>
            <TextBox x:Name="UseBox" Width="300" Margin="0,10,0,10"/>
            <TextBlock Text="Username:"/>
            <TextBox x:Name="UsernameBox" Width="300" Margin="0,10,0,10"/>
            <TextBlock Text="Password:"/>
            <PasswordBox x:Name="PasswordBox" Width="300" Margin="0,10,0,10"/>
            <TextBlock Text="Custom Notes:"/>
            <TextBox x:Name="NotesBox" Width="300" Margin="0,10,0,10"/>
        </StackPanel>
        <StackPanel Grid.Row="1" Orientation="Horizontal" VerticalAlignment="Bottom" HorizontalAlignment="Right">
            <Button x:Name="SaveButton" Content="Save" Width="80" Margin="5"/>
            <Button x:Name="CancelButton" Content="Cancel" Width="80" Margin="5"/>
        </StackPanel>
    </Grid>
</Window>
'@

    $window = [Windows.Markup.XamlReader]::Parse($xaml)
    $window.Add_KeyDown({
       param($sender, $e)
       # Check if Enter is pressed
       if ($e.Key -eq [System.Windows.Input.Key]::Return) {
           # Define the default action button (e.g., $OkButton or $SearchButton)
           $DefaultButton = $SaveButton
           # Simulate clicking the default button
           $DefaultButton.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
       }
    })
    $SolutionBox = $window.FindName("SolutionBox")
    $UseBox = $window.FindName("UseBox")
    $UsernameBox = $window.FindName("UsernameBox")
    $PasswordBox = $window.FindName("PasswordBox")
    $NotesBox = $window.FindName("NotesBox")
    $SaveButton = $window.FindName("SaveButton")
    $CancelButton = $window.FindName("CancelButton")

    $SaveButton.Add_Click({
        $solution = $SolutionBox.Text
        $use = $UseBox.Text
        $username = $UsernameBox.Text
        $password = $PasswordBox.Password
        $notes = $NotesBox.Text

        if ([string]::IsNullOrWhiteSpace($solution) -or [string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($password) -or [string]::IsNullOrWhiteSpace($use)) {
            [System.Windows.MessageBox]::Show("Solution, Use, Username, and Password cannot be empty.", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }

        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $encryptedPassword = ConvertFrom-SecureString -SecureString $securePassword -Key $EncryptionKey
        $identifier = [guid]::NewGuid().ToString()

        $credential = @{
            Solution = $solution
            Service = $use
            Username = $username
            Password = $encryptedPassword
            Notes = $notes
            Identifier = $identifier
        }

        $filePath = Join-Path $CredentialStorePath "$identifier.json"
        $credential | ConvertTo-Json -Depth 2 | Out-File -FilePath $filePath -Force

        Load-Credentials
        Refresh-CredentialsList
        [System.Windows.MessageBox]::Show("Credential added successfully.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        $window.Close()
    })

    $CancelButton.Add_Click({
        $window.Close()
    })

    $window.ShowDialog() | Out-Null
}

# Update credential
function Update-Credential {
    $selectedItem = $CredentialsListView.SelectedItem
    if (-not $selectedItem) {
        [System.Windows.MessageBox]::Show("Please select a credential to update.", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }

    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Update Credential" Height="400" Width="400" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel Orientation="Vertical" Grid.Row="0" HorizontalAlignment="Left" Margin="0,0,0,10">
            <TextBlock Text="Solution:"/>
            <TextBox x:Name="SolutionBox" Width="300" Margin="0,10,0,10"/>
            <TextBlock Text="Use:"/>
            <TextBox x:Name="UseBox" Width="300" Margin="0,10,0,10"/>
            <TextBlock Text="Username:"/>
            <TextBox x:Name="UsernameBox" Width="300" Margin="0,10,0,10"/>
            <TextBlock Text="Password:"/>
            <PasswordBox x:Name="PasswordBox" Width="300" Margin="0,10,0,10"/>
            <TextBlock Text="Custom Notes:"/>
            <TextBox x:Name="NotesBox" Width="300" Margin="0,10,0,10"/>
        </StackPanel>
        <StackPanel Grid.Row="1" Orientation="Horizontal" VerticalAlignment="Bottom" HorizontalAlignment="Right">
            <Button x:Name="SaveButton" Content="Save" Width="80" Margin="5"/>
            <Button x:Name="CancelButton" Content="Cancel" Width="80" Margin="5"/>
        </StackPanel>
    </Grid>
</Window>
'@

    $window = [Windows.Markup.XamlReader]::Parse($xaml)
    $window.Add_KeyDown({
       param($sender, $e)
       # Check if Enter is pressed
       if ($e.Key -eq [System.Windows.Input.Key]::Return) {
           # Define the default action button (e.g., $OkButton or $SearchButton)
           $DefaultButton = $SaveButton
           # Simulate clicking the default button
           $DefaultButton.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
       }
    })
    $SolutionBox = $window.FindName("SolutionBox")
    $UseBox = $window.FindName("UseBox")
    $UsernameBox = $window.FindName("UsernameBox")
    $PasswordBox = $window.FindName("PasswordBox")
    $NotesBox = $window.FindName("NotesBox")
    $SaveButton = $window.FindName("SaveButton")
    $CancelButton = $window.FindName("CancelButton")

    $SolutionBox.Text = $selectedItem.Solution
    $UseBox.Text = $selectedItem.Service
    $UsernameBox.Text = $selectedItem.Username
    $PasswordBox.Password = $selectedItem.Password
    $NotesBox.Text = $selectedItem.Notes

    $SaveButton.Add_Click({
        $solution = $SolutionBox.Text
        $use = $UseBox.Text
        $username = $UsernameBox.Text
        $password = $PasswordBox.Password
        $notes = $NotesBox.Text

        if ([string]::IsNullOrWhiteSpace($solution) -or [string]::IsNullOrWhiteSpace($username)) {
            [System.Windows.MessageBox]::Show("Solution and Username cannot be empty.", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }

        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $encryptedPassword = ConvertFrom-SecureString -SecureString $securePassword -Key $EncryptionKey
        $selectedItem.Solution = $solution
        $selectedItem.Service = $use
        $selectedItem.Username = $username
        $selectedItem.Password = $encryptedPassword
        $selectedItem.Notes = $notes

        $filePath = Join-Path $CredentialStorePath "$($selectedItem.Identifier).json"
        $selectedItem | ConvertTo-Json -Depth 2 | Out-File -FilePath $filePath -Force

        Load-Credentials
        Refresh-CredentialsList
        [System.Windows.MessageBox]::Show("Credential updated successfully.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        $window.Close()
    })

    $CancelButton.Add_Click({
        $window.Close()
    })

    $window.ShowDialog() | Out-Null
}

# Delete selected credential
function Delete-SelectedCredential {
    $selectedItem = $CredentialsListView.SelectedItem
    if (-not $selectedItem) {
        [System.Windows.MessageBox]::Show("Please select a credential to delete.", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }

    $filePath = Join-Path $CredentialStorePath "$($selectedItem.Identifier).json"
    if (Test-Path -Path $filePath) {
        Remove-Item -Path $filePath -Force
    }

    $global:CredentialsData.Remove($selectedItem.Identifier)
    Load-Credentials
    Refresh-CredentialsList
    [System.Windows.MessageBox]::Show("Credential deleted successfully.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

# View credential password
function View-CredentialPassword {
   $selectedItem = $CredentialsListView.SelectedItem
   if ($null -eq $selectedItem) {
       [System.Windows.MessageBox]::Show("Please select a credential to view its password.", "Error", "OK", "Error")
       return
   }
   # Retrieve the full password from the JSON file
   $filePath = Join-Path $CredentialStorePath "$($selectedItem.Identifier).json"
   if (-not (Test-Path $filePath)) {
       [System.Windows.MessageBox]::Show("Credential file not found.", "Error", "OK", "Error")
       return
   }
   $credential = Get-Content -Path $filePath | ConvertFrom-Json
   $encryptedPassword = $credential.Password
   $decryptionKey = [System.IO.File]::ReadAllBytes($KeyFilePath)
   $securePassword = ConvertTo-SecureString -String $encryptedPassword -Key $decryptionKey
   $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
   # Show the password in a popup
   [System.Windows.MessageBox]::Show("Password: $plainPassword", "Decrypted Password", "OK", "Information")
}

# Search functionality
function Search-Credentials {
    param ([string]$SearchText)
    # Filter credentials based on the search text
    $filteredData = $global:CredentialsData.Values | Where-Object {
        $_.Solution -like "*$SearchText*" -or
        $_.Service -like "*$SearchText*" -or
        $_.Username -like "*$SearchText*" -or
        $_.Notes -like "*$SearchText*"
    }
    # Ensure filtered data is a collection, even if only one item is found
    if ($filteredData -isnot [System.Collections.IEnumerable]) {
        $filteredData = @($filteredData)
    }
    # Update the ListView with the filtered results
    $CredentialsListView.ItemsSource = $filteredData }

# Clear search
function Clear-Search {
    Load-Credentials
    Refresh-CredentialsList
    $SearchTextBox.Text = ""
    # Clear sort indicators
    $SolutionIndicator.Text = ""
    $UseIndicator.Text = ""
    $UsernameIndicator.Text = ""
    # Reset sort states
    $global:SortStates = @{
        'Solution' = $true
        'Service' = $true
        'Username' = $true
    }
}

# Sorting functionality
function Sort-Credentials {
    param ([string]$SortBy, [bool]$Ascending = $true)
    $currentData = $CredentialsListView.ItemsSource
    $sortedData = if ($Ascending) {
        $currentData | Sort-Object -Property $SortBy
    } else {
        $currentData | Sort-Object -Property $SortBy -Descending
    }
    $CredentialsListView.ItemsSource = $sortedData }

# Toggle sort
function Toggle-Sort {
    param([string]$SortBy)
    # Initialize sort states if not already done
    if (-not $global:SortStates) {
        $global:SortStates = @{
            'Solution' = $true
            'Service' = $true
            'Username' = $true
        }
    }
    # Flip the sort state
    $global:SortStates[$SortBy] = -not $global:SortStates[$SortBy]
    $ascending = $global:SortStates[$SortBy]
    # Update the sort indicators
    Update-SortIndicators $SortBy $ascending
    # Sort the data
    Sort-Credentials -SortBy $SortBy -Ascending $ascending }

# Update sort indicators
function Update-SortIndicators {
   param([string]$SortBy, [bool]$Ascending)
   # Clear all indicators
   $SolutionIndicator.Text = ""
   $UseIndicator.Text = ""
   $UsernameIndicator.Text = ""
   switch ($SortBy) {
       'Solution' {
           if ($Ascending) {
               $SolutionIndicator.Text = "⇓"
           } else {
               $SolutionIndicator.Text = "⇑"
           }
       }
       'Service' {
           if ($Ascending) {
               $UseIndicator.Text = "⇓"
           } else {
               $UseIndicator.Text = "⇑"
           }
       }
       'Username' {
           if ($Ascending) {
               $UsernameIndicator.Text = "⇓"
           } else {
               $UsernameIndicator.Text = "⇑"
           }
       }
   }
}

# Initialize GUI
function Initialize-GUI {
    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       Title="Password Manager" Height="550" Width="850" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <StackPanel Orientation="Horizontal" Grid.Row="0" HorizontalAlignment="Center" Height="30" Margin="0,0,0,20">
            <Button x:Name="AddPasswordButton" Content="Add Credential" Width="120" Margin="5"/>
            <Button x:Name="UpdatePasswordButton" Content="Update Credential" Width="120" Margin="5"/>
            <Button x:Name="DeletePasswordButton" Content="Delete Selected" Width="120" Margin="5"/>
            <Button x:Name="ViewPasswordButton" Content="View Password" Width="120" Margin="5"/>
        </StackPanel>

        <StackPanel Orientation="Horizontal" Grid.Row="1" HorizontalAlignment="Left" Height="30" Margin="0,0,0,0">
            <TextBlock Text="Search:" Margin="0,0,5,0"/>
            <TextBox x:Name="SearchTextBox" Width="200" Margin="0,0,10,0"/>
            <Button x:Name="SearchButton" Content="Search" Width="80" Margin="0,0,10,0"/>
            <Button x:Name="ClearSearchButton" Content="Clear" Width="80" Margin="0,0,10,0"/>
        </StackPanel>

        <Grid Grid.Row="2">
            <ListView x:Name="CredentialsListView" SelectionMode="Single">
                <ListView.View>
                    <GridView>
                        <GridViewColumn Width="150">
                            <GridViewColumn.Header>
                                <GridViewColumnHeader x:Name="SolutionHeader" HorizontalContentAlignment="Stretch">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto "/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="Solution" Grid.Column="0" HorizontalAlignment="Center"/>
                                        <TextBlock x:Name="SolutionIndicator" Text="" Grid.Column="1" HorizontalAlignment="Right" Margin="0,0,5,0"/>
                                    </Grid>
                                </GridViewColumnHeader>
                            </GridViewColumn.Header>
                            <GridViewColumn.DisplayMemberBinding>
                                <Binding Path="Solution" />
                            </GridViewColumn.DisplayMemberBinding>
                        </GridViewColumn>

                        <GridViewColumn Width="150">
                            <GridViewColumn.Header>
                                <GridViewColumnHeader x:Name="UseHeader" HorizontalContentAlignment="Stretch">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="Use" Grid.Column="0" HorizontalAlignment="Center"/>
                                        <TextBlock x:Name="UseIndicator" Text="" Grid.Column="1" HorizontalAlignment="Right"/>
                                    </Grid>
                                </GridViewColumnHeader>
                            </GridViewColumn.Header>
                            <GridViewColumn.DisplayMemberBinding>
                                <Binding Path="Service" />
                            </GridViewColumn.DisplayMemberBinding>
                        </GridViewColumn>

                        <GridViewColumn Width="150">
                            <GridViewColumn.Header>
                                <GridViewColumnHeader x:Name="UsernameHeader" HorizontalContentAlignment="Stretch">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="Username" Grid.Column="0" HorizontalAlignment="Center"/>
                                        <TextBlock x:Name="UsernameIndicator" Text="" Grid.Column="1" HorizontalAlignment="Right"/>
                                    </Grid>
                                </GridViewColumnHeader>
                            </GridViewColumn.Header>
                            <GridViewColumn.DisplayMemberBinding>
                                <Binding Path="Username" />
                            </GridViewColumn.DisplayMemberBinding>
                        </GridViewColumn>

                        <GridViewColumn Header="Password" DisplayMemberBinding="{Binding Password}" Width="150"/>
                        <GridViewColumn Header="Custom Notes" DisplayMemberBinding="{Binding Notes}" Width="200"/>
                    </GridView>
                </ListView.View>
            </ListView>
        </Grid>

    </Grid>
</Window>
'@

    $window = [Windows.Markup.XamlReader]::Parse($xaml)
    $SearchTextBox = $window.FindName("SearchTextBox")
    $SearchButton = $window.FindName("SearchButton")
    $SearchTextBox.Add_KeyDown({
        param($sender, $e)
        # Check if the Enter key is pressed
        if ($e.Key -eq [System.Windows.Input.Key]::Return) {
            # Simulate clicking the Search button
            $SearchButton.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        }
    })
    $ClearSearchButton = $window.FindName("ClearSearchButton")
    $CredentialsListView = $window.FindName("CredentialsListView")
    $AddPasswordButton = $window.FindName("AddPasswordButton")
    $UpdatePasswordButton = $window.FindName("UpdatePasswordButton")
    $DeletePasswordButton = $window.FindName("DeletePasswordButton")
    $ViewPasswordButton = $window.FindName("ViewPasswordButton")

    $SolutionHeader = $window.FindName("SolutionHeader")
    $UseHeader = $window.FindName("UseHeader")
    $UsernameHeader = $window.FindName("UsernameHeader")
    $SolutionIndicator = $window.FindName("SolutionIndicator")
    $UseIndicator = $window.FindName("UseIndicator")
    $UsernameIndicator = $window.FindName("UsernameIndicator")

    $SearchButton.Add_Click({ Search-Credentials -SearchText $SearchTextBox.Text })
    $ClearSearchButton.Add_Click({ Clear-Search })
    $AddPasswordButton.Add_Click({ Add-Credential })
    $UpdatePasswordButton.Add_Click({ Update-Credential })
    $DeletePasswordButton.Add_Click({ Delete-SelectedCredential })
    $ViewPasswordButton.Add_Click({ View-CredentialPassword })

    $SolutionHeader.Add_Click({ Toggle-Sort 'Solution' })
    $UseHeader.Add_Click({ Toggle-Sort 'Service' })
    $UsernameHeader.Add_Click({ Toggle-Sort 'Username' })

    Load-Credentials
    Refresh-CredentialsList
    $window.ShowDialog() | Out-Null
}

Load-Credentials
Initialize-GUI
