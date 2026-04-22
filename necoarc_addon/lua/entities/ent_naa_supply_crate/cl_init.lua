include("shared.lua")

function ENT:Draw()
    self:DrawModel()
    if self:GetNWBool("Used", false) then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 40000 then return end

    local pos = self:GetPos() + Vector(0, 0, 50)
    -- Поворачиваем плоскость текста лицом к камере
    local ang = (ply:EyePos() - pos):Angle()
    ang:RotateAroundAxis(ang:Right(), -90)
    ang:RotateAroundAxis(ang:Up(), 90)

    cam.Start3D2D(pos, ang, 0.15)
        draw.SimpleTextOutlined("Нажми 'E'", "DermaDefaultBold", 0, 0,
            Color(100, 255, 100, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
            2, Color(0, 0, 0, 200))
    cam.End3D2D()
end