
# Tolis Achievement Creator - Step 2
# Windows PowerShell 5.1 / Windows Forms

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:DataDir = Join-Path $script:Root "Data"
$script:DataFile = Join-Path $script:DataDir "Games.json"
$script:Games = @()


function Save-Games {
    try {
        if (!(Test-Path $script:DataDir)) {
            New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null
        }

        $cleanGames = @(
            foreach ($game in $script:Games) {
                if ($null -ne $game -and $game.Name) {
                    [pscustomobject]@{
                        Id = [string]$game.Id
                        Name = [string]$game.Name
                        ExePath = [string]$game.ExePath
                        TotalSeconds = [long]$game.TotalSeconds
                        LastPlayed = [string]$game.LastPlayed
                        Achievements = @($game.Achievements)
                    }
                }
            }
        )

        $json = ConvertTo-Json -InputObject $cleanGames -Depth 8
        [System.IO.File]::WriteAllText(
            $script:DataFile,
            $json,
            (New-Object System.Text.UTF8Encoding($false))
        )

        $statusLabel.Text = "Saved successfully."
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not save the game list:`r`n$($_.Exception.Message)",
            "Save error"
        ) | Out-Null
    }
}



function Load-Games {
    try {
        if (!(Test-Path $script:DataDir)) {
            New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null
        }

        if (Test-Path $script:DataFile) {
            $rawJson = Get-Content -LiteralPath $script:DataFile -Raw

            if (![string]::IsNullOrWhiteSpace($rawJson)) {
                $loaded = ConvertFrom-Json -InputObject $rawJson -ErrorAction Stop

                # Keep only valid game records from the saved file.
                $script:Games = @(
                    foreach ($game in @($loaded)) {
                        if ($null -ne $game -and
                            $game.Name -and
                            $game.Id -and
                            $game.PSObject.Properties["Name"] -and
                            $game.PSObject.Properties["Id"]) {

                            [pscustomobject]@{
                                Id           = [string]$game.Id
                                Name         = [string]$game.Name
                                ExePath      = [string]$game.ExePath
                                TotalSeconds = [long]$game.TotalSeconds
                                LastPlayed   = [string]$game.LastPlayed
                                Achievements = @($game.Achievements)
                            }
                        }
                    }
                )
            }
            else {
                $script:Games = @()
            }
        }
        else {
            $script:Games = @()
        }

        # If no valid records remain, start with the three default games.
        if (@($script:Games).Count -eq 0) {
            $script:Games = @(
                [pscustomobject]@{
                    Id = [guid]::NewGuid().ToString()
                    Name = "Lineage II"
                    ExePath = ""
                    TotalSeconds = 0
                    LastPlayed = ""
                    Achievements = @()
                }
                [pscustomobject]@{
                    Id = [guid]::NewGuid().ToString()
                    Name = "Dragon Ball Online"
                    ExePath = ""
                    TotalSeconds = 0
                    LastPlayed = ""
                    Achievements = @()
                }
                [pscustomobject]@{
                    Id = [guid]::NewGuid().ToString()
                    Name = "Yu-Gi-Oh! PRO"
                    ExePath = ""
                    TotalSeconds = 0
                    LastPlayed = ""
                    Achievements = @()
                }
            )
            Save-Games
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not load the game list:`r`n$($_.Exception.Message)",
            "Load error"
        ) | Out-Null

        $script:Games = @()
    }
}


function Refresh-Games {
    $oldIndex = $gamesList.SelectedIndex
    $gamesList.Items.Clear()

    foreach ($game in $script:Games) {
        [void]$gamesList.Items.Add([string]$game.Name)
    }

    if ($gamesList.Items.Count -gt 0) {
        if ($oldIndex -lt 0) { $oldIndex = 0 }
        if ($oldIndex -ge $gamesList.Items.Count) {
            $oldIndex = $gamesList.Items.Count - 1
        }
        $gamesList.SelectedIndex = $oldIndex
    }
    else {
        Refresh-Details
    }
}

function Get-SelectedGame {
    $index = $gamesList.SelectedIndex

    if ($index -ge 0 -and $index -lt $script:Games.Count) {
        return $script:Games[$index]
    }

    return $null
}

function Refresh-Details {
    $game = Get-SelectedGame

    if ($null -eq $game) {
        $selectedName.Text = "No game selected"
        $exePathLabel.Text = "Executable: not set"
        $playtimeLabel.Text = "Total playtime: 0h 00m"
        $lastPlayedLabel.Text = "Last played: never"
		$gameStatusLabel.Text = "Game status: NOT RUNNING"
        $gameStatusLabel.ForeColor = [System.Drawing.Color]::DarkRed
        return
    }

    $selectedName.Text = [string]$game.Name
	
	if ($script:TrackedProcesses.ContainsKey($game.Id)) {
        $gameStatusLabel.Text = "Game status: RUNNING"
        $gameStatusLabel.ForeColor = [System.Drawing.Color]::DarkGreen
    }
    else {
        $gameStatusLabel.Text = "Game status: NOT RUNNING"
        $gameStatusLabel.ForeColor = [System.Drawing.Color]::DarkRed
    }

    if ($game.ExePath) {
        $exePathLabel.Text = "Executable: " + [string]$game.ExePath
    }
    else {
        $exePathLabel.Text = "Executable: not set"
    }

    $seconds = [long]$game.TotalSeconds
    $duration = [TimeSpan]::FromSeconds([Math]::Max(0, $seconds))

    if ($duration.TotalDays -ge 1) {
        $playtimeLabel.Text = "Total playtime: {0}d {1:00}h {2:00}m" -f `
            [int]$duration.TotalDays, $duration.Hours, $duration.Minutes
    }
    else {
        $playtimeLabel.Text = "Total playtime: {0:00}h {1:00}m" -f `
            [int]$duration.TotalHours, $duration.Minutes
    }

    if ($game.LastPlayed) {
        $lastPlayedLabel.Text = "Last played: " + [string]$game.LastPlayed
    }
    else {
        $lastPlayedLabel.Text = "Last played: never"
    }
}
function Refresh-Achievements {
    $achievementsList.Items.Clear()

    $game = Get-SelectedGame

    if ($null -eq $game) {
        $achievementProgressLabel.Text = "Progress: 0 / 0 (0%)"
        $achievementProgressBar.Value = 0
        return
    }

    $allAchievements = @(
        $game.Achievements | Where-Object {
            $null -ne $_ -and $_.Title
        }
    )

    $total = $allAchievements.Count
    $unlocked = @(
        $allAchievements | Where-Object { $_.Unlocked }
    ).Count

    $percent = 0

    if ($total -gt 0) {
        $percent = [int][Math]::Round(
            ($unlocked / $total) * 100
        )
    }

    $achievementProgressLabel.Text = "Progress: $unlocked / $total ($percent%)"
    $achievementProgressBar.Value = $percent

    foreach ($achievement in $allAchievements) {
        if ($achievement.Unlocked) {
            $state = "[UNLOCKED]"
        } else {
            $state = "[LOCKED]"
        }

        [void]$achievementsList.Items.Add(
            "$state $($achievement.Title) - $($achievement.Description)"
        )
    }
}

# Automatic game playtime tracking
$script:ActiveGameId = $null
$script:SessionStart = $null
$script:SaveTickCounter = 0
$script:TrackedProcesses = @{}
$script:GameCheckTimer = New-Object System.Windows.Forms.Timer
$script:GameCheckTimer.Interval = 1000

# Check whether a configured game is running
$script:GameCheckTimer.Add_Tick({

    foreach ($game in $script:Games) {

        if ([string]::IsNullOrWhiteSpace($game.ExePath)) {
            continue
        }

        if (!(Test-Path -LiteralPath $game.ExePath)) {
            continue
        }

        $processName = [System.IO.Path]::GetFileNameWithoutExtension(
            $game.ExePath
        )

        $runningProcesses = @(
            Get-Process -Name $processName -ErrorAction SilentlyContinue
        )

        if ($runningProcesses.Count -gt 0) {
            $script:TrackedProcesses[$game.Id] = $true
        }
        else {
            $script:TrackedProcesses.Remove($game.Id)
        }
    }
	 # Find the first configured game that is running
    $activeGame = $null

    foreach ($game in $script:Games) {
        if ($script:TrackedProcesses.ContainsKey($game.Id)) {
            $activeGame = $game
            break
        }
    }

    if ($null -ne $activeGame) {

        if ($script:ActiveGameId -ne $activeGame.Id) {
            $script:ActiveGameId = $activeGame.Id
            $script:SessionStart = Get-Date
            $activeGame.LastPlayed = $script:SessionStart.ToString(
                "yyyy-MM-dd HH:mm:ss"
            )
        }

        $activeGame.TotalSeconds = [long]$activeGame.TotalSeconds + 1
        $script:SaveTickCounter++

        if ($script:SaveTickCounter -ge 30) {
            Save-Games
            $script:SaveTickCounter = 0
            Refresh-Details
        }
    }
    else {
        $script:ActiveGameId = $null
        $script:SessionStart = $null
    }
    Refresh-Details
})

# Main window
$form = New-Object System.Windows.Forms.Form
$form.Text = "Tolis Achievement Creator"
$form.Size = New-Object System.Drawing.Size(850, 540)
$form.MinimumSize = New-Object System.Drawing.Size(760, 480)
$form.StartPosition = "CenterScreen"

# Theme colors - matching Tolis Achievement System
$script:BgColor = [System.Drawing.Color]::FromArgb(28, 30, 36)
$script:PanelColor = [System.Drawing.Color]::FromArgb(39, 42, 50)
$script:GoldColor = [System.Drawing.Color]::FromArgb(240, 190, 85)
$script:TextColor = [System.Drawing.Color]::White
$script:MutedColor = [System.Drawing.Color]::FromArgb(210, 210, 220)
$script:GreenColor = [System.Drawing.Color]::FromArgb(100, 220, 130)
$script:RedColor = [System.Drawing.Color]::FromArgb(230, 100, 100)
$script:BlueColor = [System.Drawing.Color]::FromArgb(65, 85, 130)
$script:ButtonColor = [System.Drawing.Color]::FromArgb(70, 75, 88)

$form.BackColor = $script:BgColor
$form.ForeColor = $script:TextColor
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$gamesLabel = New-Object System.Windows.Forms.Label
$gamesLabel.Text = "MY GAMES"
$gamesLabel.ForeColor = $script:GoldColor
$gamesLabel.Font = New-Object System.Drawing.Font(
    "Segoe UI", 10, [System.Drawing.FontStyle]::Bold
)
$gamesLabel.Location = New-Object System.Drawing.Point(20, 20)
$gamesLabel.AutoSize = $true

$gamesList = New-Object System.Windows.Forms.ListBox
$gamesList.Location = New-Object System.Drawing.Point(20, 48)
$gamesList.Size = New-Object System.Drawing.Size(235, 300)
$gamesList.Anchor = "Top,Bottom,Left"
$gamesList.BackColor = $script:PanelColor
$gamesList.ForeColor = $script:TextColor
$gamesList.BorderStyle = "FixedSingle"

$addButton = New-Object System.Windows.Forms.Button
$addButton.Text = "Add game"
$addButton.FlatStyle = "Flat"
$addButton.BackColor = $script:BlueColor
$addButton.ForeColor = $script:TextColor
$addButton.Location = New-Object System.Drawing.Point(20, 360)
$addButton.Size = New-Object System.Drawing.Size(110, 32)
$addButton.Anchor = "Bottom,Left"

$renameButton = New-Object System.Windows.Forms.Button
$renameButton.Text = "Rename"
$renameButton.FlatStyle = "Flat"
$renameButton.BackColor = $script:ButtonColor
$renameButton.ForeColor = $script:TextColor
$renameButton.Location = New-Object System.Drawing.Point(140, 360)
$renameButton.Size = New-Object System.Drawing.Size(115, 32)
$renameButton.Anchor = "Bottom,Left"

$deleteButton = New-Object System.Windows.Forms.Button
$deleteButton.Text = "Delete game"
$deleteButton.FlatStyle = "Flat"
$deleteButton.BackColor = $script:RedColor
$deleteButton.ForeColor = $script:TextColor
$deleteButton.Location = New-Object System.Drawing.Point(20, 402)
$deleteButton.Size = New-Object System.Drawing.Size(110, 32)
$deleteButton.Anchor = "Bottom,Left"

$selectedName = New-Object System.Windows.Forms.Label
$selectedName.Text = "Select a game"
$selectedName.Location = New-Object System.Drawing.Point(285, 48)
$selectedName.AutoSize = $true
$selectedName.Font = New-Object System.Drawing.Font(
    "Segoe UI", 15, [System.Drawing.FontStyle]::Bold
)

$selectedName.ForeColor = $script:GoldColor

$exePathLabel = New-Object System.Windows.Forms.Label
$exePathLabel.Text = "Executable: not set"
$exePathLabel.Location = New-Object System.Drawing.Point(285, 95)
$exePathLabel.Size = New-Object System.Drawing.Size(510, 35)
$exePathLabel.AutoEllipsis = $true
$exePathLabel.ForeColor = $script:MutedColor
$browseExeButton = New-Object System.Windows.Forms.Button
$browseExeButton.Text = "Browse EXE..."
$browseExeButton.FlatStyle = "Flat"
$browseExeButton.BackColor = $script:ButtonColor
$browseExeButton.ForeColor = $script:TextColor
$browseExeButton.Location = New-Object System.Drawing.Point(140, 400)
$browseExeButton.Anchor = "Bottom,Left"
$browseExeButton.Size = New-Object System.Drawing.Size(130, 28)

$playtimeLabel = New-Object System.Windows.Forms.Label
$playtimeLabel.Text = "Total playtime: 0h 00m"
$playtimeLabel.Location = New-Object System.Drawing.Point(285, 135)
$playtimeLabel.AutoSize = $true
$playtimeLabel.ForeColor = [System.Drawing.Color]::White
$playtimeLabel.BackColor = $script:BgColor
$playtimeLabel.Font = New-Object System.Drawing.Font(
    "Segoe UI", 10, [System.Drawing.FontStyle]::Bold
)

$lastPlayedLabel = New-Object System.Windows.Forms.Label
$lastPlayedLabel.Text = "Last played: never"
$lastPlayedLabel.Location = New-Object System.Drawing.Point(285, 165)
$lastPlayedLabel.AutoSize = $true
$lastPlayedLabel.ForeColor = $script:TextColor
$lastPlayedLabel.BackColor = $script:BgColor

$gameStatusLabel = New-Object System.Windows.Forms.Label
$gameStatusLabel.Text = "Game status: NOT RUNNING"
$gameStatusLabel.Location = New-Object System.Drawing.Point(285, 200)
$gameStatusLabel.AutoSize = $true
$gameStatusLabel.ForeColor = [System.Drawing.Color]::DarkRed

$achievementsLabel = New-Object System.Windows.Forms.Label
$achievementsLabel.Text = "ACHIEVEMENTS"
$achievementsLabel.Location = New-Object System.Drawing.Point(285, 230)
$achievementsLabel.AutoSize = $true
$achievementsLabel.Font = New-Object System.Drawing.Font(
    "Segoe UI", 10, [System.Drawing.FontStyle]::Bold
)

$achievementProgressLabel = New-Object System.Windows.Forms.Label
$achievementProgressLabel.Text = "Progress: 0 / 0 (0%)"
$achievementProgressLabel.Location = New-Object System.Drawing.Point(285, 265)
$achievementProgressLabel.AutoSize = $true

$achievementProgressBar = New-Object System.Windows.Forms.ProgressBar
$achievementProgressBar.Location = New-Object System.Drawing.Point(285, 285)
$achievementProgressBar.Size = New-Object System.Drawing.Size(510, 14)
$achievementProgressBar.Minimum = 0
$achievementProgressBar.Maximum = 100
$achievementProgressBar.Value = 0
$achievementProgressBar.Style = "Continuous"
$achievementProgressBar.Anchor = "Top,Left,Right"

$achievementsList = New-Object System.Windows.Forms.ListBox
$achievementsList.Location = New-Object System.Drawing.Point(285, 305)
$achievementsList.Size = New-Object System.Drawing.Size(510, 85)
$achievementsList.Anchor = "Top,Bottom,Left,Right"
$achievementsList.BackColor = $script:PanelColor
$achievementsList.ForeColor = $script:TextColor
$achievementsList.BorderStyle = "FixedSingle"

$addAchievementButton = New-Object System.Windows.Forms.Button
$addAchievementButton.Text = "Add Achievement"
$addAchievementButton.Location = New-Object System.Drawing.Point(285, 400)
$addAchievementButton.Size = New-Object System.Drawing.Size(150, 32)
$addAchievementButton.FlatStyle = "Flat"
$addAchievementButton.BackColor = $script:BlueColor
$addAchievementButton.ForeColor = $script:TextColor
$addAchievementButton.Anchor = "Bottom,Left"

$toggleAchievementButton = New-Object System.Windows.Forms.Button
$toggleAchievementButton.Text = "Unlock / Lock"
$toggleAchievementButton.Location = New-Object System.Drawing.Point(445, 400)
$toggleAchievementButton.Size = New-Object System.Drawing.Size(140, 32)
$toggleAchievementButton.FlatStyle = "Flat"
$toggleAchievementButton.BackColor = [System.Drawing.Color]::FromArgb(60, 130, 80)
$toggleAchievementButton.Anchor = "Bottom,Left"

$deleteAchievementButton = New-Object System.Windows.Forms.Button
$deleteAchievementButton.Text = "Delete"
$deleteAchievementButton.Location = New-Object System.Drawing.Point(595, 400)
$deleteAchievementButton.Size = New-Object System.Drawing.Size(100, 32)
$deleteAchievementButton.FlatStyle = "Flat"
$deleteAchievementButton.BackColor = $script:RedColor
$deleteAchievementButton.ForeColor = $script:TextColor
$deleteAchievementButton.Anchor = "Bottom,Left"
$editAchievementButton = New-Object System.Windows.Forms.Button
$editAchievementButton.Text = "Edit"
$editAchievementButton.Location = New-Object System.Drawing.Point(705, 400)
$editAchievementButton.Size = New-Object System.Drawing.Size(90, 32)
$editAchievementButton.FlatStyle = "Flat"
$editAchievementButton.BackColor = $script:GoldColor
$editAchievementButton.ForeColor = [System.Drawing.Color]::Black
$editAchievementButton.Anchor = "Bottom,Left"

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready"
$statusLabel.Location = New-Object System.Drawing.Point(20, 465)
$statusLabel.Size = New-Object System.Drawing.Size(780, 25)
$statusLabel.Anchor = "Bottom,Left,Right"

$form.Controls.AddRange(@(
    $gamesLabel,
    $gamesList,
    $addButton,
    $renameButton,
    $deleteButton,
    $selectedName,
    $exePathLabel,
	$browseExeButton,
    $playtimeLabel,
    $lastPlayedLabel,
    $gameStatusLabel,
    $achievementsLabel,
	$achievementProgressLabel,
    $achievementProgressBar,
	$achievementsList,
    $addAchievementButton,
    $toggleAchievementButton,
    $deleteAchievementButton,
	$editAchievementButton,
    $statusLabel
))
# Browse and save the selected game's EXE
$browseExeButton.Add_Click({

    $game = Get-SelectedGame

    if ($null -eq $game) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select a game first.",
            "No game selected"
        ) | Out-Null
        return
    }

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select EXE for $($game.Name)"
    $dialog.Filter = "Executable Files (*.exe)|*.exe|All Files (*.*)|*.*"
    $dialog.CheckFileExists = $true
    $dialog.Multiselect = $false

    if ($game.ExePath -and (Test-Path -LiteralPath $game.ExePath)) {
        $dialog.InitialDirectory = Split-Path -Parent $game.ExePath
        $dialog.FileName = Split-Path -Leaf $game.ExePath
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $game.ExePath = $dialog.FileName
        Save-Games
        Refresh-Details
        $statusLabel.Text = "EXE saved for $($game.Name)."
    }

    $dialog.Dispose()
})

# Selecting a game updates its details
$gamesList.Add_SelectedIndexChanged({
    Refresh-Details
    Refresh-Achievements
})

# Unlock or lock the selected achievement
$toggleAchievementButton.Add_Click({

    $game = Get-SelectedGame

    if ($null -eq $game) {
        return
    }

    $index = $achievementsList.SelectedIndex

    if ($index -lt 0 -or $index -ge @($game.Achievements).Count) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select an achievement first.",
            "No achievement selected"
        ) | Out-Null
        return
    }

    $achievement = $game.Achievements[$index]
    $achievement.Unlocked = -not [bool]$achievement.Unlocked

    if ($achievement.Unlocked) {
        $achievement.UnlockedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    else {
        $achievement.UnlockedAt = ""
    }

    Save-Games
    Refresh-Achievements

    $achievementsList.SelectedIndex = $index
    $statusLabel.Text = "Achievement status updated."
})

# Delete the selected achievement
$deleteAchievementButton.Add_Click({

    $game = Get-SelectedGame

    if ($null -eq $game) {
        return
    }

    $index = $achievementsList.SelectedIndex

    if ($index -lt 0 -or $index -ge @($game.Achievements).Count) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select an achievement first.",
            "No achievement selected"
        ) | Out-Null
        return
    }

    $achievement = $game.Achievements[$index]

    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Delete achievement '$($achievement.Title)'?",
        "Confirm deletion",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
        $game.Achievements = @(
            for ($i = 0; $i -lt @($game.Achievements).Count; $i++) {
                if ($i -ne $index) {
                    $game.Achievements[$i]
                }
            }
        )

        Save-Games
        Refresh-Achievements
        $statusLabel.Text = "Achievement deleted."
    }
})

# Edit the selected achievement
$editAchievementButton.Add_Click({

    $game = Get-SelectedGame

    if ($null -eq $game) {
        return
    }

    $index = $achievementsList.SelectedIndex

    if ($index -lt 0 -or $index -ge @($game.Achievements).Count) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select an achievement first.",
            "No achievement selected"
        ) | Out-Null
        return
    }

    $achievement = $game.Achievements[$index]

    $title = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter the achievement title:",
        "Edit Achievement",
        [string]$achievement.Title
    )

    if ([string]::IsNullOrWhiteSpace($title)) {
        return
    }

    $description = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter the achievement description:",
        "Edit Achievement",
        [string]$achievement.Description
    )

    if ([string]::IsNullOrWhiteSpace($description)) {
        return
    }

    $achievement.Title = $title.Trim()
    $achievement.Description = $description.Trim()

    Save-Games
    Refresh-Achievements

    $achievementsList.SelectedIndex = $index
    $statusLabel.Text = "Achievement updated for $($game.Name)."
})

# Add a new achievement
$addAchievementButton.Add_Click({

    $game = Get-SelectedGame

    if ($null -eq $game) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select a game first.",
            "No game selected"
        ) | Out-Null
        return
    }

    $title = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter the achievement title:",
        "Add Achievement",
        ""
    )

    if ([string]::IsNullOrWhiteSpace($title)) {
        return
    }

    $description = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter the achievement description:",
        "Add Achievement",
        ""
    )

    if ([string]::IsNullOrWhiteSpace($description)) {
        return
    }

    $newAchievement = [pscustomobject]@{
        Id = [guid]::NewGuid().ToString()
        Title = $title.Trim()
        Description = $description.Trim()
        Unlocked = $false
        UnlockedAt = ""
    }

    $game.Achievements = @($game.Achievements) + @($newAchievement)

    Save-Games
    Refresh-Achievements

    $statusLabel.Text = "Achievement added for $($game.Name)."
})

# Add a game
$addButton.Add_Click({
    $name = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter the game title:",
        "Add game",
        ""
    )

    if (![string]::IsNullOrWhiteSpace($name)) {
        $newGame = [pscustomobject]@{
            Id = [guid]::NewGuid().ToString()
            Name = $name.Trim()
            ExePath = ""
            TotalSeconds = 0
            LastPlayed = ""
            Achievements = @()
        }

        $script:Games = @($script:Games) + @($newGame)
        Save-Games
        Refresh-Games
        $gamesList.SelectedIndex = $gamesList.Items.Count - 1
        Refresh-Details
    }
})

# Rename selected game
$renameButton.Add_Click({
    $game = Get-SelectedGame

    if ($null -ne $game) {
        $name = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter the new game title:",
            "Rename game",
            [string]$game.Name
        )

        if (![string]::IsNullOrWhiteSpace($name)) {
            $game.Name = $name.Trim()
            Save-Games
            Refresh-Games
            Refresh-Details
        }
    }
})

# Delete selected game
$deleteButton.Add_Click({
    $game = Get-SelectedGame

    if ($null -ne $game) {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "Delete '$($game.Name)' and its saved data?",
            "Confirm deletion",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
            $script:Games = @(
                $script:Games | Where-Object { $_.Id -ne $game.Id }
            )
            Save-Games
            Refresh-Games
            Refresh-Details
        }
    }
})

$form.Add_FormClosing({
    Save-Games
})

Load-Games
Refresh-Games
Refresh-Details
Refresh-Achievements

$script:GameCheckTimer.Start()

[void]$form.ShowDialog()
