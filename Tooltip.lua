-- RocketMount | Tooltip.lua
-- Reads the mount item's own tooltip and pulls out what the game says is required.
--
-- (!) THIS IS THE ANSWER TO "SHOULD WE CURATE A DATABASE?" -- and it is a better one.
--
-- The problem all along: a mount is blocked by something no installed catalogue records (the
-- Dark Phoenix and its guild achievement), and the addon then claimed it was obtainable. The
-- obvious fix was to write our own database from Wowhead. That fix has a failure mode we spent
-- a whole day removing: **a curated entry that is wrong is wrong silently**, forever, and it is
-- the addon speaking with confidence about something nobody verified.
--
-- But the game already knows. Put the mouse over the mount's item in the auction house and the
-- tooltip says, in your language, *"Requires Exalted with <faction>"* or *"Requires <achievement>"*.
-- `C_TooltipInfo.GetItemByID` hands those same lines to an addon as data.
--
-- What that buys, against a curated file:
--
--   * it covers every mount that has an item, not the ones someone got around to;
--   * it is right today and right after the next patch, with nobody maintaining it;
--   * it is already translated;
--   * it is nobody's work but Blizzard's, so nothing is copied from another addon;
--   * and when it says nothing, that is the truth, not a gap in somebody's spreadsheet.
--
-- What it does NOT buy: a mount with no item (drops that teach directly, achievement rewards)
-- has no tooltip to read, and this stays quiet about those. Quiet is the correct answer there.
local _, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

-- (!) OS TEXTOS VÊM DO CLIENTE, e não de uma lista minha em português.
--
-- `ITEM_REQ_REPUTATION` é "Requires %s - %s" em inglês e "Requer %s - %s" em português, porque
-- quem traduz é a Blizzard. Escrever "Requer" aqui quebraria em todo cliente que não é ptBR --
-- e é o tipo de defeito que só aparece quando outra pessoa instala o addon.
--
-- O padrão de Lua sai da própria global: `%s` vira `(.+)` e o resto é escapado.
local function ToPattern(global)
    if type(global) ~= "string" or global == "" then return nil end
    local escaped = global:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    escaped = escaped:gsub("%%%%s", "(.+)")
    escaped = escaped:gsub("%%%%d", "(%%d+)")
    return "^" .. escaped .. "$"
end

-- As globais que descrevem requisito num tooltip de item. Cada uma pode não existir num
-- cliente; `ToPattern` devolve nil e ela simplesmente não entra.
local REQUIRE_GLOBALS = {
    "ITEM_REQ_REPUTATION",          -- "Requires %s - %s"
    "ITEM_REQ_SKILL",               -- "Requires %s"
    "ITEM_REQ_ARENA_RATING",        -- "Requires personal and team arena rating of %d"
    "ITEM_REQ_SPECIALIZATION",
    "ITEM_MIN_LEVEL",               -- "Requires Level %d"
    "LOCKED_WITH_ITEM",
}

local patterns
local function Patterns()
    if patterns then return patterns end
    patterns = {}
    for _, nome in ipairs(REQUIRE_GLOBALS) do
        local p = ToPattern(_G and _G[nome])
        if p then patterns[#patterns + 1] = { nome = nome, pattern = p } end
    end
    return patterns
end

---É uma linha de requisito?
---
---Duas evidências, e qualquer uma basta:
---
---  1. o TIPO da linha é `UsageRequirement` -- a própria Blizzard classificando;
---  2. o texto casa com uma das globais de "Requer ...".
---
---E uma terceira que decide se está CUMPRIDO: linha de requisito não cumprido vem **vermelha**
---(1, 0.125, 0.125). É assim que o jogo diz "você não pode" sem escrever isso.
local function LineInfo(line)
    if type(line) ~= "table" then return nil end
    local texto = line.leftText
    if type(texto) ~= "string" or texto == "" then return nil end

    local ehRequisito = false
    if Enum and Enum.TooltipDataLineType and line.type == Enum.TooltipDataLineType.UsageRequirement then
        ehRequisito = true
    else
        for _, p in ipairs(Patterns()) do
            if texto:match(p.pattern) then
                ehRequisito = true
                break
            end
        end
    end
    if not ehRequisito then return nil end

    -- Vermelho = não cumprido. O verde/branco do jogo significa cumprido.
    local vermelho = false
    if type(line.leftColor) == "table" and line.leftColor.r then
        vermelho = line.leftColor.r > 0.8 and line.leftColor.g < 0.3 and line.leftColor.b < 0.3
    end

    -- The reputation line specifically ("Requires %s - %s"): it can be set aside when another
    -- character is the one who holds that reputation (Sources.lua, BestAlt).
    local repP = ToPattern(_G and _G.ITEM_REQ_REPUTATION)
    local ehRep = repP and texto:match(repP) and true or false
    return { texto = texto, cumprido = not vermelho, rep = ehRep }
end

---Every line of the item's tooltip, as the game hands it, with what this addon made of it:
---for `/rmt debug`. Written for the Gilded Prowler (25/09): its "Requires Exalted with The
---Ascended." is not in the `ITEM_REQ_REPUTATION` format, and whether the game types it as a
---requirement, or paints it red, is something only the client can say.
function Tooltip.Dump(itemID)
    if type(itemID) ~= "number" or not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local out = {}
    for i, line in ipairs(data.lines) do
        local c = type(line.leftColor) == "table" and line.leftColor
        local info = LineInfo(line)
        out[#out + 1] = string.format("%d type=%s color=%s req=%s  %s", i, tostring(line.type),
            c and string.format("%.2f,%.2f,%.2f", c.r or 0, c.g or 0, c.b or 0) or "-",
            info and (info.cumprido and "met" or "UNMET") or "no",
            tostring(line.leftText))
    end
    return out
end

---Os requisitos que o tooltip do item declara.
---
---@return table|nil lista `{ { texto, cumprido }, ... }`, ou nil quando não há item ou o
---tooltip ainda não carregou (o cliente busca o item do servidor na primeira vez).
function Tooltip.Requirements(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then return nil end
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end

    local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end

    local out
    for _, line in ipairs(data.lines) do
        local info = LineInfo(line)
        if info then
            out = out or {}
            out[#out + 1] = info
        end
    end
    return out
end

---Resume os requisitos do tooltip num registro do mesmo formato dos outros.
---
---`pct` é 1 quando todos estão cumpridos e 0 quando qualquer um não está -- e é 0 e não uma
---fração de propósito: "metade dos requisitos do tooltip" não significa nada, porque eles não
---são etapas de um caminho, são portas. Ou passa, ou não passa.
function Tooltip.Gate(itemID, ignorarRep)
    local reqs = Tooltip.Requirements(itemID)
    if not reqs or #reqs == 0 then return nil end

    local faltando = {}
    for _, r in ipairs(reqs) do
        local daRep = false
        if ignorarRep then
            daRep = r.rep
            for _, nome in ipairs(ignorarRep) do
                if type(nome) == "string" and nome ~= "" and r.texto:find(nome, 1, true) then
                    daRep = true
                end
            end
        end
        if not r.cumprido and not daRep then faltando[#faltando + 1] = r.texto end
    end

    -- (!) O TOOLTIP SÓ SERVE COMO SINAL NEGATIVO. Ele diz o que BLOQUEIA, nunca o que libera.
    --
    -- Esta função já devolveu `pct = 1` quando nada no tooltip estava vermelho, e isso virou
    -- defeito no mesmo dia: o Corcel de Guerra Prestigioso apareceu como "é só ir pegar". O
    -- catálogo não sabe nada dele (`method = "SPECIAL"` e só), e o tooltip do item traz um
    -- "Requer nível 10" que o jogador cumpre — então "requisito cumprido" virou acesso
    -- liberado. Só que a montaria vem da conquista *Free For All, More For Me*, que o tooltip
    -- do item não menciona.
    --
    -- **Nada bloqueando no tooltip não é prova de que dá para pegar.** É a mesma lição das
    -- outras cinco vezes, agora aplicada à fonte mais nova do addon: ausência de impedimento
    -- lida como permissão. Devolver `nil` deixa a montaria cair onde ela pertence — em "sem
    -- estimativa" — em vez de subir para o topo.
    if #faltando == 0 then return nil end

    return {
        kind = "tooltip", pct = 0, fromTooltip = true,
        faltando = faltando,
        label = table.concat(faltando, "  ·  "),
    }
end

--------------------------------------------------------------------------------
-- LOADING THE ITEMS BEFORE READING THEM
--
-- (!) An item the client has not cached yet answers its tooltip with nothing, and nothing was
-- read as "no requirement" -- once, at login, and never again. Reported 23/09 with a list of
-- covenant, Brawler's Guild and reputation mounts sitting among the easy ones, and the user:
-- *"faça todas as validações antes de mostrar essa tela, mesmo que demore (...) coloca uma barra
-- de loading"*. So every missing mount's item is requested from the server first
-- (`C_Item.RequestLoadItemDataByID`, answered by `ITEM_DATA_LOAD_RESULT` -- both in the 12.1.0
-- API docs), and a tooltip is read only once its item is in the cache.
--------------------------------------------------------------------------------
local falhou = {}          -- itemID -> true: the server said no, or it never answered
local pendentes = {}       -- itemID -> true while waiting
local total, feitos = 0, 0
local aoTerminar
local frameEv
-- 60, not 30: every missing mount's item is asked for at once, several hundred of them.
local TIMEOUT = 60

---"ok" (in the cache, the tooltip can be trusted), "pending" or "failed".
function Tooltip.State(itemID)
    if type(itemID) ~= "number" then return nil end
    if not (C_Item and C_Item.IsItemDataCachedByID) then return "ok" end
    local ok, cached = pcall(C_Item.IsItemDataCachedByID, itemID)
    if ok and cached then return "ok" end
    if falhou[itemID] then return "failed" end
    return "pending"
end

local function Terminar()
    for id in pairs(pendentes) do falhou[id] = true end
    pendentes = {}
    local fn = aoTerminar
    aoTerminar = nil
    if fn then fn() end
end

local function Uma(itemID, sucesso)
    if not pendentes[itemID] then return end
    pendentes[itemID] = nil
    feitos = feitos + 1
    if not sucesso then falhou[itemID] = true end
    if ns.OnValidationProgress then ns.OnValidationProgress() end
    if next(pendentes) == nil then Terminar() end
end

---Asks the server for every item not in the cache, and calls `onDone` when all answered (or
---after TIMEOUT seconds; what did not answer is "failed", never "fine").
function Tooltip.Preload(itemIDs, onDone)
    total, feitos = 0, 0
    pendentes = {}
    for _, id in ipairs(itemIDs) do
        if Tooltip.State(id) == "pending" and not pendentes[id] then
            pendentes[id] = true
            total = total + 1
        end
    end
    aoTerminar = onDone
    if total == 0 or not (C_Item and C_Item.RequestLoadItemDataByID) then
        Terminar()
        return
    end
    if not frameEv then
        frameEv = CreateFrame("Frame")
        pcall(frameEv.RegisterEvent, frameEv, "ITEM_DATA_LOAD_RESULT")
        frameEv:SetScript("OnEvent", function(_, _, itemID, sucesso) Uma(itemID, sucesso) end)
    end
    for id in pairs(pendentes) do pcall(C_Item.RequestLoadItemDataByID, id) end
    if C_Timer and C_Timer.After then
        C_Timer.After(TIMEOUT, function() if aoTerminar then Terminar() end end)
    end
end

function Tooltip.Progress() return feitos, total end
