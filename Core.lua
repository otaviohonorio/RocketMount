-- RocketMounts | Core.lua
-- Namespace do addon: tudo que for compartilhado entre arquivos vai em `ns`.
local ADDON, ns = ...

ns.defaults = {
    -- Quantas linhas a lista mostra. "Por onde começar" não precisa de 400 linhas, e
    -- construir 400 linhas de frame na abertura custa caro por nada.
    topN = 100,
    -- Montaria que o jogo marca como indisponível para este personagem (facção errada,
    -- classe errada) só atrapalha uma lista cujo assunto é "o que dá para buscar".
    hideUnavailable = true,
    -- Fontes ligadas. A chave é o `sourceType` da API (ver ns.SOURCE_NAMES).
    sources = nil,   -- nil = todas
    window = nil,    -- { point, x, y } da última posição
    minimap = { angle = 200, hide = false },
}

function ns.Print(...)
    print("|cffff6a00Rocket|r Mounts:", ...)
end

--------------------------------------------------------------------------------
-- Eventos: tabela de despacho (O(1)) em vez de cadeia de if/elseif.
--------------------------------------------------------------------------------
local handlers = {}

function handlers:ADDON_LOADED(addon)
    if addon ~= ADDON then return end

    -- SavedVariables só existem a partir daqui.
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
    -- O MCL monta o `MCL_GUIDE.mountLookup` em PLAYER_LOGIN + 4s e não avisa ninguém.
    -- Em vez de chutar um atraso maior, a gente espera pelo sinal dele — e desiste
    -- depois de um tempo, porque ele pode simplesmente não estar instalado.
    ns.WaitForProviders()
end

function handlers:COMPANION_LEARNED()
    ns.Invalidate()
end

function handlers:NEW_MOUNT_ADDED()
    ns.Invalidate()
end

function handlers:UPDATE_FACTION()
    ns.Invalidate()
end

function handlers:CURRENCY_DISPLAY_UPDATE()
    ns.Invalidate()
end

local frame = CreateFrame("Frame", ADDON .. "EventFrame")
for event in pairs(handlers) do
    -- Evento que este cliente não conhece derruba o RegisterEvent inteiro.
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(self, event, ...)
    local h = handlers[event]
    if h then h(self, ...) end
end)

ns.frame = frame

--------------------------------------------------------------------------------
-- Cache da lista. Recalcular 400 montarias a cada evento de reputação seria
-- desperdício; a gente só marca como suja e recalcula quando a janela pedir.
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
-- Espera pelos provedores opcionais (MCL e MountJournalEnhanced).
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
