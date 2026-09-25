-- RocketMounts | Commands.lua
local _, ns = ...
local L = ns.L

-- (!) THE COMMAND NAMES ARE IN ENGLISH, and the Portuguese ones are aliases.
--
-- Same rule as RocketSwap: the addon ships worldwide, so `/rmt search` is the name and
-- `/rmt busca` still works -- somebody who played this in Portuguese for two weeks has the
-- word in their fingers, and refusing it over one language would be pedantry. The aliases
-- are declared at the bottom, in one place, so the table above reads as the real list.
local commands = {}

commands[""] = function()
    ns.ToggleWindow()
end

commands["config"] = function()
    if ns.category then
        Settings.OpenToCategory(ns.category:GetID())
    else
        ns.Print(L["the options panel has not registered yet."])
    end
end

-- `/rmt top` went away with the row cap: the list shows everything now. The command stays
-- here only to say so to whoever still types it, instead of answering "unknown command".
commands["top"] = function()
    ns.Print(L["the list shows every missing mount — the row cap was removed in 0.10.0."])
end

commands["minimap"] = function()
    ns.SetMinimapHidden(not ns.db.minimap.hide)
    ns.Print(ns.db.minimap.hide and L["minimap button hidden."] or L["minimap button shown."])
end

commands["expansion"] = function(rest)
    local arg = (ns.Fold and ns.Fold(rest or "") or (rest or ""):lower()):gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "" then
        ns.db.expFilter = nil
        ns.Print(L["expansion: all."])
        ns.Invalidate()
        return
    end
    for _, r in ipairs(ns.Expansion.RANGES) do
        -- Matched against BOTH the English name and the translation: the expansion names are
        -- copied from MountJournalEnhanced in English, and whoever plays in another language
        -- will type what the interface shows them.
        if ns.Fold(r.name):find(arg, 1, true) or ns.Fold(L[r.name]):find(arg, 1, true) then
            -- The same filter as the window's Expansion column.
            ns.db.expFilter = { [r.id] = true }
            ns.Print(string.format(L["expansion: %s"], L[r.name]))
            ns.Invalidate()
            return
        end
    end
    ns.Print(L["expansion not recognized. These exist:"])
    for _, r in ipairs(ns.Expansion.Menu()) do print("    " .. L[r.name]) end
end

commands["search"] = function(rest)
    ns.search = (rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if ns.search == "" then
        ns.Print(L["search cleared."])
    else
        ns.Print(string.format(L['searching for "%s".'], ns.search))
    end
    ns.Invalidate()
end

commands["warn"] = function()
    ns.db.sightings = not (ns.db.sightings ~= false)
    ns.Print(ns.db.sightings
        and L["mount sighting alert on."]
        or L["mount sighting alert off."])
end

-- Turns the ones that left the game on and off. It exists because the MCL catalogue knows
-- them, and a collector usually wants to SEE what they missed -- just not in the middle of a
-- list about where to start.
commands["gone"] = function()
    ns.db.showUnobtainable = not ns.db.showUnobtainable
    ns.Print(ns.db.showUnobtainable
        and L["also showing the ones that left the game."]
        or L["hiding the ones that left the game."])
    ns.Invalidate()
end

commands["faction"] = function(rest)
    local arg = (rest or ""):lower():gsub("%s", "")
    local mapa = {
        minha = "mine", mine = "mine",
        horda = "Horde", horde = "Horde",
        alianca = "Alliance", ["aliança"] = "Alliance", alliance = "Alliance",
    }
    ns.db.factionFilter = mapa[arg]
    local nomes = { mine = L["only what this character can get"],
                    Horde = L["Horde only"], Alliance = L["Alliance only"] }
    ns.Print(string.format(L["faction: %s"], nomes[ns.db.factionFilter] or L["all"]))
    ns.RefreshWindow()
end

commands["who"] = function(rest)
    -- (!) THE LEDGER IN ONE LINE. Without this, the only way to know whether it holds anything
    -- is to open one mount's card -- and an empty ledger (a single character) cannot answer
    -- "which of mine has it", and has to say so.
    local n = ns.Roster and ns.Roster.Count() or 0
    ns.Print(string.format(L["%d character(s) recorded. The ledger is written as each one logs in — log in with your alts once so they show up here."], n))
    if not (ns.db and ns.db.chars) then return end
    for _, c in pairs(ns.db.chars) do
        local quantas = 0
        for _ in pairs(c.reps or {}) do quantas = quantas + 1 end
        print(string.format(L["    %s%s  —  %d reputation(s) recorded"],
            c.name or "?", c.faction and (" (" .. c.faction .. ")") or "", quantas))
    end
end

commands["sources"] = function()
    -- The source filter is the window's Type column now.
    ns.db.tagFilter = nil
    ns.Print(L["source filter cleared: every source is back."])
    ns.RefreshWindow()
end

-- The labels the game hands us, and whether this client actually has them. Same command as
-- the other two addons, and it is the only way to find out from inside the game that a
-- global went missing after a patch.
commands["i18n"] = function()
    local report = ns.CheckGameStrings()
    ns.Print(string.format(L["locale %s, %d game label(s):"], GetLocale(), #report))

    local broken = 0
    for _, row in ipairs(report) do
        if row.text then
            print(string.format("  |cff33ff99ok|r    %-24s %s", row.tag, row.text))
        else
            broken = broken + 1
            print(string.format("  |cffff5555--|r    %-24s %s  (%s)", row.tag, row.key, row.why))
        end
    end

    if broken > 0 then
        ns.Print(string.format(L["%d game label(s) are not usable here."], broken))
    end
end

-- Answers in chat what the addon managed to read. It exists so nobody has to guess why a
-- mount landed in "no estimate".
commands["debug"] = function(rest)
    -- (!) `/rmt debug <name>` DUMPS EVERYTHING THE ADDON KNOWS ABOUT ONE MOUNT.
    --
    -- It exists because a defect came back: *"ainda aparece Fênix Negra e etc o erro que passei
    -- anteriormente"*. Without this, the only way to know which band it fell into and why is me
    -- guessing -- and the CLAUDE.md already says guessing spends the user's time to find out
    -- what one diagnostic line would answer.
    --
    -- The field labels below stay in English and out of `L` on purpose: they name internal
    -- fields whose VALUES are English too (`tier` numbers, `true`/`false`, the source id), and
    -- this dump gets copied into a conversation with me, not read as interface.
    local alvo = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if alvo ~= "" then
        local achou = 0
        for _, e in ipairs(ns.GetRanked(true)) do
            if (e.name or ""):lower():find(alvo, 1, true) then
                achou = achou + 1
                ns.Print("|cffffff00" .. (e.name or "?") .. "|r")
                print("    band: " .. (ns.TIER_NAME[e.tier] or "?") .. "  (" .. tostring(e.tier) .. ")")
                print("    headline: " .. tostring(e.headline))
                print("    deterministic: " .. tostring(e.deterministic)
                    .. "   source: " .. ns.SOURCE_NAMES[e.sourceType] .. " (" .. tostring(e.sourceType) .. ")")
                print("    access: " .. tostring(e.access) .. "   price: " .. tostring(e.price)
                    .. "   chance: " .. tostring(e.chance))
                print("    rep: " .. tostring(e.rep and e.rep.label))
                print("    achievement: " .. tostring(e.achievement and e.achievement.label))
                print("    cost: " .. tostring(e.cost and e.cost.price)
                    .. "   gap: " .. tostring(e.cost and e.cost.gap))
                print("    vendor: " .. tostring(e.vendor and e.vendor.npc)
                    .. "   guild vendor: " .. tostring(e.vendorGuilda))
                print("    game text: " .. tostring(e.sourceText))
                print("    percent: " .. ns.RowPercentText(e)
                    .. "   tooltip gate: " .. tostring(e.tooltipGate and e.tooltipGate.label))
                print("    item: " .. tostring(e.itemID) .. "   tooltip: " .. tostring(e.tooltipState))
                for _, linha in ipairs(e.itemID and ns.Tooltip.Dump(e.itemID) or {}) do
                    print("      " .. linha)
                end
            end
        end
        if achou == 0 then
            ns.Print(string.format(L['no missing mount has "%s" in its name.'], alvo))
        end
        return
    end

    local mcl, rar = ns.ProviderStatus()
    ns.Print(L["MCL (drop chance, coordinates):"],
        mcl and L["|cff33ff99read|r"] or L["|cffff5555missing|r"])
    ns.Print(L["MountJournalEnhanced (share of the playerbase):"],
        rar and L["|cff33ff99read|r"] or L["|cffff5555missing|r"])

    local list = ns.GetRanked(true)
    local byTier = {}
    for _, e in ipairs(list) do
        byTier[e.tier] = (byTier[e.tier] or 0) + 1
    end
    ns.Print(string.format(L["%d mounts missing on this character:"], #list))
    for t = 1, 6 do
        if byTier[t] then
            print(string.format("    %s: %d", ns.TIER_NAME[t], byTier[t]))
        end
    end
end

-- (!) "SÓ AVISAR" (25/09): on login, once the list is checked, the mounts THIS character is the
-- closest to among all of yours -- a legacy reputation it has, or has more of than any alt.
local avisado = false
function ns.ClosestHereNotice(force)
    if avisado and not force then return end
    avisado = true
    local achados = {}
    for _, e in ipairs(ns.GetRanked(true)) do
        local r = e.rep
        if r and not r.char and r.scope == "personagem" and r.pct and r.pct > 0
            and r.altPct ~= nil and r.pct > r.altPct then
            achados[#achados + 1] = e
        end
    end
    if #achados == 0 then return end
    table.sort(achados, function(a, b)
        if a.rep.pct ~= b.rep.pct then return a.rep.pct > b.rep.pct end
        return (a.name or "") < (b.name or "")
    end)
    ns.Print(string.format(L["this character is the closest of yours to %d mount(s):"], #achados))
    for i = 1, math.min(#achados, 5) do
        local e = achados[i]
        print(string.format("    %s  —  %s", e.name or "?", ns.RowPercentText(e)))
    end
end

-- THE DIARY, in chat. Only in development: the packaged addon has no `Log.lua` (see Core.lua).
commands["log"] = function(rest)
    if not ns.Log.enabled then
        ns.Print(L["the log only exists in development builds."])
        return
    end
    rest = (rest or ""):lower()
    if rest == "clear" then
        ns.Log.Clear()
        ns.Print(L["log cleared."])
    elseif rest == "on" or rest == "off" then
        ns.db.logLive = rest == "on"
        ns.Print(ns.db.logLive and L["log: every line is also printed in chat."]
            or L["log: chat echo off."])
    else
        ns.Print(string.format(L["alert %s; last lines of the log:"],
            ns.db.sightings == false and L["OFF"] or L["on"]))
        for _, linha in ipairs(ns.Log.Tail(15)) do print("  " .. linha) end
        ns.Log.PrintErrors()
    end
end

commands["help"] = function()
    ns.Print(L["commands:"])
    print("    |cffffff00/rmt|r                  " .. L["opens and closes the list"])
    print("    |cffffff00/rmt sources|r          " .. L["clears the source filter"])
    -- `||` is a literal pipe: a single `|h` in the middle of "mine|horde" is the hyperlink
    -- escape, and the game would eat the rest of the line. The Portuguese version had the
    -- same bug with "minha|horda".
    print("    |cffffff00/rmt faction [mine||horde||alliance]|r  " .. L["filters by faction"])
    print("    |cffffff00/rmt gone|r             " .. L["shows or hides the ones that left the game"])
    print("    |cffffff00/rmt warn|r             " .. L["turns the mount sighting alert on or off"])
    print("    |cffffff00/rmt search <text>|r    " .. L["searches by name, boss, zone or vendor"])
    print("    |cffffff00/rmt expansion [name]|r " .. L["filters by expansion"])
    print("    |cffffff00/rmt who|r              " .. L["the characters recorded and how many reputations each one has"])
    print("    |cffffff00/rmt minimap|r          " .. L["shows or hides the minimap button"])
    print("    |cffffff00/rmt config|r           " .. L["options"])
    print("    |cffffff00/rmt i18n|r             " .. L["checks the labels taken from the game"])
    print("    |cffffff00/rmt debug|r            " .. L["what the addon managed to read"])
    print("    |cffffff00/rmt debug <name>|r     " .. L["everything it knows about one mount"])
    if ns.Log.enabled then
        print("    |cffffff00/rmt log [on||off||clear]|r " .. L["the development log"])
    end
end

-- The Portuguese names this addon shipped with, kept working. One table, so adding a command
-- never means remembering to add an alias in a second place further down the file.
local ALIASES = {
    minimapa = "minimap",
    expansao = "expansion", ["expansão"] = "expansion",
    busca = "search",
    aviso = "warn", alerta = "warn",
    sumidas = "gone",
    faccao = "faction", ["facção"] = "faction",
    quem = "who",
    fontes = "sources",
    ajuda = "help",
}

SLASH_ROCKETMOUNT1 = "/rmt"
SLASH_ROCKETMOUNT2 = "/rocketmount"

SlashCmdList["ROCKETMOUNT"] = function(msg)
    local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    -- The sentinel key can never be a command, so an unknown word falls through to help
    -- instead of quietly toggling the window (which is what `commands[""]` does).
    local handler = commands[cmd] or commands[ALIASES[cmd] or "\0"]
    if handler then
        handler(rest)
    else
        commands["help"]()
    end
end
