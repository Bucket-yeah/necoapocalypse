-- ============================================================
--  NECO ARC APOCALYPSE — cl_hud.lua (CLIENT)
-- ============================================================

surface.CreateFont("NAA_Huge",  { font="Roboto", size=60, weight=900 })
surface.CreateFont("NAA_Big",   { font="Roboto", size=40, weight=900 })
surface.CreateFont("NAA_Med",   { font="Roboto", size=24, weight=700 })
surface.CreateFont("NAA_Small", { font="Roboto", size=17, weight=600 })
surface.CreateFont("NAA_Tiny",  { font="Roboto", size=13, weight=500 })
surface.CreateFont("NAA_Boss",  { font="Roboto", size=48, weight=1000 })
surface.CreateFont("NAA_Mono",  { font="Courier New", size=15, weight=700 })

local TypeColor = {
    normal    = Color(220,220,220),
    runner    = Color(100,200,255),
    kamikaze  = Color(255,80,0),
    healer    = Color(80,220,80),
    armored   = Color(120,160,255),
    berserker = Color(255,60,60),
    ghost     = Color(180,180,255),
    tank      = Color(160,80,40),
    neco_sniper   = Color(255,220,40),
    neco_summoner  = Color(200,100,255),
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

local function Txt(s,f,x,y,c,ax,ay)
    draw.SimpleText(s,f,x,y,c,ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP)
end
local function Box(x,y,w,h,r,c)
    draw.RoundedBox(r,x,y,w,h,c)
end
local function Bar(x,y,w,h,frac,bg,fg)
    Box(x,y,w,h,3,bg)
    if frac > 0 then Box(x,y,math.floor(w*frac),h,3,fg) end
end

-- ============================================================
--  ОТРИСОВКА HP-БАРОВ ДЛЯ ДЕТЕКТИВА
-- ============================================================
local function DrawNecoHealthBars()
    if not NAA.ClientUpgrades or not NAA.ClientUpgrades["detective"] then
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent.IsNecoArc and ent:Health() > 0 then
            local pos = ent:GetPos() + Vector(0, 0, ent:BoundingRadius() + 20)
            local screenPos = pos:ToScreen()

            if screenPos.visible then
                local hp = ent:Health()
                local maxHp = ent:GetMaxHealth()
                if maxHp <= 0 then maxHp = 1 end
                local frac = math.Clamp(hp / maxHp, 0, 1)

                local barWidth = 120
                local barHeight = 8
                local x = screenPos.x - barWidth / 2
                local y = screenPos.y - barHeight - 4

                surface.SetDrawColor(30, 30, 30, 200)
                surface.DrawRect(x, y, barWidth, barHeight)

                local r = math.floor(255 * (1 - frac))
                local g = math.floor(255 * frac)
                surface.SetDrawColor(r, g, 0, 220)
                surface.DrawRect(x, y, barWidth * frac, barHeight)

                local hpText = string.format("%d / %d", hp, maxHp)
                Txt(hpText, "NAA_Tiny", screenPos.x, y - 14,
                    Color(255, 255, 255, 220), TEXT_ALIGN_CENTER)
            end
        end
    end
end

-- ============================================================
--  ОСНОВНОЙ HUDPAINT (без Last Neco маркеров)
-- ============================================================
hook.Add("HUDPaint", "NAA_HUD", function()
    local phase = NAA.ClientPhase
    if phase == NAA.PHASE_LOBBY then return end
    if not IsValid(LocalPlayer()) then return end

    local sw, sh = ScrW(), ScrH()
    local now    = CurTime()
    local ply    = LocalPlayer()

    Box(14, 14, 240, 110, 8, Color(0,0,0,170))
    Box(14, 14, 240, 4, 2, Color(200,40,40,230))

    local diff = NAA.Difficulties[NAA.ClientDifficulty] or {}
    Txt("WAVE",   "NAA_Small", 22, 28, Color(160,160,160))
    Txt(tostring(NAA.ClientWave), "NAA_Big", 22, 44, Color(255,255,255))

    surface.SetDrawColor(70,70,70,200)
    surface.DrawRect(140, 26, 1, 82)

    Txt("ENEMIES", "NAA_Small", 152, 28, Color(160,160,160))
    local ecol = NAA.ClientEnemies > 0 and Color(255,80,80) or Color(80,220,80)
    Txt(tostring(NAA.ClientEnemies), "NAA_Big", 152, 44, ecol)

    local dname = diff.name or "?"
    local dcol  = diff.color or Color(180,180,180)
    Txt(dname, "NAA_Tiny", 22, 98, dcol)

    if diff.lives and diff.lives < 999 then
        local lstr = "Lives: " .. tostring(NAA.ClientLives)
        Txt(lstr, "NAA_Tiny", 152, 98, Color(220,80,80))
    end

    if phase == NAA.PHASE_BETWEEN_WAVES and NAA.BetweenWaveEnd > 0 then
        local remaining = math.max(0, math.ceil(NAA.BetweenWaveEnd - now))
        local tcol = remaining <= 5 and Color(255,80,80) or Color(255,220,80)
        Box(sw/2 - 120, sh - 54, 240, 40, 6, Color(0,0,0,160))
        Txt("Next wave in: " .. remaining .. "s", "NAA_Med",
            sw/2, sh - 36, tcol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if (NAA.BossAlertTimer or 0) > now then
        local alpha = math.abs(math.sin(now*5)) * 255
        Txt("!! BOSS WAVE " .. (NAA.BossAlertWave or 0) .. " !!", "NAA_Boss",
            sw/2, sh*0.18, Color(255,60,60,alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Last Neco alert removed

    local evData = nil
    for _, ev in ipairs(NAA.WaveEvents) do
        if ev.id == (NAA.ClientEvent or "") then evData=ev break end
    end
    if evData and evData.id ~= "normal" then
        if NAA.ClientWave ~= NAA._lastWaveAnn then
            NAA._lastWaveAnn    = NAA.ClientWave
            NAA.WaveEventTimer  = now + 5
        end
        if (NAA.WaveEventTimer or 0) > now then
            local alpha = math.min((NAA.WaveEventTimer-now)/5, 1) * 240
            Box(sw/2-300, sh*0.35, 600, 84, 10, Color(0,0,0,alpha*0.7))
            Txt(evData.name, "NAA_Big", sw/2, sh*0.36+6,  Color(255,200,50,alpha), TEXT_ALIGN_CENTER)
            Txt(evData.desc, "NAA_Med", sw/2, sh*0.36+50, Color(200,200,200,alpha), TEXT_ALIGN_CENTER)
        end
    end

    if (NAA.StreakTimer or 0) > now then
        local alpha = math.min((NAA.StreakTimer-now)*2.5, 1) * 240
        Txt(NAA.StreakMsg or "", "NAA_Med",
            sw/2, sh*0.54, Color(255,200,40,alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if (NAA.SynergyAlertTimer or 0) > now then
        local alpha = math.min((NAA.SynergyAlertTimer-now)*2, 1) * 240
        Box(sw/2-260, sh*0.61, 520, 56, 8, Color(0,0,0,alpha*0.75))
        Txt("SYNERGY: "..(NAA.SynergyAlertName or ""), "NAA_Med",
            sw/2, sh*0.62+2, Color(180,80,255,alpha), TEXT_ALIGN_CENTER)
        Txt(NAA.SynergyAlertDesc or "", "NAA_Small",
            sw/2, sh*0.62+28, Color(190,190,190,alpha), TEXT_ALIGN_CENTER)
    end

    if (NAA.NotifTimer or 0) > now then
        local alpha = math.min((NAA.NotifTimer-now)*2, 1) * 220
        Box(sw/2-270, sh-108, 540, 40, 7, Color(0,0,0,alpha*0.65))
        Txt(NAA.NotifMsg or "", "NAA_Med",
            sw/2, sh-90, Color(255,255,100,alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local kfx, kfy = sw - 14, 80
    for i, entry in ipairs(NAA.KillFeed or {}) do
        local age = now - entry.t
        if age > 8 then continue end
        local alpha = math.max(0, 1 - age/8) * 220
        local tcol  = TypeColor[entry.typ] or TypeColor.normal
        Box(kfx-244, kfy-2, 238, 22, 4, Color(0,0,0,alpha*0.6))
        Txt(entry.name, "NAA_Small", kfx-8, kfy,   Color(220,220,220,alpha), TEXT_ALIGN_RIGHT)
        Txt("[x]",      "NAA_Small", kfx-115,kfy,  Color(255,80,80,alpha),   TEXT_ALIGN_CENTER)
        Txt(entry.typ,  "NAA_Small", kfx-244,kfy,  Color(tcol.r,tcol.g,tcol.b,alpha))
        kfy = kfy + 24
    end

    local sorted = {}
    for nick, kills in pairs(NAA.Scores or {}) do
        sorted[#sorted+1] = { nick=nick, kills=kills }
    end
    table.sort(sorted, function(a,b) return a.kills > b.kills end)
    if #sorted > 1 then
        local lx = sw - 192
        local ly = sh - 30 - #sorted*22 - 34
        Box(lx, ly-4, 178, #sorted*22+32, 6, Color(0,0,0,150))
        Txt("Kills", "NAA_Small", lx+8, ly+2, Color(255,200,50))
        for i, v in ipairs(sorted) do
            local c = i==1 and Color(255,220,40) or Color(180,180,180)
            local n = v.nick
            if #n > 11 then n=n:sub(1,11)..".." end
            Txt(n,              "NAA_Small", lx+8,   ly+22+(i-1)*22, c)
            Txt(tostring(v.kills), "NAA_Small", lx+170, ly+22+(i-1)*22, c, TEXT_ALIGN_RIGHT)
        end
    end

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

    local hp      = ply:Health()
    local maxHP   = ply:GetMaxHealth()
    local armor   = ply:Armor()
    local hpFrac  = math.Clamp(hp / math.max(maxHP, 1), 0, 1)

    local bx, by  = 14, sh - 130
    Box(bx, by, 260, 116, 6, Color(0,0,0,165))

    local hpCol = Color(math.floor(255*(1-hpFrac)), math.floor(200*hpFrac+55), 30)
    Bar(bx+6, by+6, 248, 18, hpFrac, Color(35,35,35,200), hpCol)
    Txt("HP  " .. hp .. " / " .. maxHP, "NAA_Tiny", bx+10, by+8, Color(255,255,255))

    Bar(bx+6, by+28, 248, 13, armor/100, Color(35,35,35,200), Color(70,120,240))
    Txt("Armor  " .. armor, "NAA_Tiny", bx+10, by+29, Color(180,200,255))

    local wep = ply:GetActiveWeapon()
    if IsValid(wep) then
        local clip    = wep:Clip1()
        local maxClip = wep:GetMaxClip1()
        local reserve = ply:GetAmmoCount(wep:GetPrimaryAmmoType())

        if maxClip > 0 then
            local ammoFrac = math.Clamp(clip / maxClip, 0, 1)
            local acol = ammoFrac < 0.25 and Color(255,60,60) or Color(220,180,40)
            Bar(bx+6, by+45, 248, 13, ammoFrac, Color(35,35,35,200), acol)
            Txt(clip .. " / " .. maxClip .. "   +" .. reserve, "NAA_Tiny", bx+10, by+46, Color(255,220,100))
        else
            Txt("Melee / Infinite", "NAA_Tiny", bx+10, by+46, Color(180,180,180))
        end
    else
        Txt("No weapon", "NAA_Tiny", bx+10, by+46, Color(120,120,120))
    end

    Txt("Coins: " .. NAA.ClientCoins, "NAA_Small", bx+6, by+62, Color(255,220,60))

    local upg = NAA.ClientUpgrades or {}
    local upgList = {}
    for id, cnt in pairs(upg) do
        local u = NAA.Upgrades[id]
        if u then upgList[#upgList+1] = { u=u, cnt=cnt } end
    end
    table.sort(upgList, function(a,b) return a.u.name < b.u.name end)

    local ux2 = 14
    local uy2  = by - 4 - math.ceil(#upgList/7) * 22

    for i, entry in ipairs(upgList) do
        local u   = entry.u
        local cnt = entry.cnt
        local col = NAA.RarityConfig[u.rarity].color
        local ix  = ux2 + ((i-1) % 7) * 38
        local iy  = uy2 + math.floor((i-1) / 7) * 22
        Box(ix, iy, 34, 18, 2, Color(0,0,0,160))
        surface.SetDrawColor(col.r, col.g, col.b, 180)
        surface.DrawRect(ix+1, iy+1, 4, 4)
        Txt(u.icon,  "NAA_Tiny", ix+6,  iy+2, Color(255,255,255))
        Txt("x"..cnt,"NAA_Tiny", ix+18, iy+2, col)
    end

    local class = ply:GetNWString("NAA_Class", "survivor")
    if class == "hunter" then
        local stacks = NAA.HunterStacks or 0
        if stacks > 0 then
            Txt("HUNTER STACKS: " .. stacks, "NAA_Small", sw/2, sh*0.75,
                Color(100,160,255), TEXT_ALIGN_CENTER)
        end
    elseif class == "berserker" then
        local hpPct = hp / maxHP
        local dmgMult = math.Lerp(hpPct, 2.8, 1.0)
        Txt(string.format("RAGE DMG: x%.1f", dmgMult), "NAA_Small", sw/2, sh*0.75,
            Color(220,60,60), TEXT_ALIGN_CENTER)
    end

    DrawNecoHealthBars()
end)

hook.Add("HUDPaint", "NAA_Vignette", function()
    if not IsValid(LocalPlayer()) then return end
    local phase = NAA.ClientPhase
    if phase == NAA.PHASE_LOBBY or phase == NAA.PHASE_CLASS_SELECT or
       phase == NAA.PHASE_DIFF_SELECT then return end

    local hp = LocalPlayer():Health()
    if hp >= 40 then return end
    local alpha = math.Remap(hp, 40, 0, 0, 190)
    local pulse = math.abs(math.sin(CurTime()*3)) * 25
    local sw, sh = ScrW(), ScrH()
    local mat = Material("vgui/gradient-r")
    surface.SetMaterial(mat)
    surface.SetDrawColor(200, 0, 0, alpha + pulse)
    surface.DrawTexturedRect(0,  0, sw*0.35, sh)
    surface.DrawTexturedRect(sw, 0, -sw*0.35, sh)
    surface.SetDrawColor(200, 0, 0, (alpha+pulse)*0.5)
    surface.DrawTexturedRect(0,  0,  sw, sh*0.25)
    surface.DrawTexturedRect(0,  sh, sw, -sh*0.25)
end)
