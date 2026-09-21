-- RocketMounts | tests/harness.lua
-- Simulador mínimo da API do WoW para rodar o addon fora do jogo.
--
--     luajit tests/harness.lua        (da pasta do addon)
--
-- Não substitui o teste in-game: não desenha nada e as montarias são inventadas. O que
-- ele prova é a ORDEM — que é a única coisa que este addon faz e que os outros não fazem.
-- Se a regra de faixa quebrar, quebra aqui, em disco, e não depois de o jogador abrir a
-- janela e ver uma montaria de 1/2000 no topo. Este arquivo NÃO entra no .toc.

local ADDON = "RocketMounts"

--------------------------------------------------------------------------------
-- Objeto genérico: qualquer método vira no-op que devolve outro objeto genérico.
--------------------------------------------------------------------------------
local function widget(kind)
    local self = { __kind = kind, __scripts = {}, __events = {}, __shown = false }

    function self.SetScript(_, name, fn) self.__scripts[name] = fn end
    function self.GetScript(_, name) return self.__scripts[name] end
    function self.RegisterEvent(_, e) self.__events[e] = true end
    function self.RegisterForDrag() end
    function self.Show() self.__shown = true end
    function self.Hide() self.__shown = false end
    function self.IsShown() return self.__shown end
    function self.GetName() return kind .. "Frame" end

    function self.CreateFontString(_, _, template)
        local fs = widget("FontString")
        fs.__hasFont = template ~= nil
        function fs.SetFont(_, path, size, flags)
            fs.__hasFont = true
            fs.__font, fs.__size, fs.__flags = path, size, flags
            return true
        end
        function fs.GetFont() return fs.__font, fs.__size, fs.__flags end
        -- Reproduz o erro real: FontString sem fonte estoura no SetText, e in-game isso
        -- aparece como "cliquei e não abriu".
        function fs.SetText(_, text)
            if not fs.__hasFont then
                error("FontString:SetText(): Font not set", 2)
            end
            fs.__text = text
            return text
        end
        function fs.GetText() return fs.__text end
        return fs
    end

    function self.CreateTexture()
        local t = widget("Texture")
        function t.SetAtlas(_, a) t.__atlas = a end
        function t.GetAtlas() return t.__atlas end
        return t
    end

    setmetatable(self, {
        __index = function(t, key)
            local fn = function(...) return t end
            rawset(t, key, fn)
            return fn
        end,
    })
    return self
end

--------------------------------------------------------------------------------
-- O mundo falso
--------------------------------------------------------------------------------
_G = _G or getfenv(0)

UIParent = widget("UIParent")
GameTooltip = widget("GameTooltip")
UISpecialFrames = {}
SlashCmdList = {}
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }

function CreateFrame(kind) return widget(kind) end
function UnitFactionGroup() return "Alliance" end
function GetMoney() return 500000 end          -- 50 de ouro
function GetMoneyString(v) return tostring(v) .. "c" end
function BreakUpLargeNumbers(v) return tostring(v) end
function tinsert(t, v) table.insert(t, v) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

for i = 1, 8 do
    _G["FACTION_STANDING_LABEL" .. i] = ("Nível" .. i)
end

C_Timer = { After = function(_, fn) fn() end }
C_Texture = { GetAtlasInfo = function() return nil end }
C_Map = {
    GetMapInfo = function(id) return { name = "Zona " .. id } end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function() end,
}
C_CurrencyInfo = {
    GetCurrencyInfo = function(id) return { quantity = 300, name = "Moeda " .. id } end,
}
C_Item = {
    GetItemCount = function() return 2 end,
    GetItemNameByID = function(id) return "Item " .. id end,
}
Settings = {
    VarType = { Number = "number", Boolean = "boolean" },
    RegisterVerticalLayoutCategory = function() return widget("Category") end,
    RegisterProxySetting = function() return widget("Setting") end,
    CreateSliderOptions = function() return widget("SliderOptions") end,
    CreateSlider = function() end,
    CreateCheckbox = function() end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
}

-- Conquista: a 2 de 4 critérios.
function GetAchievementInfo(id) return id, "Conquista " .. id, 10, false end
function GetAchievementNumCriteria() return 4 end
function GetAchievementCriteriaInfo(_, i) return "c" .. i, nil, i <= 2 end

--------------------------------------------------------------------------------
-- Montarias falsas. Cada uma existe para provar UMA regra de faixa.
--------------------------------------------------------------------------------
local MOUNTS = {
    -- mountID, spellID, nome, sourceType, coletada, facção (nil = ambas)
    { 1, 1001, "Pronta por reputacao",  3, false },
    { 2, 1002, "Quase la por reputacao", 3, false },
    { 3, 1003, "Metade da conquista",   6, false },
    { 4, 1004, "Farm curto",            1, false },
    { 5, 1005, "Farm longo",            1, false },
    { 6, 1006, "Sem estimativa",        0, false },
    -- Dois pares na MESMA faixa, para o desempate ter o que provar. Sem eles, inverter
    -- a ordem de progresso dentro da faixa passava no teste sem reprovar nada.
    { 9, 1009, "Quase la com mais rep",   3, false },
    { 10, 1010, "Farm curto mais raro",   1, false },
    { 7, 1007, "Ja coletada",           1, true  },
    { 8, 1008, "Da outra faccao",       1, false, 0 },   -- 0 = Horda
}

C_MountJournal = {
    GetMountIDs = function()
        local ids = {}
        for i, m in ipairs(MOUNTS) do ids[i] = m[1] end
        return ids
    end,
    GetMountInfoByID = function(id)
        for _, m in ipairs(MOUNTS) do
            if m[1] == id then
                local factionSpecific = m[6] ~= nil
                return m[3], m[2], 100000 + id, false, true, m[4], false,
                       factionSpecific, m[6], false, m[5], id, false
            end
        end
    end,
    GetMountInfoExtraByID = function(id)
        return 1, "Descrição da montaria " .. id, "Fonte da montaria " .. id
    end,
}

-- Reputação: 1001 já está Exaltado; 1002 está a 80% do caminho.
C_Reputation = {
    GetFactionDataByID = function(fid)
        if fid == 9001 then
            return { name = "Faccao pronta", reaction = 8, currentStanding = 42000 }
        elseif fid == 9002 then
            return { name = "Faccao quase", reaction = 7, currentStanding = 33600 }  -- 80% de 42000
        elseif fid == 9003 then
            return { name = "Faccao mais perto", reaction = 7, currentStanding = 39900 }  -- 95%
        end
    end,
}
C_MajorFactions = { GetMajorFactionRenownInfo = function() return nil end }

-- O catálogo do MCL, com só o que o addon lê dele.
MCL_GUIDE = {
    ready = true,
    mountLookup = {
        [1001] = { rep = { factionId = 9001, factionName = "Faccao pronta", levelName = "Exalted" } },
        [1002] = { rep = { factionId = 9002, factionName = "Faccao quase", levelName = "Exalted" } },
        [1003] = { achievementId = 555 },
        [1004] = { chance = 100, method = "NPC", lockBossName = "Bicho", coords = { { m = 23, x = 26.8, y = 11.6 } } },
        [1005] = { chance = 2000, method = "BOSS", lockBossName = "Chefe" },
        [1009] = { rep = { factionId = 9003, factionName = "Faccao mais perto", levelName = "Exalted" } },
        [1010] = { chance = 50, method = "NPC" },
    },
}
MCL_GUIDE_CURRENCY_DATA = {}

LibStub = function() return nil end

--------------------------------------------------------------------------------
-- Carrega o addon
--------------------------------------------------------------------------------
local ns = {}
local FILES = { "Core.lua", "Skin.lua", "Sources.lua", "Score.lua", "Window.lua", "Options.lua", "Commands.lua" }

for _, file in ipairs(FILES) do
    local chunk, err = loadfile(file)
    if not chunk then error("não carregou " .. file .. ": " .. tostring(err)) end
    chunk(ADDON, ns)
end

ns.frame.__scripts.OnEvent(ns.frame, "ADDON_LOADED", ADDON)
ns.frame.__scripts.OnEvent(ns.frame, "PLAYER_LOGIN")

--------------------------------------------------------------------------------
-- Conferências
--------------------------------------------------------------------------------
local falhas = 0
local function check(rotulo, got, want)
    local ok = (got == want)
    if not ok then falhas = falhas + 1 end
    print(string.format("%s %-52s  %s%s",
        ok and "ok  " or "FALHA", rotulo, tostring(got),
        ok and "" or ("  (esperado " .. tostring(want) .. ")")))
end

local ranked = ns.GetRanked(true)

local porNome = {}
for i, e in ipairs(ranked) do porNome[e.name] = { pos = i, e = e } end

check("montaria ja coletada fica de fora", porNome["Ja coletada"], nil)
check("montaria da outra faccao fica de fora", porNome["Da outra faccao"], nil)
check("sobram as oito que faltam", #ranked, 8)

check("reputacao cumprida = Pronto para pegar",
    porNome["Pronta por reputacao"].e.tier, ns.TIER.READY)
check("reputacao a 80% = Quase la",
    porNome["Quase la por reputacao"].e.tier, ns.TIER.CLOSE)
check("conquista a 50% = Ja comecei",
    porNome["Metade da conquista"].e.tier, ns.TIER.UNDERWAY)
check("queda de 1/100 = Farm curto",
    porNome["Farm curto"].e.tier, ns.TIER.SHORTFARM)
check("queda de 1/2000 = Farm longo",
    porNome["Farm longo"].e.tier, ns.TIER.LONGFARM)
check("sem dado nenhum = Sem estimativa",
    porNome["Sem estimativa"].e.tier, ns.TIER.UNKNOWN)

-- A ordem é o produto. Trava ela inteira, não uma posição isolada: uma regra nova que
-- desloque duas montarias de lugar tem que reprovar aqui.
local ordemEsperada = {
    "Pronta por reputacao",
    -- Dentro da faixa, quem andou mais caminho vem antes: 95% na frente de 80%.
    "Quase la com mais rep", "Quase la por reputacao",
    "Metade da conquista",
    -- Empate de progresso resolve pela queda: 1/50 antes de 1/100.
    "Farm curto mais raro", "Farm curto",
    "Farm longo", "Sem estimativa",
}
for i, nome in ipairs(ordemEsperada) do
    check("posicao " .. i, ranked[i] and ranked[i].name, nome)
end

-- A faixa nunca pode ficar fora de ordem, seja qual for a regra que a produziu.
local crescente = true
for i = 2, #ranked do
    if ranked[i].tier < ranked[i - 1].tier then crescente = false end
end
check("as faixas saem em ordem crescente", crescente, true)

-- O numero que a linha mostra tem que ser o que justificou a faixa.
check("Pronto mostra 100%", porNome["Pronta por reputacao"].e.headline, "100%")
check("Quase la mostra 80%", porNome["Quase la por reputacao"].e.headline, "80%")
check("Conquista mostra 50%", porNome["Metade da conquista"].e.headline, "50%")
check("Farm curto mostra a queda", porNome["Farm curto"].e.headline, "1/100")
check("Sem estimativa nao inventa numero", porNome["Sem estimativa"].e.headline, "—")

-- Sem catalogo nenhum o addon nao pode quebrar: ele so perde a taxa de queda.
local guardado = MCL_GUIDE
MCL_GUIDE = nil
ns.Invalidate()
local semMCL = ns.GetRanked(true)
check("sem o MCL a lista continua de pe", #semMCL, 8)
local todasSemEstimativa = true
for _, e in ipairs(semMCL) do
    if e.tier ~= ns.TIER.UNKNOWN then todasSemEstimativa = false end
end
check("e sem ele tudo cai em Sem estimativa", todasSemEstimativa, true)
MCL_GUIDE = guardado
ns.Invalidate()

-- Fumaca da janela: construir e desenhar nao pode estourar.
local okJanela, erroJanela = pcall(ns.ToggleWindow)
check("a janela monta e desenha sem erro", okJanela, true)
if not okJanela then print("      " .. tostring(erroJanela)) end

print("")
print(falhas == 0 and "FIM — tudo certo" or ("FIM — " .. falhas .. " falha(s)"))
os.exit(falhas == 0 and 0 or 1)
