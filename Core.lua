-- RocketMount | Core.lua
-- Addon namespace: everything shared between files lives in `ns`.
local ADDON, ns = ...

ns.defaults = {
    -- (!) `topN` WAS REMOVED in 0.10.0. It capped the list at 100 rows "because building 400
    -- frames on open is expensive", and the price was the player finding no recent-expansion
    -- mount at all: those sit at the far end of a list ordered by effort, which is exactly the
    -- part the cap removed. The right answer was not to draw what is off screen, not to hide
    -- what exists.
    -- A mount the game marks as unavailable to this character (wrong faction, wrong
    -- class) only gets in the way of a list whose subject is "what can I go after".
    hideUnavailable = true,
    -- (!) MONTARIA QUE SAIU DO JOGO FICA DE FORA POR PADRÃO (0.8.0).
    --
    -- Promoções encerradas, montarias de card game e conquistas aposentadas: numa lista cujo
    -- assunto é "por onde começar", montaria que ninguém mais consegue é a pior linha possível.
    -- (28/09) A marca vinha de outro addon; hoje nenhuma tabela NOSSA a tem (`ns.MountGone`), e
    -- por isso nenhuma montaria está marcada. A opção fica para quando houver fonte.
    showUnobtainable = false,
    -- A busca NÃO é salva entre sessões de propósito: abrir a janela e encontrar a lista já
    -- filtrada por algo que se digitou semana passada é uma lista que parece quebrada.
    -- (fica em `ns.search`, fora do banco)
    -- Enabled sources. The key is the API `sourceType` (see ns.SOURCE_NAMES).
    sources = nil,   -- nil = all of them
    window = nil,    -- { point, x, y } of the last position
    minimap = { angle = 200, hide = false },
    -- O livro-caixa de reputação por personagem (ver `Roster.lua`). Fica em SavedVariables de
    -- CONTA de propósito: a pergunta que ele responde é sobre os outros personagens.
    chars = {},
    -- Filtro de facção: nil = tudo, "mine" = só o que este personagem pode, "Horde", "Alliance".
    factionFilter = nil,
    -- Filtro de expansão: nil = todas, ou o índice de `ns.Expansion.RANGES`.
    expansionFilter = nil,
    -- O aviso de bicho que larga montaria. Ligado por padrão, com caixa para desligar: o
    -- usuário foi explícito que nem todo mundo quer receber.
    sightings = true,
    -- The alert's sound (01/10): on, the chime, at the middle level of five ("leve").
    sightingSound = true,
    sightingSoundKey = "chime",
    sightingVolume = 60,
    sightingPos = nil,
}

-- THE DIARY IS A DEVELOPMENT TOOL, NEVER SHIPPED. The user's rule (23/09): *"quando forem
-- publicados não devem gerar os logs, por que vai ficar consumindo espaço e disco do usuário,
-- apenas aqui para desenvolvimento"*. `Log.lua` and `RocketMountLogDB` sit inside `#@debug@` in
-- the .toc, which the packager strips from every build (alpha included); `.pkgmeta` also keeps
-- the file out of the zip.
--
-- This stand-in is what a player gets: every call answers nothing, so the code that writes to
-- the diary never needs a guard, and forgetting one cannot break a release. `Log.lua`, loaded
-- after this file in development, replaces it with the real one.
ns.Log = setmetatable({ enabled = false }, {
    __index = function() return function() end end,
})

function ns.Print(...)
    print("|cffff6a00Rocket|r Mount:", ...)
end

--------------------------------------------------------------------------------
-- Events: a dispatch table (O(1)) instead of an if/elseif chain.
--------------------------------------------------------------------------------
local handlers = {}

function handlers:ADDON_LOADED(addon)
    -- The world map can load after us; its pins wait for it.
    if addon == "Blizzard_WorldMap" and ns.MapPins then
        ns.MapPins.Enable()
        if ns.MapButton then ns.MapButton.Enable() end
        return
    end
    if addon ~= ADDON then return end

    -- SavedVariables only exist from here on.
    RocketMountDB = RocketMountDB or {}
    for k, v in pairs(ns.defaults) do
        if RocketMountDB[k] == nil then
            RocketMountDB[k] = v
        end
    end
    ns.db = RocketMountDB
    -- The window's filters became columns (25/09): a saved single expansion becomes the
    -- Expansion column's choice, and the old source filter -- no longer on screen -- is dropped
    -- rather than left hiding mounts invisibly.
    if ns.db.expansionFilter ~= nil then
        ns.db.expFilter = { [ns.db.expansionFilter] = true }
        ns.db.expansionFilter = nil
    end
    ns.db.sources = nil
    ns.Log.Init()

    if ns.SetupOptions then
        ns.SetupOptions()
    end
end

function handlers:PLAYER_LOGIN()
    ns.CreateMinimapButton()
    -- O livro-caixa se escreve ao entrar, que é quando a API fala deste personagem.
    if ns.Roster then ns.Roster.Record() end
    if ns.Sighting then ns.Sighting.Enable() end
    if ns.MapPins then ns.MapPins.Enable() end
    if ns.MinimapPins then ns.MinimapPins.Enable() end
    if ns.MapButton then ns.MapButton.Enable() end
    -- The calendar of events is asked of the server (no window opens): the vendors of an event
    -- count only while the calendar says the event is on (Sources.lua, `ns.EventOn`).
    if C_Calendar and C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end
    -- And the Trading Post is asked what is on offer, in case the game already knows.
    if ns.ReadPerks then pcall(ns.ReadPerks) end
    ns.Start()
end

function handlers:COMPANION_LEARNED()
    ns.Invalidate()
end

function handlers:NEW_MOUNT_ADDED()
    ns.Invalidate()
end

function handlers:UPDATE_FACTION()
    if ns.Roster then ns.Roster.Record() end
    ns.Invalidate()
end

-- (!) EVERYTHING THE LIST READS ABOUT THE CHARACTER HAS ITS EVENT (01/10). The user: *"o addon
-- precisa fazer isso de forma rotineira, para ir atualizando os dados conforme os jogadores vão
-- mudando de char"*. Changing character is a new login, and the login reads everything again;
-- what was missing is what changes DURING the session and had no event here: renown (a
-- faction's and a covenant's), the covenant itself, an achievement earned, a quest handed in,
-- gold. Until one of the events above happened to fire, the list and the map kept the number
-- of before. The names are the client's (MajorFactionsDocumentation, CovenantSanctum-,
-- CovenantsDocumentation, 12.1.0). Each only marks the list dirty: it is built again when
-- something asks for it.
local function CharacterChanged()
    if ns.Roster then ns.Roster.Record() end
    ns.Invalidate()
end
handlers.MAJOR_FACTION_RENOWN_LEVEL_CHANGED = CharacterChanged
handlers.MAJOR_FACTION_UNLOCKED = CharacterChanged
handlers.COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED = CharacterChanged
handlers.COVENANT_CHOSEN = CharacterChanged
handlers.ACHIEVEMENT_EARNED = CharacterChanged
handlers.QUEST_TURNED_IN = CharacterChanged
handlers.PLAYER_MONEY = CharacterChanged
-- The item's own red lines ("Requires Level 40", "Requires Leatherworking") and which faction's
-- mounts are this character's.
handlers.PLAYER_LEVEL_UP = CharacterChanged
handlers.SKILL_LINES_CHANGED = CharacterChanged
handlers.NEUTRAL_FACTION_SELECT_RESULT = CharacterChanged

-- (!) THE BAGS AND THE CRITERIA OF AN ACHIEVEMENT CHANGE ALL THE TIME (every loot, every kill
-- that counts), and both are read by the list: a price in ITEMS ("3 x Coin"), an achievement
-- "40% done". Building 1,600 rows at each would be waste, so these two wait a second and
-- answer once for however many arrived.
local soon = false
local function ChangedOften()
    if soon then return end
    soon = true
    local function Now()
        soon = false
        ns.Invalidate()
    end
    if C_Timer and C_Timer.After then C_Timer.After(1, Now) else Now() end
end
handlers.BAG_UPDATE_DELAYED = ChangedOften
handlers.CRITERIA_UPDATE = ChangedOften

-- THE VENDOR, the moment it opens and every time its list refreshes (items load late).
function handlers:MERCHANT_SHOW()
    if ns.ScanMerchant and ns.ScanMerchant() then ns.Invalidate() end
end

function handlers:MERCHANT_UPDATE()
    if ns.ScanMerchant and ns.ScanMerchant() then ns.Invalidate() end
end

function handlers:CURRENCY_DISPLAY_UPDATE()
    ns.Invalidate()
end

-- The game's list of events changed (a holiday started, the calendar arrived from the server):
-- the vendors of an event are asked again.
-- The Trading Post told what is on offer (its window opened, its data arrived): kept, and the
-- list built again when the offer is another.
function handlers:PERKS_PROGRAM_DATA_REFRESH()
    if ns.ReadPerks and ns.ReadPerks() then ns.Invalidate() end
end

function handlers:PERKS_PROGRAM_OPEN()
    if ns.ReadPerks and ns.ReadPerks() then ns.Invalidate() end
end

function handlers:CALENDAR_UPDATE_EVENT_LIST()
    if ns.CalendarChanged and ns.CalendarChanged() then ns.Invalidate() end
end

local frame = CreateFrame("Frame", ADDON .. "EventFrame")
for event in pairs(handlers) do
    -- An event this client does not know brings the whole RegisterEvent down.
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(self, event, ...)
    local h = handlers[event]
    if h then h(self, ...) end
end)

ns.frame = frame

--------------------------------------------------------------------------------
-- List cache. Recomputing 400 mounts on every reputation event would be waste; we only
-- mark it dirty and recompute when the window asks.
--------------------------------------------------------------------------------
local dirty = true

function ns.Invalidate()
    dirty = true
    if ns.window and ns.window:IsShown() then
        ns.RefreshWindow()
    end
end

function ns.IsDirty()
    return dirty
end

function ns.MarkClean()
    dirty = false
    -- O índice de bichos vive da lista: refaz junto, e não a cada raro que aparece.
    if ns.Sighting then ns.Sighting.Rebuild() end
    -- And the map pins, which read that same index.
    if ns.MapPins then ns.MapPins.Refresh() end
end

--------------------------------------------------------------------------------
-- The first list of the session. Nothing to wait for: every table the list reads is the addon's
-- own, and it is already loaded.
--------------------------------------------------------------------------------
function ns.Start()
    ns.Invalidate()
    -- The achievement scan starts only once the list exists: it matches the reward text against
    -- the mounts that are MISSING.
    if ns.Achievements then ns.Achievements.Scan() end
    ns.StartValidation()
end

--------------------------------------------------------------------------------
-- THE VALIDATION, before the list is shown.
--
-- (!) The user (23/09), after reaching an NPC that would not sell: *"cada vez que um char logar,
-- tem que validar (...) faça todas as validações antes de mostrar essa tela, mesmo que demore
-- para carregar, coloca uma barra de loading"*. Per character, at every login: wait for the
-- achievement scan, then have the server send every missing mount's item, so each tooltip is
-- read with its content and not empty. Until then the window shows the bar, not a list that
-- would be half-checked.
--------------------------------------------------------------------------------
ns.validation = { state = "idle", done = 0, total = 0 }

local ESPERA_CONQUISTAS = 30   -- seconds; the scan runs in slices of 40 per frame

function ns.ValidationDone()
    return ns.validation.state == "done"
end

function ns.OnValidationProgress()
    if ns.Tooltip then
        ns.validation.done, ns.validation.total = ns.Tooltip.Progress()
    end
    if ns.UpdateLoading then ns.UpdateLoading() end
end

function ns.StartValidation()
    if ns.validation.state ~= "idle" then return end
    ns.validation.state = "running"
    ns.Log.Add("validate", { phase = "start" })

    local espera = 0
    local function Itens()
        local ids = {}
        local ok, lista = pcall(ns.GetRanked, true)
        local vistos = {}
        for _, e in ipairs(ok and lista or {}) do
            if e.itemID then ids[#ids + 1] = e.itemID end
            -- The items a mount COSTS, too: the card quotes what the game says about them.
            for _, p in ipairs(e.cost and e.cost.parts or {}) do
                if p.type == "item" and p.id and not vistos[p.id] then
                    vistos[p.id] = true
                    ids[#ids + 1] = p.id
                end
            end
        end
        ns.Log.Add("validate", { phase = "items", items = #ids })
        ns.Tooltip.Preload(ids, function()
            ns.validation.state = "done"
            if ns.ClosestHereNotice then ns.ClosestHereNotice() end
            local feitos, total = ns.Tooltip.Progress()
            ns.Log.Add("validate", { phase = "done", loaded = feitos, requested = total })
            ns.Invalidate()
            ns.OnValidationProgress()
            if ns.RefreshWindow then ns.RefreshWindow() end
        end)
        ns.OnValidationProgress()
    end
    local function Conquistas()
        local pronto = not ns.Achievements or ns.Achievements.IsDone()
        if pronto or espera >= ESPERA_CONQUISTAS then return Itens() end
        espera = espera + 0.5
        C_Timer.After(0.5, Conquistas)
    end
    Conquistas()
end

function RocketMount_OnCompartmentClick()
    ns.ToggleWindow()
end
