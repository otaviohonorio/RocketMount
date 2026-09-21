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
    [1] = "Queda",
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

local function ReputationProgress(rep)
    if not rep or not rep.factionId then return nil end

    -- Renome (facção moderna): o progresso é o nível, e a API responde direto.
    if rep.renown and C_MajorFactions and C_MajorFactions.GetMajorFactionRenownInfo then
        local ok, info = pcall(C_MajorFactions.GetMajorFactionRenownInfo, rep.factionId)
        if ok and info and info.renownLevel then
            local need = rep.level or 1
            local have = info.renownLevel
            return {
                kind = "renown",
                factionName = rep.factionName,
                have = have,
                need = need,
                pct = math.min(1, have / math.max(1, need)),
                label = string.format("Renome %d de %d", have, need),
            }
        end
        return nil
    end

    if not (C_Reputation and C_Reputation.GetFactionDataByID) then return nil end
    local ok, data = pcall(C_Reputation.GetFactionDataByID, rep.factionId)
    if not ok or not data or not data.reaction then return nil end

    local targetIdx = STANDING_INDEX[rep.levelName or ""] or 8
    local name = data.name or rep.factionName or "?"

    if data.reaction >= targetIdx then
        return {
            kind = "rep", factionName = name, pct = 1,
            label = string.format("%s: já está %s", name, _G["FACTION_STANDING_LABEL" .. targetIdx] or "no nível"),
        }
    end

    local total = STANDING_TOTAL[targetIdx]
    local standing = data.currentStanding or 0
    if total and standing >= 0 then
        -- Facção clássica: dá para dizer a fração exata do caminho.
        local pct = math.min(1, standing / total)
        return {
            kind = "rep", factionName = name, pct = pct,
            have = standing, need = total,
            label = string.format("%s: %s de %s para %s",
                name, BreakUpLargeNumbers(standing), BreakUpLargeNumbers(total),
                _G["FACTION_STANDING_LABEL" .. targetIdx] or "o nível"),
        }
    end

    -- Amizade e afins: sem a tabela de totais, o que dá para afirmar é o degrau.
    local pct = (data.reaction - 1) / math.max(1, targetIdx - 1)
    return {
        kind = "rep", factionName = name, pct = math.max(0, math.min(1, pct)),
        label = string.format("%s: %s", name, data.reaction and (_G["FACTION_STANDING_LABEL" .. data.reaction] or "") or ""),
    }
end

--------------------------------------------------------------------------------
-- Custo (ouro, moeda, item)
--------------------------------------------------------------------------------
local function CostProgress(spellID, itemID)
    local data = _G.MCL_GUIDE_CURRENCY_DATA
    if not data then return nil end
    local list = data[spellID] or (itemID and data[itemID])
    if not list then return nil end
    if type(list[1]) ~= "table" then list = { list } end

    local parts, worst = {}, 1
    for _, c in ipairs(list) do
        local have, need, label = nil, c.amount, nil

        if c.type == "gold" then
            have = GetMoney and GetMoney() or 0
            label = string.format("%s de %s", GetMoneyString(have, true), GetMoneyString(need, true))
        elseif c.type == "currency" and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, c.id)
            if ok and info then
                have = info.quantity or 0
                label = string.format("%s: %s de %s", info.name or "?",
                    BreakUpLargeNumbers(have), BreakUpLargeNumbers(need))
            end
        elseif c.type == "item" and C_Item and C_Item.GetItemCount then
            local ok, n = pcall(C_Item.GetItemCount, c.id, true)
            if ok then
                have = n or 0
                local iname = C_Item.GetItemNameByID and C_Item.GetItemNameByID(c.id) or ("item " .. c.id)
                label = string.format("%s: %d de %d", iname or ("item " .. c.id), have, need)
            end
        end

        if have and need and need > 0 then
            local pct = math.min(1, have / need)
            if pct < worst then worst = pct end
            parts[#parts + 1] = label
        end
    end

    if #parts == 0 then return nil end
    return { pct = worst, label = table.concat(parts, " · ") }
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
                    e.blackMarket = rec.blackMarket
                    e.unobtainable = rec.isUnobtainable
                    e.rep = ReputationProgress(rec.rep)
                    e.achievement = AchievementProgress(rec.achievementId)
                end

                e.cost = CostProgress(spellID, e.itemID)

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
