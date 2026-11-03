# powershellops

Windows sistem yöneticileri için PowerShell betikleri. Active Directory, sistem sağlığı, ağ, dosya ve CSV işlemleri için hazır araçlar içerir. Her modül kendi klasöründedir ve birbirinden bağımsız çalışır.

## İçindekiler

| Modül | Klasör | Ne işe yarar |
|---|---|---|
| [Kök betikler](#root) | `/` | EmployeeType ataması, Word belgesini PDF'e çevirme |
| [csvOP](#csvop) | `csvOP/` | CSV verisinde desen arama ve sütun ekleme |
| [adops](#adops) | `adops/` | Uzun süredir oturum açmamış kullanıcılar, parola süresi raporu, toplu EmployeeType ataması |
| [systemops](#systemops) | `systemops/` | Disk alanı, servis durumu ve olay günlüğü raporları |
| [networkops](#networkops) | `networkops/` | Paralel alt ağ taraması, TCP port testi |
| [fileops](#fileops) | `fileops/` | Eski dosyaları temizleme, kopya dosyaları bulma |
| [CI](#ci) | `.github/workflows/` | PSScriptAnalyzer ile otomatik kod denetimi |

## Hızlı başlangıç

```powershell
git clone https://github.com/Onur-TURAN/powershellops.git
cd powershellops

# İnternetten indirilen betikleri çalıştırabilmek için gerekirse:
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# Her betiğin ayrıntılı yardımı vardır:
Get-Help .\systemops\Get-DiskSpaceReport.ps1 -Full
```

Ortak özellikler:
- Tüm betikler **Windows PowerShell 5.1** ile uyumludur ve PowerShell 7'de de çalışır.
- Yeni betikler ekrana yazı basmak yerine **nesne döndürür**. Çıktıyı `Where-Object`, `Sort-Object` veya `Export-Csv` ile işleyebilirsiniz. Çoğunda doğrudan CSV dosyasına yazmak için `-OutputPath` parametresi vardır.
- Değişiklik yapan betikler (`Set-EmployeeTypeBulk`, `Test-ServiceHealth -Restart`, `Remove-OldFiles`) **`-WhatIf` ve `-Confirm`** destekler. Gerçek çalıştırmadan önce `-WhatIf` ile ne yapılacağını görün.

---

<a id="root"></a>

## Kök betikler

### EmployeeType_change.ps1
`employeeType` alanı boş olan **ilk** aktif AD kullanıcısına `Contractor` değerini atar. Bu tek kullanıcılık bir örnektir. Toplu işlem için [Set-EmployeeTypeBulk.ps1](#adops) betiğini kullanın.

**Gereksinim:** `ActiveDirectory` modülü ve ilgili kullanıcı üzerinde yazma yetkisi.

```powershell
.\EmployeeType_change.ps1
```

### pdfgenerate.ps1
Microsoft Word'ü arka planda (COM) açıp `GeneratedDocument.docx` belgesini aynı klasöre `GeneratedDocument.pdf` olarak kaydeder. Belgenin bulunduğu klasör, betiğin başındaki `$document_path` değişkeninde ayarlanır. Klasör yoksa betik klasörü oluşturur ve durur.

**Gereksinim:** Bilgisayarda Microsoft Word kurulu olmalı.

```powershell
# $document_path değişkenini düzenledikten sonra:
.\pdfgenerate.ps1
```

---

<a id="csvop"></a>

## csvOP — CSV İşlemleri

SQL sorgusu içeren CSV veri setlerini etiketlemek için birbirinin devamı olan üç adım. Betikler çalıştırıldıkları klasördeki dosyaları okur ve yazar.

### 01_searchpattern.ps1
`traintrue.csv` dosyasındaki her satırın `Query` sütununu, kullanıcının virgülle ayırarak girdiği regex desenleriyle karşılaştırır. Sonucu `Query`, `Label` ve `Match` (1/0) sütunlarıyla `results.csv` dosyasına yazar.

```powershell
cd csvOP
.\01_searchpattern.ps1
# Enter patterns to search for, separated by commas: SELECT,UNION,OR 1=1
```

### 02_updated_file.ps1
`trainfalse.csv` dosyasındaki her satırın sonuna `,0` ekler ve dosyayı yerinde günceller.
> Dikkat: Başlık satırına da `,0` eklenir.

### 03_searchafter.ps1
`results.csv` dosyasını okur. Satırları `Query`, `Label`, `SELECT`, `UNION`, `OR` ve `AND` sütunlarıyla yeniden oluşturur, kullanıcının adını ve değerini girdiği yeni bir sütun ekler ve sonucu `alldata.csv` dosyasına yazar.

---

<a id="adops"></a>

## adops — Active Directory İşlemleri

`adops/` klasöründe Active Directory ortamlarında sık yapılan yönetim işleri için PowerShell betikleri var. Betikler ekrana yazı basmak (`Write-Host`) yerine nesne döndürür. Bu yüzden çıktıyı `Export-Csv`, `Where-Object` gibi komutlarla doğrudan işleyebilirsiniz.

**Gereksinimler**
- Windows PowerShell 5.1 veya üzeri
- `ActiveDirectory` modülü (RSAT: Active Directory DS Tools)
- AD'de okuma yetkisi. `Set-EmployeeTypeBulk.ps1` için ilgili kullanıcılar üzerinde yazma yetkisi de gerekir.

### Get-InactiveADUsers.ps1
Belirtilen gün sayısından uzun süredir oturum açmamış ya da hiç oturum açmamış kullanıcıları listeler. `LastLogonTimestamp` özniteliğini kullanır. Bu değer replikasyon yüzünden 14 güne kadar geride olabilir.

| Parametre | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `-DaysInactive` | int | 90 | Kaç gün oturum açılmazsa hesap hareketsiz sayılır |
| `-SearchBase` | string | (tüm domain) | Aranacak OU'nun DN değeri |
| `-OutputPath` | string | - | Verilirse sonuçlar bu CSV dosyasına yazılır |
| `-IncludeDisabled` | switch | kapalı | Devre dışı hesapları da listeye ekler |

Çıktı alanları: SamAccountName, Name, Enabled, LastLogonDate, DaysSinceLogon, DistinguishedName.

```powershell
.\adops\Get-InactiveADUsers.ps1 -DaysInactive 120
.\adops\Get-InactiveADUsers.ps1 -SearchBase "OU=Sales,DC=contoso,DC=com" -OutputPath .\inactive.csv -IncludeDisabled
```

### Get-PasswordExpiryReport.ps1
Parolasının süresi yakında dolacak veya çoktan dolmuş aktif kullanıcıları raporlar. `msDS-UserPasswordExpiryTimeComputed` özniteliğini kullanır. Parolası süresiz olan hesapları ve devre dışı hesapları atlar.

| Parametre | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `-WithinDays` | int | 14 | Kaç gün içinde dolacak parolaların listeleneceği |
| `-OutputPath` | string | - | Verilirse sonuçlar bu CSV dosyasına yazılır |

Çıktı alanları: SamAccountName, Name, EmailAddress, ExpiryDate, DaysLeft. Süresi dolmuş parolalarda DaysLeft negatiftir.

```powershell
.\adops\Get-PasswordExpiryReport.ps1
.\adops\Get-PasswordExpiryReport.ps1 -WithinDays 30 -OutputPath .\expiry.csv
```

### Set-EmployeeTypeBulk.ps1
`employeeType` değeri boş olan aktif kullanıcılara toplu olarak değer atar. Dolu olan değerlerin **üzerine yazmaz**. `-WhatIf` ve `-Confirm` parametrelerini destekler. Gerçek değişiklikten önce `-WhatIf` ile denemeniz önerilir.

| Parametre | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `-EmployeeType` | string (zorunlu) | - | `Employee`, `Contractor`, `Intern` veya `Vendor` |
| `-SearchBase` | string | (tüm domain) | Aranacak OU'nun DN değeri |
| `-Limit` | int | 0 | En fazla kaç kullanıcının değiştirileceği (0 = sınırsız) |

Çıktı: her kullanıcı için SamAccountName, EmployeeType ve Status (Updated / Skipped / Failed).

```powershell
.\adops\Set-EmployeeTypeBulk.ps1 -EmployeeType Employee -SearchBase "OU=Staff,DC=contoso,DC=com" -WhatIf
.\adops\Set-EmployeeTypeBulk.ps1 -EmployeeType Intern -Limit 10
```

---

<a id="systemops"></a>

## systemops — Sistem Sağlığı ve İzleme

`systemops/` klasöründe Windows sistemlerinin disk alanını, servis durumunu ve olay günlüğü hatalarını izlemek için üç bağımsız betik var. Betikler nesne döndürür. Çıktıyı `|` ile filtreleyebilir, sıralayabilir veya CSV dosyasına aktarabilirsiniz.

**Gereksinimler**
- Windows PowerShell 5.1 veya üzeri
- Uzak bilgisayarları sorgulamak için WinRM (CIM) erişimi ve uygun yetki
- `-Restart` için hedef bilgisayarda servis başlatma yetkisi (genellikle yönetici)
- `Security` gibi bazı günlükleri okumak için yönetici yetkisi

> Not: CSV dosyasındaki sayılar sistemin bölge ayarına göre yazılır. Türkçe sistemde ondalık ayırıcı virgüldür (`298,12`).

### Get-DiskSpaceReport.ps1
Sabit disklerin (DriveType=3) toplam boyutunu, boş alanını ve boş alan yüzdesini raporlar. Boş alan yüzdesi eşiğin altındaysa durum `Warning`, değilse `OK` olur. Bir bilgisayara ulaşılamazsa uyarı verilir ve diğer bilgisayarlar taranmaya devam eder.

| Parametre | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `-ComputerName` | string[] | Yerel bilgisayar | Sorgulanacak bilgisayarların adları |
| `-WarningPercent` | int | 15 | Boş alan yüzdesi bu değerin altındaysa durum `Warning` olur (1–100) |
| `-OutputPath` | string | - | Verilirse sonuçlar bu CSV dosyasına yazılır |

```powershell
.\systemops\Get-DiskSpaceReport.ps1
.\systemops\Get-DiskSpaceReport.ps1 -ComputerName SRV01,SRV02 -WarningPercent 20 -OutputPath C:\Reports\disk.csv
```

### Test-ServiceHealth.ps1
Verilen servislerin durumunu (`Status`) ve başlangıç türünü (`StartType`) raporlar. `-Restart` verilirse, başlangıç türü `Automatic` olup durmuş olan servisleri başlatır ve servis çalışır duruma gelene kadar en fazla 30 saniye bekler. `-WhatIf` ve `-Confirm` desteklenir. Bulunamayan servisler `NotFound` durumuyla listelenir.

| Parametre | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `-ServiceName` | string[] (zorunlu) | - | Servis adları (ör. `Spooler`, `W32Time`) |
| `-ComputerName` | string[] | Yerel bilgisayar | Sorgulanacak bilgisayarların adları |
| `-Restart` | switch | kapalı | Durmuş ve başlangıç türü `Automatic` olan servisleri başlatır |

```powershell
.\systemops\Test-ServiceHealth.ps1 -ServiceName Spooler,W32Time
.\systemops\Test-ServiceHealth.ps1 -ServiceName Spooler -ComputerName SRV01,SRV02 -Restart -WhatIf
```

### Export-EventLogErrors.ps1
Belirtilen günlüklerde son `-Hours` saat içinde oluşmuş ve seviyesi **tam olarak** `-Level` olan olayları toplar. Örneğin `Warning` seçildiğinde Error ve Critical olaylar gelmez. Her olay için TimeCreated, LogName, Id, ProviderName, LevelDisplayName ve mesajın ilk satırını döndürür. Eşleşen olay yoksa hata vermeden boş sonuç döner.

| Parametre | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `-LogName` | string[] | `System`, `Application` | Okunacak olay günlükleri |
| `-Hours` | int | 24 | Kaç saat geriye bakılacağı (1–8760) |
| `-Level` | string | `Error` | `Critical`, `Error` veya `Warning` |
| `-OutputPath` | string | - | Verilirse sonuçlar bu CSV dosyasına yazılır |

```powershell
.\systemops\Export-EventLogErrors.ps1 -Hours 2
.\systemops\Export-EventLogErrors.ps1 -LogName System -Hours 72 -Level Critical -OutputPath C:\Reports\critical.csv
```

---

<a id="networkops"></a>

## networkops — Ağ İşlemleri

Ağdaki cihazları keşfetmek ve bağlantıları test etmek için betikler. **Yalnızca size ait olan ya da test etme yetkiniz bulunan ağları ve sistemleri tarayın.**

### IPtesting.ps1 (eski sürüm)
İlk sürümden kalan betik. Taranacak alt ağlar (`192.168.1`, `10.0.0`, `172.16.0`) ve CSV yolu kodun içine yazılmıştır. Her alt ağda `.1` ile `.255` arasındaki adreslere `Test-Connection` ile sırayla ping atar ve yanıt veren adreslerin DNS adını çözer. Adresleri tek tek denediği için yavaştır. Geriye dönük uyumluluk için olduğu gibi bırakıldı. Yeni kullanımlar için `Invoke-SubnetSweep.ps1` önerilir.

### Invoke-SubnetSweep.ps1
Bir veya birden çok /24 alt ağı paralel olarak tarar. `Ping.SendPingAsync` ile `-ThrottleLimit` büyüklüğünde gruplar halinde ping atar. Windows PowerShell 5.1'de çalışır, `ForEach-Object -Parallel` gerektirmez. İsteğe bağlı olarak yanıt veren adreslerin DNS adını çözer. Çıktı sütunları: IP, Reachable, RoundtripMs, HostName.

| Parametre | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `-Subnet` | string[] (zorunlu) | - | Alt ağın ilk üç okteti, ör. `192.168.1` |
| `-Start` | int | 1 | Taramanın başladığı son oktet (1–254) |
| `-End` | int | 254 | Taramanın bittiği son oktet (1–254, `-Start` değerinden küçük olamaz) |
| `-TimeoutMs` | int | 500 | Her ping için zaman aşımı (ms) |
| `-ThrottleLimit` | int | 64 | Aynı anda gönderilen en fazla ping sayısı |
| `-ResolveDns` | switch | kapalı | Yanıt veren adreslerin host adını çözer |
| `-OutputPath` | string | - | Verilirse sonuçlar bu CSV dosyasına yazılır |

```powershell
.\networkops\Invoke-SubnetSweep.ps1 -Subnet 192.168.1
.\networkops\Invoke-SubnetSweep.ps1 -Subnet 10.0.0,10.0.1 -ResolveDns -OutputPath C:\temp\sweep.csv
.\networkops\Invoke-SubnetSweep.ps1 -Subnet 172.16.0 -Start 1 -End 50 -TimeoutMs 250 | Where-Object Reachable
```

### Test-TcpPort.ps1
Bir veya birden çok sunucuda TCP portlarının açık olup olmadığını kontrol eder. Her bağlantı denemesi `-TimeoutMs` sonunda kesilir. Kendi altyapınızda bir servisin dinleyip dinlemediğini veya güvenlik duvarı kuralının doğru çalışıp çalışmadığını kontrol etmek için tasarlanmıştır. Çıktı sütunları: ComputerName, Port, Open.

| Parametre | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `-ComputerName` | string[] (zorunlu) | - | Host adları veya IP adresleri. Pipeline ile de verilebilir. |
| `-Port` | int[] (zorunlu) | - | Kontrol edilecek TCP portları (1–65535) |
| `-TimeoutMs` | int | 1000 | Her bağlantı denemesi için zaman aşımı (ms) |

```powershell
.\networkops\Test-TcpPort.ps1 -ComputerName localhost -Port 135,445
.\networkops\Test-TcpPort.ps1 -ComputerName web01,web02 -Port 80,443 -TimeoutMs 500 | Where-Object { -not $_.Open }
'db01','db02' | .\networkops\Test-TcpPort.ps1 -Port 1433
```

---

<a id="fileops"></a>

## fileops — Dosya İşlemleri

Eski dosyaları temizlemek ve kopya dosyaları bulmak için betikler.

### Remove-OldFiles.ps1
Bir klasörde son değiştirilme tarihi (`LastWriteTime`) belirtilen gün sayısından eski olan dosyaları siler. Her dosya için ayrı onay kontrolü yapıldığından `-WhatIf` ve `-Confirm` desteklenir. İsteğe bağlı olarak silinen her dosyayı log dosyasına yazar. Log, `-WhatIf` ile çalıştırıldığında da yazılır. İşlem sonunda bir özet döndürür: aday dosya sayısı, silinen ve silinemeyen dosya sayısı, boşaltılan alan (MB).

| Parametre | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `-Path` | string (zorunlu) | - | Temizlenecek klasör (var olmalı) |
| `-Days` | int (zorunlu) | - | Bu kadar günden eski dosyalar silinir |
| `-Filter` | string | `*` | Dosya adı filtresi, ör. `*.log` |
| `-Recurse` | switch | kapalı | Alt klasörleri de temizler |
| `-LogPath` | string | - | Silinen dosyaların yazılacağı log dosyası |

```powershell
# Önce ne silineceğini görün:
.\fileops\Remove-OldFiles.ps1 -Path D:\Logs -Days 30 -Filter *.log -WhatIf
# Sonra onay sormadan silin ve log tutun:
.\fileops\Remove-OldFiles.ps1 -Path D:\Temp -Days 7 -Recurse -LogPath D:\Logs\cleanup.log -Confirm:$false
```

### Find-DuplicateFiles.ps1
İçeriği aynı olan dosyaları bulur. Dosyaları önce boyutlarına göre gruplar ve yalnızca boyutu aynı olan dosyaların hash değerini hesaplar. Bu sayede büyük klasörlerde de hızlı çalışır. Boş (0 bayt) dosyalar atlanır. Her kopya kümesi için SetId, Hash, Length ve Path sütunlarını döndürür.

| Parametre | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `-Path` | string | `.` | Taranacak klasör |
| `-Recurse` | switch | kapalı | Alt klasörleri de tarar |
| `-Algorithm` | string | `SHA256` | `SHA1`, `SHA256`, `SHA384`, `SHA512` veya `MD5` |
| `-OutputPath` | string | - | Verilirse sonuçlar bu CSV dosyasına yazılır |

```powershell
.\fileops\Find-DuplicateFiles.ps1 -Path D:\Photos -Recurse
.\fileops\Find-DuplicateFiles.ps1 -Path \fs01\share -Recurse -Algorithm MD5 -OutputPath C:\temp\dupes.csv
# Her kümede ilk dosya dışındaki kopyaları listeleyin (silmeden önce gözden geçirmek için):
.\fileops\Find-DuplicateFiles.ps1 -Path D:\Data -Recurse | Group-Object SetId | ForEach-Object { $_.Group | Select-Object -Skip 1 }
```

---

<a id="ci"></a>

## CI — Kod Kalitesi

[.github/workflows/psscriptanalyzer.yml](.github/workflows/psscriptanalyzer.yml) her push ve pull request'te bütün `.ps1` dosyalarını [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) ile denetler. `Error` seviyesinde bulgu varsa iş başarısız olur. Kurallar [PSScriptAnalyzerSettings.psd1](PSScriptAnalyzerSettings.psd1) dosyasında ayarlanır.

Aynı denetimi yerelde çalıştırmak için:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
```

## Katkı

Hata bildirimi, özellik isteği ve mantık hatası için `.github/ISSUE_TEMPLATE/` altında hazır şablonlar var. Yeni bir betik eklerken:
- Betiğe uygun klasörü seçin veya yeni bir modül klasörü açın.
- Betiğe yorum tabanlı yardım (`.SYNOPSIS`, `.PARAMETER`, `.EXAMPLE`) ve `[CmdletBinding()]` ekleyin.
- Değişiklik yapan betiklerde `SupportsShouldProcess` kullanın.
- Betiği bu README'de kendi modülünün altında anlatın.

## Lisans

[LICENSE](LICENSE) dosyasına bakın.
