-- RocketMounts | Skin.lua
-- Fonte única de verdade da aparência. Painel novo que copia valor da janela
-- diverge na terceira mudança; toda tela deste addon lê daqui.
local _, ns = ...

local FONT = "Fonts\\FRIZQT__.TTF"

ns.Skin = {
    font = FONT,

    -- Escada tipográfica do jogo (Fonts.xml): 20 / 16 / 14 / 12 / 10.
    titleFontSize = 14,
    rowFontSize   = 12,
    subFontSize   = 10,
    headFontSize  = 12,

    -- Ritmo de LINHA DE DADOS (medidor nativo): 25 de tinta + 4 de respiro = 29.
    -- Não é o ritmo de formulário (26 + 9 = 35) — este aqui é lista, não campo.
    -- A tinta sobe de 25 para 36 porque a linha daqui tem DUAS: o nome e o motivo de
    -- ela estar nessa posição. 12pt + 10pt + respiro não cabem em 25. O respiro de 4
    -- entre linhas fica como está — é ele que dá o ritmo, não a altura da tinta.
    rowHeight  = 36,
    rowSpacing = 4,

    -- Bloco de cabeçalho de seção da Blizzard: 45px com o título a y=-16, o que
    -- deixa 25 de branco acima. Aqui a seção é mais leve (é lista, não formulário),
    -- mas a razão se mantém: o vão de seção tem que ser >= 2x o vão de linha.
    sectionHeight = 22,
    sectionGap    = 12,

    -- Margens do conteúdo (Blizzard_SettingsList.lua:44-45).
    padding     = 10,
    leftMargin  = 12,

    -- Painel de leitura pede fundo: sem ele o texto disputa com o cenário.
    panelAlpha = 0.92,
    rowBackground     = { 1, 1, 1, 0.045 },
    rowBackgroundHl   = { 1, 1, 1, 0.12 },
    rowBackgroundSel  = { 1, 0.82, 0, 0.14 },

    gold  = { 1, 0.82, 0 },
    text  = { 0.86, 0.87, 0.90 },
    cream = { 1, 0.96, 0.86 },
    dim   = { 0.55, 0.55, 0.58 },

    headerAtlas = "ui-damagemeters-header-bar",
    -- Recorte que a skin Midnight do Details usa para tirar o padding transparente.
    headerCrop  = { 0.045, 0.965, 4 / 60, 56 / 60 },
    headerHeight = 32,
}

-- Cor de cada faixa de esforço. Não é cor de classe e não disputa com ela:
-- verde/azul/amarelo/laranja/cinza é o vocabulário de dificuldade, não de identidade.
ns.TIER_COLOR = {
    { 0.30, 0.85, 0.40 },   -- 1 pronto
    { 0.45, 0.78, 0.95 },   -- 2 quase lá
    { 0.94, 0.80, 0.25 },   -- 3 em andamento
    { 0.95, 0.60, 0.25 },   -- 4 farm curto
    { 0.85, 0.35, 0.35 },   -- 5 farm longo
    { 0.55, 0.55, 0.58 },   -- 6 sem estimativa
}

function ns.ApplyHeaderArt(texture)
    local info = C_Texture and C_Texture.GetAtlasInfo
        and C_Texture.GetAtlasInfo(ns.Skin.headerAtlas)

    if info and (info.file or info.filename) then
        texture:SetTexture(info.file or info.filename)
        local l, r = info.leftTexCoord or 0, info.rightTexCoord or 1
        local t, b = info.topTexCoord or 0, info.bottomTexCoord or 1
        local w, h = r - l, b - t
        local crop = ns.Skin.headerCrop
        texture:SetTexCoord(l + w * crop[1], l + w * crop[2], t + h * crop[3], t + h * crop[4])
        texture:SetVertexColor(1, 1, 1)
        return true
    end

    -- `SetAtlas` falha em silêncio; o fallback é explícito de propósito.
    texture:SetColorTexture(0.13, 0.11, 0.07, 0.95)
    return false
end

-- FontString sem template nasce sem fonte, e o SetText responde
-- "Font not set" — que costuma aparecer como "cliquei e não abriu".
function ns.NewText(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetFont(ns.Skin.font, size or ns.Skin.rowFontSize, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    local c = color or ns.Skin.text
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH(justify or "LEFT")
    return fs
end
