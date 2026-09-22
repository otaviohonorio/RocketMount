-- RocketMounts | Core.lua
-- Addon namespace: everything shared between files lives in `ns`.
local ADDON, ns = ...

ns.defaults = {
    -- How many rows the list shows. "Where do I start" does not need 400 rows, and
    -- building 400 frame rows on open costs a lot for nothing.
    topN = 100,
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
    -- Enabled sources. The key is the API `sourceType` (see ns.SOURCE_NAMES).
    sources = nil,   -- nil = all of them
    window = nil,    -- { point, x, y } of the last position
    minimap = { angle = 200, hide = false },
    -- O livro-caixa de reputação por personagem (ver `Roster.lua`). Fica em SavedVariables de
    -- CONTA de propósito: a pergunta que ele responde é sobre os outros personagens.
    chars = {},
    -- Filtro de facção: nil = tudo, "mine" = só o que este personagem pode, "Horde", "Alliance".
    factionFilter = nil,
}

function ns.Print(...)
    print("|cffff6a00Rocket|r Mounts:", ...)
end

--------------------------------------------------------------------------------
-- Events: a dispatch table (O(1)) instead of an if/elseif chain.
--------------------------------------------------------------------------------
local handlers = {}

function handlers:ADDON_LOADED(addon)
    if addon ~= ADDON then return end

    -- SavedVariables only exist from here on.
    RocketMountsDB = RocketMountsDB or {}
    for k, v in pairs(ns.defaults) do
        if RocketMountsDB[k] == nil then
            RocketMountsDB[k] = v
        end
    end
    ns.db = RocketMountsDB

    if ns.SetupOptions then
        ns.SetupOptions()
    end
end

function handlers:PLAYER_LOGIN()
    ns.CreateMinimapButton()
    -- O livro-caixa se escreve ao entrar, que é quando a API fala deste personagem.
    if ns.Roster then ns.Roster.Record() end
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
        return
    end
    C_Timer.After(WAIT_STEP, function()
        ns.WaitForProviders(elapsed + WAIT_STEP)
    end)
end

function RocketMounts_OnCompartmentClick()
    ns.ToggleWindow()
end
