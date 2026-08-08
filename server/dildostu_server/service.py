"""Canlı mesaj generasiyası servisi — prompt → completer → parser + keş.

Endpoint-dən ayrıdır ki, completer və keş inject oluna (test üçün mock).
"""

from __future__ import annotations

from .chat_pipeline import ChatPipelineError, run_chat_pipeline
from .generator import (
    parse_dayplan_response,
    parse_generate_response,
    parse_word_lookup_response,
)
from .memory_store import MemoryStore
from .models import (
    ChatRequest,
    DayPlanRequest,
    DayPlanResponse,
    GenerateRequest,
    LiveMessage,
    UserProfile,
    WordLookupResponse,
)
from .prompts import (
    build_dayplan_prompt,
    build_essential_words_prompt,
    build_generate_prompt,
    build_language_essential_words_prompt,
    build_pack_words_prompt,
    build_word_lookup_prompt,
    preferred_providers,
)
from .providers import (
    AllProvidersFailed,
    ChatCompleter,
    Completer,
    complete_with_fallback,
)


class ServiceError(Exception):
    """AI generasiyası uğursuz oldu (app statik fallback-a düşməli)."""


class LiveService:
    def __init__(self, completers: dict[str, Completer], cache: dict | None = None):
        self._completers = completers
        self._cache = cache if cache is not None else {}

    def generate(self, req: GenerateRequest) -> LiveMessage:
        key = (req.context.pack_id, req.profile.level, req.mode)
        if key in self._cache:
            return self._cache[key]

        system, user = build_generate_prompt(
            req.profile, req.context, req.mode, req.recent_words
        )
        try:
            text = complete_with_fallback(
                system, user, preferred_providers(req.mode), self._completers
            )
            message = parse_generate_response(text, req.context)
        except (AllProvidersFailed, ValueError) as exc:
            raise ServiceError(str(exc)) from exc

        self._cache[key] = message
        return message

    def pack_words(
        self, profile: UserProfile, pack_id: str, count: int
    ) -> list[LiveMessage]:
        """Paket üçün söz siyahısı (söz siyahısı ekranı).

        Keş açarı (paket, səviyyə, say) — eyni paketi təkrar açanda AI-ya
        yenidən sorğu getmir; səviyyə dəyişəndə isə yeni siyahı gəlir.
        """
        key = ("pack-words", pack_id, profile.level, count)
        if key in self._cache:
            return self._cache[key]

        system, user = build_pack_words_prompt(profile, pack_id, count)
        try:
            text = complete_with_fallback(
                system, user, preferred_providers("normal"), self._completers
            )
            words = parse_dayplan_response(text, [pack_id] * count)
        except (AllProvidersFailed, ValueError) as exc:
            raise ServiceError(str(exc)) from exc

        self._cache[key] = words
        return words

    def essential_words(
        self, profile: UserProfile, words: list[str]
    ) -> list[LiveMessage]:
        """504 sabit söz bankından verilmiş sözlər üçün pedaqoji "qabıq" yaradır.

        Keş açarında sözlərin özü var (tuple) — səviyyə dəyişəndə fərqli söz
        dəsti gəldiyi üçün eyni açar heç vaxt fərqli sözlər üçün istifadə
        olunmur.
        """
        key = ("essential-words", tuple(words), profile.level)
        if key in self._cache:
            return self._cache[key]

        system, user = build_essential_words_prompt(profile, words)
        try:
            text = complete_with_fallback(
                system, user, preferred_providers("normal"), self._completers
            )
            messages = parse_dayplan_response(text, ["essential"] * len(words))
        except (AllProvidersFailed, ValueError) as exc:
            raise ServiceError(str(exc)) from exc

        self._cache[key] = messages
        return messages

    def language_essential_words(
        self, profile: UserProfile, count: int, exclude_words: list[str]
    ) -> list[LiveMessage]:
        """Barron's 504 bankı olmayan dillər (`target_lang != "en"`) üçün
        "Əsas lüğət" — AI sözləri ÖZÜ seçir (fərqli olaraq `essential_words`-dan,
        hansı ki sabit siyahı VERİLİR). Sabit bank yoxdur, ona görə keşlənmir
        (hər çağırış təzə AI sorğusudur — `exclude_words` təkrarçılığı azaldır).
        """
        system, user = build_language_essential_words_prompt(
            profile, count, exclude_words
        )
        try:
            text = complete_with_fallback(
                system, user, preferred_providers("normal"), self._completers
            )
            return parse_dayplan_response(text, ["essential"] * count)
        except (AllProvidersFailed, ValueError) as exc:
            raise ServiceError(str(exc)) from exc

    def word_lookup(self, word: str, context: str) -> WordLookupResponse:
        """Səsli kitab mətnində toxunulan sözün mənası.

        Yalnız SÖZLƏ keşlənir (kontekst yox) — eyni sözün fərqli cümlələrdə
        nadir mənası dəyişsə də, sürət/qənaət üçün bu ödün verilir.
        """
        key = ("word-lookup", word.lower())
        if key in self._cache:
            return self._cache[key]

        system, user = build_word_lookup_prompt(word, context)
        try:
            text = complete_with_fallback(
                system, user, preferred_providers("normal"), self._completers
            )
            result = parse_word_lookup_response(text, word)
        except (AllProvidersFailed, ValueError) as exc:
            raise ServiceError(str(exc)) from exc

        self._cache[key] = result
        return result

    def day_plan(self, req: DayPlanRequest) -> DayPlanResponse:
        system, user = build_dayplan_prompt(req.profile, req.pack_ids, req.date)
        try:
            text = complete_with_fallback(
                system, user, preferred_providers("normal"), self._completers
            )
            messages = parse_dayplan_response(text, req.pack_ids)
        except (AllProvidersFailed, ValueError) as exc:
            raise ServiceError(str(exc)) from exc
        return DayPlanResponse(messages=messages, source="ai")


def run_chat(
    req: ChatRequest,
    chat_completers: dict[str, ChatCompleter],
    memory: MemoryStore,
    user_id: int,
) -> str:
    """Söhbət cavabı yaradır — `chat_pipeline.run_chat_pipeline` üzərindən.

    RunnablePassthrough tipli zəncir: validate → DB-dən yüklə → AI → saxla.
    AI uğursuzsa heç nə yazılmır (ServiceError).
    """
    try:
        return run_chat_pipeline(req, chat_completers, memory, user_id)
    except ChatPipelineError as exc:
        raise ServiceError(str(exc)) from exc
