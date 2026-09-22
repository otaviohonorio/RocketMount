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

-- `/rmt top` saiu junto com o teto de linhas: a lista mostra tudo agora. O comando fica aqui
-- só para dizer isso a quem o tinha no dedo, em vez de responder "comando desconhecido".
commands["top"] = function()
    ns.Print("a lista mostra todas as montarias que faltam — o limite de linhas saiu na 0.10.0.")
end

commands["minimapa"] = function()
    ns.SetMinimapHidden(not ns.db.minimap.hide)
    ns.Print(ns.db.minimap.hide and "botão do minimapa escondido." or "botão do minimapa à mostra.")
end

-- `/rmt faccao [minha|horda|alianca]`, sem argumento limpa.
-- Liga e desliga as que saíram do jogo. Existe porque o catálogo do MCL as conhece, e quem
-- coleciona costuma querer VER o que perdeu — só não no meio da lista de "por onde começar".
commands["expansao"] = function(rest)
    local arg = (ns.Fold and ns.Fold(rest or "") or (rest or ""):lower()):gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "" then
        ns.db.expansionFilter = nil
        ns.Print("expansão: todas.")
        ns.Invalidate()
        return
    end
    for _, r in ipairs(ns.Expansion.RANGES) do
        if ns.Fold(r.name):find(arg, 1, true) then
            ns.db.expansionFilter = r.id
            ns.Print("expansão: " .. r.name)
            ns.Invalidate()
            return
        end
    end
    ns.Print("expansão não reconhecida. As que existem:")
    for _, r in ipairs(ns.Expansion.Menu()) do print("    " .. r.name) end
end

commands["busca"] = function(rest)
    ns.search = (rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if ns.search == "" then
        ns.Print("busca limpa.")
    else
        ns.Print('buscando por "' .. ns.search .. '".')
    end
    ns.Invalidate()
end

commands["sumidas"] = function()
    ns.db.showUnobtainable = not ns.db.showUnobtainable
    ns.Print(ns.db.showUnobtainable
        and "mostrando também as que saíram do jogo."
        or "escondendo as que saíram do jogo.")
    ns.Invalidate()
end

commands["faccao"] = function(rest)
    local arg = (rest or ""):lower():gsub("%s", "")
    local mapa = {
        minha = "mine", mine = "mine",
        horda = "Horde", horde = "Horde",
        alianca = "Alliance", ["aliança"] = "Alliance", alliance = "Alliance",
    }
    ns.db.factionFilter = mapa[arg]
    local nomes = { mine = "só o que este personagem pode",
                    Horde = "só da Horda", Alliance = "só da Aliança" }
    ns.Print("facção: " .. (nomes[ns.db.factionFilter] or "todas"))
    ns.RefreshWindow()
end

commands["quem"] = function(rest)
    -- (!) O LIVRO-CAIXA EM UMA LINHA. Sem isto, a única forma de saber se ele tem algo dentro
    -- é abrir a ficha de uma montaria específica — e um livro-caixa vazio (um personagem só)
    -- não consegue responder "qual dos meus tem", e precisa dizer isso.
    local n = ns.Roster and ns.Roster.Count() or 0
    ns.Print(n .. " personagem(ns) anotado(s). O livro-caixa se escreve quando cada um entra no "
        .. "jogo — entre com os alts uma vez para eles aparecerem aqui.")
    if not (ns.db and ns.db.chars) then return end
    for _, c in pairs(ns.db.chars) do
        local quantas = 0
        for _ in pairs(c.reps or {}) do quantas = quantas + 1 end
        print(string.format("    %s%s  —  %d reputações anotadas",
            c.name or "?", c.faction and (" (" .. c.faction .. ")") or "", quantas))
    end
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
    print("    |cffffff00/rmt faccao [minha|horda|alianca]|r — filtra por facção")
    print("    |cffffff00/rmt sumidas|r — mostra ou esconde as que saíram do jogo")
    print("    |cffffff00/rmt busca <texto>|r — procura por nome, chefe, zona ou vendedor")
    print("    |cffffff00/rmt expansao [nome]|r — filtra por expansão")
    print("    |cffffff00/rmt quem|r — os personagens anotados e quantas reputações cada um tem")
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
