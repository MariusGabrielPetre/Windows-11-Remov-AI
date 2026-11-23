<#
.SYNOPSIS
    Win11 Lite - eliminare completa a functiilor AI din Windows 11 + optimizare pentru PC-uri slabe.
    Interfata grafica (WPF). Ruleaza in Windows PowerShell 5.1 ca Administrator.

.DESCRIPTION
    Eliminare AI : Copilot, Microsoft 365 Copilot, Recall, Click to Do, agentul din Setari, functiile
                   agentice, AI in Edge / Paint / Notepad / Office / Cautare, accesul aplicatiilor la
                   AI generativ, serviciile si pachetele AI de sistem (AIX, CoreAI, WindowsWorkload).
    Protectie    : politici de sistem + marcare "Deprovisioned" + task programat (SYSTEM) care reaplica
                   eliminarea la pornire, la autentificare si zilnic, ca AI-ul sa nu revina prin update-uri.
    Optimizare   : plan de alimentare, efecte vizuale, servicii, telemetrie, reclame, aplicatii
                   preinstalate, aplicatii de fundal, curatare disc etc.

.NOTES
    Pornire (PowerShell deschis ca Administrator):
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
        & "C:\Calea\Catre\Win11Lite.ps1"

    Parametrul -Reapply este folosit doar de task-ul programat de protectie (ruleaza fara interfata).
    Inainte de modificari se creeaza un punct de restaurare (bifat implicit).
    Jurnale: C:\ProgramData\Win11Lite\Logs
#>
[CmdletBinding()]
param(
    [switch]$Reapply
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ============================================================================
#  Verificari de pornire: Windows PowerShell 5.1, Administrator, STA
# ============================================================================
$winPS = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Restart-InWindowsPowerShell {
    if (-not $PSCommandPath) {
        Write-Host 'Salveaza scriptul ca fisier .ps1 si ruleaza-l din Windows PowerShell deschis ca Administrator.' -ForegroundColor Yellow
        return
    }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"{0}"' -f $PSCommandPath))
    if ($Reapply) { $argList += '-Reapply' }
    Start-Process -FilePath $winPS -ArgumentList $argList -Verb RunAs
}

if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Host 'PowerShell 7 detectat - relansez in Windows PowerShell 5.1...' -ForegroundColor Yellow
    Restart-InWindowsPowerShell
    return
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Sunt necesare drepturi de Administrator - cer elevare...' -ForegroundColor Yellow
    Restart-InWindowsPowerShell
    return
}

if (-not $Reapply -and [System.Threading.Thread]::CurrentThread.ApartmentState -ne [System.Threading.ApartmentState]::STA) {
    Restart-InWindowsPowerShell
    return
}

# ============================================================================
#  NUCLEU - functii folosite atat de interfata (in fundal) cat si de task-ul de protectie
# ============================================================================
$CoreCode = @'
$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

$global:W11Version     = '1.0.0'
$global:W11Root        = Join-Path $env:ProgramData 'Win11Lite'
$global:W11LogDir      = Join-Path $global:W11Root 'Logs'
$global:W11TaskName    = 'Win11Lite-ProtectieAI'
$global:W11TaskPath    = '\Win11Lite\'
$global:W11DefaultHive = 'W11L_DEFAULT'
$global:W11Roots       = @('HKCU:')
$global:W11WarnCount   = 0

# ---------------------------------------------------------------- pachete
$global:W11Pkgs = @{
    AiStandard = @(
        'Microsoft.Copilot*',
        'Microsoft.MicrosoftOfficeHub',
        'MicrosoftWindows.Client.CoPilot',
        'Microsoft.Windows.Ai.Copilot.Provider',
        'Microsoft.Edge.GameAssist',
        'Microsoft.WritingAssistant',
        'Microsoft.Office.ActionsServer',
        'aimgr',
        'Microsoft.BingSearch'
    )
    AiSystem = @(
        'MicrosoftWindows.Client.AIX',
        'MicrosoftWindows.Client.CoreAI',
        'WindowsWorkload.*'
    )
    Gaming  = @('Microsoft.XboxGamingOverlay', 'Microsoft.Edge.GameAssist')
    Widgets = @('MicrosoftWindows.Client.WebExperience')
    Xbox    = @(
        'Microsoft.XboxApp', 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay',
        'Microsoft.XboxGamingOverlay', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.Xbox.TCUI'
    )
    Bloat = @(
        'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingFinance', 'Microsoft.BingSports',
        'Microsoft.BingTravel', 'Microsoft.BingFoodAndDrink', 'Microsoft.BingHealthAndFitness',
        'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.GetHelp', 'Microsoft.Getstarted',
        'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps', 'Microsoft.People', 'Microsoft.Todos',
        'Microsoft.PowerAutomateDesktop', 'Clipchamp.Clipchamp', 'MicrosoftCorporationII.MicrosoftFamily',
        'Microsoft.ZuneVideo', 'MicrosoftTeams', 'MSTeams', 'Microsoft.OutlookForWindows',
        'Microsoft.windowscommunicationsapps', 'Microsoft.Windows.DevHome', 'Microsoft.549981C3F5F10',
        'Microsoft.MixedReality.Portal', 'Microsoft.SkypeApp', 'Microsoft.YourPhone',
        'Microsoft.Microsoft3DViewer', 'Microsoft.Office.OneNote', 'Microsoft.MicrosoftPCManager',
        'Microsoft.Wallet', 'Microsoft.Messaging', 'Microsoft.OneConnect', 'Microsoft.Print3D',
        '*CandyCrush*', '*BubbleWitch*', '*Spotify*', '*Disney*', '*TikTok*', '*Instagram*',
        '*Facebook*', '*Netflix*', '*PrimeVideo*', '*LinkedIn*', '*Twitter*', '*king.com*'
    )
}

$global:W11TelemetryTasks = @(
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp',
    '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
    '\Microsoft\Windows\Application Experience\MareBackup',
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
    '\Microsoft\Windows\Feedback\Siuf\DmClient',
    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
    '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
    '\Microsoft\Windows\Maps\MapsUpdateTask',
    '\Microsoft\Windows\Maps\MapsToastTask'
)

# ---------------------------------------------------------------- optiuni (interfata + protectie)
# Level: rec = Recomandat (sigur), max = Maxim (compromisuri explicate), manual = doar la cerere
# Reapply: optiunea este reaplicata automat de task-ul de protectie
$global:W11Items = @(
    # ---------------- ELIMINARE AI
    [pscustomobject]@{ Id = 'ai_copilot_apps'; Tab = 'AI'; Group = 'Copilot'; Level = 'rec'; Reapply = $true
        Title = 'Dezinstaleaza Copilot si Microsoft 365 Copilot'
        Desc  = 'Elimina pentru toti utilizatorii aplicatiile Copilot, Microsoft 365 Copilot (fostul Office Hub), Copilot Provider, Edge Game Assist, Writing Assistant si Office Actions Server, apoi le marcheaza "Deprovisioned" ca Windows Update sa nu le reinstaleze.' }
    [pscustomobject]@{ Id = 'ai_copilot_policies'; Tab = 'AI'; Group = 'Copilot'; Level = 'rec'; Reapply = $true
        Title = 'Dezactiveaza Copilot in tot sistemul'
        Desc  = 'Politicile TurnOffWindowsCopilot si RemoveMicrosoftCopilotApp, ascunde butonul si companionul Copilot din taskbar, scoate "Ask Copilot" din meniul click-dreapta, opreste activarea vocala ("Hey Copilot") si deschiderea automata.' }
    [pscustomobject]@{ Id = 'ai_edge'; Tab = 'AI'; Group = 'Copilot'; Level = 'rec'; Reapply = $true
        Title = 'Elimina Copilot si functiile AI din Microsoft Edge'
        Desc  = 'Bara laterala si butonul Copilot, accesul Copilot la paginile deschise, scrierea asistata, cautarea AI in istoric, temele generate cu AI, modelul AI local si API-urile AI incorporate. Edge va afisa "Gestionat de organizatie" - este normal.' }
    [pscustomobject]@{ Id = 'ai_search'; Tab = 'AI'; Group = 'Copilot'; Level = 'rec'; Reapply = $true
        Title = 'Scoate Copilot, Bing si continutul web din Cautare'
        Desc  = 'Cautarea din Start si taskbar devine strict locala: fara rezultate Bing, fara sugestii web, fara "search highlights" si fara Copilot in panoul de cautare.' }

    [pscustomobject]@{ Id = 'ai_recall'; Tab = 'AI'; Group = 'Recall, Click to Do si agenti AI'; Level = 'rec'; Reapply = $true
        Title = 'Elimina Recall (instantanee ale ecranului)'
        Desc  = 'Dezactiveaza Recall prin politici, sterge componenta optionala Recall impreuna cu fisierele ei si opreste task-urile programate WindowsAI.' }
    [pscustomobject]@{ Id = 'ai_clicktodo'; Tab = 'AI'; Group = 'Recall, Click to Do si agenti AI'; Level = 'rec'; Reapply = $true
        Title = 'Dezactiveaza Click to Do, agentul din Setari si functiile agentice'
        Desc  = 'Opreste Click to Do (Win + clic / Win + Q), agentul AI din aplicatia Setari, spatiile de lucru pentru agenti AI (agent workspace) si conectorii de agenti (MCP).' }
    [pscustomobject]@{ Id = 'ai_genai'; Tab = 'AI'; Group = 'Recall, Click to Do si agenti AI'; Level = 'rec'; Reapply = $true
        Title = 'Blocheaza accesul aplicatiilor la AI generativ'
        Desc  = 'Permisiunile "Generare text si imagini" si "Modele AI de sistem" devin Refuzat pentru toti utilizatorii - nicio aplicatie nu mai poate folosi AI-ul local al Windows.' }

    [pscustomobject]@{ Id = 'ai_apps'; Tab = 'AI'; Group = 'AI in aplicatii si servicii'; Level = 'rec'; Reapply = $true
        Title = 'Dezactiveaza AI in Paint, Notepad si Office'
        Desc  = 'Paint: Cocreator, Image Creator, umplere si stergere generativa, eliminare fundal. Notepad: Copilot, Rewrite, Summarize. Office / Microsoft 365: Copilot in Word, Excel, PowerPoint, OneNote si analiza continutului tau.' }
    [pscustomobject]@{ Id = 'ai_input'; Tab = 'AI'; Group = 'AI in aplicatii si servicii'; Level = 'rec'; Reapply = $true
        Title = 'Opreste colectarea datelor de tastare si scris pentru AI'
        Desc  = 'Dezactiveaza "typing insights", personalizarea scrisului de mana si a tastarii si colectarea implicita de text si cerneala folosite pentru modelele Microsoft.' }
    [pscustomobject]@{ Id = 'ai_services'; Tab = 'AI'; Group = 'AI in aplicatii si servicii'; Level = 'rec'; Reapply = $true
        Title = 'Opreste serviciile AI de fundal'
        Desc  = 'Dezactiveaza serviciul Windows AI Fabric (WSAIFabricSvc) si Agent Activation Runtime (AarSvc), folosite de functiile AI si de asistentii vocali.' }
    [pscustomobject]@{ Id = 'ai_gaming'; Tab = 'AI'; Group = 'AI in aplicatii si servicii'; Level = 'max'; Reapply = $true
        Title = 'Elimina Gaming Copilot (Xbox Game Bar)'
        Desc  = 'Dezinstaleaza Xbox Game Bar, care contine Gaming Copilot, si opreste inregistrarea jocurilor in fundal. Pierzi suprapunerea Win + G (FPS, capturi video).' }

    [pscustomobject]@{ Id = 'ai_system'; Tab = 'AI'; Group = 'Componente AI de sistem'; Level = 'max'; Reapply = $true
        Title = 'Eliminare fortata a componentelor AI de sistem (avansat)'
        Desc  = 'Sterge pachetele AI marcate de Windows ca nedezinstalabile: AI Actions (AIX), CoreAI si modelele WindowsWorkload (cautare semantica, OCR si descrieri de imagini pe PC-urile Copilot+). Ascunde pagina "Componente AI" din Setari. Revenire doar prin Restaurare sistem sau reparare Windows.' }

    [pscustomobject]@{ Id = 'guard_task'; Tab = 'AI'; Group = 'Protectie impotriva revenirii prin update-uri'; Level = 'rec'; Reapply = $false
        Title = 'Instaleaza protectia automata (reaplica dupa update-uri)'
        Desc  = 'Copiaza scriptul in C:\ProgramData\Win11Lite si creeaza un task programat (cont SYSTEM) care reaplica eliminarea AI la pornire, la autentificare si zilnic. Prinde Copilot reinstalat de Windows Update sau de Store.' }
    [pscustomobject]@{ Id = 'guard_cfr'; Tab = 'AI'; Group = 'Protectie impotriva revenirii prin update-uri'; Level = 'rec'; Reapply = $true
        Title = 'Opreste livrarea timpurie de functii noi'
        Desc  = 'Dezactiveaza "Primeste cele mai noi actualizari imediat ce sunt disponibile" si activarea functiilor noi aduse de update-urile lunare. Actualizarile de securitate continua normal.' }
    [pscustomobject]@{ Id = 'guard_silent'; Tab = 'AI'; Group = 'Protectie impotriva revenirii prin update-uri'; Level = 'rec'; Reapply = $true
        Title = 'Blocheaza instalarea silentioasa de aplicatii promovate'
        Desc  = 'Windows nu mai instaleaza singur aplicatii sugerate sau sponsorizate si nu mai readuce aplicatiile eliminate prin "experientele pentru consumatori".' }
    [pscustomobject]@{ Id = 'guard_store'; Tab = 'AI'; Group = 'Protectie impotriva revenirii prin update-uri'; Level = 'manual'; Reapply = $true
        Title = 'Opreste actualizarea automata din Microsoft Store'
        Desc  = 'Store-ul nu mai poate readuce sau actualiza singur aplicatii AI. Dezavantaj: nici celelalte aplicatii din Store (Calculator, Fotografii etc.) nu se mai actualizeaza automat - le actualizezi manual din Store.' }

    # ---------------- OPTIMIZARE
    [pscustomobject]@{ Id = 'perf_power'; Tab = 'PERF'; Group = 'Sistem si alimentare'; Level = 'rec'; Reapply = $false
        Title = 'Plan de alimentare de performanta maxima'
        Desc  = 'Activeaza un plan "Ultimate Performance" (desktop) sau "High Performance" (laptop) si dezactiveaza limitarea procesorului (power throttling). Pe laptop creste consumul de baterie.' }
    [pscustomobject]@{ Id = 'perf_visual'; Tab = 'PERF'; Group = 'Sistem si alimentare'; Level = 'rec'; Reapply = $false
        Title = 'Efecte vizuale minime'
        Desc  = 'Fara animatii, transparenta, umbre si Aero Peek; meniuri mai rapide. Se pastreaza fonturile netezite si miniaturile imaginilor. Elibereaza placa video si procesorul.' }
    [pscustomobject]@{ Id = 'perf_startup'; Tab = 'PERF'; Group = 'Sistem si alimentare'; Level = 'rec'; Reapply = $false
        Title = 'Pornire mai rapida'
        Desc  = 'Elimina intarzierea artificiala a aplicatiilor de pornire si opreste Edge sa ruleze in fundal sau sa se preincarce la pornire (Startup Boost).' }
    [pscustomobject]@{ Id = 'perf_background'; Tab = 'PERF'; Group = 'Sistem si alimentare'; Level = 'rec'; Reapply = $false
        Title = 'Blocheaza aplicatiile din fundal'
        Desc  = 'Aplicatiile din Store nu mai ruleaza in fundal dupa ce le inchizi. Economiseste RAM si procesor. Unele aplicatii (ex. Phone Link) nu mai trimit notificari cand sunt inchise.' }
    [pscustomobject]@{ Id = 'perf_gamedvr'; Tab = 'PERF'; Group = 'Sistem si alimentare'; Level = 'rec'; Reapply = $false
        Title = 'Opreste inregistrarea jocurilor in fundal (Game DVR)'
        Desc  = 'Dezactiveaza captura video permanenta din jocuri si pastreaza Modul Joc activ.' }
    [pscustomobject]@{ Id = 'perf_hibernate'; Tab = 'PERF'; Group = 'Sistem si alimentare'; Level = 'max'; Reapply = $false
        Title = 'Dezactiveaza hibernarea si Fast Startup'
        Desc  = 'Sterge hiberfil.sys (elibereaza cativa GB, aprox. 40% din RAM) si evita problemele cauzate de Fast Startup. Pe laptop dispare optiunea "Hibernare".' }
    [pscustomobject]@{ Id = 'perf_svchost'; Tab = 'PERF'; Group = 'Sistem si alimentare'; Level = 'max'; Reapply = $false
        Title = 'Grupeaza procesele svchost'
        Desc  = 'Seteaza SvcHostSplitThresholdInKB la cantitatea de RAM, astfel incat serviciile sa fie grupate in mai putine procese. Mai putine procese si putin mai putina memorie folosita.' }

    [pscustomobject]@{ Id = 'perf_services'; Tab = 'PERF'; Group = 'Servicii'; Level = 'rec'; Reapply = $false
        Title = 'Dezactiveaza servicii inutile'
        Desc  = 'Dezactivate: Fax, Demo magazin, Harti descarcate, Registru la distanta, Media Player Network Sharing. Pornire manuala: raportare erori, asistent compatibilitate, urmarire legaturi, control parental, telefonie.' }
    [pscustomobject]@{ Id = 'perf_sysmain'; Tab = 'PERF'; Group = 'Servicii'; Level = 'max'; Reapply = $false
        Title = 'Dezactiveaza SysMain (Superfetch)'
        Desc  = 'Recomandat pe HDD cu discul des la 100% sau pe PC cu putina RAM. Pe SSD efectul este mic.' }
    [pscustomobject]@{ Id = 'perf_wsearch'; Tab = 'PERF'; Group = 'Servicii'; Level = 'max'; Reapply = $false
        Title = 'Dezactiveaza indexarea Windows Search'
        Desc  = 'Opreste indexarea continua a fisierelor (procesor si disc). Cautarea fisierelor din Start si Explorer devine mai lenta, iar cautarea din Outlook clasic nu mai functioneaza.' }
    [pscustomobject]@{ Id = 'perf_spooler'; Tab = 'PERF'; Group = 'Servicii'; Level = 'manual'; Reapply = $false
        Title = 'Dezactiveaza serviciul de imprimare (Print Spooler)'
        Desc  = 'Doar daca NU folosesti imprimanta sau "Print to PDF". Elibereaza memorie si inchide o cale de atac cunoscuta.' }

    [pscustomobject]@{ Id = 'perf_telemetry'; Tab = 'PERF'; Group = 'Confidentialitate si procese de fundal'; Level = 'rec'; Reapply = $false
        Title = 'Reduce telemetria si colectarea de date'
        Desc  = 'Telemetrie la minimul permis, serviciile DiagTrack si dmwappushservice oprite, task-urile de colectare (CEIP, Compatibility Appraiser, Feedback, Harti) dezactivate, raportarea erorilor, ID-ul de publicitate si istoricul activitatilor oprite.' }
    [pscustomobject]@{ Id = 'perf_ads'; Tab = 'PERF'; Group = 'Confidentialitate si procese de fundal'; Level = 'rec'; Reapply = $false
        Title = 'Elimina reclamele, sugestiile si sfaturile'
        Desc  = 'Fara recomandari si reclame in Start, Setari, ecranul de blocare si Explorer, fara "Termina configurarea dispozitivului", fara Spotlight pe desktop.' }
    [pscustomobject]@{ Id = 'perf_widgets'; Tab = 'PERF'; Group = 'Confidentialitate si procese de fundal'; Level = 'rec'; Reapply = $false
        Title = 'Elimina Widgets si stirile'
        Desc  = 'Dezactiveaza panoul Widgets / MSN prin politica si dezinstaleaza Windows Web Experience Pack, care ruleaza permanent in fundal. Ascunde si iconita Chat.' }
    [pscustomobject]@{ Id = 'perf_delivery'; Tab = 'PERF'; Group = 'Confidentialitate si procese de fundal'; Level = 'rec'; Reapply = $false
        Title = 'Opreste partajarea update-urilor P2P'
        Desc  = 'Delivery Optimization nu mai trimite bucati de update-uri catre alte PC-uri. Economiseste internet si disc.' }

    [pscustomobject]@{ Id = 'perf_bloat'; Tab = 'PERF'; Group = 'Aplicatii'; Level = 'rec'; Reapply = $false
        Title = 'Dezinstaleaza aplicatiile preinstalate inutile'
        Desc  = 'Stiri, Vreme, Solitaire, Clipchamp, Sfaturi, Feedback Hub, Harti, Teams personal, Outlook (nou), To Do, Family, Power Automate, Phone Link, Dev Home si aplicatiile promovate (Spotify, TikTok, Candy Crush etc.). Raman: Store, Calculator, Fotografii, Notepad, Paint, Terminal, Snipping Tool, Ceas, Camera, Media Player.' }
    [pscustomobject]@{ Id = 'perf_xbox'; Tab = 'PERF'; Group = 'Aplicatii'; Level = 'manual'; Reapply = $false
        Title = 'Dezinstaleaza aplicatiile Xbox'
        Desc  = 'Xbox, Game Bar, Xbox TCUI si Speech-to-text overlay. NU bifa daca joci jocuri din Microsoft Store sau Game Pass.' }
    [pscustomobject]@{ Id = 'perf_onedrive'; Tab = 'PERF'; Group = 'Aplicatii'; Level = 'manual'; Reapply = $false
        Title = 'Dezinstaleaza OneDrive'
        Desc  = 'Opreste sincronizarea si dezinstaleaza OneDrive (si pentru conturile noi). Fisierele deja descarcate raman pe disc; verifica inainte sa nu ai fisiere doar in cloud de care ai nevoie offline.' }
    [pscustomobject]@{ Id = 'perf_classicmenu'; Tab = 'PERF'; Group = 'Aplicatii'; Level = 'manual'; Reapply = $false
        Title = 'Meniu click-dreapta clasic'
        Desc  = 'Readuce meniul contextual complet din Windows 10 (fara "Afiseaza mai multe optiuni"), care se deschide mai repede.' }

    [pscustomobject]@{ Id = 'perf_cleanup'; Tab = 'PERF'; Group = 'Curatare'; Level = 'rec'; Reapply = $false
        Title = 'Curata fisierele temporare'
        Desc  = 'Sterge fisierele temporare ale sistemului si ale utilizatorilor, cache-ul de descarcari Windows Update si cache-ul Delivery Optimization.' }
    [pscustomobject]@{ Id = 'perf_dism'; Tab = 'PERF'; Group = 'Curatare'; Level = 'max'; Reapply = $false
        Title = 'Curatare componente Windows (WinSxS)'
        Desc  = 'Ruleaza DISM StartComponentCleanup pentru a sterge versiunile vechi ale componentelor. Poate dura 5-20 de minute. Update-urile instalate pot fi in continuare dezinstalate.' }
)

# ============================================================================
#  Jurnal si progres
# ============================================================================
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $prefix = ''
    switch ($Level) {
        'WARN' { $prefix = '[!] '; $global:W11WarnCount++ }
        'OK'   { $prefix = '[OK] ' }
        'HEAD' { $prefix = '>> ' }
    }
    $line = '[{0}] {1}{2}' -f (Get-Date -Format 'HH:mm:ss'), $prefix, $Message
    if ($global:W11LogFile) {
        try { Add-Content -LiteralPath $global:W11LogFile -Value $line -Encoding UTF8 -ErrorAction Stop } catch { }
    }
    if ($global:W11Sync) { $global:W11Sync.Queue.Enqueue($line) }
    elseif (-not $global:W11Silent) { Write-Host $line }
}

function Set-W11Progress {
    param([int]$Percent, [string]$Status)
    if ($global:W11Sync) {
        $global:W11Sync.Progress = [math]::Min(100, [math]::Max(0, $Percent))
        if ($Status) { $global:W11Sync.Status = $Status }
    }
}

function Initialize-W11Folder {
    foreach ($d in @($global:W11Root, $global:W11LogDir)) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    # Doar SYSTEM si Administratorii pot modifica scriptul rulat ca SYSTEM; utilizatorii doar citesc.
    try {
        & icacls.exe $global:W11Root /setowner '*S-1-5-32-544' /T /C /Q 2>&1 | Out-Null
        & icacls.exe $global:W11Root /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' /T /C /Q 2>&1 | Out-Null
    } catch { }
}

function Initialize-W11Log {
    param([string]$FileName)
    Initialize-W11Folder
    $global:W11LogFile = Join-Path $global:W11LogDir $FileName
}

# ============================================================================
#  Registru (.NET direct, vedere pe 64 de biti, se aplica tuturor profilurilor de utilizator)
# ============================================================================
function Get-W11RegKey {
    param([string]$Path, [switch]$Create, [switch]$Write)
    $view = [Microsoft.Win32.RegistryView]::Default
    if ([Environment]::Is64BitOperatingSystem) { $view = [Microsoft.Win32.RegistryView]::Registry64 }
    $hive = $null; $sub = ''
    if     ($Path -match '^HKLM:\\?(.*)$')                        { $hive = [Microsoft.Win32.RegistryHive]::LocalMachine; $sub = $Matches[1] }
    elseif ($Path -match '^HKCU:\\?(.*)$')                        { $hive = [Microsoft.Win32.RegistryHive]::CurrentUser;  $sub = $Matches[1] }
    elseif ($Path -match '^Registry::HKEY_USERS\\(.*)$')          { $hive = [Microsoft.Win32.RegistryHive]::Users;        $sub = $Matches[1] }
    elseif ($Path -match '^Registry::HKEY_LOCAL_MACHINE\\(.*)$')  { $hive = [Microsoft.Win32.RegistryHive]::LocalMachine; $sub = $Matches[1] }
    else { throw "Cale de registru necunoscuta: $Path" }
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
    try {
        if ($Create) { return $base.CreateSubKey($sub) }
        return $base.OpenSubKey($sub, [bool]$Write)
    } finally { $base.Close() }
}

function Get-W11RegTargets {
    param([string]$Path)
    if ($Path -like 'HKCU:*') {
        $out = @()
        foreach ($r in $global:W11Roots) { $out += ($Path -replace '^HKCU:', $r) }
        return $out
    }
    return @($Path)
}

function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    foreach ($t in (Get-W11RegTargets $Path)) {
        $k = $null
        try {
            $k = Get-W11RegKey -Path $t -Create
            if (-not $k) { throw 'cheia nu a putut fi creata' }
            $kind = [Microsoft.Win32.RegistryValueKind]::$Type
            if     ($Type -eq 'DWord')       { $v = [int]$Value }
            elseif ($Type -eq 'QWord')       { $v = [long]$Value }
            elseif ($Type -eq 'Binary')      { $v = [byte[]]$Value }
            elseif ($Type -eq 'MultiString') { $v = [string[]]$Value }
            else                             { $v = [string]$Value }
            $k.SetValue($Name, $v, $kind)
        } catch {
            $ex = $_.Exception
            while ($ex.InnerException) { $ex = $ex.InnerException }
            if ($ex -is [System.UnauthorizedAccessException] -or $ex -is [System.Security.SecurityException]) {
                Write-Log ('Cheie protejata de sistem (ignorata): {0} [{1}]' -f $t, $Name)
            } else {
                Write-Log ('Registru {0} [{1}]: {2}' -f $t, $Name, $ex.Message) 'WARN'
            }
        } finally {
            if ($k) { $k.Close() }
        }
    }
}

function Remove-RegValue {
    param([string]$Path, [string]$Name)
    foreach ($t in (Get-W11RegTargets $Path)) {
        try {
            $k = Get-W11RegKey -Path $t -Write
            if ($k) { $k.DeleteValue($Name, $false); $k.Close() }
        } catch { }
    }
}

function Get-RegValue {
    param([string]$Path, [string]$Name)
    try {
        $k = Get-W11RegKey -Path $Path
        if ($k) { $v = $k.GetValue($Name, $null); $k.Close(); return $v }
    } catch { }
    return $null
}

function Mount-W11DefaultHive {
    $global:W11DefaultMounted = $false
    $ntuser = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $ntuser)) { return }
    $existing = $null
    try { $existing = [Microsoft.Win32.Registry]::Users.OpenSubKey($global:W11DefaultHive) } catch { }
    if ($existing) { $existing.Close(); $global:W11DefaultMounted = $true; return }
    $null = & reg.exe load "HKU\$($global:W11DefaultHive)" "$ntuser" 2>&1
    if ($LASTEXITCODE -eq 0) { $global:W11DefaultMounted = $true }
}

function Dismount-W11DefaultHive {
    if (-not $global:W11DefaultMounted) { return }
    for ($i = 0; $i -lt 6; $i++) {
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        $null = & reg.exe unload "HKU\$($global:W11DefaultHive)" 2>&1
        if ($LASTEXITCODE -eq 0) { break }
        Start-Sleep -Milliseconds 800
    }
    $global:W11DefaultMounted = $false
}

function Update-W11UserRoots {
    $roots = @()
    try { $names = [Microsoft.Win32.Registry]::Users.GetSubKeyNames() } catch { $names = @() }
    foreach ($n in $names) {
        if ($n -match '^S-1-5-21-[\d-]+$') { $roots += "Registry::HKEY_USERS\$n" }
    }
    if ($global:W11DefaultMounted) { $roots += "Registry::HKEY_USERS\$($global:W11DefaultHive)" }
    if ($roots.Count -eq 0) { $roots = @('HKCU:') }
    $global:W11Roots = $roots
}

function Add-W11HiddenSettingsPage {
    param([string]$Page)
    $k = $null
    try {
        $k = Get-W11RegKey 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Create
        $cur = [string]$k.GetValue('SettingsPageVisibility', '')
        if ($cur -like 'showonly:*') { return }
        $pages = @()
        if ($cur -like 'hide:*') { $pages = @($cur.Substring(5) -split ';' | Where-Object { $_ }) }
        if ($pages -notcontains $Page) { $pages += $Page }
        $k.SetValue('SettingsPageVisibility', ('hide:' + ($pages -join ';')), [Microsoft.Win32.RegistryValueKind]::String)
    } catch {
        Write-Log ('SettingsPageVisibility: {0}' -f $_.Exception.Message) 'WARN'
    } finally { if ($k) { $k.Close() } }
}

# ============================================================================
#  Servicii, task-uri programate, componente
# ============================================================================
function Set-W11Service {
    param([string]$Name, [string]$Start)
    $svcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    $probe = $null
    try { $probe = Get-W11RegKey $svcPath } catch { }
    if (-not $probe) { return }
    $probe.Close()
    $map = @{ 'Disabled' = 4; 'Manual' = 3; 'Automatic' = 2 }
    $ok = $false
    try { Set-Service -Name $Name -StartupType $Start -ErrorAction Stop; $ok = $true } catch { }
    if (-not $ok) {
        try {
            $k = Get-W11RegKey $svcPath -Write
            if ($k) { $k.SetValue('Start', [int]$map[$Start], [Microsoft.Win32.RegistryValueKind]::DWord); $k.Close(); $ok = $true }
        } catch { }
    }
    if ($Start -eq 'Disabled') { try { Stop-Service -Name $Name -Force -ErrorAction Stop } catch { } }
    if ($ok) { Write-Log ('Serviciu {0} -> {1}' -f $Name, $Start) }
    else     { Write-Log ('Serviciul {0} este protejat de sistem si nu a putut fi modificat' -f $Name) }
}

function Disable-W11Task {
    param([string]$FullPath)
    $idx = $FullPath.LastIndexOf('\')
    $tp = $FullPath.Substring(0, $idx + 1)
    $tn = $FullPath.Substring($idx + 1)
    $t = Get-ScheduledTask -TaskPath $tp -TaskName $tn -ErrorAction SilentlyContinue
    if (-not $t -or $t.State -eq 'Disabled') { return }
    try {
        Disable-ScheduledTask -TaskPath $tp -TaskName $tn -ErrorAction Stop | Out-Null
        Write-Log ('Task dezactivat: {0}' -f $FullPath)
    } catch {
        Write-Log ('Task protejat de sistem (ignorat): {0}' -f $FullPath)
    }
}

function Disable-W11TaskFolder {
    param([string]$Like)
    foreach ($t in @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -like $Like })) {
        Disable-W11Task ($t.TaskPath + $t.TaskName)
    }
}

function Get-W11ProfileSids {
    $sids = @('S-1-5-18')
    try {
        $k = Get-W11RegKey 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
        if ($k) {
            foreach ($n in $k.GetSubKeyNames()) { if ($n -match '^S-1-5-21-[\d-]+$') { $sids += $n } }
            $k.Close()
        }
    } catch { }
    return $sids
}

function Remove-AppxSmart {
    param([string[]]$Names, [switch]$Force)
    $store = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore'
    if ($null -eq $global:W11ProvCache) {
        try { $global:W11ProvCache = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop) } catch { $global:W11ProvCache = @() }
    }
    $sids = Get-W11ProfileSids
    foreach ($n in $Names) {
        foreach ($p in @(Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue)) {
            Write-Log ('Elimin {0} {1}' -f $p.Name, $p.Version)
            $eolKeys = @()
            if ($Force -or $p.NonRemovable) {
                # Pachetele "nedezinstalabile" sunt marcate EndOfLife pentru a permite dezinstalarea
                if (Get-Command -Name Set-NonRemovableAppsPolicy -ErrorAction SilentlyContinue) {
                    try { Set-NonRemovableAppsPolicy -Online -PackageFamilyName $p.PackageFamilyName -NonRemovable 0 -ErrorAction Stop | Out-Null } catch { }
                }
                foreach ($sid in $sids) {
                    $ek = "$store\EndOfLife\$sid\$($p.PackageFullName)"
                    try { $k = Get-W11RegKey $ek -Create; if ($k) { $k.Close(); $eolKeys += @{ Sid = $sid; Name = $p.PackageFullName } } } catch { }
                }
                try {
                    $ib = Get-W11RegKey "$store\InboxApplications" -Write
                    if ($ib) {
                        foreach ($sk in $ib.GetSubKeyNames()) { if ($sk -like "$($p.Name)_*") { try { $ib.DeleteSubKeyTree($sk, $false) } catch { } } }
                        $ib.Close()
                    }
                } catch { }
            }
            $ok = $false
            try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop; $ok = $true } catch {
                try { Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop; $ok = $true } catch {
                    Write-Log ('  {0}: {1}' -f $p.Name, ($_.Exception.Message -replace '\s+', ' ')) 'WARN'
                }
            }
            if ($ok) { Write-Log ('  {0} eliminat' -f $p.Name) 'OK' }
            # Blocheaza reinstalarea prin Windows Update / provizionare pentru utilizatori noi
            try { $k = Get-W11RegKey "$store\Deprovisioned\$($p.PackageFamilyName)" -Create; if ($k) { $k.Close() } } catch { }
            foreach ($e in $eolKeys) {
                try { $k = Get-W11RegKey "$store\EndOfLife\$($e.Sid)" -Write; if ($k) { $k.DeleteSubKeyTree($e.Name, $false); $k.Close() } } catch { }
            }
        }
        foreach ($pp in @($global:W11ProvCache | Where-Object { $_.DisplayName -like $n })) {
            try { Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -AllUsers -ErrorAction Stop | Out-Null } catch {
                try { Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null } catch { }
            }
            Write-Log ('Deprovizionat: {0}' -f $pp.DisplayName)
            $parts = $pp.PackageName -split '_'
            if ($parts.Count -ge 2) {
                try { $k = Get-W11RegKey ("$store\Deprovisioned\{0}_{1}" -f $parts[0], $parts[-1]) -Create; if ($k) { $k.Close() } } catch { }
            }
        }
    }
}

function Remove-W11Recall {
    try {
        $f = Get-WindowsOptionalFeature -Online -FeatureName 'Recall' -ErrorAction Stop
        if (-not $f) { throw 'absent' }
        if ($f.State -eq 'DisabledWithPayloadRemoved') { Write-Log 'Recall este deja eliminat complet'; return }
        Disable-WindowsOptionalFeature -Online -FeatureName 'Recall' -Remove -NoRestart -ErrorAction Stop | Out-Null
        Write-Log 'Componenta optionala Recall eliminata (cu fisiere)' 'OK'
    } catch {
        Write-Log 'Recall nu exista pe acest PC (normal pe PC-urile care nu sunt Copilot+)'
    }
}

function Test-W11Laptop {
    if ($null -ne $global:W11IsLaptop) { return $global:W11IsLaptop }
    $global:W11IsLaptop = $false
    try {
        $ch = @((Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction Stop).ChassisTypes)
        foreach ($c in $ch) { if (@(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32) -contains [int]$c) { $global:W11IsLaptop = $true } }
        if (-not $global:W11IsLaptop -and (Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue)) { $global:W11IsLaptop = $true }
    } catch { }
    return $global:W11IsLaptop
}

function Get-W11SysInfo {
    $cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int]$cv.CurrentBuild
    $name = [string]$cv.ProductName
    if ($build -ge 22000) { $name = $name -replace 'Windows 10', 'Windows 11' }
    $ram = 0; $cpu = '?'; $disk = 'necunoscut'
    try { $ram = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1GB, 1) } catch { }
    try { $cpu = ((Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1).Name).Trim() } catch { }
    try {
        $dn = (Get-Partition -DriveLetter $env:SystemDrive.Substring(0, 1) -ErrorAction Stop).DiskNumber
        $pd = Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.DeviceId -eq "$dn" } | Select-Object -First 1
        if ($pd -and $null -ne $pd.MediaType) {
            $disk = [string]$pd.MediaType
            switch ($disk) { '3' { $disk = 'HDD' } '4' { $disk = 'SSD' } '5' { $disk = 'SCM' } '0' { $disk = 'necunoscut' } 'Unspecified' { $disk = 'necunoscut' } }
        }
    } catch { }
    [pscustomobject]@{
        Build    = $build
        UBR      = $cv.UBR
        Name     = $name
        Display  = $cv.DisplayVersion
        RamGB    = $ram
        Cpu      = $cpu
        Disk     = $disk
        IsLaptop = (Test-W11Laptop)
        IsHome   = ([string]$cv.EditionID -like 'Core*')
    }
}

# ============================================================================
#  Actiuni complexe
# ============================================================================
function New-W11RestorePoint {
    Write-Log 'Creez punctul de restaurare...' 'HEAD'
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0
        Checkpoint-Computer -Description 'Win11Lite - inainte de modificari' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Log 'Punct de restaurare creat: "Win11Lite - inainte de modificari"' 'OK'
    } catch {
        Write-Log ('Punctul de restaurare nu a putut fi creat: {0}' -f $_.Exception.Message) 'WARN'
    }
}

function Set-W11PowerPlan {
    $dest = '57696e31-314c-4974-6550-6f7765720001'
    $hp   = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    $ult  = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
    $null = & powercfg.exe /query $dest 2>&1
    if ($LASTEXITCODE -ne 0) {
        $src = $ult
        if (Test-W11Laptop) { $src = $hp }
        $null = & powercfg.exe /duplicatescheme $src $dest 2>&1
        if ($LASTEXITCODE -ne 0) { $null = & powercfg.exe /duplicatescheme $hp $dest 2>&1 }
        if ($LASTEXITCODE -eq 0) { $null = & powercfg.exe /changename $dest 'Win11Lite Performanta' 'Plan de performanta creat de Win11Lite' 2>&1 }
    }
    $null = & powercfg.exe /setactive $dest 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Log 'Plan de alimentare activ: Win11Lite Performanta' 'OK' }
    else { Write-Log 'Planul de performanta nu a putut fi activat (posibil sistem Modern Standby)' 'WARN' }
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1
}

function Set-W11GameDvrOff {
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
}

function Clear-W11Folder {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    foreach ($i in @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)) {
        try {
            if ($i.PSIsContainer) { & cmd.exe /d /c ('rd /s /q "{0}"' -f $i.FullName) 2>&1 | Out-Null }
            else { Remove-Item -LiteralPath $i.FullName -Force -ErrorAction Stop }
        } catch { }
    }
}

function Invoke-W11Cleanup {
    $drv = $env:SystemDrive
    $before = 0
    try { $before = (Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$drv'").FreeSpace } catch { }
    $dirs = @("$env:SystemRoot\Temp")
    foreach ($u in @(Get-ChildItem -LiteralPath "$drv\Users" -Directory -Force -ErrorAction SilentlyContinue)) {
        if ($u.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        $t = Join-Path $u.FullName 'AppData\Local\Temp'
        if (Test-Path -LiteralPath $t) { $dirs += $t }
    }
    foreach ($d in $dirs) { Write-Log ('Curat {0}' -f $d); Clear-W11Folder $d }
    if (Get-Command -Name Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
        try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop | Out-Null; Write-Log 'Cache Delivery Optimization golit' } catch { }
    }
    Stop-Service -Name 'wuauserv', 'bits' -Force -ErrorAction SilentlyContinue
    Write-Log 'Curat cache-ul de descarcari Windows Update'
    Clear-W11Folder "$env:SystemRoot\SoftwareDistribution\Download"
    $after = $before
    try { $after = (Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$drv'").FreeSpace } catch { }
    Write-Log ('Spatiu eliberat: {0:N2} GB' -f ([math]::Max(0, ($after - $before)) / 1GB)) 'OK'
}

function Invoke-W11Dism {
    Write-Log 'DISM StartComponentCleanup ruleaza - poate dura 5-20 de minute, nu inchide fereastra...'
    try {
        $p = Start-Process -FilePath "$env:SystemRoot\System32\dism.exe" -ArgumentList '/Online', '/Cleanup-Image', '/StartComponentCleanup', '/NoRestart' -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
        if ($p.ExitCode -eq 0) { Write-Log 'Curatarea componentelor Windows s-a terminat' 'OK' }
        else { Write-Log ('DISM a returnat codul {0}' -f $p.ExitCode) 'WARN' }
    } catch { Write-Log ('DISM: {0}' -f $_.Exception.Message) 'WARN' }
}

function Remove-W11OneDrive {
    Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $setups = @()
    $setups += @(Get-ChildItem -Path "$env:SystemDrive\Users\*\AppData\Local\Microsoft\OneDrive\*\OneDriveSetup.exe" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    $setups += @(Get-ChildItem -Path "$env:ProgramFiles\Microsoft OneDrive\*\OneDriveSetup.exe" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    foreach ($p in @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe")) {
        if (Test-Path -LiteralPath $p) { $setups += $p }
    }
    $ran = $false
    foreach ($s in $setups) {
        $argStr = '/uninstall'
        if ($s -like "$env:ProgramFiles*") { $argStr = '/uninstall /allusers' }
        try { Start-Process -FilePath $s -ArgumentList $argStr -Wait -WindowStyle Hidden -ErrorAction Stop; $ran = $true } catch { }
    }
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1
    Remove-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'OneDriveSetup'
    Remove-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'OneDrive'
    Set-Reg 'HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' 'System.IsPinnedToNameSpaceTree' 0
    if ($ran) { Write-Log 'OneDrive dezinstalat si blocat' 'OK' } else { Write-Log 'Instalatorul OneDrive nu a fost gasit; OneDrive a fost doar blocat prin politica' }
}

# ============================================================================
#  Protectie (task programat)
# ============================================================================
function Save-W11Config {
    if (-not $global:W11AppliedIds -or $global:W11AppliedIds.Count -eq 0) { return }
    Initialize-W11Folder
    $cfgFile = Join-Path $global:W11Root 'config.json'
    $ids = @()
    if (Test-Path -LiteralPath $cfgFile) {
        try { $ids = @((Get-Content -LiteralPath $cfgFile -Raw | ConvertFrom-Json).AiItems) } catch { }
    }
    $ids = @(@($ids) + @($global:W11AppliedIds) | Where-Object { $_ } | Select-Object -Unique)
    $obj = [pscustomobject]@{ Version = $global:W11Version; Updated = (Get-Date).ToString('s'); AiItems = $ids }
    $obj | ConvertTo-Json | Set-Content -LiteralPath $cfgFile -Encoding UTF8
}

function Install-W11Guard {
    if (-not $global:W11ScriptFile -or -not (Test-Path -LiteralPath $global:W11ScriptFile)) {
        Write-Log 'Scriptul nu ruleaza dintr-un fisier .ps1 - protectia nu poate fi instalata. Salveaza-l ca fisier si ruleaza-l din nou.' 'WARN'
        return
    }
    Save-W11Config
    Initialize-W11Folder
    $dest = Join-Path $global:W11Root 'Win11Lite.ps1'
    if ([IO.Path]::GetFullPath($global:W11ScriptFile) -ne [IO.Path]::GetFullPath($dest)) {
        Copy-Item -LiteralPath $global:W11ScriptFile -Destination $dest -Force
    }
    try { Unblock-File -LiteralPath $dest -ErrorAction SilentlyContinue } catch { }
    $cfgFile = Join-Path $global:W11Root 'config.json'
    $count = 0
    if (Test-Path -LiteralPath $cfgFile) { try { $count = @((Get-Content -LiteralPath $cfgFile -Raw | ConvertFrom-Json).AiItems).Count } catch { } }

    $psExe   = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $action  = New-ScheduledTaskAction -Execute $psExe -Argument ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Reapply' -f $dest)
    $t1 = New-ScheduledTaskTrigger -AtStartup; $t1.Delay = 'PT3M'
    $t2 = New-ScheduledTaskTrigger -AtLogOn;   $t2.Delay = 'PT2M'
    $t3 = New-ScheduledTaskTrigger -Daily -At '13:00'
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
    try {
        Register-ScheduledTask -TaskName $global:W11TaskName -TaskPath $global:W11TaskPath -Action $action `
            -Trigger @($t1, $t2, $t3) -Principal $principal -Settings $settings -Force `
            -Description 'Win11 Lite: reaplica eliminarea functiilor AI dupa update-uri.' -ErrorAction Stop | Out-Null
        Write-Log ('Protectie instalata: task {0}{1} ({2} setari AI monitorizate)' -f $global:W11TaskPath, $global:W11TaskName, $count) 'OK'
    } catch {
        Write-Log ('Task-ul de protectie nu a putut fi creat: {0}' -f $_.Exception.Message) 'WARN'
    }
}

function Uninstall-W11Guard {
    $t = Get-ScheduledTask -TaskPath $global:W11TaskPath -TaskName $global:W11TaskName -ErrorAction SilentlyContinue
    if ($t) { Unregister-ScheduledTask -TaskPath $global:W11TaskPath -TaskName $global:W11TaskName -Confirm:$false -ErrorAction SilentlyContinue }
    foreach ($f in @('Win11Lite.ps1', 'config.json')) {
        Remove-Item -LiteralPath (Join-Path $global:W11Root $f) -Force -ErrorAction SilentlyContinue
    }
    return [bool]$t
}

# ============================================================================
#  Actiunile fiecarei optiuni
# ============================================================================
$global:W11Actions = @{

    'ai_copilot_apps' = {
        Remove-AppxSmart -Names $global:W11Pkgs.AiStandard
        Disable-W11Task '\Microsoft\Office\Office Actions Server'
    }

    'ai_copilot_policies' = {
        foreach ($h in @('HKLM', 'HKCU')) {
            Set-Reg "$($h):\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' 1
            Set-Reg "$($h):\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" 'RemoveMicrosoftCopilotApp' 1
            Set-Reg "$($h):\SOFTWARE\Microsoft\Windows\Shell\Copilot" 'IsCopilotAvailable' 0
            Set-Reg "$($h):\SOFTWARE\Microsoft\Windows\Shell\Copilot" 'CopilotDisabledReason' 'FeatureIsDisabled' 'String'
            Set-Reg "$($h):\SOFTWARE\Microsoft\Windows\Shell\Copilot\BingChat" 'IsUserEligible' 0
            Set-Reg "$($h):\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" '{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}' 'Ask Copilot' 'String'
        }
        $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Set-Reg $adv 'ShowCopilotButton' 0
        Set-Reg $adv 'TaskbarCompanion' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\WindowsCopilot' 'AllowCopilotRuntime' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings' 'AutoOpenCopilotLargeScreens' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins' 'CopilotPWAPin' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins' 'RecallPin' 0
        Set-Reg 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps' 'AgentActivationEnabled' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsActivateWithVoice' 2
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsActivateWithVoiceAboveLock' 2
        Write-Log 'Politicile Copilot au fost aplicate' 'OK'
    }

    'ai_edge' = {
        $e = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
        foreach ($n in @('HubsSidebarEnabled', 'CopilotPageContext', 'CopilotCDPPageContext', 'EdgeEntraCopilotPageContext',
                         'Microsoft365CopilotChatIconEnabled', 'EdgeHistoryAISearchEnabled', 'ComposeInlineEnabled',
                         'BuiltInAIAPIsEnabled', 'AIGenThemesEnabled', 'ShareBrowsingHistoryWithCopilotSearchAllowed')) {
            Set-Reg $e $n 0
        }
        Set-Reg $e 'GenAILocalFoundationalModelSettings' 1
        Set-Reg $e 'DevToolsGenAiSettings' 2
        Write-Log 'Politicile AI pentru Edge au fost aplicate (reporneste Edge)' 'OK'
    }

    'ai_search' = {
        $ws = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
        Set-Reg $ws 'AllowCortana' 0
        Set-Reg $ws 'DisableWebSearch' 1
        Set-Reg $ws 'ConnectedSearchUseWeb' 0
        Set-Reg $ws 'AllowCloudSearch' 0
        Set-Reg $ws 'EnableDynamicContentInWSB' 0
        Set-Reg $ws 'AllowSearchToUseLocation' 0
        foreach ($h in @('HKLM', 'HKCU')) { Set-Reg "$($h):\SOFTWARE\Policies\Microsoft\Windows\Explorer" 'DisableSearchBoxSuggestions' 1 }
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds\DSB' 'ShowDynamicContent' 0
        Write-Log 'Cautarea foloseste acum doar continut local' 'OK'
    }

    'ai_recall' = {
        foreach ($h in @('HKLM', 'HKCU')) {
            Set-Reg "$($h):\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" 'DisableAIDataAnalysis' 1
            Set-Reg "$($h):\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" 'TurnOffSavingSnapshots' 1
        }
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
        Remove-W11Recall
        Disable-W11TaskFolder '\Microsoft\Windows\WindowsAI\*'
    }

    'ai_clicktodo' = {
        foreach ($h in @('HKLM', 'HKCU')) {
            foreach ($n in @('DisableClickToDo', 'DisableSettingsAgent', 'DisableAgentConnectors', 'DisableAgentWorkspaces', 'DisableRemoteAgentConnectors')) {
                Set-Reg "$($h):\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" $n 1
            }
        }
        Set-Reg 'HKCU:\Software\Microsoft\Windows\Shell\ClickToDo' 'DisableClickToDo' 1
        Write-Log 'Click to Do, agentul din Setari si functiile agentice au fost dezactivate' 'OK'
    }

    'ai_genai' = {
        foreach ($cap in @('generativeAI', 'systemAIModels')) {
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$cap" 'Value' 'Deny' 'String'
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$cap" 'Value' 'Deny' 'String'
        }
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessGenerativeAI' 2
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessSystemAIModels' 2
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\Capabilities\systemAIModels' 'RecordUsageData' 0
        Write-Log 'Accesul aplicatiilor la AI generativ a fost blocat' 'OK'
    }

    'ai_apps' = {
        $paint = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'
        foreach ($n in @('DisableCocreator', 'DisableGenerativeFill', 'DisableImageCreator', 'DisableGenerativeErase', 'DisableRemoveBackground')) { Set-Reg $paint $n 1 }
        Set-Reg 'HKLM:\SOFTWARE\Policies\WindowsNotepad' 'DisableAIFeatures' 1
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\ai\training\general' 'disabletraining' 1
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\ai\training\specific\adaptivefloatie' 'disabletrainingofadaptivefloatie' 1
        foreach ($app in @('Word', 'Excel', 'PowerPoint')) { Set-Reg "HKCU:\Software\Microsoft\Office\16.0\$app\Options" 'EnableCopilot' 0 }
        foreach ($n in @('CopilotEnabled', 'CopilotNotebooksEnabled', 'CopilotSkittleEnabled')) { Set-Reg 'HKCU:\Software\Microsoft\Office\16.0\OneNote\Options\Copilot' $n 0 }
        Set-Reg 'HKCU:\Software\Policies\Microsoft\office\16.0\common\privacy' 'usercontentdisabled' 2
        Write-Log 'AI dezactivat in Paint, Notepad si Office' 'OK'
    }

    'ai_input' = {
        Set-Reg 'HKCU:\Software\Microsoft\input\Settings' 'InsightsEnabled' 0
        Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 1
        Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1
        Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\InkingAndTypingPersonalization' 'Value' 0
        Set-Reg 'HKCU:\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization' 'AllowInputPersonalization' 0
        Write-Log 'Colectarea datelor de tastare si scris a fost oprita' 'OK'
    }

    'ai_services' = {
        Set-W11Service 'WSAIFabricSvc' 'Disabled'
        Set-W11Service 'AarSvc' 'Disabled'
        Get-Service -Name 'AarSvc_*' -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
    }

    'ai_gaming' = {
        Remove-AppxSmart -Names $global:W11Pkgs.Gaming
        Set-W11GameDvrOff
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'UseNexusForGameBarEnabled' 0
    }

    'ai_system' = {
        Remove-AppxSmart -Names $global:W11Pkgs.AiSystem -Force
        Add-W11HiddenSettingsPage 'aicomponents'
    }

    'guard_task' = { Install-W11Guard }

    'guard_cfr' = {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'IsContinuousInnovationOptedIn' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'AllowTemporaryEnterpriseFeatureControl' 0
        Write-Log 'Livrarea timpurie a functiilor noi a fost oprita' 'OK'
    }

    'guard_silent' = {
        $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        foreach ($n in @('SilentInstalledAppsEnabled', 'OemPreInstalledAppsEnabled', 'PreInstalledAppsEnabled', 'PreInstalledAppsEverEnabled', 'ContentDeliveryAllowed', 'FeatureManagementEnabled')) { Set-Reg $cdm $n 0 }
        $cc = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        Set-Reg $cc 'DisableWindowsConsumerFeatures' 1
        Set-Reg $cc 'DisableCloudOptimizedContent' 1
        Set-Reg $cc 'DisableConsumerAccountStateContent' 1
        Write-Log 'Instalarea silentioasa a aplicatiilor promovate a fost blocata' 'OK'
    }

    'guard_store' = {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' 'AutoDownload' 2
        Write-Log 'Actualizarea automata din Microsoft Store a fost oprita' 'OK'
    }

    'perf_power' = { Set-W11PowerPlan }

    'perf_visual' = {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 3
        Set-Reg 'HKCU:\Control Panel\Desktop' 'UserPreferencesMask' ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) 'Binary'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'FontSmoothing' '2' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'DragFullWindows' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '100' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
        $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Set-Reg $adv 'TaskbarAnimations' 0
        Set-Reg $adv 'ListviewAlphaSelect' 0
        Set-Reg $adv 'ListviewShadow' 0
        Set-Reg $adv 'IconsOnly' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'AlwaysHibernateThumbnails' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
        Write-Log 'Efecte vizuale setate pentru performanta' 'OK'
    }

    'perf_startup' = {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'WaitForIdleState' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0
        Write-Log 'Pornire accelerata, Edge nu mai ruleaza in fundal' 'OK'
    }

    'perf_background' = {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BackgroundAppGlobalToggle' 0
        Write-Log 'Aplicatiile din fundal au fost blocate' 'OK'
    }

    'perf_gamedvr' = {
        Set-W11GameDvrOff
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
        Write-Log 'Game DVR oprit, Modul Joc activ' 'OK'
    }

    'perf_hibernate' = {
        $null = & powercfg.exe /hibernate off 2>&1
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0
        Write-Log 'Hibernarea si Fast Startup au fost dezactivate' 'OK'
    }

    'perf_svchost' = {
        try {
            $kb = [int64]((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1KB)
            if ($kb -gt 2147483647) { $kb = 2147483647 }
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB' ([int]$kb)
            Write-Log ('SvcHostSplitThresholdInKB = {0}' -f $kb) 'OK'
        } catch { Write-Log ('Nu am putut citi memoria RAM: {0}' -f $_.Exception.Message) 'WARN' }
    }

    'perf_services' = {
        foreach ($s in @('Fax', 'RetailDemo', 'MapsBroker', 'RemoteRegistry', 'WMPNetworkSvc')) { Set-W11Service $s 'Disabled' }
        foreach ($s in @('WerSvc', 'PcaSvc', 'TrkWks', 'WpcMonSvc', 'PhoneSvc')) { Set-W11Service $s 'Manual' }
    }

    'perf_sysmain' = { Set-W11Service 'SysMain' 'Disabled' }
    'perf_wsearch' = { Set-W11Service 'WSearch' 'Disabled' }
    'perf_spooler' = { Set-W11Service 'Spooler' 'Disabled' }

    'perf_telemetry' = {
        $dc = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
        Set-Reg $dc 'AllowTelemetry' 0
        Set-Reg $dc 'DoNotShowFeedbackNotifications' 1
        Set-Reg $dc 'AllowDeviceNameInTelemetry' 0
        Set-Reg $dc 'LimitDiagnosticLogCollection' 1
        Set-Reg $dc 'LimitDumpCollection' 1
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
        $sys = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        Set-Reg $sys 'EnableActivityFeed' 0
        Set-Reg $sys 'PublishUserActivities' 0
        Set-Reg $sys 'UploadUserActivities' 0
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'Disabled' 1
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'Disabled' 1
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' 'CEIPEnable' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'AITEnable' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'DisableInventory' 1
        Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
        Set-W11Service 'DiagTrack' 'Disabled'
        Set-W11Service 'dmwappushservice' 'Disabled'
        foreach ($t in $global:W11TelemetryTasks) { Disable-W11Task $t }
    }

    'perf_ads' = {
        $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        foreach ($n in @('ContentDeliveryAllowed', 'FeatureManagementEnabled', 'OemPreInstalledAppsEnabled', 'PreInstalledAppsEnabled',
                         'PreInstalledAppsEverEnabled', 'SilentInstalledAppsEnabled', 'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled',
                         'RotatingLockScreenOverlayEnabled', 'SubscribedContentEnabled', 'SubscribedContent-310093Enabled',
                         'SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled',
                         'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled',
                         'SubscribedContent-353698Enabled')) {
            Set-Reg $cdm $n 0
        }
        $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Set-Reg $adv 'Start_IrisRecommendations' 0
        Set-Reg $adv 'Start_AccountNotifications' 0
        Set-Reg $adv 'ShowSyncProviderNotifications' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
        $ccU = 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent'
        Set-Reg $ccU 'DisableSpotlightCollectionOnDesktop' 1
        Set-Reg $ccU 'DisableTailoredExperiencesWithDiagnosticData' 1
        Set-Reg $ccU 'DisableThirdPartySuggestions' 1
        Set-Reg $ccU 'DisableWindowsSpotlightWindowsWelcomeExperience' 1
        $cc = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        Set-Reg $cc 'DisableWindowsConsumerFeatures' 1
        Set-Reg $cc 'DisableSoftLanding' 1
        Set-Reg $cc 'DisableCloudOptimizedContent' 1
        Set-Reg $cc 'DisableConsumerAccountStateContent' 1
        Write-Log 'Reclamele, sugestiile si sfaturile au fost oprite' 'OK'
    }

    'perf_widgets' = {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat' 'ChatIcon' 3
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds' 0
        Remove-AppxSmart -Names $global:W11Pkgs.Widgets
    }

    'perf_delivery' = {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
        Write-Log 'Partajarea P2P a update-urilor a fost oprita' 'OK'
    }

    'perf_bloat' = { Remove-AppxSmart -Names $global:W11Pkgs.Bloat }

    'perf_xbox' = {
        Remove-AppxSmart -Names $global:W11Pkgs.Xbox
        Set-W11GameDvrOff
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'UseNexusForGameBarEnabled' 0
    }

    'perf_onedrive' = { Remove-W11OneDrive }

    'perf_classicmenu' = {
        Set-Reg 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '' '' 'String'
        Write-Log 'Meniul click-dreapta clasic va aparea dupa repornire' 'OK'
    }

    'perf_cleanup' = { Invoke-W11Cleanup }
    'perf_dism'    = { Invoke-W11Dism }
}

# ============================================================================
#  Scanare, rulare, reaplicare
# ============================================================================
function Invoke-W11Scan {
    Write-Log 'Scanare componente AI instalate' 'HEAD'
    $names = @($global:W11Pkgs.AiStandard) + @($global:W11Pkgs.AiSystem) + @('Microsoft.XboxGamingOverlay')
    $found = 0
    foreach ($n in $names) {
        foreach ($p in @(Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue)) {
            $found++
            Write-Log ('  Instalat: {0}  ({1})' -f $p.Name, $p.Version)
        }
    }
    if ($found -eq 0) { Write-Log 'Niciun pachet AI cunoscut nu este instalat' 'OK' }
    else { Write-Log ('{0} pachete AI sunt instalate' -f $found) }
    Set-W11Progress 60 'Verific Recall, politicile si protectia...'
    try {
        $f = Get-WindowsOptionalFeature -Online -FeatureName 'Recall' -ErrorAction Stop
        if ($f) { Write-Log ('Recall: {0}' -f $f.State) } else { Write-Log 'Recall: nu exista pe acest PC' }
    } catch { Write-Log 'Recall: nu exista pe acest PC' }
    $checks = @(
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot', 'TurnOffWindowsCopilot', 'Politica "Copilot oprit" (1 = activa)'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'DisableAIDataAnalysis', 'Politica "Recall oprit" (1 = activa)'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'DisableClickToDo', 'Politica "Click to Do oprit" (1 = activa)'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy', 'LetAppsAccessGenerativeAI', 'Acces aplicatii la AI generativ (2 = blocat)'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Edge', 'HubsSidebarEnabled', 'Edge - bara Copilot (0 = oprita)'),
        @('HKLM:\SOFTWARE\Policies\WindowsNotepad', 'DisableAIFeatures', 'Notepad - AI oprit (1 = da)')
    )
    foreach ($c in $checks) {
        $v = Get-RegValue $c[0] $c[1]
        $txt = 'nesetat'
        if ($null -ne $v) { $txt = [string]$v }
        Write-Log ('{0}: {1}' -f $c[2], $txt)
    }
    $svc = Get-Service -Name 'WSAIFabricSvc' -ErrorAction SilentlyContinue
    if ($svc) { Write-Log ('Serviciul WSAIFabricSvc: {0} / pornire {1}' -f $svc.Status, $svc.StartType) }
    $t = Get-ScheduledTask -TaskPath $global:W11TaskPath -TaskName $global:W11TaskName -ErrorAction SilentlyContinue
    if ($t) {
        $last = 'inca nu a rulat'
        try {
            $info = $t | Get-ScheduledTaskInfo -ErrorAction Stop
            if ($info.LastRunTime -and $info.LastRunTime.Year -gt 2000) { $last = '{0} (cod {1})' -f $info.LastRunTime, $info.LastTaskResult }
        } catch { }
        Write-Log ('Protectie automata: ACTIVA - ultima rulare: {0}' -f $last) 'OK'
    } else { Write-Log 'Protectie automata: neinstalata' }
    Set-W11Progress 100 'Scanare terminata'
}

function Invoke-W11Run {
    param([string[]]$Ids, [bool]$RestorePoint)
    $global:W11WarnCount  = 0
    $global:W11ProvCache  = $null
    $global:W11AppliedIds = New-Object System.Collections.Generic.List[string]
    $global:W11CurrentIds = $Ids
    try {
        Initialize-W11Log -FileName ('Win11Lite_{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        Write-Log ('Win11 Lite v{0} - {1}' -f $global:W11Version, (Get-Date)) 'HEAD'
        Mount-W11DefaultHive
        Update-W11UserRoots
        Write-Log ('Profiluri de utilizator vizate: {0} (inclusiv profilul implicit pentru conturi noi: {1})' -f $global:W11Roots.Count, $(if ($global:W11DefaultMounted) { 'da' } else { 'nu' }))
        if ($Ids -contains '__scan') { Set-W11Progress 20 'Scanare...'; Invoke-W11Scan; return }

        $items = @($global:W11Items | Where-Object { ($Ids -contains $_.Id) -and ($_.Id -ne 'guard_task') })
        if ($Ids -contains 'guard_task') { $items += @($global:W11Items | Where-Object { $_.Id -eq 'guard_task' }) }
        $total = $items.Count + [int]$RestorePoint
        $step = 0
        if ($RestorePoint) { Set-W11Progress 1 'Creez punctul de restaurare...'; New-W11RestorePoint; $step++ }
        foreach ($it in $items) {
            Set-W11Progress ([int](($step / [math]::Max($total, 1)) * 100)) $it.Title
            Write-Log $it.Title 'HEAD'
            try {
                & $global:W11Actions[$it.Id]
                if ($it.Reapply) { $global:W11AppliedIds.Add($it.Id) }
            } catch {
                Write-Log ('Eroare: {0}' -f $_.Exception.Message) 'WARN'
            }
            $step++
        }
        Save-W11Config
        Set-W11Progress 100 'Gata'
        Write-Log ('Terminat. Avertismente: {0}. Reporneste PC-ul pentru a finaliza modificarile.' -f $global:W11WarnCount) 'OK'
    } catch {
        Write-Log ('Eroare neasteptata: {0}' -f $_.Exception.Message) 'WARN'
    } finally {
        Dismount-W11DefaultHive
        if ($global:W11Sync) { $global:W11Sync.Warn = $global:W11WarnCount; $global:W11Sync.Done = $true }
    }
}

function Invoke-W11Reapply {
    $global:W11Silent = $true
    Initialize-W11Folder
    $global:W11LogFile = Join-Path $global:W11LogDir 'Reapply.log'
    if ((Test-Path -LiteralPath $global:W11LogFile) -and ((Get-Item -LiteralPath $global:W11LogFile).Length -gt 2MB)) {
        Move-Item -LiteralPath $global:W11LogFile -Destination ($global:W11LogFile + '.old') -Force
    }
    $cfgFile = Join-Path $global:W11Root 'config.json'
    if (-not (Test-Path -LiteralPath $cfgFile)) { Write-Log 'config.json lipseste - nimic de reaplicat' 'WARN'; return }
    $cfg = $null
    try { $cfg = Get-Content -LiteralPath $cfgFile -Raw | ConvertFrom-Json } catch { Write-Log 'config.json este corupt' 'WARN'; return }
    Write-Log ('Reaplicare protectie AI (v{0})' -f $global:W11Version) 'HEAD'
    $global:W11ProvCache = $null
    try {
        Mount-W11DefaultHive
        Update-W11UserRoots
        foreach ($id in @($cfg.AiItems)) {
            $item = $global:W11Items | Where-Object { $_.Id -eq $id } | Select-Object -First 1
            if (-not $item -or -not $item.Reapply) { continue }
            try { & $global:W11Actions[$id] } catch { Write-Log ('{0}: {1}' -f $id, $_.Exception.Message) 'WARN' }
        }
    } finally {
        Dismount-W11DefaultHive
    }
    Write-Log 'Reaplicare terminata' 'OK'
}
'@

# Incarca nucleul in sesiunea curenta
. ([scriptblock]::Create($CoreCode))
$global:W11ScriptFile = $PSCommandPath

# ============================================================================
#  Mod fara interfata (task-ul programat de protectie)
# ============================================================================
if ($Reapply) {
    Invoke-W11Reapply
    return
}

# ============================================================================
#  INTERFATA GRAFICA
# ============================================================================
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Win11 Lite - Eliminare AI si Optimizare Windows 11"
        Width="1080" Height="860" MinWidth="900" MinHeight="600"
        WindowStartupLocation="CenterScreen"
        Background="#14141F" Foreground="#E6E6F0"
        FontFamily="Segoe UI" FontSize="13">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="Background" Value="#2C2C46"/>
      <Setter Property="Padding" Value="14,8"/>
      <Setter Property="Margin" Value="0,4,8,4"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Opacity" Value="0.85"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bd" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TabItem">
      <Setter Property="Foreground" Value="#E6E6F0"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border x:Name="Bd" Background="#22223A" CornerRadius="8,8,0,0" Padding="20,9" Margin="0,0,6,0" Cursor="Hand">
              <ContentPresenter ContentSource="Header" HorizontalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#7C5CFF"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#E6E6F0"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>
  </Window.Resources>

  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="140"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="#1E1E30" CornerRadius="10" Padding="18,14" Margin="0,0,0,12">
      <Grid>
        <StackPanel>
          <TextBlock Text="Win11 Lite" FontSize="26" FontWeight="Bold" Foreground="#FFFFFF"/>
          <TextBlock Text="Eliminare completa a functiilor AI si optimizare pentru PC-uri cu resurse reduse" Foreground="#A9A9C8" Margin="0,2,0,0"/>
          <TextBlock x:Name="SysInfo" Margin="0,10,0,0" Foreground="#C9C9E0" TextWrapping="Wrap"/>
          <TextBlock x:Name="SysWarn" Margin="0,6,0,0" Foreground="#F0B35E" TextWrapping="Wrap"/>
        </StackPanel>
        <TextBlock x:Name="VersionText" HorizontalAlignment="Right" VerticalAlignment="Top" Foreground="#6E6E90"/>
      </Grid>
    </Border>

    <TabControl Grid.Row="1" x:Name="Tabs" Background="#1B1B2B" BorderThickness="0" Padding="0">
      <TabItem Header="Eliminare AI">
        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Background="#1B1B2B">
          <StackPanel x:Name="AiPanel" Margin="14,6,14,14"/>
        </ScrollViewer>
      </TabItem>
      <TabItem Header="Optimizare performanta">
        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Background="#1B1B2B">
          <StackPanel x:Name="PerfPanel" Margin="14,6,14,14"/>
        </ScrollViewer>
      </TabItem>
      <TabItem Header="Ajutor">
        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Background="#1B1B2B">
          <TextBlock x:Name="HelpText" Margin="20" TextWrapping="Wrap" Foreground="#D0D0E4" FontSize="13" LineHeight="20"/>
        </ScrollViewer>
      </TabItem>
    </TabControl>

    <Grid Grid.Row="2" Margin="0,12,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <WrapPanel Grid.Column="0" VerticalAlignment="Center">
        <Button x:Name="BtnRec" Content="Selecteaza Recomandat"/>
        <Button x:Name="BtnMax" Content="Selecteaza Maxim"/>
        <Button x:Name="BtnNone" Content="Deselecteaza tot"/>
        <Button x:Name="BtnScan" Content="Verifica sistemul"/>
        <Button x:Name="BtnRestore" Content="Restaurare sistem"/>
        <Button x:Name="BtnUnguard" Content="Elimina protectia"/>
        <Button x:Name="BtnLogs" Content="Jurnale"/>
      </WrapPanel>
      <StackPanel Grid.Column="1" Orientation="Vertical" VerticalAlignment="Center" Margin="10,0,0,0">
        <CheckBox x:Name="ChkRestore" Content="Creeaza punct de restaurare inainte" IsChecked="True" Margin="0,0,0,6"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <TextBlock x:Name="SelCount" VerticalAlignment="Center" Foreground="#A9A9C8" Margin="0,0,10,0"/>
          <Button x:Name="BtnApply" Content="APLICA SELECTIA" Background="#7C5CFF" FontWeight="Bold" Padding="24,10" Margin="0"/>
        </StackPanel>
      </StackPanel>
    </Grid>

    <StackPanel Grid.Row="3" Margin="0,10,0,8">
      <TextBlock x:Name="StatusText" Foreground="#A9A9C8" Margin="0,0,0,4" Text="Pregatit"/>
      <ProgressBar x:Name="Progress" Height="8" Minimum="0" Maximum="100" Value="0" Background="#2A2A40" Foreground="#7C5CFF" BorderThickness="0"/>
    </StackPanel>

    <TextBox Grid.Row="4" x:Name="LogBox" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
             Background="#0E0E17" Foreground="#CFCFE6" BorderThickness="0" Padding="10" FontFamily="Consolas" FontSize="12"/>
  </Grid>
</Window>
'@

$HelpContent = @'
CUM FOLOSESTI
1. Bifeaza optiunile dorite. "Selecteaza Recomandat" si "Selecteaza Maxim" aleg automat seturi predefinite.
2. Apasa APLICA SELECTIA. Inainte de orice modificare se creeaza un punct de restaurare (daca lasi bifa activa).
3. La final reporneste PC-ul.

NIVELURI
RECOMANDAT - sigur pentru orice PC.
MAXIM - castig suplimentar de resurse, cu compromisurile explicate in descrierea fiecarei optiuni.
MANUAL - doar daca stii sigur ca nu ai nevoie de functia respectiva (nu este inclus in niciun set automat).

CUM ESTE IMPIEDICATA REVENIREA AI PRIN UPDATE-URI
- Politici de sistem in registru, pe care Windows Update nu le sterge.
- Pachetele eliminate sunt marcate "Deprovisioned", ca Windows sa nu le reinstaleze si sa nu le dea conturilor noi.
- Task-ul programat \Win11Lite\Win11Lite-ProtectieAI (ruleaza ca SYSTEM) reaplica eliminarea AI la fiecare pornire, la autentificare si zilnic. Daca un update readuce Copilot, este sters din nou. Jurnal: C:\ProgramData\Win11Lite\Logs\Reapply.log
- Optional: oprirea livrarii timpurii de functii noi si a actualizarilor automate din Store.

CUM ANULEZI
- "Restaurare sistem" deschide System Restore: alege punctul "Win11Lite - inainte de modificari".
- "Elimina protectia" sterge task-ul programat. Setarile deja aplicate raman; dupa aceea poti reinstala Copilot din Microsoft Store daca vrei.

CE NU MODIFICA SCRIPTUL (intentionat)
Windows Defender, Windows Update (actualizarile de securitate), firewall-ul, UAC, memoria virtuala si compresia memoriei raman neatinse. Dezactivarea lor ar face PC-ul vulnerabil sau instabil fara un castig real de performanta.
Functiile de accesibilitate (Narator, Voice Access, Live Captions) si Windows Studio Effects (driverul camerei) nu sunt atinse.

NOTE
- Pe Windows 11 Home unele politici de grup sunt ignorate de sistem; scriptul aplica si setarile echivalente pentru fiecare utilizator.
- In Setari si in Edge poate aparea mesajul "Unele setari sunt gestionate de organizatia ta" - este efectul normal al politicilor aplicate.
- Setarile per utilizator se aplica tuturor conturilor conectate si profilului implicit (conturile create ulterior).
- Jurnalele fiecarei rulari: C:\ProgramData\Win11Lite\Logs
'@

[xml]$xamlXml = $Xaml
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xamlXml))

$ui = @{}
foreach ($n in @('SysInfo', 'SysWarn', 'VersionText', 'Tabs', 'AiPanel', 'PerfPanel', 'HelpText', 'BtnRec', 'BtnMax', 'BtnNone',
                 'BtnScan', 'BtnRestore', 'BtnUnguard', 'BtnLogs', 'ChkRestore', 'BtnApply', 'SelCount', 'StatusText', 'Progress', 'LogBox')) {
    $ui[$n] = $window.FindName($n)
}

$script:BrushConv  = New-Object System.Windows.Media.BrushConverter
$script:CheckBoxes = @{}
$script:Running    = $false
$script:LastWasApply = $false

function New-Brush([string]$Color) { return $script:BrushConv.ConvertFromString($Color) }
function New-Thick([double]$l, [double]$t, [double]$r, [double]$b) { return New-Object System.Windows.Thickness($l, $t, $r, $b) }

function Add-UiLog([string]$Text) {
    $ui.LogBox.AppendText(('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Text) + [Environment]::NewLine)
    $ui.LogBox.ScrollToEnd()
}

function Update-SelCount {
    $n = @($script:CheckBoxes.Values | Where-Object { $_.IsChecked -eq $true }).Count
    $ui.SelCount.Text = ('{0} optiuni selectate' -f $n)
}

function Add-ItemCards($Panel, [string]$Tab) {
    $groups = New-Object System.Collections.Generic.List[string]
    foreach ($it in $global:W11Items) { if ($it.Tab -eq $Tab -and -not $groups.Contains($it.Group)) { $groups.Add($it.Group) } }
    foreach ($g in $groups) {
        $h = New-Object System.Windows.Controls.TextBlock
        $h.Text = $g
        $h.FontSize = 16
        $h.FontWeight = [System.Windows.FontWeights]::Bold
        $h.Foreground = New-Brush '#B9A8FF'
        $h.Margin = New-Thick 2 14 0 8
        [void]$Panel.Children.Add($h)

        foreach ($it in @($global:W11Items | Where-Object { $_.Tab -eq $Tab -and $_.Group -eq $g })) {
            $card = New-Object System.Windows.Controls.Border
            $card.Background = New-Brush '#24243A'
            $card.CornerRadius = New-Object System.Windows.CornerRadius(8)
            $card.Padding = New-Thick 14 10 14 10
            $card.Margin = New-Thick 0 0 0 8

            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Tag = $it.Id
            $cb.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Top

            $sp = New-Object System.Windows.Controls.StackPanel
            $sp.Margin = New-Thick 8 0 0 0

            $row = New-Object System.Windows.Controls.WrapPanel
            $title = New-Object System.Windows.Controls.TextBlock
            $title.Text = $it.Title
            $title.FontSize = 14
            $title.FontWeight = [System.Windows.FontWeights]::SemiBold
            $title.Foreground = New-Brush '#FFFFFF'
            $title.TextWrapping = [System.Windows.TextWrapping]::Wrap
            [void]$row.Children.Add($title)

            $badgeColor = '#3FB950'; $badgeText = 'RECOMANDAT'
            if ($it.Level -eq 'max')    { $badgeColor = '#F0883E'; $badgeText = 'MAXIM' }
            if ($it.Level -eq 'manual') { $badgeColor = '#8B949E'; $badgeText = 'MANUAL' }
            $badge = New-Object System.Windows.Controls.Border
            $badge.Background = New-Brush $badgeColor
            $badge.CornerRadius = New-Object System.Windows.CornerRadius(4)
            $badge.Padding = New-Thick 7 1 7 1
            $badge.Margin = New-Thick 10 1 0 0
            $badge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $bt = New-Object System.Windows.Controls.TextBlock
            $bt.Text = $badgeText
            $bt.FontSize = 10
            $bt.FontWeight = [System.Windows.FontWeights]::Bold
            $bt.Foreground = New-Brush '#14141F'
            $badge.Child = $bt
            [void]$row.Children.Add($badge)

            $desc = New-Object System.Windows.Controls.TextBlock
            $desc.Text = $it.Desc
            $desc.Foreground = New-Brush '#A9A9C8'
            $desc.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $desc.Margin = New-Thick 0 4 0 0

            [void]$sp.Children.Add($row)
            [void]$sp.Children.Add($desc)
            $cb.Content = $sp
            $cb.Add_Checked({ Update-SelCount })
            $cb.Add_Unchecked({ Update-SelCount })
            $card.Child = $cb
            [void]$Panel.Children.Add($card)
            $script:CheckBoxes[$it.Id] = $cb
        }
    }
}

function Set-Preset([string]$Mode) {
    foreach ($it in $global:W11Items) {
        $cb = $script:CheckBoxes[$it.Id]
        switch ($Mode) {
            'rec'  { $cb.IsChecked = ($it.Level -eq 'rec') }
            'max'  { $cb.IsChecked = ($it.Level -eq 'rec' -or $it.Level -eq 'max') }
            'none' { $cb.IsChecked = $false }
        }
    }
    Update-SelCount
}

function Set-UiEnabled([bool]$Enabled) {
    foreach ($n in @('BtnRec', 'BtnMax', 'BtnNone', 'BtnScan', 'BtnUnguard', 'BtnApply', 'ChkRestore', 'AiPanel', 'PerfPanel')) {
        $ui[$n].IsEnabled = $Enabled
    }
}

# ---------------------------------------------------------------- rulare in fundal
$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromMilliseconds(200)

function Receive-JobOutput {
    if (-not $script:Sync) { return }
    $line = $null
    $sb = New-Object System.Text.StringBuilder
    while ($script:Sync.Queue.TryDequeue([ref]$line)) { [void]$sb.AppendLine($line) }
    if ($sb.Length -gt 0) { $ui.LogBox.AppendText($sb.ToString()); $ui.LogBox.ScrollToEnd() }
}

function Start-W11Job([string[]]$Ids, [bool]$RestorePoint) {
    $script:Running = $true
    Set-UiEnabled $false
    $ui.Progress.Value = 0
    $ui.StatusText.Text = 'Pornire...'
    $script:Sync = [hashtable]::Synchronized(@{
        Queue    = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
        Progress = 0
        Status   = 'Pornire...'
        Done     = $false
        Warn     = 0
    })
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    try { $iss.ExecutionPolicy = [Microsoft.PowerShell.ExecutionPolicy]::Bypass } catch { }
    $rs = [runspacefactory]::CreateRunspace($iss)
    $rs.ThreadOptions = 'ReuseThread'
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('W11Sync', $script:Sync)
    $rs.SessionStateProxy.SetVariable('W11JobIds', $Ids)
    $rs.SessionStateProxy.SetVariable('W11JobRP', $RestorePoint)
    $rs.SessionStateProxy.SetVariable('W11ScriptFile', $global:W11ScriptFile)
    $script:Ps = [powershell]::Create()
    $script:Ps.Runspace = $rs
    [void]$script:Ps.AddScript($CoreCode + [Environment]::NewLine + 'Invoke-W11Run -Ids $W11JobIds -RestorePoint $W11JobRP')
    $script:Handle = $script:Ps.BeginInvoke()
    $script:Timer.Start()
}

function Complete-W11Job {
    Receive-JobOutput
    try { [void]$script:Ps.EndInvoke($script:Handle) } catch { Add-UiLog ('[!] {0}' -f $_.Exception.Message) }
    try {
        $errs = @($script:Ps.Streams.Error)
        foreach ($e in ($errs | Select-Object -First 10)) { Add-UiLog ('[!] {0}' -f $e) }
    } catch { }
    try { $script:Ps.Runspace.Close(); $script:Ps.Dispose() } catch { }
    $script:Running = $false
    Set-UiEnabled $true
    $ui.Progress.Value = 100
    if ($script:LastWasApply) {
        $ui.StatusText.Text = ('Terminat - avertismente: {0}. Reporneste PC-ul.' -f $script:Sync.Warn)
        $msg = "Operatiunile s-au terminat.`n`nAvertismente: $($script:Sync.Warn) (detalii in jurnal).`n`nPentru a finaliza modificarile este necesara repornirea PC-ului.`nRepornesti acum?"
        $r = [System.Windows.MessageBox]::Show($msg, 'Win11 Lite', 'YesNo', 'Information')
        if ($r -eq 'Yes') { Restart-Computer -Force }
    } else {
        $ui.StatusText.Text = 'Scanare terminata'
    }
}

$script:Timer.Add_Tick({
    Receive-JobOutput
    if ($script:Sync) {
        $ui.Progress.Value = $script:Sync.Progress
        $ui.StatusText.Text = $script:Sync.Status
        if ($script:Sync.Done) {
            $script:Timer.Stop()
            Complete-W11Job
        }
    }
})

# ---------------------------------------------------------------- evenimente
$ui.BtnRec.Add_Click({ Set-Preset 'rec' })
$ui.BtnMax.Add_Click({ Set-Preset 'max' })
$ui.BtnNone.Add_Click({ Set-Preset 'none' })

$ui.BtnScan.Add_Click({
    $script:LastWasApply = $false
    Start-W11Job -Ids @('__scan') -RestorePoint $false
})

$ui.BtnRestore.Add_Click({
    try { Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\rstrui.exe') } catch { Add-UiLog ('[!] {0}' -f $_.Exception.Message) }
})

$ui.BtnUnguard.Add_Click({
    $r = [System.Windows.MessageBox]::Show("Elimini task-ul de protectie automata?`n`nSetarile deja aplicate raman, dar AI-ul ar putea reveni prin update-uri.", 'Win11 Lite', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }
    if (Uninstall-W11Guard) { Add-UiLog 'Protectia automata a fost eliminata.' } else { Add-UiLog 'Protectia automata nu era instalata.' }
})

$ui.BtnLogs.Add_Click({
    if (-not (Test-Path -LiteralPath $global:W11LogDir)) { New-Item -ItemType Directory -Path $global:W11LogDir -Force | Out-Null }
    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $global:W11LogDir)
})

$ui.BtnApply.Add_Click({
    $ids = @($global:W11Items | Where-Object { $script:CheckBoxes[$_.Id].IsChecked -eq $true } | ForEach-Object { $_.Id })
    if ($ids.Count -eq 0) {
        [void][System.Windows.MessageBox]::Show('Nu ai selectat nicio optiune.', 'Win11 Lite', 'OK', 'Information')
        return
    }
    $msg = "Vor fi aplicate $($ids.Count) optiuni.`n`nDezinstalarea pachetelor si eliminarea Recall pot fi anulate doar prin Restaurare sistem.`n`nContinui?"
    $r = [System.Windows.MessageBox]::Show($msg, 'Win11 Lite - confirmare', 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return }
    $script:LastWasApply = $true
    Start-W11Job -Ids $ids -RestorePoint ([bool]$ui.ChkRestore.IsChecked)
})

$window.Add_Closing({
    param($src, $evt)
    if ($script:Running) {
        [void][System.Windows.MessageBox]::Show('Asteapta terminarea operatiunilor in curs.', 'Win11 Lite', 'OK', 'Warning')
        $evt.Cancel = $true
    }
})

# Ecrane mici (ex. laptop 1366x768): fereastra nu depaseste zona de lucru
$workArea = [System.Windows.SystemParameters]::WorkArea
if ($window.Height -gt ($workArea.Height - 10)) { $window.Height = [math]::Max(600, $workArea.Height - 10) }
if ($window.Width -gt ($workArea.Width - 10))   { $window.Width  = [math]::Max(900, $workArea.Width - 10) }

# ---------------------------------------------------------------- initializare
$ui.VersionText.Text = 'v' + $global:W11Version
$ui.HelpText.Text = $HelpContent
Add-ItemCards $ui.AiPanel 'AI'
Add-ItemCards $ui.PerfPanel 'PERF'

$si = Get-W11SysInfo
$kind = 'Desktop'
if ($si.IsLaptop) { $kind = 'Laptop' }
$ui.SysInfo.Text = ('{0} {1} (build {2}.{3})   |   RAM: {4} GB   |   CPU: {5}   |   Disc sistem: {6}   |   {7}' -f `
    $si.Name, $si.Display, $si.Build, $si.UBR, $si.RamGB, $si.Cpu, $si.Disk, $kind)

$warn = @()
if ($si.Build -lt 22000) { $warn += 'Atentie: acest sistem nu este Windows 11 - unele optiuni nu se aplica.' }
if ($si.IsHome)          { $warn += 'Windows 11 Home: unele politici de grup sunt ignorate; scriptul aplica si echivalentele per utilizator.' }
if ($si.IsLaptop)        { $warn += 'Laptop: planul de performanta maxima consuma mai multa baterie.' }
if ($si.RamGB -gt 0 -and $si.RamGB -le 4) { $warn += 'RAM putina: merita bifate si SysMain + indexarea din setul Maxim.' }
if ($si.Disk -eq 'HDD')  { $warn += 'Disc HDD: merita dezactivate SysMain si indexarea (setul Maxim).' }
$ui.SysWarn.Text = ($warn -join '   ')
if ($warn.Count -eq 0) { $ui.SysWarn.Visibility = 'Collapsed' }

if ($si.Build -lt 22000) {
    $r = [System.Windows.MessageBox]::Show('Acest script este facut pentru Windows 11. Continui pe propria raspundere?', 'Win11 Lite', 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return }
}

Set-Preset 'rec'
Add-UiLog 'Pregatit. Bifeaza optiunile dorite si apasa APLICA SELECTIA.'
Add-UiLog 'Sfat: apasa "Verifica sistemul" pentru a vedea ce componente AI sunt instalate acum.'

[void]$window.ShowDialog()
