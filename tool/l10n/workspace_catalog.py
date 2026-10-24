"""V2 chat-first workspace copy, ported from the v1 home and drawer."""

PORT_KEYS = {
    "chatNoServerYet",
    "chatSetUpServer",
    "chatNewChat",
    "chatSelectOrCreate",
}

NEW_KEYS = ()

COPY = {
    locale: ()
    for locale in (
        "ar", "bn", "de", "en", "es", "fr", "hi",
        "it", "ja", "ko", "pt", "ru", "ur", "zh",
    )
}
