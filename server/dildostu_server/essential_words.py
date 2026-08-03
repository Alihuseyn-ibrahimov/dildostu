"""504 ümumi ingilis dili sözü — çətinlik səviyyəsinə görə bölünmüş söz bankı.

Mənbə: sözlərin özləri (ictimai domen — sadəcə İngilis dili lüğət vahidləridir)
"504 Absolutely Essential Words" (Bromberg/Liebb/Traiger, Barron's) dərsliyinin
öz əlifba indeksindən (hər sözün ilk keçdiyi dərs nömrəsi) çıxarılıb.

MÜHÜM: kitabın öz tərifləri, nümunə cümlələri və hekayələri (müəllif hüququ
qorunan orijinal mətn) BURAYA KÖÇÜRÜLMƏYİB və heç vaxt köçürülməməlidir — hər
sözün AZ tərcüməsi, IPA-sı və nümunə cümləsi bizim öz AI sistemimizlə (bax
prompts.py `build_essential_words_prompt`) təzədən yaradılır.

Dərs nömrəsi (1-42) çətinlik səviyyəsi üçün proksi kimi işlədilir — kitab
sözləri tədricən çətinləşən sırayla təqdim edir. 42 dərs 3 səviyyəyə bərabər
bölünür (hərəsi 14 dərs = 168 söz):
  Asan (beginner):       dərs 1-14
  Orta (intermediate):   dərs 15-28
  Çətin (advanced):      dərs 29-42
"""

from __future__ import annotations

# word -> kitabda ilk keçdiyi dərs nömrəsi (1-42). Doğrulanıb: tam 504 söz,
# hər dərsdə tam 12 söz (bax tests/test_essential_words.py).
WORD_LESSON: dict[str, int] = {
    "abandon": 1, "abide": 37, "abolish": 12, "abroad": 25, "absorb": 19,
    "absurd": 11, "abundant": 19, "abuse": 33, "accurate": 16, "acknowledge": 22,
    "addict": 17, "adequate": 12, "adolescent": 34, "alter": 15, "amateur": 8,
    "ambush": 20, "amend": 42, "annual": 3, "anticipate": 21, "apologize": 32,
    "appeal": 17, "appoint": 30, "approach": 6, "appropriate": 19, "architect": 25,
    "assemble": 5, "attract": 30, "audible": 12, "authority": 24, "avoid": 17,
    "aware": 17, "awesome": 26, "awkward": 26,
    "bachelor": 1, "baffle": 21, "baggage": 25, "bait": 28, "ballot": 42,
    "ban": 19, "beau": 3, "beckon": 26, "beneficiary": 22, "betray": 26,
    "bewildered": 14, "bigamy": 25, "biography": 38, "blend": 3, "blunder": 29,
    "brawl": 14, "brutal": 14, "budget": 18, "bulky": 8, "burden": 5,
    "calamity": 25, "calculate": 19, "campus": 5, "cancel": 39, "candidate": 34,
    "capacity": 16, "capsule": 7, "captive": 20, "casual": 15, "cautious": 16,
    "cease": 27, "censor": 28, "century": 9, "challenge": 9, "charity": 38,
    "chiropractor": 40, "cinema": 35, "circulate": 4, "clergy": 39, "client": 6,
    "coeducational": 34, "coincide": 39, "collapse": 25, "colleague": 32,
    "collide": 21, "commence": 13, "commend": 29, "commuter": 31, "compel": 26,
    "compete": 10, "complacent": 41, "comprehend": 29, "comprehensive": 6,
    "conceal": 2, "conclude": 9, "confident": 16, "confine": 31, "confirm": 21,
    "conflict": 11, "consent": 7, "consider": 24, "contagious": 39, "corpse": 2,
    "crafty": 20, "culprit": 28, "customary": 39,
    "data": 1, "daze": 29, "debate": 5, "debtor": 39, "decade": 11,
    "deceive": 6, "decrease": 12, "defect": 6, "defiant": 20, "defraud": 6,
    "dejected": 38, "deliberate": 37, "delinquent": 22, "denounce": 7, "dense": 4,
    "depart": 39, "depict": 30, "deprive": 22, "descend": 4, "despite": 27,
    "detect": 6, "detest": 24, "detour": 21, "devise": 3, "devour": 20,
    "dilemma": 21, "diminish": 32, "disaster": 28, "discard": 35, "disclose": 28,
    "dismal": 2, "dispute": 31, "disrupt": 27, "distress": 32, "document": 9,
    "doubt": 16, "drastic": 42, "dread": 10, "drench": 38, "drought": 37,
    "duplicate": 14, "dwindle": 37,
    "economical": 18, "editor": 13, "elevate": 35, "eliminate": 4, "embrace": 23,
    "emerge": 20, "employee": 6, "encourage": 24, "endure": 42, "enormous": 4,
    "envy": 25, "epidemic": 40, "essential": 3, "estimate": 19, "evade": 5,
    "event": 35, "evidence": 11, "exaggerate": 8, "excel": 10, "excessive": 28,
    "exempt": 29, "exhaust": 27, "exhibit": 23, "expand": 15, "expensive": 3,
    "explore": 5, "expose": 42, "extract": 23,
    "famine": 13, "feeble": 27, "feminine": 10, "fertile": 31, "fiction": 11,
    "fierce": 24, "final": 29, "finance": 35, "flee": 32, "flexible": 10,
    "forbid": 23, "fortunate": 15, "fragile": 20, "frank": 12, "frequent": 11,
    "frigid": 2, "fugitive": 25,
    "gallant": 1, "glance": 18, "gleam": 13, "glimpse": 11, "gloomy": 7,
    "grateful": 16, "guide": 26,
    "hardship": 1, "harmony": 36, "harsh": 17, "harvest": 19, "hasty": 36,
    "hazy": 13, "heed": 37, "heir": 37, "hesitate": 11, "hinder": 33,
    "homicide": 22, "horrid": 18, "humid": 4,
    "identify": 13, "idle": 31, "idol": 31, "ignite": 12, "ignore": 9,
    "illegal": 36, "illustrate": 28, "indifference": 41, "ingenious": 18,
    "inhabit": 2, "innovative": 15, "insist": 28,
    "jagged": 20, "jealous": 1, "jeopardize": 40, "jest": 31, "jolly": 33,
    "journalist": 13, "justice": 22, "juvenile": 28,
    "keen": 1, "keg": 17, "kneel": 38,
    "lack": 9, "lecture": 33, "legend": 42, "legible": 39, "linger": 20,
    "logical": 23, "lottery": 35, "loyalty": 32, "lubricate": 18, "lunatic": 31,
    "magnify": 40, "maim": 29, "maintain": 42, "majestic": 37, "majority": 5,
    "manipulate": 18, "masculine": 10, "massive": 7, "matrimony": 25, "mature": 15,
    "maximum": 32, "mediocre": 8, "menace": 10, "merit": 21, "microscope": 16,
    "migrate": 13, "miniature": 9, "minimum": 3, "minority": 11, "miserly": 27,
    "misfortune": 17, "molest": 7, "monarch": 27, "morality": 30, "morgue": 41,
    "morsel": 19, "mortal": 30, "mount": 10, "mourn": 29, "multitude": 41,
    "mumble": 33, "municipal": 40, "mute": 33, "mythology": 32,
    "narcotic": 36, "negative": 40, "neglect": 6, "neutral": 24, "nimble": 18,
    "nominate": 41, "nourish": 17, "novel": 30, "numb": 2, "numerous": 10,
    "oath": 1, "obedient": 38, "obesity": 40, "observant": 13, "obstacle": 40,
    "obtain": 35, "obvious": 8, "occupant": 30, "opponent": 14, "opt": 17,
    "oral": 40, "outlaw": 28,
    "pacify": 26, "panic": 19, "parole": 41, "partial": 23, "patriotic": 31,
    "pauper": 25, "pedestrian": 18, "penalize": 22, "penetrate": 16, "pension": 40,
    "peril": 2, "perish": 20, "persist": 13, "persuade": 3, "pierce": 16,
    "pioneer": 15, "placard": 39, "plea": 21, "pledge": 15, "pollute": 12,
    "ponder": 42, "popular": 6, "population": 12, "possible": 26, "postpone": 7,
    "potential": 41, "precaution": 23, "precede": 34, "predict": 4, "prejudice": 33,
    "preoccupied": 41, "preserve": 7, "prior": 23, "probe": 5, "proceed": 23,
    "prohibit": 12, "prominent": 8, "promote": 28, "prompt": 36, "prosecute": 25,
    "prosper": 20, "pursue": 15,
    "qualify": 1, "quantity": 17, "quarter": 30, "quench": 26, "quota": 19,
    "quote": 30,
    "radical": 34, "rage": 9, "rapid": 27, "rarely": 23, "rash": 27,
    "rave": 18, "recede": 38, "recent": 11, "reckless": 18, "recline": 2,
    "redeem": 36, "refer": 32, "reform": 5, "refrain": 36, "rehabilitate": 41,
    "reject": 22, "relate": 35, "relieve": 21, "reluctant": 8, "repetition": 29,
    "reptile": 23, "resent": 7, "resign": 42, "resist": 9, "respond": 26,
    "resume": 36, "retain": 33, "reveal": 12, "revise": 15, "revive": 13,
    "rival": 14, "roam": 30, "rural": 5,
    "sacred": 15, "scald": 39, "scarce": 3, "scorch": 36, "scowl": 24,
    "security": 8, "sensitive": 34, "severity": 27, "shriek": 2, "shrill": 33,
    "signify": 32, "sinister": 2, "site": 30, "skim": 34, "slender": 16,
    "sneer": 24, "snub": 42, "soar": 35, "solitary": 11, "soothe": 36,
    "source": 9, "spontaneous": 34, "spouse": 22, "squander": 25, "stationary": 35,
    "subsequent": 35, "subside": 29, "summit": 37, "surpass": 16, "surplus": 37,
    "survive": 8, "swarm": 38, "symbol": 24, "sympathetic": 36,
    "tact": 1, "temperate": 34, "tempest": 36, "tempt": 2, "tendency": 10,
    "theory": 4, "thorough": 6, "threat": 19, "thrifty": 27, "thrust": 14,
    "toil": 29, "topic": 5, "torment": 32, "torrent": 7, "tradition": 5,
    "tragedy": 18, "traitor": 37, "transmit": 21, "transparent": 39, "trifle": 24,
    "tumult": 38, "typical": 3, "tyrant": 38,
    "unaccustomed": 1, "unanimous": 15, "undeniable": 9, "underdog": 14,
    "underestimate": 10, "undernourished": 28, "undoubtedly": 6, "unearth": 39,
    "uneasy": 19, "uneventful": 31, "unforeseen": 7, "unify": 37, "unique": 7,
    "unite": 27, "unruly": 14, "unstable": 22, "untidy": 34, "upholstery": 41,
    "urban": 12, "urgent": 12, "utensil": 34, "utilize": 4, "utter": 26,
    "vacant": 1, "vaccinate": 34, "vague": 35, "vain": 29, "valiant": 23,
    "valid": 8, "valor": 31, "vandal": 37, "vanish": 4, "vapor": 4,
    "variety": 8, "vast": 16, "vein": 31, "ventilate": 40, "venture": 26,
    "verdict": 38, "verify": 21, "vermin": 24, "verse": 30, "vertical": 41,
    "vessel": 13, "vicinity": 9, "vicious": 14, "victorious": 10, "vigor": 20,
    "villain": 4, "violent": 14, "visible": 3, "vision": 11, "vital": 40,
    "vocation": 22, "volunteer": 33, "vulnerable": 32,
    "wad": 33, "wager": 2, "wail": 24, "warden": 22, "wary": 17,
    "wasp": 41, "weary": 21, "weird": 8, "wharf": 42, "whirling": 14,
    "wholesale": 3, "witty": 33, "wobble": 38, "wrath": 42, "wretched": 17,
}

# Dərs (1-42) → çətinlik səviyyəsi. 14 dərslik bərabər bloklar.
_LEVEL_LESSON_MAX = {"beginner": 14, "intermediate": 28, "advanced": 42}


def words_for_level(level: str) -> list[str]:
    """Verilmiş səviyyəyə uyğun sözləri dərs sırası ilə (sabit, təkrarlana bilən
    sıra) qaytarır. Naməlum səviyyə → boş siyahı (çağıran tərəf idarə edir)."""
    max_lesson = _LEVEL_LESSON_MAX.get(level)
    if max_lesson is None:
        return []
    min_lesson = max_lesson - 13  # 14 dərslik blok
    return sorted(
        (w for w, lesson in WORD_LESSON.items() if min_lesson <= lesson <= max_lesson),
        key=lambda w: (WORD_LESSON[w], w),
    )
