-- RocketMount | Log.lua
-- A diary written to SavedVariables, readable from outside the game.
--
-- WHY IT EXISTS. The user, standing in front of the Sha of Anger waiting for it to respawn:
-- *"pode criar logs como fez em outros addons para acompanhar e poder fazer algum tipo de
-- debug"*. Without it, "the alert did not show" had three explanations nobody could tell apart
-- -- the addon never saw the creature, it saw it and decided to stay quiet, or it announced and
-- the panel failed -- and each one would cost a round of guessing.
--
-- Same format as RocketSwap's and RocketMeter's (`RocketSwap/Log.lua`), so the
-- `wow-addon-logs` skill reads all three the same way:
--
--   WTF\Account\<account>\SavedVariables\RocketMount.lua  ->  RocketMountLogDB
--     entries   the ring of lines: { time, event, combat, data }
--     erros     OUR errors, grouped: a repeat becomes a count, not a new line
--     captura   HOW errors are being captured ("buggrabber", "handler", "nenhuma"), so an empty
--               `erros` can be told apart from "not looking"
--
-- `/rmt log on` also echoes every line to chat as it happens, which answers "did it see the
-- Sha?" on the spot -- SavedVariables are only written on /reload or logout.
--
-- GOLDEN RULE, inherited from the meter: never store a secret value. Store facts ABOUT the data.
local ADDON, ns = ...
local L = ns.L

local Log = { enabled = true }
ns.Log = Log

-- A sighting decision is one line; a loot, one per corpse. 400 lines hold hours of play.
local MAX_ENTRIES = 400
local MAX_ERROS = 40

local function Store()
    RocketMountLogDB = RocketMountLogDB or { entries = {} }
    RocketMountLogDB.entries = RocketMountLogDB.entries or {}
    return RocketMountLogDB
end

---A value described, never stored raw. `issecretvalue` comes BEFORE `type`: for an opaque value
---`type()` answers the real type, and `tostring` would receive a secret.
local function Describe(value)
    if value == nil then return nil end
    if issecretvalue and issecretvalue(value) then return "SECRET" end
    local t = type(value)
    if t == "number" or t == "string" or t == "boolean" then return value end
    return t
end

local function Line(e)
    local parts = {}
    for k, v in pairs(e.data or {}) do
        parts[#parts + 1] = k .. "=" .. tostring(v)
    end
    table.sort(parts)
    return ("%s  %-8s %s"):format(e.time, e.event, table.concat(parts, "  "))
end

---Write one line.
---@param event string what happened, in one word ("alert", "silent", "loot", "rebuild")
---@param data table|nil the fields of that moment; secret values are described, not kept
function Log.Add(event, data)
    local clean
    if data then
        clean = {}
        for k, v in pairs(data) do clean[k] = Describe(v) end
    end
    local entries = Store().entries
    local e = {
        time = date("%H:%M:%S"),
        event = event,
        combat = InCombatLockdown and InCombatLockdown() and true or false,
        data = clean,
    }
    entries[#entries + 1] = e
    while #entries > MAX_ENTRIES do table.remove(entries, 1) end

    if ns.db and ns.db.logLive then
        print("|cff888888[rmt]|r " .. Line(e))
    end
end

function Log.Tail(howMany)
    local entries = Store().entries
    local out = {}
    for i = math.max(1, #entries - (howMany or 12) + 1), #entries do
        out[#out + 1] = Line(entries[i])
    end
    return out
end

function Log.Count() return #Store().entries end

function Log.Clear()
    local captura = Store().captura
    RocketMountLogDB = { entries = {}, captura = captura }
end

--------------------------------------------------------------------------------
-- Errors
--
-- Two ways in, the same as RocketSwap:
--   1. with !BugGrabber: subscribe to `BugGrabber.BugGrabbed` and copy what is ours -- it has
--      already neutralised `seterrorhandler` (`BugGrabber.lua:573-574`), so installing a handler
--      beside it is a call that does nothing and says nothing;
--   2. without it: chain onto the current handler, and CHECK it took, by comparing
--      `geterrorhandler()` with ours.
--------------------------------------------------------------------------------
local capturaInstalada = false

---Only THIS addon's frames of the stack, at most six. `nil` when none is ours: that is how an
---error from another addon is told apart.
local function NossosQuadros(stack)
    if type(stack) ~= "string" then return nil end
    local linhas, achou = {}, false
    for linha in stack:gmatch("[^\r\n]+") do
        if linha:find("AddOns\\" .. ADDON .. "\\", 1, true) or linha:find("AddOns/" .. ADDON .. "/", 1, true) then
            achou = true
            if #linhas < 6 then linhas[#linhas + 1] = (linha:gsub("^%s+", "")) end
        end
    end
    if not achou then return nil end
    return table.concat(linhas, " <- ")
end

local function RegistrarErro(mensagem, stack)
    if type(mensagem) ~= "string" then return end
    local nossos = NossosQuadros(stack)
    -- The trailing separator matters here: "RocketMount" is a prefix of nothing today, but
    -- `AddOns/RocketMount` would also match a future `RocketMountFoo`.
    local pelaMensagem = mensagem:find("AddOns\\" .. ADDON .. "\\", 1, true)
        or mensagem:find("AddOns/" .. ADDON .. "/", 1, true)
    if not nossos and not pelaMensagem then return end

    local store = Store()
    store.erros = store.erros or {}
    local agora = date("%Y-%m-%d %H:%M:%S")
    for _, e in ipairs(store.erros) do
        if e.mensagem == mensagem then
            e.vezes = (e.vezes or 1) + 1
            e.ultima = agora
            return
        end
    end
    local ultimo = store.entries[#store.entries]
    store.erros[#store.erros + 1] = {
        mensagem = mensagem,
        pilha = nossos,
        vezes = 1,
        primeira = agora,
        ultima = agora,
        versao = store.version,
        combate = InCombatLockdown and InCombatLockdown() and true or false,
        -- WHERE THE DIARY WAS. An error alone says what; with the last line beside it, it
        -- also says when.
        depoisDe = ultimo and (ultimo.time .. " " .. tostring(ultimo.event)) or nil,
    }
    while #store.erros > MAX_ERROS do table.remove(store.erros, 1) end
end

---Turns capture on. Idempotent.
---@return string which way took ("buggrabber", "handler" or "nenhuma")
function Log.CaptureErrors()
    if capturaInstalada then return Store().captura or "nenhuma" end
    capturaInstalada = true
    local store = Store()

    if BugGrabber and BugGrabber.GetErrorByID and EventRegistry then
        EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", function(_, tableID)
            -- `pcall`: this runs INSIDE the handling of an error; blowing up here loses the
            -- original one.
            pcall(function()
                local erro = BugGrabber:GetErrorByID(tableID)
                if erro then RegistrarErro(erro.message, erro.stack) end
            end)
        end, Log)
        store.captura = "buggrabber"
        return store.captura
    end

    if type(seterrorhandler) == "function" then
        local anterior = type(geterrorhandler) == "function" and geterrorhandler() or nil
        local meu
        meu = function(mensagem, ...)
            pcall(RegistrarErro, mensagem, debugstack and debugstack(2) or nil)
            if anterior then return anterior(mensagem, ...) end
        end
        seterrorhandler(meu)
        if type(geterrorhandler) == "function" and geterrorhandler() == meu then
            store.captura = "handler"
            return store.captura
        end
    end

    store.captura = "nenhuma"
    return store.captura
end

function Log.ErrorCount()
    local distintos, total = 0, 0
    for _, e in ipairs(Store().erros or {}) do
        distintos = distintos + 1
        total = total + (e.vezes or 1)
    end
    return distintos, total
end

---The error summary in chat -- and it says whether errors are being captured at all: "no
---error" and "not looking" look the same in silence.
function Log.PrintErrors()
    local distintos, total = Log.ErrorCount()
    local modo = Store().captura or "nenhuma"
    if modo == "nenhuma" then
        ns.Print(L["errors are NOT being captured on this client."])
        return
    end
    if distintos == 0 then
        ns.Print(string.format(L["no error captured (capture: %s)."], modo))
        return
    end
    ns.Print(string.format(L["%d error(s) captured, %d occurrence(s):"], distintos, total))
    for _, e in ipairs(Store().erros or {}) do
        print(string.format("  |cffff5555x%d|r %s", e.vezes or 1, e.mensagem))
        if e.pilha then print("      " .. e.pilha) end
    end
end

function Log.Init()
    local store = Store()
    store.version = C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata(ADDON, "Version") or nil
    store.locale = GetLocale and GetLocale() or nil
    store.started = date("%Y-%m-%d %H:%M:%S")
    -- HERE, and not at PLAYER_LOGIN: an error while the addon loads is exactly the one nobody
    -- sees happen.
    Log.CaptureErrors()
end
