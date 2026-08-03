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

## Self-update mexanizmi

`app_update_client.dart` → `/app/version` + `/app/latest.apk` (Cloudflare
`no-store` başlıqları ilə). APK ~150+ MB olduğu üçün **axın (stream) kimi**
yüklənir (`send()` + `stream.pipe`), `get()...bodyBytes` YOX — bütün faylı
yaddaşa yığmaq telefonda səssiz OOM-a səbəb olurdu (heç bir xəta görünmədən
"Yenilə" zolağı sadəcə çıxmırdı). Bunu təkrar pozma.

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

## Yoxlama qaydası

Hər dəyişiklikdən sonra: server `pytest -q`, app `flutter analyze` + `flutter test`.
Canlıda test edəndə HƏMİŞƏ mənbədən yoxla (curl/DB), UI mətninə görə "işləyir"
demə — fallback mesajı uğurlu cavaba oxşaya bilər.
