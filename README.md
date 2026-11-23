# Win11 Lite

Script PowerShell cu interfață grafică pentru **Windows 11** care:

- **elimină funcțiile AI**: Copilot, Microsoft 365 Copilot, Recall, Click to Do, agentul din Setări, funcțiile agentice, AI din Edge / Paint / Notepad / Office / Căutare, accesul aplicațiilor la AI generativ, serviciile și pachetele AI de sistem;
- **împiedică revenirea AI prin update-uri** (politici de sistem, pachete marcate „Deprovisioned” și un task programat care reaplică totul la pornire, la autentificare și zilnic);
- **optimizează Windows 11 pentru PC-uri slabe** (plan de alimentare, efecte vizuale, servicii, telemetrie, reclame, aplicații preinstalate, aplicații de fundal, curățare disc).

---

## Descărcare și rulare (pe orice PC cu internet)

1. Intră pe GitHub cu contul tău și deschide fișierul [`Win11Lite.ps1`](Win11Lite.ps1) din acest repository.
2. Apasă **Download raw file** (iconița de descărcare din dreapta sus). Fișierul ajunge în folderul **Descărcări / Downloads**.
3. Deschide **PowerShell ca Administrator** (Start → scrie `powershell` → *Executare ca administrator*) și rulează:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
& "$env:USERPROFILE\Downloads\Win11Lite.ps1"
```

Dacă fișierul e în alt folder: în File Explorer ține **Shift**, click-dreapta pe fișier → **Copiere ca cale**, apoi în PowerShell scrie `& ` și lipește calea.

Dacă pornești scriptul din PowerShell 7 sau fără drepturi de administrator, se redeschide singur în Windows PowerShell 5.1 și cere elevarea (UAC).

### Rulare cu o singură comandă (doar dacă repository-ul devine public)

Cât timp repository-ul este **privat**, varianta de mai sus (cu autentificare în browser) este cea care funcționează. Dacă îl faci public, poți descărca și porni scriptul direct, fără autentificare:

```powershell
$f = "$env:TEMP\Win11Lite.ps1"
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/MariusGabrielPetre/Windows-11-Remov-AI/main/Win11Lite.ps1" -OutFile $f
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $f
```

---

## Cum se folosește

1. Bifează opțiunile dorite. Butoanele **Selectează Recomandat** și **Selectează Maxim** aleg automat seturi predefinite.
2. Apasă **APLICĂ SELECȚIA**. Înainte de modificări se creează un punct de restaurare (opțiune bifată implicit).
3. Repornește PC-ul la final.

| Nivel | Semnificație |
|---|---|
| **RECOMANDAT** | sigur pentru orice PC |
| **MAXIM** | câștig suplimentar de resurse, cu compromisurile explicate în descrierea fiecărei opțiuni |
| **MANUAL** | doar dacă știi sigur că nu ai nevoie de funcția respectivă |

Butonul **Verifică sistemul** arată ce componente AI sunt instalate și dacă protecția automată este activă. Merită rulat după fiecare update mare de Windows.

## Protecția împotriva update-urilor

- politici de sistem în registru, pe care Windows Update nu le șterge;
- pachetele eliminate sunt marcate „Deprovisioned”, ca Windows să nu le reinstaleze și să nu le dea conturilor noi;
- task-ul programat `\Win11Lite\Win11Lite-ProtectieAI` (rulează ca SYSTEM) reaplică eliminarea AI la pornire, la autentificare și zilnic.

Fișiere locale: `C:\ProgramData\Win11Lite` (scriptul copiat, `config.json`, jurnale în `Logs\`).

## Cum anulezi

- **Restaurare sistem** (buton în interfață) → alege punctul „Win11Lite - inainte de modificari”.
- **Elimină protecția** (buton în interfață) șterge task-ul programat; setările deja aplicate rămân.

## Ce NU modifică (intenționat)

Windows Defender, Windows Update (actualizările de securitate), firewall-ul, UAC, memoria virtuală și compresia memoriei rămân neatinse. Funcțiile de accesibilitate (Narator, Voice Access, Live Captions) nu sunt atinse.

## Note

- Cerințe: Windows 11, Windows PowerShell 5.1 (inclus în Windows), drepturi de administrator.
- Pe Windows 11 Home unele politici de grup sunt ignorate; scriptul aplică și setările echivalente per utilizator.
- În Setări și în Edge poate apărea mesajul „Unele setări sunt gestionate de organizația ta” – este efectul normal al politicilor.
- Nu rula scriptul pe PC-uri administrate de un departament IT fără acordul acestuia.
- Folosește-l pe propria răspundere; testează-l întâi pe un PC de test sau într-o mașină virtuală.
