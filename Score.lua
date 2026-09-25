-- RocketMount | Score.lua
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
local L = ns.L

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
    -- Depois de tudo, e só quando o jogador pede para ver: não é difícil, é impossível.
    GONE      = 8,
}

-- The names carry the split the collector community actually uses -- **guaranteed** against
-- **luck** ("guaranteed" vs "RNG" in the English guides; "obtenção fácil" against "sorte"
-- and "camperar" in the Brazilian ones). It is the same boundary the engine computes in
-- `Deterministic`, so the label now says in words what the rule already did in code. Band 6
-- carries neither name because it mixes both kinds.
--
--
-- (!) THE KEY IS THE ENGLISH TEXT, and the band name is where that matters most: it is the
-- longest label the list draws, and a translation that outgrows `TIER_TITLE_WIDTH` crosses the
-- list border. The harness counts LETTERS, not bytes, because of the accents.
-- (!) WHERE EACH BAND SITS IN THE LIST, apart from its number. The number is the band's identity
-- (colour, name, hint are indexed by it); this is the ORDER, and the two had to come apart.
--
-- The user, 23/09, at a vendor with the gold for a mount the list put at the very end: *"a ideia é
-- uma ordem do mais fácil para o mais difícil (...) esse aí é só ter o gold e ir no NPC agora"*.
-- "Check with the vendor" -- price met, no access requirement known, ordinary vendor -- had been
-- sent BELOW every luck band after the Black Phoenix. That overcorrected: the Phoenix is a GUILD
-- vendor, and guild vendors already go to the long road on their own rule. What is left in this
-- band is gold in hand and a walk to an NPC, which is the second easiest thing there is. The
-- README always listed it second; the code had drifted from it.
ns.TIER_RANK = {
    [ns.TIER.READY]     = 1,
    [ns.TIER.CLOSE]     = 2,
    [ns.TIER.UNDERWAY]  = 3,
    [ns.TIER.SHORTFARM] = 4,
    [ns.TIER.LONGFARM]  = 5,
    -- (!) AND BACK AT THE BOTTOM, THE SAME DAY. Moving it second put every mount the addon
    -- could not check -- Dark Phoenix, covenant and Brawler's Guild mounts -- among the easy ones,
    -- and the user: *"se não tem [certeza], vai pra sessão de que não sabe"*. The rule that came
    -- out of it: the top is only what is CERTAIN. A purchase is certain when the vendor said so
    -- (Sources.lua, vendorCheck); everything else waits here, next to "no estimate".
    [ns.TIER.CHECK]     = 6,
    [ns.TIER.UNKNOWN]   = 7,
    [ns.TIER.GONE]      = 8,
}

ns.TIER_NAME = {
    [1] = L["Guaranteed — just go get it"],
    [2] = L["Guaranteed — nearly unlocked"],
    [3] = L["Guaranteed — halfway there"],
    [4] = L["Down to luck — good odds"],
    [5] = L["Long road"],
    [6] = L["Not confirmed"],
    [7] = L["No estimate"],
    [8] = L["Cannot be obtained any more"],
}

-- The hint is short because it shares a line with the band name, which grew. Practical
-- ceiling: ~36 characters. Past that it crosses the list border (see the width check in
-- the harness, which counts LETTERS, not bytes).
-- A dica fala do que a MONTARIA exige, e não do que o addon sabe. A dica da faixa 6 chegou a
-- ser *"sei o preço; o resto não sei"* e foi reprovada na hora: o jogador não quer saber o que
-- o addon sabe, quer saber o que falta para ele pegar a montaria.
---A 1-in-n chance as a percentage, the ONE formatter for the window, the card, the alert and chat.
---
---The user (23/09): *"esse 1/200 por exemplo, poderia ser tudo convertido em percentual, tanto
---na janela, quanto nos avisos"*. Two significant figures below 1% (1/200 is 0.5%, 1/910 is
---0.11%, 1/2000 is 0.05%), one decimal from 1% to 10% (1/60 is 1.7%), whole numbers above.
---Trailing zeros go (1/100 is "1%", not "1.0%"). `rough` puts "~" in front: a Wowhead sample
---with fewer than ten drops.
---
---The decimal point comes from the translation (`L["."]`): "0,5%" in Portuguese is the correct
---form, and Blizzard's own `FormattingUtil.lua` only localises the THOUSANDS separator.
function ns.FormatChance(n, rough)
    if type(n) ~= "number" or n <= 0 then return nil end
    local pct = 100 / n
    local casas
    if pct >= 10 then
        casas = 0
    elseif pct >= 1 then
        casas = 1
    else
        casas = -math.floor(math.log10(pct)) + 1
    end
    local txt = string.format("%." .. casas .. "f", pct)
    if casas > 0 then txt = txt:gsub("0+$", ""):gsub("%.$", "") end
    txt = txt:gsub("%.", L["."]) .. "%"
    return rough and ("~" .. txt) or txt
end

ns.TIER_HINT = {
    [1] = L["requirement met and checked"],
    [2] = L["a little left on the requirement"],
    [3] = L["road already walked"],
    [4] = L["1% or better"],
    [5] = L["bad odds, or a distant requirement"],
    [6] = L["open the vendor to confirm"],
    [7] = L["no data to estimate from"],
    [8] = L["left the game"],
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
-- (!) "SPECIAL" É O CATÁLOGO DIZENDO QUE NÃO SABE. São 126 montarias marcadas assim — evento,
-- promoção, recompensa esquisita — e para todas elas o registro traz **só** o método e o item.
-- Tratar isso como aquisição determinística é concluir "é só comprar" a partir de um campo que
-- literalmente diz "é um caso à parte".
local UNKNOWN_METHOD = { SPECIAL = true, [""] = true }

local function Deterministic(e)
    if e.chance and e.chance > 0 then return false end
    if LUCK_SOURCE[e.sourceType] then return false end
    if e.method and UNKNOWN_METHOD[e.method] then return false end
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
-- `tooltipGate` entra como acesso: ele é o jogo dizendo "você não pode comprar isto ainda", e
-- isso é exatamente um requisito de acesso. Vem por último na lista porque é o mais genérico —
-- quando reputação e conquista já explicam, a frase do tooltip costuma repetir o que elas dizem.
-- `vendorCheck` is the vendor's own verdict (Sources.lua): the only source that can say "met"
-- on its own, because it is the game answering, not the catalogue being silent.
local ACCESS_KEYS = { "rep", "achievement", "achievementReward", "quest", "tooltipGate", "vendorCheck" }

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

    -- SAIU DO JOGO: nenhuma das regras abaixo se aplica. Ranquear esforço de uma montaria que
    -- ninguém mais consegue seria responder a pergunta errada com preciso.
    if e.unobtainable then
        e.tier = ns.TIER.GONE
        e.headline = "—"
        e.why = (e.sourceText and e.sourceText ~= "" and (e.sourceText:gsub("%s+", " ")))
            or ns.SOURCE_NAMES[e.sourceType]
        return e
    end
    local access, from = Access(e)
    local price = Price(e)

    -- The requirement the row shows is the further behind of the two: whoever has the
    -- reputation but not the gold is stuck on the gold, and the other way round.
    local req = access
    if price and (not req or price < req) then
        req, from = price, "cost"
    end

    -- (!) TODOS OS REQUISITOS, e não só o pior (defeito de 22/09).
    --
    -- Relato: *"falta cristal de ressonância mas que também falta reputação"*. A tela mostrava
    -- um dos dois — o mais atrasado — e calava sobre o outro. Quem lê "faltam 2.000 cristais"
    -- vai farmar cristal, chega no vendedor e descobre a reputação lá.
    --
    -- O `min` continua decidindo a FAIXA (o requisito mais atrasado é que diz o quanto falta),
    -- mas a lista inteira vai junto para a linha e para a ficha. Esconder metade do preço é pior
    -- que mostrar um número grande.
    e.requisitos = {}
    for _, key in ipairs({ "rep", "achievement", "achievementReward", "quest",
                          "tooltipGate", "vendorCheck", "cost" }) do
        local p = e[key]
        if p and p.pct then
            e.requisitos[#e.requisitos + 1] = {
                key = key, pct = p.pct, label = p.label, cumprido = p.pct >= 1,
            }
        end
    end
    table.sort(e.requisitos, function(x, y) return x.pct < y.pct end)

    -- Quantos ainda faltam, que é o que a linha precisa dizer em uma palavra.
    e.faltando = 0
    for _, r in ipairs(e.requisitos) do
        if not r.cumprido then e.faltando = e.faltando + 1 end
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
    end

    -- (!) CERTAINTY FOR A PURCHASE (23/09). "Just go get it" on a vendor mount is a promise the
    -- player acts on -- a trip to the NPC -- and the user: *"isso é frustrante chegar no NPC e não
    -- poder comprar"*. What the addon can read about a purchase is never the whole of it: MCL may
    -- not know the vendor's condition, and an item tooltip does not show an achievement the
    -- vendor asks for. The one source that is the whole of it is the vendor itself.
    -- So a vendor mount is "ready" ONLY with the vendor's verdict for this character; otherwise it
    -- waits in "not confirmed". A known requirement that is NOT met still pushes it down, as always.
    if e.isVendorMount and e.tier == ns.TIER.READY
        and not (e.vendorCheck and e.vendorCheck.pct >= 1) then
        e.tier = ns.TIER.CHECK
    end
    -- And no tooltip still loading can be read as clean.
    if e.tier == ns.TIER.READY and (e.tooltipState == "pending" or e.tooltipState == "failed") then
        e.tier = ns.TIER.CHECK
    end

    if e.deterministic then
        -- decided in the block above
    elseif e.gated then
        -- Depends on luck AND is not even unlocked yet: the worst of both worlds.
        e.tier = ns.TIER.LONGFARM
    elseif e.chance and e.chance > 0 then
        e.tier = (e.chance <= SHORT_FARM_CHANCE) and ns.TIER.SHORTFARM or ns.TIER.LONGFARM
    else
        -- Aqui cai o método "à parte" (`SPECIAL`) sem chance: não é determinístico, não tem
        -- requisito e não tem sorte medida — sobra "sem estimativa", que é a verdade.
        --
        -- Houve aqui um `elseif` só para esse caso. Ele saiu: nenhuma sabotagem conseguia
        -- derrubá-lo, porque este `else` já levava ao mesmo lugar. Regra que não muda nada é
        -- código que alguém vai ter que entender à toa depois.
        e.tier = ns.TIER.UNKNOWN
    end

    -- The number on the right. The rule: **a percentage only where the percentage is the
    -- whole story**. Where luck decides, the number is the chance, never the requirement --
    -- it was that mix that made a 1-in-3 cache announce itself as 100%.
    if e.deterministic then
        if e.tier == ns.TIER.READY then
            e.headline = L["ready to grab"]
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
        e.headline = ns.FormatChance(e.chance)
    elseif e.ownedByPct then
        e.headline = string.format(L["%.0f%% own it"], e.ownedByPct)
    else
        e.headline = "—"
    end

    -- The sentence that explains the position.
    local reqLabel = from and e[from] and e[from].label or nil

    if e.gated and not e.deterministic then
        -- First what blocks, then the luck: that is the order in which the player acts.
        e.why = string.format(L["Not unlocked yet — %s"], reqLabel or L["requirement not met"])
        if e.faltando > 1 then
            e.why = e.why .. string.format(L[" (and %d more)"], e.faltando - 1)
        end
        if e.chance then
            e.why = e.why .. string.format(L["  ·  then, a %s chance"], ns.FormatChance(e.chance))
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
            e.why = e.why .. L["  ·  guild vendor: asks for reputation and an achievement OF THE GUILD, which I cannot read"]
        else
            e.why = e.why .. L["  ·  there may be a requirement I cannot read"]
        end
        if e.cost and e.cost.gap then
            e.why = e.why .. string.format(L["  ·  %s missing"], e.cost.gap)
        end
    elseif e.deterministic and reqLabel then
        e.why = reqLabel
        -- E DIZ QUE HÁ MAIS, quando há. A linha não cabe os dois, mas cabe o aviso de que o
        -- outro existe — e a ficha lista todos.
        if e.faltando > 1 then
            e.why = e.why .. string.format(L["  ·  and %d more requirement(s)"], e.faltando - 1)
        end
    elseif e.chance then
        e.why = string.format(L["%s chance"], ns.FormatChance(e.chance))
        if reqLabel then e.why = e.why .. "  ·  " .. reqLabel end
        if e.bossName then
            e.why = e.why .. "  ·  " .. (ns.LocalizedCreature and ns.LocalizedCreature(e.bossName) or e.bossName)
        end
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
    if a.tier ~= b.tier then return ns.TIER_RANK[a.tier] < ns.TIER_RANK[b.tier] end

    -- (!) ONDE A SORTE DECIDE, A CHANCE MANDA — e não o requisito (defeito de 22/09).
    --
    -- Relato: *"Portador da Trilha-prado é 5%, tá acima de um que é 33%"*. Estava mesmo. Ele
    -- pede renome 5 com os Centauros Maruuk (o jogador tem 25, então cumprido) e depois cai a
    -- 1 em 20 do baú da Caçada Grandiosa. O outro cai a 1 em 3 e não tem requisito conhecido.
    --
    -- A regra antiga ordenava por requisito primeiro, e como "cumprido" (1) ganha de
    -- "desconhecido" (-1), a de 1 em 20 subia na frente da de 1 em 3. Mas **requisito cumprido
    -- não é progresso rumo à montaria** — ele só abre a porta. Entre duas que dependem de sorte,
    -- o que separa uma da outra é a chance, e nada mais.
    --
    -- O requisito continua mandando onde ele DECIDE alguma coisa: nas faixas determinísticas,
    -- onde ele é o próprio caminho, e na classificação de faixa (gated vai para o fim).
    -- In "not confirmed", what is known and met goes first: it is the best bet for the trip.
    if a.tier == ns.TIER.CHECK then
        local ka, kb = (a.access or 0) >= 1, (b.access or 0) >= 1
        if ka ~= kb then return ka end
    end

    local sorte = not a.deterministic and not b.deterministic
    if sorte then
        local ca, cb = a.chance or math.huge, b.chance or math.huge
        if ca ~= cb then return ca < cb end
    end

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
---Todos os termos da busca têm que aparecer, e não um deles.
---
---"fyrakk aberrus" acha o que está nos dois; com "um deles" bastaria, a busca ficaria mais larga
---quanto mais se escreve, que é o contrário do que digitar mais significa.
local function PassaBusca(e, termos)
    if not termos then return true end
    local alvo = e.busca or ""
    for i = 1, #termos do
        if not alvo:find(termos[i], 1, true) then return false end
    end
    return true
end

---A facção do personagem conectado passa por aqui uma vez só, e não a cada montaria.
local function MyFaction()
    return UnitFactionGroup and UnitFactionGroup("player") or nil
end

---A montaria passa no filtro de facção?
---
---Quatro modos, e o padrão (`nil`) mostra tudo. `"mine"` é o útil no dia a dia — some o que este
---personagem não pode usar — e os dois nomes servem para quem está planejando o outro lado.
local function PassaFaccao(e, modo)
    if not modo then return true end
    if not e.factionOnly then return true end       -- serve para os dois lados
    if modo == "mine" then return e.factionOnly == MyFaction() end
    return e.factionOnly == modo
end

-- A lista já ranqueada, depois dos filtros.
function ns.GetFiltered()
    local all = ns.GetRanked()
    local modo = ns.db.factionFilter

    -- Os termos são quebrados UMA vez, e não dentro do laço.
    local termos
    if ns.search and ns.search ~= "" then
        termos = {}
        for termo in ns.Fold(ns.search):gmatch("%S+") do
            termos[#termos + 1] = termo
        end
        if #termos == 0 then termos = nil end
    end

    local out = {}
    for i = 1, #all do
        local e = all[i]
        -- (The old source filter and the single-expansion filter live on as the Type and
        -- Expansion columns: `ns.PassesColumnFilters`. A filter kept but no longer shown would
        -- hide mounts with nothing on screen saying why.)
        if PassaFaccao(e, modo)
            and (ns.db.showUnobtainable or not e.unobtainable)
            and PassaBusca(e, termos)
            and ns.PassesColumnFilters(e) then
            out[#out + 1] = e
        end
    end
    return out, #all
end

--------------------------------------------------------------------------------
-- THE WINDOW'S LIST: one list, tags, one number (25/09)
--
-- (!) The user: *"a lista com o percentual do lado confunde, por que aparece em um bloco de
-- garantido 71% e termina com 0%, dai o proximo bloco começa com 33% que é na sorte... Melhor ser
-- uma lista única com tags"*. The bands still exist INSIDE the addon -- they carry the certainty
-- rules and the alert -- but the window shows one list, ordered by one number, and says WHAT each
-- mount is with tags, filterable like columns.
--------------------------------------------------------------------------------

-- Tag keys, in the order they are shown on a row (the most telling first).
ns.TAG_ORDER = { "raid", "dungeon", "drop", "quest", "achievement", "renown", "reputation",
                 "vendor", "profession", "event", "petbattle", "promotion", "discovery" }
ns.TAG_NAME = {
    raid = L["Raid"], dungeon = L["Dungeon"], drop = L["Drop"], quest = L["Quest"],
    achievement = L["Achievement"], renown = L["Renown"], reputation = L["Reputation"],
    vendor = L["Vendor"], profession = L["Profession"], event = L["World Event"],
    petbattle = L["Pet Battle"], promotion = L["Shop / promotion"], discovery = L["Discovery"],
}
local TAG_RANK = {}
for i, k in ipairs(ns.TAG_ORDER) do TAG_RANK[k] = i end

-- Blizzard's own source type (`C_MountJournal` source) -> tag.
local TAG_OF_SOURCE = {
    [1] = "drop", [2] = "quest", [3] = "vendor", [4] = "profession", [5] = "petbattle",
    [6] = "achievement", [7] = "event", [8] = "promotion", [9] = "promotion", [10] = "promotion",
    [11] = "discovery",
}

---What a mount IS, as a set of tags and an ordered list. Built from what the game says (source
---type) and what the catalogue adds (reputation, renown, the group an encounter needs).
function ns.Tags(e)
    local set = {}
    local function Add(k) if k then set[k] = true end end
    Add(TAG_OF_SOURCE[e.sourceType])
    if e.chance and e.chance > 0 then Add("drop") end
    if e.groupSize then
        if e.groupSize >= 10 then Add("raid") elseif e.groupSize >= 2 then Add("dungeon") end
    end
    if e.quest then Add("quest") end
    if e.achievement or e.achievementReward then Add("achievement") end
    if e.rep then Add(e.isRenown and "renown" or "reputation") end
    if e.isVendorMount or e.cost then Add("vendor") end
    local list = {}
    for _, k in ipairs(ns.TAG_ORDER) do
        if set[k] then list[#list + 1] = k end
    end
    return set, list
end

-- (!) ONE NUMBER, AND IT IS WHAT THE MOUNT DEPENDS ON (25/09). Two readings were offered and
-- the user tried both: *"nem um nem outro (...) se a chance de drop de algo é 33% então é 33% mesmo
-- que seja de paragon de reputação ou de drop, se for de alguma conquista depende de quantas já
-- fez e falta, de reputação é o que falta da reputação, de 0% a 100%"*.
--
--   luck         the drop chance -- a rare's, a paragon cache's, a boss's -- even while a
--                requirement still locks it: the number is what the mount itself costs you
--   achievement  how much of it is done, criteria partial included (Almost Completed
--                Achievements' formula, the addon that inspired this number)
--   reputation   the whole road to the standing asked for, 0 to 100% (renown: levels)
--   ready        100%
--   ?            what cannot be measured: an unconfirmed purchase, or no data at all

---The row's number, 0..1, or nil when it cannot be measured (it goes last, shown as "?").
function ns.RowPercent(e)
    if e.tier == ns.TIER.GONE or e.tier == ns.TIER.UNKNOWN or e.tier == ns.TIER.CHECK then
        return nil
    end
    if not e.deterministic and e.chance and e.chance > 0 then
        return 1 / e.chance
    end
    if e.tier == ns.TIER.READY then return 1 end
    if e.requirement then return math.max(0, math.min(1, e.requirement)) end
    return nil
end

---As the row shows it: a drop keeps the chance format (33%, 1%, 0.05%, ~0.11%), the rest is a
---whole percentage.
function ns.RowPercentText(e)
    local v = ns.RowPercent(e)
    if not v then return "?" end
    if not e.deterministic and e.chance and e.chance > 0 then return ns.FormatChance(e.chance) end
    if v > 0 and v < 0.01 then return "<1%" end
    return string.format("%d%%", math.floor(v * 100 + 0.5))
end

---The window's order: an optional column first (tag or expansion), then ALWAYS the number
---(highest first, unmeasurable last), then the name.
function ns.SortForWindow(list, by)
    local key = {}
    for _, e in ipairs(list) do
        local _, tags = ns.Tags(e)
        key[e] = {
            pct = ns.RowPercent(e),
            tag = TAG_RANK[tags[1] or ""] or 99,
            exp = -(e.expansion or -1),
            name = e.name or "",
        }
    end
    table.sort(list, function(a, b)
        local ka, kb = key[a], key[b]
        if by == "tag" and ka.tag ~= kb.tag then return ka.tag < kb.tag end
        if by == "expansion" and ka.exp ~= kb.exp then return ka.exp < kb.exp end
        if by == "name" and ka.name ~= kb.name then return ka.name < kb.name end
        if (ka.pct == nil) ~= (kb.pct == nil) then return ka.pct ~= nil end
        if ka.pct and kb.pct and ka.pct ~= kb.pct then return ka.pct > kb.pct end
        return ka.name < kb.name
    end)
    return list
end

---The column filters: tags (a mount passes when it has ANY chosen tag) and expansions.
function ns.PassesColumnFilters(e)
    local t = ns.db and ns.db.tagFilter
    if t and next(t) then
        local set = ns.Tags(e)
        local ok = false
        for k in pairs(t) do if set[k] then ok = true; break end end
        if not ok then return false end
    end
    local x = ns.db and ns.db.expFilter
    if x and next(x) and not x[e.expansion or -1] then return false end
    return true
end

---The expansion's name in the game's language (`EXPANSION_NAME<n>`), our English as reserve.
function ns.ExpansionLabel(id, fallback)
    local g = id and _G["EXPANSION_NAME" .. id]
    if type(g) == "string" and g ~= "" then return g end
    return fallback or "?"
end
