"""Google Play üçün məcburi statik səhifələr — məxfilik siyasəti və hesab
silmə təlimatı. Backend, verilənlər bazası tələb etmir (sabit HTML).
"""

from __future__ import annotations

_CONTACT_EMAIL = "dildostu@prdostu.com"

_STYLE = """
<style>
  body { font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif;
         max-width: 720px; margin: 0 auto; padding: 32px 20px; line-height: 1.6;
         color: #1a1a1a; }
  h1 { font-size: 1.6rem; } h2 { font-size: 1.2rem; margin-top: 2rem; }
  a { color: #1B4F8A; } code { background: #f2f2f2; padding: 2px 6px; border-radius: 4px; }
</style>
"""


def privacy_policy_html() -> str:
    return f"""<!doctype html>
<html lang="az"><head><meta charset="utf-8">
<title>LachinGo — Məxfilik Siyasəti</title>{_STYLE}</head>
<body>
<h1>LachinGo — Məxfilik Siyasəti</h1>
<p><em>Privacy Policy for the LachinGo language-learning app.</em></p>
<p>Son yenilənmə: 2026-08-03</p>

<h2>Hansı məlumatları toplayırıq</h2>
<ul>
  <li><strong>Hesab məlumatı:</strong> e-poçt ünvanı və şifrənin hash-i (şifrənin
      özü heç vaxt saxlanmır).</li>
  <li><strong>Məkan:</strong> tətbiq açıq olarkən (və icazə verilibsə arxa fonda)
      cari koordinatın — yaxınlıqdakı yer tipini (kafe, market və s.) müəyyən
      etmək üçün. Dəqiq ünvan və ya ad saxlanmır, yalnız koordinat + kateqoriya.</li>
  <li><strong>İstifadə profili:</strong> seçdiyin çətinlik səviyyəsi, öyrənmə
      məqsədin, maraqların — AI-nin sənə uyğun məzmun yaratması üçün.</li>
</ul>

<h2>Məlumatlardan necə istifadə edirik</h2>
<p>Toplanan məlumat yalnız sənə fərdiləşdirilmiş dil dərsləri təqdim etmək
üçün işlədilir: AI (Groq/Anthropic) sənin profilinə uyğun söz və cümlələr
yaradır; məkan məlumatı yaxınlıqdakı mövzuya uyğun sözləri təklif etmək üçün
Foursquare Places API-yə göndərilir (adın və ya hesab məlumatın ora
ötürülmür).</p>

<h2>Məlumatların saxlanması</h2>
<p>Bütün data LachinGo-nun öz serverində saxlanılır. Üçüncü tərəflərə
satılmır və reklam məqsədilə paylaşılmır.</p>

<h2>Hesabını sil</h2>
<p>Tətbiq daxilində: <strong>Profil → Hesabı sil</strong>. Bu, hesabını və
bütün rutin/məkan datanı həmişəlik silir. Ətraflı: <a href="/delete-account">
məlumat silmə səhifəsi</a>.</p>

<h2>Əlaqə</h2>
<p>Suallar üçün: <a href="mailto:{_CONTACT_EMAIL}">{_CONTACT_EMAIL}</a></p>
</body></html>"""


def delete_account_html() -> str:
    return f"""<!doctype html>
<html lang="az"><head><meta charset="utf-8">
<title>LachinGo — Hesabı və Datanı Sil</title>{_STYLE}</head>
<body>
<h1>Hesabını və datanı sil</h1>
<p><em>How to delete your LachinGo account and data.</em></p>

<h2>Tətbiq daxilində (tövsiyə olunan yol)</h2>
<ol>
  <li>LachinGo-nu aç</li>
  <li><strong>Profil</strong> tabına keç</li>
  <li><strong>Hesabı sil</strong> düyməsinə bas, təsdiqlə</li>
</ol>
<p>Bu, dərhal və həmişəlik silir: hesabın (e-poçt), profilin (səviyyə,
maraqlar) və bütün məkan/rutin tarixçən.</p>

<h2>Tətbiq quraşdırılmayıbsa</h2>
<p>Hesabını silmək üçün <a href="mailto:{_CONTACT_EMAIL}">{_CONTACT_EMAIL}</a>
ünvanına qeydiyyatdan keçdiyin e-poçtu göstərərək yaz — hesabın 7 gün
ərzində silinəcək.</p>

<h2>Nə silinir</h2>
<ul>
  <li>Hesab (e-poçt, şifrə hash-i)</li>
  <li>Profil (səviyyə, məqsəd, maraqlar)</li>
  <li>Bütün məkan/rutin nümunələri</li>
</ul>
</body></html>"""
