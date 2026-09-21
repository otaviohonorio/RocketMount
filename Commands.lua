-- RocketMounts | Commands.lua
local _, ns = ...

local commands = {}

commands[""] = function()
    ns.ToggleWindow()
end

commands["config"] = function()
    if ns.category then
        Settings.OpenToCategory(ns.category:GetID())
    else
        ns.Print("o painel de opções ainda não registrou.")
    end
end

commands["top"] = function(rest)
    local n = tonumber(rest)
    if not n or n < 10 or n > 400 then
        ns.Print("uso: /rmt top <10 a 400>. Agora está em " .. tostring(ns.db.topN) .. ".")
        return
    end
    ns.db.topN = math.floor(n)
    ns.Print("a lista passa a mostrar as " .. ns.db.topN .. " primeiras.")
    ns.RefreshWindow()
end

commands["fontes"] = function()
    ns.db.sources = nil
    ns.Print("filtro de fonte limpo: todas as fontes voltam a aparecer.")
    ns.RefreshWindow()
end

-- Responde no chat o que o addon conseguiu ler. Existe para não precisar adivinhar
-- por que uma montaria caiu em "sem estimativa".
commands["debug"] = function()
    local mcl, rar = ns.ProviderStatus()
    ns.Print("MCL (taxa de queda, coordenada):", mcl and "|cff33ff99lido|r" or "|cffff5555ausente|r")
    ns.Print("MountJournalEnhanced (percentual da base):", rar and "|cff33ff99lido|r" or "|cffff5555ausente|r")

    local list = ns.GetRanked(true)
    local byTier = {}
    for _, e in ipairs(list) do
        byTier[e.tier] = (byTier[e.tier] or 0) + 1
    end
    ns.Print(#list .. " montarias faltando neste personagem:")
    for t = 1, 6 do
        if byTier[t] then
            print(string.format("    %s: %d", ns.TIER_NAME[t], byTier[t]))
        end
    end
end

commands["help"] = function()
    ns.Print("comandos:")
    print("    |cffffff00/rmt|r — abre e fecha a lista")
    print("    |cffffff00/rmt top <n>|r — quantas linhas a lista mostra")
    print("    |cffffff00/rmt fontes|r — limpa o filtro de fonte")
    print("    |cffffff00/rmt config|r — opções")
    print("    |cffffff00/rmt debug|r — o que o addon conseguiu ler")
end

SLASH_ROCKETMOUNTS1 = "/rmt"
SLASH_ROCKETMOUNTS2 = "/rocketmounts"

SlashCmdList["ROCKETMOUNTS"] = function(msg)
    local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    local handler = commands[(cmd or ""):lower()]
    if handler then
        handler(rest)
    else
        commands["help"]()
    end
end
