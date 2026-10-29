-- RocketMount | Options.lua
-- One place only to configure: Options > AddOns. The Settings API already brings Blizzard's
-- form metrics for free -- no SetPoint here.
local ADDON, ns = ...
local L = ns.L

function ns.SetupOptions()
    if ns.category then return end

    local category = Settings.RegisterVerticalLayoutCategory("Rocket Mount")
    ns.category = category

    --[[ O deslizador de tamanho da lista saiu na 0.10.0 junto com o teto de linhas.
    do
        local name = "Tamanho da lista"
        local variable = ADDON .. "TopN"
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Number, name, 100,
            function() return ns.db.topN end,
            function(value)
                ns.db.topN = value
                ns.RefreshWindow()
            end)

        local options = Settings.CreateSliderOptions(10, 400, 10)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value) return string.format("%d linhas", value) end)

        Settings.CreateSlider(category, setting, options,
            "Quantas montarias a lista mostra. O começo da lista é o que interessa: " ..
            "as primeiras já são as mais fáceis.")
    end
    ]]

    do
        -- (!) EVERY LABEL HERE IS SHORT (01/10). The user: *"as opções dos checkboxes estão com
        -- texto muito longo, tem que ser mais simples, resumido e curto, o mouse em cima explica
        -- melhor"*. The panel gives a label about 200 px (180 to a sub-option), and a longer one
        -- was once cut to "Esconder o que este persona..." (screenshot, 23/09). The label names
        -- the thing in two or three words; the tooltip says what it does. The harness holds
        -- every label to 22 letters, in both languages.
        local name = L["Only what I can get"]
        local variable = ADDON .. "HideUnavailable"
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, true,
            function() return ns.db.hideUnavailable end,
            function(value)
                ns.db.hideUnavailable = value
                ns.Invalidate()
            end)

        Settings.CreateCheckbox(category, setting,
            L["A mount from the other faction or another class leaves the list. Uncheck to see the whole collection."])
    end

    do
        local name = L["Minimap button"]
        local variable = ADDON .. "Minimap"
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, true,
            function() return not ns.db.minimap.hide end,
            function(value) ns.SetMinimapHidden(not value) end)

        Settings.CreateCheckbox(category, setting,
            L["The button opens the list with a click and the options with a right-click. Its tooltip already shows the next mount in line."])
    end

    -- (21/10) the achievement-style alert when a mount comes (Toast.lua)
    do
        local setting = Settings.RegisterProxySetting(category, ADDON .. "MountToast",
            Settings.VarType.Boolean, L["Mount achievement"], true,
            function() return ns.db.mountToast ~= false end,
            function(value) ns.db.mountToast = value end)
        Settings.CreateCheckbox(category, setting,
            L["When you learn a mount, an alert like the game's achievement one shows its name and icon. It is the addon's, not a real achievement."])
    end

    do
        local name = L["Rare alert"]
        local variable = ADDON .. "Sightings"
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, true,
            function() return ns.db.sightings ~= false end,
            function(value) ns.db.sightings = value end)

        local aviso = Settings.CreateCheckbox(category, setting,
            L["A rare, elite or world boss that drops a mount you do not have: the alert shows who it is, the mount and the chance. Open world only, and quiet once you looted it."])

        -- (!) THE SOUND OF THE ALERT (01/10): on or off, which one, how loud. The three hang
        -- under the alert's own switch and go grey with it. Choosing a sound or moving the
        -- volume plays it, so the choice is heard and not guessed.
        local filhas = {}
        do
            local s = Settings.RegisterProxySetting(category, ADDON .. "SightingSound",
                Settings.VarType.Boolean, L["Play a sound"], true,
                function() return ns.db.sightingSound ~= false end,
                function(value) ns.db.sightingSound = value end)
            filhas[#filhas + 1] = Settings.CreateCheckbox(category, s,
                L["A short chime when the alert appears. It is the addon's own: no sound of the game is used."])
        end
        if Settings.CreateDropdown and Settings.CreateControlTextContainer then
            local s = Settings.RegisterProxySetting(category, ADDON .. "SightingSoundKey",
                Settings.VarType.String, L["Sound"], ns.Sighting.DEFAULT_SOUND,
                function() return ns.db.sightingSoundKey or ns.Sighting.DEFAULT_SOUND end,
                function(value)
                    ns.db.sightingSoundKey = value
                    ns.Sighting.PlaySound(value, ns.db.sightingVolume)
                end)
            local function Lista()
                local container = Settings.CreateControlTextContainer()
                for _, som in ipairs(ns.Sighting.Sounds()) do container:Add(som.key, som.label) end
                return container:GetData()
            end
            filhas[#filhas + 1] = Settings.CreateDropdown(category, s, Lista,
                L["Which chime the alert plays. Picking one plays it."])
        end
        do
            local s = Settings.RegisterProxySetting(category, ADDON .. "SightingVolume",
                Settings.VarType.Number, L["Volume"], ns.Sighting.DEFAULT_VOLUME,
                function() return ns.db.sightingVolume or ns.Sighting.DEFAULT_VOLUME end,
                function(value)
                    ns.db.sightingVolume = value
                    ns.Sighting.PlaySound(ns.db.sightingSoundKey or ns.Sighting.DEFAULT_SOUND, value)
                end)
            local options = Settings.CreateSliderOptions(20, 100, 20)
            if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
                options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
                    function(value) return string.format("%d%%", value) end)
            end
            filhas[#filhas + 1] = Settings.CreateSlider(category, s, options,
                L["How loud the alert's sound is, in five steps. The game's own sound effects volume still applies."])
        end
        do
            -- (13/10) the rare's place handed to TomTom, when the player has it (Sighting.ToTomTom)
            local s = Settings.RegisterProxySetting(category, ADDON .. "SightingTomTom",
                Settings.VarType.Boolean, L["Send to TomTom"], true,
                function() return ns.db.tomtom ~= false end,
                function(value) ns.db.tomtom = value end)
            filhas[#filhas + 1] = Settings.CreateCheckbox(category, s,
                L["With TomTom installed, the alert also puts the rare's place in it, with its arrow. Without TomTom nothing changes; the pin in the chat is there either way."])
        end
        for _, filha in ipairs(filhas) do
            if type(filha) == "table" and filha.SetParentInitializer and aviso then
                filha:SetParentInitializer(aviso, function() return setting:GetValue() end)
            end
        end
    end

    do
        local name = L["Removed mounts"]
        local variable = ADDON .. "ShowUnobtainable"
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, false,
            function() return ns.db.showUnobtainable end,
            function(value)
                ns.db.showUnobtainable = value
                ns.Invalidate()
            end)

        Settings.CreateCheckbox(category, setting,
            L["Also lists the mounts that left the game: closed promotions, trading card game mounts and retired achievements. They cannot be obtained any more, so they stay out of the list by default."])
    end

    -- (22/10) THE ALERT BEFORE A MOUNT'S EVENT (Events.lua), under its own header: the switch, how many
    -- minutes before, and one box per event -- the user: *"no addon tem que ter a lista desses eventos por
    -- que ele pode querer desativar algum"*. Every box on by default; the event's name is the game's.
    do
        local layout = SettingsPanel and SettingsPanel.GetLayout and SettingsPanel:GetLayout(category)
        if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Mount events"]))
        end
        local mestreSetting = Settings.RegisterProxySetting(category, ADDON .. "EventAlerts",
            Settings.VarType.Boolean, L["Event alert"], true,
            function() return ns.db.eventAlerts ~= false end,
            function(value) ns.db.eventAlerts = value end)
        local mestre = Settings.CreateCheckbox(category, mestreSetting,
            L["A few minutes before an event that leads to a mount you do not have starts: a line in the chat with where it is and a link that points the arrow there, and the alert on the screen if you choose it. Never in combat or inside a dungeon, raid, delve or other instance: it waits, and is dropped if the event starts in the meantime. Quiet once the event's reward of the week is taken."])
        local filhas = {}
        do
            local P = ns.Events and ns.Events.LEAD or { MIN = 1, MAX = 15, STEP = 1, DEFAULT = 5 }
            local s = Settings.RegisterProxySetting(category, ADDON .. "EventLead",
                Settings.VarType.Number, L["Minutes before"], P.DEFAULT,
                function() return tonumber(ns.db.eventLead) or P.DEFAULT end,
                function(value) ns.db.eventLead = value end)
            local options = Settings.CreateSliderOptions(P.MIN, P.MAX, P.STEP)
            if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
                options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
                    function(value) return string.format(L["%dmin"], value) end)
            end
            filhas[#filhas + 1] = Settings.CreateSlider(category, s, options,
                L["How long before the start the alert comes."])
        end
        -- (24/10) the chat only, or the chat and the alert on the screen (the rare's panel). The user: *"isso tudo
        -- configuravel, ou só no chat ou no chat e popup"*.
        if Settings.CreateDropdown and Settings.CreateControlTextContainer then
            local HOW = ns.Events and ns.Events.HOW or { "popup", "chat" }
            local s = Settings.RegisterProxySetting(category, ADDON .. "EventHow",
                Settings.VarType.String, L["How to alert"], HOW[1],
                function() return ns.db.eventHow or HOW[1] end,
                function(value) ns.db.eventHow = value end)
            local function Lista()
                local container = Settings.CreateControlTextContainer()
                container:Add("popup", L["In the chat and on the screen"])
                container:Add("chat", L["In the chat only"])
                return container:GetData()
            end
            filhas[#filhas + 1] = Settings.CreateDropdown(category, s, Lista,
                L["On the screen, the alert is the rare alert's: click it to point the arrow at the event, right-click to close it."])
        end
        -- (29/10) the alert held back by combat or an instance, once the event has started: off by default. The user:
        -- *"por padrão deixa desabilitado, o unico aviso é dos 5 min antes de começar e se o usuário não viu pq estava em
        -- conteúdo ai perde o aviso"*
        do
            local s = Settings.RegisterProxySetting(category, ADDON .. "EventLate",
                Settings.VarType.Boolean, L["Event already started"], false,
                function() return ns.db.eventLate == true end,
                function(value) ns.db.eventLate = value and true or false end)
            filhas[#filhas + 1] = Settings.CreateCheckbox(category, s,
                L["When the alert was held back by combat or an instance and the event started in the meantime: the alert comes once you are free, if the event still has 5 minutes or more to go. Off: only the alert before the start, and one missed in combat or an instance is lost."])
        end
        local COMO = { drop = L["The event's reward can bring it."], currency = L["The event's currency buys it."],
                       renown = L["The event's reputation unlocks it."] }
        for _, e in ipairs(ns.Events and ns.Events.List() or {}) do
            local s = Settings.RegisterProxySetting(category, ADDON .. "Event_" .. e.key,
                Settings.VarType.Boolean, L[e.name], true,
                function() return not (type(ns.db.eventOff) == "table" and ns.db.eventOff[e.key]) end,
                function(value)
                    ns.db.eventOff = type(ns.db.eventOff) == "table" and ns.db.eventOff or {}
                    ns.db.eventOff[e.key] = (not value) or nil
                end)
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
            filhas[#filhas + 1] = Settings.CreateCheckbox(category, s, table.concat(partes, " "))
        end
        for _, filha in ipairs(filhas) do
            if type(filha) == "table" and filha.SetParentInitializer and mestre then
                filha:SetParentInitializer(mestre, function() return mestreSetting:GetValue() end)
            end
        end
    end

    -- THE WORLD MAP, under its own header: four switches about one subject are a section
    -- (wow-ui-design: a section is a subject, and Blizzard marks it with a title, not with air).
    -- The three below the first are its sub-options, and go grey with it.
    do
        local layout = SettingsPanel and SettingsPanel.GetLayout and SettingsPanel:GetLayout(category)
        if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["World map"]))
        end

        local function Caixa(chave, sufixo, nome, dica)
            local setting = Settings.RegisterProxySetting(category, ADDON .. sufixo,
                Settings.VarType.Boolean, nome, true,
                function() return ns.db[chave] ~= false end,
                function(value)
                    ns.db[chave] = value
                    if ns.MapPins then ns.MapPins.Refresh() end
                    -- The button on the map shows the same switch, and is itself an option.
                    if ns.MapButton then ns.MapButton.Update() end
                end)
            return Settings.CreateCheckbox(category, setting, dica), setting
        end

        local mestre, mestreSetting = Caixa("mapPins", "MapPins", L["Markers on the map"],
            L["Every source of a mount you do not have, on the world map: the mount's icon, what kind of source it is, and the chance or how much is left when you hover it. A looted rare goes dim."])
        local filhas = {
            (Caixa("mapSources", "MapSources", L["Vendors and quests"],
                L["Besides the rares, every other place known for a mount you do not have: who sells it, who gives the quest, where the treasure is."])),
            (Caixa("mapInstances", "MapInstances", L["Instance entrances"],
                L["Raid and dungeon entrances, with the mounts that drop inside. The marker steps aside so the game's own entrance icon stays visible."])),
            (Caixa("mapLabels", "MapLabels", L["Source names"],
                L["Writes Rare, Vendor, Quest, Raid… under each marker. Unchecked, the small symbol on the marker still says it."])),
            (Caixa("mapButton", "MapButton", L["Map button"],
                L["A round button with a horseshoe on the world map, in the column of the map's own buttons at the top right. Its menu hides every marker of Rocket Mount, for when you need the map clean, shows only the mounts you are missing, or the collected ones too, with a gold ring."])),
            (Caixa("minimapPins", "MinimapPins", L["On the minimap"],
                L["Marks the places within the minimap's reach too, each with the symbol of what it is: a rare, a vendor, a treasure. Hover one for the same details as on the world map; click it to point the arrow there."])),
            (Caixa("mapRoutes", "MapRoutes", L["Rare routes"],
                L["A rare that patrols gets one marker and a dashed line along where it was seen. The route is an estimate from players' sightings. Unchecked, only the marker is drawn."])),
        }
        -- THE SIZE OF THE MARKERS (02/10): 80% to 150% of the game's quest pin, in steps of 10.
        do
            local P = ns.MapPins and ns.MapPins.PIN_SCALE or { MIN = 80, MAX = 150, STEP = 10, DEFAULT = 100 }
            local s = Settings.RegisterProxySetting(category, ADDON .. "MapPinScale",
                Settings.VarType.Number, L["Marker size"], P.DEFAULT,
                function() return tonumber(ns.db.mapPinScale) or P.DEFAULT end,
                function(value)
                    ns.db.mapPinScale = value
                    if ns.MapPins then ns.MapPins.Refresh() end
                end)
            local options = Settings.CreateSliderOptions(P.MIN, P.MAX, P.STEP)
            if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
                options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
                    function(value) return string.format("%d%%", value) end)
            end
            filhas[#filhas + 1] = Settings.CreateSlider(category, s, options,
                L["How large the markers are on the world map. 100% is the size of the game's own quest marker."])
        end
        -- And of the ones on the MINIMAP, with the same limits.
        do
            local P = ns.MinimapPins and ns.MinimapPins.PIN_SCALE or { MIN = 80, MAX = 150, STEP = 10, DEFAULT = 100 }
            local s = Settings.RegisterProxySetting(category, ADDON .. "MinimapPinScale",
                Settings.VarType.Number, L["Size on the minimap"], P.DEFAULT,
                function() return tonumber(ns.db.minimapPinScale) or P.DEFAULT end,
                function(value)
                    ns.db.minimapPinScale = value
                    if ns.MinimapPins then ns.MinimapPins.Refresh() end
                end)
            local options = Settings.CreateSliderOptions(P.MIN, P.MAX, P.STEP)
            if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
                options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
                    function(value) return string.format("%d%%", value) end)
            end
            filhas[#filhas + 1] = Settings.CreateSlider(category, s, options,
                L["How large the markers are on the minimap."])
        end
        -- The game's own way of hanging an option under another (Blizzard_SettingControls.lua:
        -- `SetParentInitializer`, the 15 px indent); older clients simply list them.
        for _, filha in ipairs(filhas) do
            if type(filha) == "table" and filha.SetParentInitializer and mestre then
                filha:SetParentInitializer(mestre, function() return mestreSetting:GetValue() end)
            end
        end
    end

    -- (!) NO SUPPORT ROW HERE (28/09). The panel had a "Support" section with the donation and
    -- the report links. The user: *"sobre a parte de apoiar dos addons, somente na janela do addon
    -- e não na aba de addons da janela da blizzard, pode remover esse"*. They live at the bottom
    -- of the addon's own window (Donate.lua, `ns.DonateFooter`), and nowhere else.

    Settings.RegisterAddOnCategory(category)
end
