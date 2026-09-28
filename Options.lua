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
        -- Short on purpose: the Settings panel gives a label ~200px, and the longer version was
        -- cut to "Esconder o que este persona..." (screenshot, 23/09).
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
        local name = L["Show the minimap button"]
        local variable = ADDON .. "Minimap"
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, true,
            function() return not ns.db.minimap.hide end,
            function(value) ns.SetMinimapHidden(not value) end)

        Settings.CreateCheckbox(category, setting,
            L["The button opens the list with a click and the options with a right-click. Its tooltip already shows the next mount in line."])
    end

    do
        local name = L["Alert on mount rares"]
        local variable = ADDON .. "Sightings"
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, true,
            function() return ns.db.sightings ~= false end,
            function(value) ns.db.sightings = value end)

        Settings.CreateCheckbox(category, setting,
            L["A rare, elite or world boss that drops a mount you do not have: the alert shows who it is, the mount and the chance. Open world only, and quiet once you looted it."])
    end

    do
        local name = L["Show the ones that left the game"]
        local variable = ADDON .. "ShowUnobtainable"
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, false,
            function() return ns.db.showUnobtainable end,
            function(value)
                ns.db.showUnobtainable = value
                ns.Invalidate()
            end)

        Settings.CreateCheckbox(category, setting,
            L["Closed promotions, trading card game mounts and retired achievements. They cannot be obtained any more, so they stay out of the list by default."])
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

        local mestre, mestreSetting = Caixa("mapPins", "MapPins", L["Show them on the world map"],
            L["Every source of a mount you do not have, on the world map: the mount's icon, what kind of source it is, and the chance or how much is left when you hover it. A looted rare goes dim."])
        local filhas = {
            (Caixa("mapSources", "MapSources", L["Vendors, quests and treasures too"],
                L["Every place the collection data knows for a mount you do not have: who sells it, who gives the quest, where the treasure is."])),
            (Caixa("mapInstances", "MapInstances", L["Raid and dungeon entrances too"],
                L["The mounts that drop inside, at the entrance. The marker steps aside so the game's own entrance icon stays visible."])),
            (Caixa("mapLabels", "MapLabels", L["Name the source under each marker"],
                L["Rare, Vendor, Quest, Raid… under the mount's icon. Unchecked, the small symbol on the marker still says it."])),
            (Caixa("mapButton", "MapButton", L["A button on the map to hide and show them"],
                L["A round button with a horseshoe, in the column of the map's own buttons at the top right. One click hides every marker of Rocket Mount, for when you need the map clean; another brings them back."])),
            (Caixa("minimapPins", "MinimapPins", L["On the minimap too"],
                L["The places within the minimap's reach, each with the symbol of what it is: a rare, a vendor, a treasure. Hover one for the same details as on the world map; click it to point the arrow there."])),
            (Caixa("mapRoutes", "MapRoutes", L["Draw the route of a creature that walks"],
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
