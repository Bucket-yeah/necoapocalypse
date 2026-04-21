include("shared.lua")

local matGlow = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")

function ENT:Draw()
    local pos = self:GetPos()
    local radius = self:GetNWInt("CloudRadius", 120)
    local endTime = self:GetNWFloat("CloudEnd", CurTime() + 5)
    local t = CurTime()
    local pulse = 0.5 + 0.5 * math.sin(t * 5)

    render.SetMaterial(matSmoke)
    render.DrawSphere(pos, radius, 16, 16, Color(20, 100, 20, math.floor(100 + pulse * 50)))
    render.DrawSphere(pos, radius * 1.2, 16, 16, Color(20, 80, 20, math.floor(60 + pulse * 30)))

    render.SetMaterial(matGlow)
    render.DrawSprite(pos + Vector(0, 0, 20), radius * 2.5, radius * 2.5, Color(100, 255, 100, math.floor(pulse * 80 + 40)))
end