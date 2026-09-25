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
    -- O addon lia a marca `isUnobtainable` do MCL desde a primeira versão e **nunca a usava**:
    -- promoções encerradas, montarias de card game e conquistas aposentadas entravam na lista e
    -- eram ranqueadas junto com as que dá para pegar. Numa lista cujo assunto é "por onde
    -- começar", montaria que ninguém mais consegue é a pior linha possível.
    --
    -- O MCL esconde essas por padrão (`MCL_SETTINGS.unobtainable = false`) e deixa ligar; aqui
    -- é igual, e aí quem quer ver o catálogo completo vê.
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
    -- MCL builds `MCL_GUIDE.mountLookup` at PLAYER_LOGIN + 4s and tells nobody. Rather
    -- than guessing a longer delay, we wait for its own ready flag -- and give up after a
    -- while, because it may simply not be installed.
    ns.WaitForProviders()
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
-- Waiting for the optional providers (MCL and MountJournalEnhanced).
--------------------------------------------------------------------------------
local WAIT_STEP = 1
local WAIT_GIVEUP = 20

function ns.WaitForProviders(elapsed)
    elapsed = elapsed or 0
    if ns.ProvidersReady() or elapsed >= WAIT_GIVEUP then
        ns.Invalidate()
        -- A varredura de conquistas só começa depois de a lista existir: ela casa o texto de
        -- recompensa contra as montarias que FALTAM, e antes disso não há contra o que casar.
        if ns.Achievements then ns.Achievements.Scan() end
        ns.StartValidation()
        return
    end
    C_Timer.After(WAIT_STEP, function()
        ns.WaitForProviders(elapsed + WAIT_STEP)
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
        local ok, lista = pcall(ns.GetRanked, true)
        for _, e in ipairs(ok and lista or {}) do
            if e.itemID then ids[#ids + 1] = e.itemID end
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
