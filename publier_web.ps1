# Publication des plans sur GitHub Pages.
# Premiere fois : cree le depot, pousse, allume Pages.
# Les fois suivantes : envoie seulement les plans modifies. MEME ADRESSE.
param(
  [string]$Compte = "francoisarnaudon",
  [string]$Depot  = "plans-serene-exe-2027",
  [string]$Nom    = "",
  [string]$Email  = "",
  [switch]$Public,
  [switch]$Prive
)

# SURTOUT PAS "Stop" ici. Le .bat lance `powershell` = Windows PowerShell 5.1,
# ou le moindre message d'un exe sur la sortie d'erreur (gh qui dit "vous
# n'etes pas connecte") devient une erreur TERMINANTE : le script mourait
# instantanement et la fenetre se refermait sans rien afficher.
# Tout le controle passe de toute facon par $LASTEXITCODE et des Echec
# explicites, verifies un par un.
$ErrorActionPreference = "Continue"
$PSNativeCommandUseErrorActionPreference = $false

# Filet de securite : plus jamais de fermeture muette.
trap {
  Write-Host ""
  Write-Host "Erreur inattendue :" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
  Write-Host ""
  Read-Host "Entree pour fermer"
  exit 1
}
# On se recale TOUJOURS sur le dossier du script : c'est la protection contre
# le piege classique (un terminal ouvert ailleurs, et git init part sur C:).
Set-Location -LiteralPath $PSScriptRoot
Write-Host ""
Write-Host "Dossier publie : $PSScriptRoot" -ForegroundColor Cyan

function Echec($m) { Write-Host ""; Write-Host $m -ForegroundColor Red; Read-Host "Entree pour fermer"; exit 1 }
function Etape($m) { Write-Host ""; Write-Host "-> $m" -ForegroundColor Yellow }

# --- 1. git ---------------------------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Echec "Git n'est pas installe. Installez-le depuis https://git-scm.com puis relancez."
}

# --- 2. GitHub CLI --------------------------------------------------------
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  # L'explorateur Windows transmet l'environnement de l'ouverture de session :
  # gh peut etre installe et pourtant invisible ici. On relit le PATH reel
  # AVANT de conclure qu'il manque, sinon on relance winget a chaque fois.
  $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path","User")
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Etape "Installation de l'outil GitHub (une seule fois)..."
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Echec "winget est introuvable. Installez GitHub CLI depuis https://cli.github.com puis relancez."
  }
  # --source winget explicitement : la source Microsoft Store peut etre
  # inaccessible (certificat refuse) et ferait echouer une installation
  # pourtant possible
  winget install --id GitHub.cli --source winget --silent --accept-source-agreements --accept-package-agreements
  $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path","User")
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "L'outil GitHub n'est pas encore utilisable." -ForegroundColor Red
    Write-Host "1) Le plus souvent il est installe mais pas encore visible :"
    Write-Host "   FERMEZ cette fenetre, rouvrez-la, relancez publier.bat."
    Write-Host "2) Si le probleme persiste, installez-le a la main depuis"
    Write-Host "   https://cli.github.com  puis relancez publier.bat."
    Echec "Arret ici."
  }
}

# --- 3. connexion GitHub --------------------------------------------------
gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
  Etape "Connexion a GitHub (votre navigateur va s'ouvrir)..."
  gh auth login --hostname github.com --git-protocol https --web
  if ($LASTEXITCODE -ne 0) { Echec "Connexion a GitHub abandonnee." }
}

# --- 4. identite git ------------------------------------------------------
if (-not (Test-Path ".git")) {
  Etape "Preparation du dossier..."
  git init -b main *> $null
  if ($LASTEXITCODE -ne 0) { git init *> $null; git checkout -b main *> $null }
}
if (-not (git config user.name))  {
  if (-not $Nom)   { $Nom   = Read-Host "Votre nom (pour l'historique des versions)" }
  git config user.name $Nom
}
if (-not (git config user.email)) {
  if (-not $Email) { $Email = Read-Host "Votre e-mail" }
  git config user.email $Email
}

# GitHub Pages ignore les dossiers commencant par _ sans ce fichier temoin
if (-not (Test-Path ".nojekyll")) { New-Item -ItemType File ".nojekyll" | Out-Null }

# --- 5. taille ------------------------------------------------------------
$Mo = [math]::Round(((Get-ChildItem -Recurse -File -Force |
        Where-Object { $_.FullName.Split([IO.Path]::DirectorySeparatorChar) -notcontains '.git' } |
        Measure-Object -Property Length -Sum).Sum / 1MB), 1)
Write-Host "Poids des plans : $Mo Mo"
if ($Mo -gt 900) {
  Write-Host "ATTENTION : au-dela de 1 Go, GitHub refuse le depot." -ForegroundColor Red
  Write-Host "Republiez moins de feuilles, ou cochez 'Repartir de zero' dans l'outil." -ForegroundColor Red
}

# --- 6. enregistrement ----------------------------------------------------
Etape "Enregistrement des plans..."
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
  Write-Host "   (aucun changement depuis la derniere publication)"
} else {
  git commit -m ("plans du " + (Get-Date -Format "dd/MM/yyyy HH:mm")) *> $null
}

# --- 7. depot distant -----------------------------------------------------
git remote get-url origin *> $null
$origine = $(if ($LASTEXITCODE -eq 0) { (git remote get-url origin 2>&1 | Select-Object -First 1) } else { "" })
if (-not $origine) {
  # PUBLIC par defaut. Attention : ce n'est pas qu'une question de prix.
  # Une page GitHub Pages est publique MEME depuis un depot prive (le
  # controle d'acces est reserve a GitHub Enterprise Cloud) ; sur un compte
  # gratuit, -Prive empeche simplement la page d'exister.
  $vis = $(if ($Prive) { "--private" } else { "--public" })
  # garde.js porte un sel quand les plans sont chiffres : l'avertissement
  # n'a alors pas lieu d'etre le meme.
  $chiffre = $false
  if (Test-Path "garde.js") { $chiffre = ((Get-Content "garde.js" -Raw) -match '"sel"') }
  if (-not $Prive) {
    Write-Host ""
    if ($chiffre) {
      Write-Host "PUBLICATION PUBLIQUE - PLANS CHIFFRES" -ForegroundColor Green
      Write-Host "Le depot sera public, mais les plans sont chiffres : seul le"
      Write-Host "mot de passe permet de les lire. Transmettez-le a votre"
      Write-Host "collaborateur par un AUTRE canal que le lien."
    } else {
      Write-Host "PUBLICATION PUBLIQUE - PLANS EN CLAIR" -ForegroundColor Yellow
      Write-Host "Ces plans seront lisibles par tous : le depot apparaitra sur" -ForegroundColor Yellow
      Write-Host "votre profil GitHub, la page pourra etre trouvee par Google," -ForegroundColor Yellow
      Write-Host "et toute copie faite par un tiers sera definitive." -ForegroundColor Yellow
      Write-Host ""
      Write-Host "Pour les proteger : relancez Visionneuse web dans Revit en"
      Write-Host "cochant "Proteger les plans par un mot de passe"."
      Write-Host ""
      $ok = Read-Host "Tapez PUBLIER pour continuer, autre chose pour annuler"
      if ($ok -ne "PUBLIER") { Echec "Publication annulee. Rien n'a ete mis en ligne." }
    }
    Write-Host ""
  }
  Etape "Creation du depot $Compte/$Depot ($($vis.Trim('-')))..."
  gh repo create "$Compte/$Depot" $vis --source . --remote origin --push
  if ($LASTEXITCODE -ne 0) { Echec "Le depot n'a pas pu etre cree (nom deja pris ?)." }
} else {
  Etape "Envoi vers $origine ..."
  git push -u origin main
  if ($LASTEXITCODE -ne 0) { Echec "L'envoi a echoue - lisez le message ci-dessus." }
}

# --- 8. GitHub Pages ------------------------------------------------------
Etape "Activation de la page web..."
gh api "repos/$Compte/$Depot/pages" *> $null
if ($LASTEXITCODE -ne 0) {
  gh api -X POST "repos/$Compte/$Depot/pages" -f "source[branch]=main" -f "source[path]=/" *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Pages n'a pas pu etre active automatiquement." -ForegroundColor Red
    Write-Host "Cause la plus frequente : le depot est PRIVE et le compte n'est pas GitHub Pro."
    Write-Host "Allez sur https://github.com/$Compte/$Depot/settings/pages"
    Write-Host "et choisissez la branche main, dossier / (root)."
  }
}

$url = "https://$Compte.github.io/$Depot/"
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Publie. Le lien a envoyer (il ne changera plus jamais) :" -ForegroundColor Green
Write-Host "   $url" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " La toute premiere publication peut demander 1 a 2 minutes."
Set-Clipboard -Value $url -ErrorAction SilentlyContinue
Write-Host " (le lien est copie dans le presse-papier)"
Read-Host "Entree pour fermer"
