-- RocketMount | Toast.lua
--
-- (21/10) AN ACHIEVEMENT-STYLE ALERT WHEN A MOUNT IS LEARNED. The user: *"poderia fazer um fake
-- conquista quando ganha a montaria"*, showing the game's own alert for Invincible's Reins, and then
-- *"só deixar igual o print e tá ótimo"*: the game's achievement alert, the mount's name and icon in
-- it, the shield with no points (the one of a Feat of Strength, as in the print).
--
-- HOW, and why not the game's alert queue: the frame is the game's own template
-- (`AchievementAlertFrameTemplate`, AlertFrameSystems.xml, 12.1.x) -- its art, fonts and animations --
-- but OUR frame, outside `AlertFrame`. Adding a subsystem to `AlertFrame` (what the game does for its
-- alerts, and Krowi_AchievementFilter for its own) writes our value into the game's list of
-- subsystems; from then on every alert the game shows reads it while anchoring, and the rest of that
-- code runs marked by this addon -- the road that ended in "execution tainted by 'RocketMount'" on
-- the world map (02/10). With no container the template never calls back into `AlertFrame`
-- (`ContainedAlertFrameMixin:OnManagedAlertFrameVisibilityChanged` does nothing without one).
-- It sits ABOVE the game's alerts: the game's "You collected" toast of the same mount takes the first
-- slot over `AlertFrame` (`AlertFrameQueueMixin:AdjustAnchors`: 10 above it, 96 tall).
-- A click closes it (the game's own toast of the mount is the one that opens the journal); over it,
-- the attempts it took when the addon counted them. No sound: the game's toast already plays one.
local ADDON, ns = ...
local L = ns.L

local Toast = {}
ns.Toast = Toast

local TEMPLATE = "AchievementAlertFrameTemplate"
local ABOVE_GAME = 10 + 96 + 14   -- the game's first alert over `AlertFrame`, and some air
local STAY = 6                    -- seconds before fading (the game's achievement alert: 4)
local SHIELD_ATLAS = "ui-achievement-shield-nopoints"

local frame   -- nil: not built yet; false: the template could not be made here

local function Build()
    if frame ~= nil then return frame or nil end
    local ok, f = pcall(CreateFrame, "ContainedAlertFrame", nil, UIParent, TEMPLATE)
    if not (ok and f and f.Name and f.Unlocked and f.Icon and f.Shield and f.animIn and f.waitAndAnimOut) then
        frame = false
        if ns.Log then pcall(ns.Log.Add, "toast", { built = false, error = not ok and tostring(f) or "parts" }) end
        return nil
    end
    f:SetFrameStrata("DIALOG")
    -- The template's click asks the alert container (none here) and opens an achievement by id.
    f:SetScript("OnClick", function(self)
        self.animIn:Stop()
        if self.glow then self.glow.animIn:Stop() end
        if self.shine then self.shine.animIn:Stop() end
        self.waitAndAnimOut:Stop()
        self:Hide()
    end)
    f:SetScript("OnEnter", function(self)
        self.waitAndAnimOut:Stop()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip_SetTitle(GameTooltip, self.mountName or "")
        local tries = ns.Attempts and self.mountID and ns.Attempts.Text(self.mountID)
        if tries then GameTooltip_AddHighlightLine(GameTooltip, tries, true) end
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip_AddInstructionLine(GameTooltip, L["Click: close"], true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self.waitAndAnimOut.animOut:SetStartDelay(1)
        self.waitAndAnimOut:Play()
    end)
    frame = f
    return f
end

---The alert for a mount just learned (NEW_MOUNT_ADDED); `force` shows it with the option off
---(`/rmt toast`, to see how it looks).
function Toast.Show(mountID, force)
    if not (force or (ns.db and ns.db.mountToast ~= false)) or type(mountID) ~= "number" then return false end
    if not (C_MountJournal and C_MountJournal.GetMountInfoByID) then return false end
    local ok, name, _, icon = pcall(C_MountJournal.GetMountInfoByID, mountID)
    if not ok or type(name) ~= "string" or name == "" then return false end
    local f = Build()
    if not f then return false end
    f.mountID, f.mountName = mountID, name

    f.Unlocked:SetText(ACHIEVEMENT_UNLOCKED or L["Achievement Earned"])
    f.Name:SetText(name)
    f.Icon.Texture:SetTexture(icon)
    f.Shield.Icon:SetAtlas(SHIELD_ATLAS, true)
    f.Shield.Icon:Show()
    f.Shield.Points:Hide()
    if f.GuildName then f.GuildName:Hide() end
    if f.GuildBanner then f.GuildBanner:Hide() end
    if f.GuildBorder then f.GuildBorder:Hide() end

    f:ClearAllPoints()
    if AlertFrame then
        f:SetPoint("BOTTOM", AlertFrame, "TOP", 0, ABOVE_GAME)
    else
        f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 128 + ABOVE_GAME)
    end

    f.animIn:Stop()
    f.waitAndAnimOut:Stop()
    f:Show()
    f.animIn:Play()
    if f.glow then f.glow:Show(); f.glow.animIn:Play() end
    if f.shine then f.shine:Show(); f.shine.animIn:Play() end
    f.waitAndAnimOut.animOut:SetStartDelay(STAY)
    f.waitAndAnimOut:Play()
    if ns.Log then pcall(ns.Log.Add, "toast", { mount = mountID }) end
    return true
end

local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "NEW_MOUNT_ADDED")
events:SetScript("OnEvent", function(_, _, mountID)
    -- the count of tries is closed first (Attempts.lua, same event): the tooltip says the last one
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, function() Toast.Show(mountID) end)
    else
        Toast.Show(mountID)
    end
end)

---A mount the player has, for `/rmt toast`: the one whose alert the player would like to see again.
function Toast.AnyCollected()
    if not (C_MountJournal and C_MountJournal.GetMountIDs) then return nil end
    local ok, ids = pcall(C_MountJournal.GetMountIDs)
    for _, id in ipairs(ok and ids or {}) do
        local ok2, _, _, _, _, _, _, _, _, _, _, isCollected = pcall(C_MountJournal.GetMountInfoByID, id)
        if ok2 and isCollected then return id end
    end
    return nil
end

Toast.Build = Build                -- for the tests
function Toast.Reset() frame = nil end
