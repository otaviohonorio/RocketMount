-- RocketMounts | Achievements.lua
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

local Achievements = {}
ns.Achievements = Achievements

local byMount       -- nome dobrado da montaria -> { id, nome da conquista }
local scanning = false

-- A varredura é fatiada: percorrer todas as categorias de uma vez trava o cliente por um
-- instante no login, que é justamente quando ele já está ocupado.
local SLICE = 40

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
    if not (GetCategoryList and GetAchievementReward and GetAchievementInfo) then return end

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
                    local okR, texto = pcall(GetAchievementReward, achID)
                    if okR then Store(achID, texto, faltantes) end
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

---A conquista que dá esta montaria, se alguma.
function Achievements.For(mountName)
    if not byMount or not mountName then return nil end
    return byMount[ns.Fold(mountName)]
end

---O requisito, no formato dos outros.
---
---(!) SINAL NEGATIVO, como todas as fontes deste addon: quando a conquista existe e não está
---feita, ele bloqueia; quando está feita, ele **não** devolve "liberado", porque conquista
---concluída não prova que a montaria ainda é obtenível -- foi exatamente assim que o tooltip
---promoveu o Corcel de Guerra Prestigioso para o topo.
function Achievements.Gate(mountName)
    local ach = Achievements.For(mountName)
    if not ach then return nil end

    local okI, _, nome, _, completo = pcall(GetAchievementInfo, ach.id)
    if not okI then return nil end
    if completo then return nil end

    return {
        kind = "achievementReward", pct = 0, achID = ach.id,
        label = string.format("Conquista \"%s\": não concluída", nome or ach.nome or "?"),
    }
end
