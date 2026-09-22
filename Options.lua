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

    do
        local name = "Mostrar o botão no minimapa"
        local variable = ADDON .. "Minimap"
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, true,
            function() return not ns.db.minimap.hide end,
            function(value) ns.SetMinimapHidden(not value) end)

        Settings.CreateCheckbox(category, setting,
            "O botão abre a lista com um clique e as opções com o botão direito. " ..
            "A dica dele já mostra a próxima montaria da fila.")
    end

    do
        local name = "Mostrar as que saíram do jogo"
        local variable = ADDON .. "ShowUnobtainable"
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, false,
            function() return ns.db.showUnobtainable end,
            function(value)
                ns.db.showUnobtainable = value
                ns.Invalidate()
            end)

        Settings.CreateCheckbox(category, setting,
            "Promoções encerradas, montarias de jogo de cartas e conquistas aposentadas. " ..
            "Elas não podem mais ser conseguidas, então ficam fora da lista por padrão.")
    end

    Settings.RegisterAddOnCategory(category)
end
