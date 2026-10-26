-- RocketMount | Tooltip.lua
-- Reads the mount item's own tooltip and pulls out what the game says is required.
--
-- (!) THIS IS THE ANSWER TO "SHOULD WE CURATE A DATABASE?" -- and it is a better one.
--
-- The problem all along: a mount is blocked by something no catalogue records (the
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
--   * it is nobody's work but Blizzard's;
--   * and when it says nothing, that is the truth, not a gap in somebody's spreadsheet.
--
-- What it does NOT buy: a mount with no item (drops that teach directly, achievement rewards)
-- has no tooltip to read, and this stays quiet about those. Quiet is the correct answer there.
local _, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

-- (!) THE TEXTS COME FROM THE CLIENT, and not from a list of mine in Portuguese.
--
-- `ITEM_REQ_REPUTATION` is "Requires %s - %s" in English and "Requer %s - %s" in Portuguese, because
-- Blizzard is who translates. Writing "Requer" here would break in every client that is not ptBR --
-- and it is the kind of defect that only shows when someone else installs the addon.
--
-- The Lua pattern comes from the global itself: `%s` becomes `(.+)` and the rest is escaped.
local function ToPattern(global)
    if type(global) ~= "string" or global == "" then return nil end
    local escaped = global:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    escaped = escaped:gsub("%%%%s", "(.+)")
    escaped = escaped:gsub("%%%%d", "(%%d+)")
    return "^" .. escaped .. "$"
end

-- The globals that describe a requirement in an item tooltip. Each one may not exist in a
-- client; `ToPattern` returns nil and it simply does not go in.
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

--- Is it a requirement line?
---
--- Two pieces of evidence, and either is enough:
---
---  1. the line's TYPE is `UsageRequirement` -- Blizzard itself classifying it;
---  2. the text matches one of the "Requires ..." globals.
---
--- And a third that decides whether it is MET: an unmet requirement line comes **red**
--- (1, 0.125, 0.125). That is how the game says "you cannot" without writing it.
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

    -- Red = not met. The game's green/white means met.
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

---What the game says an item IS: its flavour text, the line in quotes at the foot of its
---tooltip. For a currency item it is usually where it comes from and who takes it -- "Solidified
---motes of energy slipping into Azeroth from the Emerald Dream. Celestine of the Harvest near
---Dreamsurge Investigations will trade for these." -- already in the player's language.
---
---The line is recognised by the TYPE the game gives it (`Enum.TooltipDataLineType.FlavorText`),
---never by its look. An item not in the cache yet is asked for and answers nil this time.
---@return string|nil text, without the quotes
function Tooltip.Flavor(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then return nil end
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    if Tooltip.State(itemID) ~= "ok" then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
        return nil
    end
    local tipo = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.FlavorText
    if not tipo then return nil end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    for _, line in ipairs(data.lines) do
        local texto = type(line) == "table" and line.type == tipo and line.leftText
        if type(texto) == "string" and not (issecretvalue and issecretvalue(texto)) and texto ~= "" then
            return (texto:gsub('^"', ""):gsub('"$', ""))
        end
    end
    return nil
end

--- The requirements the item's tooltip states.
---
--- @return table|nil list `{ { text, met }, ... }`, or nil when there is no item or the
--- tooltip has not loaded yet (the client fetches the item from the server the first time).
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

--- Sums up the tooltip's requirements in a record of the same shape as the others.
---
--- `pct` is 1 when all are met and 0 when any is not -- and it is 0 and not a
--- fraction on purpose: "half the tooltip's requirements" means nothing, because they are not
--- stages of a road, they are doors. It either passes, or it does not.
function Tooltip.Gate(itemID, ignorarRep)
    local reqs = Tooltip.Requirements(itemID)
    if not reqs or #reqs == 0 then return nil end

    local faltando = {}
    for _, r in ipairs(reqs) do
        local daRep = false
        if ignorarRep then
            -- `onlyNamed`: only the line that names one of the factions is set aside; a
            -- reputation line of ANOTHER faction is still a requirement.
            daRep = r.rep and not ignorarRep.onlyNamed
            for _, nome in ipairs(ignorarRep) do
                if type(nome) == "string" and nome ~= "" and r.texto:find(nome, 1, true) then
                    daRep = true
                end
            end
        end
        if not r.cumprido and not daRep then faltando[#faltando + 1] = r.texto end
    end

    -- (!) THE TOOLTIP ONLY SERVES AS A NEGATIVE SIGNAL. It says what BLOCKS, never what frees.
    --
    -- This function once returned `pct = 1` when nothing in the tooltip was red, and that became a
    -- defect the same day: the Prestigious War Steed showed as "just go get it". The
    -- catalogue knows nothing about it (`method = "SPECIAL"` and that is all), and the item's tooltip brings a
    -- "Requires level 10" the player meets -- so "requirement met" became access
    -- granted. Only the mount comes from the achievement *Free For All, More For Me*, which the item's
    -- tooltip does not mention.
    --
    -- **Nothing blocking in the tooltip is no proof that it can be had.** It is the same lesson as the
    -- other five times, now applied to the addon's newest source: the absence of a block
    -- read as permission. Returning `nil` lets the mount fall where it belongs -- in "no
    -- estimate" -- instead of going up to the top.
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
local REQUESTS_PER_FRAME = 25
Tooltip.REQUESTS_PER_FRAME = REQUESTS_PER_FRAME
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
    -- (!) A FEW PER FRAME (02/10): several hundred requests in one frame were part of the hitch
    -- when the game opened. The answers come by event, as before.
    local fila = {}
    for id in pairs(pendentes) do fila[#fila + 1] = id end
    table.sort(fila)
    local proximo = 1
    local function Lote()
        local ate = math.min(#fila, proximo + REQUESTS_PER_FRAME - 1)
        for k = proximo, ate do
            if pendentes[fila[k]] then pcall(C_Item.RequestLoadItemDataByID, fila[k]) end
        end
        proximo = ate + 1
        if proximo <= #fila and aoTerminar and C_Timer and C_Timer.After then C_Timer.After(0, Lote) end
    end
    if C_Timer and C_Timer.After then
        Lote()
        C_Timer.After(TIMEOUT, function() if aoTerminar then Terminar() end end)
    else
        for _, id in ipairs(fila) do pcall(C_Item.RequestLoadItemDataByID, id) end
    end
end

function Tooltip.Progress() return feitos, total end
