-- ============================================================
-- neco_boss_apex/cl_init.lua (GRAND FINALE — смерть с эффектами)
-- ============================================================
include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")
local matBeam  = Material("sprites/laserbeam")

-- Шрифт для финального текста
surface.CreateFont("ApexDeathFont", {
    font     = "Arial",
    size     = 58,
    weight   = 900,
    antialias = true,
    shadow   = false,
})
surface.CreateFont("ApexDeathFontSub", {
    font     = "Arial",
    size     = 30,
    weight   = 700,
    antialias = true,
    shadow   = false,
})

local PHASE_COLORS = {
    [1] = { mod = {1.0, 0.28, 0.28},  glow = Color(255, 70,  70)  },
    [2] = { mod = {1.0, 0.18, 0.75},  glow = Color(255, 45, 195)  },
    [3] = { mod = {0.75, 0.10, 1.0},  glow = Color(195, 25, 255)  },
}

-- Сетевые события
local novaEvents    = {}
local meteorWarnings = {}
local meteorBlasts   = {}
local teleportFX    = {}
local phasePulse    = 0
local apocActive    = false
local apocParticles = {}

-- Финал смерти
local deathFX         = {}   -- { pos, t, phase }
local deathBursts     = {}   -- { pos, t, isFinal }
local deathParticles  = {}   -- разлетающиеся частицы

net.Receive("NAA_ApexNova", function()
    local pos    = net.ReadVector()
    local isNova = net.ReadBool()
    table.insert(novaEvents, { pos = pos, t = CurTime(), isNova = isNova })
    if isNova then util.ScreenShake(LocalPlayer():GetPos(), 12, 15, 1.5, 1200) end
end)

net.Receive("NAA_ApexMeteor", function()
    table.insert(meteorWarnings, { pos = net.ReadVector(), t = CurTime() })
end)

net.Receive("NAA_ApexMeteorImpact", function()
    local pos = net.ReadVector()
    table.insert(meteorBlasts, { pos = pos, t = CurTime() })
    util.ScreenShake(LocalPlayer():GetPos(), 10, 14, 1.2, 800)
end)

net.Receive("NAA_ApexTeleport", function()
    table.insert(teleportFX, { from = net.ReadVector(), to = net.ReadVector(), t = CurTime() })
end)

net.Receive("NAA_ApexPhase", function()
    phasePulse = CurTime()
    local phase = net.ReadInt(4)
    local col = PHASE_COLORS[phase] and PHASE_COLORS[phase].glow or Color(255, 80, 80)
    _ApexPhaseFlash = { t = CurTime(), col = col }
end)

net.Receive("NAA_ApexApocalypse", function()
    apocActive = net.ReadBool()
end)

-- ── Грандиозный финал смерти ──────────────────────────────────
net.Receive("NAA_ApexDeath", function()
    local pos   = net.ReadVector()
    local phase = net.ReadInt(4)
    table.insert(deathFX, { pos = pos, t = CurTime(), phase = phase })

    -- Начальная тряска на клиенте
    local lp = IsValid(LocalPlayer()) and LocalPlayer() or nil
    if lp then util.ScreenShake(lp:GetPos(), 45, 60, 7.0, 6000) end

    -- Первая волна разлетающихся частиц
    for i = 1, 60 do
        local ang  = math.random(0, 360)
        local pitch = math.random(-40, 40)
        local spd   = math.random(280, 900)
        local dir   = Vector(
            math.cos(math.rad(ang)) * math.cos(math.rad(pitch)),
            math.sin(math.rad(ang)) * math.cos(math.rad(pitch)),
            math.sin(math.rad(pitch))
        )
        table.insert(deathParticles, {
            pos  = pos + Vector(0, 0, 80),
            vel  = dir * spd,
            t    = CurTime(),
            life = 3.5 + math.random() * 2.5,
            sz   = math.random(12, 55),
            col  = (math.random() > 0.5)
                      and Color(255, math.random(80, 200), 20)
                      or  Color(255, 255, math.random(100, 220)),
        })
    end
end)

net.Receive("NAA_ApexDeathBurst", function()
    local pos     = net.ReadVector()
    local isFinal = net.ReadFloat() >= 1.0
    table.insert(deathBursts, { pos = pos, t = CurTime(), isFinal = isFinal })

    -- При финальном взрыве — дополнительный шквал частиц
    if isFinal then
        for i = 1, 120 do
            local ang   = math.random(0, 360)
            local pitch = math.random(-60, 60)
            local spd   = math.random(500, 2000)
            local dir   = Vector(
                math.cos(math.rad(ang)) * math.cos(math.rad(pitch)),
                math.sin(math.rad(ang)) * math.cos(math.rad(pitch)),
                math.sin(math.rad(pitch))
            )
            table.insert(deathParticles, {
                pos  = pos,
                vel  = dir * spd,
                t    = CurTime(),
                life = 4.0 + math.random() * 3.0,
                sz   = math.random(20, 80),
                col  = Color(255, math.random(60, 230), math.random(0, 60)),
            })
        end
    end
end)

hook.Add("Think", "Apex_FXThink", function()
    local now = CurTime()

    if apocActive then
        for _ = 1, 5 do
            local ply = IsValid(LocalPlayer()) and LocalPlayer() or nil
            if not ply then break end
            local center = ply:GetPos()
            table.insert(apocParticles, {
                pos  = center + Vector(math.random(-700,700), math.random(-700,700), math.random(180, 650)),
                vel  = Vector(math.random(-25,25), math.random(-25,25), -math.random(55, 150)),
                t    = now, life = 2.2 + math.random(), sz = math.random(10, 38)
            })
        end
    end

    for i = #apocParticles, 1, -1 do if now - apocParticles[i].t > apocParticles[i].life then table.remove(apocParticles, i) end end
    for i = #novaEvents,      1, -1 do if now - novaEvents[i].t      > 2.8 then table.remove(novaEvents, i) end end
    for i = #meteorWarnings,  1, -1 do if now - meteorWarnings[i].t  > 6.0 then table.remove(meteorWarnings, i) end end
    for i = #meteorBlasts,    1, -1 do if now - meteorBlasts[i].t    > 3.5 then table.remove(meteorBlasts, i) end end
    for i = #teleportFX,      1, -1 do if now - teleportFX[i].t      > 1.8 then table.remove(teleportFX, i) end end

    -- Обновление частиц смерти
    for _, dp in ipairs(deathParticles) do
        dp.vel = dp.vel + Vector(0, 0, -180) * FrameTime()  -- гравитация
    end
    for i = #deathParticles, 1, -1 do if now - deathParticles[i].t > deathParticles[i].life then table.remove(deathParticles, i) end end
    for i = #deathFX,        1, -1 do if now - deathFX[i].t        > 10.0 then table.remove(deathFX, i) end end
    for i = #deathBursts,    1, -1 do if now - deathBursts[i].t    > 3.5  then table.remove(deathBursts, i) end end
end)

hook.Add("PostDrawTranslucentRenderables", "Apex_PostDraw", function()
    local now = CurTime()

    render.SetMaterial(matGlow)
    for _, ev in ipairs(novaEvents) do
        local age  = now - ev.t
        local frac = math.min(age / (ev.isNova and 2.2 or 0.9), 1)
        local a    = math.floor(Lerp(frac, 225, 0))
        local col  = ev.isNova and Color(195, 25, 255) or Color(255, 55, 195)

        if ev.isNova then
            if age < 0.15 then
                local bf = age / 0.15
                render.DrawSprite(ev.pos + Vector(0,0,30),
                    Lerp(bf, 1200, 200), Lerp(bf, 1200, 200),
                    Color(255, 240, 255, math.floor((1-bf)*240)))
            end

            render.DrawSphere(ev.pos + Vector(0,0,30),
                frac * 650, 16, 16,
                Color(col.r, col.g, col.b, math.floor(a * 0.22)))

            render.SetMaterial(matBeam)
            for i = 0, 11 do
                local ang  = i * 30
                local dir  = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
                local len  = math.min(frac * 1500, 1500)
                local aw   = math.floor(Lerp(frac, 225, 0))
                local wOuter = 9 * (1 - frac * 0.65)
                local wInner = 2.8
                render.DrawBeam(ev.pos + Vector(0,0,30),
                    ev.pos + Vector(0,0,30) + dir * len, wOuter, 0, 1,
                    Color(col.r, col.g, col.b, aw))
                render.DrawBeam(ev.pos + Vector(0,0,30),
                    ev.pos + Vector(0,0,30) + dir * len, wInner, 0, 1,
                    Color(255, 230, 255, math.floor(aw * 0.85)))
            end
            render.SetMaterial(matGlow)
        else
            render.DrawSphere(ev.pos + Vector(0,0,30), frac * 400, 14, 14,
                Color(col.r, col.g, col.b, math.floor(a * 0.2)))
            render.DrawSprite(ev.pos + Vector(0,0,10),
                Lerp(frac, 600, 60), Lerp(frac, 600, 60),
                Color(col.r, col.g, col.b, math.floor(Lerp(frac, 190, 0))))
        end
    end

    render.SetMaterial(matGlow)
    for _, mw in ipairs(meteorWarnings) do
        local age  = now - mw.t
        local frac = math.min(age / 5.5, 1)
        local pulse = 0.5 + 0.5 * math.sin(age * 12)
        local a    = math.floor(Lerp(frac, 200, 60))
        local r    = 120 + pulse * 30

        render.DrawSphere(mw.pos + Vector(0,0,8), r, 10, 10,
            Color(255, 60, 10, math.floor(a * 0.35)))
        render.DrawSprite(mw.pos + Vector(0,0,12), r*2.8, r*2.8,
            Color(255, 80, 20, math.floor(pulse*90 + 30)))
    end

    for _, mb in ipairs(meteorBlasts) do
        local age  = now - mb.t
        local frac = math.min(age / 3.0, 1)
        local ef   = math.min(age / 0.28, 1)
        local a    = math.floor(Lerp(frac, 210, 0))
        local r    = ef * 300

        if ef < 1 then
            render.DrawSprite(mb.pos + Vector(0,0,15),
                Lerp(ef, 700, 90), Lerp(ef, 700, 90),
                Color(255, 160, 30, math.floor((1-ef)*230)))
        end

        render.DrawSphere(mb.pos + Vector(0,0,8), r, 12, 12,
            Color(255, 110, 20, math.floor(a * 0.38)))

        render.SetMaterial(matSmoke)
        for i = 1, 12 do
            local ang = i * 30 + age * 85
            local sp  = mb.pos + Vector(
                math.cos(math.rad(ang)) * r * 0.88,
                math.sin(math.rad(ang)) * r * 0.88,
                age * 25 + (i % 4) * 14
            )
            local dsz = Lerp(frac, 38, 140)
            render.DrawSprite(sp, dsz, dsz, Color(190, 75, 20, math.floor(a * (1 - i/16))))
        end
        render.SetMaterial(matGlow)

        if age > 0.4 then
            local ga = math.floor(Lerp(math.min((age-0.4)/0.3, 1), 0, 70) * Lerp(frac, 1, 0))
            render.DrawSphere(mb.pos + Vector(0,0,10), math.min((age-0.4)/0.3,1) * 240, 8, 8,
                Color(255, 100, 10, ga))
        end
    end

    render.SetMaterial(matSmoke)
    for _, tf in ipairs(teleportFX) do
        local age  = now - tf.t
        local frac = math.min(age / 1.5, 1)
        local a    = math.floor(Lerp(frac, 210, 0))

        for i = 1, 10 do
            local ang  = i * 36 + age * 180
            local r    = Lerp(math.min(age / 0.3, 1), 15, Lerp(frac, 20, 160))
            for _, p in ipairs({ tf.from, tf.to }) do
                local sp = p + Vector(
                    math.cos(math.rad(ang)) * r,
                    math.sin(math.rad(ang)) * r,
                    age * 22 + i * 6
                )
                render.DrawSprite(sp,
                    Lerp(frac, 30, 95), Lerp(frac, 30, 95),
                    Color(130, 8, 210, math.floor(a * (1 - i/14))))
            end
        end
        render.SetMaterial(matBeam)
        local beamA = math.floor(Lerp(frac, 180, 0))
        render.DrawBeam(tf.from, tf.to, Lerp(frac, 12, 1), 0, 1, Color(180, 30, 255, beamA))
        render.DrawBeam(tf.from, tf.to, Lerp(frac, 4, 0.5),  0, 1, Color(255, 200, 255, math.floor(beamA*0.7)))
        render.SetMaterial(matSmoke)
    end

    render.SetMaterial(matGlow)
    for _, p in ipairs(apocParticles) do
        local age  = now - p.t
        local frac = age / p.life
        local pos2 = p.pos + p.vel * age
        local a
        if frac < 0.15 then
            a = math.floor(frac / 0.15 * 215)
        elseif frac > 0.78 then
            a = math.floor((1 - frac) / 0.22 * 215)
        else
            a = 215
        end
        local r = math.floor(255)
        local g = math.floor(110 + math.sin(age * 6 + p.sz) * 45)
        render.DrawSprite(pos2, p.sz, p.sz, Color(r, g, 15, a))
        local trail_pos = pos2 - p.vel * 0.08 * age
        render.DrawSprite(trail_pos, p.sz * 0.45, p.sz * 0.45, Color(220, 80, 10, math.floor(a*0.5)))
    end

    -- ══════════════════════════════════════════════════════
    --  ГРАНДИОЗНЫЙ ФИНАЛ СМЕРТИ — 3D-ЭФФЕКТЫ
    -- ══════════════════════════════════════════════════════

    -- Частицы смерти (от обоих событий)
    render.SetMaterial(matGlow)
    for _, dp in ipairs(deathParticles) do
        local age  = now - dp.t
        local frac = age / dp.life
        local ppos = dp.pos + dp.vel * age + Vector(0,0,-90) * age * age * 0.5
        local a
        if frac < 0.12 then
            a = math.floor(frac / 0.12 * 230)
        elseif frac > 0.75 then
            a = math.floor((1 - frac) / 0.25 * 230)
        else
            a = 230
        end
        local c = dp.col
        render.DrawSprite(ppos, dp.sz * (1 + frac * 0.4), dp.sz * (1 + frac * 0.4),
            Color(c.r, c.g, c.b, a))
        -- Хвост частицы
        local trailPos = ppos - dp.vel * FrameTime() * 3
        render.DrawSprite(trailPos, dp.sz * 0.4, dp.sz * 0.4,
            Color(255, 200, 60, math.floor(a * 0.4)))
    end

    -- Мини-взрывы (deathBursts)
    render.SetMaterial(matGlow)
    for _, db in ipairs(deathBursts) do
        local age   = now - db.t
        local frac  = math.min(age / (db.isFinal and 3.5 or 2.0), 1)
        local ef    = math.min(age / 0.18, 1)   -- вспышка
        local wavR  = ef * (db.isFinal and 1200 or 500)
        local wA    = math.floor(math.max(0, 220 - frac * 240))

        -- Мгновенная вспышка
        if ef < 1 then
            local cf = 1 - ef
            render.DrawSprite(db.pos,
                Lerp(ef, db.isFinal and 2400 or 900, 60),
                Lerp(ef, db.isFinal and 2400 or 900, 60),
                Color(255, 240, 180, math.floor(cf * 255)))
        end

        -- Расширяющаяся волна
        render.DrawSphere(db.pos, wavR, 16, 16,
            Color(255, 160, 40, math.floor(wA * 0.28)))

        if db.isFinal then
            -- Лучи финального взрыва (24 луча)
            render.SetMaterial(matBeam)
            local beamLen = math.min(age * 1200, 4000)
            local bA      = math.floor(math.max(0, 200 - frac * 220))
            for i = 0, 23 do
                local ang   = i * 15 + age * 5
                local pitch = (i % 6 - 2.5) * 20
                local dir   = Vector(
                    math.cos(math.rad(ang)) * math.cos(math.rad(pitch)),
                    math.sin(math.rad(ang)) * math.cos(math.rad(pitch)),
                    math.sin(math.rad(pitch))
                )
                dir:Normalize()
                local bw = math.max(0.5, 12 - frac * 11)
                render.DrawBeam(db.pos, db.pos + dir * beamLen,
                    bw,    0, 1, Color(255, 140, 30, bA))
                render.DrawBeam(db.pos, db.pos + dir * beamLen,
                    bw * 0.3, 0, 1, Color(255, 255, 200, math.floor(bA * 0.65)))
            end
            render.SetMaterial(matGlow)

            -- Пульсирующее ядро
            local gp = 0.5 + 0.5 * math.sin(age * 14)
            render.DrawSphere(db.pos, 200 + gp * 120, 14, 14,
                Color(255, 200, 80, math.floor(wA * 0.55)))
            render.DrawSprite(db.pos,
                700 + gp * 300, 700 + gp * 300,
                Color(255, 180, 50, math.floor(gp * wA * 0.7)))
        else
            -- Обычный взрыв — кольцо + спрайт
            render.DrawSphere(db.pos, math.min(ef * 280, 280), 10, 10,
                Color(255, 120, 20, math.floor(wA * 0.35)))
            render.DrawSprite(db.pos,
                Lerp(frac, 280, 40), Lerp(frac, 280, 40),
                Color(255, 150, 40, math.floor(Lerp(frac, 180, 0))))

            render.SetMaterial(matSmoke)
            for i = 1, 6 do
                local sang = i * 60 + age * 75
                local sr   = wavR * 0.75
                local sp   = db.pos + Vector(
                    math.cos(math.rad(sang)) * sr,
                    math.sin(math.rad(sang)) * sr,
                    age * 30 + i * 10
                )
                render.DrawSprite(sp, Lerp(frac, 25, 80), Lerp(frac, 25, 80),
                    Color(180, 70, 20, math.floor(wA * 0.6 * (1 - i/8))))
            end
            render.SetMaterial(matGlow)
        end
    end

    -- Основное свечение смерти (долгое угасание)
    for _, df in ipairs(deathFX) do
        local age  = now - df.t
        local frac = math.min(age / 9.0, 1)
        local glow = math.floor(math.max(0, (1 - frac) * 160))
        local gp   = 0.5 + 0.5 * math.sin(age * 7)
        local center = df.pos + Vector(0,0,80)

        render.SetMaterial(matGlow)
        render.DrawSphere(center, 300 + gp * 80, 14, 14,
            Color(255, 170, 50, math.floor(glow * 0.45)))
        render.DrawSprite(center, 500 + gp * 200, 500 + gp * 200,
            Color(255, 200, 80, math.floor(gp * glow * 0.6)))
    end

    render.SetMaterial(matGlow)
end)

hook.Add("HUDPaint", "Apex_HUDOverlays", function()
    local now = CurTime()

    if apocActive then
        local pulse = 0.5 + 0.5 * math.sin(now * 3.5)
        surface.SetDrawColor(85, 18, 0, math.floor(pulse * 65 + 22))
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end

    if _ApexPhaseFlash then
        local age  = now - _ApexPhaseFlash.t
        if age < 0.9 then
            local pf = age / 0.9
            local c  = _ApexPhaseFlash.col
            surface.SetDrawColor(c.r, c.g, c.b, math.floor((1 - pf) * 100))
            surface.DrawRect(0, 0, ScrW(), ScrH())
        end
    end

    -- ══════════════════════════════════════════════════════
    --  ГРАНДИОЗНЫЙ ФИНАЛ — HUD-ОВЕРЛЕЙ
    -- ══════════════════════════════════════════════════════
    for _, db in ipairs(deathBursts) do
        if db.isFinal then
            local age = now - db.t
            -- Ослепительная белая вспышка во весь экран
            if age < 1.2 then
                local ff = 1 - age / 1.2
                local a  = math.floor(ff * ff * 250)
                surface.SetDrawColor(255, 240, 200, a)
                surface.DrawRect(0, 0, ScrW(), ScrH())
            end
        end
    end

    for _, df in ipairs(deathFX) do
        local age  = now - df.t
        local SW, SH = ScrW(), ScrH()

        -- Начальная вспышка (первые 0.6 сек)
        if age < 0.6 then
            local ff = 1 - age / 0.6
            surface.SetDrawColor(255, 230, 180, math.floor(ff * ff * 220))
            surface.DrawRect(0, 0, SW, SH)
        end

        -- Красная пульсирующая виньетка (0.3–6.0 сек)
        if age > 0.3 and age < 6.5 then
            local va   = math.max(0, math.min(1, (age - 0.3) / 0.6))
            local vout = math.max(0, 1 - (age - 5.0) / 1.5)
            local pulse = 0.5 + 0.5 * math.sin(age * 5)
            local ia   = math.floor(va * vout * (45 + pulse * 35))
            if ia > 0 then
                -- Виньетка — 4 полосы по краям с затемнением
                local vig = math.floor(ia * 1.5)
                surface.SetDrawColor(90, 10, 0, vig)
                surface.DrawRect(0, 0, SW, SH * 0.18)                     -- верх
                surface.DrawRect(0, SH * 0.82, SW, SH * 0.18)             -- низ
                surface.DrawRect(0, 0, SW * 0.12, SH)                     -- лево
                surface.DrawRect(SW * 0.88, 0, SW * 0.12, SH)             -- право
            end
        end

        -- ── Победный текст (1.5–9.0 сек) ──────────────────────────
        if age > 1.5 and age < 9.0 then
            local ta
            if age < 2.2 then
                ta = (age - 1.5) / 0.7       -- нарастание
            elseif age > 7.5 then
                ta = 1 - (age - 7.5) / 1.5   -- угасание
            else
                ta = 1.0
            end
            local pulse   = 0.5 + 0.5 * math.sin(age * 3.5)
            local textAlpha = math.floor(ta * 255)

            -- Заголовок
            local title  = "АПЕКС НЕКО ПОВЕРЖЕНА!"
            surface.SetFont("ApexDeathFont")
            local tw, th = surface.GetTextSize(title)
            local cx = SW / 2
            local cy = SH * 0.32

            -- Тень (смещение + размытие через повторные рисования)
            for _, off in ipairs({{4,4},{3,3},{2,2}}) do
                surface.SetTextColor(0, 0, 0, math.floor(textAlpha * 0.55))
                surface.SetTextPos(cx - tw/2 + off[1], cy - th/2 + off[2])
                surface.DrawText(title)
            end

            -- Цвет заголовка: огненный градиент через пульсацию
            local gr = math.floor(120 + pulse * 130)
            surface.SetTextColor(255, gr, 10, textAlpha)
            surface.SetTextPos(cx - tw/2, cy - th/2)
            surface.DrawText(title)

            -- Светящийся белый контур (поверх)
            local glowA = math.floor(pulse * textAlpha * 0.5)
            surface.SetTextColor(255, 255, 220, glowA)
            surface.SetTextPos(cx - tw/2, cy - th/2)
            surface.DrawText(title)

            -- Подзаголовок
            local sub = "ВЫ ПОБЕДИЛИ!"
            surface.SetFont("ApexDeathFontSub")
            local sw2, sh2 = surface.GetTextSize(sub)
            local subPulse = 0.5 + 0.5 * math.sin(age * 6)
            local sr2 = math.floor(200 + subPulse * 55)
            local sg2 = math.floor(200 + subPulse * 55)
            surface.SetTextColor(0, 0, 0, math.floor(textAlpha * 0.5))
            surface.SetTextPos(cx - sw2/2 + 2, cy + th/2 + 10 + 2)
            surface.DrawText(sub)
            surface.SetTextColor(sr2, sg2, 255, textAlpha)
            surface.SetTextPos(cx - sw2/2, cy + th/2 + 10)
            surface.DrawText(sub)

            -- Горизонтальная разделительная линия
            local lineW = math.floor(math.min((age - 1.5) / 0.5, 1) * tw * 1.2)
            local lineX = cx - lineW / 2
            local lineY = cy - th / 2 - 8
            local lineA = math.floor(ta * 180)
            surface.SetDrawColor(255, math.floor(pulse * 200 + 55), 30, lineA)
            surface.DrawRect(lineX, lineY, lineW, 3)
            surface.DrawRect(lineX, cy + th / 2 + sh2 + 22, lineW, 3)
        end
    end
end)

function ENT:Draw()
    self._drawPos = self:GetPos()
    local t     = CurTime()
    local phase = self:GetNWInt("ApexPhase", 1)
    local pc    = PHASE_COLORS[phase] or PHASE_COLORS[1]
    local apoc  = self:GetNWBool("ApexApocalypse", false)
    local pulse = 0.5 + 0.5 * math.sin(t * 2.5)
    local pulse2 = 0.5 + 0.5 * math.sin(t * 4.1 + 1.0)

    local sincePhase = t - phasePulse
    if sincePhase < 3 then
        local fp = math.sin(sincePhase * 22) * 0.5 * math.max(1 - sincePhase/3, 0)
        render.SetColorModulation(
            math.Clamp(pc.mod[1] + fp, 0, 1),
            math.Clamp(pc.mod[2] + fp * 0.4, 0, 1),
            math.Clamp(pc.mod[3] + fp * 0.4, 0, 1))
    else
        render.SetColorModulation(pc.mod[1], pc.mod[2], pc.mod[3])
    end

    render.SetBlend(apoc and 0.68 or 1.0)
    self:DrawModel()
    render.SetBlend(1)
    render.SetColorModulation(1, 1, 1)

    -- ИСПРАВЛЕНО: используем базовую позицию вместо OBBCenter, чтобы эффекты были внутри модели
    local basePos = self:GetPos()
    local gc      = pc.glow

    -- Многослойная аура — опущена вниз
    render.SetMaterial(matGlow)
    render.DrawSphere(basePos + Vector(0,0,80), 185+pulse*32,  16, 16, Color(gc.r, gc.g, gc.b, math.floor(42+pulse*28)))
    render.DrawSphere(basePos + Vector(0,0,60), 295+pulse*42,  14, 14, Color(gc.r, gc.g, gc.b, math.floor(18+pulse*14)))
    render.DrawSphere(basePos + Vector(0,0,40), 390+pulse2*55, 12, 12, Color(gc.r, gc.g, gc.b, math.floor(9+pulse2*8)))
    render.DrawSprite(basePos + Vector(0,0,70), 570+pulse*85, 570+pulse*85,
        Color(gc.r, gc.g, gc.b, math.floor(pulse*48+14)))

    -- Основные орбитальные сферы
    local orbitCount = phase + 2
    for i = 1, orbitCount do
        local speed  = 30 + phase * 9
        local ang    = t * speed + i * (360 / orbitCount)
        local r      = 215 + math.sin(t * 2.1 + i) * 42
        local z      = math.sin(t * 1.25 + i * 1.55) * 65 + 80  -- смещено вниз
        local op     = basePos + Vector(math.cos(math.rad(ang))*r, math.sin(math.rad(ang))*r, z)

        local op_p = 0.5 + 0.5 * math.sin(t * (3.0 + i*0.25) + i)
        render.DrawSprite(op, 35 + op_p*10, 35 + op_p*10,
            Color(gc.r, gc.g, gc.b, math.floor(185+op_p*55)))
        render.DrawSprite(op, 15 + op_p*5,  15 + op_p*5,
            Color(255, 240, 255, math.floor(op_p*100 + 40)))

        render.SetMaterial(matBeam)
        render.DrawBeam(basePos + Vector(0,0,80), op, 1.8, 0, 1,
            Color(gc.r, gc.g, gc.b, math.floor(55+pulse*35)))
        render.DrawBeam(basePos + Vector(0,0,80), op, 0.5, 0, 1,
            Color(255, 240, 255, math.floor(pulse*30 + 12)))
        render.SetMaterial(matGlow)
    end

    -- Контр-вращающиеся малые сферы (phase 2+)
    if phase >= 2 then
        local smallCount = phase
        for i = 1, smallCount do
            local ang = -t * (50 + phase * 10) + i * (360 / smallCount) + 45
            local r   = 140 + math.sin(t * 3 + i * 0.8) * 20
            local z   = math.sin(t * 2 + i * 2) * 40 + 80
            local op  = basePos + Vector(math.cos(math.rad(ang))*r, math.sin(math.rad(ang))*r, z)
            local sp  = 0.5 + 0.5 * math.sin(t * 5 + i)
            render.DrawSprite(op, 18 + sp*6, 18 + sp*6,
                Color(gc.r, gc.g, gc.b, math.floor(130+sp*70)))
        end
    end

    -- Заряд выстрела
    if self:GetNWBool("ApexShot", false) then
        local sp = 0.5 + 0.5 * math.sin(t * 35)
        render.DrawSprite(basePos + Vector(0,0,100), 420+sp*90, 420+sp*90,
            Color(gc.r, gc.g, gc.b, math.floor(sp*185+55)))
        render.DrawSprite(basePos + Vector(0,0,100), 180+sp*50, 180+sp*50,
            Color(255, 240, 255, math.floor(sp*150+45)))
    end

    -- Телепорт: мерцание
    if self:GetNWBool("ApexTeleporting", false) then
        local tp = 0.5 + 0.5 * math.sin(t * 22)
        render.DrawSphere(basePos + Vector(0,0,100), 260+tp*45, 12, 12,
            Color(210, 110, 255, math.floor(160+tp*85)))
        render.DrawSprite(basePos + Vector(0,0,100), 580+tp*90, 580+tp*90,
            Color(190, 65, 255, math.floor(tp*150+45)))
    end

    -- Апокалипсис: огненный столп
    if apoc then
        local ap  = 0.5 + 0.5 * math.sin(t * 5.5)
        local ap2 = 0.5 + 0.5 * math.sin(t * 9.0 + 1.2)
        render.DrawSphere(basePos + Vector(0,0,100), 390+ap*65, 14, 14,
            Color(255, 95, 18, math.floor(75+ap*55)))
        render.DrawSprite(basePos + Vector(0,0,100), 900+ap*130, 900+ap*130,
            Color(255, 115, 28, math.floor(ap*105+30)))

        local top = basePos + Vector(0, 0, 1500)
        render.SetMaterial(matBeam)
        render.DrawBeam(basePos + Vector(0,0,50), top, 55+ap*18, 0, 1,
            Color(255, 55, 8, math.floor(55+ap*38)))
        render.DrawBeam(basePos + Vector(0,0,50), top, 28+ap2*10, 0, 1,
            Color(255, 130, 30, math.floor(70+ap2*40)))
        render.DrawBeam(basePos + Vector(0,0,50), top, 12, 0, 1,
            Color(255, 210, 100, math.floor(80+ap*45)))
        render.DrawBeam(basePos + Vector(0,0,50), top, 3, 0, 1,
            Color(255, 255, 220, math.floor(90+ap2*50)))
        render.SetMaterial(matGlow)

        render.DrawSphere(basePos + Vector(0,0,12), 200+ap*40, 8, 8,
            Color(255, 80, 12, math.floor(60+ap*50)))
    end
end