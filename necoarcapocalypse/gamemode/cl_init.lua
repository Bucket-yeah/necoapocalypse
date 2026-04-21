-- ============================================================
--  NECO ARC APOCALYPSE — cl_init.lua (CLIENT)
--  Полная версия с режимом разработчика
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
include("cl_devmode.lua")     -- ← DEVMODE (F9 при sv_cheats 1)

-- ============================================================
--  CLIENT STATE — ВСЕ переменные инициализированы явно
-- ============================================================
NAA.ClientPhase       = NAA.PHASE_LOBBY
NAA.ClientWave        = 0
NAA.ClientEnemies     = 0
NAA.ClientDifficulty  = "normal"
NAA.ClientCoins       = 0
NAA.ClientLives       = 5

-- Копия апгрейдов игрока (синхронизируется с сервера)
NAA.ClientUpgrades    = {}
-- Активные синергии (пересчитываются при получении апгрейдов)
NAA.ClientSynergies   = {}

-- Мета-данные (нео-монеты, разблокировки)
NAA.MetaData          = { neo_coins = 0, unlocks = {} }

-- Таймер между волнами
NAA.BetweenWaveEnd    = 0

-- Счётчики/состояния для HUD
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

    if phase == NAA.PHASE_LOBBY        then pcall(NAA_ShowMenu)         end
    if phase == NAA.PHASE_CLASS_SELECT then pcall(NAA_ShowClassSelect)  end
    if phase == NAA.PHASE_DIFF_SELECT  then pcall(NAA_ShowDiffSelect)   end
    if phase == NAA.PHASE_GAME_OVER    then pcall(NAA_ShowDeath)        end

    if phase == NAA.PHASE_WAVE then
        -- Закрываем все панели выбора
        if IsValid(NAA.ActivePanel)   then NAA.ActivePanel:Remove();   NAA.ActivePanel   = nil end
        if IsValid(NAA.UpgradePanel)  then NAA.UpgradePanel:Remove();  NAA.UpgradePanel  = nil end
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

-- Синхронизация монет
net.Receive("NAA_SyncCoins", function()
    NAA.ClientCoins = net.ReadInt(16)
end)

-- Синхронизация жизней
net.Receive("NAA_SyncLives", function()
    NAA.ClientLives = net.ReadInt(16)
end)

-- Синхронизация апгрейдов (JSON с сервера)
net.Receive("NAA_UpgradeList", function()
    local json = net.ReadString()
    NAA.ClientUpgrades = util.JSONToTable(json) or {}

    -- Пересчитываем активные синергии
    local classId = LocalPlayer():GetNWString("NAA_Class", "survivor")
    NAA.ClientSynergies = NAA.GetActiveSynergies(NAA.ClientUpgrades, classId)

    -- Обновляем NW прыжки (двойной прыжок)
    local extraJumps = NAA.ClientUpgrades.double_jump or 0
    -- (сервер уже выставил NWInt, но на клиенте дублируем для UI)
    NAA.ClientExtraJumps = extraJumps
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
    -- Очищаем старые
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

-- Special alert (дрон, пузырь, etc.)
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

-- Hunter stacks sync
net.Receive("NAA_HunterStacks", function()
    NAA.HunterStacks = net.ReadInt(16)
end)

-- Run result (конец игры)
net.Receive("NAA_RunResult", function()
    NAA.RunResult = util.JSONToTable(net.ReadString()) or {}
    pcall(NAA_ShowDeath)
end)

-- ============================================================
--  HITMARKER / CROSSHAIR (HUDPaint)
-- ============================================================
hook.Add("HUDPaint", "NAA_HitMarkersDraw", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Hit markers
    local cx, cy = ScrW()/2, ScrH()/2
    local now    = CurTime()
    for i = #(NAA.HitMarkers or {}), 1, -1 do
        local hm = NAA.HitMarkers[i]
        if hm.t < now then
            table.remove(NAA.HitMarkers, i)
        else
            local alpha = math.Clamp((hm.t - now) / 0.2 * 255, 0, 255)
            local col   = hm.crit and Color(255, 220, 0, alpha) or Color(255, 255, 255, alpha)
            local size  = hm.crit and 12 or 8

            surface.SetDrawColor(col)
            -- Крест
            surface.DrawLine(cx - size, cy, cx - 3, cy)
            surface.DrawLine(cx + 3, cy, cx + size, cy)
            surface.DrawLine(cx, cy - size, cx, cy - 3)
            surface.DrawLine(cx, cy + 3, cx, cy + size)

            if hm.crit then
                draw.SimpleText("КРИТ!", "DermaDefault", cx, cy - 28,
                    Color(255, 220, 0, alpha), TEXT_ALIGN_CENTER)
            end
        end
    end

    -- Special alert
    if NAA.NotifTimer > now then
        local alpha = math.Clamp((NAA.NotifTimer - now) * 255, 0, 255)
        local sw, sh = ScrW(), ScrH()
        local msg    = NAA.NotifMsg or ""
        local tw, _  = surface.GetTextSize and ({surface.SetFont("DermaDefaultBold"), surface.GetTextSize(msg)})[2] or 200

        draw.RoundedBox(4, sw/2 - 160, sh * 0.78 - 16, 320, 32, Color(0, 0, 0, alpha * 0.6))
        draw.SimpleText(msg, "DermaDefaultBold", sw/2, sh * 0.78,
            Color(255, 240, 100, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Synergy alert
    if NAA.SynergyAlertTimer > now then
        local alpha = math.Clamp((NAA.SynergyAlertTimer - now) * 60, 0, 255)
        local sw, sh = ScrW(), ScrH()
        draw.RoundedBox(6, sw/2 - 200, sh * 0.85 - 30, 400, 60, Color(20, 8, 40, alpha))
        surface.SetDrawColor(180, 80, 255, alpha)
        surface.DrawOutlinedRect(sw/2 - 200, sh * 0.85 - 30, 400, 60)
        draw.SimpleText("✨ " .. (NAA.SynergyAlertName or ""), "DermaDefaultBold",
            sw/2, sh * 0.85 - 12, Color(200, 130, 255, alpha), TEXT_ALIGN_CENTER)
        draw.SimpleText(NAA.SynergyAlertDesc or "", "DermaDefault",
            sw/2, sh * 0.85 + 8, Color(180, 160, 220, alpha), TEXT_ALIGN_CENTER)
    end

    -- Kill streak
    if NAA.StreakTimer > now then
        local alpha = math.Clamp((NAA.StreakTimer - now) * 80, 0, 255)
        local sw, sh = ScrW(), ScrH()
        draw.RoundedBox(4, sw/2 - 170, sh * 0.22 - 16, 340, 32, Color(0, 0, 0, alpha * 0.7))
        draw.SimpleText(NAA.StreakMsg or "", "DermaDefaultBold",
            sw/2, sh * 0.22, Color(255, 200, 40, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

-- ============================================================
--  LIGHT STEP: Плавное гашение отдачи на клиенте
-- ============================================================
hook.Add("Think", "NAA_LightStepClient", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local stack = (NAA.ClientUpgrades or {}).light_step or 0
    if stack <= 0 then return end

    local punch  = ply:GetViewPunchAngles()
    local factor = 0.15 * stack  -- чем больше стаков, тем сильнее гасим
    if math.abs(punch.p) > 0.01 or math.abs(punch.y) > 0.01 then
        ply:ViewPunch(Angle(
            -punch.p * factor,
            -punch.y * factor * 0.5,
            0
        ))
    end
end)

-- ============================================================
--  SLIPPERY: Плавное торможение (меньше трения)
-- ============================================================
hook.Add("Move", "NAA_SlipperyMove", function(ply, mv)
    local stack = (NAA.ClientUpgrades or {}).slippery or 0
    if stack <= 0 then return end

    -- Эффект: уменьшаем торможение при остановке
    local vel    = mv:GetVelocity()
    local speed  = vel:Length2D()
    if speed < 10 then return end

    -- При отпускании кнопки скорость падает медленнее
    if not ply:KeyDown(IN_FORWARD) and not ply:KeyDown(IN_BACK)
        and not ply:KeyDown(IN_MOVELEFT) and not ply:KeyDown(IN_MOVERIGHT) then
        local inertia = math.min(0.05 * stack, 0.25)
        local newVel  = vel * (1 - inertia)
        mv:SetVelocity(newVel)
    end
end)

-- ============================================================
--  ДЕТЕКТИВ: HP-бары над врагами
-- ============================================================
hook.Add("PostDrawOpaqueRenderables", "NAA_DetectiveHPBars", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if (NAA.ClientUpgrades or {}).detective == nil then return end
    if ((NAA.ClientUpgrades or {}).detective or 0) <= 0 then return end

    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        if not (ent.IsNecoArc or ent.IsNecoBoss or ent.IsMiniBoss) then continue end
        if not ent:IsNPC() then continue end

        local hp    = ent:Health()
        local maxhp = ent:GetMaxHealth()
        if maxhp <= 0 or hp <= 0 then continue end

        local pos    = ent:GetPos() + Vector(0, 0, ent:OBBMaxs().z + 18)
        local screen = pos:ToScreen()
        if not screen.visible then continue end

        local x, y  = screen.x, screen.y
        local barW  = 64
        local barH  = 9
        local prog  = math.Clamp(hp / maxhp, 0, 1)

        -- Фон
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(x - barW/2 - 1, y - barH/2 - 1, barW + 2, barH + 2)

        -- HP-бар (цвет: зелёный→красный)
        local r = math.floor(255 * (1 - prog))
        local g = math.floor(255 * prog)
        surface.SetDrawColor(r, g, 30, 240)
        surface.DrawRect(x - barW/2, y - barH/2, math.max(math.floor(barW * prog), 0), barH)

        -- Текст HP
        draw.SimpleText(
            math.max(hp, 0) .. "/" .. maxhp,
            "DermaDefault",
            x, y - barH/2 - 2,
            Color(255, 255, 255, 230),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM
        )

        -- Имя союзной Неко
        if ent.IsAllyNeco then
            local allyName = ent:GetNWString("NAA_AllyName", "Союзная Неко")
            draw.SimpleText(allyName, "DermaDefault",
                x, y - barH/2 - 14,
                Color(255, 160, 210, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
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
    net.Start("NAA_RequestMeta")
    net.SendToServer()
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
    local phase = NAA.ClientPhase
    if phase == NAA.PHASE_WAVE or phase == NAA.PHASE_BETWEEN_WAVES
        or phase == NAA.PHASE_CLASS_SELECT or phase == NAA.PHASE_DIFF_SELECT
        or phase == NAA.PHASE_GAME_OVER then
        if hideElements[name] then return false end
    end
end)

print("[NAA] Client init: devmode на F9 (нужен sv_cheats 1)")
