-- RocketMount | Options.lua
-- WHAT can be configured, as data: one list of definitions that the window's Settings tab draws (OptionsTab.lua).
-- (!) NOT IN THE GAME'S PANEL ANY MORE (03/11/2026). The user: *"não queria ter as configurações dos addons no menu
-- opções aba addons, poderia ter na propria janela dos addons, nessa tela em opções addons, só abre a janela com as
-- configurações do addon"*. Options > AddOns now only holds a button that opens the window on this tab
-- (OptionsEntry.lua).
--
-- (!) EVERY LABEL HERE IS SHORT (01/10). The user: *"as opções dos checkboxes estão com texto muito longo, tem que
-- ser mais simples, resumido e curto, o mouse em cima explica melhor"*. The label names the thing in two or three
-- words; the tooltip says what it does. The harness holds every label to 22 letters, in both languages.
--
-- Definition: { key, kind = "checkbox" | "slider" | "dropdown", name, tip, default, get, set, parent = key of the
-- option it hangs under (greyed while that one is off), min, max, step, format, entries = function -> {{value,label}} }.
-- Sections: { section = title, column = n }.
local ADDON, ns = ...
local L = ns.L

local defs

local function Build()
    local list = {}
    local function Section(title, column) list[#list + 1] = { section = title, column = column } end
    local function Add(d)
        d.key = ADDON .. d.key
        if d.parent then d.parent = ADDON .. d.parent end
        list[#list + 1] = d
        return d
    end

    -- Column 1: the list and the rare alert ---------------------------------------------------------------
    Section(GENERAL, 1)
    Add({ key = "HideUnavailable", kind = "checkbox", name = L["Only what I can get"], default = true,
        tip = L["A mount from the other faction or another class leaves the list. Uncheck to see the whole collection."],
        get = function() return ns.db.hideUnavailable end,
        set = function(v) ns.db.hideUnavailable = v; ns.Invalidate() end })
    Add({ key = "ShowUnobtainable", kind = "checkbox", name = L["Removed mounts"], default = false,
        tip = L["Also lists the mounts that left the game: closed promotions, trading card game mounts and retired achievements. They cannot be obtained any more, so they stay out of the list by default."],
        get = function() return ns.db.showUnobtainable end,
        set = function(v) ns.db.showUnobtainable = v; ns.Invalidate() end })
    Add({ key = "Minimap", kind = "checkbox", name = L["Minimap button"], default = true,
        tip = L["The button opens the list with a click and the options with a right-click. Its tooltip already shows the next mount in line."],
        get = function() return not ns.db.minimap.hide end,
        set = function(v) ns.SetMinimapHidden(not v) end })
    -- (21/10) the achievement-style alert when a mount comes (Toast.lua)
    Add({ key = "MountToast", kind = "checkbox", name = L["Mount achievement"], default = true,
        tip = L["When you learn a mount, an alert like the game's achievement one shows its name and icon. It is the addon's, not a real achievement."],
        get = function() return ns.db.mountToast ~= false end,
        set = function(v) ns.db.mountToast = v end })

    Section(L["Rare alert"], 1)
    Add({ key = "Sightings", kind = "checkbox", name = L["Rare alert"], default = true,
        tip = L["A rare, elite or world boss that drops a mount you do not have: the alert shows who it is, the mount and the chance. Open world only, and quiet once you looted it."],
        get = function() return ns.db.sightings ~= false end,
        set = function(v) ns.db.sightings = v end })
    -- (!) THE SOUND OF THE ALERT (01/10): on or off, which one, how loud. They hang under the alert's own switch
    -- and go grey with it. Choosing a sound or moving the volume plays it, so the choice is heard and not guessed.
    Add({ key = "SightingSound", kind = "checkbox", name = L["Play a sound"], default = true, parent = "Sightings",
        tip = L["A short chime when the alert appears. It is the addon's own: no sound of the game is used."],
        get = function() return ns.db.sightingSound ~= false end,
        set = function(v) ns.db.sightingSound = v end })
    Add({ key = "SightingSoundKey", kind = "dropdown", name = L["Sound"], default = ns.Sighting.DEFAULT_SOUND,
        parent = "Sightings", tip = L["Which chime the alert plays. Picking one plays it."],
        entries = function()
            local out = {}
            for _, som in ipairs(ns.Sighting.Sounds()) do out[#out + 1] = { value = som.key, label = som.label } end
            return out
        end,
        get = function() return ns.db.sightingSoundKey or ns.Sighting.DEFAULT_SOUND end,
        set = function(v)
            ns.db.sightingSoundKey = v
            ns.Sighting.PlaySound(v, ns.db.sightingVolume)
        end })
    Add({ key = "SightingVolume", kind = "slider", name = L["Volume"], default = ns.Sighting.DEFAULT_VOLUME,
        parent = "Sightings", min = 20, max = 100, step = 20, format = "%d%%",
        tip = L["How loud the alert's sound is, in five steps. The game's own sound effects volume still applies."],
        get = function() return ns.db.sightingVolume or ns.Sighting.DEFAULT_VOLUME end,
        set = function(v)
            ns.db.sightingVolume = v
            ns.Sighting.PlaySound(ns.db.sightingSoundKey or ns.Sighting.DEFAULT_SOUND, v)
        end })
    -- (13/10) the rare's place handed to TomTom, when the player has it (Sighting.ToTomTom)
    Add({ key = "SightingTomTom", kind = "checkbox", name = L["Send to TomTom"], default = true, parent = "Sightings",
        tip = L["With TomTom installed, the alert also puts the rare's place in it, with its arrow. Without TomTom nothing changes; the pin in the chat is there either way."],
        get = function() return ns.db.tomtom ~= false end,
        set = function(v) ns.db.tomtom = v end })

    -- Column 2: the world map ------------------------------------------------------------------------------------
    -- Four switches about one subject are a section (wow-ui-design: a section is a subject, marked by a title).
    Section(L["World map"], 2)
    local function MapCheck(dbKey, key, name, tip, parent)
        return Add({ key = key, kind = "checkbox", name = name, tip = tip, default = true, parent = parent,
            get = function() return ns.db[dbKey] ~= false end,
            set = function(v)
                ns.db[dbKey] = v
                if ns.MapPins then ns.MapPins.Refresh() end
                -- The button on the map shows the same switch, and is itself an option.
                if ns.MapButton then ns.MapButton.Update() end
            end })
    end
    MapCheck("mapPins", "MapPins", L["Markers on the map"],
        L["Every source of a mount you do not have, on the world map: the mount's icon, what kind of source it is, and the chance or how much is left when you hover it. A looted rare goes dim."])
    MapCheck("mapSources", "MapSources", L["Vendors and quests"],
        L["Besides the rares, every other place known for a mount you do not have: who sells it, who gives the quest, where the treasure is."], "MapPins")
    MapCheck("mapInstances", "MapInstances", L["Instance entrances"],
        L["Raid and dungeon entrances, with the mounts that drop inside. The marker steps aside so the game's own entrance icon stays visible."], "MapPins")
    MapCheck("mapLabels", "MapLabels", L["Source names"],
        L["Writes Rare, Vendor, Quest, Raid… under each marker. Unchecked, the small symbol on the marker still says it."], "MapPins")
    MapCheck("mapButton", "MapButton", L["Map button"],
        L["A round button with a horseshoe on the world map, in the column of the map's own buttons at the top right. Its menu hides every marker of Rocket Mount, for when you need the map clean, shows only the mounts you are missing, or the collected ones too, with a gold ring."], "MapPins")
    MapCheck("minimapPins", "MinimapPins", L["On the minimap"],
        L["Marks the places within the minimap's reach too, each with the symbol of what it is: a rare, a vendor, a treasure. Hover one for the same details as on the world map; click it to point the arrow there."], "MapPins")
    MapCheck("mapRoutes", "MapRoutes", L["Rare routes"],
        L["A rare that patrols gets one marker and a dashed line along where it was seen. The route is an estimate from players' sightings. Unchecked, only the marker is drawn."], "MapPins")
    -- THE SIZE OF THE MARKERS (02/10): 80% to 150% of the game's quest pin, in steps of 10.
    do
        local P = ns.MapPins and ns.MapPins.PIN_SCALE or { MIN = 80, MAX = 150, STEP = 10, DEFAULT = 100 }
        Add({ key = "MapPinScale", kind = "slider", name = L["Marker size"], default = P.DEFAULT, parent = "MapPins",
            min = P.MIN, max = P.MAX, step = P.STEP, format = "%d%%",
            tip = L["How large the markers are on the world map. 100% is the size of the game's own quest marker."],
            get = function() return tonumber(ns.db.mapPinScale) or P.DEFAULT end,
            set = function(v)
                ns.db.mapPinScale = v
                if ns.MapPins then ns.MapPins.Refresh() end
            end })
    end
    do
        local P = ns.MinimapPins and ns.MinimapPins.PIN_SCALE or { MIN = 80, MAX = 150, STEP = 10, DEFAULT = 100 }
        Add({ key = "MinimapPinScale", kind = "slider", name = L["Size on the minimap"], default = P.DEFAULT,
            parent = "MapPins", min = P.MIN, max = P.MAX, step = P.STEP, format = "%d%%",
            tip = L["How large the markers are on the minimap."],
            get = function() return tonumber(ns.db.minimapPinScale) or P.DEFAULT end,
            set = function(v)
                ns.db.minimapPinScale = v
                if ns.MinimapPins then ns.MinimapPins.Refresh() end
            end })
    end

    -- Column 3: the alert before a mount's event (Events.lua) ---------------------------------------------------
    -- (22/10) the switch, how many minutes before, and one box per event -- the user: *"no addon tem que ter a lista
    -- desses eventos por que ele pode querer desativar algum"*. Every box on by default; the event's name is the game's.
    Section(L["Mount events"], 3)
    Add({ key = "EventAlerts", kind = "checkbox", name = L["Event alert"], default = true,
        tip = L["A few minutes before an event that leads to a mount you do not have starts: a line in the chat with where it is and a link that points the arrow there, and the alert on the screen if you choose it. Never in combat or inside a dungeon, raid, delve or other instance: it waits, and is dropped if the event starts in the meantime. Quiet once the event's reward of the week is taken."],
        get = function() return ns.db.eventAlerts ~= false end,
        set = function(v) ns.db.eventAlerts = v end })
    do
        local P = ns.Events and ns.Events.LEAD or { MIN = 1, MAX = 15, STEP = 1, DEFAULT = 5 }
        Add({ key = "EventLead", kind = "slider", name = L["Minutes before"], default = P.DEFAULT, parent = "EventAlerts",
            min = P.MIN, max = P.MAX, step = P.STEP, format = L["%dmin"],
            tip = L["How long before the start the alert comes."],
            get = function() return tonumber(ns.db.eventLead) or P.DEFAULT end,
            set = function(v) ns.db.eventLead = v end })
    end
    -- (24/10) the chat only, or the chat and the alert on the screen. The user: *"isso tudo configuravel, ou só no
    -- chat ou no chat e popup"*.
    do
        local HOW = ns.Events and ns.Events.HOW or { "popup", "chat" }
        Add({ key = "EventHow", kind = "dropdown", name = L["How to alert"], default = HOW[1], parent = "EventAlerts",
            tip = L["On the screen, the alert is the rare alert's: click it to point the arrow at the event, right-click to close it."],
            entries = function()
                return { { value = "popup", label = L["In the chat and on the screen"] },
                         { value = "chat", label = L["In the chat only"] } }
            end,
            get = function() return ns.db.eventHow or HOW[1] end,
            set = function(v) ns.db.eventHow = v end })
    end
    -- (29/10) the alert held back by combat or an instance, once the event has started: off by default. The user:
    -- *"por padrão deixa desabilitado, o unico aviso é dos 5 min antes de começar"*
    Add({ key = "EventLate", kind = "checkbox", name = L["Event already started"], default = false, parent = "EventAlerts",
        tip = L["When the alert was held back by combat or an instance and the event started in the meantime: the alert comes once you are free, if the event still has 5 minutes or more to go. Off: only the alert before the start, and one missed in combat or an instance is lost."],
        get = function() return ns.db.eventLate == true end,
        set = function(v) ns.db.eventLate = v and true or false end })
    local COMO = { drop = L["The event's reward can bring it."], currency = L["The event's currency buys it."],
                   renown = L["The event's reputation unlocks it."] }
    for _, e in ipairs(ns.Events and ns.Events.List() or {}) do
        -- the tooltip: where, the mounts (named by the game) and how the event leads to them
        local nomes = {}
        for _, id in ipairs(e.mounts or {}) do
            local ok, nome = pcall(C_MountJournal and C_MountJournal.GetMountInfoByID or error, id)
            if ok and type(nome) == "string" then nomes[#nomes + 1] = nome end
        end
        local partes = {}
        local zona = ns.Events.Zone(e)
        if zona then partes[#partes + 1] = zona .. "." end
        if #nomes > 0 then partes[#partes + 1] = string.format(L["Mounts: %s."], table.concat(nomes, ", ")) end
        partes[#partes + 1] = COMO[e.how]
        Add({ key = "Event_" .. e.key, kind = "checkbox", name = L[e.name], default = true, parent = "EventAlerts",
            tip = table.concat(partes, " "),
            get = function() return not (type(ns.db.eventOff) == "table" and ns.db.eventOff[e.key]) end,
            set = function(v)
                ns.db.eventOff = type(ns.db.eventOff) == "table" and ns.db.eventOff or {}
                ns.db.eventOff[e.key] = (not v) or nil
            end })
    end

    -- (!) NO SUPPORT ROW HERE (28/09): the donation and the report links live at the bottom of the window
    -- (Donate.lua, `ns.DonateFooter`), and nowhere else.
    return list
end

---Every definition, built once (after the saved variables exist).
function ns.OptionDefs()
    defs = defs or Build()
    return defs
end

---Kept for the loader in Core.lua: the definitions are made when the saved variables are ready.
function ns.SetupOptions()
    ns.OptionDefs()
end
