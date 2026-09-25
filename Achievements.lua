-- RocketMount | Achievements.lua
-- Which achievement rewards which mount -- asked of the game, not written down by hand.
--
-- (!) THIS CLOSES THE BIGGEST HOLE THE CATALOGUE HAS, AND IT COSTS NO CURATION.
--
-- The catalogue marks 126 mounts as `method = "SPECIAL"` and records nothing else about them.
-- That is what made the Prestigious War Steed claim to be ready: nothing known, nothing blocking,
-- so nothing stopped it. Checking a sample against warcraftmounts.com showed the pattern -- a
-- large share of those are **achievement rewards**: Prestigious War Steed, Prestigious War Wolf,
-- Llothien Prowler, Arcanist's Manasaber.
--
-- And the game knows every one of them. `GetAchievementReward(id)` returns the reward line of an
-- achievement, and for these it names the mount. Walk the achievement categories once, match the
-- reward text against the mounts you are missing, and the link falls out -- current after every
-- patch, already translated, and nothing copied from anyone.
--
-- The alternative was writing those 126 links into a file by hand from a website. Same answer as
-- always: a hand-written entry is wrong silently, and this one cannot be.
local _, ns = ...
local L = ns.L

local Achievements = {}
ns.Achievements = Achievements

local byMount       -- nome dobrado da montaria -> { id, nome da conquista }
local scanning = false

-- A varredura é fatiada: percorrer todas as categorias de uma vez trava o cliente por um
-- instante no login, que é justamente quando ele já está ocupado.
local SLICE = 40

-- The reward line. `GetAchievementReward` where it exists; otherwise the 11th return of
-- `GetAchievementInfo`, which is what Almost Completed Achievements reads (`Scan.lua`).
local function RewardText(achID)
    if GetAchievementReward then
        local ok, texto = pcall(GetAchievementReward, achID)
        if ok and type(texto) == "string" and texto ~= "" then return texto end
    end
    local ok, _, _, _, _, _, _, _, _, _, _, texto = pcall(GetAchievementInfo, achID)
    return ok and texto or nil
end

local function Store(achID, texto, faltantes)
    if type(texto) ~= "string" or texto == "" then return end
    local dobrado = ns.Fold(texto)
    for chave, nome in pairs(faltantes) do
        -- `find` simples: o texto da recompensa é "Montaria: <nome>" ou variações por idioma, e
        -- procurar o nome dentro dele funciona em todas sem eu escrever o formato de nenhuma.
        if dobrado:find(chave, 1, true) then
            local _, achNome = GetAchievementInfo(achID)
            byMount[chave] = { id = achID, nome = achNome or nome }
        end
    end
end

---Monta o índice. Roda uma vez por sessão, fatiado, e só depois de a lista existir.
function Achievements.Scan()
    if byMount or scanning then return end
    if not (GetCategoryList and GetAchievementInfo) then return end

    scanning = true
    byMount = {}

    -- Só o que falta: casar o texto de recompensa contra mil e cem nomes seria desperdício, e
    -- montaria já coletada não precisa de requisito nenhum.
    local faltantes = {}
    local ok, lista = pcall(ns.GetRanked)
    if ok and type(lista) == "table" then
        for _, e in ipairs(lista) do
            if e.name then faltantes[ns.Fold(e.name)] = e.name end
        end
    end

    local categorias = GetCategoryList() or {}
    local ci, ai = 1, 1

    local function Step()
        local feitas = 0
        while ci <= #categorias and feitas < SLICE do
            local cat = categorias[ci]
            local total = GetCategoryNumAchievements and GetCategoryNumAchievements(cat) or 0
            if ai > total then
                ci, ai = ci + 1, 1
            else
                local okA, achID = pcall(GetAchievementInfo, cat, ai)
                if okA and achID then
                    Store(achID, RewardText(achID), faltantes)
                end
                ai = ai + 1
                feitas = feitas + 1
            end
        end

        if ci <= #categorias then
            C_Timer.After(0, Step)
        else
            scanning = false
            ns.Invalidate()
        end
    end

    Step()
end

---How much of an achievement is done, 0..1 -- the way Almost Completed Achievements counts it
---(`Scan.lua`, `completionPercent`), the addon the user pointed to: every completed criterion is 1,
---and an incomplete one counts its PARTIAL progress (`quantity / reqQuantity`), so "kill 100,
---50 done" is half a criterion and "collect 500 shards" moves with every shard. Our first version
---counted completed criteria only, and a one-criterion achievement sat at 0% until the end.
---
---(!) A META ACHIEVEMENT COUNTS ITS CHILDREN'S PROGRESS (25/09). A meta's criteria are other
---achievements (criteria type 8, the child's id in `assetID`), and the game reports each as
---0 of 1 until the child is done -- so "Worldsoul-Searching" with every child half-way read as
---0%. ACA follows the children down (`Meta.lua`, `buildNode`); so does this, to any depth.
local CRITERIA_ACHIEVEMENT = 8     -- ACHIEVEMENT_CRITERIA_TYPE_ACHIEVEMENT (ACA: Meta.lua)
local MAX_DEPTH = 4

-- Metas whose criteria do not name their children, copied from ACA (`META_CHILD_OVERRIDES`):
-- "Light Up the Night" (Midnight) is these four achievements.
local CHILD_OVERRIDES = {
    [62386] = { 62261, 61453, 62260, 62256 },
}

local function Completion(achID, depth, visiting)
    local override = CHILD_OVERRIDES[achID]
    if override then
        local soma = 0
        for _, filho in ipairs(override) do
            local okI, _, _, _, completo = pcall(GetAchievementInfo, filho)
            if okI and completo then
                soma = soma + 1
            elseif depth < MAX_DEPTH and not visiting[filho] then
                visiting[filho] = true
                soma = soma + Completion(filho, depth + 1, visiting)
                visiting[filho] = nil
            end
        end
        return soma / #override
    end

    local okN, num = pcall(GetAchievementNumCriteria, achID)
    if not okN or not num or num == 0 then return 0 end
    local feito = 0
    for i = 1, num do
        local ok, _, tipo, completo, qty, req, _, _, asset = pcall(GetAchievementCriteriaInfo, achID, i)
        if ok then
            if completo then
                feito = feito + 1
            elseif tipo == CRITERIA_ACHIEVEMENT and type(asset) == "number" and asset > 0
                    and depth < MAX_DEPTH and not visiting[asset] then
                visiting[asset] = true
                feito = feito + Completion(asset, depth + 1, visiting)
                visiting[asset] = nil
            elseif type(qty) == "number" and type(req) == "number" and req > 0 then
                feito = feito + math.max(0, math.min(1, qty / req))
            end
        end
    end
    return feito / num
end

function ns.AchievementCompletion(achID)
    if not (achID and GetAchievementNumCriteria and GetAchievementCriteriaInfo) then return nil end
    return math.max(0, math.min(1, Completion(achID, 0, { [achID] = true })))
end

---True once the scan went through every category (the validation waits for it).
function Achievements.IsDone()
    return byMount ~= nil and not scanning
end

---A conquista que dá esta montaria, se alguma (pela varredura das categorias, pelo nome).
function Achievements.For(mountName)
    if not byMount or not mountName then return nil end
    return byMount[ns.Fold(mountName)]
end

-- (!) THE FIXED TABLE, BY MOUNT ID (25/09): `Data/AchievementMounts.lua`, built from the game's
-- data tables. The category walk above cannot see a SECRET achievement (not listed until earned)
-- nor a reward line that names the ITEM instead of the mount ("Mount: Galakras" teaches Spawn of
-- Galakras, and every "Gladiator Mount") -- 41 of them. Asking `GetAchievementInfo(id)` by id
-- reaches all of them.
local porMontaria, fonte
local function TableFor(mountID)
    if not porMontaria or fonte ~= ns.AchievementMounts then
        porMontaria, fonte = {}, ns.AchievementMounts
        for _, t in ipairs(ns.AchievementMounts or {}) do
            local lista = porMontaria[t[2]]
            if not lista then lista = {}; porMontaria[t[2]] = lista end
            lista[#lista + 1] = { id = t[1], faction = t[3] }
        end
    end
    return mountID and porMontaria[mountID]
end

---Every achievement that gives this mount to THIS character: the fixed table (minus the other
---faction's twin) and the category walk, without repeats.
function Achievements.Candidates(mountName, mountID)
    local out, visto = {}, {}
    local faccao = UnitFactionGroup and UnitFactionGroup("player")
    for _, c in ipairs(TableFor(mountID) or {}) do
        if not visto[c.id] and (not c.faction or not faccao or c.faction == faccao) then
            visto[c.id] = true
            out[#out + 1] = c.id
        end
    end
    local pelaVarredura = Achievements.For(mountName)
    if pelaVarredura and not visto[pelaVarredura.id] then out[#out + 1] = pelaVarredura.id end
    return out
end

---O requisito, no formato dos outros.
---
---(!) SINAL NEGATIVO, como todas as fontes deste addon: quando a conquista existe e não está
---feita, ele bloqueia; quando está feita, ele **não** devolve "liberado", porque conquista
---concluída não prova que a montaria ainda é obtenível -- foi exatamente assim que o tooltip
---promoveu o Corcel de Guerra Prestigioso para o topo.
---
---More than one achievement can give the same mount (the legacy 10- and 25-player "Glory",
---and the one that replaced both). Any of them done: no gate. None done: the one closest to
---done is the road shown.
function Achievements.Gate(mountName, mountID)
    local melhor
    for _, id in ipairs(Achievements.Candidates(mountName, mountID)) do
        local okI, _, nome, _, completo = pcall(GetAchievementInfo, id)
        if okI and nome then
            if completo then return nil end
            -- Its real progress, not a flat 0: the list is ordered by how much is left.
            local pct = ns.AchievementCompletion(id) or 0
            if not melhor or pct > melhor.pct then
                melhor = { id = id, nome = nome, pct = pct }
            end
        end
    end
    if not melhor then return nil end
    return {
        kind = "achievementReward", pct = melhor.pct, achID = melhor.id,
        label = string.format(L['Achievement "%s": %d%% done'], melhor.nome,
            math.floor(melhor.pct * 100)),
    }
end
