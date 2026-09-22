-- RocketMounts | Options.lua
-- Um lugar só para configurar: Opções > AddOns. A Settings API já traz a métrica de
-- formulário da Blizzard de graça — nenhum SetPoint aqui.
local ADDON, ns = ...
local L = ns.L

function ns.SetupOptions()
    if ns.category then return end

    local category = Settings.RegisterVerticalLayoutCategory("Rocket Mounts")
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
        local name = L["Hide what this character cannot get"]
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
        local name = L["Warn when you see something that drops a mount"]
        local variable = ADDON .. "Sightings"
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, true,
            function() return ns.db.sightings ~= false end,
            function(value) ns.db.sightings = value end)

        Settings.CreateCheckbox(category, setting,
            L["Shows up on target, mouseover or when the rare yells — and only for a mount you do not have yet. A link comes in chat to mark where you saw it."])
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

    Settings.RegisterAddOnCategory(category)
end
