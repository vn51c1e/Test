param()

function Write-Log {
    param (
        [string]$Message,
        [string]$path,
        [string]$Severity = "Info"
    )
    if (-not $path) {
        Write-Error "The 'path' parameter is empty. Cannot write log message."
        return
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Severity] $Message"
    Add-Content -Path $path -Value $logMessage
}

function New-FolderCreation {
    param (
        [string]$foldername
    )
    if (-not (Test-Path -Path $foldername)) {
        New-Item -ItemType Directory -Path $foldername
    }
}

#################logs and variables##########################
$log = "logs/githubcopilotmetrics.log"
$report1 = "Report/githubcopilotmetrics-Suggestions.csv"
$report2 = "Report/githubcopilotmetrics-Languages-Suggestions.csv"

$ent = "xxxx"

#$apiUrl = "https://api.github.com/orgs/$ent/copilot/billing"

#$usageAPIUrl = "https://api.github.com/orgs/$ent/copilot/usage" retired

$usageAPIUrl = "https://api.github.com/orgs/$ent/copilot/metrics"

$logrecyclelimit = "60"
New-FolderCreation -foldername "Archive"
$datastorage = $(get-location).path + "\Archive"
$userscsv = $(get-location).path + "\Archive\githubcopilotmetrics-users.csv"
###################Admin params##########################
$smtpserver = "smtpserver"
$erroremail = "xxxx"
$from = "xxxxx"
######################Spo Cet Auth#########################
$token = "xxxx"
Write-Log -Message "Start...........Script" -path $log 
##############################rest api function#############################
# Function to make API requests
function Invoke-GitHubApi {
  param (
    [string]$url
  )
  $headers = @{
    Authorization = "token $token"
    Accept        = "application/vnd.github.v3+json"
  }
  $allResults = @()
  $page = 1
  do {
    $pagedUrl = $url + "?page=" + $page
    Write-Log -Message "Requesting URL: $pagedUrl" -path $log
    $response = Invoke-RestMethod -Uri $pagedUrl -Headers $headers -Method Get
    $allResults += $response.Seats
    $page++
  } while ($response.Seats.Count -gt 0)
  return $allResults
}

############################Start script############################################
try { 
  Write-Log -Message "invoke rest api" -path $log
  $copilotUsers = Invoke-GitHubApi -url $apiUrl
  $copilotUsers | ForEach-Object {
    $getaduser = $login = $null
    $Login = $_.assignee.login
    # Apply general replacements
    $Login = ($Login -replace '-', '.' -replace '_', '@' -replace 'testcb', 'test.com')

    $getaduser = get-aduser -filter { UserPrincipalName -eq $Login }

    if ($getaduser) {
      [PSCustomObject]@{
        Login              = $Login
        AssignedTime       = $_.created_at
        AssignedMonth      = $(get-date $_.created_at).ToString("MMMM")
        LastActivity       = $_.last_activity_at
        LastActivityEditor = $_.last_activity_editor
        Status             = "FoundinAD"
      }

    }
    else {
      [PSCustomObject]@{
        Login              = $Login
        AssignedTime       = $_.created_at
        AssignedMonth      = $(get-date $_.created_at).ToString("MMMM")
        LastActivity       = $_.last_activity_at
        LastActivityEditor = $_.last_activity_editor
        Status             = "NotFoundinAD"
      }
    }

  } | Select | Export-Csv $userscsv -NoTypeInformation

  Write-Log -Message "Created Report" -path $log
}
catch {
  $exception = $_.Exception.Message
  Write-Log -Message "exception $exception has occured creating users report - githubcopilotmetrics" -path $log -Severity Error
  #Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error creating users report - githubcopilotmetrics" -Body $($_.Exception.Message)
  break;
}
########################################usage report#####################################
try {
  $headers = @{
    Authorization = "token $token"
    Accept        = "application/vnd.github.v3+json"
  }
  $copilotUsage = Invoke-RestMethod -Uri $usageAPIUrl -Headers $headers -Method Get
  $collection = @()
  $copilotUsage | ForEach-Object {
    $coll = "" | Select-Object day, total_suggestions_count, total_acceptances_count, total_lines_suggested, total_lines_accepted, total_active_users, total_chat_acceptances, total_chat_turns,total_active_chat_users,total_chat_copy_events,total_chat_insertion_events
    $coll.day = $_.date
    
    $totalSuggestions = 0
    foreach($i in $_.copilot_ide_code_completions.editors) {
      foreach($suggestion in $i.models.languages.total_code_suggestions) {
        $totalSuggestions += $suggestion
      }
    }
    $coll.total_suggestions_count = $totalSuggestions

    $totalcodeacceptences = 0
    foreach($i in $_.copilot_ide_code_completions.editors) {
      foreach($suggestion in $i.models.languages.total_code_acceptances) {
        $totalcodeacceptences += $suggestion
      }
    }
    
    $coll.total_acceptances_count = $totalcodeacceptences
    $totallinessuggested = 0
    foreach($i in $_.copilot_ide_code_completions.editors) {
      foreach($suggestion in $i.models.languages.total_code_lines_suggested) {
        $totallinessuggested += $suggestion
      }
    }
    $coll.total_lines_suggested = $totallinessuggested

    $totallinesaccepted = 0
    foreach($i in $_.copilot_ide_code_completions.editors) {
      foreach($suggestion in $i.models.languages.total_code_lines_accepted) {
        $totallinesaccepted += $suggestion
      }
    }
    $coll.total_lines_accepted = $totallinesaccepted
    $coll.total_active_users = $_.total_active_users

    $totalchats= 0
    foreach($i in $_.copilot_ide_chat.editors) {
      foreach($suggestion in $i.models.Total_chats) {
        $totalchats += $suggestion
      }
    }
    $coll.total_chat_turns = $totalchats

    $totalchatacceptances = 0
    $totalchatinsertionevents = 0
    foreach($i in $_.copilot_ide_chat.editors) {
      foreach($suggestion in $i.models.total_chat_insertion_events) {
        $totalchatinsertionevents += $suggestion
      }
    }
    $coll.total_chat_insertion_events = $totalchatinsertionevents

    $totalchatcopyevents = 0
    foreach($i in $_.copilot_ide_chat.editors) {
      foreach($suggestion in $i.models.total_chat_copy_events) {
        $totalchatcopyevents += $suggestion
      }
    }
    $coll.total_chat_copy_events = $totalchatcopyevents
    
    $totalchatacceptances += $totalchatcopyevents 
    $totalchatacceptances += $totalchatinsertionevents
    $coll.total_chat_acceptances = $totalchatacceptances

    $totalchatengagedusers= 0
    foreach($i in $_.copilot_ide_chat.editors) {
      foreach($suggestion in $i.models.total_engaged_users) {
        $totalchatengagedusers += $suggestion
      }
    }
    
    $coll.total_active_chat_users = $totalchatengagedusers
    $collection += $coll
  }
  $collection | Export-Csv $report1 -NoTypeInformation
  Move-Item -Path $report1 -Destination $datastorage -Force
  #########################Create similar files for languages################################
  $lcollection = @()
  $copilotUsage | ForEach-Object {
    foreach ($editor in $_.copilot_ide_code_completions.editors) {
      foreach ($language in $editor.models.languages) {
        $coll = "" | Select-Object day, language, total_engaged_users, total_code_acceptances, total_code_suggestions, total_code_lines_accepted, total_code_lines_suggested
        $coll.day = $_.date
        $coll.language = $language.name
        $coll.total_engaged_users = $language.total_engaged_users
        $coll.total_code_acceptances = $language.total_code_acceptances
        $coll.total_code_suggestions = $language.total_code_suggestions
        $coll.total_code_lines_accepted = $language.total_code_lines_accepted
        $coll.total_code_lines_suggested = $language.total_code_lines_suggested
        $lcollection += $coll
      }
    }
  }
  $lcollection | Export-Csv $report2 -NoTypeInformation
  Move-Item -Path $report2 -Destination $datastorage -Force
}
catch {
  $exception = $_.Exception.Message
  Write-Log -Message "exception $exception has occured creating usage report - githubcopilotmetrics" -path $log -Severity Error
  #Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error creating usage report - githubcopilotmetrics" -Body $($_.Exception.Message)
  break;
}
#########################Recycle Logs#################################################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
#Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - githubcopilotmetrics" -Attachments $log
#######################################################################################
