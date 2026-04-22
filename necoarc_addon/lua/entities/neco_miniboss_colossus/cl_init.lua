include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")
local matBeam  = Material("sprites/laserbeam")

-- =========================================================
--  МЕТАЛЛИЧЕСКИЙ БЛИК (скользит по телу)
-- =========================================================
local function DrawSteelSheen(ent)
    local t     = CurTime()
    local phase = (t % 4) / 4
    local shine = math.max(0, 1 - math.abs(phase - 0.5) * 10)
    if shine < 0.01 then return end

    local center = ent:GetPos() + ent:OBBCenter()
    local right  = ent:GetRight()
    local blikPos = center + right * Lerp(phase, -30, 30)

    render.SetMaterial(matGlow)
    render.DrawSprite(blikPos, 22, 80, Color(180, 210, 255, math.floor(shine * 180)))
    render.DrawSprite(center,  80, 80, Color(140, 180, 255, math.floor(shine * 50)))
end

-- =========================================================
--  ТУМАН ПРОВОКАЦИИ — облака через Think
-- =========================================================
local fogClouds = {}

hook.Add("Think", "Colossus_FogSpawn", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_miniboss_colossus")) do
        if not IsValid(ent) or not ent:GetNWBool("ColossusTaunt", false) then continue end

        if not ent._nextFogT or ent._nextFogT < now then
            ent._nextFogT = now + 0.06
            for _ = 1, 5 do
                local offXY = VectorRand() * 180
                offXY.z = math.random(0, 80)
                table.insert(fogClouds, {
                    pos  = ent:GetPos() + offXY,
                    t    = now,
                    seed = math.random(1, 9999)
                })
            end
        end
    end

    for i = #fogClouds, 1, -1 do
        if now - fogClouds[i].t > 3.0 then table.remove(fogClouds, i) end
    end
end)

-- =========================================================
--  УДАРНАЯ ВОЛНА — расширяющееся кольцо
-- =========================================================
local shockwaveRings = {}

hook.Add("Think", "Colossus_ShockwaveTrack", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_miniboss_colossus")) do
        if not IsValid(ent) then continue end
        if ent:GetNWBool("ColossusShockwave", false) then
            if not ent._lastShockRing or ent._lastShockRing < now then
                ent._lastShockRing = now + 99 -- ставим очень вперёд, чтоб не спавнить дважды
                table.insert(shockwaveRings, { pos = ent:GetPos(), t = now, maxR = 340 })
            end
        else
            ent._lastShockRing = nil
        end
    end
    for i = #shockwaveRings, 1, -1 do
        if now - shockwaveRings[i].t > 0.7 then table.remove(shockwaveRings, i) end
    end
end)

-- =========================================================
--  PostDrawTranslucentRenderables
-- =========================================================
hook.Add("PostDrawTranslucentRenderables", "Colossus_FX", function()
    local now = CurTime()

    -- 1. ТУМАНные облака
    render.SetMaterial(matSmoke)
    for _, cloud in ipairs(fogClouds) do
        local age  = now - cloud.t
        local frac = age / 3.0
        local a    = math.floor(Lerp(frac, 140, 0))
        local sz   = Lerp(frac, 50, 260)
        local drift = age * 12 + math.sin(cloud.seed * 0.017) * 20
        local p = cloud.pos + Vector(
            math.sin(cloud.seed * 0.023) * drift,
            math.cos(cloud.seed * 0.023) * drift,
            age * 10)
        render.DrawSprite(p, sz, sz, Color(160, 185, 230, a))
    end

    -- 2. Пыльные кольца ударной волны
    for _, ring in ipairs(shockwaveRings) do
        local age  = now - ring.t
        local frac = math.min(age / 0.6, 1)
        local r    = ring.maxR * frac
        local a    = math.floor(Lerp(frac, 200, 0))
        local col  = Color(120, 160, 255, a)

        render.SetMaterial(matSmoke)
        for i = 1, 18 do
            local ang = i * 20
            local p   = ring.pos + Vector(
                math.cos(math.rad(ang)) * r,
                math.sin(math.rad(ang)) * r, 5)
            render.DrawSprite(p, Lerp(frac, 25, 80), Lerp(frac, 25, 80), col)
        end

        -- Лучи ударной волны
        render.SetMaterial(matBeam)
        for i = 1, 8 do
            local ang = i * 45
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            render.DrawBeam(ring.pos, ring.pos + dir * r, 6 * (1 - frac), 0, 1,
                Color(140, 180, 255, math.floor(180 * (1 - frac))))
        end
        render.SetMaterial(matGlow)
    end

    render.SetMaterial(matGlow)
end)

-- =========================================================
--  ENT:Draw
-- =========================================================
function ENT:Draw()
    local t = CurTime()

    -- Стально-синий оттенок (не сплошной цвет)
    render.SetColorModulation(0.48, 0.62, 1.0)
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    -- Скользящий металлический блик
    DrawSteelSheen(self)

    local center = self:GetPos() + self:OBBCenter()

    -- ── ПРОВОКАЦИЯ ──────────────────────────────────────────
    if self:GetNWBool("ColossusTaunt", false) then
        local pulse = 0.5 + 0.5 * math.sin(t * 2.8)

        render.SetMaterial(matGlow)

        -- Тело свечения
        render.DrawSphere(center, 120 + pulse * 25, 16, 16,
            Color(100, 150, 255, math.floor(55 + pulse * 35)))
        render.DrawSphere(center, 200 + pulse * 30, 16, 16,
            Color(90, 135, 240, math.floor(25 + pulse * 20)))

        -- Мягкий большой спрайт
        render.DrawSprite(center, 520 + pulse * 60, 520 + pulse * 60,
            Color(110, 155, 255, math.floor(35 + pulse * 25)))

        -- Вертикальный столп света вверх
        local top = center + Vector(0, 0, 400)
        render.SetMaterial(matBeam)
        render.DrawBeam(center, top, 18 + pulse * 6, 0, 1,
            Color(110, 160, 255, math.floor(60 + pulse * 40)))
        render.DrawBeam(center, top, 6, 0, 1,
            Color(180, 210, 255, math.floor(80 + pulse * 50)))
        render.SetMaterial(matGlow)

        -- 4 вращающихся орбитальных луча
        render.SetMaterial(matBeam)
        for i = 1, 4 do
            local ang = t * 50 + i * 90
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0.25)
            dir:Normalize()
            render.DrawBeam(center, center + dir * (160 + pulse * 20), 3, 0, 1,
                Color(120, 170, 255, math.floor(140 + pulse * 60)))
        end
        render.SetMaterial(matGlow)
    end

    -- ── УДАРНАЯ ВОЛНА ────────────────────────────────────────
    if self:GetNWBool("ColossusShockwave", false) then
        local pulse = 0.5 + 0.5 * math.sin(t * 30)

        render.SetMaterial(matGlow)
        -- Яркая вспышка в точке удара
        render.DrawSprite(self:GetPos(), 300 + pulse * 40, 300 + pulse * 40,
            Color(140, 190, 255, math.floor(150 + pulse * 80)))
        render.DrawSphere(self:GetPos(), 80, 16, 16,
            Color(160, 200, 255, math.floor(180 + pulse * 60)))
    end

    -- ── ЭМИ-ВСПЫШКА ─────────────────────────────────────────
    if self:GetNWBool("ColossusEMI", false) then
        local pulse = 0.5 + 0.5 * math.sin(t * 18)
        local pos   = self:GetPos() + Vector(0, 0, 60)

        render.SetMaterial(matGlow)
        -- Три пульсирующие сферы
        render.DrawSphere(pos, 200 + pulse * 20, 16, 16,
            Color(100, 200, 255, math.floor(160 + pulse * 80)))
        render.DrawSphere(pos, 290 + pulse * 25, 16, 16,
            Color(80, 170, 255, math.floor(90 + pulse * 50)))
        render.DrawSphere(pos, 390 + pulse * 30, 16, 16,
            Color(60, 140, 255, math.floor(40 + pulse * 30)))
        -- Огромный спрайт-вспышка
        render.DrawSprite(pos, 700 + pulse * 80, 700 + pulse * 80,
            Color(120, 190, 255, math.floor(pulse * 80 + 20)))

        -- 8 молниевых лучей наружу
        render.SetMaterial(matBeam)
        for i = 1, 8 do
            local ang = t * 60 + i * 45
            local jit = Vector(math.random(-15, 15), math.random(-15, 15), 0)
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            render.DrawBeam(pos, pos + dir * (380 + pulse * 30) + jit, 4 + pulse * 2, 0, 1,
                Color(100, 200, 255, math.floor(180 + pulse * 70)))
            -- Белая сердцевина
            render.DrawBeam(pos, pos + dir * (350 + pulse * 20) + jit, 1.5, 0, 1,
                Color(220, 240, 255, math.floor(140 + pulse * 60)))
        end
        render.SetMaterial(matGlow)
    end

    -- ── AMBIENT ПУЛЬСАЦИЯ (всегда) ───────────────────────────
    local ap = 0.5 + 0.5 * math.sin(t * 1.4)
    render.SetMaterial(matGlow)
    render.DrawSprite(center, 65 + ap * 15, 65 + ap * 15,
        Color(120, 165, 255, math.floor(ap * 30 + 10)))
end

-- =========================================================
--  ЭМИ — экранные эффекты игрока
-- =========================================================
hook.Add("Think", "Colossus_EMIEffect", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if ply.EMIActive and CurTime() < (ply.EMIEnd or 0) then
        ply:ScreenFade(SCREENFADE.MODULATE, Color(100, 180, 255, 100), 0.1, 0)
        RunConsoleCommand("volume", "0.2")
    elseif ply.EMIActive then
        ply.EMIActive = false
        RunConsoleCommand("volume", "1.0")
    end
end)

hook.Add("HUDShouldDraw", "Colossus_HideHUD", function(name)
    local ply = LocalPlayer()
    if IsValid(ply) and ply.EMIActive and CurTime() < (ply.EMIEnd or 0) then
        return false
    end
end)
