include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")
local matBeam  = Material("sprites/laserbeam")

-- =========================================================
--  ЧАСТИЦЫ ИСЦЕЛЕНИЯ — поднимаются вверх от хилера
-- =========================================================
local healParticles = {}

hook.Add("Think", "Healer_HealParticles", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_healer")) do
        if not IsValid(ent) then continue end
        if (ent._nextHealParticle or 0) > now then continue end
        ent._nextHealParticle = now + 0.12

        -- Маленькие зелёные крестики/искры поднимаются вверх
        for _ = 1, 2 do
            local offXY = VectorRand() * 22
            offXY.z = 0
            table.insert(healParticles, {
                pos  = ent:GetPos() + Vector(offXY.x, offXY.y, math.random(10, 40)),
                vel  = Vector(math.random(-8, 8), math.random(-8, 8), math.random(28, 55)),
                t    = now,
                life = 0.8 + math.random() * 0.6,
                sz   = math.random(8, 16)
            })
        end
    end
    for i = #healParticles, 1, -1 do
        if now - healParticles[i].t > healParticles[i].life then
            table.remove(healParticles, i)
        end
    end
end)

-- =========================================================
--  PostDraw: частицы + ИНДИКАТОР БЛАГОСЛОВЕНИЯ над целями
-- =========================================================
hook.Add("PostDrawTranslucentRenderables", "NAA_HealerFX", function()
    local now = CurTime()

    -- 1. Частицы исцеления
    render.SetMaterial(matGlow)
    for _, p in ipairs(healParticles) do
        local age  = now - p.t
        local frac = age / p.life
        local pos  = p.pos + p.vel * age
        local a    = math.floor(Lerp(frac, 200, 0))
        local sz   = Lerp(frac, p.sz, p.sz * 2.5)
        render.DrawSprite(pos, sz, sz, Color(80, 255, 120, a))
    end

    -- 2. Индикатор благословения над союзниками
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        if not ent:GetNWBool("NecoBlessed", false) then continue end

        local endTime = ent:GetNWFloat("NecoBlessEnd", 0)
        if CurTime() >= endTime then
            ent:SetNWBool("NecoBlessed", false)
            continue
        end

        local t        = now
        local pulse    = 0.5 + 0.5 * math.sin(t * 3.5)
        local timeLeft = endTime - now
        local frac     = math.min(timeLeft / 8, 1)   -- предполагаем ~8 сек длительность

        local topZ = ent:OBBMaxs().z + 18
        local pos  = ent:GetPos() + Vector(0, 0, topZ)

        render.SetMaterial(matGlow)

        -- Пульсирующий нимб над головой
        local haloSize = 32 + pulse * 10
        render.DrawSprite(pos, haloSize, haloSize,
            Color(60, 240, 100, math.floor(160 + pulse * 60)))
        -- Внешний мягкий ореол
        render.DrawSprite(pos, haloSize * 2.2, haloSize * 2.2,
            Color(60, 200, 80, math.floor(50 + pulse * 30)))

        -- 3 маленьких орбитальных огня (вращаются по нимбу)
        for i = 1, 3 do
            local ang = t * 120 + i * 120
            local r   = 20 + pulse * 4
            local op  = pos + Vector(
                math.cos(math.rad(ang)) * r,
                math.sin(math.rad(ang)) * r, 0)
            render.DrawSprite(op, 8 + pulse * 3, 8 + pulse * 3,
                Color(120, 255, 140, math.floor(200 + pulse * 55)))
        end

        -- Вертикальная колонна (чем меньше времени, тем тусклее)
        render.SetMaterial(matBeam)
        local colTop = pos + Vector(0, 0, 55)
        render.DrawBeam(pos, colTop, 3 + pulse, 0, 1,
            Color(80, 255, 110, math.floor(frac * (80 + pulse * 50))))
        render.DrawBeam(pos, colTop, 1, 0, 1,
            Color(200, 255, 210, math.floor(frac * (60 + pulse * 30))))
        render.SetMaterial(matGlow)

        -- Таймер над головой — красивый 3D текст (без отладочного вида)
        local timerPos = pos + Vector(0, 0, 70)
        local timeLeftSec = math.ceil(timeLeft)
        local textAlpha   = math.floor(Lerp(math.min(timeLeft, 2) / 2, 80, 220))
        cam.Start3D2D(timerPos, Angle(0, (LocalPlayer():EyeAngles().y + 180) % 360, 0), 0.22)
            draw.SimpleTextOutlined(
                "✦ " .. timeLeftSec .. "с",
                "DermaDefaultBold",
                0, 0,
                Color(100, 255, 130, textAlpha),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                2, Color(0, 0, 0, textAlpha))
        cam.End3D2D()
    end

    render.SetMaterial(matGlow)
end)

-- =========================================================
--  ENT:Draw
-- =========================================================
function ENT:Draw()
    local t = CurTime()

    -- Изумрудный тинт через SetColorModulation (не ModelMaterialOverride)
    render.SetColorModulation(0.20, 0.92, 0.38)
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    local center = self:GetPos() + self:OBBCenter()
    local pulse  = 0.5 + 0.5 * math.sin(t * 2.2)

    render.SetMaterial(matGlow)

    -- Ambient зелёное свечение
    render.DrawSprite(center, 55 + pulse * 14, 55 + pulse * 14,
        Color(50, 230, 90, math.floor(pulse * 45 + 18)))

    -- Пульсирующий «медицинский» крест над головой
    local crossPos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 30)
    local cs = 14 + pulse * 4

    render.SetMaterial(matBeam)
    -- Горизонтальная перекладина
    render.DrawBeam(
        crossPos + Vector(-cs, 0, 0),
        crossPos + Vector( cs, 0, 0),
        3 + pulse, 0, 1,
        Color(80, 255, 120, math.floor(180 + pulse * 60)))
    -- Вертикальная перекладина
    render.DrawBeam(
        crossPos + Vector(0, 0, -cs),
        crossPos + Vector(0, 0,  cs),
        3 + pulse, 0, 1,
        Color(80, 255, 120, math.floor(180 + pulse * 60)))

    render.SetMaterial(matGlow)
    -- Свечение центра креста
    render.DrawSprite(crossPos, 18 + pulse * 6, 18 + pulse * 6,
        Color(140, 255, 160, math.floor(200 + pulse * 55)))
end
