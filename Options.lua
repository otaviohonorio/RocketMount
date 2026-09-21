-- RocketMounts | Options.lua
-- Um lugar só para configurar: Opções > AddOns. A Settings API já traz a métrica de
-- formulário da Blizzard de graça — nenhum SetPoint aqui.
local ADDON, ns = ...

function ns.SetupOptions()
    if ns.category then return end

    local category = Settings.RegisterVerticalLayoutCategory("Rocket Mounts")
    ns.category = category

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

    do
        local name = "Esconder o que este personagem não pode pegar"
        local variable = ADDON .. "HideUnavailable"
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, true,
            function() return ns.db.hideUnavailable end,
            function(value)
                ns.db.hideUnavailable = value
                ns.Invalidate()
            end)

        Settings.CreateCheckbox(category, setting,
            "Montaria de outra facção ou de outra classe sai da lista. " ..
            "Desmarque para ver a coleção inteira.")
    end

    Settings.RegisterAddOnCategory(category)
end
