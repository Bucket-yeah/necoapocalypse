AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    -- FIX: сетевая строка для РЕАЛЬНОГО взрыва при ударе
    -- (отличается от NAA_ApexMeteor, который — предупреждение при спавне)
    util.AddNetworkString("NAA_ApexMeteorImpact")

    function ENT:Initialize()
        self:SetModel("models/props_junk/rock001a.mdl")
        self:SetModelScale(2.5)
        self:SetSolid(SOLID_BBOX)
        self:SetMoveType(MOVETYPE_FLY)
        self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
        self:DrawShadow(false)
        self.ImpactDmg = self.ImpactDmg or 50
        self.ImpactRad = self.ImpactRad or 150
        self.Hit       = false
        self.Lifetime  = CurTime() + 6
    end

    function ENT:Think()
        if self.Hit then return end
        if CurTime() > self.Lifetime then self:Remove(); return end

        local target = self.TargetPos or self:GetPos()
        local dir    = (target - self:GetPos()):GetNormalized()
        if dir:IsZero() then dir = Vector(0,0,-1) end
        self:SetVelocity(dir * 900)

        -- Проверка касания земли
        local tr = util.TraceLine({
            start  = self:GetPos(),
            endpos = self:GetPos() - Vector(0,0,30),
            mask   = MASK_SOLID_BRUSHONLY
        })
        if tr.Hit then self:DoImpact() end

        self:NextThink(CurTime())
        return true
    end

    function ENT:Touch(ent)
        if not self.Hit and ent:IsWorld() then self:DoImpact() end
    end

    function ENT:PhysicsCollide(data, phys)
        if not self.Hit then self:DoImpact() end
    end

    function ENT:DoImpact()
        if self.Hit then return end
        self.Hit = true

        local pos = self:GetPos()
        util.ScreenShake(pos, 15, 20, 1.5, self.ImpactRad + 300)
        self:EmitSound("ambient/explosions/explode_" .. math.random(1,9) .. ".wav", 165, 70)

        -- Урон игрокам в зоне
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:Alive() then continue end
            local dist = ply:GetPos():Distance(pos)
            if dist > self.ImpactRad then continue end
            local d = DamageInfo()
            d:SetDamage(self.ImpactDmg * (1 - dist / self.ImpactRad * 0.5))
            d:SetAttacker(IsValid(self.Attacker) and self.Attacker or self)
            d:SetInflictor(self); d:SetDamageType(DMG_BLAST)
            ply:TakeDamageInfo(d)
            local dir2 = (ply:GetPos() - pos):GetNormalized(); dir2.z = 0.5
            ply:SetVelocity(dir2 * 500 + Vector(0,0,300))
        end

        -- FIX: отправляем РЕАЛЬНЫЙ взрыв клиентам (NAA_ApexMeteorImpact)
        -- Клиент покажет взрыв именно здесь и именно сейчас, а не при спавне
        net.Start("NAA_ApexMeteorImpact")
            net.WriteVector(pos)
        net.Broadcast()

        timer.Simple(0.1, function() if IsValid(self) then self:Remove() end end)
    end
end
