-- ============================================================
--  NECO ARC APOCALYPSE — cl_init.lua (CLIENT)
-- ============================================================
DeriveGamemode("base")
GM.Name   = "Neco Arc Apocalypse"
GM.Author = "NAA"

include("shared.lua")
include("cl_hud.lua")
include("cl_menu.lua")
include("cl_upgrades.lua")
include("cl_shop.lua")
include("cl_death.lua")
include("cl_metashop.lua")
include("cl_devmode.lua")

-- ============================================================
--  CLIENT STATE
-- ============================================================
NAA.ClientPhase       = NAA.PHASE_LOBBY
NAA.ClientWave        = 0
NAA.ClientEnemies     = 0
NAA.ClientDifficulty  = "normal"
NAA.ClientCoins       = 0
NAA.ClientLives       = 5
NAA.ClientUpgrades    = {}
NAA.ClientSynergies   = {}
NAA.MetaData          = { neo_coins = 0, unlocks = {} }
NAA.BetweenWaveEnd    = 0
NAA.HunterStacks      = 0
NAA.BossAlertWave     = 0
NAA.BossAlertTimer    = 0
NAA.StreakMsg         = ""
NAA.StreakTimer       = 0
NAA.NotifMsg          = ""
NAA.NotifTimer        = 0
NAA.SynergyAlertName  = ""
NAA.SynergyAlertDesc  = ""
NAA.SynergyAlertTimer = 0
NAA.KillFeed          = {}
NAA.HitMarkers        = {}
NAA.Scores            = {}
NAA.RunResult         = {}
NAA.ClientEvent       = "normal"
NAA.LobbyData         = {}
NAA.ClassStateData    = {}
NAA.DiffVoteData      = { votes={}, players={}, countdown=0 }
NAA.UpgradePending    = {}

-- ============================================================
--  NET RECEIVERS
-- ============================================================

-- Смена фазы
net.Receive("NAA_Phase", function()
    local phase = net.ReadString()
    local wave  = net.ReadInt(16)
    local diff  = net.ReadString()
    NAA.ClientPhase      = phase
    NAA.ClientWave       = wave
    NAA.ClientDifficulty = diff

    hook.Run("NAA_PhaseChanged", phase)

    if phase == NAA.PHASE_LOBBY        then pcall(NAA_ShowMenu)        end
    if phase == NAA.PHASE_CLASS_SELECT then pcall(NAA_ShowClassSelect) end
    if phase == NAA.PHASE_DIFF_SELECT  then pcall(NAA_ShowDiffSelect)  end
    if phase == NAA.PHASE_GAME_OVER    then pcall(NAA_ShowDeath)       end

    if phase == NAA.PHASE_WAVE then
        if IsValid(NAA.ActivePanel)  then NAA.ActivePanel:Remove();  NAA.ActivePanel  = nil end
        if IsValid(NAA.UpgradePanel) then NAA.UpgradePanel:Remove(); NAA.UpgradePanel = nil end
        NAA.UpgradePending = {}
    end
end)

-- Таймер между волнами
net.Receive("NAA_BetweenWaveTimer", function()
    local dur = net.ReadInt(8)
    NAA.BetweenWaveEnd = CurTime() + dur
end)

-- Обновление волны/врагов
net.Receive("NAA_WaveUpdate", function()
    NAA.ClientWave    = net.ReadInt(16)
    NAA.ClientEnemies = net.ReadInt(16)
    NAA.ClientEvent   = net.ReadString()
end)

-- Монеты
net.Receive("NAA_SyncCoins", function()
    NAA.ClientCoins = net.ReadInt(16)
end)

-- Жизни
net.Receive("NAA_SyncLives", function()
    NAA.ClientLives = net.ReadInt(16)
end)

-- Апгрейды
net.Receive("NAA_UpgradeList", function()
    local json = net.ReadString()
    NAA.ClientUpgrades = util.JSONToTable(json) or {}
    local classId = LocalPlayer():GetNWString("NAA_Class", "survivor")
    NAA.ClientSynergies  = NAA.GetActiveSynergies(NAA.ClientUpgrades, classId)
    NAA.ClientExtraJumps = NAA.ClientUpgrades.double_jump or 0
end)

-- Мета-данные
net.Receive("NAA_MetaData", function()
    NAA.MetaData = util.JSONToTable(net.ReadString()) or { neo_coins=0, unlocks={} }
end)

-- Boss alert
net.Receive("NAA_BossAlert", function()
    NAA.BossAlertWave  = net.ReadInt(16)
    NAA.BossAlertTimer = CurTime() + 6
    surface.PlaySound("ambient/levels/labs/electric_explosion4.wav")
end)

-- Kill feed
net.Receive("NAA_KillFeed", function()
    NAA.KillFeed = NAA.KillFeed or {}
    local name = net.ReadString()
    local typ  = net.ReadString()
    table.insert(NAA.KillFeed, 1, { name=name, typ=typ, t=CurTime() })
    while #NAA.KillFeed > 8 do table.remove(NAA.KillFeed) end
end)

-- Kill streak
net.Receive("NAA_KillStreak", function()
    NAA.StreakMsg   = net.ReadString()
    NAA.StreakTimer = CurTime() + 4
    surface.PlaySound("buttons/button14.wav")
end)

-- Hit marker
net.Receive("NAA_HitMarker", function()
    local isCrit = net.ReadBool()
    NAA.HitMarkers = NAA.HitMarkers or {}
    table.insert(NAA.HitMarkers, { t = CurTime() + 0.2, crit = isCrit })
    while #NAA.HitMarkers > 20 do table.remove(NAA.HitMarkers, 1) end
end)

-- Scores
net.Receive("NAA_Scores", function()
    NAA.Scores = util.JSONToTable(net.ReadString()) or {}
end)

-- Between wave notification
net.Receive("NAA_BetweenWave", function()
    NAA.NotifMsg   = net.ReadString()
    NAA.NotifTimer = CurTime() + 5
end)

-- Special alert
net.Receive("NAA_SpecialAlert", function()
    NAA.NotifMsg   = net.ReadString()
    NAA.NotifTimer = CurTime() + 4
end)

-- Synergy unlock alert
net.Receive("NAA_SynergyAlert", function()
    NAA.SynergyAlertName  = net.ReadString()
    NAA.SynergyAlertDesc  = net.ReadString()
    NAA.SynergyAlertTimer = CurTime() + 6
    surface.PlaySound("buttons/button14.wav")
end)

-- Hunter stacks
net.Receive("NAA_HunterStacks", function()
    NAA.HunterStacks = net.ReadInt(16)
end)

-- Run result
net.Receive("NAA_RunResult", function()
    NAA.RunResult = util.JSONToTable(net.ReadString()) or {}
    pcall(NAA_ShowDeath)
end)

-- ============================================================
--  МУЛЬТИПЛЕЕР: состояние лобби
-- ============================================================
net.Receive("NAA_LobbyState", function()
    local data = util.JSONToTable(net.ReadString()) or {}
    NAA.LobbyData = data.players or {}
    -- Обновляем отображение если панель открыта
    if IsValid(NAA.LobbyPanel) then
        NAA.LobbyPanel:InvalidateLayout(true)
    end
end)

-- Состояние выбора класса
net.Receive("NAA_ClassState", function()
    local data = util.JSONToTable(net.ReadString()) or {}
    NAA.ClassStateData = data.players or {}
    if IsValid(NAA.ClassPanel) then
        NAA.ClassPanel:InvalidateLayout(true)
    end
end)

-- Состояние голосования за сложность
net.Receive("NAA_DiffVoteState", function()
    local data = util.JSONToTable(net.ReadString()) or {}
    NAA.DiffVoteData = {
        votes     = data.votes     or {},
        players   = data.players   or {},
        countdown = data.countdown or 0,
    }
    if IsValid(NAA.DiffPanel) then
        NAA.DiffPanel:InvalidateLayout(true)
    end
end)

-- Статус выбора апгрейдов (кто ещё не выбрал)
net.Receive("NAA_UpgradeStatus", function()
    local data = util.JSONToTable(net.ReadString()) or {}
    NAA.UpgradePending = data.pending or {}
end)

-- ============================================================
--  HITMARKER (отдельный HUDPaint)
-- ============================================================
hook.Add("HUDPaint", "NAA_HitMarkersDraw", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local cx, cy = ScrW()/2, ScrH()/2
    local now    = CurTime()
    for i = #(NAA.HitMarkers or {}), 1, -1 do
        local hm = NAA.HitMarkers[i]
        if hm.t < now then
            table.remove(NAA.HitMarkers, i)
        else
            local alpha = math.Clamp((hm.t-now)/0.2*255, 0, 255)
            local col   = hm.crit and Color(255,220,0,alpha) or Color(255,255,255,alpha)
            local size  = hm.crit and 12 or 8
            surface.SetDrawColor(col)
            surface.DrawLine(cx-size, cy, cx-3, cy)
            surface.DrawLine(cx+3,    cy, cx+size, cy)
            surface.DrawLine(cx, cy-size, cx, cy-3)
            surface.DrawLine(cx, cy+3,    cx, cy+size)
            if hm.crit then
                draw.SimpleText("КРИТ!", "DermaDefault", cx, cy-28,
                    Color(255,220,0,alpha), TEXT_ALIGN_CENTER)
            end
        end
    end
end)

-- ============================================================
--  LIGHT STEP: гашение отдачи
-- ============================================================
hook.Add("Think", "NAA_LightStepClient", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local stack = (NAA.ClientUpgrades or {}).light_step or 0
    if stack <= 0 then return end
    local punch  = ply:GetViewPunchAngles()
    local factor = 0.15 * stack
    if math.abs(punch.p) > 0.01 or math.abs(punch.y) > 0.01 then
        ply:ViewPunch(Angle(-punch.p*factor, -punch.y*factor*0.5, 0))
    end
end)

-- ============================================================
--  SLIPPERY: инерция
-- ============================================================
hook.Add("Move", "NAA_SlipperyMove", function(ply, mv)
    local stack = (NAA.ClientUpgrades or {}).slippery or 0
    if stack <= 0 then return end
    local vel   = mv:GetVelocity()
    local speed = vel:Length2D()
    if speed < 10 then return end
    if not ply:KeyDown(IN_FORWARD) and not ply:KeyDown(IN_BACK)
        and not ply:KeyDown(IN_MOVELEFT) and not ply:KeyDown(IN_MOVERIGHT) then
        local inertia = math.min(0.05*stack, 0.25)
        mv:SetVelocity(vel*(1-inertia))
    end
end)

-- ============================================================
--  ДЕТЕКТИВ: HP-бары над врагами (PostDraw)
-- ============================================================
hook.Add("PostDrawOpaqueRenderables", "NAA_DetectiveHPBars", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ((NAA.ClientUpgrades or {}).detective or 0) <= 0 then return end
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        if not (ent.IsNecoArc or ent.IsNecoBoss or ent.IsMiniBoss) then continue end
        if not ent:IsNPC() then continue end
        local hp    = ent:Health()
        local maxhp = ent:GetMaxHealth()
        if maxhp <= 0 or hp <= 0 then continue end
        local pos    = ent:GetPos() + Vector(0,0,ent:OBBMaxs().z+18)
        local screen = pos:ToScreen()
        if not screen.visible then continue end
        local x, y  = screen.x, screen.y
        local barW  = 64; local barH = 9
        local prog  = math.Clamp(hp/maxhp,0,1)
        surface.SetDrawColor(0,0,0,200)
        surface.DrawRect(x-barW/2-1, y-barH/2-1, barW+2, barH+2)
        local r = math.floor(255*(1-prog)); local g = math.floor(255*prog)
        surface.SetDrawColor(r,g,30,240)
        surface.DrawRect(x-barW/2, y-barH/2, math.max(math.floor(barW*prog),0), barH)
        draw.SimpleText(math.max(hp,0).."/"..maxhp, "DermaDefault",
            x, y-barH/2-2, Color(255,255,255,230), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        if ent.IsAllyNeco then
            local allyName = ent:GetNWString("NAA_AllyName","Союзная Неко")
            draw.SimpleText(allyName, "DermaDefault",
                x, y-barH/2-14, Color(255,160,210,220), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        end
    end
end)

-- ============================================================
--  МУЗЫКА
-- ============================================================
CreateClientConVar("naa_music", "1", true, false, "Enable NAA music")

local function StartMusic()
    if not GetConVar("naa_music"):GetBool() then return end
    surface.PlaySound("infection/taank.mp3")
    local dur = SoundDuration("infection/taank.mp3")
    if dur <= 0 then dur = 120 end
    timer.Create("NAA_MusicLoop", dur, 0, function()
        if GetConVar("naa_music"):GetBool() then
            surface.PlaySound("infection/taank.mp3")
        end
    end)
end

local function StopMusic()
    timer.Remove("NAA_MusicLoop")
    RunConsoleCommand("stopsound")
end

hook.Add("NAA_PhaseChanged", "NAA_MusicControl", function(phase)
    if phase == NAA.PHASE_WAVE and NAA.ClientWave == 1 then StartMusic() end
    if phase == NAA.PHASE_LOBBY or phase == NAA.PHASE_GAME_OVER then StopMusic() end
end)

-- ============================================================
--  ЗАПРОС МЕТА ПРИ ПОДКЛЮЧЕНИИ
-- ============================================================
hook.Add("InitPostEntity", "NAA_RequestMeta", function()
    net.Start("NAA_RequestMeta") net.SendToServer()
end)

-- ============================================================
--  СКРЫТИЕ СТАНДАРТНОГО HUD GMOD
-- ============================================================
local hideElements = {
    CHudHealth=true, CHudBattery=true, CHudAmmo=true, CHudSecondaryAmmo=true,
    HUDQuickInfo=true, CHudSuitPower=true, CHudZoom=true,
    CHudDamageIndicator=true, CHudDeathNotice=true, CHudHintDisplay=true,
    CHudSquadStatus=true, CHudWeapon=true, CHudVehicle=true,
    CHudAutoAim=true, CHudPoisonDamageIndicator=true,
}

hook.Add("HUDShouldDraw", "NAA_HideDefaultHUD", function(name)
    -- 1. Всегда скрываем стандартный килфид
    if name == "CHudDeathNotice" then return false end

    -- 2. Скрываем остальные элементы только в игровых фазах
    local phase = NAA.ClientPhase
    if phase == NAA.PHASE_WAVE or phase == NAA.PHASE_BETWEEN_WAVES
        or phase == NAA.PHASE_CLASS_SELECT or phase == NAA.PHASE_DIFF_SELECT
        or phase == NAA.PHASE_GAME_OVER then
        if hideElements[name] then return false end
    end
end)

print("[NAA] Client init OK — DevMode: F9 при sv_cheats 1")
