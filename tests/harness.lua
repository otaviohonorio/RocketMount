-- RocketMount | tests/harness.lua
-- Simulador mínimo da API do WoW para rodar o addon fora do jogo.
--
--     luajit tests/harness.lua        (da pasta do addon)
--
-- Não substitui o teste in-game: não desenha nada e as montarias são inventadas. O que
-- ele prova é a ORDEM — que é a única coisa que este addon faz e que os outros não fazem.
-- Se a regra de faixa quebrar, quebra aqui, em disco, e não depois de o jogador abrir a
-- janela e ver uma montaria de 1/2000 no topo. Este arquivo NÃO entra no .toc.

local ADDON = "RocketMount"

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
Minimap = widget("Minimap")
UISpecialFrames = {}
SlashCmdList = {}
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }

function CreateFrame(kind) return widget(kind) end
-- O harness roda em enUS: o `Locales/ptBR.lua` sai na primeira linha, e as conferencias abaixo
-- leem o texto das CHAVES, que sao o ingles. Trocar para "ptBR" aqui faria o addon carregar
-- traduzido -- util para conferir uma traducao longa demais, e por isso a funcao existe em vez
-- de a string estar cravada nos dois lugares.
function GetLocale() return "enUS" end
function UnitFactionGroup() return "Alliance" end
function UnitName(u)
    -- Com unidade falsa montada, responde o nome dela; sem ela, o personagem.
    -- "player" e sempre o personagem: o registro de saque e por personagem, e com a unidade
    -- montada ele saia no nome do raro.
    if u and u ~= "player" and UNIDADE and UNIDADE.nome then return UNIDADE.nome end
    return "Hamfarir"
end
function GetRealmName() return "Azralon" end

-- As globais de requisito vem do CLIENTE, e o addon monta os padroes a partir delas. O stub usa
-- o texto em INGLES de proposito: se o codigo tivesse "Requer" cravado, passaria aqui e quebraria
-- em todo cliente que nao e ptBR.
ITEM_REQ_REPUTATION = "Requires %s - %s"
ITEM_REQ_SKILL = "Requires %s"
ITEM_MIN_LEVEL = "Requires Level %d"

Enum = Enum or {}
Enum.TooltipDataLineType = { UsageRequirement = 12 }

-- O tooltip de cada item, como o jogo entrega: linhas com texto, tipo e cor. Vermelho e como o
-- jogo diz "voce nao cumpre isto".
local TOOLTIPS = {
    -- O caso da Fenix Negra: o catalogo so sabe o preco, e o TOOLTIP sabe da conquista.
    [7015] = { lines = {
        { leftText = "Reins of the Dark Phoenix" },
        { leftText = "Requires Guild Glory of the Cataclysm Raider", type = 12,
          leftColor = { r = 1, g = 0.125, b = 0.125 } },
    } },
    -- Um item cujo requisito o jogador CUMPRE: o jogo nao pinta de vermelho.
    [7016] = { lines = {
        { leftText = "Requires Level 10", type = 12,
          leftColor = { r = 1, g = 1, b = 1 } },
    } },
    -- (!) SEM O CAMPO `type`: aqui so o TEXTO identifica o requisito, e ele so e identificado se
    -- o padrao tiver saido da global do cliente. Com "Requer %s - %s" cravado em portugues, esta
    -- linha em ingles passaria batida -- que e o defeito que quebraria o addon para todo mundo
    -- fora do Brasil, e em silencio.
    [7017] = { lines = {
        { leftText = "Requires Maruuk Centaur - Exalted",
          leftColor = { r = 1, g = 0.125, b = 0.125 } },
    } },
}

C_TooltipInfo = {
    GetItemByID = function(id) return TOOLTIPS[id] end,
}
function UnitClass() return "Death Knight", "DEATHKNIGHT" end
function time() return 1758500000 end
function GetCursorPosition() return 0, 0 end
function IsShiftKeyDown() return false end
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
-- ONDE O JOGADOR ESTA, e o teste mexe nisso a vontade: a guarda de zona e o que separa "o raro
-- esta na sua frente" de "alguem com esse nome existe em algum lugar do mundo".
MAPA_DO_JOGADOR = 23
C_Map = {
    GetMapInfo = function(id) return { name = "Zona " .. id } end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function() end,
    GetBestMapForUnit = function() return MAPA_DO_JOGADOR end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m = m, x = x, y = y } end }

-- A UNIDADE FALSA. O addon so aceita como raro o que tem GUID de criatura E classificacao de
-- raro -- as duas guardas do SilverDragon --, entao o teste precisa poder montar cada caso:
-- o raro de verdade, o pet de jogador com o nome do raro, e o bicho comum.
UNIDADE = { existe = false }
function UnitExists(u) return UNIDADE.existe and u ~= nil end
function UnitIsPlayer() return UNIDADE.jogador == true end
function UnitIsDead() return UNIDADE.morto == true end
function UnitGUID() return UNIDADE.guid end
function UnitClassification() return UNIDADE.classe end

-- O RELOGIO, porque sem ele o intervalo de repeticao era sempre `0 - 0` e o teste de "nao
-- repete" passava por acidente, medindo nada. Com o tempo controlavel da para provar as duas
-- metades da regra: cala dentro do intervalo, volta a falar depois dele.
TEMPO = 1000
function GetTime() return TEMPO end

VINHETAS = {}
C_VignetteInfo = {
    GetVignettes = function() return VINHETAS end,
    GetVignetteInfo = function(g) return g end,
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
-- (!) O CAMINHO DAS CONQUISTAS, como o jogo entrega: categorias, e por categoria as conquistas,
-- e por conquista o TEXTO DA RECOMPENSA. E ele que liga conquista a montaria sem ninguem curar.
local CATEGORIAS = { 91 }
local CONQUISTAS = {
    [91] = {
        -- A que da a montaria "Metodo a parte": e o caso do Corcel de Guerra Prestigioso, que o
        -- catalogo marca SPECIAL e sobre o qual nao sabe mais nada.
        { id = 8008, reward = "Montaria: Metodo a parte" },
        { id = 8009, reward = "Titulo: Nada a ver" },
    },
}
function GetCategoryList() return CATEGORIAS end
function GetCategoryNumAchievements(cat) return #(CONQUISTAS[cat] or {}) end
function GetAchievementReward(id)
    for _, lista in pairs(CONQUISTAS) do
        for _, a in ipairs(lista) do
            if a.id == id then return a.reward end
        end
    end
end

function GetAchievementInfo(a, b)
    -- Duas assinaturas, como no jogo: (categoria, indice) devolve o id; (id) devolve os dados.
    if b then
        local lista = CONQUISTAS and CONQUISTAS[a]
        local entrada = lista and lista[b]
        return entrada and entrada.id
    end
    -- A 8008 e a conquista do "Metodo a parte", e ela NAO esta concluida.
    return a, "Conquista " .. a, 10, false
end

-- Missoes: a 500 esta feita, a 501 nao. `IsQuestFlaggedCompletedOnAccount` responde pela conta,
-- e ela dizer "sim" NAO cumpre o requisito -- a montaria e deste personagem.
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return id == 500 end,
    IsQuestFlaggedCompletedOnAccount = function(id) return id == 500 or id == 501 end,
    GetTitleForQuestID = function(id) return "Missao traduzida " .. id end,
    RequestLoadQuestByID = function() end,
}

MCL_GUIDE_QUEST_DATA = {
    [25] = { quest = "Grand Gryphon", questId = 501, npc = "Aviana", zone = "Vale Sombrio" },
    [26] = { quest = "Ja fiz essa",   questId = 500, npc = "Alguem", zone = "Algum lugar" },
}
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
    -- O caso relatado em 21/09: reputação CUMPRIDA, mas a montaria cai de baú a 1 em 3.
    -- Aparecia em primeiro com "100%". Requisito cumprido não é montaria no bolso.
    { 11, 1011, "Bau com reputacao pronta", 1, false },
    -- E o inverso: queda cuja reputação ainda NÃO libera a tentativa. É o pior dos dois
    -- mundos e tem que cair no fim, não no meio dos farms que já dá para tentar.
    { 12, 1012, "Queda ainda trancada",     1, false },
    -- Dois requisitos ao mesmo tempo: reputação cumprida e moeda a 30%. Quem manda é o
    -- que está MAIS ATRASADO. Sem este caso, trocar o mínimo pelo máximo passava batido.
    { 13, 1013, "Dois requisitos",          3, false },
    -- Queda cuja FONTE não é "Queda" — baú de paração entra no diário como vendedor. Aqui
    -- a única prova de que há sorte no meio é a taxa. Sem este caso, ignorar a taxa na
    -- checagem de determinismo passava batido, que é exatamente o defeito relatado.
    { 14, 1014, "Bau fora do tipo queda",   3, false },
    -- (!) O DEFEITO DE 22/09: o catalogo diz que ha requisito de reputacao, mas a API nao
    -- responde por essa faccao -- e ela nao responde justamente quando o personagem NUNCA a
    -- encontrou, que e o caso em que a montaria esta mais longe. A versao anterior lia esse
    -- silencio como "nao ha requisito" e mandava a montaria para perto do topo.
    { 17, 1017, "Rep que nunca vi",        3, false },
    -- Vendedor COMUM, so ouro, sem guilda: e este que pertence a faixa de "exige mais que o
    -- preco" -- nao ha requisito conhecido, mas tambem nao ha um bloqueio nomeado.
    { 18, 1018, "So ouro, sem guilda",      3, false },
    -- Especifica de faccao: ate agora isso so servia para ESCONDER, e esconder nao e informar.
    { 19, 1019, "So da Alianca",            3, false, 1 },
    -- E uma so da HORDA: sem ela, o filtro "minha" (Alianca aqui) nao tinha o que excluir, e o
    -- teste dele passava com a regra desligada.
    { 20, 1020, "So da Horda",              3, false, 0 },
    -- (!) SAIU DO JOGO: promocao encerrada, card game, conquista aposentada. O addon lia a marca
    -- do MCL desde a primeira versao e nunca a usava -- elas eram ranqueadas junto com as que da
    -- para pegar, numa lista cujo assunto e "por onde comecar".
    { 21, 1021, "Saiu do jogo",             8, false },
    -- (!) O CASO DO PORTADOR DA TRILHA-PRADO (relatado em 22/09). Ele pede renome 5 com os
    -- Centauros Maruuk -- que o jogador tem de sobra (25) -- e depois cai a 1 em 20 do bau da
    -- Cacada Grandiosa. Aparecia ACIMA de uma de 1 em 3, porque a regra antiga ordenava por
    -- requisito, e "cumprido" ganhava de "desconhecido". Requisito cumprido nao e progresso rumo
    -- a montaria: ele so abre a porta.
    { 22, 1022, "Renome cumprido, 1 em 20", 1, false },
    -- (!) DOIS REQUISITOS FALTANDO AO MESMO TEMPO (relatado em 22/09): *"falta cristal de
    -- ressonancia mas que tambem falta reputacao"*. A tela mostrava so o mais atrasado, entao
    -- quem lia ia farmar a moeda e descobria a reputacao no vendedor.
    { 23, 1023, "Moeda E reputacao",        3, false },
    -- (!) O CASO DA FENIX NEGRA RESOLVIDO PELO TOOLTIP: o catalogo so sabe o preco, e o jogo
    -- sabe da conquista de guilda. E a alternativa a curar uma base a mao -- dado da Blizzard,
    -- ja traduzido, e certo depois do proximo patch tambem.
    { 24, 1024, "So o tooltip sabe",        3, false },
    -- (!) MISSAO NAO CONCLUIDA (perguntado em 22/09 sobre o Grande Grifo): "se falta missao, nao
    -- da para ir pegar, correto?". Correto -- e ate agora a tela nao dizia nem que havia missao,
    -- porque o addon ignorava a tabela de missoes do catalogo inteira.
    { 25, 1025, "Missao pendente",         2, false },
    { 26, 1026, "Missao ja feita",         2, false },
    -- (!) O CORCEL DE GUERRA PRESTIGIOSO (relatado em 22/09): o catalogo so sabe
    -- `method = "SPECIAL"` e o item; o tooltip do item so tem "Requer nivel 10", que o jogador
    -- cumpre. Aparecia como "e so ir pegar" -- mas ela vem de uma conquista que nada disso
    -- menciona. Sao 126 montarias marcadas SPECIAL no catalogo.
    { 27, 1027, "Metodo a parte",          0, false },
    -- O caso da Fenix Negra (21/09): o catalogo sabe SO o preco. O jogador tem o ouro, e a
    -- versao anterior concluia "e so ir pegar" -- mas ela exige guilda Exaltada mais uma
    -- conquista de guilda, e disso nao ha uma linha no dado que este addon le.
    { 15, 1015, "So sei o preco",           3, false },
    -- E o contraste: mesma fonte, mesmo preco, mas com acesso CONHECIDO e cumprido.
    { 16, 1016, "Preco e acesso conhecido", 3, false },
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
    -- 9001 e 9003 valem para a conta; 9002 e so deste personagem. A diferenca muda o que o
    -- jogador tem que fazer, e era justamente ela que a tela nao dizia.
    IsAccountWideReputation = function(fid) return fid == 9001 or fid == 9003 end,
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
C_MajorFactions = {
    -- O jogador esta em renome 25 na faccao 9001: bem acima do 5 que a montaria pede.
    GetMajorFactionRenownInfo = function(fid)
        if fid == 9001 then return { renownLevel = 25 } end
        return nil
    end,
}

-- O catálogo do MCL, com só o que o addon lê dele.
MCL_GUIDE = {
    ready = true,
    mountLookup = {
        [1001] = { rep = { factionId = 9001, factionName = "Faccao pronta", levelName = "Exalted" } },
        [1002] = { rep = { factionId = 9002, factionName = "Faccao quase", levelName = "Exalted" } },
        [1003] = { achievementId = 555 },
        [1004] = { chance = 100, method = "NPC", lockBossName = "Bicho",
        -- `n` e `v` reproduzem o registro real do MCL: nome do raro no pin e o id da
        -- vinheta. O "Rhazul" e o caso de 22/09 -- raro de verdade, mapa 23, e o aviso
        -- disparando com o jogador em outra zona.
        -- `dq` e a missao diaria oculta do raro, como no MCL de verdade (Pterrock: 92191).
        coords = { { m = 23, x = 26.8, y = 11.6, n = "Rhazul", v = 5555, dq = 92191 } } },
        [1005] = { chance = 2000, method = "BOSS", lockBossName = "Chefe" },
        [1009] = { rep = { factionId = 9003, factionName = "Faccao mais perto", levelName = "Exalted" } },
        [1010] = { chance = 50, method = "NPC" },
        [1011] = { chance = 3, method = "USE",
                   rep = { factionId = 9001, factionName = "Faccao pronta", levelName = "Exalted" } },
        [1012] = { chance = 3, method = "USE",
                   rep = { factionId = 9002, factionName = "Faccao quase", levelName = "Exalted" } },
        [1013] = { rep = { factionId = 9001, factionName = "Faccao pronta", levelName = "Exalted" } },
        [1014] = { chance = 3, method = "USE" },
        [1015] = { vendorInfo = { npc = "Guild Vendors", zone = "" } },
        [1017] = { rep = { factionId = 9999, factionName = "Faccao que nunca vi",
                           levelName = "Exalted" } },
        [1018] = { vendorInfo = { npc = "Katie Stokx", zone = "Cidade", m = 1519, x = 77, y = 67 } },
        [1019] = { vendorInfo = { npc = "Katie Stokx", zone = "Cidade", m = 1519, x = 77, y = 67 } },
        [1020] = { vendorInfo = { npc = "Ogunaro", zone = "Orgrimmar", m = 85, x = 61, y = 35 } },
        [1021] = { isUnobtainable = true, chance = 100, lockBossName = "Chefe sumido" },
        [1023] = { rep = { factionId = 9002, factionName = "Faccao quase", levelName = "Exalted" } },
        [1025] = {}, [1026] = {},
        [1027] = { method = "SPECIAL", itemId = 7016 },
        [1024] = { itemId = 7015, vendorInfo = { npc = "Katie Stokx", zone = "Cidade", m = 1519, x = 77, y = 67 } },
        [1022] = { chance = 20, method = "Grand Hunt",
                   rep = { factionId = 9001, factionName = "Maruuk", renown = true, level = 5 } },
        [1016] = { rep = { factionId = 9001, factionName = "Faccao pronta", levelName = "Exalted" },
                   vendorInfo = { npc = "Katie Stokx", zone = "Cidade", m = 1519, x = 77, y = 67 } },
    },
}
-- As faccoes que alguma montaria pede: e desta tabela que o `Roster` tira o que anotar. Sem ela
-- ele nao anota nada, e todo teste sobre o livro-caixa passa por vazio.
MCL_GUIDE_REP_DATA = {
    [1002] = { { factionId = 9002, factionName = "Faccao quase", levelName = "Exalted" } },
    [1017] = { { factionId = 9999, factionName = "Faccao que nunca vi", levelName = "Exalted" } },
}

MCL_GUIDE_CURRENCY_DATA = {
    -- 300 no bolso (ver GetCurrencyInfo) de 1000 = 30%.
    [1013] = { { type = "currency", id = 77, amount = 1000 } },
    -- Preco que o jogador cobre de sobra, nos dois casos.
    [1015] = { { type = "gold", id = 0, amount = 1000 } },
    [1017] = { { type = "gold", id = 0, amount = 1000 } },
    [1018] = { { type = "gold", id = 0, amount = 1000 } },
    -- 300 no bolso de 1000: 30%. A reputacao dessa esta em 80%, entao a moeda e a mais atrasada
    -- -- e era so ela que aparecia.
    [1023] = { { type = "currency", id = 77, amount = 1000 } },
    [1024] = { { type = "gold", id = 0, amount = 1000 } },
    [1019] = { { type = "gold", id = 0, amount = 1000 } },
    [1020] = { { type = "gold", id = 0, amount = 1000 } },
    [1016] = { { type = "gold", id = 0, amount = 1000 } },
}

LibStub = function() return nil end

--------------------------------------------------------------------------------
-- Carrega o addon
--------------------------------------------------------------------------------
local ns = {}
-- (!) A LISTA VEM DO `.toc`, e nao cravada aqui. Ela ja esteve cravada, e o preco apareceu na
-- primeira vez que um arquivo novo entrou no addon: o `Roster.lua` foi para o `.toc`, o jogo
-- passou a carrega-lo e o harness NAO -- entao o teste rodava contra um addon que nao existe.
-- Ler o `.toc` faz o simulador carregar exatamente o que o jogo carrega, e na mesma ordem.
local FILES = {}
for line in io.lines(ADDON .. ".toc") do
    line = line:gsub("%s+$", "")
    if line:match("%.lua$") and not line:match("^#") then
        FILES[#FILES + 1] = line:gsub("\\", "/")
    end
end

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
check("sobram as vinte e quatro que faltam", #ranked, 24)

check("reputacao cumprida = Pronto para pegar",
    porNome["Pronta por reputacao"].e.tier, ns.TIER.READY)
check("reputacao a 80% = Quase liberado",
    porNome["Quase la por reputacao"].e.tier, ns.TIER.CLOSE)
check("conquista a 50% = Requisito em andamento",
    porNome["Metade da conquista"].e.tier, ns.TIER.UNDERWAY)
check("queda de 1/100 = Farm curto",
    porNome["Farm curto"].e.tier, ns.TIER.SHORTFARM)
check("queda de 1/2000 = Caminho longo",
    porNome["Farm longo"].e.tier, ns.TIER.LONGFARM)
check("sem dado nenhum = Sem estimativa",
    porNome["Sem estimativa"].e.tier, ns.TIER.UNKNOWN)

-- A ordem é o produto. Trava ela inteira, não uma posição isolada: uma regra nova que
-- desloque duas montarias de lugar tem que reprovar aqui.
local ordemEsperada = {
    -- As duas que valem "e so ir pegar": acesso conhecido E cumprido.
    -- A de missao ja feita entra junto das prontas: requisito cumprido e requisito cumprido.
    "Missao ja feita", "Preco e acesso conhecido", "Pronta por reputacao",
    -- Dentro da faixa, quem andou mais caminho vem antes: 95% na frente de 80%.
    "Quase la com mais rep", "Quase la por reputacao",
    "Metade da conquista", "Dois requisitos", "Moeda E reputacao",
    -- No farm, primeiro quem ja esta liberado e, entre os liberados, a chance mais generosa.
    "Bau com reputacao pronta", "Bau fora do tipo queda",
    -- A de 1 em 20 com renome CUMPRIDO fica ABAIXO das de 1 em 3 sem requisito conhecido:
    -- requisito cumprido abre a porta, nao anda o caminho.
    "Renome cumprido, 1 em 20",
    "Farm curto mais raro", "Farm curto",
    "Queda ainda trancada",
    -- (!) E SO ENTAO a de preco-so. Ela ja esteve em TERCEIRO, logo abaixo de "e so ir pegar",
    -- e isso fazia a lista recomendar justamente o que ela nao consegue avaliar. Posicao e
    -- recomendacao: "eu nao sei" pertence ao fim, ao lado de "sem estimativa".
    -- A reputacao que a API nao le entra como NAO cumprida (0%), e nao como ausente: por isso
    -- ela cai aqui embaixo, e nao la em cima junto das que dao para comprar.
    -- Requisito conhecido e NAO cumprido (0%) vem antes de requisito que nao da para medir:
    -- saber o que falta vale mais que nao saber nada.
    -- As tres com requisito conhecido e NAO cumprido, antes das que ninguem sabe medir.
    -- Requisito conhecido e NAO cumprido, em ordem alfabetica de nome no empate de 0%.
    -- (!) "Metodo a parte" ESTAVA AQUI EMBAIXO, ao lado de "Sem estimativa", porque o catalogo
    -- so dizia `SPECIAL`. `Achievements.lua` le do jogo que ela vem de uma conquista NAO
    -- concluida, e com isso ela vira requisito conhecido e nao cumprido -- 0%, como as outras
    -- deste grupo, em ordem alfabetica. Subiu de lugar por saber MAIS, e nao por estar perto.
    "Metodo a parte",
    "Missao pendente", "Rep que nunca vi", "So o tooltip sabe", "So sei o preco", "Farm longo",
    "So da Alianca", "So ouro, sem guilda",
    "Sem estimativa",
    -- Por ultimo, e so quando pedida: nao e dificil, e impossivel.
    "Saiu do jogo",
}
for i, nome in ipairs(ordemEsperada) do
    check("posicao " .. i, ranked[i] and ranked[i].name, nome)
end

-- ⚑ O DEFEITO DA FENIX NEGRA (relatado em 21/09): "so sei o preco" nao e "pode pegar".
local soPreco = porNome["So sei o preco"].e
check("so com preco NAO e 'e so ir pegar'", soPreco.tier ~= ns.TIER.READY, true)
-- (!) A F958NIX NEGRA e de vendedor de GUILDA, e isso e um bloqueio NOMEADO, nao uma
-- duvida: pesquisado na wiki em 22/09, todas exigem guilda Exaltada e a maioria uma conquista
-- DE GUILDA. Entao ela nao fica na faixa de "requisito desconhecido" -- ela cai no caminho longo.
check("vendedor de guilda cai no caminho longo", soPreco.tier, ns.TIER.LONGFARM)
-- (!) O NUMERO DA DIREITA E O PRECO, e nao um veredito. "preco ok" foi reprovado pelo usuario
-- em 22/09: parecia um "pode ir" com outro nome, que e exatamente o que esta faixa existe para
-- NAO dizer. Preco e informacao; quem le decide.
local soOuro = porNome["So ouro, sem guilda"].e
check("vendedor comum sem requisito conhecido fica em 'exige mais que o preco'",
    soOuro.tier, ns.TIER.CHECK)
check("o numero da direita e o preco", soOuro.headline, soOuro.cost.price)
check("  e nao um veredito", soOuro.headline:find("ok", 1, true), nil)
check("a linha avisa que pode haver mais",
    soOuro.why:find("cannot read", 1, true) ~= nil, true)
-- E QUANDO O VENDEDOR E DE GUILDA, a ressalva deixa de ser generica e ganha nome: toda montaria
-- de vendedor de guilda exige reputacao com a guilda mais uma conquista DE GUILDA.
check("vendedor de guilda e reconhecido", soPreco.vendorGuilda, true)
check("  e a linha nomeia o bloqueio",
    soPreco.why:find("guild", 1, true) ~= nil, true)
check("vendedor sem coordenada fica marcado como vago", soPreco.vendorVago, true)
check("e a faixa de preco-so fica NO FIM, nao perto do topo",
    ns.TIER.CHECK > ns.TIER.LONGFARM, true)

local comAcesso = porNome["Preco e acesso conhecido"].e
check("com acesso conhecido e cumprido, ai sim e pronto", comAcesso.tier, ns.TIER.READY)
check("e ele diz 'ready to grab'", comAcesso.headline, "ready to grab")
check("vendedor com coordenada nao e vago", comAcesso.vendorVago, false)

-- (!) REQUISITO QUE NAO DA PARA LER E REQUISITO NAO CUMPRIDO (defeito de 22/09).
--
-- `GetFactionDataByID` nao responde por uma faccao que o personagem NUNCA encontrou -- que e
-- exatamente o caso em que a montaria esta mais longe. Ler esse silencio como "nao ha requisito"
-- fazia a montaria subir para perto do topo: quanto menos o addon sabia, melhor ela parecia.
local nuncaVi = porNome["Rep que nunca vi"].e
check("reputacao ilegivel NAO vira 'nada a cumprir'", nuncaVi.access, 0)
check("  e a montaria NAO sobe para o topo", nuncaVi.tier ~= ns.TIER.READY, true)
check("  nem fica na faixa de so-preco", nuncaVi.tier ~= ns.TIER.CHECK, true)
check("  e a linha diz o que houve", nuncaVi.rep.label:find("reputation", 1, true) ~= nil, true)

-- (!) O CORCEL DE GUERRA PRESTIGIOSO: "SPECIAL" E O CATALOGO DIZENDO QUE NAO SABE (22/09).
local aParte = porNome["Metodo a parte"].e
check("metodo 'SPECIAL' nao vira aquisicao deterministica", aParte.deterministic, false)
check("  e a montaria NAO aparece como pronta", aParte.tier ~= ns.TIER.READY, true)
-- Ela ja caiu em "sem estimativa", que era o certo enquanto o addon nao sabia nada dela. Agora
-- a conquista e um requisito conhecido e nao cumprido, e o lugar disso e a faixa de farm longo,
-- com as outras de 0%. O que NAO pode mudar e o de baixo: ela nunca volta para o topo.
check("  ela cai na faixa de requisito nao cumprido", aParte.tier, ns.TIER.LONGFARM)
check("  e o que a segura e a conquista", aParte.achievementReward ~= nil, true)
check("  e o tooltip cumprido nao a promoveu", aParte.tooltipGate, nil)

-- (!) MISSAO: O CATALOGO TINHA O DADO E O ADDON IGNORAVA (22/09).
local pendente = porNome["Missao pendente"].e
local feita = porNome["Missao ja feita"].e
check("missao vira requisito", pendente.quest ~= nil, true)
check("  nao concluida = 0", pendente.quest.pct, 0)
check("  e o nome vem TRADUZIDO do jogo, nao do catalogo em ingles",
    pendente.quest.titulo:find("traduzida", 1, true) ~= nil, true)
check("  e a linha diz onde pegar", pendente.quest.label:find("Aviana", 1, true) ~= nil, true)
check("missao concluida = 1", feita.quest.pct, 1)

-- (!) FEITA EM OUTRO PERSONAGEM NAO CUMPRE: a montaria e deste. Mas dizer que outro ja fez e
-- informacao util -- evita o jogador procurar uma missao que ele nao consegue mais pegar.
check("feita na conta nao cumpre neste personagem", pendente.quest.pct, 0)
check("  mas a linha avisa que outro ja fez",
    pendente.quest.label:find("another character", 1, true) ~= nil, true)

-- (!) O TOOLTIP DO ITEM FECHA O BURACO DO CATALOGO (22/09).
--
-- Antes: catalogo so sabe o preco -> "exige mais que o preco", sem dizer o que. Agora o jogo
-- diz, em texto proprio e ja traduzido: "Requires Guild Glory of the Cataclysm Raider".
local soTooltip = porNome["So o tooltip sabe"].e
check("o tooltip vira requisito de acesso", soTooltip.tooltipGate ~= nil, true)
check("  e ele conta como NAO cumprido", soTooltip.tooltipGate.pct, 0)
check("  entao a montaria nao fica em 'exige mais que o preco'",
    soTooltip.tier ~= ns.TIER.CHECK, true)
check("  e a linha diz o que o JOGO disse",
    soTooltip.tooltipGate.label:find("Guild Glory", 1, true) ~= nil, true)

-- (!) OS PADROES SAIEM DAS GLOBAIS DO CLIENTE, e nao de uma lista em portugues: o stub usa o
-- texto em ingles, e casar com ele prova que nada foi cravado no idioma errado.
local cumprido = ns.Tooltip.Gate(7016)
-- (!) O TOOLTIP SO SERVE COMO SINAL NEGATIVO (defeito do Corcel de Guerra Prestigioso, 22/09).
--
-- Ele ja devolveu `pct = 1` quando nada estava vermelho, e isso mandou para o topo uma montaria
-- que vem de conquista que o tooltip nem menciona -- o item so trazia um "Requer nivel 10" que o
-- jogador cumpre. Nada bloqueando NAO e prova de que da para pegar.
check("nada bloqueando no tooltip nao vira acesso liberado", cumprido, nil)
check("item sem tooltip nao inventa requisito", ns.Tooltip.Gate(999999), nil)

-- Linha SEM o campo `type`: so o texto a identifica, e so se o padrao veio da global do cliente.
local soTexto = ns.Tooltip.Gate(7017)
check("requisito reconhecido pelo TEXTO da global", soTexto ~= nil, true)
check("  e ele nao esta cumprido", soTexto and soTexto.pct, 0)
check("  e a frase e a do jogo",
    soTexto and soTexto.label:find("Maruuk", 1, true) ~= nil, true)

-- (!) DOIS REQUISITOS FALTANDO: OS DOIS APARECEM (defeito de 22/09).
local dois2 = porNome["Moeda E reputacao"].e
check("o addon guarda os dois requisitos", #dois2.requisitos, 2)
check("  e conta quantos faltam", dois2.faltando, 2)
check("  a linha avisa que ha mais de um", dois2.why:find("1 more", 1, true) ~= nil, true)
-- O `min` continua decidindo a FAIXA -- o mais atrasado e que diz o quanto falta --, mas nao
-- e mais ele sozinho que a tela mostra.
check("  e a faixa ainda sai do mais atrasado", dois2.requirement, 0.3)

-- E quando esta tudo cumprido, a ficha diz isso em vez de listar faltas que nao existem.
local prontaTudo = porNome["Preco e acesso conhecido"].e
check("com tudo cumprido, nada falta", prontaTudo.faltando, 0)

-- (!) MONTARIA QUE SAIU DO JOGO NAO ENTRA NA LISTA (defeito de 22/09). O addon lia a marca do
-- MCL desde a primeira versao e NUNCA a usava: promocao encerrada e card game eram ranqueados
-- junto com o que da para pegar, numa lista cujo assunto e "por onde comecar".
local sumida = porNome["Saiu do jogo"].e
check("o ranqueamento a marca como sumida", sumida.tier, ns.TIER.GONE)
check("  e nao inventa numero para ela", sumida.headline, "—")
-- Ela tem chance de 1/100, que a poria em "farm curto" se a marca fosse ignorada: este check
-- existe para provar que a marca MANDA MAIS que a chance.
check("  mesmo com chance boa, a marca manda mais", sumida.tier ~= ns.TIER.SHORTFARM, true)

ns.db.showUnobtainable = false
local function TemSumida()
    for _, e in ipairs((ns.GetFiltered())) do
        if e.name == "Saiu do jogo" then return true end
    end
    return false
end
check("por padrao ela fica FORA da lista", TemSumida(), false)
ns.db.showUnobtainable = true
check("  e aparece quando o jogador pede", TemSumida(), true)
ns.db.showUnobtainable = false


-- ⚑ DE QUEM E A REPUTACAO (relatado em 21/09: "qual char tem essa reputacao?")
check("reputacao de conta se identifica como tal",
    comAcesso.rep.label:find("account-wide", 1, true) ~= nil, true)
local doChar = porNome["Quase la por reputacao"].e
check("reputacao de personagem diz o NOME do personagem",
    doChar.rep.label:find("Hamfarir") ~= nil, true)

-- ⚑ O defeito relatado em 21/09, travado: requisito cumprido com queda no meio NÃO é pronto.
local bau = porNome["Bau com reputacao pronta"].e
check("baú com reputacao pronta NAO e 'Pronto para pegar'", bau.tier ~= ns.TIER.READY, true)
check("baú com reputacao pronta cai em Farm curto", bau.tier, ns.TIER.SHORTFARM)
check("e o numero da linha e a QUEDA, nao o requisito", bau.headline, "1/3")
check("o requisito cumprido nao vira 100%", bau.headline ~= "100%", true)

local dois = porNome["Dois requisitos"].e
check("com dois requisitos vale o mais atrasado", dois.headline, "30%")

-- (!) PRECO E FALTA SAO DUAS COISAS, e nunca o mesmo texto. A versao anterior escrevia
-- "300 de 1000" numa string so, e o usuario chamou de confuso com razao: para saber o preco era
-- preciso primeiro descobrir qual dos dois numeros era o preco.
check("o preco diz quanto CUSTA", dois.cost.price:find("1000", 1, true) ~= nil, true)
check("  e nao quanto eu tenho", dois.cost.price:find("300", 1, true), nil)
check("a falta diz quanto FALTA", dois.cost.gap:find("700", 1, true) ~= nil, true)
check("  e preco e falta sao campos separados", dois.cost.price ~= dois.cost.gap, true)

-- E quem ja pode pagar nao tem falta nenhuma: o campo some, em vez de escrever "faltam 0".
check("quem pode pagar nao tem falta", soOuro.cost.gap, nil)
check("e ele nao entra em 'Pronto para pegar'", dois.tier, ns.TIER.UNDERWAY)

local foraDoTipo = porNome["Bau fora do tipo queda"].e
check("taxa de queda basta para nao ser deterministica", foraDoTipo.deterministic, false)
check("mesmo a fonte sendo vendedor, ela cai no farm", foraDoTipo.tier, ns.TIER.SHORTFARM)
check("e mostra a queda, nao 'pode pegar'", foraDoTipo.headline, "1/3")

local trancada = porNome["Queda ainda trancada"].e
check("queda ainda trancada cai no fim", trancada.tier, ns.TIER.LONGFARM)
check("e a linha dela diz o que falta liberar",
    trancada.why:find("Not unlocked", 1, true) ~= nil, true)

-- Só aquisição determinística pode dizer "pode pegar".
local prontos = 0
for _, e in ipairs(ranked) do
    if e.headline == "ready to grab" then
        prontos = prontos + 1
        check("  '" .. e.name .. "' e mesmo deterministica", e.deterministic, true)
    end
end
check("alguma montaria chega a 'pode pegar'", prontos > 0, true)

-- Nenhuma linha pode mostrar porcentagem quando a sorte decide.
local pctOndeNaoDeve = 0
for _, e in ipairs(ranked) do
    if not e.deterministic and e.headline:find("%%") and not e.headline:find("t95xm") then
        pctOndeNaoDeve = pctOndeNaoDeve + 1
    end
end
check("nenhuma queda se anuncia em porcentagem", pctOndeNaoDeve, 0)

-- A faixa nunca pode ficar fora de ordem, seja qual for a regra que a produziu.
local crescente = true
for i = 2, #ranked do
    if ranked[i].tier < ranked[i - 1].tier then crescente = false end
end
check("as faixas saem em ordem crescente", crescente, true)

-- O numero que a linha mostra tem que ser o que justificou a faixa.
check("Pronto mostra 'ready to grab', nao 100%",
    porNome["Pronta por reputacao"].e.headline, "ready to grab")
check("Quase liberado mostra 80%", porNome["Quase la por reputacao"].e.headline, "80%")
check("Conquista mostra 50%", porNome["Metade da conquista"].e.headline, "50%")
check("Farm curto mostra a queda", porNome["Farm curto"].e.headline, "1/100")
check("Sem estimativa nao inventa numero", porNome["Sem estimativa"].e.headline, "—")

-- Sem catalogo nenhum o addon nao pode quebrar: ele so perde a taxa de queda.
-- Sem o MCL somem os DOIS globais dele, não só o `MCL_GUIDE`: a tabela de moeda é
-- separada, e deixar ela de pé fingia uma instalação que não existe.
local guardado, guardadaMoeda = MCL_GUIDE, MCL_GUIDE_CURRENCY_DATA
MCL_GUIDE, MCL_GUIDE_CURRENCY_DATA = nil, nil
ns.Invalidate()
local semMCL = ns.GetRanked(true)
check("sem o MCL a lista continua de pe", #semMCL, 24)
-- (!) "TUDO CAI EM SEM ESTIMATIVA" DEIXOU DE SER VERDADE, e a mudanca e boa: `Achievements.lua`
-- le a conquista do proprio jogo, entao esse requisito sobrevive ao MCL sumir. O que o MCL
-- levava embora era so a TAXA DE QUEDA -- e e isso que este teste tem que travar agora, senao
-- ele passa a medir a moda do dia em vez da dependencia.
local semChance, semSinalPropio = true, true
for _, e in ipairs(semMCL) do
    if e.chance then semChance = false end
    if e.tier ~= ns.TIER.UNKNOWN and not e.achievementReward then semSinalPropio = false end
end
check("e sem ele ninguem tem taxa de queda", semChance, true)
check("e o que sobra de fora do MCL e so o do jogo", semSinalPropio, true)
MCL_GUIDE, MCL_GUIDE_CURRENCY_DATA = guardado, guardadaMoeda
ns.Invalidate()

-- O botao do minimapa: criar e passar o mouse nao pode estourar. A dica dele chama o
-- ranqueamento, entao ela e um caminho de codigo de verdade, nao enfeite.
local btn = ns.CreateMinimapButton()
check("o botao do minimapa nasce", btn ~= nil, true)
local okDica = pcall(function() btn.__scripts.OnEnter(btn) end)
check("a dica do botao monta sem erro", okDica, true)
local okEsconde = pcall(ns.SetMinimapHidden, true)
check("esconder o botao nao estoura", okEsconde, true)
ns.SetMinimapHidden(false)

-- Geometria e aritmetica, e da para conferir em disco. O nome da faixa e a dica dividem
-- a largura da lista; passar do teto nao "quebra", ele corta o texto em silencio.
--
-- Conta LETRAS, nao bytes: o `#` do Lua conta bytes, e em UTF-8 o travessao vale 3 e cada
-- acento vale 2. A primeira versao deste teste reprovou um rotulo de 35 letras por causa
-- disso, e largura de pixel segue a letra, nao o byte.
local function letras(s)
    -- Sem padrao com escape: byte de continuacao UTF-8 fica entre 128 e 191, e
    -- contar por `string.byte` nao depende de acertar o escape no arquivo.
    local n = 0
    for i = 1, #s do
        local b = s:byte(i)
        if b < 128 or b > 191 then n = n + 1 end
    end
    return n
end

-- TODA faixa precisa de nome, dica e COR. A cor ficou de fora quando a faixa "Confira no
-- vendedor" entrou em segundo lugar: as seis cores existentes escorregaram um degrau, a
-- gravidade saiu invertida (farm curto vermelho, caminho longo cinza) e a setima faixa ficou
-- sem cor nenhuma. Ninguem percebe isso lendo codigo; um teste percebe.
for t = 1, 7 do
    check("faixa " .. t .. " tem cor propria", ns.TIER_COLOR[t] ~= nil, true)
end

local TITULO_MAX, DICA_MAX = 36, 36
for t = 1, 7 do
    local nome, dica = ns.TIER_NAME[t], ns.TIER_HINT[t]
    check("nome da faixa " .. t .. " cabe", letras(nome) <= TITULO_MAX, true)
    check("dica da faixa " .. t .. " cabe", letras(dica) <= DICA_MAX, true)
end

-- (!) E A TRADUCAO TAMBEM, e nao so o idioma que o harness carregou.
--
-- O addon roda aqui em enUS, entao as chaves passavam no teto e o ptBR.lua podia crescer a
-- vontade sem ninguem reclamar -- justamente o arquivo onde o acento faz o rotulo ocupar mais
-- pixel por letra. Aqui o arquivo de idioma e lido como DADO: uma tabela vazia no lugar do
-- `ns.L`, e o que ele escrever dentro dela e o que se mede.
local function Traducoes(arquivo)
    local chunk = loadfile(arquivo)
    if not chunk then return nil end
    local fingido = { L = {} }
    local antes = GetLocale
    GetLocale = function() return arquivo:match("([^/]+)%.lua$") end
    local ok = pcall(chunk, ADDON, fingido)
    GetLocale = antes
    if not ok then return nil end
    return fingido.L
end

local ptBR = Traducoes("Locales/ptBR.lua")
check("o ptBR.lua carrega como dado", ptBR ~= nil, true)
if ptBR then
    local maiorNome, maiorDica = 0, 0
    for t = 1, 7 do
        local nome = ptBR[ns.TIER_NAME[t]]
        local dica = ptBR[ns.TIER_HINT[t]]
        check("faixa " .. t .. " tem nome traduzido", nome ~= nil, true)
        check("faixa " .. t .. " tem dica traduzida", dica ~= nil, true)
        if nome then maiorNome = math.max(maiorNome, letras(nome)) end
        if dica then maiorDica = math.max(maiorDica, letras(dica)) end
    end
    check("o nome de faixa mais longo em ptBR cabe", maiorNome <= TITULO_MAX, true)
    check("a dica mais longa em ptBR cabe", maiorDica <= DICA_MAX, true)
end

-- Fumaca da janela: construir e desenhar nao pode estourar.
local okJanela, erroJanela = pcall(ns.ToggleWindow)
check("a janela monta e desenha sem erro", okJanela, true)
if not okJanela then print("      ERRO: " .. tostring(erroJanela)) end

print("")
--------------------------------------------------------------------------------

-- QUEM TEM A REPUTACAO, E O FILTRO DE FACCAO (22/09)
--
-- A API so fala do personagem conectado. A pergunta *"qual personagem meu tem essa reputacao?"*
-- so tem resposta se alguem anotar o que cada um tinha ao entrar -- e e isso que o `Roster` faz,
-- em SavedVariables de conta.
--------------------------------------------------------------------------------
do
    print("")
    print("-- livro-caixa de reputacao e filtro de faccao")

    -- O livro-caixa se escreve com o personagem conectado.
    ns.Roster.Record()
    check("o personagem conectado entra no livro-caixa", ns.Roster.Count(), 1)

    -- E NAO responde sobre si mesmo: a pergunta e sobre os OUTROS. Perguntar e receber o proprio
    -- nome de volta seria pior que nao responder -- o jogador ja sabe em quem esta.
    check("ele anotou as faccoes que alguma montaria pede",
        ns.db.chars["Hamfarir-Azralon"].reps[9002] ~= nil, true)
    -- E NAO responde sobre si mesmo: perguntar "quem tem" e receber o proprio nome de volta
    -- seria pior que nao responder -- o jogador ja sabe em quem esta.
    check("  e nao aparece na resposta sobre os OUTROS", #ns.Roster.WhoHas(9002), 0)

    -- Um alt anotado numa sessao anterior. E o caso que motivou tudo: reputacao legada que
    -- ESTE personagem nao tem, mas outro tem.
    ns.db.chars["Ottozinho-Azralon"] = {
        name = "Ottozinho", realm = "Azralon", faction = "Horde", class = "SHAMAN",
        reps = { [9999] = 8 },      -- Exaltado na faccao que o conectado nunca viu
    }
    check("agora sao dois no livro-caixa", ns.Roster.Count(), 2)

    local quem = ns.Roster.WhoHas(9999, 8)
    check("o livro-caixa acha quem tem a reputacao", #quem, 1)
    check("  e diz o nome", quem[1] and quem[1].name, "Ottozinho")
    check("  e o nivel", quem[1] and quem[1].reaction, 8)

    -- E A LINHA DA MONTARIA PASSA A DIZER ISSO, em vez de "nenhuma reputacao neste personagem".
    ns.Invalidate()
    local lista = ns.GetRanked(true)
    local nuncaVi2
    for _, e in ipairs(lista) do
        if e.name == "Rep que nunca vi" then nuncaVi2 = e end
    end
    check("a montaria aponta o alt que tem", nuncaVi2.rep.outroChar ~= nil, true)
    check("  nomeando ele", nuncaVi2.rep.label:find("Ottozinho", 1, true) ~= nil, true)
    -- MAS CONTINUA NAO CUMPRIDA: quem tem e outro personagem, e a montaria e por personagem.
    check("  e mesmo assim o requisito NAO esta cumprido", nuncaVi2.rep.pct, 0)

    -- O FILTRO DE FACCAO. Com `hideUnavailable` ligado a montaria da outra faccao nem entra na
    -- lista, entao o filtro so tem o que fazer com ele desligado -- que e justamente o modo de
    -- quem esta planejando o outro lado.
    ns.db.hideUnavailable = false
    ns.Invalidate()
    ns.db.factionFilter = nil
    local todas = select(1, ns.GetFiltered())
    ns.db.factionFilter = "Horde"
    local soHorda = select(1, ns.GetFiltered())
    -- (!) OS NUMEROS SAO CONTADOS DA LISTA, e nao supostos. A primeira versao destes checks
    -- assumia "uma da Horda e uma da Alianca" e errou: a fixture ja tinha outra da Horda de
    -- antes. Contar o que existe e imune a fixture crescer.
    local nHorda, nAlianca = 0, 0
    for _, e in ipairs(todas) do
        if e.factionOnly == "Horde" then nHorda = nHorda + 1
        elseif e.factionOnly == "Alliance" then nAlianca = nAlianca + 1 end
    end
    check("a fixture tem montaria dos dois lados", nHorda > 0 and nAlianca > 0, true)

    check("o filtro de Horda tira as da Alianca", #soHorda, #todas - nAlianca)

    ns.db.factionFilter = "Alliance"
    local soAlianca = select(1, ns.GetFiltered())
    check("e o da Alianca tira as da Horda", #soAlianca, #todas - nHorda)

    -- "minha" segue a faccao do PERSONAGEM (Alianca aqui): exclui as da Horda, e so elas.
    ns.db.factionFilter = "mine"
    local minhas = select(1, ns.GetFiltered())
    check("'minha' exclui as da outra faccao", #minhas, #todas - nHorda)
    local temHorda = false
    for _, e in ipairs(minhas) do
        if e.name == "So da Horda" then temHorda = true end
    end
    check("  e a excluida e mesmo a da Horda", temHorda, false)

    ns.db.hideUnavailable = true

    ns.db.factionFilter = nil
    ns.db.chars["Ottozinho-Azralon"] = nil
    ns.Invalidate()
end

--------------------------------------------------------------------------------
-- BUSCA EM TEXTO LIVRE (22/09)
--
-- (!) O EXEMPLO DO USUARIO E O TESTE: *"nao achei a montaria que dropa no Fyrakk"*. A montaria
-- do Fyrakk se chama **Anu'relos, Flame's Guidance** -- "Fyrakk" nao aparece no nome dela em
-- lugar nenhum. Buscar so pelo nome falharia exatamente no caso que motivou a busca.
--------------------------------------------------------------------------------
do
    print("")
    print("-- busca em texto livre")

    ns.db.showUnobtainable = false
    ns.db.factionFilter = nil
    ns.search = nil

    local function Nomes()
        local out = {}
        for _, e in ipairs((ns.GetFiltered())) do out[#out + 1] = e.name end
        return table.concat(out, "|")
    end

    local todas = #select(1, ns.GetFiltered())

    -- Pelo NOME, que e o caso facil.
    ns.search = "farm curto"
    check("acha pelo nome", Nomes():find("Farm curto", 1, true) ~= nil, true)

    -- (!) PELO CHEFE, que e o caso do Fyrakk: o nome do chefe vem do catalogo, nao do nome da
    -- montaria. A fixture tem "Bicho" como chefe da "Farm curto".
    ns.search = "bicho"
    check("acha pelo nome do CHEFE, que nao esta no nome da montaria",
        Nomes(), "Farm curto")

    -- Pelo texto que a Blizzard escreve ("Fonte da montaria N" na fixture).
    ns.search = "fonte da montaria"
    check("acha pelo texto do jogo", #select(1, ns.GetFiltered()) > 1, true)

    -- TODOS os termos tem que bater, e nao um deles: digitar mais tem que estreitar.
    ns.search = "bicho farm"
    local doisTermos = #select(1, ns.GetFiltered())
    ns.search = "bicho"
    local umTermo = #select(1, ns.GetFiltered())
    check("mais termos estreita, nao alarga", doisTermos <= umTermo, true)

    -- Sem acento acha com acento: quem digita "fenix" tem que achar "Fenix".
    check("a dobra tira o acento", ns.Fold("Fênix Negra"), "fenix negra")

    -- Busca vazia devolve tudo.
    ns.search = ""
    check("busca vazia nao filtra nada", #select(1, ns.GetFiltered()), todas)
    ns.search = nil
end


--------------------------------------------------------------------------------
-- AVISO DE BICHO QUE LARGA MONTARIA (22/09)
--
-- (!) NENHUM DADO NOVO FOI PRECISO: o catalogo ja guarda o nome do chefe de cada montaria
-- (`lockBossName`) e o nome nos pins do mapa. Invertendo -- nome -> montarias -- o addon
-- reconhece o bicho no instante em que ele aparece.
--------------------------------------------------------------------------------
do
    print("")
    print("-- aviso de bicho que larga montaria")

    ns.db.showUnobtainable = false
    ns.Sighting.Rebuild()

    local avisos = {}
    local realPrint = ns.Print
    ns.Print = function(...) avisos[#avisos + 1] = table.concat({ ... }, " ") end
    local function limpar() avisos = {} end

    -- (!) O DEFEITO DE 22/09, VIRADO TESTE. Relato com print: o addon anunciou "Rhazul pode
    -- largar ..." com o jogador parado em Luaprata, na tela de login. Rhazul existe e larga
    -- mesmo a montaria -- so que no mapa 23, e o jogador estava em outro lugar. Casar por nome
    -- sem conferir a zona e o que produziu isso.
    MAPA_DO_JOGADOR = 1234
    ns.Sighting.SightName("Rhazul")
    check("nome certo em mapa errado NAO avisa", #avisos, 0)

    MAPA_DO_JOGADOR = 23
    check("  e no mapa certo avisa", ns.Sighting.SightName("Rhazul"), true)
    check("  dizendo qual montaria", avisos[1]:find("Farm curto", 1, true) ~= nil, true)

    -- A SETA APONTA PARA O RARO, e nao para os pes do jogador -- o outro erro do mesmo relato.
    -- O link carrega a coordenada do catalogo (mapa 23, 26.8, 11.6), em decimos de milesimo.
    check("  e o link aponta para o mapa do raro",
        avisos[1]:find("rocketmount:23:2680:1160", 1, true) ~= nil, true)

    limpar()
    ns.Sighting.SightName("Rhazul")
    check("nao repete o mesmo raro dentro do intervalo", #avisos, 0)

    -- E VOLTA A FALAR DEPOIS DELE. Sem esta metade, "nao repete" seria satisfeito por um addon
    -- que simplesmente nunca mais avisa -- que e defeito, nao silencio educado.
    TEMPO = TEMPO + 601
    check("  e avisa de novo passado o intervalo", ns.Sighting.SightName("Rhazul"), true)

    -- A VINHETA E A CHAVE BOA: numero, igual em todo idioma. Nao precisa de guarda de zona,
    -- porque vinheta que voce enxerga esta perto de voce por definicao.
    limpar()
    MAPA_DO_JOGADOR = 1234
    check("vinheta avisa mesmo com o mapa 'errado'",
        ns.Sighting.SightVignette(5555, "Rhazul"), true)
    check("  e a linha nomeia a montaria", avisos[1]:find("Farm curto", 1, true) ~= nil, true)

    limpar()
    check("vinheta desconhecida nao avisa", ns.Sighting.SightVignette(4242, "Sei la"), false)

    -- Montaria que saiu do jogo nao gera aviso: avisar sobre o que ninguem mais pega e provocacao.
    MAPA_DO_JOGADOR = 23
    limpar()
    ns.Sighting.SightName("Chefe sumido")
    check("raro de montaria sumida nao avisa", #avisos, 0)

    -- Bicho que nao larga nada: o addon nao e um segundo escaneador de raros.
    ns.Sighting.SightName("Javali qualquer")
    check("bicho sem montaria nao avisa", #avisos, 0)

    -- (!) AS DUAS GUARDAS DO SILVERDRAGON, uma de cada vez.
    --
    -- O pet de um cacador chamado com o nome de um raro tem GUID `Pet`, e e assim que ele sai
    -- da conta: estruturalmente, sem lista de nomes para manter. E bicho comum com o nome certo
    -- tambem nao passa, porque quem diz que algo e raro e o jogo, nao o catalogo.
    limpar()
    -- "Bicho" e o `lockBossName` da mesma montaria, e nao "Rhazul": o teste acima ja gastou o
    -- Rhazul no intervalo de repeticao, e com ele um "nao avisou" nao provaria a guarda -- so
    -- provaria o cooldown. Nome diferente, cooldown limpo, guarda medida de verdade.
    UNIDADE = { existe = true, nome = "Bicho", guid = "Pet-0-1-2-3-99999-000" , classe = "rare" }
    ns.Sighting.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    check("pet de jogador com nome de raro NAO avisa", #avisos, 0)

    UNIDADE = { existe = true, nome = "Bicho", guid = "Creature-0-1-2-3-99999-000", classe = "normal" }
    ns.Sighting.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    check("criatura comum com nome de raro NAO avisa", #avisos, 0)

    UNIDADE = { existe = true, nome = "Bicho", guid = "Creature-0-1-2-3-99999-000", classe = "rareelite" }
    ns.Sighting.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    check("criatura raro de verdade avisa", #avisos, 1)
    UNIDADE = { existe = false }

    -- E COM O AVISO DESLIGADO ELE CALA. O usuario foi explicito que nem todo mundo quer.
    limpar()
    ns.db.sightings = false
    ns.Sighting.SightName("Chefe")
    check("desligado, nao avisa", #avisos, 0)
    ns.db.sightings = true

    ns.Print = realPrint

    -- O LINK DO CHAT: o prefixo tem o nome do addon para nao colidir com o de outro, e link
    -- que nao e nosso tem que passar batido.
    check("link de outro addon passa batido", ns.Sighting.HandleLink("item:1234"), false)
end


--------------------------------------------------------------------------------
-- A CHANCE DE DROP, PELA TABELA DO WOWHEAD (23/09)
--
-- Pedido: voando pela zona, o aviso diz quem e o raro, o que ele dropa e QUAL A CHANCE. O MCL
-- tem a chance de 5 dos 40 raros; a tabela gerada do Wowhead (`Data/MobDrops.lua`) tem por
-- NPC, e e chaveada pelo npc id do GUID -- que nao se engana com nome.
--------------------------------------------------------------------------------
do
    print("")
    print("-- chance de drop pela tabela do Wowhead")

    local S = ns.Sighting

    -- O GUID: so criatura tem npc id, e GUID secreto nao e nem tocado.
    check("npc id do GUID de criatura", S.NpcOfGUID("Creature-0-3767-2552-1234-248741-0000ABCDEF"), 248741)
    check("pet de jogador nao tem npc id", S.NpcOfGUID("Pet-0-1-2-3-248741-000"), nil)
    check("jogador nao tem npc id", S.NpcOfGUID("Player-3209-0ABCDEF1"), nil)
    local realSecret = issecretvalue
    issecretvalue = function() return true end
    check("GUID secreto e recusado", S.NpcOfGUID("Creature-0-1-2-3-248741-000"), nil)
    issecretvalue = realSecret

    -- O TEXTO DA CHANCE. Duas casas significativas, porque sao amostras: 6391/7 e "1/910", e
    -- nao um "1/913" com cara de precisao. E "~" abaixo de dez quedas vistas.
    check("amostra pequena leva ~ e arredonda", S.ChanceText({ drop = { count = 7, outof = 6391 } }), "~1/910")
    check("amostra de 15 nao leva ~", S.ChanceText({ drop = { count = 15, outof = 5390 } }), "1/360")
    check("chance do MCL e exata", S.ChanceText({ entry = { chance = 100 } }), "1/100")
    check("  e 1/2000 continua 1/2000", S.ChanceText({ entry = { chance = 2000 } }), "1/2000")
    check("melhor que 1 em 10 vira porcentagem", S.ChanceText({ entry = { chance = 4 } }), "25%")
    check("sem dado nenhum, sem texto", S.ChanceText({ entry = {} }), nil)
    check("  e quem ja tem contagem do Wowhead ganha dela",
        S.ChanceText({ entry = { chance = 100 }, drop = { count = 50, outof = 1000 } }), "1/20")

    -- A TABELA. Item 9000+n e a montaria n da fixture; a 7 ja foi coletada.
    C_MountJournal.GetMountFromItem = function(item) return item > 9000 and item - 9000 or nil end
    local realDrops = ns.MobDrops
    ns.MobDrops = {
        [248741] = { name = "Rhazul", { item = 9005, count = 7, outof = 6391 } },
        [250317] = { name = "Oro'ohna",
            { item = 9005, count = 15, outof = 5390 },
            { item = 9007, count = 3, outof = 900 } },     -- ja coletada
        [300000] = { name = "So coletada", { item = 9007, count = 9, outof = 90 } },
        [15311] = { name = "Anubisath Warder", c = 1, { item = 9005, count = 40, outof = 88000 } },
    }
    S.Rebuild()

    local avisos = {}
    local realPrint = ns.Print
    ns.Print = function(...) avisos[#avisos + 1] = table.concat({ ... }, " ") end

    -- (!) O NPC NAO PRECISA DE GUARDA DE ZONA: o id e exato. O jogador esta num mapa que o
    -- catalogo nao conhece, e mesmo assim o raro de verdade avisa -- com a chance.
    MAPA_DO_JOGADOR = 9999
    UNIDADE = { existe = true, nome = "Rhazul", guid = "Creature-0-1-2-3-248741-000", classe = "rare" }
    S.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    check("raro da tabela avisa em qualquer mapa", #avisos, 1)
    check("  com a montaria e a chance", (avisos[1] or ""):find("Farm longo (~1/910)", 1, true) ~= nil, true)

    -- O MESMO RARO POR OUTRO CAMINHO E UM AVISO SO. Voando, a vinheta chega primeiro; depois o
    -- jogador mira. Sao duas deteccoes do mesmo bicho, e a chave e o npc id nas duas.
    avisos = {}
    VINHETAS = { { vignetteID = 777, name = "Oro'ohna", objectGUID = "Creature-0-1-2-3-250317-000" } }
    S.OnEvent(nil, "VIGNETTE_MINIMAP_UPDATED")
    check("vinheta com GUID de criatura avisa pelo npc", #avisos, 1)
    check("  so com o que falta (a coletada nao entra)",
        (avisos[1] or ""):find("Farm longo (1/360)", 1, true) ~= nil
            and (avisos[1] or ""):find("Ja coletada", 1, true) == nil, true)
    UNIDADE = { existe = true, nome = "Oro'ohna", guid = "Creature-0-1-2-3-250317-000", classe = "rare" }
    S.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    check("  e mirar o mesmo raro depois nao repete", #avisos, 1)

    -- (!) ELITE COMUM DA TABELA AVISA. Pedido do usuario: "raros, elites, world boss e etc".
    -- A guarda de classificacao era para o NOME; com o npc id exato, um elite de AQ que larga
    -- o tanque Qiraji e reconhecido igual a um raro.
    avisos = {}
    UNIDADE = { existe = true, nome = "Anubisath Warder", guid = "Creature-0-1-2-3-15311-000", classe = "elite" }
    S.OnEvent(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    check("elite da tabela avisa, mesmo sem ser raro", #avisos, 1)
    check("  com a chance dele", (avisos[1] or ""):find("Farm longo (1/2200)", 1, true) ~= nil, true)

    -- E o elite FORA da tabela continua calado: o addon nao vira um alarme de todo elite.
    avisos = {}
    UNIDADE = { existe = true, nome = "Elite qualquer", guid = "Creature-0-1-2-3-424242-000", classe = "elite" }
    S.OnEvent(nil, "NAME_PLATE_UNIT_ADDED", "nameplate2")
    check("elite fora da tabela nao avisa", #avisos, 0)

    -- Raro cuja unica montaria voce ja tem: silencio.
    avisos = {}
    UNIDADE = { existe = true, nome = "So coletada", guid = "Creature-0-1-2-3-300000-000", classe = "rare" }
    S.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    check("raro so de montaria coletada nao avisa", #avisos, 0)

    -- (!) RARO JA SAQUEADO HOJE NAO AVISA. Pedido do usuario: "se der respawn eu nao posso avisar
    -- de novo, por que o jogador ja matou ele e nao vai dropar nada".
    --
    -- Fonte 1, a do jogo: a missao diaria oculta que o MCL cataloga (`dq`).
    local realQuest = C_QuestLog.IsQuestFlaggedCompleted
    C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 92191 or realQuest(id) end
    TEMPO = TEMPO + 601
    avisos = {}
    check("raro com a diaria do MCL feita NAO avisa", S.SightVignette(5555, "Rhazul"), false)
    C_QuestLog.IsQuestFlaggedCompleted = realQuest
    check("  e com a diaria por fazer avisa", S.SightVignette(5555, "Rhazul"), true)

    -- Fonte 2, o nosso registro: o saque aberto diz de que corpo veio.
    local realTime = time
    local AGORA = realTime()
    time = function() return AGORA end
    C_DateAndTime = {
        GetSecondsUntilDailyReset = function() return 3600 end,
        GetSecondsUntilWeeklyReset = function() return 5 * 86400 end,
    }
    local SAQUE = {}
    GetNumLootItems = function() return #SAQUE end
    GetLootSourceInfo = function(slot) return SAQUE[slot], 1 end
    -- O Wowhead chama todo chefe de elite (o Lich King vem `c = 1`); quem diz "world boss" e o
    -- jogo, na classificacao da unidade. O elite de AQ faz as vezes de world boss aqui.
    UNIDADE = { existe = true, nome = "Anubisath Warder", guid = "Creature-0-1-2-3-15311-000", classe = "worldboss" }
    TEMPO = TEMPO + 601
    S.OnEvent(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")

    SAQUE = { "Creature-0-1-2-3-248741-000", "Creature-0-1-2-3-424242-000" }
    ns.db.sightings = false                          -- anota mesmo com o aviso desligado
    S.OnEvent(nil, "LOOT_OPENED")
    ns.db.sightings = true
    check("o saque anota o raro da tabela", ns.db.looted["Hamfarir-Azralon"] ~= nil
        and ns.db.looted["Hamfarir-Azralon"][248741] == AGORA + 3600, true)
    check("  e ignora o bicho que nao esta na tabela", ns.db.looted["Hamfarir-Azralon"][424242], nil)

    TEMPO = TEMPO + 601
    avisos = {}
    UNIDADE = { existe = true, nome = "Rhazul", guid = "Creature-0-1-2-3-248741-000", classe = "rare" }
    S.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    check("raro saqueado hoje NAO avisa no respawn", #avisos, 0)

    AGORA = AGORA + 3601                             -- passou o reset diario
    TEMPO = TEMPO + 601
    S.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    check("  e depois do reset volta a avisar", #avisos, 1)
    check("  e o registro vencido some do arquivo", ns.db.looted["Hamfarir-Azralon"][248741], nil)

    -- World boss: o bloqueio e semanal, e nao some no reset do dia.
    SAQUE = { "Creature-0-1-2-3-15311-000" }
    S.OnEvent(nil, "LOOT_OPENED")
    check("world boss fica bloqueado ate o reset SEMANAL",
        ns.db.looted["Hamfarir-Azralon"][15311], AGORA + 5 * 86400)
    AGORA = AGORA + 3601
    TEMPO = TEMPO + 601
    avisos = {}
    UNIDADE = { existe = true, nome = "Anubisath Warder", guid = "Creature-0-1-2-3-15311-000", classe = "worldboss" }
    S.OnEvent(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    check("  e continua calado no dia seguinte", #avisos, 0)

    ns.db.looted = nil
    time = realTime
    GetNumLootItems, GetLootSourceInfo, C_DateAndTime = nil, nil, nil

    -- (!) A MONTARIA RECEM-APRENDIDA SAI DO AVISO NA HORA. Pedido do usuario: "so avise sobre a
    -- montaria que o usuario nao tenha ainda". O evento de montaria nova so marcava a lista como
    -- suja; com a janela fechada, o indice do aviso seguia com a lista velha e oferecia a
    -- montaria que o jogador acabou de ganhar.
    local farmLongo
    for _, m in ipairs(MOUNTS) do if m[3] == "Farm longo" then farmLongo = m end end
    -- COM A JANELA FECHADA, que e o caso do defeito: aberta, o evento ja recalcula a lista
    -- pelo caminho da janela, e o teste passaria sem medir nada (a sabotagem mostrou isso).
    if ns.window then ns.window:Hide() end
    check("  (a janela esta fechada)", ns.window == nil or not ns.window:IsShown(), true)
    farmLongo[5] = true                      -- aprendeu
    ns.frame.__scripts.OnEvent(ns.frame, "NEW_MOUNT_ADDED")
    TEMPO = TEMPO + 601                      -- fora do intervalo de repeticao
    avisos = {}
    UNIDADE = { existe = true, nome = "Rhazul", guid = "Creature-0-1-2-3-248741-000", classe = "rare" }
    S.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    check("montaria aprendida agora nao e mais oferecida", #avisos, 0)
    farmLongo[5] = false
    ns.frame.__scripts.OnEvent(ns.frame, "NEW_MOUNT_ADDED")

    UNIDADE = { existe = false }
    VINHETAS = {}
    ns.Print = realPrint
    ns.MobDrops = realDrops
    C_MountJournal.GetMountFromItem = nil
    S.Rebuild()
end


--------------------------------------------------------------------------------
-- A CONQUISTA QUE O JOGO DIZ QUE DA A MONTARIA (22/09)
--
-- (!) FECHA O MAIOR BURACO DO CATALOGO SEM CURAR NADA. Sao 126 montarias marcadas "SPECIAL",
-- sobre as quais o catalogo nao sabe mais nada -- e foi isso que deixou o Corcel de Guerra
-- Prestigioso se anunciar como pronto. Conferido no warcraftmounts.com: boa parte delas e
-- recompensa de conquista, e o jogo sabe de todas via `GetAchievementReward`.
--------------------------------------------------------------------------------
do
    print("")
    print("-- conquista que da a montaria, lida do jogo")

    ns.Achievements.Scan()
    -- A varredura e fatiada com `C_Timer.After(0, ...)`, que no simulador roda na hora.

    local ach = ns.Achievements.For("Metodo a parte")
    check("acha a conquista pelo texto da recompensa", ach ~= nil, true)
    check("  e guarda o id dela", ach and ach.id, 8008)

    -- Conquista que premia OUTRA coisa nao vira requisito de montaria nenhuma.
    check("recompensa que nao e montaria nao entra", ns.Achievements.For("Nada a ver"), nil)

    local gate = ns.Achievements.Gate("Metodo a parte")
    check("conquista nao concluida bloqueia", gate and gate.pct, 0)
    check("  e a linha nomeia a conquista",
        gate and gate.label:find("Achievement", 1, true) ~= nil, true)

    -- (!) SINAL NEGATIVO, como todas as fontes: conquista CONCLUIDA nao devolve "liberado".
    -- Concluida nao prova que a montaria ainda e obtenivel -- foi assim que o tooltip promoveu
    -- o Prestigioso para o topo, e a regra vale para a fonte nova tambem.
    local realInfo = GetAchievementInfo
    GetAchievementInfo = function(a, b)
        if b then return realInfo(a, b) end
        return a, "Conquista " .. a, 10, true      -- agora consta como concluida
    end
    check("conquista concluida NAO vira acesso liberado", ns.Achievements.Gate("Metodo a parte"), nil)
    GetAchievementInfo = realInfo

    -- E a montaria do caso deixa de ficar sem requisito nenhum.
    ns.Invalidate()
    local depois
    for _, e in ipairs(ns.GetRanked(true)) do
        if e.name == "Metodo a parte" then depois = e end
    end
    check("a montaria SPECIAL passa a ter requisito", depois.achievementReward ~= nil, true)
    check("  e continua fora do topo", depois.tier ~= ns.TIER.READY, true)
end


--------------------------------------------------------------------------------
-- A FICHA NAO PODE DIZER A MESMA COISA DUAS VEZES (relatado em 22/09, testando no jogo)
--------------------------------------------------------------------------------
-- *"tem o Requisitos, tem o preco e o Falta, as vezes tem as mesmas informacoes"*. O preco
-- estava em tres lugares: na lista de requisitos, no bloco "Preco" e no bloco "Falta".
--
-- (!) O TESTE SO EXISTE PORQUE A REGRA SAIU DE DENTRO DO DESENHO. Enquanto ela morava no
-- codigo que pinta widget, duplicata nenhuma era visivel daqui -- que e como esta passou.
print("")
print("-- a ficha da montaria")
do
    -- "Dois requisitos" e o pior caso: reputacao cumprida E moeda a 30%, ou seja, preco com
    -- falta. E nele que as tres copias apareciam.
    local e = porNome["Dois requisitos"].e
    local blocos = ns.DetailBlocks(e)
    check("a ficha tem blocos", #blocos > 0, true)

    local porRotulo, repetido = {}, nil
    for _, b in ipairs(blocos) do
        if porRotulo[b.label] then repetido = b.label end
        porRotulo[b.label] = b.value
    end
    check("nenhum rotulo aparece duas vezes", repetido, nil)

    -- O preco tem que aparecer UMA vez -- nem zero (some a informacao) nem duas.
    local vezes = 0
    for _, b in ipairs(blocos) do
        if b.value:find(e.cost.price, 1, true) then vezes = vezes + 1 end
    end
    check("o preco aparece uma vez so", vezes, 1)
    check("  e quem o carrega e a lista de requisitos", (function()
        for _, b in ipairs(blocos) do
            if b.label:find("Requirements", 1, true) and b.value:find(e.cost.price, 1, true) then
                return true
            end
        end
        return false
    end)(), true)

    -- E a falta continua dita, dentro da mesma linha: sumir com a duplicata nao pode sumir
    -- com o dado. Era o risco desta correcao, e e ele que esta travado aqui.
    check("o que falta continua na ficha", (function()
        for _, b in ipairs(blocos) do
            if b.value:find(e.cost.gap, 1, true) then return true end
        end
        return false
    end)(), true)

    -- E nao sobrou bloco "Preco"/"Falta" solto por esquecimento.
    check("nao ha mais bloco 'Preco' separado", porRotulo["Preço"], nil)
    check("nem bloco 'Falta'", porRotulo["Falta"], nil)
end

--------------------------------------------------------------------------------
-- GEOMETRIA DA JANELA (relatado em 22/09, testando no jogo)
--------------------------------------------------------------------------------
-- *"as informacoes da direita estao bem grudadas e tem texto vazando pra fora da janela"*.
--
-- Isto e aritmetica, e aritmetica se confere em disco -- nao se gasta uma rodada de teste
-- in-game com ela. O que os testes travam e a RELACAO entre as pecas, nao o numero cru: os
-- numeros mudam quando a janela mudar; o "tem que caber" nao pode voltar a quebrar.
print("")
print("-- geometria da janela")
do
    local G = ns.Geometry
    check("a geometria esta exposta", type(G) == "table", true)

    -- (!) A CONTA QUE ESTAVA ERRADA. A largura declarada tem que ser exatamente a que as pecas
    -- pedem: menor, e a ficha vaza pela borda (era o caso, por 15px); maior, sobra buraco.
    -- Somam: margem + lista + barra de rolagem + respiro + fio + respiro + ficha + margem.
    check("a largura declarada e a largura necessaria batem", G.windowW, G.neededW)

    -- A barra de rolagem vive FORA do quadro rolavel, encostada a direita dele. Sem calha
    -- propria ela desenha por cima do fio separador, que foi metade do "bem grudadas".
    check("ha calha para a barra de rolagem", G.scrollbarW >= 20, true)

    -- Na linha, o nome nao pode terminar depois de onde o numero da direita comeca. Estava
    -- 4px por cima -- e como o nome nao quebra linha, ele era cortado encostado no numero.
    local fimDoNome = G.rowTextX + G.rowTextW
    local inicioDoNumero = G.rowW - G.headlineInset - G.headlineW
    check("o nome termina antes do numero da direita", fimDoNome <= inicioDoNumero, true)
    check("  e sobra respiro entre os dois", inicioDoNumero - fimDoNome >= 8, true)

    -- E a ficha nao pode ser mais estreita que a medida de leitura: ela e prosa, e prosa em
    -- coluna estreita vira escada.
    check("a ficha tem largura de leitura", G.detailW >= 320, true)
end

print(falhas == 0 and "FIM — tudo certo" or ("FIM — " .. falhas .. " falha(s)"))
os.exit(falhas == 0 and 0 or 1)
