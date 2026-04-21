include("shared.lua")

local matGlow = Material("sprites/light_glow02_add")
local matBeam = Material("sprites/laserbeam")

local function DrawMetallicSheen(ent)
    local t     = CurTime()
    local phase = (t % 3) / 3
    local shine = math.max(0, 1 - math.abs(phase - 0.5) * 8)
    if shine < 0.01 then return end

    local center = ent:GetPos() + ent:OBBCenter()
    local right  = ent:GetRight()
    local blikPos = center + right * Lerp(phase, -20, 20)

    render.SetMaterial(matGlow)
    render.DrawSprite(blikPos, 18, 60, Color(220, 235, 255, math.floor(shine * 200)))
    render.DrawSprite(center, 60, 60, Color(160, 200, 255, math.floor(shine * 60)))
end

local function DrawAmbientSheen(ent)
    local pulse  = 0.5 + 0.5 * math.sin(CurTime() * 2.5)
    local center = ent:GetPos() + ent:OBBCenter()
    render.SetMaterial(matGlow)
    render.DrawSprite(center, 40, 40, Color(180, 210, 255, math.floor(pulse * 30 + 10)))
end

function ENT:Draw()
    -- Стальной оттенок вместо сплошного синего
    render.SetColorModulation(0.70, 0.82, 1.0)
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    DrawMetallicSheen(self)
    DrawAmbientSheen(self)

    if self:GetNWBool("ArmoredProvoke", false) then
        local t     = CurTime()
        local pulse = 0.5 + 0.5 * math.sin(t * 6)
        local pos   = self:GetPos() + self:OBBCenter()

        render.SetMaterial(matGlow)
        local r1 = 44 + pulse * 8
        render.DrawSphere(pos, r1, 16, 16,
            Color(255, 70, 70, math.floor(180 + pulse * 60)))
        render.DrawSphere(pos, r1 + 16, 16, 16,
            Color(255, 110, 80, math.floor(80 + pulse * 40)))
        render.DrawSprite(pos, 90 + pulse * 20, 90 + pulse * 20,
            Color(255, 90, 60, math.floor(120 + pulse * 80)))

        for i = 1, 4 do
            local ang = t * 80 + i * 90
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            render.SetMaterial(matBeam)
            render.DrawBeam(pos, pos + dir * (56 + pulse * 10), 3, 0, 1,
                Color(255, 120, 60, math.floor(160 + pulse * 60)))
        end
        render.SetMaterial(matGlow)
    end
end
