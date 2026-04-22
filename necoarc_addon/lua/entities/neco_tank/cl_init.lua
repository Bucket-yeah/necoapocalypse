include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")
local matBeam  = Material("sprites/laserbeam")

-- Расширяющееся кольцо пыли при ударе
local dustRings = {}  -- { pos, startTime, maxR }

hook.Add("Think", "Tank_DustRings", function()
    local now = CurTime()
    for i = #dustRings, 1, -1 do
        if now - dustRings[i].t > 0.9 then table.remove(dustRings, i) end
    end
end)

-- Серверная часть рассылает net при ударе; здесь ловим флаг через NW
hook.Add("PostDrawTranslucentRenderables", "Tank_DustEffect", function()
    local now = CurTime()

    for _, ent in ipairs(ents.FindByClass("neco_tank")) do
        if not IsValid(ent) then continue end

        -- Когда флаг TankSlam активен — порождаем новое кольцо
        if ent:GetNWBool("TankSlam", false) then
            if not ent._lastSlamRing or now - ent._lastSlamRing > 0.12 then
                ent._lastSlamRing = now
                table.insert(dustRings, { pos = ent:GetPos(), t = now, maxR = 220 })
            end
        end
    end

    render.SetMaterial(matSmoke)
    for _, ring in ipairs(dustRings) do
        local age  = now - ring.t            -- 0..0.9
        local frac = age / 0.9              -- 0..1
        local r    = ring.maxR * frac       -- расширяется
        local a    = math.floor(Lerp(frac, 160, 0))
        local col  = Color(120, 90, 55, a)

        -- 12 спрайтов по окружности на уровне пола
        for i = 1, 12 do
            local ang = i * 30
            local p   = ring.pos
                + Vector(math.cos(math.rad(ang)) * r,
                         math.sin(math.rad(ang)) * r,
                         4)
            local sz  = Lerp(frac, 30, 90)
            render.DrawSprite(p, sz, sz, col)
        end
    end

    -- Дополнительные вертикальные клубы пыли
    for _, ent in ipairs(ents.FindByClass("neco_tank")) do
        if not IsValid(ent) then continue end
        if not ent:GetNWBool("TankSlam", false) then continue end

        render.SetMaterial(matSmoke)
        for i = 1, 6 do
            local offXY = VectorRand() * 60
            offXY.z = math.random(5, 50)
            local p = ent:GetPos() + offXY
            render.DrawSprite(p, math.random(40, 80), math.random(40, 80),
                Color(130, 100, 60, math.random(80, 150)))
        end
        render.SetMaterial(matGlow)
    end
end)

function ENT:Draw()
    render.SetColorModulation(0.58, 0.30, 0.14)
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    -- Эффект удара по земле (TankSlam)
    if self:GetNWBool("TankSlam", false) then
        local t     = CurTime()
        local pulse = 0.5 + 0.5 * math.sin(t * 20)
        local pos   = self:GetPos()

        -- Ударная волна — расширяющиеся кольца
        render.SetMaterial(matGlow)
        render.DrawSphere(pos, 80 + pulse * 20, 16, 16, Color(180, 130, 60, math.floor(120 + pulse * 60)))
        render.DrawSphere(pos, 140, 16, 16, Color(160, 110, 50, 60))

        -- Яркая вспышка в момент удара
        render.DrawSprite(pos, 180, 180, Color(200, 170, 100, math.floor(pulse * 160)))
    end

    -- Эффект раздавливания (TankCrush)
    if self:GetNWBool("TankCrush", false) then
        local pos = self:GetPos()
        local ef  = EffectData()
        ef:SetOrigin(pos)
        ef:SetScale(2)
        util.Effect("Sparks", ef)

        render.SetMaterial(matGlow)
        render.DrawSprite(pos + Vector(0, 0, 20), 120, 120, Color(210, 160, 80, 140))
    end
end
