<#
INSTRUCTIONS
place this script in the container folder that contains all your git projects.
it will extract any git log for git projects nested on that container, up to a depth level of 4 ( confirubale in the empty params)
Getting the author name:
- Check a gitlog of a repo, and search for your authorname
- run "git config user.name" and grab the name from there
#>

$pathDelimiter = "\"
if ($IsMacOS -or $IsLinux) {
    #only works in powershell core, change delimiter if UNIX system
    $pathDelimiter = "/"
}
write-host "Using path delimiter = $pathDelimiter"
$gitRelateFolder = "$PSScriptRoot\"
$gitlogFolder = "zartis-logs"
$gitAuthor = ""
while (!$gitAuthor) {
    $gitAuthor = Read-Host -Prompt "Please enter the author name for the git commits"
}
$semester = -1
while ($semester -notin 0, 1, 2) {
    $semester = Read-Host -Prompt "Please enter target semester of the report ( 0 = full year (just press enter), 1 = 1st semester, 2 = 2nd semester )"
    if ($semester -eq -1) { $semester = 0}
}
$currentYear = ""
while (!$currentYear) {
    $currentYear = Read-Host -Prompt "Please enter target year of the report (press enter for current year)"
    if (!$currentYear) { $currentYear = Get-Date -Format "yyyy" }
}
switch ($semester) {
    1 {
        $startDate = Get-Date -Year $currentYear -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0 -Format "yyyy-MM-ddTHH.mm:ssK"
        $endDate = Get-Date -Year $currentYear -Month 6 -Day 30 -Hour 23 -Minute 59 -Second 59 -Format "yyyy-MM-ddTHH.mm:ssK"
    }
    2 {
        $startDate = Get-Date -Year $currentYear -Month 07 -Day 1 -Hour 0 -Minute 0 -Second 0 -Format "yyyy-MM-ddTHH.mm:ssK"
        $endDate = Get-Date -Year $currentYear -Month 12 -Day 31 -Hour 23 -Minute 59 -Second 59 -Format "yyyy-MM-ddTHH.mm:ssK"
    }
    Default {
        $startDate = Get-Date -Year $currentYear -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0 -Format "yyyy-MM-ddTHH.mm:ssK"
        $endDate = Get-Date -Year $currentYear -Month 12 -Day 31 -Hour 23 -Minute 59 -Second 59 -Format "yyyy-MM-ddTHH.mm:ssK"
    }
}
write-host "Searching logs from $startDate to $endDate"

$semesterLabel = ""
if ($semester -gt 0) {
    $semesterLabel = "-s{0}" -f $semester
}
$gitlogFolder = "zartis-logs-{0}{1}" -f $currentYear, $semesterLabel

$nestedFolders = 4 # used for the dept level
# create ( if needed ) the folder where we want to store the gitlogs
if ( !$(Test-Path $gitRelateFolder$gitlogFolder -ErrorAction SilentlyContinue) ) {
    New-Item -ItemType Directory $gitRelateFolder$gitlogFolder > $null
}
$gitlogFolder = Get-Item -path $gitRelateFolder$gitlogFolder -ErrorAction Stop
#generate the git logs for all existing repos and for the given username
$gitRepos = Get-ChildItem -recurse -Directory -Path $gitRelateFolder -Force -depth $nestedFolders | Where-Object { $_.name -eq ".git" }
$gitRepos | ForEach-Object {
    $gitrepo = $_
    $gitrepoFolder = $gitrepo.FullName.Substring(0, $gitrepo.FullName.LastIndexOf($pathDelimiter) + 1)
    $gitreponame = $(get-item -path $gitrepoFolder ).name
    Set-Location -Path $gitrepoFolder -ErrorAction Stop > $null
    $gitlogfilename = "{0}-{1}.csv" -f $gitreponame, $($gitAuthor -replace " ", "")
    $trycheckout = git checkout master *>&1
    if ( "$trycheckout".indexOf( "error") -ge 0) {
        write-host "There are pending changes on current branch. Please commit and merge to master, then try again '$gitlogfilename'" -foregroundcolor red
    }
    else {
        . { git log --author="$gitAuthor" --branches --pretty="format:%h;%an;%ad;%s;" --date=local --no-merges --shortstat --after="$startDate" --before "$endDate" > $gitlogFolder$pathDelimiter$gitlogfilename }
        write-host "Log exported '$gitlogfilename'" -foregroundcolor green
    }
}
#cleanup empty logs
Get-ChildItem -Recurse -Path $gitlogFolder | ForEach-Object {
    $gitlog = $_
    if ($(Get-Content -Path $gitlog.FullName) -eq $null) {
        Remove-Item -Path $gitlog.FullName -Force
        write-host "Empty log deleted '$($gitlog.FullName)'" -foregroundcolor darkyellow
    }
    else {
        #add csv headers
        "hash;author;date;message;diff`r`n" + (Get-Content $gitlog.FullName -Raw) | Set-Content $gitlog.FullName
        #cleanup format
        ((Get-Content -path $gitlog.FullName -Raw).Replace(";`r`n ", ";")) | Set-Content -Path $gitlog.FullName
        ((Get-Content -path $gitlog.FullName -Raw).Replace("`r`n`r`n", "`r`n")) | Set-Content -Path $gitlog.FullName
    }
}
Set-Location -Path $gitRelateFolder -ErrorAction Stop > $null
write-host "=> All Logs can be found here: '$($gitlogFolder.Fullname)$pathDelimiter'" -foregroundcolor green
