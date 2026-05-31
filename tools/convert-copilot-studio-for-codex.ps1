param(
  [string]$PluginRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$MarketplacePath = "",
  [switch]$WriteMarketplace
)

$ErrorActionPreference = "Stop"

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText((Resolve-Path -LiteralPath (Split-Path -Parent $Path)).Path + [System.IO.Path]::DirectorySeparatorChar + (Split-Path -Leaf $Path), $Content, $encoding)
}

function Get-SkillDescription([string]$Frontmatter, [string]$SkillName) {
  $frontLines = $Frontmatter -split "\r?\n"
  for ($i = 0; $i -lt $frontLines.Count; $i++) {
    if ($frontLines[$i] -match "^description:\s*>\s*$") {
      $collected = New-Object System.Collections.Generic.List[string]
      for ($j = $i + 1; $j -lt $frontLines.Count; $j++) {
        $line = $frontLines[$j]
        if ($line -match "^[ \t]+") {
          $trimmed = $line.Trim()
          if ($trimmed.Length -gt 0) { $collected.Add($trimmed) }
        } elseif ($line.Trim().Length -eq 0) {
          continue
        } else {
          break
        }
      }
      $description = ($collected -join " ").Trim()
      if ($description.Length -gt 0) { return $description }
    }
  }

  $single = [regex]::Match($Frontmatter, "(?m)^description:\s*(.+?)\s*$")
  if ($single.Success) {
    $description = $single.Groups[1].Value.Trim()
    if (($description.StartsWith('"') -and $description.EndsWith('"')) -or
        ($description.StartsWith("'") -and $description.EndsWith("'"))) {
      $description = $description.Substring(1, $description.Length - 2)
    }
    if ($description.Length -gt 0) { return $description }
  }

  return "Work with Microsoft Copilot Studio agent YAML for $SkillName tasks."
}

function Wrap-Description([string]$Description) {
  $words = $Description -replace "\s+", " " -split " "
  $lines = New-Object System.Collections.Generic.List[string]
  $current = ""
  foreach ($word in $words) {
    if ($current.Length -eq 0) {
      $current = $word
    } elseif (($current.Length + 1 + $word.Length) -le 96) {
      $current = "$current $word"
    } else {
      $lines.Add("  $current")
      $current = $word
    }
  }
  if ($current.Length -gt 0) { $lines.Add("  $current") }
  return ($lines -join [Environment]::NewLine)
}

function Convert-DescriptionText([string]$Description) {
  $converted = $Description.Replace("/copilot-studio:", "copilot-studio ")
  $converted = $converted.Replace("/add-generative-answers", "add-generative-answers")
  $converted = $converted.Replace("/add-node", "add-node")
  return $converted
}

function Convert-BodyText([string]$Body) {
  $converted = $Body.Replace('${CLAUDE_SKILL_DIR}/../../', '../../')
  $converted = $converted.Replace('${CLAUDE_SKILL_DIR}', '.')
  $converted = $converted.Replace('CLAUDE_SKILL_DIR', 'the current skill directory')
  return $converted
}

function Test-CodexSkillFrontmatter([string]$Path) {
  $raw = Get-Content -LiteralPath $Path -Raw
  $match = [regex]::Match($raw, "(?ms)^---\s*\r?\n(.*?)^---\s*\r?\n?")
  if (-not $match.Success) { throw "Missing YAML frontmatter in $Path" }
  if ($match.Groups[1].Value -notmatch "(?m)^name:\s*[a-z0-9-]+\s*$") { throw "Missing Codex skill name in $Path" }
  if ($match.Groups[1].Value -notmatch "(?m)^description:\s*") { throw "Missing Codex skill description in $Path" }
}

$PluginRoot = (Resolve-Path -LiteralPath $PluginRoot).Path
$claudeManifestPath = Join-Path $PluginRoot ".claude-plugin/plugin.json"
if (-not (Test-Path -LiteralPath $claudeManifestPath)) {
  throw "Missing upstream .claude-plugin/plugin.json at $claudeManifestPath"
}

$claudeManifest = Get-Content -LiteralPath $claudeManifestPath -Raw | ConvertFrom-Json
$codexPluginDir = Join-Path $PluginRoot ".codex-plugin"
New-Item -ItemType Directory -Force -Path $codexPluginDir | Out-Null

$pluginManifest = [ordered]@{
  name = $claudeManifest.name
  version = $claudeManifest.version
  description = $claudeManifest.description
  author = $claudeManifest.author
  repository = "https://github.com/tobony/skills-for-copilot-studio-in-codex"
  homepage = "https://github.com/microsoft/skills-for-copilot-studio"
  license = "MIT"
  keywords = @("copilot-studio", "microsoft", "yaml", "agent-authoring", "power-platform", "codex")
  skills = "./skills/"
  interface = [ordered]@{
    displayName = "Copilot Studio"
    shortDescription = "Build and validate Copilot Studio YAML agents."
    longDescription = "Codex-compatible conversion of Microsoft's Skills for Copilot Studio plugin for creating, editing, validating, testing, and troubleshooting Copilot Studio YAML agents."
    developerName = "Microsoft Copilot Studio CAT Team"
    category = "Productivity"
    capabilities = @("Interactive", "Write")
    websiteURL = "https://github.com/tobony/skills-for-copilot-studio-in-codex"
    defaultPrompt = @(
      "Review my Copilot Studio agent YAML.",
      "Create a Copilot Studio topic.",
      "Validate this Copilot Studio workspace."
    )
  }
}

$pluginJsonPath = Join-Path $codexPluginDir "plugin.json"
Write-Utf8NoBom $pluginJsonPath ($pluginManifest | ConvertTo-Json -Depth 10)

$skillFiles = Get-ChildItem -LiteralPath (Join-Path $PluginRoot "skills") -Filter "SKILL.md" -Recurse
foreach ($file in $skillFiles) {
  $raw = Get-Content -LiteralPath $file.FullName -Raw
  $match = [regex]::Match($raw, "(?ms)^---\s*\r?\n(.*?)^---\s*\r?\n?(.*)$")
  if (-not $match.Success) {
    throw "Missing YAML frontmatter in $($file.FullName)"
  }

  $skillName = Split-Path -Leaf $file.DirectoryName
  $description = Convert-DescriptionText (Get-SkillDescription $match.Groups[1].Value $skillName)
  $body = Convert-BodyText $match.Groups[2].Value
  $frontmatter = @(
    "---"
    "name: $skillName"
    "description: >"
    (Wrap-Description $description)
    "---"
    ""
  ) -join [Environment]::NewLine

  Write-Utf8NoBom $file.FullName ($frontmatter + $body)
  Test-CodexSkillFrontmatter $file.FullName
}

if ($WriteMarketplace) {
  if (-not $MarketplacePath) {
    $MarketplacePath = Join-Path $HOME ".agents/plugins/marketplace.json"
  }

  $marketplaceDir = Split-Path -Parent $MarketplacePath
  New-Item -ItemType Directory -Force -Path $marketplaceDir | Out-Null
  if (Test-Path -LiteralPath $MarketplacePath) {
    $marketplace = Get-Content -LiteralPath $MarketplacePath -Raw | ConvertFrom-Json
    if (-not $marketplace.plugins) {
      $marketplace | Add-Member -MemberType NoteProperty -Name plugins -Value @()
    }
  } else {
    $marketplace = [pscustomobject]@{
      name = "personal"
      interface = [pscustomobject]@{ displayName = "Personal" }
      plugins = @()
    }
  }

  $entry = [pscustomobject]@{
    name = "copilot-studio"
    source = [pscustomobject]@{ source = "local"; path = "./plugins/copilot-studio" }
    policy = [pscustomobject]@{ installation = "AVAILABLE"; authentication = "ON_INSTALL" }
    category = "Productivity"
  }
  $marketplace.plugins = @($marketplace.plugins | Where-Object { $_.name -ne "copilot-studio" }) + @($entry)
  Write-Utf8NoBom $MarketplacePath ($marketplace | ConvertTo-Json -Depth 10)
  Write-Output "Updated marketplace: $MarketplacePath"
}

Write-Output "Converted $($skillFiles.Count) skills"
Write-Output "Wrote $pluginJsonPath"
