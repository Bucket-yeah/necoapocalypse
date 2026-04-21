include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")
local matBeam  = Material("sprites/laserbeam")

-- =========================================================
--  ВИХРЬ РИТУАЛА — частицы по спирали при SummonerRitual
-- =========================================================
local ritualParticles = {}

hook.Add("Think", "Summoner_RitualParticles", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_summoner")) do
        if not IsValid(ent) then continue end
        if not ent:GetNWBool("SummonerRitual", false) then continue end

        if (ent._nextRitualP or 0) < now then
            ent._nextRitualP = now + 0.05
            local angle = (now * 180) % 360
            for i = 0, 2 do
                local a = angle + i * 120
                local r = 80 + math.sin(now * 3 + i) * 20
                table.insert(ritualParticles, {
                    pos  = ent:GetPos() + Vector(
                        math.cos(math.rad(a)) * r,
                        math.sin(math.rad(a)) * r,
                        math.random(5, 60)),
                    vel  = Vector(0, 0, math.random(20, 45)),
                    t    = now,
                    life = 0.7 + math.random() * 0.5,
                    sz   = math.random(12, 24)
                })
            end
        end
    end
    for i = #ritualParticles, 1, -1 do
        if now - ritualParticles[i].t > ritualParticles[i].life then
            table.remove(ritualParticles, i)
        end
    end
end)

-- =========================================================
--  ЖЕРТВОПРИНОШЕНИЕ — расширяющаяся волна от точки жертвы
-- =========================================================
local sacrificeWaves = {}

hook.Add("Think", "Summoner_SacrificeWave", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_summoner")) do
        if not IsValid(ent) then continue end
        if ent:GetNWBool("SummonerSacrificeBeam", false) and not ent._sacrificeTracked then
            ent._sacrificeTracked = true
            local pos = ent:GetNWVector("SummonerSacrificeBeamPos", ent:GetPos())
            table.insert(sacrificeWaves, { pos = pos, t = now })
        elseif not ent:GetNWBool("SummonerSacrificeBeam", false) then
            ent._sacrificeTracked = false
        end
    end
    for i = #sacrificeWaves, 1, -1 do
        if now - sacrificeWaves[i].t > 4.0 then table.remove(sacrificeWaves, i) end
    end
end)

-- =========================================================
--  PostDraw
-- =========================================================
hook.Add("PostDrawTranslucentRenderables", "Summoner_FX", function()
    local now = CurTime()

    -- 1. Частицы ритуала
    render.SetMaterial(matSmoke)
    for _, p in ipairs(ritualParticles) do
        local age  = now - p.t
        local frac = age / p.life
        local pos  = p.pos + p.vel * age
        local a    = math.floor(Lerp(frac, 200, 0))
        local sz   = Lerp(frac, p.sz, p.sz * 2)
        render.DrawSprite(pos, sz, sz, Color(100, 20, 180, a))
    end

    -- 2. Волна от жертвоприношения
    for _, wave in ipairs(sacrificeWaves) do
        local age  = now - wave.t
        local frac = math.min(age / 1.5, 1)
        local r    = frac * 300
        local a    = math.floor(Lerp(frac, 200, 0))

        render.SetMaterial(matSmoke)
        for i = 1, 14 do
            local ang = i * (360 / 14)
            local p   = wave.pos + Vector(
                math.cos(math.rad(ang)) * r,
                math.sin(math.rad(ang)) * r, 5)
            render.DrawSprite(p, Lerp(frac, 20, 70), Lerp(frac, 20, 70),
                Color(180, 30, 255, a))
        end

        render.SetMaterial(matGlow)
        render.DrawSphere(wave.pos + Vector(0, 0, 30), r * 0.4, 12, 12,
            Color(150, 20, 220, math.floor(a * 0.35)))
    end

    render.SetMaterial(matGlow)
end)

-- =========================================================
--  ENT:Draw
-- =========================================================
function ENT:Draw()
    local t = CurTime()

    -- Тёмно-фиолетовый тинт
    local ritualActive = self:GetNWBool("SummonerRitual", false)
    if ritualActive then
        -- В ритуале: насыщеннее
        local pulse = 0.5 + 0.5 * math.sin(t * 6)
        render.SetColorModulation(0.50 + pulse * 0.10, 0.10, 0.70 + pulse * 0.15)
    else
        render.SetColorModulation(0.38, 0.06, 0.55)
    end
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    local center = self:GetPos() + self:OBBCenter()
    local pulse  = 0.5 + 0.5 * math.sin(t * 1.8)

    render.SetMaterial(matGlow)

    -- Ambient фиолетовое свечение
    render.DrawSprite(center, 65 + pulse * 16, 65 + pulse * 16,
        Color(160, 30, 230, math.floor(pulse * 40 + 15)))

    -- ── ПРИЗЫВ (SummonerSummon, 0.5 сек) ────────────────────
    if self:GetNWBool("SummonerSummon", false) then
        local sp = 0.5 + 0.5 * math.sin(t * 25)
        render.SetMaterial(matGlow)
        render.DrawSphere(center, 90 + sp * 25, 16, 16,
            Color(180, 80, 255, math.floor(180 + sp * 75)))
        render.DrawSphere(center, 130 + sp * 30, 16, 16,
            Color(150, 50, 230, math.floor(100 + sp * 50)))
        render.DrawSprite(center, 250 + sp * 40, 250 + sp * 40,
            Color(200, 100, 255, math.floor(sp * 130 + 40)))

        -- 4 вращающихся луча при выбросе миньонов
        render.SetMaterial(matBeam)
        for i = 1, 4 do
            local ang = t * 300 + i * 90
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0.2)
            dir:Normalize()
            render.DrawBeam(center, center + dir * (110 + sp * 20), 4 + sp * 2, 0, 1,
                Color(200, 80, 255, math.floor(200 + sp * 55)))
        end
        render.SetMaterial(matGlow)
    end

    -- ── РИТУАЛ (SummonerRitual) ──────────────────────────────
    if ritualActive then
        local rp = 0.5 + 0.5 * math.sin(t * 4)

        render.SetMaterial(matGlow)

        -- Три концентрических пульсирующих сферы
        render.DrawSphere(center, 110 + rp * 20, 16, 16,
            Color(120, 30, 220, math.floor(100 + rp * 60)))
        render.DrawSphere(center, 160 + rp * 25, 16, 16,
            Color(100, 20, 200, math.floor(55 + rp * 35)))
        render.DrawSphere(center, 220 + rp * 30, 16, 16,
            Color(80, 10, 170, math.floor(25 + rp * 20)))

        -- Большой мягкий ореол
        render.DrawSprite(center, 450 + rp * 60, 450 + rp * 60,
            Color(130, 40, 220, math.floor(30 + rp * 25)))

        -- Вертикальный тёмный столп
        local top = center + Vector(0, 0, 350)
        render.SetMaterial(matBeam)
        render.DrawBeam(center, top, 14 + rp * 5, 0, 1,
            Color(100, 20, 200, math.floor(60 + rp * 45)))
        render.DrawBeam(center, top, 4, 0, 1,
            Color(200, 140, 255, math.floor(80 + rp * 50)))

        -- 6 спиральных лучей вокруг (вращаются медленно)
        for i = 1, 6 do
            local ang = t * 35 + i * 60
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0.3)
            dir:Normalize()
            local tipR = 180 + rp * 30
            render.DrawBeam(center, center + dir * tipR, 3, 0, 1,
                Color(160, 50, 240, math.floor(120 + rp * 60)))
        end
        render.SetMaterial(matGlow)
    end

    -- ── ЖЕРТВОПРИНОШЕНИЕ (SummonerSacrifice) ────────────────
    if self:GetNWBool("SummonerSacrifice", false) then
        local sp = 0.5 + 0.5 * math.sin(t * 10)
        render.SetMaterial(matGlow)

        -- Красно-фиолетовый «заряженный» ореол
        render.DrawSphere(center, 80 + sp * 15, 12, 12,
            Color(255, 40, 200, math.floor(160 + sp * 70)))
        render.DrawSphere(center, 110 + sp * 20, 12, 12,
            Color(220, 20, 170, math.floor(80 + sp * 40)))
        render.DrawSprite(center, 200 + sp * 30, 200 + sp * 30,
            Color(255, 60, 200, math.floor(sp * 100 + 30)))

        -- Быстрые орбиты
        render.SetMaterial(matBeam)
        for i = 1, 3 do
            local ang = t * 220 + i * 120
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            render.DrawBeam(center, center + dir * (90 + sp * 20), 3 + sp * 2, 0, 1,
                Color(255, 50, 200, math.floor(180 + sp * 60)))
        end
        render.SetMaterial(matGlow)
    end

    -- ── ЛУЧ ЖЕРТВОПРИНОШЕНИЯ (SummonerSacrificeBeam) ────────
    if self:GetNWBool("SummonerSacrificeBeam", false) then
        local sacrificePos = self:GetNWVector("SummonerSacrificeBeamPos", self:GetPos())
        local sp = 0.5 + 0.5 * math.sin(t * 8)

        render.SetMaterial(matBeam)

        -- Луч от точки жертвы вверх (сам портал)
        local beamTop = sacrificePos + Vector(0, 0, 550)
        render.DrawBeam(sacrificePos, beamTop, 14 + sp * 4, 0, 1,
            Color(160, 20, 255, math.floor(130 + sp * 70)))
        render.DrawBeam(sacrificePos, beamTop, 5, 0, 1,
            Color(230, 160, 255, math.floor(150 + sp * 80)))
        -- Тонкая белая сердцевина
        render.DrawBeam(sacrificePos, beamTop, 1.5, 0, 1,
            Color(255, 240, 255, math.floor(100 + sp * 60)))

        -- Луч от суммонера к точке жертвы (канал энергии)
        render.DrawBeam(center, sacrificePos, 3 + sp * 1.5, 0, 1,
            Color(180, 60, 255, math.floor(100 + sp * 60)))
        render.DrawBeam(center, sacrificePos, 1, 0, 1,
            Color(240, 200, 255, math.floor(80 + sp * 40)))

        render.SetMaterial(matGlow)

        -- Сфера в точке жертвы
        render.DrawSphere(sacrificePos + Vector(0,0,20), 50 + sp * 15, 12, 12,
            Color(180, 30, 255, math.floor(160 + sp * 60)))
        render.DrawSprite(sacrificePos, 120 + sp * 25, 120 + sp * 25,
            Color(200, 80, 255, math.floor(sp * 100 + 40)))
    end
end
