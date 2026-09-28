-- RocketMount | Sources.lua
-- Camada de dados: junta o que a API do jogo sabe com o que os addons de catálogo
-- já curaram, e devolve um registro normalizado por montaria que falta.
--
-- Política: a API é a fonte da verdade do que É (o que você tem, quanta reputação,
-- quanta moeda). Os addons de terceiro entram só com o que a API NÃO dá — a taxa de
-- drop e a coordenada. Sem eles o addon continua funcionando com menos informação.
local _, ns = ...
local L = ns.L
local Vendedores   -- defined below (the vendor section); used by BuildList at run time

--------------------------------------------------------------------------------
-- Provedores opcionais
--------------------------------------------------------------------------------

-- MCL (Mount Collection Log): `MCL_GUIDE.mountLookup[spellId]` é um registro já
-- mesclado (guia + vendedor + reputação + conquista), montado em PLAYER_LOGIN + 4s.
local function MCLGuide()
    local g = _G.MCL_GUIDE
    if g and g.ready and g.mountLookup then return g end
    return nil
end

-- MountJournalEnhanced embute a MountsRarity-2.0: o percentual da base de jogadores
-- que tem cada montaria. NÃO é taxa de drop — é popularidade. Entra só como desempate.
local rarityLib
local function Rarity()
    if rarityLib == nil then
        if _G.LibStub then
            local ok, lib = pcall(_G.LibStub, "MountsRarity-2.0", true)
            rarityLib = (ok and lib) or false
        else
            rarityLib = false
        end
    end
    return rarityLib or nil
end

function ns.ProvidersReady()
    return MCLGuide() ~= nil
end

function ns.ProviderStatus()
    local mcl = MCLGuide() and true or false
    local rar = Rarity() and true or false
    return mcl, rar
end

--------------------------------------------------------------------------------
-- Nome das fontes. O jogo já traduz essas strings; a tabela abaixo é só o plano B
-- para o caso de uma delas não existir neste cliente.
--------------------------------------------------------------------------------
local SOURCE_FALLBACK = {
    [0] = L["Unknown"],
    [1] = L["Drop"],
    [2] = L["Quest"],
    [3] = L["Vendor"],
    [4] = L["Profession"],
    [5] = L["Pet Battle"],
    [6] = L["Achievement"],
    [7] = L["World Event"],
    [8] = L["Promotion"],
    [9] = L["Trading Card Game"],
    [10] = L["Shop"],
    [11] = L["Discovery"],
}

ns.SOURCE_NAMES = setmetatable({}, {
    __index = function(t, k)
        local s = _G["BATTLE_PET_SOURCE_" .. tostring(k)] or SOURCE_FALLBACK[k] or SOURCE_FALLBACK[0]
        rawset(t, k, s)
        return s
    end,
})

--------------------------------------------------------------------------------
-- Reputação
--------------------------------------------------------------------------------

-- Nível de reputação como o MCL escreve (em inglês, é o dado dele) → índice da API.
local STANDING_INDEX = {
    Hated = 1, Hostile = 2, Unfriendly = 3, Neutral = 4,
    Friendly = 5, Honored = 6, Revered = 7, Exalted = 8,
}

-- Reputação acumulada, a partir do Neutro, para chegar a cada nível. São os valores
-- padrão do jogo desde sempre; valem para facção clássica (amizade e renome não usam).
local STANDING_TOTAL = {
    [5] = 3000,    -- Amigável
    [6] = 9000,    -- Honrado
    [7] = 21000,   -- Reverenciado
    [8] = 42000,   -- Exaltado
}

---De QUEM é a reputação que estamos lendo.
---
---⛑ Relato do usuário, 21/09: *"eu não sei qual char meu tem a reputação e se tem, por que tá
---escrito que posso pegar, mas qual char tem essa reputação?"*. Ele está certo e a pergunta não
---tinha resposta na tela: o addon lê a reputação do personagem **conectado**, e nunca dizia isso.
---Desde o War Within parte das facções virou reputação de **Brigada** (vale para a conta inteira)
---e parte continua por personagem — e a diferença muda completamente o que o jogador tem que
---fazer. `C_Reputation.IsAccountWideReputation` (11.0+) responde qual é qual.
local function ReputationScope(factionId)
    if C_Reputation and C_Reputation.IsAccountWideReputation then
        local ok, conta = pcall(C_Reputation.IsAccountWideReputation, factionId)
        if ok and conta then return "conta" end
        if ok then return "personagem" end
    end
    return nil    -- cliente sem a função: não afirmamos nada
end

---A frase que diz de quem é aquele progresso. Sem ela "Exaltado" não informa nada: o jogador
---não sabe se é dele, deste personagem, ou de um alt que ele nem lembra.
local function ScopeLabel(factionId)
    local escopo = ReputationScope(factionId)
    if escopo == "conta" then
        return L["account-wide reputation"]
    elseif escopo == "personagem" then
        return string.format(L["this character only (%s)"], UnitName("player") or "?")
    end
    return nil
end

---(!) A REQUIREMENT WE CANNOT READ IS AN UNMET REQUIREMENT, NOT AN ABSENT ONE.
---
---This function used to return `nil` on six different paths -- faction unknown to the API,
---standing name we do not map, renown info missing. And the caller read `nil` as "this mount has
---no reputation gate", which is the opposite of the truth: the catalogue had just told us there
---IS one.
---
---The player caught it: *"os outros e reputacao que nenhum personagem meu tem e ta ali como se
---desse para comprar"*. Exactly right, and the mechanism is precise -- `GetFactionDataByID`
---returns nothing for a faction this character has never encountered, which is the very case
---where the mount is furthest away. The less we knew, the closer to the top it went.
---
---So it never returns nil once the catalogue says there is a requirement. Unreadable becomes
---`pct = 0` plus `unreadable`, and the label says why.
local function ReputationProgressHere(rep)
    if not rep or not rep.factionId then return nil end

    local nome = rep.factionName or "?"
    local alvo = STANDING_INDEX[rep.levelName or ""]

    -- (!) ANTES DE DIZER "ninguém tem", PERGUNTA AO LIVRO-CAIXA. A API só fala do personagem
    -- conectado, mas o `Roster` anotou o que cada um tinha ao entrar — e a pergunta do usuário
    -- era exatamente essa: *"consegue mostrar qual personagem tem a reputação, caso seja
    -- legada?"*. Reputação de Brigada não precisa disto; a legada, sim.
    local outro = ns.Roster and ns.Roster.Line(rep.factionId, alvo) or nil
    local desconhecida = {
        kind = "rep", factionName = nome, pct = 0, unreadable = true,
        outroChar = outro,
        label = outro
            and string.format(L["%s: %s — this character does not have it"], nome, outro)
            or string.format(L["%s: no reputation with this faction on this character"], nome),
    }

    -- Renome (facção moderna): o progresso é o nível, e a API responde direto.
    if rep.renown and C_MajorFactions and C_MajorFactions.GetMajorFactionRenownInfo then
        local ok, info = pcall(C_MajorFactions.GetMajorFactionRenownInfo, rep.factionId)
        if ok and info and info.renownLevel then
            local need = rep.level or 1
            local have = info.renownLevel
            -- (!) "renome 25 de 5" NÃO É FRASE. O usuário leu e perguntou: *"eu tenho 25 e precisa
            -- de 5? isso que entendi?"*. A forma "X de Y" só faz sentido enquanto X caminha para
            -- Y; passado o Y, ela vira charada. Cumprido se diz cumprido.
            local texto
            if have >= need then
                texto = string.format(L["%s: renown %d reached (you are at %d)"], nome, need, have)
            else
                texto = string.format(L["%s: renown %d of %d"], nome, have, need)
            end
            local escopo = ScopeLabel(rep.factionId)
            return {
                kind = "rep", factionName = nome,
                have = have, need = need,
                pct = math.min(1, have / math.max(1, need)),
                scope = ReputationScope(rep.factionId),
                label = texto .. (escopo and ("  —  " .. escopo) or ""),
            }
        end
        return desconhecida
    end

    if not (C_Reputation and C_Reputation.GetFactionDataByID) then return desconhecida end
    local ok, data = pcall(C_Reputation.GetFactionDataByID, rep.factionId)
    if not ok or not data or not data.reaction then return desconhecida end

    local name = data.name or nome

    -- Paragon: a barra que continua depois do Exaltado, e que reinicia a cada baú.
    if rep.levelName == "Paragon" then
        if C_Reputation.GetFactionParagonInfo then
            local okP, value, threshold = pcall(C_Reputation.GetFactionParagonInfo, rep.factionId)
            if okP and value and threshold and threshold > 0 then
                local into = value % threshold
                return {
                    kind = "rep", factionName = name, pct = into / threshold,
                    scope = ReputationScope(rep.factionId),
                    label = string.format(L["%s: %s of %s to the next cache"],
                        name, BreakUpLargeNumbers(into), BreakUpLargeNumbers(threshold)),
                }
            end
        end
        return desconhecida
    end

    local targetIdx = STANDING_INDEX[rep.levelName or ""]
    if not targetIdx then
        -- Nível que não é patamar de reputação (ex.: "Professional", que é perícia de
        -- profissão). Não dá para medir, e por isso mesmo NÃO está cumprido.
        return {
            kind = "rep", factionName = name, pct = 0, unreadable = true,
            label = string.format(L["%s: asks for %s, which I cannot measure"], name, rep.levelName or "?"),
        }
    end

    if data.reaction >= targetIdx then
        return {
            kind = "rep", factionName = name, pct = 1,
            scope = ReputationScope(rep.factionId),
            label = string.format(L["%s: already %s%s"], name,
                _G["FACTION_STANDING_LABEL" .. targetIdx] or L["at the standing"],
                ScopeLabel(rep.factionId) and ("  —  " .. ScopeLabel(rep.factionId)) or ""),
        }
    end

    local total = STANDING_TOTAL[targetIdx]
    local standing = data.currentStanding or 0
    if total and standing >= 0 then
        local pct = math.min(1, standing / total)
        return {
            kind = "rep", factionName = name, pct = pct,
            have = standing, need = total,
            scope = ReputationScope(rep.factionId),
            label = string.format(L["%s: %s of %s to %s%s"],
                name, BreakUpLargeNumbers(standing), BreakUpLargeNumbers(total),
                _G["FACTION_STANDING_LABEL" .. targetIdx] or L["the standing"],
                ScopeLabel(rep.factionId) and ("  —  " .. ScopeLabel(rep.factionId)) or ""),
        }
    end

    local pct = (data.reaction - 1) / math.max(1, targetIdx - 1)
    return {
        kind = "rep", factionName = name, pct = math.max(0, math.min(1, pct)),
        scope = ReputationScope(rep.factionId),
        label = string.format("%s: %s", name,
            _G["FACTION_STANDING_LABEL" .. data.reaction] or ""),
    }
end

-- (!) THE CLOSEST OF YOUR CHARACTERS (25/09). The user: *"se um char x tiver a reputação que
-- precisa ou que falta pouco, só avisar e atualizar esta lista, e dai a lista pega tudo
-- independente de facção e dizer qual dos chars que está mais proximo de pegar"*. A mount is
-- collected for the whole account, so for a LEGACY reputation (one per character) the number is
-- the best character's, and the row names it. This reverses the rule of 22/09 ("whoever has it
-- is another character, so it is not met") -- the user's call.
--
-- Only legacy standings: a Warband reputation is the same on every character, and renown and
-- friendship are not in the ledger. The ledger is what each character had at its last login,
-- and the label says whose number it is.
local function BestAlt(factionId, alvo)
    if not (ns.Roster and ns.Roster.WhoHas) then return nil end
    local melhor
    for _, c in ipairs(ns.Roster.WhoHas(factionId)) do
        local pct
        if c.reaction >= alvo then
            pct = 1
        elseif c.standing and STANDING_TOTAL[alvo] and c.standing >= 0 then
            pct = math.min(1, c.standing / STANDING_TOTAL[alvo])
        else
            pct = math.max(0, math.min(1, (c.reaction - 1) / math.max(1, alvo - 1)))
        end
        if not melhor or pct > melhor.pct then
            melhor = { name = c.name, class = c.class, pct = pct, standing = c.standing,
                reaction = c.reaction }
        end
    end
    return melhor
end

local function ReputationProgress(rep)
    local aqui = ReputationProgressHere(rep)
    if aqui and rep and rep.factionId then aqui.factionId = aqui.factionId or rep.factionId end
    if not (rep and rep.factionId) or rep.renown or rep.friendship then return aqui end
    local alvo = STANDING_INDEX[rep.levelName or ""]
    if not alvo or ReputationScope(rep.factionId) == "conta" then return aqui end

    local melhor = BestAlt(rep.factionId, alvo)
    local meu = (aqui and not aqui.unreadable and aqui.pct) or 0
    if aqui then aqui.altPct = melhor and melhor.pct or nil end
    if not melhor or melhor.pct <= meu then return aqui end

    local nome = (aqui and aqui.factionName) or rep.factionName or "?"
    local nivel = _G["FACTION_STANDING_LABEL" .. alvo] or rep.levelName
    local texto
    if melhor.pct >= 1 then
        texto = string.format(L["%s: %s is already %s — buy it on that character"],
            nome, melhor.name, nivel)
    elseif melhor.standing and STANDING_TOTAL[alvo] then
        texto = string.format(L["%s: %s is at %s of %s to %s — the closest of your characters"],
            nome, melhor.name, BreakUpLargeNumbers(melhor.standing),
            BreakUpLargeNumbers(STANDING_TOTAL[alvo]), nivel)
    else
        texto = string.format(L["%s: %s is %s — the closest of your characters"], nome,
            melhor.name, _G["FACTION_STANDING_LABEL" .. melhor.reaction] or "?")
    end
    return {
        kind = "rep", factionId = rep.factionId, factionName = nome,
        pct = melhor.pct, char = melhor.name, charClass = melhor.class,
        outroChar = melhor.name, minePct = meu,
        scope = "personagem", label = texto,
    }
end

--------------------------------------------------------------------------------
-- THE DROP CHANCE, FROM OUR OWN TABLE
--
-- (!) No addon of ours depends on another one (the user, 27/09). The list took the chance from
-- MCL and from nowhere else -- the window's footer said so in red -- while `Data/MobDrops.lua`
-- (Wowhead's "Dropped by", keyed by creature) sat in the addon feeding only the rare alert and
-- the map. It knows 158 mounts; MCL knows the chance of 192, and 102 are the same ones.
--
-- Which number, when several creatures drop the mount: THE BEST creature's, among those with at
-- least ten drops seen. The player goes where it drops most, and a pooled average is dragged
-- down by whoever is killed most (Amber Primordial Direhorn: 1 in 21 from the Warbringers, 1 in
-- 133 pooled with the scouts that almost never drop it). With no creature at ten drops, the
-- pool of all of them, marked rough.
--
-- (!) A CREATURE THAT DROPS IT NEARLY EVERY TIME IS NOT A FARM. Measured against MCL on 27/09:
-- Mail Muncher is "1 in 1" on Wowhead and 1 in 100 in MCL; Grey Riding Camel, Alunira, the
-- Void-Scarred Gryphon the same. The kill is certain -- finding, summoning or unlocking the
-- creature is the whole task, and no drop table measures that. Shown as a chance it would put
-- those mounts on top of the farms. So from half the kills up there is NO chance number: the
-- mount stays without an estimate, and the row says why.
--------------------------------------------------------------------------------
local SURE_DROP = 0.5     -- from here up the kill is not where the luck is
local ENOUGH_DROPS = 10   -- Wowhead's sample below this is a rough estimate
local porItem             -- item -> { n, rough, npc, name, sure, creatures }
local indexadoDe          -- the table `porItem` was built from

local function IndexarChance()
    porItem = {}
    if type(ns.MobDrops) ~= "table" then return end
    local soma = {}
    for npc, rec in pairs(ns.MobDrops) do
        if type(rec) == "table" then
            for _, d in ipairs(rec) do
                local c, o = tonumber(d.count), tonumber(d.outof)
                if d.item and c and o and c > 0 and o > 0 then
                    local s = soma[d.item] or { count = 0, outof = 0, creatures = 0 }
                    soma[d.item] = s
                    s.count, s.outof, s.creatures = s.count + c, s.outof + o, s.creatures + 1
                    local taxa = c / o
                    if c >= ENOUGH_DROPS and (not s.melhor or taxa > s.melhor) then
                        s.melhor, s.npc, s.name = taxa, npc, rec.name
                    end
                    if not s.qualquer or taxa > s.qualquer then
                        s.qualquer, s.npcQualquer, s.nomeQualquer = taxa, npc, rec.name
                    end
                end
            end
        end
    end
    for item, s in pairs(soma) do
        local taxa = s.melhor or (s.count / s.outof)
        porItem[item] = {
            n = 1 / taxa,
            rough = not s.melhor,
            npc = s.npc or s.npcQualquer,
            name = s.name or s.nomeQualquer,
            sure = taxa >= SURE_DROP,
            creatures = s.creatures,
        }
    end
end

---The chance of the mount this item teaches, from our own table.
---@return table|nil `{ n = 1-in-n, rough, npc, name, sure, creatures }`
function ns.OwnChance(itemID)
    if not itemID then return nil end
    -- The table is swapped in tests and never in game: indexed again when it is another one.
    if not porItem or indexadoDe ~= ns.MobDrops then
        IndexarChance()
        indexadoDe = ns.MobDrops
    end
    return porItem[itemID]
end

--------------------------------------------------------------------------------
-- WHERE IT IS GOT, FROM OUR OWN TABLE
--
-- (!) The user, 28/09: *"falta os pontos no mapa como mostrei em prints de vendedores, missão e
-- etc"*. The map took vendors, treasures and quest givers from MCL, read at run time; alone, it
-- had the rares and nothing else -- and no addon of ours depends on another one.
-- `Data/MountPlaces.lua` (tools/coletar_lugares.py) holds, for each mount, who sells it, the
-- chest it is in and the quest that rewards it, each with its place on the map.
--
-- What comes out has the shape the rest of the addon already reads (it was MCL's): `vendors`
-- and `coords`, in the map's own scale. A vendor or a quest of the OTHER faction is left out.
--------------------------------------------------------------------------------
local function DoMeuLado(ficha)
    if type(ficha) ~= "table" then return false end
    if not ficha.side then return true end
    local meu = UnitFactionGroup and UnitFactionGroup("player") or nil
    return not meu or ficha.side == meu
end

---A table's `where`, as a list in a fixed order (the map's id, then the order of the table).
local function Pontos(where)
    local mapas, out = {}, {}
    for mapa in pairs(type(where) == "table" and where or {}) do mapas[#mapas + 1] = mapa end
    table.sort(mapas)
    for _, mapa in ipairs(mapas) do
        local pts = where[mapa]
        for i = 1, #pts - 1, 2 do
            out[#out + 1] = { m = mapa, x = pts[i], y = pts[i + 1] }
        end
    end
    return out
end

---The name of an object in the player's language: the game has no way to ask it by id, so the
---translation is ours (`Locales/ptBR_Places.lua`) and English is what is left.
local function NomeDoObjeto(id, ingles)
    local t = ns.PlaceNamesLocal and ns.PlaceNamesLocal.object
    local nome = type(t) == "table" and t[id]
    return type(nome) == "string" and nome or ingles
end

---@return table|nil `{ vendors, coords, quests, box }`
function ns.OwnPlaces(mountID)
    local T = ns.MountPlaces
    local m = type(T) == "table" and type(T.mount) == "table" and T.mount[mountID]
    if type(m) ~= "table" then return nil end
    local out = { vendors = {}, coords = {}, quests = {}, box = type(m.box) == "table" and m.box or nil }

    for _, id in ipairs(type(m.npc) == "table" and m.npc or {}) do
        local v = type(T.npc) == "table" and T.npc[id]
        if DoMeuLado(v) then
            local pts = Pontos(v.where)
            for _, p in ipairs(pts) do
                out.vendors[#out.vendors + 1] = { npc = v.name, npcId = id, m = p.m, x = p.x, y = p.y }
            end
            -- A vendor nobody has placed is still a vendor: the card names it.
            if #pts == 0 then out.vendors[#out.vendors + 1] = { npc = v.name, npcId = id } end
        end
    end
    for _, id in ipairs(type(m.object) == "table" and m.object or {}) do
        local o = type(T.object) == "table" and T.object[id]
        if type(o) == "table" then
            -- An object is a chest unless the table says what else: a PORTAL is the way in to
            -- where the mount is, and appears at one of its places (28/09).
            local kind = type(o.kind) == "string" and o.kind or "treasure"
            local mapa
            for _, p in ipairs(Pontos(o.where)) do
                out.coords[#out.coords + 1] = {
                    m = p.m, x = p.x, y = p.y, n = NomeDoObjeto(id, o.name), kind = kind, objectId = id,
                    -- the first of each map: on a continent, the only one drawn
                    first = p.m ~= mapa,
                }
                mapa = p.m
            end
        end
    end
    for _, id in ipairs(type(m.quest) == "table" and m.quest or {}) do
        local q = type(T.quest) == "table" and T.quest[id]
        if DoMeuLado(q) then
            out.quests[#out.quests + 1] = { id = id, name = q.name }
            for _, p in ipairs(Pontos(q.where)) do
                -- `q` is what the map reads to know the point is spent: the quest done.
                out.coords[#out.coords + 1] = {
                    m = p.m, x = p.x, y = p.y, n = q.name, kind = "quest", questId = id, q = id,
                }
            end
        end
    end
    return out
end

--------------------------------------------------------------------------------
-- WHERE THE PRICE COMES FROM
--
-- (!) Reported on 27/09 with a screenshot, standing at Elianna (Emerald Dream): *"Montaria
-- apontando 100% mas sem a moeda para comprar"*. Garrant costs 1 Dream Infusion, the character
-- held none, and the list said 100%, "the vendor sells it to you", "Requirements -- all met".
-- The footer of the same screenshot: "without MCL". The price used to come from MCL's table and
-- from nowhere else, so without the catalogue the addon knew NO price at all -- and the vendor's
-- verdict is about requirements, not about money (the game does not tint red what you cannot
-- afford, `MerchantFrame.lua`). No price known was read as nothing to pay: the same family of
-- defect, for the seventh time, and this one reaches everybody who installs the addon alone.
--
-- Three sources now, the most certain first:
--   vendor      what the vendor CHARGES, read with the vendor open (`ns.ScanMerchant`). It is the
--               game charging, so it wins. Kept for the account: a price is not per character.
--   catalogue   MCL's table, when it is installed.
--   journal     the game's own source text, which carries the price as a link:
--               `Cost: |r1|Hcurrency:2777|h|T...|t`. Always there, in every language.
--
-- Measured on 27/09 against the client's table (515 mounts with a price somewhere): the journal
-- and MCL agree on 338, the journal alone has 16, and where they differ the journal is usually
-- SHORT -- it names the first part of a price made of several (Great Red Elekk: 500 gold, and
-- MCL adds 5 Champion's Seals). So the journal comes last, and it can only ever say "at least
-- this much": a requirement, never a permission. And it can be wrong (Blessed Amani Burrower:
-- 1,600 written, 6,400 charged), which is why the vendor, once seen, replaces it.
--------------------------------------------------------------------------------

---A number as the journal writes it: `1600`, `5,000,000`, `5.000.000`. Prices are whole numbers.
local function Inteiro(s)
    local n = tonumber((tostring(s or ""):gsub("[%.,]", "")))
    return n
end

---The price the journal's source text states, in MCL's shape.
---
---The text is one block per vendor, separated by an empty line, and a mount sold by two vendors
---(one per faction) states its price twice: the first block that has a price is the price.
---A price with an icon and no link (honour, a holiday's token) names nothing the game can count,
---and is left out rather than guessed.
---@return table[]|nil `{ { type = "currency"|"item"|"gold", id = number, amount = number }, ... }`
function ns.JournalCost(sourceText)
    if type(sourceText) ~= "string" or sourceText == "" then return nil end
    if issecretvalue and issecretvalue(sourceText) then return nil end
    local NL = string.char(10)
    local texto = sourceText:gsub("|n", NL)
    texto = texto .. NL .. NL
    for bloco in texto:gmatch("(.-)" .. NL .. "%s*" .. NL) do
        local out = {}
        -- `|r<number>` then a link, then the icon -- or the icon alone, for gold.
        for numero, resto in bloco:gmatch("|r%s*(%d[%d%.,]*)%s*(|[HT][^" .. NL .. "]*)") do
            local quanto = Inteiro(numero)
            local tipo, id = resto:match("^|H(%a+):(%d+)")
            if quanto and quanto > 0 then
                if tipo == "currency" or tipo == "item" then
                    out[#out + 1] = { type = tipo, id = tonumber(id), amount = quanto }
                elseif not tipo and resto:upper():find("^|T[^|]*UI%-GOLDICON") then
                    out[#out + 1] = { type = "gold", id = 0, amount = quanto * 10000 }
                end
            end
        end
        if #out > 0 then return out end
    end
    return nil
end

---What the vendor charged for this mount the last time one was open, in MCL's shape.
local function VendorCost(mountID)
    local v = mountID and ns.db and type(ns.db.vendorCost) == "table" and ns.db.vendorCost[mountID]
    if type(v) == "table" and #v > 0 then return v end
    return nil
end

---What it costs, and whether you can pay -- as TWO separate facts.
---
---(!) They used to be one string, and the player called it out: *"a linha onde aparece valores
---mistura o valor que tenho em bag com o valor da montaria, muito confuso"*. He was right --
---`"1234g 56s 78c de 3000g"` asks the reader to parse two numbers and work out which is which,
---every row, when what he wants first is one of them: **the price**.
---
---So `price` is the number the row shows, and `gap` is a short clause that only exists when
---something is missing. What you already hold is not printed unless it matters.
local function CostOf(list)
    -- Gold apart from the rest (currencies, items): the percentage holds gold back until every
    -- other requirement is met (Score.lua, `Price`).
    local precos, faltas, worst = {}, {}, 1
    local goldPct, otherPct
    -- What each part of the price is, for the card's "where it comes from" (27/09): the name and
    -- what the GAME says about it. A currency carries its description; an item's is its flavour
    -- text, read from its tooltip when the card is drawn (it may not be in the cache yet).
    local partes = {}
    for _, c in ipairs(list) do
        local have, need, preco, falta = nil, c.amount, nil, nil
        local parte

        if c.type == "gold" then
            have = GetMoney and GetMoney() or 0
            -- `GetCoinTextureString` é compacto e já traz o ícone da moeda: "3000g". O
            -- `GetMoneyString` escreve por extenso e ocupa a linha inteira.
            preco = GetCoinTextureString and GetCoinTextureString(need) or tostring(need)
            if have < need then
                falta = GetCoinTextureString and GetCoinTextureString(need - have)
                    or tostring(need - have)
            end
        elseif c.type == "currency" and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, c.id)
            if ok and info then
                have = info.quantity or 0
                preco = string.format("%s %s", BreakUpLargeNumbers(need), info.name or "?")
                if have < need then
                    falta = string.format("%s %s", BreakUpLargeNumbers(need - have), info.name or "?")
                end
                parte = { type = "currency", id = c.id, name = info.name, icon = info.iconFileID,
                          about = info.description }
            end
        elseif c.type == "item" and C_Item and C_Item.GetItemCount then
            local ok, n = pcall(C_Item.GetItemCount, c.id, true)
            if ok then
                have = n or 0
                local iname = (C_Item.GetItemNameByID and C_Item.GetItemNameByID(c.id))
                    or string.format(L["item %d"], c.id)
                preco = string.format("%d x %s", need, iname)
                if have < need then
                    falta = string.format("%d x %s", need - have, iname)
                end
                parte = { type = "item", id = c.id, name = iname }
            end
        end
        if parte then
            parte.have, parte.need = have, need
            partes[#partes + 1] = parte
        end

        if have and need and need > 0 and preco then
            local pct = math.min(1, have / need)
            if pct < worst then worst = pct end
            if c.type == "gold" then
                goldPct = math.min(goldPct or 1, pct)
            else
                otherPct = math.min(otherPct or 1, pct)
            end
            precos[#precos + 1] = preco
            if falta then faltas[#faltas + 1] = falta end
        end
    end

    if #precos == 0 then return nil end

    local preco = table.concat(precos, " + ")
    local falta = #faltas > 0 and table.concat(faltas, " + ") or nil
    return {
        pct = worst,
        goldPct = goldPct,
        otherPct = otherPct,
        price = preco,
        gap = falta,
        parts = partes,
        -- A frase completa, para a ficha: o preço primeiro, a falta depois, e nunca os dois
        -- números grudados um no outro.
        label = falta and string.format(L["%s  ·  %s missing"], preco, falta)
            or string.format(L["%s  ·  you have it"], preco),
    }
end

---The price from the most certain source that has one (see "WHERE THE PRICE COMES FROM").
---A source whose entries cannot be counted (MCL has prices with amount 0) gives way to the next.
local function CostProgress(spellID, itemID, mountID, sourceText)
    local fontes = {}
    local visto = VendorCost(mountID)
    if visto then fontes[#fontes + 1] = { "vendor", visto } end
    local data = _G.MCL_GUIDE_CURRENCY_DATA
    local list = type(data) == "table" and (data[spellID] or (itemID and data[itemID])) or nil
    if type(list) == "table" then
        if type(list[1]) ~= "table" then list = { list } end
        fontes[#fontes + 1] = { "catalogue", list }
    end
    local ok, doDiario = pcall(ns.JournalCost, sourceText)
    if ok and doDiario then fontes[#fontes + 1] = { "journal", doDiario } end

    for _, f in ipairs(fontes) do
        local okC, custo = pcall(CostOf, f[2])
        if okC and custo then
            custo.from = f[1]
            -- The vendor charged something the addon could not read: what is here is part of it.
            custo.partial = f[1] == "vendor" and f[2].partial or nil
            return custo
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Missão
--------------------------------------------------------------------------------
---A missão que entrega a montaria já foi feita?
---
---(!) O CATÁLOGO TINHA ISTO E EU NÃO LIA. `MCL_GUIDE_QUEST_DATA` guarda missão, id, quem entrega
---e onde, para 83 montarias — e o addon ignorava a tabela inteira. Pergunta do usuário:
---*"Grande Grifo, se falta missão, não dá para ir pegar, correto?"*. Correto, e até agora a tela
---não dizia nem que havia missão.
---
---⚠️ O QUE ESTA FUNÇÃO **NÃO** RESPONDE, e o usuário perguntou direto: se a missão está
---**disponível**. O jogo não expõe o grafo de pré-requisito de missão para addon — dá para saber
---se você CONCLUIU uma missão, nunca se você PODE pegá-la. (Conferência: dos addons instalados,
---67 usam `IsQuestFlaggedCompleted` e **nenhum** usa API de pré-requisito, porque não existe; os
---que mostram cadeia de missão, como o Zygor, embarcam base própria.)
---
---Então aqui se diz o que dá para provar: feita, ou não feita. "Não feita" já responde a pergunta
---que importa — tem coisa no caminho — sem fingir saber quantos passos faltam.
local function QuestProgress(mountID, nossas)
    local q
    -- OURS FIRST (28/09): the quests of `Data/MountPlaces.lua`. A mount with a quest for each
    -- faction has one left here (`ns.OwnPlaces` drops the other side's); with more than one, the
    -- one already done counts, and otherwise the first.
    if type(nossas) == "table" and #nossas > 0 then
        q = { questId = nossas[1].id, quest = nossas[1].name }
        for _, n in ipairs(nossas) do
            local ok, feita = pcall(C_QuestLog.IsQuestFlaggedCompleted, n.id)
            if ok and feita then q = { questId = n.id, quest = n.name }; break end
        end
    else
        local data = _G.MCL_GUIDE_QUEST_DATA
        if not data or not mountID then return nil end
        q = data[mountID]
    end
    if type(q) ~= "table" then return nil end

    local questID = q.questId
    -- O nome vem do jogo quando ele já carregou a missão; senão fica o do catálogo, que é o
    -- nome em inglês. Pedir o carregamento aqui faz o próximo desenho já achar traduzido.
    local titulo = q.quest
    if questID and C_QuestLog then
        if C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, questID) end
        if C_QuestLog.GetTitleForQuestID then
            local ok, t = pcall(C_QuestLog.GetTitleForQuestID, questID)
            if ok and type(t) == "string" and t ~= "" then titulo = t end
        end
    end

    local feita, naConta = false, false
    if questID and C_QuestLog then
        if C_QuestLog.IsQuestFlaggedCompleted then
            local ok, v = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
            feita = ok and v or false
        end
        if C_QuestLog.IsQuestFlaggedCompletedOnAccount then
            local ok, v = pcall(C_QuestLog.IsQuestFlaggedCompletedOnAccount, questID)
            naConta = ok and v or false
        end
    end

    local onde = q.npc and (q.npc .. (q.zone and (" — " .. q.zone) or "")) or q.zone

    if feita then
        return {
            kind = "quest", pct = 1, questID = questID, titulo = titulo, onde = onde,
            label = string.format(L['Quest "%s": completed'], titulo or "?"),
        }
    end

    -- FEITA EM OUTRO PERSONAGEM é informação, e não requisito cumprido: a montaria é deste.
    local extra = naConta and L["  —  already done on another character"] or ""
    return {
        kind = "quest", pct = 0, questID = questID, titulo = titulo, onde = onde,
        naConta = naConta,
        label = string.format(L['Quest "%s": not completed%s%s'], titulo or "?",
            onde and ("  ·  " .. onde) or "", extra),
    }
end

--------------------------------------------------------------------------------
-- Conquista
--------------------------------------------------------------------------------
local function AchievementProgress(achID)
    if not achID or not GetAchievementInfo then return nil end
    local ok, _, name, _, completed = pcall(GetAchievementInfo, achID)
    if not ok or not name then return nil end
    if completed then
        return { pct = 1, achID = achID, label = string.format(L["Achievement completed: %s"], name) }
    end

    -- Partial criteria count (Almost Completed Achievements' formula: Achievements.lua).
    local pct = ns.AchievementCompletion and ns.AchievementCompletion(achID) or 0
    return {
        pct = pct, achID = achID,
        label = string.format(L["%s: %d%% done"], name, math.floor(pct * 100)),
    }
end

--------------------------------------------------------------------------------
-- Busca em texto livre
--------------------------------------------------------------------------------
-- (!) A BUSCA NÃO PODE SER SÓ PELO NOME, e o exemplo do usuário prova: *"não achei a montaria
-- que dropa no Fyrakk"*. A montaria do Fyrakk se chama **Anu'relos, Flame's Guidance** — a
-- palavra "Fyrakk" não aparece no nome dela em lugar nenhum. Ela aparece no texto de origem do
-- jogo e no nome do chefe que o catálogo guarda.
--
-- Então o que se pesquisa é tudo que o addon sabe sobre a montaria: nome, o texto da Blizzard,
-- o chefe, o vendedor, a zona e a facção. Quem procura "fyrakk", "aberrus" ou "vendedor" acha.

-- Acentos fora, para "fenix" achar "Fênix". São os pares do português, em UTF-8: cada acentuado
-- ocupa dois bytes, então `gsub` byte a byte não serve e a substituição é por par.
local ACENTOS = {
    ["á"]="a", ["à"]="a", ["â"]="a", ["ã"]="a", ["ä"]="a",
    ["é"]="e", ["è"]="e", ["ê"]="e", ["ë"]="e",
    ["í"]="i", ["ì"]="i", ["î"]="i", ["ï"]="i",
    ["ó"]="o", ["ò"]="o", ["ô"]="o", ["õ"]="o", ["ö"]="o",
    ["ú"]="u", ["ù"]="u", ["û"]="u", ["ü"]="u",
    ["ç"]="c", ["ñ"]="n",
}

function ns.Fold(texto)
    if type(texto) ~= "string" then return "" end
    texto = texto:lower()
    for acentuado, simples in pairs(ACENTOS) do
        texto = texto:gsub(acentuado, simples)
    end
    return texto
end

---Tudo que dá para pesquisar numa montaria, junto e sem acento.
local function Haystack(e)
    local partes = {
        e.name, e.sourceText, e.description, e.bossName, e.method,
        e.rep and e.rep.factionName,
        e.vendor and e.vendor.npc, e.vendor and e.vendor.zone,
        ns.SOURCE_NAMES[e.sourceType],
        -- A expansão entra na busca: quem digita "midnight" ou "legion" acha por ela.
        e.expansionName,
    }
    -- A zona das coordenadas também entra: quem lembra "Aberrus" e não o nome do chefe acha.
    if e.coords and C_Map and C_Map.GetMapInfo then
        for _, wp in ipairs(e.coords) do
            if wp.m then
                local info = C_Map.GetMapInfo(wp.m)
                if info and info.name then partes[#partes + 1] = info.name end
            end
            if wp.n then partes[#partes + 1] = wp.n end
        end
    end

    local limpo = {}
    for _, parte in ipairs(partes) do
        if type(parte) == "string" and parte ~= "" then
            limpo[#limpo + 1] = parte
        end
    end
    return ns.Fold(table.concat(limpo, " "))
end

ns.Haystack = Haystack

--------------------------------------------------------------------------------
-- Monta a lista
--------------------------------------------------------------------------------

-- Só interessa o que o personagem pode de fato buscar.
local function Playable(isFactionSpecific, faction, shouldHideOnChar)
    if shouldHideOnChar then return false end
    if isFactionSpecific and faction ~= nil then
        local mine = UnitFactionGroup("player")
        local want = (faction == 0) and "Horde" or "Alliance"
        if mine and mine ~= want then return false end
    end
    return true
end

function ns.BuildList()
    local out = {}
    local ids = C_MountJournal.GetMountIDs()
    if not ids then return out end

    local guide = MCLGuide()
    local rarity = Rarity()

    for _, mountID in ipairs(ids) do
        local name, spellID, icon, _, _, sourceType, _, isFactionSpecific,
              faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)

        if name and not isCollected then
            local playable = Playable(isFactionSpecific, faction, shouldHideOnChar)
            if playable or not ns.db.hideUnavailable then
                local e = {
                    mountID = mountID,
                    spellID = spellID,
                    name = name,
                    icon = icon,
                    sourceType = sourceType or 0,
                    isFactionSpecific = isFactionSpecific,
                    faction = faction,
                    playable = playable,
                    -- "Horde" / "Alliance" / nil. Vira rótulo e vira filtro: até aqui a facção
                    -- só servia para ESCONDER a montaria, e esconder não é informar.
                    factionOnly = isFactionSpecific and faction ~= nil
                        and ((faction == 0) and "Horde" or "Alliance") or nil,
                }

                -- O texto que a Blizzard escreve explicando de onde a montaria vem,
                -- já no idioma do cliente. É o melhor "como pega" que existe de graça.
                local _, description, source = C_MountJournal.GetMountInfoExtraByID(mountID)
                e.description = description
                e.sourceText = source

                local rec = guide and spellID and guide.mountLookup[spellID] or nil
                if rec then
                    e.chance = rec.chance
                    e.method = rec.method
                    e.itemID = rec.itemId
                    e.coords = rec.coords
                    e.bossName = rec.lockBossName
                    -- For the Raid / Dungeon tags: MCL records the group an encounter needs.
                    e.groupSize = rec.groupSize
                    -- The difficulties the mount drops on, as the game's own ids: the card names
                    -- them with `GetDifficultyInfo`, in the player's language.
                    e.difficulties = rec.instanceDifficulties
                    -- (!) `vendorInfo` CAN BE A LIST. For the 504 mounts it knows only from its
                    -- vendor table, MCL builds a minimal record with `vendorInfo = vendorList`
                    -- (`MCL_Guide.lua:484`). Read as one vendor, `.npc` was nil: the Dark Phoenix
                    -- stopped being recognised as a guild vendor, and the Gilded Prowler said
                    -- "not even the catalogue knows the vendor" with the vendor right there.
                    e.vendors = Vendedores(rec.vendorInfo)
                    e.vendor = e.vendors[1]
                    for _, v in ipairs(e.vendors) do
                        if v.m and v.x then e.vendor = v; break end
                    end
                    -- ⛑ VENDEDOR SEM COORDENADA é sinal de que nem o catálogo sabe qual é.
                    e.vendorVago = #e.vendors > 0 and not (e.vendor.m and e.vendor.x)
                    e.isVendorMount = #e.vendors > 0 or rec.method == "VENDOR"

                    -- (!) VENDEDOR DE GUILDA TEM NOME PARA O BLOQUEIO. A Fênix Negra continuou
                    -- incomodando mesmo depois de sair de "é só ir pegar": ela ia para a faixa
                    -- de requisito desconhecido dizendo apenas "pode haver requisito", que é
                    -- verdade e não ajuda ninguém.
                    --
                    -- Quando o vendedor é de guilda dá para ser específico: **toda** montaria de
                    -- vendedor de guilda exige reputação com a guilda mais uma conquista DE
                    -- GUILDA — e a conquista de guilda é justamente o que este addon não lê,
                    -- porque nenhum catálogo instalado diz QUAL conquista é de qual montaria.
                    -- Dizer isso é muito melhor que a ressalva genérica.
                    -- (!) VENDEDOR DE GUILDA É REQUISITO NÃO CUMPRIDO, e não "desconhecido".
                    --
                    -- Pesquisado (wiki oficial, 22/09): **toda** montaria de vendedor de guilda
                    -- exige reputação Exaltada com a guilda, e boa parte exige também uma
                    -- conquista DE GUILDA — a Fênix Negra pede a *Guild Glory of the Cataclysm
                    -- Raider*. Isso não é "pode haver requisito": é requisito certo, só que o
                    -- addon não consegue medir (nenhum catálogo instalado associa a conquista de
                    -- guilda à montaria, e a reputação de guilda depende da guilda atual).
                    --
                    -- Então ela entra como acesso a 0%, exatamente como a reputação que não dá
                    -- para ler: não dá para afirmar que está cumprido, então não está.
                    e.vendorGuilda = false
                    for _, v in ipairs(e.vendors) do
                        if type(v.npc) == "string" and v.npc:lower():find("guild", 1, true) then
                            e.vendorGuilda = true
                        end
                    end
                    e.blackMarket = rec.blackMarket
                    -- Marca do MCL para o que saiu do jogo. Ela existia e não era usada: ver
                    -- `showUnobtainable` no `Core.lua`.
                    e.unobtainable = rec.isUnobtainable and true or false
                    e.rep = ReputationProgress(rec.rep)
                    e.isRenown = type(rec.rep) == "table" and rec.rep.renown and true or false
                    -- DEPOIS da leitura de reputação, e não antes: ela sobrescreve `e.rep`, e
                    -- com a injeção em cima a guarda de guilda era apagada duas linhas depois
                    -- de ser escrita. O teste de ordem denunciou — a montaria continuava na
                    -- faixa de preço-só mesmo com o código do bloqueio no lugar.
                    if e.vendorGuilda and not e.rep then
                        e.rep = {
                            kind = "guild", pct = 0, unreadable = true,
                            label = L["Guild vendor: asks for Exalted with the guild and, in most cases, an achievement OF THE GUILD"],
                        }
                    end
                    e.achievement = AchievementProgress(rec.achievementId)
                    e.quest = QuestProgress(mountID)
                end

                -- (!) THE VENDOR'S REPUTATION, when MCL has none (25/09). The Gilded Prowler asks
                -- for Exalted with The Ascended, and neither MCL nor the item's data says so: it
                -- is the vendor's condition, which Wowhead records. `Data/MountReputation.lua`
                -- holds it for every mount, in MCL's shape; MCL's own record wins when it exists.
                if not e.rep and ns.MountReputation and ns.MountReputation[mountID] then
                    local r = ns.MountReputation[mountID]
                    e.rep = ReputationProgress(r)
                    e.isRenown = r.renown and true or false
                end

                -- (!) WHERE IT IS GOT: OURS FIRST (28/09). Vendors, chests and quests from
                -- `Data/MountPlaces.lua`. Of the catalogue's points only what ours does not have
                -- yet is kept: the entrances of instances.
                local okP, nosso = pcall(ns.OwnPlaces, mountID)
                if okP and type(nosso) == "table" then
                    if #nosso.vendors > 0 then
                        e.vendors = nosso.vendors
                        e.vendor = e.vendors[1]
                        for _, v in ipairs(e.vendors) do
                            if v.m and v.x then e.vendor = v; break end
                        end
                        e.vendorVago = not (e.vendor.m and e.vendor.x)
                        e.isVendorMount = true
                        e.placesFrom = "own"
                    end
                    if #nosso.coords > 0 then
                        for _, wp in ipairs(e.coords or {}) do
                            if type(wp) == "table" and wp.i then nosso.coords[#nosso.coords + 1] = wp end
                        end
                        e.coords = nosso.coords
                        e.placesFrom = "own"
                    end
                    if #nosso.quests > 0 then
                        local okQ, missao = pcall(QuestProgress, mountID, nosso.quests)
                        if okQ and missao then e.quest = missao end
                    end
                    e.box = nosso.box
                end

                e.cost = CostProgress(spellID, e.itemID, mountID, source)

                -- (!) O QUE O PRÓPRIO JOGO DIZ QUE FALTA. É a fonte que fecha o buraco que a
                -- Fênix Negra abriu: o catálogo não sabe da conquista de guilda, e o tooltip do
                -- item sabe — em português, e certo depois do próximo patch também.
                -- A conquista que o JOGO diz que dá esta montaria. Fecha o buraco das 126
                -- marcadas "SPECIAL" no catálogo, que não tinham requisito nenhum.
                if ns.Achievements then
                    e.achievementReward = ns.Achievements.Gate(e.name, mountID)
                end

                -- The item, when the catalogue does not have it: our table, but only where
                -- the GAME agrees the item teaches this mount.
                if not e.itemID then e.itemID = ns.VerifiedMountItem(mountID) end
                -- The chance: ours first, the catalogue's only where ours knows nothing (see
                -- "THE DROP CHANCE, FROM OUR OWN TABLE").
                local okCh, nossa = pcall(ns.OwnChance, e.itemID)
                if okCh and nossa then
                    if nossa.sure then
                        e.chance, e.sureDrop = nil, nossa
                    else
                        e.chance, e.chanceRough = nossa.n, nossa.rough
                    end
                    e.chanceFrom = "own"
                    e.dropNpc, e.dropName, e.dropCreatures = nossa.npc, nossa.name, nossa.creatures
                elseif e.box and tonumber(e.box.count) and tonumber(e.box.outof)
                    and e.box.count > 0 and e.box.outof > 0 then
                    -- THE CONTAINER (28/09): a chest, a bag, a reputation's trove. The same two
                    -- rules of the creatures: nearly every time is not a chance, and a small
                    -- sample is rough.
                    local taxa = e.box.count / e.box.outof
                    local nome = e.box.name
                    if e.box.kind == "object" then
                        nome = NomeDoObjeto(e.box.id, nome)
                    elseif C_Item and C_Item.GetItemNameByID then
                        local okN, n = pcall(C_Item.GetItemNameByID, e.box.id)
                        if okN and type(n) == "string" and n ~= "" then nome = n end
                    end
                    if taxa >= SURE_DROP then
                        e.chance, e.sureDrop = nil, { name = nome, box = true }
                    else
                        e.chance, e.chanceRough = 1 / taxa, e.box.count < ENOUGH_DROPS
                    end
                    e.chanceFrom = "own"
                    e.dropName = nome
                    -- (!) A BAG OR A TROVE IS NOT AN ATTEMPT YOU MAKE WHEN YOU WANT. A kill is;
                    -- a chest standing in the world is. How a bag is earned -- a weekly quest,
                    -- a reputation filled again and again -- is not in this table, and a 25%
                    -- trove that takes weeks to come is no short farm (Score.lua).
                    e.chanceIndirect = e.box.kind == "item"
                elseif e.chance then
                    e.chanceFrom = "catalogue"
                end
                -- (!) READ ONLY WHAT ARRIVED. An item out of the cache answers with an empty
                -- tooltip, and empty is not "no requirement". Until it loads, the mount cannot be
                -- confirmed (Score.lua), and the validation (Core.lua) waits for it.
                e.tooltipState = e.itemID and ns.Tooltip and ns.Tooltip.State(e.itemID) or nil
                if e.tooltipState == "ok" then
                    -- When another character holds the reputation, THIS one's red "Requires
                    -- <faction> - Exalted" is not what stands in the way.
                    e.tooltipGate = ns.Tooltip.Gate(e.itemID,
                        e.rep and e.rep.char and { e.rep.factionName } or nil)
                end
                -- What a vendor told THIS character, when it stood in front of one.
                e.vendorCheck = ns.VendorVerdict(mountID)
                -- Montado uma vez por varredura, e não a cada tecla digitada.
                e.expansion, e.expansionName = ns.Expansion and ns.Expansion.Of(mountID)
                e.busca = Haystack(e)

                if rarity and rarity.GetRarityByID then
                    local ok, pct = pcall(rarity.GetRarityByID, rarity, mountID)
                    if ok then e.ownedByPct = pct end
                end

                out[#out + 1] = e
            end
        end
    end

    return out
end

---MCL's `vendorInfo` as a list, whatever shape it came in (one vendor, or a list of them).
Vendedores = function(vi)
    if type(vi) ~= "table" then return {} end
    if vi.npc or vi.m then return { vi } end
    local out = {}
    for _, v in ipairs(vi) do
        if type(v) == "table" then out[#out + 1] = v end
    end
    return out
end

---The item that teaches this mount, from `Data/MountItems.lua` -- only when the game agrees.
local conferido = {}   -- mountID -> item, or false: an item never changes mount within a session
function ns.VerifiedMountItem(mountID)
    if conferido[mountID] ~= nil then return conferido[mountID] or nil end
    local item = ns.MountItems and ns.MountItems[mountID]
    if not (item and C_MountJournal and C_MountJournal.GetMountFromItem) then return nil end
    local ok, m = pcall(C_MountJournal.GetMountFromItem, item)
    conferido[mountID] = (ok and m == mountID) and item or false
    return conferido[mountID] or nil
end

--------------------------------------------------------------------------------
-- THE VENDOR'S OWN VERDICT
--
-- (!) Reported on 23/09 with a screenshot, standing at Trader Araanda (Lunarfall): *"tem montaria
-- que posso pegar, mas no addon não mostra"*. Rocktusk Battleboar, 10,000 gold, the player
-- holding 19,334. The catalogue knows only the price, so the mount went to "Asks for more than
-- the price" -- the band that sits at the END of the list since the Black Phoenix (price known,
-- guild achievement missing, shown as "just go get it"). Right for the Phoenix, wrong here: for
-- the boar, the price IS the whole story, and nothing in the data could say so.
--
-- The game can. With the vendor open, `C_MerchantFrame.GetItemInfo` answers `isPurchasable`
-- and `isUsable` for every item, and Blizzard tints an item red exactly when either is false
-- (`MerchantFrame.lua:362`, 12.1.0). The screenshot shows it is about REQUIREMENTS, not money:
-- a 500-gold item is red with 19k in the bag, and the 20k Witherhide Cliffstomper is NOT red
-- although the player cannot afford it.
--
-- This is not "no data, so it is fine" -- the family of defect this addon keeps fighting. It is
-- the game itself saying "you may buy this". It is recorded per character (the verdict belongs
-- to who stood at the vendor), with the day, and read as an ACCESS requirement: met, or not.
--------------------------------------------------------------------------------
local function CharKey()
    local name = UnitName and UnitName("player")
    if not name then return nil end
    return name .. "-" .. (GetRealmName and GetRealmName() or "")
end

---What the vendor said to THIS character about this mount, as an access requirement.
---@return table|nil `{ pct = 1|0, label }`, nil when this character never saw it at a vendor
function ns.VendorVerdict(mountID)
    local chave = CharKey()
    local porChar = chave and ns.db and ns.db.vendorSeen and ns.db.vendorSeen[chave]
    local v = porChar and porChar[mountID]
    if not v then return nil end
    local quando = date and v.t and date(L["%m/%d"], v.t) or "?"
    if v.ok then
        return { pct = 1, label = string.format(L["the vendor sells it to you (seen %s)"], quando) }
    end
    return { pct = 0, label = string.format(L["the vendor does not sell it to you yet (seen %s)"], quando) }
end

---What the vendor charges for the item at `index`, in MCL's shape: gold from `price` (copper),
---the rest from the extended cost (`GetMerchantItemCostItem`, the call Blizzard's own frame makes
---to draw the price, `MerchantFrame.lua:479` in 12.1.0). `partial` when a part could not be read.
---@return table|nil
local function MerchantCost(index, info)
    local out = {}
    local preco = tonumber(info.price) or 0
    if preco > 0 then out[#out + 1] = { type = "gold", id = 0, amount = preco } end
    if info.hasExtendedCost and GetMerchantItemCostInfo and GetMerchantItemCostItem then
        local okN, n = pcall(GetMerchantItemCostInfo, index)
        for j = 1, math.min(okN and tonumber(n) or 0, MAX_ITEM_COST or 3) do
            local ok, textura, quanto, link = pcall(GetMerchantItemCostItem, index, j)
            if not ok then
                out.partial = true
            elseif textura then
                local tipo, id
                if type(link) == "string" and not (issecretvalue and issecretvalue(link)) then
                    tipo, id = link:match("|H(%a+):(%d+)")
                end
                quanto = tonumber(quanto)
                if (tipo == "currency" or tipo == "item") and quanto and quanto > 0 then
                    out[#out + 1] = { type = tipo, id = tonumber(id), amount = quanto }
                else
                    out.partial = true
                end
            end
        end
    end
    if #out == 0 and not out.partial then return nil end
    out.t = time and time() or 0
    return out
end

---Reads the open vendor. Called on MERCHANT_SHOW and MERCHANT_UPDATE.
---@return boolean changed whether any verdict is new or different
function ns.ScanMerchant()
    if not (GetMerchantNumItems and GetMerchantItemID and C_MerchantFrame
        and C_MerchantFrame.GetItemInfo and C_MountJournal and C_MountJournal.GetMountFromItem) then
        return false
    end
    local chave = CharKey()
    if not (chave and ns.db) then return false end
    ns.db.vendorSeen = ns.db.vendorSeen or {}
    ns.db.vendorSeen[chave] = ns.db.vendorSeen[chave] or {}
    local reg = ns.db.vendorSeen[chave]

    local mudou = false
    local okN, n = pcall(GetMerchantNumItems)
    for i = 1, (okN and n or 0) do
        local okI, itemID = pcall(GetMerchantItemID, i)
        local okM, mountID = pcall(C_MountJournal.GetMountFromItem, okI and itemID or 0)
        if okM and type(mountID) == "number" then
            local okInfo, info = pcall(C_MerchantFrame.GetItemInfo, i)
            if okInfo and type(info) == "table" then
                -- The same test Blizzard uses to tint the item red.
                local ok = info.isPurchasable and info.isUsable and true or false
                local antes = reg[mountID]
                if not antes or antes.ok ~= ok then mudou = true end
                reg[mountID] = { ok = ok, t = time and time() or 0 }
                -- And what it CHARGES: the verdict above is about requirements, not money.
                local okC, custo = pcall(MerchantCost, i, info)
                local escrito = ""
                if okC and custo then
                    ns.db.vendorCost = ns.db.vendorCost or {}
                    local era = ns.db.vendorCost[mountID]
                    if type(era) ~= "table" or #era ~= #custo then mudou = true end
                    for j, c in ipairs(custo) do
                        escrito = escrito .. (j > 1 and " + " or "") .. c.amount .. " " .. c.type .. ":" .. c.id
                        local a = type(era) == "table" and era[j]
                        if not a or a.type ~= c.type or a.id ~= c.id or a.amount ~= c.amount then
                            mudou = true
                        end
                    end
                    ns.db.vendorCost[mountID] = custo
                end
                ns.Log.Add("merchant", {
                    mount = mountID, item = itemID, name = info.name,
                    purchasable = info.isPurchasable, usable = info.isUsable, verdict = ok,
                    cost = escrito, partial = okC and custo and custo.partial or false,
                })
            end
        end
    end
    return mudou
end
