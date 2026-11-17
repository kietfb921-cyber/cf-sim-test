/* pure decision rules shared by the dylib and its unit tests */
#ifndef RULES_H
#define RULES_H

static int r_streq(const char *a, const char *b) {
    int i = 0;
    if (!a || !b) return 0;
    while (a[i] && b[i]) { if (a[i] != b[i]) return 0; i++; }
    return a[i] == b[i];
}

static int r_has(const char *h, const char *n) {
    int i, j;
    if (!h || !n || !n[0]) return 0;
    for (i = 0; h[i]; i++) {
        for (j = 0; n[j] && h[i + j] == n[j]; j++) ;
        if (!n[j]) return 1;
    }
    return 0;
}

/* system windows that must never be touched */
static int r_is_system_window(const char *cn) {
    if (!cn) return 1;
    if (cn[0] == '_') return 1;
    if (r_has(cn, "Keyboard")) return 1;
    if (r_has(cn, "TextEffects")) return 1;
    if (r_has(cn, "StatusBar")) return 1;
    if (r_has(cn, "Alert")) return 1;
    if (r_has(cn, "Tracking")) return 1;
    if (r_has(cn, "Remote")) return 1;
    return 0;
}

/* hide a window only if it is a visible, non-game, non-system overlay */
static int r_should_hide_window(const char *cn, int is_game_window, int hidden) {
    if (is_game_window) return 0;
    if (hidden) return 0;
    if (r_is_system_window(cn)) return 0;
    return 1;
}

/* dismiss a presented VC unless it belongs to the game itself */
static int r_should_dismiss_vc(const char *cn) {
    if (!cn) return 0;
    if (r_has(cn, "Unity")) return 0;
    if (r_has(cn, "Game")) return 0;
    return 1;
}
#endif
