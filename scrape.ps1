# Cloud scraper for the Degree Apprenticeship Tracker.
# Runs on GitHub Actions (PowerShell Core, Linux) twice a day.
# Reads & rewrites the three sector data files (sales / finance / consulting).
# Source: GOV.UK "Find an Apprenticeship" only. Non-technical (sales/finance/consulting) roles.

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$TECH = 'software|web develop|developer|programmer|data scien|data engineer|data analy|\bdata\b|cyber|\bcloud|devops|infrastructure|\bnetwork|enginee|structural|mechanical|electrical|chemical|aerospace|laborator|quantity survey|architect\b'
$BIG  = 'microsoft|ibm|salesforce|amazon|oracle|\bsap\b|hsbc|barclays|goldman|jpmorgan|j\.p\. morgan|jp morgan|pwc|pricewaterhouse|deloitte|kpmg|ernst|\bey\b|accenture|capgemini|cognizant|infosys|tata|\btcs\b|bt group|\bbt\b|vodafone|\bsky\b|virgin media|\bo2\b|lloyds|natwest|santander|nationwide|standard chartered|aviva|legal & general|prudential|\baxa\b|allianz|zurich|morgan stanley|\bciti\b|bank of america|merrill|\bubs\b|deutsche bank|nomura|bnp paribas|schroders|fidelity|unilever|procter|nestle|coca-cola|pepsico|diageo|\bmars\b|johnson|\bgsk\b|glaxo|astrazeneca|pfizer|siemens|bosch|cisco|\bdell\b|\bhp\b|hewlett|intel|google|meta|apple|adobe|tesco|sainsbury|\basda\b|marks & spencer|m&s|john lewis|boots|\bbp\b|shell|centrica|national grid|rolls-royce|\bbae\b|airbus|jaguar|land rover|nissan|toyota|\bford\b|\bbmw\b|mercedes|volkswagen|network rail|royal mail|\bdhl\b|fedex|\bups\b|american express|\bamex\b|visa|mastercard|paypal|\bsage\b|softcat|computacenter'

function Parse-CloseDate([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }
  $s2 = $s -replace ' at .*$','' -replace '^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+',''
  try { ([datetime]::Parse($s2.Trim(), [System.Globalization.CultureInfo]::GetCultureInfo('en-GB'))).ToString('yyyy-MM-dd') } catch { $null }
}
function Status-From([string]$iso) {
  if ([string]::IsNullOrWhiteSpace($iso)) { return 'open' }
  try { $d = ([datetime]$iso - (Get-Date)).TotalDays; if ($d -lt 0) { 'closed' } elseif ($d -le 14) { 'closing_soon' } else { 'open' } } catch { 'open' }
}
function Is-Technical([string]$title, [string]$course) { (("$title $course").ToLower()) -match $TECH }
function Category-From([string]$title) {
  $t = $title.ToLower()
  if ($t -match 'sales|business develop|account|customer|relationship|commercial|partnership') { 'Sales' }
  elseif ($t -match 'audit|assurance|\btax\b') { 'Audit' }
  elseif ($t -match 'finance|financ|bank|invest|wealth') { 'Finance' }
  elseif ($t -match 'consult|advis|strateg') { 'Consulting' }
  elseif ($t -match 'market') { 'Marketing' }
  else { 'Business' }
}
# Route a broad-search "interest" listing to the sector page it belongs on.
function Sector-ForCategory([string]$cat) {
  switch ($cat) {
    'Finance'    { 'finance' }
    'Audit'      { 'consulting' }
    'Consulting' { 'consulting' }
    default      { 'sales' }   # Sales, Marketing, Business
  }
}
function Get-Vacancies([string]$html) {
  $out = @()
  $titles = [regex]::Matches($html, '<span id="(VAC\d+)-vacancy-title">([^<]*)</span>')
  for ($k = 0; $k -lt $titles.Count; $k++) {
    $id = $titles[$k].Groups[1].Value; $title = ($titles[$k].Groups[2].Value).Trim()
    $bStart = $titles[$k].Index
    $bEnd = if ($k + 1 -lt $titles.Count) { $titles[$k+1].Index } else { $html.Length }
    $block = $html.Substring($bStart, $bEnd - $bStart)
    $employer=''; $location=''; $course=''; $closeRaw=''
    $em = [regex]::Match($block, '<p class="govuk-body govuk-!-margin-bottom-0">([^<]+)</p>'); if ($em.Success) { $employer = $em.Groups[1].Value.Trim() }
    $lm = [regex]::Match($block, 'das-!-color-dark-grey">\s*([^<]+?)\s*</p>'); if ($lm.Success) { $location = ($lm.Groups[1].Value.Trim() -replace '\s+',' ') }
    $cm = [regex]::Match($block, '<b>Training course</b>\s*([^<]+)</p>'); if ($cm.Success) { $course = $cm.Groups[1].Value.Trim() }
    $clm = [regex]::Match($block, 'Closes[^(<]*\(([^)]+)\)'); if ($clm.Success) { $closeRaw = $clm.Groups[1].Value.Trim() }
    $out += [pscustomobject]@{ id=$id; title=$title; employer=$employer; location=$location; course=$course; closeISO=(Parse-CloseDate $closeRaw) }
  }
  return $out
}
function Fetch-Html([string]$url) {
  try { (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30 -Headers @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }).Content } catch { $null }
}

# ---- the three sector datasets ----
$sectorFiles = [ordered]@{ sales = 'sales/data.json'; finance = 'finance/data.json'; consulting = 'consulting/data.json' }
$today = (Get-Date).ToString('yyyy-MM-dd')

$data = @{}
foreach ($s in $sectorFiles.Keys) {
  $p = Join-Path $root $sectorFiles[$s]
  $data[$s] = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

$errors = 0
$liveItems = @()       # {id, company, title, sector} for everything found this run (for notifications)
$coreIdsAll = @{}      # vacancy ids matched to a core company (excluded from interest)
$coreLive = 0

# ---- core companies: scrape each sector's tracked employers ----
foreach ($s in $sectorFiles.Keys) {
  foreach ($co in $data[$s].companies) {
    $html = Fetch-Html $co.govSearchUrl
    if ($null -eq $html) { $errors++; continue }
    $matched = @()
    foreach ($v in (Get-Vacancies $html)) {
      $empOk = $false
      foreach ($variant in $co.employerNameVariants) { if ($v.employer -and ($v.employer.ToLower() -like ("*" + $variant.ToLower() + "*"))) { $empOk = $true; break } }
      if (-not $empOk) { continue }
      if (Is-Technical $v.title $v.course) { continue }
      $matched += $v
    }
    if ($matched.Count -gt 0) {
      $progs = @()
      foreach ($v in ($matched | Sort-Object { if ($_.closeISO) { [datetime]$_.closeISO } else { [datetime]::MaxValue } })) {
        $coreIdsAll[$v.id] = $true; $coreLive++
        $liveItems += [pscustomobject]@{ id=$v.id; company=$co.name; title=$v.title; sector=$s }
        $progs += [pscustomobject]@{
          id=$v.id; name=$v.title; standard="Level 6"; location=$v.location; salary=$null; duration=""
          status=(Status-From $v.closeISO); closingDate=$v.closeISO
          applyUrl=("https://www.findapprenticeship.service.gov.uk/apprenticeship/" + $v.id)
          govVacancyId=$v.id; firstSeen=$today; lastSeen=$today
        }
      }
      $co.programs = $progs
    }
    # else: leave the company's existing (seeded / pre-season) programs untouched
  }
}

# ---- interest: broad GOV.UK searches, routed to the matching sector page ----
$terms = @('sales','business+development','account+management','finance','banking','consulting','audit','business','marketing','commercial')
$interestBySector = @{ sales = @(); finance = @(); consulting = @() }
$seenInterest = @{}
foreach ($term in $terms) {
  $html = Fetch-Html "https://www.findapprenticeship.service.gov.uk/apprenticeships?searchTerm=$term&levelIds=6&distanceType=England&sort=AgeDesc"
  if ($null -eq $html) { $errors++; continue }
  foreach ($v in (Get-Vacancies $html)) {
    if ($seenInterest.ContainsKey($v.id) -or $coreIdsAll.ContainsKey($v.id)) { continue }
    if (Is-Technical $v.title $v.course) { continue }
    if (-not $v.employer) { continue }
    if ($v.employer.ToLower() -notmatch $BIG) { continue }
    if ($v.closeISO -and ([datetime]$v.closeISO -lt (Get-Date))) { continue }
    $seenInterest[$v.id] = $true
    $cat = Category-From $v.title
    $sec = Sector-ForCategory $cat
    $liveItems += [pscustomobject]@{ id=$v.id; company=$v.employer; title=$v.title; sector=$sec }
    $interestBySector[$sec] += [pscustomobject]@{
      id=$v.id; company=$v.employer; title=$v.title; standard="Level 6"; location=$v.location; salary=$null
      category=$cat; closingDate=$v.closeISO
      applyUrl=("https://www.findapprenticeship.service.gov.uk/apprenticeship/" + $v.id); firstSeen=$today
    }
  }
}

# ---- per-sector: update meta, compute what's new, write the file ----
$allNew = @()   # {id, sector}
foreach ($s in $sectorFiles.Keys) {
  $d = $data[$s]
  $d.interestListings = @($interestBySector[$s])

  $sectorIds = @()
  foreach ($co in $d.companies) { foreach ($p in $co.programs) { if ($p.govVacancyId) { $sectorIds += $p.govVacancyId } } }
  foreach ($it in $interestBySector[$s]) { $sectorIds += $it.id }
  $sectorIds = @($sectorIds | Select-Object -Unique)

  $seen = @(); if ($d.meta.seenVacancyIds) { $seen = @($d.meta.seenVacancyIds) }
  $new = @($sectorIds | Where-Object { $seen -notcontains $_ })
  foreach ($n in $new) { $allNew += [pscustomobject]@{ id=$n; sector=$s } }

  $d.meta.lastUpdated = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  $d.meta.seenVacancyIds = @($seen + $sectorIds | Select-Object -Unique)
  $d.meta.newSinceLastScrape = @($new)

  $json = $d | ConvertTo-Json -Depth 12
  [System.IO.File]::WriteAllText((Join-Path $root $sectorFiles[$s]), $json, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host "Done. coreLive=$coreLive new=$($allNew.Count) errors=$errors"

# --- Notifications — only when there are genuinely NEW roles this run ---
if ($allNew.Count -gt 0) {
  $lines = @()
  foreach ($grp in ($allNew | Group-Object sector)) {
    $lines += ($grp.Name.ToUpper())
    foreach ($n in $grp.Group) {
      $it = $liveItems | Where-Object { $_.id -eq $n.id -and $_.sector -eq $n.sector } | Select-Object -First 1
      if ($it) { $lines += ("- {0}: {1}" -f $it.company, $it.title) }
    }
  }
  $msg = "New Level 6 apprenticeship(s) found:`n" + ($lines -join "`n")
  $sent = $false

  # Telegram (preferred) — needs TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID (stored as GitHub Secrets)
  $tgToken = $env:TELEGRAM_BOT_TOKEN; $tgChat = $env:TELEGRAM_CHAT_ID
  if ($tgToken -and $tgChat) {
    try {
      Invoke-RestMethod -Uri "https://api.telegram.org/bot$tgToken/sendMessage" -Method Post -Body @{ chat_id = $tgChat; text = $msg } | Out-Null
      Write-Host "Sent Telegram notification ($($allNew.Count) new role(s))."; $sent = $true
    } catch { Write-Host "Telegram notification failed: $_" }
  }

  # ntfy.sh (optional alternative) — needs NTFY_TOPIC
  $topic = $env:NTFY_TOPIC
  if ($topic) {
    try {
      Invoke-RestMethod -Uri "https://ntfy.sh/$topic" -Method Post -Body $msg -Headers @{ Title = "New apprenticeship(s) found"; Tags = "mortar_board" } | Out-Null
      Write-Host "Sent ntfy notification to topic '$topic'."; $sent = $true
    } catch { Write-Host "ntfy notification failed: $_" }
  }

  if (-not $sent) { Write-Host "New roles found but no notifier configured (set TELEGRAM_BOT_TOKEN+TELEGRAM_CHAT_ID, or NTFY_TOPIC)." }
} else {
  Write-Host "No new roles this run; no notification sent."
}
