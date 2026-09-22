-- RocketMounts | Score.lua
-- The order. It is the one thing this addon does that the others do not.
--
-- The criterion is stated, not a magic number: every mount lands in a band by a RULE,
-- and the row shows the number that put it there. If the order looks wrong, you can
-- disagree with the criterion by looking at the list itself.
--
-- (!) The distinction that holds everything up, and that the first version did not make:
--
--    REQUIREMENT != ACQUISITION.
--
-- Reputation, currency and achievements are **requirements**: they say whether you may
-- *try*. What delivers the mount is something else -- buying from a vendor delivers,
-- killing a boss with a 1-in-100 chance does not. The previous version merged the two and
-- called it all progress, so the Blackwater Bonecrusher showed up first with "100%"
-- because the reputation was met -- except it drops from a cache, at 1 in 3. A hundred
-- percent of the requirement, zero percent of the mount.
--
-- Hence the hard rule: **only a deterministic acquisition can be "ready to grab".** With a
-- drop chance in the way, the requirement at most unlocks the farm; it never completes it.
--
-- What this model still does NOT consider, and it is the largest known gap: attempt
-- lockouts. A 1/100 drop from a boss on a weekly lockout and a 1/100 drop from a mob with
-- no lockout at all are years apart, and today both land in the same band. The per-mount
-- lockout period is missing -- the API does not expose it and no installed catalogue keeps
-- it. Until it exists, the row shows the method and the player judges.
local _, ns = ...

-- (!) A ORDEM DAS FAIXAS É A PROMESSA DO ADDON, e ela estava errada: "requisito desconhecido"
-- ficava em SEGUNDO, logo abaixo de "é só ir pegar". Posição é recomendação — pôr "eu não sei"
-- perto do topo faz a lista recomendar justamente o que ela não consegue avaliar. Agora ela cai
-- para o fim, ao lado de "sem estimativa", que é onde a falta de informação pertence.
ns.TIER = {
    READY     = 1,
    CLOSE     = 2,
    UNDERWAY  = 3,
    SHORTFARM = 4,
    LONGFARM  = 5,
    CHECK     = 6,
    UNKNOWN   = 7,
}

-- The names carry the split the collector community actually uses -- **guaranteed** against
-- **luck** ("guaranteed" vs "RNG" in the English guides; "obtenção fácil" against "sorte"
-- and "camperar" in the Brazilian ones). It is the same boundary the engine computes in
-- `Deterministic`, so the label now says in words what the rule already did in code. Band 6
-- carries neither name because it mixes both kinds.
--
-- (!) These strings are player-facing and are still hardcoded in Brazilian Portuguese. This
-- addon has no `Locales/` yet, and it needs one -- with English as the key language -- before
-- it can go on the release pipeline.
ns.TIER_NAME = {
    [1] = "Garantidas — é só ir pegar",
    [2] = "Garantidas — quase liberadas",
    [3] = "Garantidas — a meio caminho",
    [4] = "Na sorte — chance boa",
    [5] = "Caminho longo",
    [6] = "Exige mais que o preço",
    [7] = "Sem estimativa",
}

-- The hint is short because it shares a line with the band name, which grew. Practical
-- ceiling: ~36 characters. Past that it crosses the list border (see the width check in
-- the harness, which counts LETTERS, not bytes).
-- A dica fala do que a MONTARIA exige, e não do que o addon sabe. A dica da faixa 6 chegou a
-- ser *"sei o preço; o resto não sei"* e foi reprovada na hora: o jogador não quer saber o que
-- o addon sabe, quer saber o que falta para ele pegar a montaria.
ns.TIER_HINT = {
    [1] = "requisito cumprido e conferido",
    [2] = "falta pouco do requisito",
    [3] = "caminho já andado",
    [4] = "1 em 100 ou melhor",
    [5] = "chance ruim, ou requisito longe",
    [6] = "conquista, reputação ou guilda",
    [7] = "sem dado para estimar",
}

-- The chance above which a farm stops being an afternoon's work. Not a measurement: it is
-- the cut the game itself settled on (a "1% drop" is the tier where people talk of farming).
local SHORT_FARM_CHANCE = 100

-- Sources where the mount arrives by luck rather than by meeting a requirement. A drop is
-- obvious; a discovery is finding it by accident. In those two, a met requirement never
-- means ready.
local LUCK_SOURCE = {
    [1] = true,    -- Drop
    [11] = true,   -- Discovery
}

-- The acquisition is deterministic when nothing in it depends on luck: buying from the
-- vendor, handing in the quest, closing the achievement. A drop chance on the record is
-- proof of the opposite.
local function Deterministic(e)
    if e.chance and e.chance > 0 then return false end
    if LUCK_SOURCE[e.sourceType] then return false end
    return true
end

-- (!) ACCESS IS NOT PRICE, and confusing the two was the defect reported on 21/09.
--
-- The Blackwater Bonecrusher opened the list as "just go get it". The catalogue knows exactly
-- one thing about it: it costs 3,000 gold. The player has the gold -> requirement met ->
-- ready. Except it requires **Exalted with your guild plus the "Guild Glory of the Cataclysm
-- Raider" achievement**, and there is not one line about either in the data this addon reads.
--
-- The lesson is not about that mount: it is that **the absence of a known requirement was
-- being read as the absence of a requirement**. And gold is almost never what blocks anyone
-- -- what blocks is reputation, achievements, guild, rating. Knowing only the price is
-- knowing almost nothing.
--
-- So requirements became two families:
--
--   ACCESS  reputation, renown, achievement -- decides whether you CAN
--   PRICE   gold, currency, item            -- decides whether you PAY
--
-- "Just go get it" demands a known AND met access requirement. Knowing only the price sends
-- the mount to "check with the vendor", which promises exactly what can be proven.
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
    local access, from = Access(e)
    local price = Price(e)

    -- The requirement the row shows is the further behind of the two: whoever has the
    -- reputation but not the gold is stuck on the gold, and the other way round.
    local req = access
    if price and (not req or price < req) then
        req, from = price, "cost"
    end

    e.access = access
    e.price = price
    e.requirement = req
    e.requirementFrom = from
    e.deterministic = Deterministic(e)
    e.gated = (req ~= nil and req < 1)

    if e.deterministic then
        if access == nil then
            -- NO KNOWN ACCESS. We cannot say "just go get it": what we know is the price,
            -- and price is almost never what blocks.
            if price == nil then
                e.tier = ns.TIER.UNKNOWN
            elseif price >= 1 then
                e.tier = ns.TIER.CHECK
            elseif price >= 0.75 then
                e.tier = ns.TIER.CLOSE
            elseif price > 0 then
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
        -- Depends on luck AND is not even unlocked yet: the worst of both worlds.
        e.tier = ns.TIER.LONGFARM
    elseif e.chance and e.chance > 0 then
        e.tier = (e.chance <= SHORT_FARM_CHANCE) and ns.TIER.SHORTFARM or ns.TIER.LONGFARM
    else
        e.tier = ns.TIER.UNKNOWN
    end

    -- The number on the right. The rule: **a percentage only where the percentage is the
    -- whole story**. Where luck decides, the number is the chance, never the requirement --
    -- it was that mix that made a 1-in-3 cache announce itself as 100%.
    if e.deterministic then
        if e.tier == ns.TIER.READY then
            e.headline = "pode pegar"
        elseif e.tier == ns.TIER.CHECK then
            -- (!) O NÚMERO É O PREÇO, e não um veredito. "preço ok" foi reprovado na hora —
            -- ele parecia um "pode ir" com outro nome, que é exatamente o que esta faixa
            -- existe para NÃO dizer. Preço é informação: quem lê decide.
            e.headline = (e.cost and e.cost.price) or "—"
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

    -- The sentence that explains the position.
    local reqLabel = from and e[from] and e[from].label or nil

    if e.gated and not e.deterministic then
        -- First what blocks, then the luck: that is the order in which the player acts.
        e.why = "Falta liberar — " .. (reqLabel or "requisito não cumprido")
        if e.chance then
            e.why = e.why .. "  ·  depois, chance de 1 em " .. e.chance
        end
    elseif e.tier == ns.TIER.CHECK then
        -- A FRASE COMEÇA PELO QUE O JOGO DIZ, e não pela minha ressalva. O `sourceText` da
        -- Blizzard costuma nomear o vendedor e a condição ("Guild Vendor", "Requires ..."), e
        -- isso vale mais que qualquer frase minha. A ressalva vem depois, curta.
        -- `%s+` colapsa qualquer espaco em branco, inclusive a quebra de linha que a Blizzard
        -- poe no meio do texto -- e faz isso sem escape nenhum no padrao.
        local doJogo = e.sourceText and e.sourceText ~= ""
            and (e.sourceText:gsub("%s+", " ")) or nil
        e.why = doJogo or ns.SOURCE_NAMES[e.sourceType]
        if e.vendorGuilda then
            e.why = e.why .. "  ·  vendedor de guilda: exige reputação e conquista DA GUILDA, "
                .. "que eu não leio"
        else
            e.why = e.why .. "  ·  pode haver requisito que eu não leio"
        end
        if e.cost and e.cost.gap then
            e.why = e.why .. "  ·  faltam " .. e.cost.gap
        end
    elseif e.deterministic and reqLabel then
        e.why = reqLabel
    elseif e.chance then
        e.why = string.format("Chance de 1 em %d", e.chance)
        if reqLabel then e.why = e.why .. "  ·  " .. reqLabel end
        if e.bossName then e.why = e.why .. "  ·  " .. e.bossName end
    elseif e.sourceText and e.sourceText ~= "" then
        -- Blizzard's text comes with line breaks; a list row wants a single line.
        e.why = (e.sourceText:gsub("[\r\n]+", "  ·  "))
    else
        e.why = ns.SOURCE_NAMES[e.sourceType]
    end

    return e
end

-- Order within a band: more requirement walked first, then the more generous chance, and
-- finally how many players already own it -- more common tends to be easier in practice.
--
-- There used to be a line here putting deterministic acquisitions first. It was removed for
-- two reasons: no test could make it fail (in bands 1 to 5 the items are all of the same
-- kind, so it never decided anything), and in the one place where it would decide -- the
-- "long road", which mixes both -- it would decide wrongly: grinding reputation from zero to
-- buy something is a worse bet than a 1-in-3 drop already 80% unlocked.
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

-- The ranked list, after the source filter.
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
