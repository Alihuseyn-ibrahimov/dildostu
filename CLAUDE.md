# DilDostu — operativ təlimat

Kontekstli AZ→EN dil öyrənmə Flutter app + FastAPI "Live" backend. Statik
paketlərdən (kafe/aeroport/...) canlı AI-yə keçid edilib: server GPS/vaxta görə
kontekst tapır, Groq/Claude ilə fərdi söz+nümunə yaradır, server əlçatmaz olsa
statik ehtiyat paketlərə düşür.

**Struktur:**

| Qovluq | Nədir |
|---|---|
| `app/` | Flutter app (`lib/src/`) — `data/` (HTTP client-lər), `ui/` (ekranlar), `models/`, `engine/` (kontekst/level məntiqi), `services/` (native köməkçilər) |
| `server/` | FastAPI backend (`dildostu_server/`) — prompt qurma, provayder fallback, endpoint-lər |
| `content_gen/` | MVP-nin statik paket JSON-larını yaradan skriptlər (`app/assets/packs/*.json`) |

## Mühit — ilk növbədə bil

- **Android build YALNIZ istifadəçinin öz terminalından** (`app/build_apk.bat`,
  `build_apk_play.bat`) — Claude-un sandbox-undan Gradle işləmir (pub-cache
  problemi, `url_launcher_android` kimi paketlərdə təkrarlanan xəta görülüb).
  Bax [feedback: env_gitbash_arg_transliteration] AZ hərfli arqumentlər üçün.
- Server tərəfi: `server/.venv/Scripts/python` (Windows venv), `PYTHONIOENCODING=utf-8`
  AZ mətn çap edəndə.
- Flutter PATH-də deyil, tam yol lazımdır: `"C:\Users\Alihuseyn Ibrahimov\flutter\bin"`.

## Deploy — İKİ AYRI ADDIM, biri digərini əvəz etmir

1. **APK (client) publish** — `server/deploy/publish_release.ps1`. `pubspec.yaml`-dan
   versiyanı oxuyub `app-direct-debug.apk`-nı SCP ilə VPS-ə göndərir
   (`/opt/dildostu/server/releases/`). Yalnız client kodunu yeniləyir.
2. **Server kodu deploy** — `/opt/dildostu/server` VPS-də **git repo DEYİL**,
   fayllar əl ilə/scp ilə köçürülüb. `DEPLOY.md`-dəki "git pull" addımı
   **işləmir**. Doğru yol:
   ```bash
   scp dildostu/server/dildostu_server/*.py root@68.183.210.59:/opt/dildostu/server/dildostu_server/
   ssh root@68.183.210.59 "cd /opt/dildostu/server && .venv/bin/python -c 'import dildostu_server.app' && systemctl restart dildostu-live"
   ```
   Yeni endpoint/model əlavə edəndən sonra bunu unutsan, app "404"/köhnə davranış
   görər — 2026-08-03-də essential-words endpoint-i saatlarla bu səbəbdən işləmədi.

Hər ikisindən sonra **canlı `curl` ilə yoxla** (mətnə/UI-ya güvənmə):
```bash
curl -s https://dildostu.prdostu.com/app/version   # {"version_code":N,...}
curl -s -X POST https://dildostu.prdostu.com/<endpoint> -d '{...}'
```

## Self-update mexanizmi — üç dəfə sınıb, üçünü də pozma

`app_update_client.dart` → `/app/version` + `/app/latest.apk` (Cloudflare
`no-store` başlıqları ilə). Zolaq aylarla görünmədi; üç ayrı səbəb vardı:

1. **Timeout (v15-də düzəldildi):** 150+ MB yükləmə üçün 20 saniyə verilirdi.
   İndi `_versionTimeout` (20s, kiçik JSON) və `_downloadTimeout` (5 dəq) ayrıdır.
2. **OOM (v17-də düzəldildi):** `get()...bodyBytes` bütün faylı yaddaşa yığırdı.
   İndi **axın** kimi (`send()` + çanaq-çanaq `sink.add`) birbaşa diskə yazılır.
3. **ƏSL SƏBƏB — sıra (v19-da düzəldildi):** `checkForUpdate()` banneri yalnız
   APK TAM yükləndikdən sonra qaytarırdı. İstifadəçi app-ı açanda heç bir əlamət
   görmür, arxada səssiz yükləmə gedir, app bağlananda itirdi → zolaq praktikada
   heç vaxt çıxmırdı. İndi `checkForUpdate()` **yalnız versiyanı yoxlayır**,
   zolaq dərhal görünür; yükləmə istifadəçi toxunanda, faiz göstəricisi ilə
   başlayır (`_startUpdate` + `onProgress`), uğursuzluqda "Yenidən cəhd et".

**Qayda:** yükləməni heç vaxt banner göstərilməzdən əvvələ qaytarma və heç bir
uğursuzluğu səssiz udma — istifadəçi hər mərhələni görməlidir.

Qırıq yükləmə mexanizmi özü-özünü yeniləyə bilməz (köhnə pozuq kod yeni APK-nı
yükləyə bilmir). Belə düzəlişlərdən sonra HƏMİŞƏ istifadəçiyə birbaşa link
göndər (`https://dildostu.prdostu.com/app/latest.apk`), əl ilə bir dəfə qurdur.

İlk versiyanın (v17-dən əvvəlki) yükləmə mexanizmi qırıq idi — bu növ qırıqlıq
özü-özünü yeniləyə bilməz (köhnə pozuq kodun özü yeni APK-nı yükləyə bilmir).
Belə "kritik yükləmə" düzəlişlərindən sonra HƏMİŞƏ istifadəçiyə birbaşa link
göndər (`https://dildostu.prdostu.com/app/latest.apk`), əl ilə bir dəfə qurdur.

## Groq günlük token limiti (100K TPD, pulsuz tier)

Bir "Əsas lüğət" partiyası (~12 söz) ~2.3K token yeyir — sıx test/generasiya
günündə limit tükənə bilər (`429 tokens_exceeded`, "Please try again in Nm").
`ANTHROPIC_API_KEY` VPS-də konfiqurasiya olunmayıb (2026-08-03 vəziyyəti) —
Groq uğursuz olanda Claude-a fallback YOXDUR, `complete_with_fallback` birbaşa
`AllProvidersFailed` atır → endpoint 502 qaytarır. Kütləvi generasiya (statik
asset üçün 40+ sorğu) lazım olsa, Cloudflare-i SSH tunellə yan keç
(`ssh -f -N -L 18100:127.0.0.1:8100 root@68.183.210.59`), checkpoint saxlayan
skriptlə işlə, limit sıfırlanana (~gecə saat 00:00 UTC) qədər gözlə.

## 504 Essential Words (Əsas lüğət)

Barron's "504 Absolutely Essential Words" kitabının YALNIZ söz→dərs indeksi
(faktiki, müəllif hüququ qorunmayan data) `server/dildostu_server/essential_words.py`-də.
Kitabın öz tərifləri/nümunələri/hekayələri HEÇ YERƏ köçürülməyib — hər sözün
tərcümə/IPA/nümunəsi bizim AI sistemimizlə (bax `build_essential_words_prompt`)
yaradılır. 42 dərs → 3 səviyyə (14 dərslik bloklar, 168 söz/səviyyə).

- **Server:** `POST /essential-words` — `{profile, offset, count}` →
  `{words, total, next_offset}` (dövriyyəli səhifələmə).
- **App onlayn:** `LiveContentClient.essentialWords()` → `EssentialWordsScreen`
  (ana səhifədə ayrıca kart, paket şəbəkəsindən müstəqil).
- **App offline:** `assets/essential/words.json` — bütün 504 sözün BİR DƏFƏLİK
  əvvəlcədən (production API-dən) yaradılmış statik nüsxəsi, `EssentialWordsRepository`
  vasitəsilə yüklənir. Server/internet yoxdursa `LiveContentClient` avtomatik
  bura düşür (eyni offset/total/wraparound qaydası ilə, `isLive: false`).
  Bu faylı yeniləmək lazım olsa: `POST /essential-words`-i hər səviyyə üçün
  14×12-lik dəstlərlə (168/12) çağırıb nəticəni `pack_id: "essential"` formatında
  birləşdir (bax köhnə skript nümunəsi — tək dəfəlik, runtime-a aid deyil).

## Səsli kitablar

İctimai domen mətn (Project Gutenberg) + **Piper TTS** (MIT, offline).
Dizayn: `docs/superpowers/specs/2026-08-04-audiobooks-design.md`.

**Audio HEÇ VAXT serverdə yaradılmır** — VPS-də cəmi ~115 MB əlçatan RAM var.
Generasiya yerli kompüterdə, bir dəfəlik:
```bash
cd dildostu/content_gen
.venv/Scripts/python scripts/build_audiobook.py --book aesop --limit 5   # sınaq
.venv/Scripts/python scripts/build_audiobook.py --book aesop            # hamısı
```
Piper binarı + səs modeli (~99 MB) `.tools/`-a yüklənir, **repoya girmir**
(`.gitignore`-da). Nəticə `audiobooks_out/` → `scp` ilə
`/opt/dildostu/server/audiobooks/`.

Ölçülmüş rəqəmlər: Piper RTF ~0.086 (1 saat audio ≈ 5 dəq), MP3 64 kbps mono
= **0.50 MB/dəq** (1 saat = 30 MB). Ezop = 284 hekayə ≈ 4 saat ≈ 122 MB.

**Server:** `GET /audiobooks` (manifest) + `/audiobooks/{kitab}/{fəsil}.mp3`.
Audio `immutable` ilə **uzun keşlənir** — APK-nın `no-store`-undan qəsdən
fərqlidir, səhv salma. id-lər yalnız `[a-z0-9-]` (path traversal bağlı).

**App:** plyer native `MediaPlayer`-dir (MethodChannel `dildostu/audio`) —
`just_audio` kimi federated plugin İŞLƏTMƏ, yuxarıdakı Gradle riski.

**Müəllif hüququ:** yalnız ictimai domen. Barron's 504 kimi qorunan kitabların
mətni səsləndirilməməlidir — o kitabdan yalnız söz→dərs indeksi götürülüb.

## Səsli kitab — sözə toxunub mənasına bax (Faza 3, 2026-08-04)

Fəsil mətnindəki hər sözü ayrıca toxunula bilən `TextSpan`-a bölürük
(`tappable_text.dart`), toxunanda `POST /word-lookup` (word + sözün öz
cümləsi kontekst kimi) → AZ tərcümə + IPA, aşağı vərəqdə göstərilir.

- Server: yalnız `translation_az`+`ipa` istənir, **nümunə cümlə YOX** —
  sözün öz cümləsi artıq ekranda görünür, təkrar yaratmaq token itkisidir.
  Yalnız SÖZLƏ keşlənir (kontekstsiz) — nadir omonim səhvi ödün verilir,
  sürət/qənaət üçün.
- App: `RichText`-in `TextSpan`-ları `find.text()` ilə TAPILMIR (Flutter-in
  standart tap axtarışı yalnız `Text`/`EditableText` widget-lərini görür) —
  testdə `TapGestureRecognizer`-i birbaşa çağırmaq lazımdır (bax
  `audiobook_screens_test.dart`-dakı `_tapWordSpan`).

## App açılışı — "ağ ekran" səbəbi (2026-08-04)

`main.dart`-ın `_bootstrap()`-u əvvəllər müstəqil şəbəkə çağırışlarını
**ardıcıl** gözləyirdi: profil çəkmə (8s) + cihaz bağlama (15s) + məkan
(GPS+server+OSM, ~25s) = ən pis halda **~48 saniyə**. İstifadəçi bunu çökmə
zənn edib "ağ ekran" adlandırırdı — əslində proqram donmurdu, sadəcə növbə
ilə gözləyirdi (logcat-da çökmə/ANR YOX idi, sadəcə 39s sükut).

**Düzəliş:** bir-birindən asılı olmayan fütürlər (`profileFuture`,
`claimFuture`, `locationFuture`, `notifInitFuture`) əvvəlcə BAŞLADILIR (await
olmadan), sonra ayrıca gözlənilir — ən pis hal ~48s-dən ~25s-ə düşür (məkan
zənciri özü daxilən ardıcıldır: GPS→server→OSM, bunu ayırmaq olmaz).

**Dərs:** app açılışında YENİ şəbəkə çağırışı əlavə edəndə, onun mövcud
zəncirə **ardıcıl** yoxsa **paralel** qoşulacağını düşün. Ardıcıl `await`
zənciri asanlıqla 30-40+ saniyəyə çatır və istifadəçiyə "sınıb" kimi görünür.

## Ana səhifə boş qalırdı — ƏSL SƏBƏB HƏLL OLUNDU (2026-08-04)

**Kökündən səbəb:** `HomeTab`-ın `Column`-una "Yenilə" zolağı (`UpdateBanner`)
**dinamik** əlavə olunurdu — app açılanda YOX, bir az sonra serverdən yeni
versiya aşkarlananda (`setState` ilə). Bu, Samsung S926B-də `HomeTab`-ın
bütün ListView məzmununu (salamlama, səviyyə seçici, kartlar, paket şəbəkəsi)
**əbədi `NEEDS-LAYOUT`/`NEEDS-PAINT`** vəziyyətində saxlayıb tam boş göstərirdi
— heç bir Dart/native xəta olmadan. Bu, canlı `flutter attach` + VM Service
(`ext.flutter.debugDumpApp`) ilə **widget ağacını birbaşa telefondan oxuyaraq**
sübut edildi: versiyalar üst-üstə düşəndə (banner yoxdursa) `GridView`/kartlar
ağacda VAR idi; server versiyası yeni olub banner əlavə olunanda YOX idi.

İki yalan iz sınanıb rədd edildi (ikisi də sənəddə saxlanılır ki, təkrar
sınanmasın):
1. Bootstrap-ın ardıcıl şəbəkə çağırışları (v23-də paralelə keçirildi —
   yaxşılaşdırma idi, amma əsl səbəb deyildi).
2. Impeller (Vulkan) renderinq mühərriki (v24/v25-də söndürüldü,
   `<application>` səviyyəsinə düzgün yerləşdirilərək təsdiqləndi işlədiyi —
   amma problem YENƏ təkrarlandı, deməli bu da səbəb deyildi).

**Əsl həll (v26):** yeniləmə axını (yoxla → yüklə → quraşdır) `HomeTab`-dan
TAM ÇIXARILIB, **Ayarlar ekranına köçürülüb** (`SettingsScreen`). Ayarlar öz
ayrı marşrutudur (`Navigator.push`) — Ana səhifənin widget ağacına heç vaxt
toxunmur, ona görə bu problem sinfi kökündən aradan qalxır. `update_logic.dart`
(artıq işlədilməyən köhnə müqayisə funksiyası) silindi.

**Dərs:** Ana səhifə kimi **ilk açılan, ən çox baxılan** ekranlara sonradan
`setState` ilə YENİ widget əlavə etmək (xüsusən şərti/dinamik renderinq)
riskli ola bilər — bəzi cihazlarda layout/paint dövriyyəsini poza bilir.
Bu cür dinamik məzmunu (bildiriş zolaqları və s.) ayrı, sabit marşrutlarda
saxlamaq daha təhlükəsizdir.

## Yoxlama qaydası

Hər dəyişiklikdən sonra: server `pytest -q`, app `flutter analyze` + `flutter test`.
Canlıda test edəndə HƏMİŞƏ mənbədən yoxla (curl/DB), UI mətninə görə "işləyir"
demə — fallback mesajı uğurlu cavaba oxşaya bilər.
