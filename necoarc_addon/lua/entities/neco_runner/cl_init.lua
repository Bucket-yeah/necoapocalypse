include("shared.lua")

local matBeam  = Material("sprites/laserbeam")

-- =========================================================
--  Линии стаи
-- =========================================================
hook.Add("PostDrawTranslucentRenderables", "Runner_PackLines", function()
    local runners = ents.FindByClass("neco_runner")

    for _, ent in ipairs(runners) do
        if not IsValid(ent) then continue end

        for _, other in ipairs(runners) do
            if not IsValid(other) or other == ent then continue end
            local dist = ent:GetPos():Distance(other:GetPos())
            if dist > 300 then continue end

            local s = ent:GetPos()   + Vector(0, 0, 28)
            local e = other:GetPos() + Vector(0, 0, 28)

            local proximity = 1 - (dist / 300)
            local lineAlpha = math.floor(60 + proximity * 100)

            render.SetMaterial(matBeam)
            -- Внешнее свечение линии
            render.DrawBeam(s, e, 3, 0, 1,
                Color(60, 190, 255, math.floor(lineAlpha * 0.4)))
            -- Основная линия
            render.DrawBeam(s, e, 1.5, 0, 1,
                Color(100, 220, 255, lineAlpha))
        end
    end
end)

-- =========================================================
--  ENT:Draw
-- =========================================================
function ENT:Draw()
    local vel = self:GetVelocity():Length()
    local fast = vel > 120

    if fast then
        render.SetColorModulation(0.28, 0.85, 1.0)
    else
        render.SetColorModulation(0.22, 0.68, 0.90)
    end
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)
end