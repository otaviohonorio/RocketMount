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

commands["minimapa"] = function()
    ns.SetMinimapHidden(not ns.db.minimap.hide)
    ns.Print(ns.db.minimap.hide and "botão do minimapa escondido." or "botão do minimapa à mostra.")
end

commands["fontes"] = function()
    ns.db.sources = nil
    ns.Print("filtro de fonte limpo: todas as fontes voltam a aparecer.")
    ns.RefreshWindow()
end

-- Responde no chat o que o addon conseguiu ler. Existe para não precisar adivinhar
-- por que uma montaria caiu em "sem estimativa".
commands["debug"] = function(rest)
    -- (!) `/rmt debug <nome>` DESPEJA TUDO QUE O ADDON SABE DE UMA MONTARIA.
    --
    -- Existe porque um defeito voltou: *"ainda aparece Fênix Negra e etc o erro que passei
    -- anteriormente"*. Sem isto, a única forma de saber em que faixa ela caiu e por quê é eu
    -- adivinhar — e já está escrito no CLAUDE.md que adivinhar custa o tempo do usuário para
    -- descobrir o que uma linha de diagnóstico responde.
    local alvo = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if alvo ~= "" then
        local achou = 0
        for _, e in ipairs(ns.GetRanked(true)) do
            if (e.name or ""):lower():find(alvo, 1, true) then
                achou = achou + 1
                ns.Print("|cffffff00" .. (e.name or "?") .. "|r")
                print("    faixa: " .. (ns.TIER_NAME[e.tier] or "?") .. "  (" .. tostring(e.tier) .. ")")
                print("    número da direita: " .. tostring(e.headline))
                print("    determinística: " .. tostring(e.deterministic)
                    .. "   fonte: " .. ns.SOURCE_NAMES[e.sourceType] .. " (" .. tostring(e.sourceType) .. ")")
                print("    acesso: " .. tostring(e.access) .. "   preço: " .. tostring(e.price)
                    .. "   chance: " .. tostring(e.chance))
                print("    rep: " .. tostring(e.rep and e.rep.label))
                print("    conquista: " .. tostring(e.achievement and e.achievement.label))
                print("    custo: " .. tostring(e.cost and e.cost.price)
                    .. "   falta: " .. tostring(e.cost and e.cost.gap))
                print("    vendedor: " .. tostring(e.vendor and e.vendor.npc)
                    .. "   de guilda: " .. tostring(e.vendorGuilda))
                print("    texto do jogo: " .. tostring(e.sourceText))
            end
        end
        if achou == 0 then
            ns.Print("nenhuma montaria que falta tem \"" .. alvo .. "\" no nome.")
        end
        return
    end

    local mcl, rar = ns.ProviderStatus()
    ns.Print("MCL (chance de saque, coordenada):", mcl and "|cff33ff99lido|r" or "|cffff5555ausente|r")
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
    print("    |cffffff00/rmt minimapa|r — mostra ou esconde o botão do minimapa")
    print("    |cffffff00/rmt config|r — opções")
    print("    |cffffff00/rmt debug|r — o que o addon conseguiu ler")
    print("    |cffffff00/rmt debug <nome>|r — tudo que ele sabe de uma montaria")
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
