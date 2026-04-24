--[[
    i18n.lua — internationalisation module for the Slide Puzzle plugin.

    Supported languages: pt, en, es, fr, de, ko
    Language is persisted in the plugin's own LuaSettings file under the
    key "language". On first run the system locale is detected via the
    LANG / LC_ALL / LANGUAGE environment variables; Portuguese is the
    ultimate fallback.

    Public API:
        i18n.load(settings)         -- call once at plugin init; reads or
                                    --   detects the active language
        i18n.set(lang, settings)    -- change language and persist
        i18n.t(key [, ...])         -- return translated (+ interpolated) string
        i18n.current                -- active language code (read-only)
        i18n.AVAILABLE              -- ordered list of {code, label} tables
--]]

local M = {}

M.current = "pt"   -- safe default; overwritten by load()

-- -------------------------------------------------------------------------
-- Available languages (order controls how they appear in the menu)
-- -------------------------------------------------------------------------

M.AVAILABLE = {
    { code = "pt", label = "Português" },
    { code = "en", label = "English"   },
    { code = "es", label = "Español"   },
    { code = "fr", label = "Français"  },
    { code = "de", label = "Deutsch"   },
    { code = "ko", label = "한국어"     },
}

-- -------------------------------------------------------------------------
-- String table
-- -------------------------------------------------------------------------

M.strings = {

    -- Portuguese ----------------------------------------------------------
    pt = {
        -- buttons / menu
        new              = "Novo",
        size             = "Tamanho",
        stats            = "Estatísticas",
        close            = "Fechar",
        cancel           = "Cancelar",
        confirm          = "Confirmar",

        -- header / status
        moves            = "Movimentos",
        time             = "Tempo",
        best             = "Melhor",
        best_label       = "Melhor: %1    Menos movimentos: %2",
        best_not_set     = "Melhor: ainda não definido",
        header           = "Puzzle %1x%1    Movimentos: %2    Tempo: %3",

        -- messages
        solved_message   = "Resolvido em %1 movimentos e %2.",
        solved_overlay   = "Você resolveu o puzzle %1x%1!\nMovimentos: %2\nTempo: %3",
        solved_play_again = "Resolvido! Toque em \"Novo\" para jogar novamente.",
        instruction      = "Toque em uma peça ou deslize.",
        invalid_move     = "Apenas peças ao lado do espaço podem se mover.",
        new_puzzle       = "Novo puzzle — boa sorte!",

        -- size dialog
        select_size      = "Selecionar tamanho",
        size_label       = "%1 × %1",

        -- stats dialog
        stats_title      = "Recordes",
        stat_col_size    = "Tam",
        stat_col_time    = "Tempo",
        stat_col_moves   = "Movim",
        stat_col_games   = "Jogos",
        reset_done       = "Melhores resultados apagados.",

        font_size        = "Fonte",
        increase_font    = "Aumentar fonte",
        decrease_font    = "Diminuir fonte",

        -- main menu
        menu_title       = "Slide Puzzle",
        play             = "Jogar",
        always_new       = "Ao abrir: sempre iniciar novo puzzle",
        resume           = "Ao abrir: continuar jogo salvo",
        reset            = "Resetar melhores resultados",
        reset_confirm    = "Deseja realmente apagar os melhores resultados?",

        large_font_on    = "Fonte dos números: grande",
        large_font_off   = "Fonte dos números: normal",

        -- language menu
        language         = "Idioma",
        select_language  = "Selecionar idioma",
        language_changed = "Idioma alterado. Feche e reabra o menu para aplicar.",
    },

    -- English -------------------------------------------------------------
    en = {
        new              = "New",
        size             = "Size",
        stats            = "Stats",
        close            = "Close",
        cancel           = "Cancel",
        confirm          = "Confirm",

        moves            = "Moves",
        time             = "Time",
        best             = "Best",
        best_label       = "Best: %1    Fewest moves: %2",
        best_not_set     = "Best: not set yet",
        header           = "%1x%1 Puzzle    Moves: %2    Time: %3",

        solved_message   = "Solved in %1 moves and %2.",
        solved_overlay   = "You solved the %1x%1 puzzle!\nMovmoves: %2\nTime: %3",
        solved_play_again = "Solved! Tap \"New\" to play again.",
        instruction      = "Tap a tile next to the gap, or swipe to slide.",
        invalid_move     = "Only tiles next to the gap can move.",
        new_puzzle       = "New puzzle — good luck!",

        select_size      = "Select board size",
        size_label       = "%1 × %1",

        stats_title      = "Records",
        stat_col_size    = "Size",
        stat_col_time    = "Time",
        stat_col_moves   = "Moves",
        stat_col_games   = "Games",
        reset_done       = "Best results cleared.",

        font_size        = "Font",
        increase_font    = "Increase font",
        decrease_font    = "Decrease font",

        menu_title       = "Slide Puzzle",
        play             = "Play",
        always_new       = "On open: always start a fresh puzzle",
        resume           = "On open: resume saved puzzle",
        reset            = "Reset best results",
        reset_confirm    = "Do you really want to clear best results?",

        large_font_on    = "Tile font: large",
        large_font_off   = "Tile font: normal",

        language         = "Language",
        select_language  = "Select language",
        language_changed = "Language changed. Close and reopen the menu to apply.",
    },

    -- Spanish -------------------------------------------------------------
    es = {
        new              = "Nuevo",
        size             = "Tamaño",
        stats            = "Estadísticas",
        close            = "Cerrar",
        cancel           = "Cancelar",
        confirm          = "Confirmar",

        moves            = "Movimientos",
        time             = "Tiempo",
        best             = "Mejor",
        best_label       = "Mejor: %1    Menos movimientos: %2",
        best_not_set     = "Mejor: aún no definido",
        header           = "Puzzle %1x%1    Movimientos: %2    Tempo: %3",

        solved_message   = "Resuelto en %1 movimientos y %2.",
        solved_overlay   = "¡Resolviste el puzzle %1x%1!\nMovimientos: %2\nTiempo: %3",
        solved_play_again = "¡Resuelto! Toca \"Nuevo\" para jugar de nuevo.",
        instruction      = "Toca una pieza junto al espacio vacío o desliza.",
        invalid_move     = "Solo las piezas junto al espacio pueden moverse.",
        new_puzzle       = "Nuevo puzzle — ¡buena suerte!",

        select_size      = "Seleccionar tamaño",
        size_label       = "%1 × %1",

        stats_title      = "Récords",
        stat_col_size    = "Tam",
        stat_col_time    = "Tiempo",
        stat_col_moves   = "Movim",
        stat_col_games   = "Juegos",
        reset_done       = "Mejores resultados borrados.",

        font_size        = "Fuente",
        increase_font    = "Aumentar fuente",
        decrease_font    = "Diminuir fuente",

        menu_title       = "Slide Puzzle",
        play             = "Jugar",
        always_new       = "Al abrir: siempre iniciar nuevo puzzle",
        resume           = "Al abrir: continuar juego guardado",
        reset            = "Reiniciar mejores resultados",
        reset_confirm    = "¿Desea borrar los mejores resultados?",

        large_font_on    = "Fuente de números: grande",
        large_font_off   = "Fuente de números: normal",

        language         = "Idioma",
        select_language  = "Seleccionar idioma",
        language_changed = "Idioma cambiado. Cierra y vuelve a abrir el menú para aplicar.",
    },

    -- French --------------------------------------------------------------
    fr = {
        new              = "Nouveau",
        size             = "Taille",
        stats            = "Statistiques",
        close            = "Fermer",
        cancel           = "Annuler",
        confirm          = "Confirmer",

        moves            = "Coups",
        time             = "Temps",
        best             = "Meilleur",
        best_label       = "Meilleur : %1    Moins de coups : %2",
        best_not_set     = "Meilleur : pas encore défini",
        header           = "Puzzle %1x%1    Coups : %2    Temps : %3",

        solved_message   = "Résolu en %1 coups et %2.",
        solved_overlay   = "Vous avez résolu le puzzle %1x%1 !\nCoups : %2\nTemps : %3",
        solved_play_again = "Résolu ! Appuyez sur « Nouveau » pour rejouer.",
        instruction      = "Appuyez sur une pièce à côté du vide ou faites glisser.",
        invalid_move     = "Seules les pièces à côté du vide peuvent bouger.",
        new_puzzle       = "Nouveau puzzle — bonne chance !",

        select_size      = "Choisir la taille",
        size_label       = "%1 × %1",

        stats_title      = "Records",
        stat_col_size    = "Tail",
        stat_col_time    = "Temps",
        stat_col_moves   = "Coups",
        stat_col_games   = "Jeux",
        reset_done       = "Meilleurs résultats effacés.",

        font_size        = "Police",
        increase_font    = "Agrandir la police",
        decrease_font    = "Réduire la police",

        menu_title       = "Slide Puzzle",
        play             = "Jouer",
        always_new       = "À l'ouverture : toujours commencer un nouveau puzzle",
        resume           = "À l'ouverture : reprendre la partie sauvegardée",
        reset            = "Réinitialiser les meilleurs résultats",
        reset_confirm    = "Voulez-vous vraiment effacer les meilleurs résultats ?",

        large_font_on    = "Police des chiffres : grande",
        large_font_off   = "Police des chiffres : normale",

        language         = "Langue",
        select_language  = "Choisir la langue",
        language_changed = "Langue modifiée. Fermez et rouvrez le menu pour appliquer.",
    },

    -- German --------------------------------------------------------------
    de = {
        new              = "Neu",
        size             = "Größe",
        stats            = "Statistiken",
        close            = "Schließen",
        cancel           = "Abbrechen",
        confirm          = "Bestätigen",

        moves            = "Züge",
        time             = "Zeit",
        best             = "Bestzeit",
        best_label       = "Bestzeit: %1    Wenigste Züge: %2",
        best_not_set     = "Bestzeit: noch nicht gesetzt",
        header           = "%1x%1-Puzzle    Züge: %2    Zeit: %3",

        solved_message   = "Gelöst in %1 Zügen und %2.",
        solved_overlay   = "Das %1x%1-Puzzle gelöst!\nZüge: %2\nZeit: %3",
        solved_play_again = 'Gelöst! Tippe auf "Neu", um erneut zu spielen.',
        instruction      = "Tippe auf eine Kachel neben dem Leerfeld oder wische.",
        invalid_move     = "Nur Kacheln neben dem Leerfeld können bewegt werden.",
        new_puzzle       = "Neues Puzzle — viel Erfolg!",

        select_size      = "Größe wählen",
        size_label       = "%1 × %1",

        stats_title      = "Rekorde",
        stat_col_size    = "Größ",
        stat_col_time    = "Zeit",
        stat_col_moves   = "Züge",
        stat_col_games   = "Spiel",
        reset_done       = "Bestresultate gelöscht.",

        font_size        = "Schriftart",
        increase_font    = "Schrift vergrößern",
        decrease_font    = "Schrift verkleinern",

        menu_title       = "Slide Puzzle",
        play             = "Spielen",
        always_new       = "Beim Öffnen: immer neues Puzzle starten",
        resume           = "Beim Öffnen: gespeichertes Spiel fortsetzen",
        reset            = "Bestresultate zurücksetzen",
        reset_confirm    = "Möchten Sie die Bestresultate wirklich löschen?",

        large_font_on    = "Kachelschrift: groß",
        large_font_off   = "Kachelschrift: normal",

        language         = "Sprache",
        select_language  = "Sprache wählen",
        language_changed = "Sprache geändert. Menü schließen und neu öffnen, um die Änderung anzuwenden.",
    },

    -- Korean --------------------------------------------------------------
    ko = {
        new              = "새 게임",
        size             = "크기",
        stats            = "통계",
        close            = "닫기",
        cancel           = "취소",
        confirm          = "확인",

        moves            = "이동 수",
        time             = "시간",
        best             = "최고 기록",
        best_label       = "최고 기록: %1    최소 이동: %2",
        best_not_set     = "최고 기록: 아직 없음",
        header           = "%1x%1 퍼즐    이동: %2    시간: %3",

        solved_message   = "%1번 이동, %2 만에 해결했습니다.",
        solved_overlay   = "%1x%1 퍼즐을 완성했습니다!\n이동 수: %2\n시간: %3",
        solved_play_again = "완성! \"새 게임\"을 눌러 다시 시작하세요.",
        instruction      = "빈 칸 옆의 조각을 누르거나 스와이프하세요.",
        invalid_move     = "빈 칸 옆의 조각만 이동할 수 있습니다.",
        new_puzzle       = "새 퍼즐 — 행운을 빕니다!",

        select_size      = "크기 선택",
        size_label       = "%1 × %1",

        stats_title      = "기록",
        stat_col_size    = "크기",
        stat_col_time    = "시간",
        stat_col_moves   = "이동",
        stat_col_games   = "게임",
        reset_done       = "최고 기록이 삭제되었습니다.",

        font_size        = "글꼴",
        increase_font    = "글꼴 크게",
        decrease_font    = "글꼴 작게",

        menu_title       = "슬라이드 퍼즐",
        play             = "게임 시작",
        always_new       = "열 때: 항상 새 퍼즐 시작",
        resume           = "열 때: 저장된 게임 계속",
        reset            = "최고 기록 초기화",
        reset_confirm    = "최고 기록을 정말 삭제하시겠습니까?",

        large_font_on    = "숫자 글꼴: 크게",
        large_font_off   = "숫자 글꼴: 보통",

        language         = "언어",
        select_language  = "언어 선택",
        language_changed = "언어가 변경되었습니다. 메뉴를 닫고 다시 열어 적용하세요.",
    },
}

-- -------------------------------------------------------------------------
-- Internal helpers
-- -------------------------------------------------------------------------

-- Lightweight positional template: replaces %1, %2, … with arguments.
-- Mirrors the behaviour of KOReader's ffi/util template() so callers
-- can use the same format strings regardless of whether they call this
-- module's M.t() or KOReader's T() directly.
local function fmt(s, ...)
    local args = { ... }
    return (s:gsub("%%(%d+)", function(n)
        return tostring(args[tonumber(n)] or "")
    end))
end

local function detectSystemLanguage()
    -- Walk locale variables in descending priority order.
    local vars = { "LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG" }
    for _, v in ipairs(vars) do
        local val = os.getenv(v) or ""
        -- Strip encoding / territory suffix (e.g. "pt_BR.UTF-8" → "pt_BR").
        val = val:match("^([^.@]+)") or ""
        -- Compare against each supported code.  We compare only the
        -- leading characters so that, e.g., "pt_BR" matches "pt".
        for _, entry in ipairs(M.AVAILABLE) do
            if val:lower():sub(1, #entry.code) == entry.code:lower() then
                return entry.code
            end
        end
    end
    return "pt"   -- ultimate fallback
end

-- -------------------------------------------------------------------------
-- Public API
-- -------------------------------------------------------------------------

--- Load (or detect) the language.  Must be called once during plugin init.
-- @param settings  LuaSettings instance belonging to the plugin.
function M.load(settings)
    local saved = settings and settings:readSetting("language")
    if saved and M.strings[saved] then
        M.current = saved
    else
        M.current = detectSystemLanguage()
    end
end

--- Change the active language and persist it immediately.
-- @param lang      Language code (must exist in M.strings).
-- @param settings  LuaSettings instance belonging to the plugin.
function M.set(lang, settings)
    if not M.strings[lang] then return end
    M.current = lang
    if settings then
        settings:saveSetting("language", lang)
        settings:flush()
    end
end

--- Translate a key, with optional positional argument interpolation.
-- Extra arguments beyond the key are substituted for %1, %2, … in the
-- translated string, so callers never need to call fmt() directly.
-- Falls back to the key name if the key is missing.
-- @param key   String key defined in M.strings[lang].
-- @param ...   Optional values to substitute into the string.
function M.t(key, ...)
    local lang_table = M.strings[M.current] or M.strings["pt"]
    local s = lang_table[key] or key
    if select("#", ...) > 0 then
        return fmt(s, ...)
    end
    return s
end

return M
