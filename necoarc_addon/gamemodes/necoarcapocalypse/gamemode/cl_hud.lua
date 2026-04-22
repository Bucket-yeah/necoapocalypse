-- ============================================================
--  NECO ARC APOCALYPSE — cl_hud.lua (CLIENT)
--  Полный редизайн: союзники (L4D), чистый HUD, без смайлов
--  Исправления: убран math.Lerp у берсерка, интерфейс как у медика
--  Добавлена подсветка последних врагов сквозь стены
-- ============================================================

surface.CreateFont("NAA_Huge",      { font="Roboto", size=60, weight=900 })
surface.CreateFont("NAA_Big",       { font="Roboto", size=40, weight=900 })
surface.CreateFont("NAA_Med",       { font="Roboto", size=24, weight=700 })
surface.CreateFont("NAA_Small",     { font="Roboto", size=17, weight=600 })
surface.CreateFont("NAA_Tiny",      { font="Roboto", size=13, weight=500 })
surface.CreateFont("NAA_Boss",      { font="Roboto", size=48, weight=1000 })
surface.CreateFont("NAA_Mono",      { font="Courier New", size=15, weight=700 })
surface.CreateFont("NAA_AllyName",  { font="Roboto", size=15, weight=700 })
surface.CreateFont("NAA_AllySmall", { font="Roboto", size=12, weight=500 })

local TypeColor = {
    normal    = Color(220,220,220),
    runner    = Color(100,200,255),
    kamikaze  = Color(255,80,0),
    healer    = Color(80,220,80),
    armored   = Color(120,160,255),
    berserker = Color(255,60,60),
    ghost     = Color(180,180,255),
    tank      = Color(160,80,40),
    neco_sniper           = Color(255,220,40),
    neco_summoner         = Color(200,100,255),
    neco_miniboss_shadow      = Color(80,0,120),
    neco_miniboss_colossus    = Color(120,160,255),
    neco_miniboss_necromancer = Color(180,80,255),
    neco_miniboss_elemental   = Color(80,160,255),
    neco_boss_giant     = Color(255,140,0),
    neco_boss_berserker = Color(220,40,40),
    neco_boss_swarm     = Color(200,100,255),
    neco_boss_apex      = Color(255,40,40),
    boss     = Color(255,40,40),
}

local ClassColors = {
    survivor  = Color(180,180,180),
    medic     = Color(80,220,120),
    berserker = Color(220,60,60),
    hunter    = Color(100,160,255),
}
local ClassIcons = {
    survivor  = "[S]",
    medic     = "[M]",
    berserker = "[B]",
    hunter    = "[H]",
}

local function Txt(s,f,x,y,c,ax,ay)
    draw.SimpleText(s,f,x,y,c, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP)
end
local function Box(x,y,w,h,r,c)
    draw.RoundedBox(r,x,y,w,h,c)
end
local function Bar(x,y,w,h,frac,bg,fg,r)
    r = r or 3
    Box(x,y,w,h,r,bg)
    local fw = math.max(math.floor(w*math.Clamp(frac,0,1)), 0)
    if fw > 0 then Box(x,y,fw,h,r,fg) end
end

-- ============================================================
--  HP БАРЫ ДЛЯ ДЕТЕКТИВА (над врагами в 3D)
-- ============================================================
local function DrawNecoHealthBars()
    if not NAA.ClientUpgrades or (NAA.ClientUpgrades["detective"] or 0) <= 0 then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        if not (ent.IsNecoArc or ent.IsNecoBoss or ent.IsMiniBoss) then continue end
        local hp    = ent:Health()
        local maxhp = ent:GetMaxHealth()
        if maxhp <= 0 or hp <= 0 then continue end
        local pos    = ent:GetPos() + Vector(0,0,ent:OBBMaxs().z + 16)
        local screen = pos:ToScreen()
        if not screen.visible then continue end
        local x, y = screen.x, screen.y
        local bW, bH = 70, 8
        local prog = math.Clamp(hp/maxhp,0,1)
        surface.SetDrawColor(0,0,0,200)
        surface.DrawRect(x-bW/2-1, y-bH/2-1, bW+2, bH+2)
        local r = math.floor(255*(1-prog))
        local g = math.floor(210*prog)
        surface.SetDrawColor(r,g,30,240)
        surface.DrawRect(x-bW/2, y-bH/2, math.max(math.floor(bW*prog),0), bH)
        draw.SimpleText(math.max(hp,0).."/"..maxhp, "NAA_AllySmall",
            x, y-bH/2-1, Color(255,255,255,220), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end
end

-- ============================================================
--  ПАНЕЛЬ СОЮЗНИКОВ (L4D стиль, левый низ)
-- ============================================================
local ALLY_PANEL_W  = 210
local ALLY_PANEL_H  = 54
local ALLY_PANEL_X  = 14
local ALLY_PANEL_GAP = 6

local function DrawAllyPanels()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local sw, sh = ScrW(), ScrH()
    local baseY = sh - 14 - 130 - 8

    local allies = {}
    for _, p in player.Iterator() do
        if IsValid(p) and p ~= ply then
            allies[#allies+1] = p
        end
    end

    for i = #allies, 1, -1 do
        local p   = allies[i]
        local idx = #allies - i
        local py  = baseY - idx * (ALLY_PANEL_H + ALLY_PANEL_GAP) - ALLY_PANEL_H

        local hp    = p:Health()
        local maxHP = p:GetMaxHealth()
        local armor = p:Armor()
        local hpFrac = math.Clamp(hp / math.max(maxHP,1), 0, 1)
        local arFrac = math.Clamp(armor / 100, 0, 1)
        local dead  = not p:Alive()
        local cls   = p:GetNWString("NAA_Class","survivor")
        local clsC  = ClassColors[cls] or Color(180,180,180)
        local clsI  = ClassIcons[cls]  or "[?]"

        local bgAlpha = dead and 100 or 200
        Box(ALLY_PANEL_X, py, ALLY_PANEL_W, ALLY_PANEL_H, 6, Color(0,0,0,bgAlpha))
        surface.SetDrawColor(clsC.r, clsC.g, clsC.b, dead and 80 or 200)
        surface.DrawRect(ALLY_PANEL_X, py, 4, ALLY_PANEL_H)

        local txtC = dead and Color(120,120,120,180) or Color(255,255,255,255)
        Txt(clsI, "NAA_AllySmall", ALLY_PANEL_X + 8, py + 4, clsC)

        local nick = p:Nick()
        if #nick > 16 then nick = nick:sub(1,16) .. ".." end
        Txt(nick, "NAA_AllyName", ALLY_PANEL_X + 30, py + 4, txtC)

        if dead then
            Txt("ПОГИБ", "NAA_AllySmall", ALLY_PANEL_X + 30, py + 22, Color(220,60,60))
        else
            local hpCol = Color(
                math.floor(255*(1-hpFrac*0.6)),
                math.floor(180*hpFrac + 40),
                30
            )
            Bar(ALLY_PANEL_X + 30, py + 22, ALLY_PANEL_W - 38, 8, hpFrac,
                Color(30,30,30,220), hpCol, 2)
            Txt("HP "..hp, "NAA_AllySmall", ALLY_PANEL_X + 30, py + 32, Color(210,210,210))

            if armor > 0 then
                Bar(ALLY_PANEL_X + 30, py + 42, ALLY_PANEL_W - 38, 5, arFrac,
                    Color(30,30,30,180), Color(70,120,240,200), 2)
            end
        end
    end
end

-- ============================================================
--  ОСНОВНОЙ HUD PAINT
-- ============================================================
hook.Add("HUDPaint", "NAA_HUD", function()
    local phase = NAA.ClientPhase
    if phase == NAA.PHASE_LOBBY       then return end
    if phase == NAA.PHASE_CLASS_SELECT then return end
    if phase == NAA.PHASE_DIFF_SELECT  then return end
    if not IsValid(LocalPlayer()) then return end

    local sw, sh = ScrW(), ScrH()
    local now    = CurTime()
    local ply    = LocalPlayer()
    local hp     = ply:Health()
    local maxHP  = ply:GetMaxHealth()
    local armor  = ply:Armor()
    local hpFrac = math.Clamp(hp / math.max(maxHP,1), 0, 1)
    local class  = ply:GetNWString("NAA_Class", "survivor")

    -- --------------------------------------------------------
    --  Верхний левый: ВОЛНА / ВРАГИ / СЛОЖНОСТЬ
    -- --------------------------------------------------------
    local topW, topH = 250, 108
    Box(14, 14, topW, topH, 8, Color(0,0,0,175))
    local diff = NAA.Difficulties[NAA.ClientDifficulty] or {}
    local dc   = diff.color or Color(180,180,180)
    surface.SetDrawColor(dc.r, dc.g, dc.b, 160)
    surface.DrawRect(14, 14+topH-3, topW, 3)

    Txt("ВОЛНА",   "NAA_Small", 22, 26, Color(140,140,140))
    Txt(tostring(NAA.ClientWave), "NAA_Big", 22, 42, Color(255,255,255))

    surface.SetDrawColor(60,60,60,200)
    surface.DrawRect(144, 24, 1, 70)

    Txt("ВРАГИ", "NAA_Small", 154, 26, Color(140,140,140))
    local ecol = NAA.ClientEnemies > 0 and Color(255,80,80) or Color(70,210,80)
    Txt(tostring(NAA.ClientEnemies), "NAA_Big", 154, 42, ecol)

    local dname = diff.name or "?"
    Txt(dname, "NAA_Tiny", 22, 94, dc)
    if diff.lives and diff.lives < 999 then
        local livesCol = (NAA.ClientLives or 5) <= 1 and Color(255,80,80) or Color(220,180,80)
        Txt("Жизни: "..(NAA.ClientLives or "?"), "NAA_Tiny", 154, 94, livesCol)
    end

    -- --------------------------------------------------------
    --  Монеты (под топ-блоком)
    -- --------------------------------------------------------
    Box(14, 130, topW, 24, 5, Color(0,0,0,145))
    Txt("Монеты: " .. (NAA.ClientCoins or 0), "NAA_Small", 22, 133, Color(255,215,50))

    -- --------------------------------------------------------
    --  Апгрейды (над нижним HUD)
    -- --------------------------------------------------------
    local bx, by = 14, sh - 148
    local upg = NAA.ClientUpgrades or {}
    local upgList = {}
    for id, cnt in pairs(upg) do
        local u = NAA.Upgrades and NAA.Upgrades[id]
        if u and cnt > 0 then upgList[#upgList+1] = { u=u, cnt=cnt } end
    end
    table.sort(upgList, function(a,b) return a.u.name < b.u.name end)

    local cols = 7
    local cellW, cellH = 35, 20
    local rows = math.max(1, math.ceil(#upgList / cols))
    local upgPanelH = rows * cellH + 6

    if #upgList > 0 then
        Box(bx, by - upgPanelH - 2, cols * cellW + 8, upgPanelH, 4, Color(0,0,0,145))
        for i, entry in ipairs(upgList) do
            local u   = entry.u
            local cnt = entry.cnt
            local rc  = NAA.RarityConfig and NAA.RarityConfig[u.rarity]
            local col = rc and rc.color or Color(180,180,180)
            local ix  = bx + 4 + ((i-1) % cols) * cellW
            local iy  = by - upgPanelH + 3 + math.floor((i-1) / cols) * cellH
            Box(ix, iy, cellW-2, cellH-2, 2, Color(0,0,0,160))
            surface.SetDrawColor(col.r, col.g, col.b, 160)
            surface.DrawRect(ix+1, iy+1, 3, 3)
            Txt(u.icon or "?",  "NAA_Tiny", ix+5,  iy+2, Color(240,240,240))
            Txt("x"..cnt, "NAA_Tiny", ix+16, iy+2, col)
        end
    end

    -- --------------------------------------------------------
    --  Нижний левый: HP / БРОНЯ / ОРУЖИЕ
    -- --------------------------------------------------------
    local hpPanelH = 120
    Box(bx, by, topW, hpPanelH, 6, Color(0,0,0,175))

    local hpBarCol = Color(
        math.floor(255*(1-hpFrac*0.6)),
        math.floor(200*hpFrac + 40),
        30
    )
    Bar(bx+6, by+8, topW-12, 20, hpFrac, Color(30,30,30,220), hpBarCol, 4)
    Txt("HP  "..hp.." / "..maxHP, "NAA_Small", bx+12, by+10, Color(255,255,255))

    Bar(bx+6, by+32, topW-12, 12, armor/math.max(ply:GetMaxArmor(),1),
        Color(30,30,30,200), Color(65,110,230,220), 3)
    Txt("Броня  "..armor, "NAA_Tiny", bx+12, by+33, Color(170,195,255))

    local wep = ply:GetActiveWeapon()
    if IsValid(wep) then
        local clip    = wep:Clip1()
        local maxClip = wep:GetMaxClip1()
        local reserve = ply:GetAmmoCount(wep:GetPrimaryAmmoType())
        if maxClip > 0 then
            local aFrac = math.Clamp(clip/maxClip,0,1)
            local acol  = aFrac < 0.25 and Color(255,60,60) or Color(210,175,40)
            Bar(bx+6, by+49, topW-12, 12, aFrac, Color(30,30,30,200), acol, 3)
            Txt(clip.." / "..maxClip.."   +"..reserve, "NAA_Tiny", bx+12, by+50, Color(240,210,90))
        else
            Txt("Ближний / Бесконечно", "NAA_Tiny", bx+12, by+50, Color(170,170,170))
        end
    else
        Txt("Нет оружия", "NAA_Tiny", bx+12, by+50, Color(110,110,110))
    end

    -- --------------------------------------------------------
    --  Класс-специфичная информация
    -- --------------------------------------------------------
    local classInfoX = bx + topW + 10
    local classInfoY = by + 60

    if class == "hunter" then
        local stacks = NAA.HunterStacks or 0
        if stacks > 0 then
            local sc = math.min(stacks / 25, 1)
            local scCol = Color(math.floor(100+sc*155), math.floor(160-sc*80), 255)
            Box(classInfoX, classInfoY, 160, 40, 6, Color(0,0,0,160))
            Txt("СТАКИ ОХОТНИКА", "NAA_Tiny",  classInfoX+8, classInfoY+4,  Color(140,180,255))
            Txt(tostring(stacks), "NAA_Med",   classInfoX+8, classInfoY+17, scCol)
            Bar(classInfoX+6, classInfoY+36, 148, 4, sc,
                Color(30,30,30,180), scCol, 2)
        end
    elseif class == "berserker" then
        local hpPct = hpFrac
        local dmgMult = 2.8 - (1.8 * hpPct)
        if hpPct < 0.01 then dmgMult = 2.8 end
        local col = Color(math.floor(200 + 55 * (1 - hpPct)), math.floor(60 * hpPct), 30)
        Box(classInfoX, classInfoY, 160, 40, 6, Color(0,0,0,160))
        Txt("ЯРОСТЬ", "NAA_Tiny",  classInfoX+8, classInfoY+4,  Color(220,80,80))
        Txt(string.format("x%.2f урона", dmgMult), "NAA_Med", classInfoX+8, classInfoY+17, col)
        Bar(classInfoX+6, classInfoY+36, 148, 4, 1 - hpPct,
            Color(30,30,30,180), Color(220,60,60,200), 2)
    elseif class == "medic" then
        Box(classInfoX, classInfoY, 160, 40, 6, Color(0,0,0,160))
        Txt("МЕДИК", "NAA_Tiny",  classInfoX+8, classInfoY+4,  Color(80,220,120))
        Txt("Аура: +2 HP/сек", "NAA_Small", classInfoX+8, classInfoY+17, Color(160,255,160))
    end

    -- --------------------------------------------------------
    --  Таймер между волнами (центр внизу)
    -- --------------------------------------------------------
    if phase == NAA.PHASE_BETWEEN_WAVES and NAA.BetweenWaveEnd > 0 then
        local remaining = math.max(0, math.ceil(NAA.BetweenWaveEnd - now))
        local urgent    = remaining <= 5
        local tcol      = urgent and Color(255,80,80) or Color(255,215,60)
        local bwW = 260
        Box(sw/2 - bwW/2, sh - 56, bwW, 42, 7, Color(0,0,0,170))
        Txt("Следующая волна через: "..remaining.."с", "NAA_Med",
            sw/2, sh - 37, tcol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- --------------------------------------------------------
    --  Событие волны (центр экрана)
    -- --------------------------------------------------------
    local evData = nil
    for _, ev in ipairs(NAA.WaveEvents or {}) do
        if ev.id == (NAA.ClientEvent or "") then evData = ev break end
    end
    if evData and evData.id ~= "normal" then
        if NAA.ClientWave ~= NAA._lastWaveAnn then
            NAA._lastWaveAnn   = NAA.ClientWave
            NAA.WaveEventTimer = now + 5
        end
        if (NAA.WaveEventTimer or 0) > now then
            local alpha = math.min((NAA.WaveEventTimer-now)/5, 1) * 240
            Box(sw/2-320, sh*0.32, 640, 88, 10, Color(0,0,0,alpha*0.7))
            Txt(evData.name, "NAA_Big",   sw/2, sh*0.33+8,  Color(255,200,50,alpha), TEXT_ALIGN_CENTER)
            Txt(evData.desc, "NAA_Med",   sw/2, sh*0.33+52, Color(200,200,200,alpha), TEXT_ALIGN_CENTER)
        end
    end

    -- --------------------------------------------------------
    --  Босс алерт
    -- --------------------------------------------------------
    if (NAA.BossAlertTimer or 0) > now then
        local pulse = math.abs(math.sin(now*4)) * 220 + 35
        Box(sw/2-340, sh*0.14, 680, 72, 12, Color(60,0,0,180))
        Txt("!! БОСС-ВОЛНА "..(NAA.BossAlertWave or 0).." !!", "NAA_Boss",
            sw/2, sh*0.14+36, Color(255,60,60,pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- --------------------------------------------------------
    --  Стрик
    -- --------------------------------------------------------
    if (NAA.StreakTimer or 0) > now then
        local alpha = math.min((NAA.StreakTimer-now)*2.5, 1) * 240
        Txt(NAA.StreakMsg or "", "NAA_Med",
            sw/2, sh*0.54, Color(255,200,40,alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- --------------------------------------------------------
    --  Синергия алерт
    -- --------------------------------------------------------
    if (NAA.SynergyAlertTimer or 0) > now then
        local alpha = math.min((NAA.SynergyAlertTimer-now)*2, 1) * 240
        Box(sw/2-270, sh*0.60, 540, 60, 8, Color(0,0,0,alpha*0.75))
        surface.SetDrawColor(150,60,240,alpha)
        surface.DrawOutlinedRect(sw/2-270, sh*0.60, 540, 60)
        Txt("СИНЕРГИЯ: "..(NAA.SynergyAlertName or ""), "NAA_Med",
            sw/2, sh*0.61+2, Color(200,130,255,alpha), TEXT_ALIGN_CENTER)
        Txt(NAA.SynergyAlertDesc or "", "NAA_Small",
            sw/2, sh*0.61+28, Color(190,190,190,alpha), TEXT_ALIGN_CENTER)
    end

    -- --------------------------------------------------------
    --  Уведомление
    -- --------------------------------------------------------
    if (NAA.NotifTimer or 0) > now then
        local alpha = math.min((NAA.NotifTimer-now)*2, 1) * 220
        Box(sw/2-290, sh-112, 580, 42, 7, Color(0,0,0,alpha*0.65))
        Txt(NAA.NotifMsg or "", "NAA_Med",
            sw/2, sh-93, Color(255,255,100,alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- --------------------------------------------------------
    --  Кил-фид (правый верх)
    -- --------------------------------------------------------
    local kfx, kfy = sw - 14, 80
for i, entry in ipairs(NAA.KillFeed or {}) do
    local age = now - entry.t
    if age > 8 then continue end
    local alpha = math.max(0, 1 - age/8) * 220
    local tcol  = TypeColor[entry.typ] or TypeColor.normal
    Box(kfx-250, kfy-2, 244, 22, 4, Color(0,0,0,alpha*0.6))
    -- Игрок (слева)
    Txt(entry.name, "NAA_Small", kfx-242, kfy, Color(220,220,220,alpha), TEXT_ALIGN_LEFT)
    -- "убил" (по центру)
    Txt("убил",     "NAA_Small", kfx-120, kfy, Color(255,80,80,alpha),   TEXT_ALIGN_CENTER)
    -- Тип врага (справа)
    Txt(entry.typ,  "NAA_Small", kfx-8,   kfy, Color(tcol.r,tcol.g,tcol.b,alpha), TEXT_ALIGN_RIGHT)
    kfy = kfy + 24
end

    -- --------------------------------------------------------
    --  Таблица очков (правый низ, только при 2+ игроках)
    -- --------------------------------------------------------
    local sorted = {}
    for nick, kills in pairs(NAA.Scores or {}) do
        sorted[#sorted+1] = { nick=nick, kills=kills }
    end
    table.sort(sorted, function(a,b) return a.kills > b.kills end)
    if #sorted > 1 then
        local lx = sw - 200
        local ly = sh - 30 - #sorted * 22 - 34
        Box(lx-4, ly-4, 190, #sorted*22+32, 6, Color(0,0,0,155))
        Txt("Убийства", "NAA_Small", lx+4, ly+2, Color(255,200,50))
        for i, v in ipairs(sorted) do
            local c = i==1 and Color(255,220,40) or Color(180,180,180)
            local n = v.nick
            if #n > 12 then n = n:sub(1,12)..".." end
            Txt(n,                 "NAA_Small", lx+4,   ly+22+(i-1)*22, c)
            Txt(tostring(v.kills), "NAA_Small", lx+182, ly+22+(i-1)*22, c, TEXT_ALIGN_RIGHT)
        end
    end

    -- --------------------------------------------------------
    --  Союзные панели (L4D стиль)
    -- --------------------------------------------------------
    DrawAllyPanels()

    -- --------------------------------------------------------
    --  Хит-маркер
    -- --------------------------------------------------------
    NAA.HitMarkers = NAA.HitMarkers or {}
    local hasCrit, hasHit = false, false
    for i = #NAA.HitMarkers, 1, -1 do
        if NAA.HitMarkers[i].t < now then
            table.remove(NAA.HitMarkers, i)
        else
            if NAA.HitMarkers[i].crit then hasCrit=true else hasHit=true end
        end
    end
    if hasHit or hasCrit then
        local cx, cy = sw/2, sh/2
        local s = hasCrit and 12 or 8
        local c = hasCrit and Color(255,220,40,240) or Color(255,60,60,240)
        surface.SetDrawColor(c.r,c.g,c.b,c.a)
        surface.DrawLine(cx-s, cy-s, cx+s, cy+s)
        surface.DrawLine(cx+s, cy-s, cx-s, cy+s)
    end

    -- --------------------------------------------------------
    --  Статус выбора апгрейда (кто ещё не выбрал)
    -- --------------------------------------------------------
    if NAA.UpgradePending and #NAA.UpgradePending > 0 then
        local pendStr = "Ждём: " .. table.concat(NAA.UpgradePending, ", ")
        if #pendStr > 60 then pendStr = pendStr:sub(1,60).."..." end
        Box(sw/2 - 260, 14, 520, 30, 5, Color(0,0,0,160))
        Txt(pendStr, "NAA_Small", sw/2, 29, Color(200,200,100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    DrawNecoHealthBars()
end)

-- ============================================================
--  ВИНЬЕТКА при низком HP
-- ============================================================
hook.Add("HUDPaint", "NAA_Vignette", function()
    if not IsValid(LocalPlayer()) then return end
    local phase = NAA.ClientPhase
    if phase == NAA.PHASE_LOBBY or phase == NAA.PHASE_CLASS_SELECT or
       phase == NAA.PHASE_DIFF_SELECT then return end

    local hp    = LocalPlayer():Health()
    local maxHP = LocalPlayer():GetMaxHealth()
    if maxHP <= 0 then return end
    local hpPct = hp / maxHP

    if hpPct >= 0.35 then return end

    local sw, sh = ScrW(), ScrH()
    local severity = math.Remap(hpPct, 0.35, 0, 0, 1)

    local pulse = math.abs(math.sin(CurTime() * (1.5 + severity))) * severity

    local edgeAlpha = math.floor((severity * 0.55 + pulse * 0.2) * 255)
    local matL = Material("vgui/gradient-r")
    local matR = Material("vgui/gradient-l")
    local matT = Material("vgui/gradient-d")
    local matB = Material("vgui/gradient-u")

    local edgeW = math.floor(sw * 0.18 * severity)
    local edgeH = math.floor(sh * 0.18 * severity)

    surface.SetMaterial(matL)
    surface.SetDrawColor(160, 0, 0, edgeAlpha)
    surface.DrawTexturedRect(0, 0, edgeW, sh)

    surface.SetMaterial(matR)
    surface.SetDrawColor(160, 0, 0, edgeAlpha)
    surface.DrawTexturedRect(sw, 0, -edgeW, sh)

    surface.SetMaterial(matT)
    surface.SetDrawColor(160, 0, 0, math.floor(edgeAlpha*0.7))
    surface.DrawTexturedRect(0, 0, sw, edgeH)

    surface.SetMaterial(matB)
    surface.SetDrawColor(160, 0, 0, math.floor(edgeAlpha*0.7))
    surface.DrawTexturedRect(0, sh, sw, -edgeH)

    if hpPct < 0.15 then
        local warnAlpha = math.floor(pulse * 255)
        Txt("КРИТИЧЕСКИЙ УРОН", "NAA_Med",
            sw/2, sh * 0.88, Color(255, 60, 60, warnAlpha),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

-- ============================================================
--  ПОДСВЕТКА ПОСЛЕДНИХ ВРАГОВ (МАРКЕРЫ СКВОЗЬ СТЕНЫ)
-- ============================================================
NAA.LastNecoPositions = {}

net.Receive("NAA_LastNecoPos", function()
    local count = net.ReadInt(6)
    NAA.LastNecoPositions = {}
    for i = 1, count do
        NAA.LastNecoPositions[i] = net.ReadVector()
    end
end)

local function DrawLastNecoMarkers()
    local positions = NAA.LastNecoPositions
    if not positions or #positions == 0 then return end
    local now = CurTime()

    for _, pos in ipairs(positions) do
        if not pos then continue end
        local markerPos = pos + Vector(0, 0, 120)
        local screenPos = markerPos:ToScreen()

        if screenPos.visible then
            -- Пульсирующий красный ромб
            local pulse  = math.abs(math.sin(now * 3)) * 0.4 + 0.6
            local size   = 18 * pulse
            local alpha  = math.floor(220 * pulse)
            local sx, sy = screenPos.x, screenPos.y

            surface.SetDrawColor(255, 40, 40, alpha)
            surface.DrawLine(sx,      sy - size, sx + size, sy)
            surface.DrawLine(sx + size, sy,      sx,      sy + size)
            surface.DrawLine(sx,      sy + size, sx - size, sy)
            surface.DrawLine(sx - size, sy,      sx,      sy - size)

            -- Текст с количеством оставшихся врагов
            draw.SimpleText("Осталось " .. #positions, "NAA_Tiny", sx, sy - size - 14,
                Color(255, 100, 100, alpha), TEXT_ALIGN_CENTER)
        else
            -- Стрелка за краем экрана
            local sw, sh   = ScrW(), ScrH()
            local cx, cy   = sw / 2, sh / 2
            local dir      = Vector(screenPos.x - cx, screenPos.y - cy, 0):GetNormalized()
            local edgeX    = math.Clamp(cx + dir.x * (sw / 2 - 40), 30, sw - 30)
            local edgeY    = math.Clamp(cy + dir.y * (sh / 2 - 40), 30, sh - 30)
            local pulse    = math.abs(math.sin(now * 3)) * 0.5 + 0.5

            surface.SetDrawColor(255, 40, 40, math.floor(200 * pulse))
            local ang = math.atan2(dir.y, dir.x)
            local sz  = 16
            local pts = {
                { x = edgeX + math.cos(ang) * sz,          y = edgeY + math.sin(ang) * sz },
                { x = edgeX + math.cos(ang + 2.3) * sz * 0.6, y = edgeY + math.sin(ang + 2.3) * sz * 0.6 },
                { x = edgeX + math.cos(ang - 2.3) * sz * 0.6, y = edgeY + math.sin(ang - 2.3) * sz * 0.6 },
            }
            surface.DrawLine(pts[1].x, pts[1].y, pts[2].x, pts[2].y)
            surface.DrawLine(pts[2].x, pts[2].y, pts[3].x, pts[3].y)
            surface.DrawLine(pts[3].x, pts[3].y, pts[1].x, pts[1].y)
        end
    end
end

hook.Add("HUDPaint", "NAA_DrawLastNecoMarkers", DrawLastNecoMarkers)