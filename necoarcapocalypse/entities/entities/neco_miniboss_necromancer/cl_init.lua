include("shared.lua")

local matBeam  = Material("sprites/laserbeam")
local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")

-- =========================================================
--  ДРЕНАЖ ДУШ — частицы летят к Некроманту
-- =========================================================
local drainParticles = {}   -- { pos, vel, toward, t, life }

hook.Add("Think", "Necro_DrainParticles", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_miniboss_necromancer")) do
        if not IsValid(ent) then continue end
        if not ent:GetNWBool("NecroSoulDrain", false) then continue end

        if (ent._drainParticleNext or 0) < now then
            ent._drainParticleNext = now + 0.05

            local necroPos = ent:GetPos() + ent:OBBCenter()

            -- 6 частиц спавнятся по кругу вокруг некроманта и летят к нему
            for i = 1, 6 do
                local ang = math.random(0, 360)
                local r   = math.random(80, 220)
                local startPos = necroPos + Vector(
                    math.cos(math.rad(ang)) * r,
                    math.sin(math.rad(ang)) * r,
                    math.random(-30, 60))
                local toNecro = (necroPos - startPos):GetNormalized()
                table.insert(drainParticles, {
                    pos   = startPos,
                    vel   = toNecro * math.random(120, 260),
                    necro = ent,  -- ссылка на некроманта
                    t     = now,
                    life  = r / math.random(120, 260),
                    sz    = math.random(6, 16)
                })
            end
        end
    end
    for i = #drainParticles, 1, -1 do
        if now - drainParticles[i].t > drainParticles[i].life then
            table.remove(drainParticles, i)
        end
    end
end)

-- =========================================================
--  СМЕРТЬ — взрыв тёмной энергии
-- =========================================================
local deathFX = {}   -- { pos, t }

hook.Add("EntityRemoved", "Necro_DeathFX", function(ent)
    if not IsValid(ent) then return end
    if ent:GetClass() ~= "neco_miniboss_necromancer" then return end

    local pos = ent:GetPos()
    table.insert(deathFX, { pos = pos, t = CurTime() })

    -- Взрыв тёмных частиц-дыма
    local now = CurTime()
    for _ = 1, 50 do
        local dir = VectorRand():GetNormalized()
        table.insert(drainParticles, {
            pos   = pos + Vector(0, 0, 50),
            vel   = dir * math.random(60, 200),
            necro = nil,
            t     = now,
            life  = 0.5 + math.random() * 0.8,
            sz    = math.random(10, 28)
        })
    end
end)

-- =========================================================
--  Портальные частицы
-- =========================================================
local portalParticles = {}

hook.Add("Think", "Necro_PortalParticles", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_miniboss_necromancer")) do
        if not IsValid(ent) then continue end
        if not ent:GetNWBool("NecroSummonBeam", false) then continue end

        local pos = ent:GetNWVector("NecroSummonBeamPos", ent:GetPos())
        if not ent._nextParticleT or ent._nextParticleT < now then
            ent._nextParticleT = now + 0.04
            for _ = 1, 4 do
                local ang = math.random(0, 360)
                local r   = math.random(40, 120)
                table.insert(portalParticles, {
                    pos  = pos + Vector(
                        math.cos(math.rad(ang)) * r,
                        math.sin(math.rad(ang)) * r,
                        math.random(-20, 70)),
                    vel  = Vector(
                        math.random(-12, 12),
                        math.random(-12, 12),
                        math.random(8, 28)),
                    t    = now,
                    life = 0.6 + math.random() * 0.5
                })
            end
        end
    end
    for i = #portalParticles, 1, -1 do
        if now - portalParticles[i].t > portalParticles[i].life then
            table.remove(portalParticles, i)
        end
    end
end)

-- =========================================================
--  PostDraw
-- =========================================================
hook.Add("PostDrawTranslucentRenderables", "Necro_AllPostDraw", function()
    local now = CurTime()

    -- 1. Частицы дренажа (тёмно-красные/фиолетовые, летят к некроманту)
    render.SetMaterial(matGlow)
    for _, p in ipairs(drainParticles) do
        local age  = now - p.t
        local frac = age / p.life
        local pos  = p.pos + p.vel * age

        -- Цвет: тёмно-красный → фиолетовый → угасает
        local r = math.floor(Lerp(frac, 200, 80))
        local g = math.floor(Lerp(frac, 10, 0))
        local b = math.floor(Lerp(frac, 60, 180))
        local a = math.floor(Lerp(frac, 220, 0))
        local sz = Lerp(frac, p.sz, p.sz * 0.4)

        render.DrawSprite(pos, sz, sz, Color(r, g, b, a))
    end

    -- 2. Портальные частицы
    render.SetMaterial(matSmoke)
    for _, p in ipairs(portalParticles) do
        local age  = now - p.t
        local frac = age / p.life
        local pos  = p.pos + p.vel * age
        local a    = math.floor(Lerp(frac, 190, 0))
        local sz   = Lerp(frac, 14, 50)
        render.DrawSprite(pos, sz, sz, Color(15, 0, 22, a))
    end

    -- 3. Эффект смерти — коллапс тёмной сферы
    render.SetMaterial(matGlow)
    for i = #deathFX, 1, -1 do
        local fx   = deathFX[i]
        local age  = now - fx.t
        if age > 3.0 then table.remove(deathFX, i); continue end

        local frac = age / 3.0

        -- Фаза 1 (0-0.3с): быстрое расширение
        -- Фаза 2 (0.3-3с): медленное угасание
        local expandFrac = math.min(age / 0.3, 1)
        local fadeFrac   = math.max((age - 0.3) / 2.7, 0)

        local r    = Lerp(expandFrac, 60, 300) * (1 - fadeFrac)
        local a    = math.floor(Lerp(expandFrac, 220, 180) * (1 - fadeFrac))

        render.DrawSphere(fx.pos + Vector(0, 0, 40), r, 16, 16,
            Color(80, 0, 130, math.max(0, a)))
        render.DrawSphere(fx.pos + Vector(0, 0, 40), r * 1.4, 16, 16,
            Color(50, 0, 80, math.max(0, math.floor(a * 0.4))))
        render.DrawSprite(fx.pos + Vector(0, 0, 40),
            r * 3 * expandFrac, r * 3 * expandFrac,
            Color(120, 10, 200, math.max(0, math.floor(Lerp(fadeFrac, 180, 0)))))

        -- 8 лучей при взрыве
        if expandFrac < 1 then
            render.SetMaterial(matBeam)
            for j = 1, 8 do
                local ang = j * 45
                local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0.3)
                dir:Normalize()
                render.DrawBeam(fx.pos + Vector(0,0,40),
                    fx.pos + Vector(0,0,40) + dir * r * 1.2,
                    6 * (1 - expandFrac), 0, 1,
                    Color(140, 20, 220, math.floor(200 * (1 - expandFrac))))
            end
            render.SetMaterial(matGlow)
        end
    end

    render.SetMaterial(matGlow)
end)

-- =========================================================
--  ENT:Draw
-- =========================================================
function ENT:Draw()
    local t = CurTime()

    render.SetColorModulation(0.10, 0.04, 0.14)
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    local ambPulse = 0.5 + 0.5 * math.sin(t * 1.5)
    local center   = self:GetPos() + self:OBBCenter()

    render.SetMaterial(matGlow)
    render.DrawSprite(center, 70, 70,
        Color(120, 20, 180, math.floor(ambPulse * 40 + 15)))

    -- ── ДРЕНАЖ ДУШ (NecroSoulDrain) ─────────────────────────
    if self:GetNWBool("NecroSoulDrain", false) then
        local pulse = 0.5 + 0.5 * math.sin(t * 8)
        local pos   = self:GetPos() + Vector(0, 0, 60)

        render.SetMaterial(matGlow)

        -- Пульсирующее кроваво-красное ядро поглощения
        render.DrawSphere(pos, 55 + pulse * 20, 12, 12,
            Color(180, 0, 60, math.floor(200 + pulse * 55)))
        -- Тёмно-фиолетовая оболочка
        render.DrawSphere(pos, 80 + pulse * 25, 12, 12,
            Color(100, 0, 140, math.floor(130 + pulse * 50)))
        -- Внешняя дымка
        render.DrawSphere(pos, 110 + pulse * 30, 12, 12,
            Color(60, 0, 90, math.floor(55 + pulse * 35)))

        -- Большой пульсирующий спрайт-вспышка
        render.DrawSprite(pos, 220 + pulse * 50, 220 + pulse * 50,
            Color(160, 0, 80, math.floor(pulse * 90 + 25)))

        -- 3 коротких луча-щупальца наружу (втягивают энергию)
        render.SetMaterial(matBeam)
        for i = 1, 3 do
            local ang = t * 150 + i * 120
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            render.DrawBeam(pos, pos + dir * (100 + pulse * 30), 4 + pulse * 2, 0, 1,
                Color(200, 0, 80, math.floor(160 + pulse * 70)))
        end
        render.SetMaterial(matGlow)
    end

    -- ── ЛУЧА ЗАРЯДКИ ────────────────────────────────────────
    if self:GetNWBool("NecroBeamCharging", false) then
        local target = self:GetNWEntity("NecroBeamTarget")
        if IsValid(target) then
            local pulse = 0.5 + 0.5 * math.sin(t * 15)
            render.SetMaterial(matBeam)
            render.DrawBeam(self:EyePos(), target:EyePos(),
                1.5 + pulse, 0, 1,
                Color(180, 80, 255, math.floor(80 + pulse * 80)))
        end
    end

    -- ── АКТИВНЫЙ ЛУЧ ────────────────────────────────────────
    if self:GetNWBool("NecroBeamActive", false) then
        local targetPos = self:GetNWVector("NecroBeamPos", self:GetPos())
        local pulse     = 0.5 + 0.5 * math.sin(t * 20)
        render.SetMaterial(matBeam)
        render.DrawBeam(self:EyePos(), targetPos, 3, 0, 1,
            Color(220, 120, 255, 255))
        render.DrawBeam(self:EyePos(), targetPos, 8 + pulse * 3, 0, 1,
            Color(160, 60, 220, math.floor(80 + pulse * 60)))
    end

    -- ── ПОРТАЛ (NecroSummonBeam) ─────────────────────────────
    if self:GetNWBool("NecroSummonBeam", false) then
        local pos   = self:GetNWVector("NecroSummonBeamPos", self:GetPos())
        local pulse = 0.5 + 0.5 * math.sin(t * 4)
        local spin  = t * 60

        render.SetMaterial(matGlow)
        render.DrawSphere(pos, 80 + pulse * 10, 16, 16,
            Color(10, 0, 15, math.floor(210 + pulse * 45)))
        render.DrawSphere(pos, 100 + pulse * 12, 16, 16,
            Color(20, 0, 35, math.floor(160 + pulse * 30)))
        render.DrawSphere(pos, 130, 16, 16,
            Color(60, 0, 90, math.floor(80 + pulse * 30)))
        render.DrawSprite(pos, 280 + pulse * 30, 280 + pulse * 30,
            Color(25, 0, 40, math.floor(80 + pulse * 40)))

        render.SetMaterial(matBeam)
        for i = 1, 4 do
            local ang = spin + i * 90
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            render.DrawBeam(pos, pos + dir * (120 + pulse * 20), 5 + pulse * 2, 0, 1,
                Color(40, 0, 60, math.floor(180 + pulse * 60)))
        end

        render.SetMaterial(matSmoke)
        for _ = 1, 3 do
            local offXY = VectorRand() * 60
            offXY.z = math.random(0, 100)
            render.DrawSprite(pos + offXY, math.random(40, 90), math.random(40, 90),
                Color(8, 0, 12, math.random(120, 180)))
        end
        render.SetMaterial(matGlow)
    end
end
