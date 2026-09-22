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
Minimap = widget("Minimap")
UISpecialFrames = {}
SlashCmdList = {}
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }

function CreateFrame(kind) return widget(kind) end
function UnitFactionGroup() return "Alliance" end
function UnitName() return "Hamfarir" end
function GetRealmName() return "Azralon" end
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
        [1021] = { isUnobtainable = true, chance = 100 },
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
check("sobram as dezoito que faltam", #ranked, 18)

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
    "Preco e acesso conhecido", "Pronta por reputacao",
    -- Dentro da faixa, quem andou mais caminho vem antes: 95% na frente de 80%.
    "Quase la com mais rep", "Quase la por reputacao",
    "Metade da conquista", "Dois requisitos",
    -- No farm, primeiro quem ja esta liberado e, entre os liberados, a chance mais generosa.
    "Bau com reputacao pronta", "Bau fora do tipo queda",
    "Farm curto mais raro", "Farm curto",
    "Queda ainda trancada",
    -- (!) E SO ENTAO a de preco-so. Ela ja esteve em TERCEIRO, logo abaixo de "e so ir pegar",
    -- e isso fazia a lista recomendar justamente o que ela nao consegue avaliar. Posicao e
    -- recomendacao: "eu nao sei" pertence ao fim, ao lado de "sem estimativa".
    -- A reputacao que a API nao le entra como NAO cumprida (0%), e nao como ausente: por isso
    -- ela cai aqui embaixo, e nao la em cima junto das que dao para comprar.
    -- Requisito conhecido e NAO cumprido (0%) vem antes de requisito que nao da para medir:
    -- saber o que falta vale mais que nao saber nada.
    "Rep que nunca vi", "So sei o preco", "Farm longo",
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
    soOuro.why:find("que eu n") ~= nil, true)
-- E QUANDO O VENDEDOR E DE GUILDA, a ressalva deixa de ser generica e ganha nome: toda montaria
-- de vendedor de guilda exige reputacao com a guilda mais uma conquista DE GUILDA.
check("vendedor de guilda e reconhecido", soPreco.vendorGuilda, true)
check("  e a linha nomeia o bloqueio",
    soPreco.why:find("guilda", 1, true) ~= nil, true)
check("vendedor sem coordenada fica marcado como vago", soPreco.vendorVago, true)
check("e a faixa de preco-so fica NO FIM, nao perto do topo",
    ns.TIER.CHECK > ns.TIER.LONGFARM, true)

local comAcesso = porNome["Preco e acesso conhecido"].e
check("com acesso conhecido e cumprido, ai sim e pronto", comAcesso.tier, ns.TIER.READY)
check("e ele diz 'pode pegar'", comAcesso.headline, "pode pegar")
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
check("  e a linha diz o que houve", nuncaVi.rep.label:find("reputa") ~= nil, true)

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
    comAcesso.rep.label:find("da conta") ~= nil, true)
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
    trancada.why:find("Falta liberar") ~= nil, true)

-- Só aquisição determinística pode dizer "pode pegar".
local prontos = 0
for _, e in ipairs(ranked) do
    if e.headline == "pode pegar" then
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
check("Pronto mostra 'pode pegar', nao 100%", porNome["Pronta por reputacao"].e.headline, "pode pegar")
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
check("sem o MCL a lista continua de pe", #semMCL, 18)
local todasSemEstimativa = true
for _, e in ipairs(semMCL) do
    if e.tier ~= ns.TIER.UNKNOWN then todasSemEstimativa = false end
end
check("e sem ele tudo cai em Sem estimativa", todasSemEstimativa, true)
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

-- Fumaca da janela: construir e desenhar nao pode estourar.
local okJanela, erroJanela = pcall(ns.ToggleWindow)
check("a janela monta e desenha sem erro", okJanela, true)
if not okJanela then print("      " .. tostring(erroJanela)) end

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

print(falhas == 0 and "FIM — tudo certo" or ("FIM — " .. falhas .. " falha(s)"))
os.exit(falhas == 0 and 0 or 1)
