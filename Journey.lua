-- RocketMount | Journey.lua
--
-- (!) THE SKIN INSPIRED BY THE JOURNEYS TAB (03/11/2026), on trial in the Mount first. The user, with the Adventure
-- Guide's Journeys tab as the example: *"não é para levar ao pé da letra é para ver as cores, textura e etc (...) é
-- inspiração, não copia"*, and on the first preview *"o fundo ali mais laranja tu pegou e esticou e ficou todo
-- deformado, é só criar esse fundo semelhante mas com qualidade"*.
--
-- So NOTHING here stretches an art out of its proportion. Every piece is the game's own art (Blizzard_Journeys.xml,
-- 12.1.5), cut out of its file with the coordinates the game gives (`C_Texture.GetAtlasInfo`) and drawn at its own
-- scale:
--
--   Stone(tex, w, h)   `ui-journeys-bg`, a w x h window of it at one scale (the body of the window, the cards)
--   Card(owner, box)   (04/11) OUR art, one image (tools/arte_cartao.py), inspired by the Journeys renown button.
--                      States: normal, hover (the art added over itself) and selected (the gold frame)
--   Ring(owner, icon)  the round icon in the renown ring (`ui-journeys-renown-radial-bar`)
--   Bar(owner)         the renown progress bar (`ui-journeys-renown-progressbar-bg/fill/frame`), the fill CUT, not
--                      squeezed
--
-- Without `GetAtlasInfo` (an old client, a test) each piece falls back to the plain atlas.
local ADDON, ns = ...

local J = {}
ns.Journey = J

local BUTTON = "ui-journeys-renown-button"
local STONE = "ui-journeys-bg"
local RING = "ui-journeys-renown-radial-bar"
local BAR_BG, BAR_FILL, BAR_FRAME = "ui-journeys-renown-progressbar-bg", "ui-journeys-renown-progressbar-fill",
    "ui-journeys-renown-progressbar-frame"
J.ATLASES = { BUTTON, STONE, RING, BAR_BG, BAR_FILL, BAR_FRAME }

-- The content's margins inside the card (L-054): the frame and its shadow take less than EDGE from each side, the
-- inside starts at INNER. Kept from the card made of the game's button (374 x 112, measured 03/11); the card drawn by
-- tools/arte_cartao.py (04/11) has its frame within ~8 units, so everything placed by these margins stays clear of it.
local EDGE = 15
local INNER = 11
J.EDGE, J.INNER = EDGE, INNER

local infoCache = {}
local function Info(atlas)
    local c = infoCache[atlas]
    if c == nil then
        local ok, i = pcall(function() return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) end)
        c = (ok and type(i) == "table" and (i.file or i.filename) and i.width and i.width > 0) and i or false
        infoCache[atlas] = c
    end
    return c or nil
end
J.Info = Info

---Shows the rectangle (x0, y0)-(x1, y1), in the atlas's own pixels, of `atlas` on `tex`. False when the game did not
---say where the atlas is (the caller falls back to the whole atlas).
local function Cut(tex, atlas, x0, y0, x1, y1, inset)
    local i = Info(atlas)
    if not i then return false end
    if inset then x0, y0, x1, y1 = x0 + inset, y0 + inset, x1 - inset, y1 - inset end
    tex:SetTexture(i.file or i.filename)
    local du, dv = (i.rightTexCoord - i.leftTexCoord) / i.width, (i.bottomTexCoord - i.topTexCoord) / i.height
    tex:SetTexCoord(i.leftTexCoord + du * x0, i.leftTexCoord + du * x1, i.topTexCoord + dv * y0, i.topTexCoord + dv * y1)
    return true
end
J.Cut = Cut

---The window of the stone of size w x h at one scale: the stone's own size when it fits, scaled up the same on both
---axes when the place is bigger than it. `seed` picks a different window for each card.
function J.StoneWindow(w, h, seed)
    local i = Info(STONE)
    local sw, sh = i and i.width or 792, i and i.height or 432
    local s = math.max(1, w / sw, h / sh)
    local cw, ch = w / s, h / s
    local fx, fy = sw - cw, sh - ch
    local k = seed or 0
    local x0 = fx > 0 and (k * 397) % math.floor(fx + 1) or 0
    local y0 = fy > 0 and (k * 211) % math.floor(fy + 1) or 0
    return x0, y0, x0 + cw, y0 + ch
end

function J.Stone(tex, w, h, seed)
    if not (w and h and w > 0 and h > 0) then return end
    local x0, y0, x1, y1 = J.StoneWindow(w, h, seed)
    if not Cut(tex, STONE, x0, y0, x1, y1) then tex:SetAtlas(STONE) end
end

--------------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------------

local CardMixin = {}

-- (04/11) THE CARD IS OUR OWN ART, ONE IMAGE. The user, on the card made of the game's pieces: *"olha na barra a parte
-- direita, tá completamente feia, dá pra ver que foi uma gambiarra, é mais fácil tu criar a arte se inspirando nessa
-- atual e usar ali"*. The layers (stone, amber cut to the right, eight pieces of bevel) showed their seams: a lighter
-- band where the bevel's inside covered the amber, the ramp where the amber began. `tools/arte_cartao.py` draws the
-- card (inspired by the Journeys renown button: chamfered metal frame, warm dark stone, amber with veins on the right)
-- at the row's exact size, 2 pixels per unit, in the top-left of a 2048 x 256 file. Drawn at the box's size: the rows
-- never change size (04/11), and the test holds the box to the art's proportion. Hover: the same art added over itself
-- (the Journeys' `AlphaHighlightButtonTemplate`); selected: the version with the gold frame.
local CARD_FILE = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\Card.png"
local CARD_SELECTED = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\CardSelected.png"
local ART_W, ART_H, FILE_W, FILE_H = 1774, 140, 2048, 256
J.CARD_FILE, J.CARD_SELECTED, J.CARD_ART = CARD_FILE, CARD_SELECTED, { ART_W, ART_H, FILE_W, FILE_H }
local HOVER = 0.25

local function Tex(owner, sub)
    return owner:CreateTexture(nil, "BACKGROUND", nil, sub)
end

---A card drawn on `owner` (its textures are the owner's, under its text), the size of `box` (a frame with no art,
---anchored where the card goes). `amberMax` and `seed` are kept for the callers (one image has no amber of its own
---to place, nor stone to pick).
function J.Card(owner, box, amberMax, seed)
    local c = { owner = owner, box = box, state = "normal" }
    for k, v in pairs(CardMixin) do c[k] = v end
    c.art = Tex(owner, -8)
    c.art:SetAllPoints(box)
    c.art:SetTexCoord(0, ART_W / FILE_W, 0, ART_H / FILE_H)
    c.glow = Tex(owner, -7)
    c.glow:SetAllPoints(box)
    c.glow:SetTexture(CARD_FILE)
    c.glow:SetTexCoord(0, ART_W / FILE_W, 0, ART_H / FILE_H)
    c.glow:SetBlendMode("ADD")
    c.glow:SetAlpha(HOVER)
    c.glow:Hide()
    c:SetState("normal")
    return c
end

---Kept for the callers: the image needs nothing placed when the box changes size.
function CardMixin:Layout() end

---"normal", "hover" or "selected".
function CardMixin:SetState(state)
    self.state = state
    self.art:SetTexture(state == "selected" and CARD_SELECTED or CARD_FILE)
    self.art:SetTexCoord(0, ART_W / FILE_W, 0, ART_H / FILE_H)
    self.glow:SetShown(state == "hover")
end

--------------------------------------------------------------------------------
-- The ring and the bar
--------------------------------------------------------------------------------

---The icon made round and the renown ring around it, `size` across (the icon is the ring's inside).
function J.Ring(owner, icon, size)
    local ring = owner:CreateTexture(nil, "ARTWORK")
    ring:SetAtlas(RING)
    ring:SetSize(size, size)
    ring:SetPoint("CENTER", icon, "CENTER", 0, 0)
    if owner.CreateMaskTexture then
        local mask = owner:CreateMaskTexture()
        if type(mask) == "table" and mask.SetTexture and icon.AddMaskTexture then
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(icon)
            icon:AddMaskTexture(mask)
        end
    end
    return ring
end

local BarMixin = {}

---The renown bar of the Journeys, `w` x `h`; `SetValue(0..1)` cuts the fill (never squeezes it).
function J.Bar(owner, w, h)
    local b = { w = w, h = h }
    for k, v in pairs(BarMixin) do b[k] = v end
    b.bg = owner:CreateTexture(nil, "ARTWORK", nil, 1)
    b.bg:SetAtlas(BAR_BG)
    b.bg:SetSize(w, h)
    b.fill = owner:CreateTexture(nil, "ARTWORK", nil, 2)
    b.fill:SetPoint("LEFT", b.bg, "LEFT", 0, 0)
    b.fill:SetHeight(h)
    b.frame = owner:CreateTexture(nil, "ARTWORK", nil, 3)
    b.frame:SetAtlas(BAR_FRAME)
    b.frame:SetAllPoints(b.bg)
    b:SetValue(0)
    return b
end

function BarMixin:SetPoint(...) self.bg:ClearAllPoints(); self.bg:SetPoint(...) end

function BarMixin:SetShown(on)
    self.bg:SetShown(on); self.frame:SetShown(on); self.fill:SetShown(on and (self.value or 0) > 0)
end

function BarMixin:SetValue(v)
    v = math.max(0, math.min(1, tonumber(v) or 0))
    self.value = v
    if v <= 0 then self.fill:Hide(); return end
    self.fill:SetWidth(math.max(self.w * v, 1))
    local i = Info(BAR_FILL)
    if not (i and Cut(self.fill, BAR_FILL, 0, 0, i.width * v, i.height)) then
        self.fill:SetAtlas(BAR_FILL)
    end
    self.fill:SetShown(self.bg:IsShown() ~= false)
end
