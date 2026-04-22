include("shared.lua")

local matGlow = Material("sprites/light_glow02_add")
local matBeam = Material("sprites/laserbeam")

-- Пульсирующее ауро-свечение в режиме ярости
hook.Add("PostDrawTranslucentRenderables", "Berserker_RageAura", function()
    for _, ent in ipairs(ents.FindByClass("neco_berserker")) do
        if not IsValid(ent) then continue end
        if not ent:GetNWBool("BerserkerRage", false) then continue end

        local t     = CurTime()
        local pulse = 0.5 + 0.5 * math.sin(t * 10)   -- быстрое биение
        local pos   = ent:GetPos() + ent:OBBCenter()

        render.SetMaterial(matGlow)

        -- Ядро — яркий красный шар
        local coreR = 38 + pulse * 14
        render.DrawSphere(pos, coreR, 16, 16,
            Color(255, 30, 10, math.floor(200 + pulse * 55)))

        -- Средняя оболочка
        render.DrawSphere(pos, coreR + 20, 16, 16,
            Color(255, 60, 20, math.floor(120 + pulse * 60)))

        -- Внешний ореол
        render.DrawSphere(pos, coreR + 50, 16, 16,
            Color(255, 80, 30, math.floor(50 + pulse * 40)))

        -- Большой мягкий спрайт
        local sprSize = 140 + pulse * 40
        render.DrawSprite(pos, sprSize, sprSize,
            Color(255, 50, 10, math.floor(100 + pulse * 80)))

        -- 6 огненных лучей наружу (вращаются)
        render.SetMaterial(matBeam)
        for i = 1, 6 do
            local ang = t * 120 + i * 60
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            local tip = pos + dir * (70 + pulse * 20)
            render.DrawBeam(pos, tip, 4 + pulse * 3, 0, 1,
                Color(255, 80 + math.floor(pulse * 60), 10, math.floor(180 + pulse * 60)))
        end
        render.SetMaterial(matGlow)
    end
end)

function ENT:Draw()
    if self:GetNWBool("BerserkerRage", false) then
        -- В ярости: насыщенный красный + лёгкое мерцание
        local pulse = 0.5 + 0.5 * math.sin(CurTime() * 10)
        render.SetColorModulation(1, 0.08 + pulse * 0.06, 0.04)
        render.SetBlend(1)
        self:DrawModel()
    else
        -- Обычный: тёмно-красный оттенок
        render.SetColorModulation(0.80, 0.12, 0.10)
        render.SetBlend(1)
        self:DrawModel()

        -- Небольшой ambient-glow в спокойном состоянии
        local pulse = 0.5 + 0.5 * math.sin(CurTime() * 1.5)
        local pos   = self:GetPos() + self:OBBCenter()
        render.SetMaterial(matGlow)
        render.DrawSprite(pos, 40, 40, Color(200, 40, 20, math.floor(pulse * 30 + 10)))
    end
    render.SetColorModulation(1, 1, 1)
    render.SetBlend(1)
end
