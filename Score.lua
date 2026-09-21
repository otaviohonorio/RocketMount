-- RocketMounts | Score.lua
-- A ordem. É a única coisa que este addon faz e que os outros não fazem.
--
-- O critério é declarado, não é um número mágico: cada montaria cai numa faixa por
-- uma REGRA, e a linha mostra o número que a pôs ali. Se a ordem parecer errada, dá
-- para discordar do critério olhando a própria lista.
--
-- ⚑ A distinção que sustenta tudo, e que a primeira versão não fazia:
--
--    REQUISITO ≠ AQUISIÇÃO.
--
-- Reputação, moeda e conquista são **requisitos**: eles dizem se você pode *tentar*.
-- O que entrega a montaria é outra coisa — comprar do vendedor entrega, matar um chefe
-- com 1 em 100 de chance não entrega. A versão anterior somava os dois e chamava tudo
-- de progresso, e o Esmaga-ossos Aguanegra aparecia em primeiro com "100%" porque a
-- reputação estava cumprida — só que ele cai de baú, a 1 em 3. Cem por cento do
-- requisito, zero por cento da montaria.
--
-- Daí a regra dura: **só é "Pronto para pegar" o que a aquisição é determinística.**
-- Tendo taxa de queda no meio, o requisito no máximo libera o farm; nunca o conclui.
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

-- Os nomes carregam a divisão que a comunidade de colecionadores realmente usa —
-- **garantida** contra **na sorte** ("guaranteed" contra "RNG", nos guias em inglês;
-- "obtenção fácil" contra "sorte" e "camperar", nos guias brasileiros). É a mesma fronteira
-- que o motor calcula em `Deterministic`, então o rótulo passou a dizer em palavra o que a
-- regra já fazia em código. A faixa 5 não leva nenhum dos dois nomes: ela mistura os tipos.
ns.TIER_NAME = {
    [1] = "Garantidas — é só ir pegar",
    [2] = "Garantidas — quase liberadas",
    [3] = "Garantidas — a meio caminho",
    [4] = "Na sorte — chance boa",
    [5] = "Caminho longo",
    [6] = "Sem estimativa",
}

-- A dica é curta porque divide a linha com o nome da faixa, que cresceu. Teto prático:
-- ~36 caracteres. Acima disso ela atravessa a borda da lista (ver TIER_HINT_WIDTH).
ns.TIER_HINT = {
    [1] = "nada aqui depende de sorte",
    [2] = "falta pouco do requisito",
    [3] = "caminho já andado neste personagem",
    [4] = "1 em 100 ou melhor",
    [5] = "chance ruim, ou requisito no começo",
    [6] = "não há como medir esta",
}

-- Chance a partir da qual o farm deixa de ser de uma tarde. Não é medição, é o corte
-- que o jogo consagrou (as quedas "de 1%" são o patamar em que se fala em farmar).
local SHORT_FARM_CHANCE = 100

-- Fonte em que a montaria vem por sorte, e não por cumprir requisito. Saque é óbvio;
-- descoberta é achar por acaso. Nessas duas, requisito cumprido nunca significa pronto.
local LUCK_SOURCE = {
    [1] = true,    -- Saque
    [11] = true,   -- Descoberta
}

-- A aquisição é determinística quando nada nela depende de sorte: comprar do vendedor,
-- entregar a missão, fechar a conquista. Taxa de queda no registro é prova do contrário.
local function Deterministic(e)
    if e.chance and e.chance > 0 then return false end
    if LUCK_SOURCE[e.sourceType] then return false end
    return true
end

-- O requisito que está MAIS ATRASADO, e não o mais adiantado. Quem precisa de reputação
-- e de 10.000 de moeda não está pronto por ter a reputação — está preso na moeda. A
-- primeira versão usava o máximo e por isso mostrava sempre o número mais bonito.
local function Requirement(e)
    local worst, from = nil, nil
    for _, key in ipairs({ "rep", "cost", "achievement" }) do
        local p = e[key]
        if p and p.pct then
            if not worst or p.pct < worst then
                worst, from = p.pct, key
            end
        end
    end
    return worst, from
end

function ns.Rank(entry)
    local e = entry
    local req, from = Requirement(e)
    e.requirement = req
    e.requirementFrom = from
    e.deterministic = Deterministic(e)
    e.gated = (req ~= nil and req < 1)

    if e.deterministic then
        if req == nil then
            -- Sem taxa de queda e sem requisito mensurável: não há o que afirmar.
            e.tier = ns.TIER.UNKNOWN
        elseif req >= 1 then
            e.tier = ns.TIER.READY
        elseif req >= 0.75 then
            e.tier = ns.TIER.CLOSE
        elseif req > 0 then
            e.tier = ns.TIER.UNDERWAY
        else
            e.tier = ns.TIER.LONGFARM
        end
    elseif e.gated then
        -- Depende de sorte E ainda nem está liberado: é o pior dos dois mundos.
        e.tier = ns.TIER.LONGFARM
    elseif e.chance and e.chance > 0 then
        e.tier = (e.chance <= SHORT_FARM_CHANCE) and ns.TIER.SHORTFARM or ns.TIER.LONGFARM
    else
        e.tier = ns.TIER.UNKNOWN
    end

    -- O número da direita. A regra nova: **porcentagem só onde a porcentagem é a
    -- história inteira**. Onde a sorte decide, o número é a chance, nunca o requisito —
    -- foi essa mistura que fez um baú de 1 em 3 se anunciar como 100%.
    if e.deterministic then
        if e.tier == ns.TIER.READY then
            e.headline = "pode pegar"
        elseif req then
            e.headline = string.format("%d%%", math.floor(req * 100 + 0.5))
        else
            e.headline = "—"
        end
    elseif e.chance and e.chance > 0 then
        e.headline = "1/" .. e.chance
    elseif e.ownedByPct then
        e.headline = string.format("%.0f%% têm", e.ownedByPct)
    else
        e.headline = "—"
    end

    -- A frase que explica a posição.
    local reqLabel = from and e[from] and e[from].label or nil

    if e.gated and not e.deterministic then
        -- Primeiro o que trava, depois a sorte: é nessa ordem que o jogador age.
        e.why = "Falta liberar — " .. (reqLabel or "requisito não cumprido")
        if e.chance then
            e.why = e.why .. "  ·  depois, chance de 1 em " .. e.chance
        end
    elseif e.deterministic and reqLabel then
        e.why = reqLabel
    elseif e.chance then
        e.why = string.format("Chance de 1 em %d", e.chance)
        if reqLabel then e.why = e.why .. "  ·  " .. reqLabel end
        if e.bossName then e.why = e.why .. "  ·  " .. e.bossName end
    elseif e.sourceText and e.sourceText ~= "" then
        -- O texto da Blizzard vem com quebra de linha; a linha da lista quer uma só.
        e.why = (e.sourceText:gsub("[\r\n]+", "  ·  "))
    else
        e.why = ns.SOURCE_NAMES[e.sourceType]
    end

    return e
end

-- Ordem dentro da faixa: quem tem mais requisito andado, depois a chance mais generosa,
-- e por fim quantos jogadores já têm — mais comum costuma ser mais fácil na prática.
--
-- Havia aqui uma linha pôndo a aquisição determinística na frente. Saiu por dois motivos:
-- nenhum teste conseguia reprová-la (nas faixas 1 a 4 os itens são todos do mesmo tipo,
-- então ela nunca decidia nada), e no único lugar onde ela decidiria — o "Caminho longo",
-- que mistura os dois — ela decidiria errado: reputação do zero para comprar é aposta pior
-- que uma queda de 1 em 3 já 80% liberada.
local function Compare(a, b)
    if a.tier ~= b.tier then return a.tier < b.tier end

    local ra, rb = a.requirement or -1, b.requirement or -1
    if ra ~= rb then return ra > rb end

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
