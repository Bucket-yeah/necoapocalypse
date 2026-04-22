include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matMark  = Material("sprites/light_glow02_add")

function ENT:Draw()
    -- Желтоватый оттенок тела
    render.SetColorModulation(1.0, 0.85, 0.16)
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    if self:GetNWBool("SniperAiming", false) then
        local target = self:GetNWEntity("SniperTarget")
        if IsValid(target) then
            local t        = CurTime()
            local pulse    = 0.5 + 0.5 * math.sin(t * 8)
            local startPos = self:GetShootPos()
            local laserPos = self:GetNWVector("SniperLaserPos",
                                 target:GetPos() + target:OBBCenter())

            -- Основной красный луч (переменная толщина)
            local w = 3 + pulse * 1.5
            render.DrawBeam(startPos, laserPos, w, 0, 1,
                Color(255, 20, 20, 255))

            -- Сердцевина — яркий белый луч
            render.DrawBeam(startPos, laserPos, 1, 0, 1,
                Color(255, 200, 200, 200))

            -- Мерцающая точка прицела на цели
            local dotPos = laserPos + Vector(0, 0, 2)
            render.SetMaterial(matGlow)
            local dotSize = 12 + pulse * 8
            render.DrawSprite(dotPos, dotSize, dotSize,
                Color(255, 40, 40, math.floor(200 + pulse * 55)))
            -- Внешний ореол точки
            render.DrawSprite(dotPos, dotSize * 2.5, dotSize * 2.5,
                Color(255, 80, 60, math.floor(60 + pulse * 40)))

            -- Мерцающий ореол у дула снайпера
            render.DrawSprite(startPos, 20, 20,
                Color(255, 60, 60, math.floor(pulse * 180)))
        end
    end
end

-- Маркер «помечена цель» на голове игрока
hook.Add("PostDrawTranslucentRenderables", "NAA_SniperMarkIndicator", function()
    local t = CurTime()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:Alive() then continue end
        if not ply:GetNWBool("SniperMarked", false) then continue end

        local pulse = 0.5 + 0.5 * math.sin(t * 6)
        local pos   = ply:GetPos() + Vector(0, 0, 82)   -- над головой

        render.SetMaterial(matMark)

        -- Пульсирующий красный ромб
        render.DrawQuadEasy(pos, Vector(0, 0, 1), 20 + pulse * 6, 20 + pulse * 6,
            Color(255, 30, 30, math.floor(180 + pulse * 75)))
        -- Внешнее кольцо
        render.DrawSprite(pos, 55 + pulse * 10, 55 + pulse * 10,
            Color(255, 60, 40, math.floor(80 + pulse * 40)))
    end
end)
