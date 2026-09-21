-- RocketMounts | Score.lua
-- A ordem. É a única coisa que este addon faz e que os outros não fazem.
--
-- O critério é declarado, não é um número mágico: cada montaria cai numa faixa por
-- uma REGRA, e a linha mostra o número que a pôs ali. Se a ordem parecer errada, dá
-- para discordar do critério olhando a própria lista.
--
-- O que este modelo AINDA NÃO considera, e é a maior lacuna conhecida: a trava de
-- tentativa. Uma queda de 1/100 num chefe com trava semanal e uma de 1/100 num bicho
-- sem trava nenhuma são separadas por anos, e hoje as duas caem na mesma faixa. Falta
-- o dado do período de trava por montaria — a API não dá e nenhum catálogo instalado
-- guarda. Até ter, a linha mostra o método, para o jogador julgar.
local _, ns = ...

ns.TIER = {
    READY     = 1,
    CLOSE     = 2,
    UNDERWAY  = 3,
    SHORTFARM = 4,
    LONGFARM  = 5,
    UNKNOWN   = 6,
}

ns.TIER_NAME = {
    [1] = "Pronto para pegar",
    [2] = "Quase lá",
    [3] = "Já comecei",
    [4] = "Farm curto",
    [5] = "Farm longo",
    [6] = "Sem estimativa",
}

ns.TIER_HINT = {
    [1] = "você já cumpre o requisito — falta ir buscar",
    [2] = "três quartos do caminho andados",
    [3] = "tem progresso guardado neste personagem",
    [4] = "queda de 1 em 100 ou melhor",
    [5] = "queda pior que 1 em 100",
    [6] = "nenhum catálogo instalado sabe a taxa desta",
}

-- Queda a partir da qual o farm deixa de ser de uma tarde. Não é medição, é o corte
-- que o jogo consagrou (as quedas "de 1%" são o patamar em que se fala em farmar).
local SHORT_FARM_CHANCE = 100

-- O melhor progresso já feito neste personagem, entre reputação, custo e conquista,
-- e de onde ele veio. É o que dá valor à lista: o que está quase pronto sobe.
local function BestProgress(e)
    local best, from = nil, nil
    for _, key in ipairs({ "rep", "cost", "achievement" }) do
        local p = e[key]
        if p and p.pct then
            if not best or p.pct > best then
                best, from = p.pct, key
            end
        end
    end
    return best, from
end

function ns.Rank(entry)
    local e = entry
    local progress, from = BestProgress(e)
    e.progress = progress
    e.progressFrom = from

    if progress and progress >= 1 then
        e.tier = ns.TIER.READY
    elseif progress and progress >= 0.75 then
        e.tier = ns.TIER.CLOSE
    elseif progress and progress >= 0.25 then
        e.tier = ns.TIER.UNDERWAY
    elseif e.chance and e.chance > 0 and e.chance <= SHORT_FARM_CHANCE then
        e.tier = ns.TIER.SHORTFARM
    elseif e.chance and e.chance > 0 then
        e.tier = ns.TIER.LONGFARM
    elseif progress and progress > 0 then
        e.tier = ns.TIER.UNDERWAY
    else
        e.tier = ns.TIER.UNKNOWN
    end

    -- O número que justificou a faixa, curto, para a direita da linha.
    if from == "rep" then
        e.headline = string.format("%d%%", math.floor((progress or 0) * 100 + 0.5))
    elseif from == "cost" then
        e.headline = string.format("%d%%", math.floor((progress or 0) * 100 + 0.5))
    elseif from == "achievement" then
        e.headline = string.format("%d%%", math.floor((progress or 0) * 100 + 0.5))
    elseif e.chance then
        e.headline = "1/" .. e.chance
    elseif e.ownedByPct then
        e.headline = string.format("%.0f%% têm", e.ownedByPct)
    else
        e.headline = "—"
    end

    -- A frase que explica a posição, para a segunda linha.
    local why = e[from or ""] and e[from or ""].label or nil
    if not why then
        if e.chance then
            why = string.format("Queda de 1 em %d", e.chance)
            if e.bossName then why = why .. " · " .. e.bossName end
        elseif e.sourceText and e.sourceText ~= "" then
            -- O texto da Blizzard vem com quebra de linha; a linha da lista quer uma só.
            why = (e.sourceText:gsub("[\r\n]+", " · "))
        else
            why = ns.SOURCE_NAMES[e.sourceType]
        end
    end
    e.why = why

    return e
end

-- Chave de ordenação dentro da faixa: quem está mais perto primeiro; empate resolve
-- pela queda, e depois por quantos jogadores já têm (mais comum = mais fácil na prática).
local function Compare(a, b)
    if a.tier ~= b.tier then return a.tier < b.tier end

    local pa, pb = a.progress or -1, b.progress or -1
    if pa ~= pb then return pa > pb end

    local ca, cb = a.chance or math.huge, b.chance or math.huge
    if ca ~= cb then return ca < cb end

    local oa, ob = a.ownedByPct or -1, b.ownedByPct or -1
    if oa ~= ob then return oa > ob end

    return (a.name or "") < (b.name or "")
end

local cache

function ns.GetRanked(force)
    if cache and not force and not ns.IsDirty() then return cache end

    local list = ns.BuildList()
    for i = 1, #list do
        ns.Rank(list[i])
    end
    table.sort(list, Compare)

    cache = list
    ns.MarkClean()
    return cache
end

-- A lista já ranqueada, depois do filtro de fonte.
function ns.GetFiltered()
    local all = ns.GetRanked()
    local want = ns.db.sources
    if not want then return all, #all end

    local out = {}
    for i = 1, #all do
        if want[all[i].sourceType] then
            out[#out + 1] = all[i]
        end
    end
    return out, #all
end
