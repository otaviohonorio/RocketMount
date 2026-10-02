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
    -- The size of the markers on the world map, in percent of the game's quest pin (02/10).
    mapPinScale = 100,
    minimapPinScale = 100,
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

-- (!) THE OPENING OF THE GAME IS NOT THE ADDON'S TO SPEND (02/10). Everything used to happen
-- inside PLAYER_LOGIN, in the one frame the game is busiest: the ledger, the calendar, the
-- Trading Post, the first list. Now only what costs nothing is done there (the button, the
-- modules that listen); the rest waits START_DELAY seconds for the world to be on screen and
-- then goes one step per frame, each step of the heavy ones sliced in turn (the list in
-- Score.lua, the achievements in Achievements.lua, the items in Tooltip.lua).
local START_DELAY = 3
ns.START_DELAY = START_DELAY

function handlers:PLAYER_LOGIN()
    ns.CreateMinimapButton()
    if ns.Sighting then ns.Sighting.Enable() end
    if ns.MapPins then ns.MapPins.Enable() end
    if ns.MinimapPins then ns.MinimapPins.Enable() end
    if ns.MapButton then ns.MapButton.Enable() end

    local passos = {
        -- O livro-caixa se escreve ao entrar, que é quando a API fala deste personagem.
        function() if ns.Roster then ns.Roster.Record() end end,
        -- The calendar of events is asked of the server (no window opens): the vendors of an
        -- event count only while the calendar says the event is on (Sources.lua, `ns.EventOn`).
        function() if C_Calendar and C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end end,
        -- And the Trading Post is asked what is on offer, in case the game already knows.
        function() if ns.ReadPerks then pcall(ns.ReadPerks) end end,
        function() ns.Start() end,
    }
    local function Proximo(i)
        local passo = passos[i]
        if not passo then return end
        pcall(passo)
        if passos[i + 1] then
            if C_Timer and C_Timer.After then C_Timer.After(0, function() Proximo(i + 1) end) else Proximo(i + 1) end
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(START_DELAY, function() Proximo(1) end) else Proximo(1) end
end

function handlers:COMPANION_LEARNED()
    ns.Invalidate()
end

function handlers:NEW_MOUNT_ADDED()
    ns.Invalidate()
end

-- (!) THE LEDGER IS WRITTEN A LITTLE LATER, ONCE (02/10). Reputation moves at every kill, and
-- each event read some sixty factions again. Five seconds later, once for however many came.
local ledgerSoon, ledgerAt = false, 0
local function RecordSoon()
    if not ns.Roster then return end
    local agora = GetTime and GetTime() or 0
    -- (A wait that never came back -- a timer lost -- does not hold the ledger for ever.)
    if ledgerSoon and (agora - ledgerAt) < 30 then return end
    ledgerSoon, ledgerAt = true, agora
    local function Agora()
        ledgerSoon = false
        if ns.Roster then ns.Roster.Record() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(5, Agora) else Agora() end
end

function handlers:UPDATE_FACTION()
    RecordSoon()
    ns.Invalidate(true)
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
    RecordSoon()
    ns.Invalidate(true)
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
        ns.Invalidate(true)
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
    ns.Invalidate(true)
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
--
-- (!) "WHEN SOMETHING ASKS" WAS EVERY TWO SECONDS (02/10). The user: *"quando abro o jogo ele
-- sobe bem o uso de CPU do addon e a memória também"*. The diary of that morning had the
-- answer: in 1 h 44 of play the whole list (658 mounts, each with its tooltip, reputation,
-- achievements and price read from the game) was built 265 times -- up to 24 times in one
-- minute, one every 2 seconds on the median. Two things met: the events that mark the list
-- dirty are constant while playing (gold, bags, reputation, currency, criteria), and the rare
-- alert asks for the list at every nameplate, mouseover and vignette. Each build is CPU, and
-- every table it makes is garbage for the collector.
--
-- So the dirt has two kinds:
--   URGENT  the SET of mounts changed, or the player asked for something (a mount learned, an
--           option, a vendor read): the next one to ask gets a new list;
--   LAZY    only numbers changed (gold, a reputation point, a criterion): whoever works in
--           the background -- the rare alert, the map, the minimap -- goes on with the list it
--           has, and a new one is made at most every LAZY_INTERVAL seconds. The addon's own
--           window always shows a fresh list, at most once a second.
--------------------------------------------------------------------------------
local LAZY_INTERVAL = 20
local dirty, urgent, builtAt = true, true, 0
local refreshSoon = false
ns.LAZY_INTERVAL = LAZY_INTERVAL

local function Clock() return GetTime and GetTime() or 0 end

local serial = 0
---A number that changes at every Invalidate: a sliced build compares it at its end to know
---whether something changed while it worked.
function ns.DirtySerial() return serial end

---@param lazy boolean|nil true when only numbers changed (see above)
function ns.Invalidate(lazy)
    dirty = true
    serial = serial + 1
    if not lazy then urgent = true end
    if not (ns.window and ns.window:IsShown()) then return end
    if not lazy then
        ns.RefreshWindow()
    elseif not refreshSoon then
        -- The open window follows the numbers, once a second however many events arrive.
        refreshSoon = true
        local function Agora()
            refreshSoon = false
            if ns.window and ns.window:IsShown() then ns.RefreshWindow() end
        end
        if C_Timer and C_Timer.After then C_Timer.After(1, Agora) else Agora() end
    end
end

function ns.IsDirty()
    return dirty
end

---Is a new list due? `fresh` is the addon's own window: it does not live with old numbers.
function ns.NeedsRebuild(fresh)
    if not dirty then return false end
    if urgent or fresh then return true end
    return (Clock() - builtAt) >= LAZY_INTERVAL
end

function ns.MarkClean()
    dirty, urgent, builtAt = false, false, Clock()
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
    -- The first list, in slices; and only once it exists, the achievement scan (it matches the
    -- reward text against the mounts that are MISSING) and the validation of the items.
    ns.WhenBuilt(function()
        if ns.Achievements then ns.Achievements.Scan() end
        ns.StartValidation()
    end)
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
        -- The list that is there: the opening just built it, and the scan's end marked it
        -- due again -- the items are the same either way.
        local ok, lista = pcall(ns.GetRanked)
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
