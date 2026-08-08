"""Mahnı draft-larını `songs_out/drafts/`-dan yaradır, merge + timing tətbiq edir."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRAFTS = ROOT / "songs_out" / "drafts"
DRAFTS.mkdir(parents=True, exist_ok=True)
PY = ROOT / ".venv" / "Scripts" / "python.exe"


def _lines(items: list[tuple[str, str]]) -> list[dict]:
    return [
        {"line_id": f"l{i}", "text": es, "translation_az": az}
        for i, (es, az) in enumerate(items, start=1)
    ]


def _write(name: str, song: dict) -> None:
    path = DRAFTS / name
    path.write_text(json.dumps(song, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"draft: {path.name} ({len(song['lines'])} setr)")


# --- Bebe (advanced, es) ---

_write(
    "bebe-gente.json",
    {
        "song_id": "bebe-gente",
        "title": "Gente",
        "artist": "Bebe",
        "youtube_id": "kZWVsnMfOZ4",
        "level": "advanced",
        "lang": "es",
        "lines": _lines([
            ("Gente, gente que se despierta cuando andas de noche,", "İnsanlar, gecə gəzəndə oyanan insanlar,"),
            ("Y cocina cuando cae el sol.", "Gün batanda yemək bişirən."),
            ("Gente que acompaña gente en hospitales, parques,", "Xestəxanalarda, parklarda insana yoldaşlıq edən,"),
            ("Gente que despide o que recibe a gente en los andenes.", "Platformada insanı yola salan və ya qarşılayan."),
            ("Gente que va de frente, que no esquiva tu mirada,", "Üz-üzə gedən, baxışından qaçmayan,"),
            ("Y que percibe en el viento cómo será el verano, cómo será el invierno.", "Küləkdən yayın, qışın necə olacağını hiss edən."),
            ("Dos, tres horas para disfrutarte,", "Sənə həzz almaq üçün iki-üç saat,"),
            ("Y dos de cada siete días para darte,", "Sənə vermək üçün həftənin iki günü,"),
            ("Un pasaje en la más bella historia de amor.", "Ən gözəl sevgi hekayəsində bir yer."),
            ("Dos, tres horas para contemplarte,", "Sənə baxmaq üçün iki-üç saat,"),
            ("Me acomodo en un rincón de tu corazón.", "Ürəyinin bir küncünə yerləşirəm."),
            ("Gente que pide por la gente en los altares, en las romerías,", "Məbədlərdə, ziyarətlərdə insan üçün dua edən,"),
            ("Gente que da la vida, que infunde fe,", "Həyat verən, inam aşılayan,"),
            ("Que crece y que merece paz.", "Böyüyən və sülhə layiq olan."),
            ("Qué fresca es la sombra que ofrecen,", "Verdikləri kölgə nə dincdir,"),
            ("Qué limpia el agua dulce de sus miradas.", "Baxışlarının şirin suyu nə təmizdir."),
            ("Es por ti que empiezo un nuevo día,", "Yeni günə sənə görə başlayıram,"),
            ("Hay ángeles entre nosotros.", "Aramızda mələklər var."),
        ]),
    },
)

_write(
    "bebe-siempre-me-quedara.json",
    {
        "song_id": "bebe-siempre-me-quedara",
        "title": "Siempre Me Quedará",
        "artist": "Bebe",
        "youtube_id": "C4cmJ7QqBMI",
        "level": "advanced",
        "lang": "es",
        "lines": _lines([
            ("Cómo decir que me parte en mil las esquinitas de mi hueso,", "Sümüyümün küncələrini min parçaya bölən sözü necə deməli,"),
            ("Que han caído los esquemas de mi vida,", "Həyatımın planları dağıldı,"),
            ("Ahora que todo era perfecto y algo más que eso.", "Hər şey mükəmməl olanda."),
            ("Me cuesta abrir los ojos y lo hago poco a poco,", "Gözlərimi açmaq çətindir, yavaş-yavaş edirəm,"),
            ("No sé si aún te encuentres cerca.", "Hələ yaxınlıqdasanmı, bilmirəm."),
            ("Me guardo tus recuerdos como el mejor secreto,", "Xatirələrini ən yaxşı sirr kimi saxlayıram,"),
            ("Qué dulce fue tenerte dentro.", "Sənə sahib olmaq nə şirin idi."),
            ("Siempre me quedará la voz suave del mar, volver a respirar,", "Həmişə qalacaq dənizin yumşaq səsi, yenidən nəfəs almaq,"),
            ("La lluvia que caerá sobre este cuerpo y mojará,", "Bu bədənə düşüb isladacaq yağmur,"),
            ("La flor que crece en mí y volverá a reír,", "Məndə böyüyən və yenidən güləcək çiçək,"),
            ("Y cada día un instante volveré a pensar en ti.", "Hər gün bir an sənə düşəcəyəm."),
            ("El tiempo todo calma, la tempestad y la calma.", "Zaman hər şeyi sakitləşdirir, fırtına və sakitlik."),
        ]),
    },
)

_write(
    "bebe-tu-silencio.json",
    {
        "song_id": "bebe-tu-silencio",
        "title": "Tu Silencio",
        "artist": "Bebe",
        "youtube_id": "fAuQtoy_HJs",
        "level": "advanced",
        "lang": "es",
        "lines": _lines([
            ("Como quien tira de una cuerda que se romperá,", "Qopacaq ipi dartan kimi,"),
            ("Tirar, tirar, tirar, tirar, tirar.", "Dart, dart, dart, dart, dart."),
            ("Como sin darse cuenta, rozar un poco más,", "Fərqinə varmadan bir az daha toxunmaq,"),
            ("Los ojos han cerrado para no afrontar,", "Gözlər üzləşməmək üçün bağlanıb,"),
            ("Que el aire es de cristal, que puede estallar,", "Havanın şüşə kimi, partlaya biləcəyini,"),
            ("Que aunque parezca extraño te quiero devorar.", "Qəribə görünsə də, səni yemək istəyirəm."),
            ("Tu silencio es la más elocuente forma de mentir,", "Sənin suskunluğun yalan deməyin ən aydın yoludur,"),
            ("En tu silencio habita el mío,", "Sənin suskunluğunda mənimki yaşayır,"),
            ("Y en alguna parte de mi cuerpo habitó un trozo de tu olor,", "Bədənimin bir yerində qoxunun parçası qaldı,"),
            ("Y en alguna parte de mis ojos habitó un trozo de dolor.", "Gözlərimin bir yerində acının parçası qaldı."),
            ("Ahora estás aquí, ahora estoy aquí,", "İndi buradasan, indi mən buradayam,"),
            ("Abrázame para que piense alguna vez en ti.", "Bir gün sənə düşüm deyə, qucaqla məni."),
        ]),
    },
)

# --- EN intermediate ---

_write(
    "louis-armstrong-wonderful-world.json",
    {
        "song_id": "louis-armstrong-what-a-wonderful-world",
        "title": "What a Wonderful World",
        "artist": "Louis Armstrong",
        "youtube_id": "A3yCcXgbKrE",
        "level": "intermediate",
        "lang": "en",
        "lines": _lines([
            ("I see trees of green, red roses too,", "Yaşıl ağaclar, qırmızı qızılgüllər görürəm,"),
            ("I see them bloom for me and you,", "Onların mənim və sənin üçün açdığını görürəm,"),
            ("And I think to myself what a wonderful world.", "Öz-özümə düşünürəm: nə gözəl dünyadır."),
            ("I see skies of blue and clouds of white,", "Mavi göy, ağ buludlar görürəm,"),
            ("The bright blessed day, the dark sacred night,", "Parlaq mübarək gün, qaranlıq müqəddəs gecə,"),
            ("And I think to myself what a wonderful world.", "Öz-özümə düşünürəm: nə gözəl dünyadır."),
            ("The colors of the rainbow so pretty in the sky,", "Göydə göy qurşağının rəngləri nə gözəldir,"),
            ("Are also on the faces of people going by.", "Keçən insanların üzündə də var."),
            ("I see friends shaking hands saying how do you do,", "Əl sıxan dostlar görürəm, salam verirlər,"),
            ("They're really saying I love you.", "Əslində deyirlər: səni sevirəm."),
            ("I hear babies cry, I watch them grow,", "Körpələrin ağlamasını eşidirəm, böyüməsini izləyirəm,"),
            ("They'll learn much more than I'll ever know,", "Mənim heç vaxt bilməyəcəyimdən çox şey öyrənəcəklər,"),
            ("And I think to myself what a wonderful world.", "Öz-özümə düşünürəm: nə gözəl dünyadır."),
        ]),
    },
)

# --- EN advanced ---

_write(
    "ed-sheeran-shape-of-you.json",
    {
        "song_id": "ed-sheeran-shape-of-you",
        "title": "Shape of You",
        "artist": "Ed Sheeran",
        "youtube_id": "_dK2tDK9grQ",
        "level": "advanced",
        "lang": "en",
        "lines": _lines([
            ("The club isn't the best place to find a lover,", "Sevgili tapmaq üçün klub ən yaxşı yer deyil,"),
            ("So the bar is where I go.", "Ona görə bura gedirəm."),
            ("Me and my friends at the table doing shots,", "Masa arxasında dostlarımla şot edirik,"),
            ("Drinking fast and then we talk slow.", "Tez içirik, sonra yavaş danışırıq."),
            ("Come over and start up a conversation with just me,", "Yaxınlaş, yalnız mənimlə söhbət başlat,"),
            ("And trust me I'll give it a chance now.", "Etibar et, indi şans verəcəyəm."),
            ("Take my hand, stop, put Van the Man on the jukebox,", "Əlimi tut, dayan, jukebox-da Van Morrison qoy,"),
            ("And then we start to dance.", "Sonra rəqsə başlayırıq."),
            ("And now my bedsheets smell like you,", "İndi yataq dəstlərim sənin qoxunla doludur,"),
            ("Every day discovering something brand new.", "Hər gün tamamilə yeni bir şey kəşf edirik."),
            ("I'm in love with the shape of you.", "Sənin formasına aşiqəm."),
            ("We push and pull like a magnet do,", "Maqnit kimi bir-birimizə çəkirik,"),
            ("Although my heart is falling too,", "Ürəyim də düşsə belə,"),
            ("I'm in love with your body.", "Bədəninə aşiqəm."),
        ]),
    },
)

# --- ES intermediate ---

_write(
    "luis-fonsi-despacito.json",
    {
        "song_id": "luis-fonsi-despacito",
        "title": "Despacito",
        "artist": "Luis Fonsi ft. Daddy Yankee",
        "youtube_id": "gm3-m2CFVWM",
        "level": "intermediate",
        "lang": "es",
        "lines": _lines([
            ("Sí, sabes que ya llevo un rato mirándote,", "Bəli, bir müddətdir sənə baxdığımı bilirsən,"),
            ("Tengo que bailar contigo hoy.", "Bu gün səninlə rəqs etməliyəm."),
            ("Vi que tu mirada ya estaba llamándome,", "Baxışının artıq məni çağırdığını gördüm,"),
            ("Muéstrame el camino que yo voy.", "Getdiyim yolu mənə göstər."),
            ("Oh, tú, tú eres el imán y yo soy el metal,", "Sən maqnitsən, mən metalam,"),
            ("Me voy acercando y voy armando el plan.", "Yaxınlaşıram və plan qururam."),
            ("Solo con pensarlo se acelera el pulso.", "Düşünmək belə nəbzimi sürətləndirir."),
            ("Oh, yeah, ya, ya me está gustando más de lo normal.", "Bəli, adi haldan daha çox xoşuma gəlir."),
            ("Todos mis sentidos van pidiendo más,", "Bütün duyğularım daha çox istəyir,"),
            ("Esto hay que tomarlo sin ningún apuro.", "Bunu heç tələsmədən etmək lazımdır."),
            ("Despacito, quiero respirar tu cuello despacito,", "Yavaş-yavaş, boynundan yavaş nəfəs almaq istəyirəm,"),
            ("Deja que te diga cosas al oído,", "Qulağına bir şeylər deməyə icazə ver,"),
            ("Para que te acuerdes si no estás conmigo.", "Mənimlə olmadıqda xatırlasan deyə."),
            ("Despacito, quiero desnudarte a besos despacito,", "Yavaş-yavaş, öpücüklərlə soyundurmaq istəyirəm,"),
            ("Firmo las paredes de tu laberinto,", "Labirintinin divarlarını imzalayıram,"),
            ("Y hacer de tu cuerpo todo un manuscrito.", "Bədənini tam bir əlyazmasına çevirirəm."),
        ]),
    },
)

# Transkripsiya + merge + timing
NEW_IDS = [
    ("A3yCcXgbKrE", "en", "wonderful world trees green roses", "small"),
    ("_dK2tDK9grQ", "en", "Shape of You Ed Sheeran bar club", "large-v3"),
    ("gm3-m2CFVWM", "es", "Despacito Luis Fonsi Daddy Yankee", "large-v3"),
]

for vid, lang, hw, model in NEW_IDS:
    words_path = ROOT / "songs_out" / f"_words_{vid}.json"
    if not words_path.exists():
        print(f"transcribe: {vid} ({model})...")
        subprocess.run(
            [str(PY), str(ROOT / "scripts/transcribe_song.py"), vid, lang,
             "--model", model, "--hotwords", hw],
            check=True,
            env={**os.environ, "HF_HUB_DISABLE_SYMLINKS": "1"},
        )

print("merge...")
subprocess.run([str(PY), str(ROOT / "scripts/merge_song_draft.py")], check=True)
print("timing...")
subprocess.run([str(PY), str(ROOT / "scripts/apply_song_timing.py")], check=True)
print("verify...")
subprocess.run([str(PY), str(ROOT / "scripts/verify_song_timing.py")], check=True)
print("Hazir.")
