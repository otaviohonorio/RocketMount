-- RocketMount | Options.lua
-- Um lugar só para configurar: Opções > AddOns. A Settings API já traz a métrica de
-- formulário da Blizzard de graça — nenhum SetPoint aqui.
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
                L["A round button with a horseshoe on the world map, in the column of the map's own buttons at the top right. One click hides every marker of Rocket Mount, for when you need the map clean; another brings them back."])),
            (Caixa("minimapPins", "MinimapPins", L["On the minimap"],
                L["Marks the places within the minimap's reach too, each with the symbol of what it is: a rare, a vendor, a treasure. Hover one for the same details as on the world map; click it to point the arrow there."])),
            (Caixa("mapRoutes", "MapRoutes", L["Rare routes"],
                L["A rare that patrols gets one marker and a dashed line along where it was seen. The route is an estimate from players' sightings. Unchecked, only the marker is drawn."])),
        }
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
