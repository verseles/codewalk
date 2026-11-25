"""Timeline tokens-per-second (TPS) localization catalog."""

NEW_KEYS = (
    "settingsAppearanceTokensPerSecond",
    "msgInfoTokensPerSecondValue",
    "msgInfoTokensPerSecond",
)

METADATA = {
    "settingsAppearanceTokensPerSecond": {
        "description": "Display menu toggle label for showing tokens per second on final turn responses",
    },
    "msgInfoTokensPerSecondValue": {
        "description": "Compact tokens per second chip value",
        "placeholders": {
            "value": {"type": "String"},
        },
    },
    "msgInfoTokensPerSecond": {
        "description": "Message info dialog row label showing token generation speed",
        "placeholders": {
            "tps": {"type": "String"},
        },
    },
}

COPY = {
    "en": (
        "Tokens per second",
        "{value} tok/s",
        "Speed: {tps}",
    ),
    "pt": (
        "Tokens por segundo",
        "{value} tok/s",
        "Velocidade: {tps}",
    ),
    "es": (
        "Tokens por segundo",
        "{value} tok/s",
        "Velocidad: {tps}",
    ),
    "fr": (
        "Jetons par seconde",
        "{value} tok/s",
        "Vitesse : {tps}",
    ),
    "de": (
        "Tokens pro Sekunde",
        "{value} tok/s",
        "Geschwindigkeit: {tps}",
    ),
    "it": (
        "Token al secondo",
        "{value} tok/s",
        "Velocità: {tps}",
    ),
    "ru": (
        "Токенов в секунду",
        "{value} tok/s",
        "Скорость: {tps}",
    ),
    "ja": (
        "1秒あたりのトークン数",
        "{value} tok/s",
        "速度: {tps}",
    ),
    "ko": (
        "초당 토큰 수",
        "{value} tok/s",
        "속도: {tps}",
    ),
    "zh": (
        "每秒 Token 数",
        "{value} tok/s",
        "速度：{tps}",
    ),
    "hi": (
        "प्रति सेकंड टोकन",
        "{value} tok/s",
        "गति: {tps}",
    ),
    "bn": (
        "প্রতি সেকেন্ডে টোকেন",
        "{value} tok/s",
        "গতি: {tps}",
    ),
    "ar": (
        "الرموز في الثانية",
        "{value} tok/s",
        "السرعة: {tps}",
    ),
    "ur": (
        "فی سیکنڈ ٹوکنز",
        "{value} tok/s",
        "رفتار: {tps}",
    ),
}
