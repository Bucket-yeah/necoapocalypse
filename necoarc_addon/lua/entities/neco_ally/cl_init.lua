include("shared.lua")

local matGlow = Material("sprites/light_glow02_add")

function ENT:Draw()
    local alpha = self:GetNWInt("ShadowAlpha", 25)   -- очень прозрачная
    render.SetColorModulation(1, 1, 1)
    render.SetBlend(alpha / 255)
    self:DrawModel()
    render.SetBlend(1)

    -- Едва заметный белый контур для выделения
    local pulse = 0.5 + 0.5 * math.sin(CurTime() * 3)
    local center = self:GetPos() + self:OBBCenter()
    render.SetMaterial(matGlow)
    render.DrawSprite(center, 50 + pulse * 10, 50 + pulse * 10,
        Color(255, 255, 255, math.floor(pulse * 30 + 10)))
end