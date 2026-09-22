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
    CHECK     = 2,
    CLOSE     = 3,
    UNDERWAY  = 4,
    SHORTFARM = 5,
    LONGFARM  = 6,
    UNKNOWN   = 7,
}

-- Os nomes carregam a divisão que a comunidade de colecionadores realmente usa —
-- **garantida** contra **na sorte** ("guaranteed" contra "RNG", nos guias em inglês;
-- "obtenção fácil" contra "sorte" e "camperar", nos guias brasileiros). É a mesma fronteira
-- que o motor calcula em `Deterministic`, então o rótulo passou a dizer em palavra o que a
-- regra já fazia em código. A faixa 5 não leva nenhum dos dois nomes: ela mistura os tipos.
ns.TIER_NAME = {
    [1] = "Garantidas — é só ir pegar",
    [2] = "Confira no vendedor",
    [3] = "Garantidas — quase liberadas",
    [4] = "Garantidas — a meio caminho",
    [5] = "Na sorte — chance boa",
    [6] = "Caminho longo",
    [7] = "Sem estimativa",
}

-- A dica é curta porque divide a linha com o nome da faixa, que cresceu. Teto prático:
-- ~36 caracteres. Acima disso ela atravessa a borda da lista (ver TIER_HINT_WIDTH).
ns.TIER_HINT = {
    [1] = "requisito cumprido e conferido",
    [2] = "o preço você tem; pode haver mais",
    [3] = "falta pouco do requisito",
    [4] = "caminho já andado",
    [5] = "1 em 100 ou melhor",
    [6] = "chance ruim, ou requisito no começo",
    [7] = "não há como medir esta",
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

-- ⛑ ACESSO NÃO É PREÇO, e confundir os dois foi o defeito relatado em 21/09.
--
-- A Fênix Negra apareceu como "é só ir pegar". O catálogo sabe uma coisa só sobre ela: custa
-- 3.000 de ouro. O jogador tem o ouro → requisito cumprido → pronto. Só que ela exige **guilda
-- Exaltada mais a conquista "Guild Glory of the Cataclysm Raider"**, e disso não há uma linha
-- em lugar nenhum do dado que este addon lê.
--
-- A lição não é sobre essa montaria: é que **a ausência de requisito conhecido estava sendo
-- lida como ausência de requisito**. E ouro quase nunca é o que trava alguém — o que trava é
-- reputação, conquista, guilda, classificação. Saber só o preço é saber quase nada.
--
-- Então os requisitos viraram duas famílias:
--
--   ACESSO  reputação, renome, conquista — o que decide se você PODE
--   PREÇO   ouro, moeda, item            — o que decide se você PAGA
--
-- "É só ir pegar" exige um acesso conhecido E cumprido. Sabendo só o preço, a montaria vai
-- para "Confira no vendedor", que promete exatamente o que dá para provar.
local ACCESS_KEYS = { "rep", "achievement" }

local function Access(e)
    local worst, from = nil, nil
    for _, key in ipairs(ACCESS_KEYS) do
        local p = e[key]
        if p and p.pct then
            if not worst or p.pct < worst then
                worst, from = p.pct, key
            end
        end
    end
    return worst, from
end

local function Price(e)
    local p = e.cost
    if p and p.pct then return p.pct end
    return nil
end

function ns.Rank(entry)
    local e = entry
    local acesso, from = Access(e)
    local preco = Price(e)

    -- O requisito que a linha mostra é o mais atrasado dos dois: quem tem a reputação mas não
    -- o ouro está preso no ouro, e vice-versa.
    local req = acesso
    if preco and (not req or preco < req) then
        req, from = preco, "cost"
    end

    e.access = acesso
    e.price = preco
    e.requirement = req
    e.requirementFrom = from
    e.deterministic = Deterministic(e)
    e.gated = (req ~= nil and req < 1)

    if e.deterministic then
        if acesso == nil then
            -- SEM ACESSO CONHECIDO. Não dá para dizer "é só ir pegar": o que se sabe é o preço,
            -- e preço quase nunca é o que trava.
            if preco == nil then
                e.tier = ns.TIER.UNKNOWN
            elseif preco >= 1 then
                e.tier = ns.TIER.CHECK
            elseif preco >= 0.75 then
                e.tier = ns.TIER.CLOSE
            elseif preco > 0 then
                e.tier = ns.TIER.UNDERWAY
            else
                e.tier = ns.TIER.LONGFARM
            end
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
        elseif e.tier == ns.TIER.CHECK then
            -- NÃO é "pode pegar" e não é porcentagem: o que se afirma é só que o preço cabe.
            e.headline = "preço ok"
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
    elseif e.tier == ns.TIER.CHECK then
        -- A frase precisa dizer as DUAS coisas: o que dá para garantir e o que não dá.
        e.why = (reqLabel and (reqLabel .. "  ·  ") or "")
            .. "pode haver requisito que eu não leio"
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
