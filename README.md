# DilDostu — kontekstli dil öyrənmə tətbiqi (AZ → EN)

Azərbaycandilli istifadəçilər üçün ingilis dili öyrənmə mobil tətbiqi. Tətbiq
istifadəçinin harada olduğunu və günün vaxtını nəzərə alır (kafe, aeroport, ofis…)
və həmin vəziyyətə uyğun söz və nümunə cümlələri AI ilə canlı yaradır.

## Əsas imkanlar
- **Kontekstli öyrənmə:** GPS + vaxt əsasında vəziyyətə uyğun lüğət
- **Live AI backend:** fərdi söz və nümunələr LLM ilə yaradılır
- **Offline ehtiyat:** server əlçatmaz olduqda statik paketlərə keçid
- Səviyyəyə uyğunlaşan məzmun

## Struktur
| Qovluq | Nədir |
|---|---|
| `app/` | Flutter mobil tətbiq (Android) |
| `server/` | FastAPI backend — prompt qurma, LLM provayder fallback-i (Groq / Claude) |
| `content_gen/` | Statik məzmun paketlərini yaradan skriptlər |

## Texnologiyalar
Flutter / Dart · Python · FastAPI · Groq · Claude API
