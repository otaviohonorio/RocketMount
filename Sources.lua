-- RocketMounts | Sources.lua
-- Camada de dados: junta o que a API do jogo sabe com o que os addons de catálogo
-- já curaram, e devolve um registro normalizado por montaria que falta.
--
-- Política: a API é a fonte da verdade do que É (o que você tem, quanta reputação,
-- quanta moeda). Os addons de terceiro entram só com o que a API NÃO dá — a taxa de
-- drop e a coordenada. Sem eles o addon continua funcionando com menos informação.
local _, ns = ...

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
    [0] = "Desconhecida",
    [1] = "Saque",
    [2] = "Missão",
    [3] = "Vendedor",
    [4] = "Profissão",
    [5] = "Batalha de mascotes",
    [6] = "Conquista",
    [7] = "Evento mundial",
    [8] = "Promoção",
    [9] = "Jogo de cartas",
    [10] = "Loja",
    [11] = "Descoberta",
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
        return "reputação da conta"
    elseif escopo == "personagem" then
        return "só deste personagem (" .. (UnitName("player") or "?") .. ")"
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
local function ReputationProgress(rep)
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
            and string.format("%s: %s — este personagem não tem", nome, outro)
            or string.format("%s: nenhuma reputação com esta facção neste personagem", nome),
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
                texto = string.format("%s: renome %d alcançado (você está em %d)", nome, need, have)
            else
                texto = string.format("%s: renome %d de %d", nome, have, need)
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
                    label = string.format("%s: %s de %s para o próximo baú",
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
            label = string.format("%s: exige %s, que eu não sei medir", name, rep.levelName or "?"),
        }
    end

    if data.reaction >= targetIdx then
        return {
            kind = "rep", factionName = name, pct = 1,
            scope = ReputationScope(rep.factionId),
            label = string.format("%s: já está %s%s", name,
                _G["FACTION_STANDING_LABEL" .. targetIdx] or "no nível",
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
            label = string.format("%s: %s de %s para %s%s",
                name, BreakUpLargeNumbers(standing), BreakUpLargeNumbers(total),
                _G["FACTION_STANDING_LABEL" .. targetIdx] or "o nível",
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

---What it costs, and whether you can pay -- as TWO separate facts.
---
---(!) They used to be one string, and the player called it out: *"a linha onde aparece valores
---mistura o valor que tenho em bag com o valor da montaria, muito confuso"*. He was right --
---`"1234g 56s 78c de 3000g"` asks the reader to parse two numbers and work out which is which,
---every row, when what he wants first is one of them: **the price**.
---
---So `price` is the number the row shows, and `gap` is a short clause that only exists when
---something is missing. What you already hold is not printed unless it matters.
local function CostProgress(spellID, itemID)
    local data = _G.MCL_GUIDE_CURRENCY_DATA
    if not data then return nil end
    local list = data[spellID] or (itemID and data[itemID])
    if not list then return nil end
    if type(list[1]) ~= "table" then list = { list } end

    local precos, faltas, worst = {}, {}, 1
    for _, c in ipairs(list) do
        local have, need, preco, falta = nil, c.amount, nil, nil

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
            end
        elseif c.type == "item" and C_Item and C_Item.GetItemCount then
            local ok, n = pcall(C_Item.GetItemCount, c.id, true)
            if ok then
                have = n or 0
                local iname = (C_Item.GetItemNameByID and C_Item.GetItemNameByID(c.id))
                    or ("item " .. c.id)
                preco = string.format("%d x %s", need, iname)
                if have < need then
                    falta = string.format("%d x %s", need - have, iname)
                end
            end
        end

        if have and need and need > 0 and preco then
            local pct = math.min(1, have / need)
            if pct < worst then worst = pct end
            precos[#precos + 1] = preco
            if falta then faltas[#faltas + 1] = falta end
        end
    end

    if #precos == 0 then return nil end

    local preco = table.concat(precos, " + ")
    local falta = #faltas > 0 and table.concat(faltas, " + ") or nil
    return {
        pct = worst,
        price = preco,
        gap = falta,
        -- A frase completa, para a ficha: o preço primeiro, a falta depois, e nunca os dois
        -- números grudados um no outro.
        label = falta and (preco .. "  ·  faltam " .. falta) or (preco .. "  ·  você tem"),
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
        return { pct = 1, label = string.format("Conquista concluída: %s", name) }
    end

    local num = GetAchievementNumCriteria and GetAchievementNumCriteria(achID) or 0
    if num and num > 0 then
        local done = 0
        for i = 1, num do
            local ok2, _, _, criteriaCompleted = pcall(GetAchievementCriteriaInfo, achID, i)
            if ok2 and criteriaCompleted then done = done + 1 end
        end
        return {
            pct = done / num,
            label = string.format("%s: %d de %d", name, done, num),
        }
    end

    return { pct = 0, label = name }
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
                    e.vendor = rec.vendorInfo
                    -- ⛑ VENDEDOR SEM COORDENADA é sinal de que nem o catálogo sabe qual é: a
                    -- Fênix Negra vem como `{ npc = "Guild Vendors", zone = "" }`. Onde o
                    -- catálogo é vago, o addon não pode ser categórico.
                    e.vendorVago = rec.vendorInfo ~= nil
                        and not (rec.vendorInfo.m and rec.vendorInfo.x)

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
                    local npc = rec.vendorInfo and rec.vendorInfo.npc or ""
                    e.vendorGuilda = npc:lower():find("guild", 1, true) ~= nil
                    e.blackMarket = rec.blackMarket
                    -- Marca do MCL para o que saiu do jogo. Ela existia e não era usada: ver
                    -- `showUnobtainable` no `Core.lua`.
                    e.unobtainable = rec.isUnobtainable and true or false
                    e.rep = ReputationProgress(rec.rep)
                    -- DEPOIS da leitura de reputação, e não antes: ela sobrescreve `e.rep`, e
                    -- com a injeção em cima a guarda de guilda era apagada duas linhas depois
                    -- de ser escrita. O teste de ordem denunciou — a montaria continuava na
                    -- faixa de preço-só mesmo com o código do bloqueio no lugar.
                    if e.vendorGuilda and not e.rep then
                        e.rep = {
                            kind = "guild", pct = 0, unreadable = true,
                            label = "Vendedor de guilda: exige guilda Exaltada e, na maioria, "
                                .. "uma conquista DE GUILDA",
                        }
                    end
                    e.achievement = AchievementProgress(rec.achievementId)
                end

                e.cost = CostProgress(spellID, e.itemID)

                -- (!) O QUE O PRÓPRIO JOGO DIZ QUE FALTA. É a fonte que fecha o buraco que a
                -- Fênix Negra abriu: o catálogo não sabe da conquista de guilda, e o tooltip do
                -- item sabe — em português, e certo depois do próximo patch também.
                if e.itemID and ns.Tooltip then
                    e.tooltipGate = ns.Tooltip.Gate(e.itemID)
                end
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
