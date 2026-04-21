AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    util.AddNetworkString("NAA_SporeImpact")

    local SPORE_SPEED    = 900
    local SPORE_DAMAGE   = 8
    local CLOUD_RADIUS   = 120
    local CLOUD_DURATION = 5
    local CLOUD_DPS      = 3

    function ENT:Initialize()
        self:SetModel("models/props_junk/watermelon01.mdl")
        self:SetModelScale(0.6)
        self:SetSolid(SOLID_BBOX)                          -- FIX: VPHYSICS → BBOX для FLY
        self:SetMoveType(MOVETYPE_FLY)
        self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
        self:SetNWString("ProjType", "spore")
        self:DrawShadow(false)

        -- FIX: не перезаписывать флаги, установленные ДО Spawn()
        -- (Apex устанавливает IsHoming = false перед proj:Spawn())
        if self.IsHoming == nil then self.IsHoming = true end
        self.MoveSpeed = self.MoveSpeed or SPORE_SPEED
        self.Lifetime  = CurTime() + 12
        self.Hit       = false

        -- FIX: устанавливаем начальную скорость — иначе спора стоит на месте первый кадр
        if IsValid(self.Target) then
            local targetPos = self.Target:GetPos() + self.Target:OBBCenter()
            local dir = (targetPos - self:GetPos()):GetNormalized()
            self:SetVelocity(dir * self.MoveSpeed)
        end
    end

    function ENT:Think()
        if self.Hit then return end
        if CurTime() > self.Lifetime then self:Remove(); return end

        -- Перенацеливание если таргет умер
        local target = self.Target
        if not IsValid(target) then
            local best, bestD = nil, math.huge
            for _, ply in player.Iterator() do
                if IsValid(ply) and ply:Alive() then
                    local d = self:GetPos():DistToSqr(ply:GetPos())
                    if d < bestD then bestD = d; best = ply end
                end
            end
            target = best
            self.Target = target
        end

        local dir
        if self.IsHoming and IsValid(target) then
            -- FIX: используем флаг IsHoming (ранее флаг устанавливался, но никогда не проверялся)
            local targetPos = target:GetPos() + target:OBBCenter()
            local toward    = (targetPos - self:GetPos()):GetNormalized()
            local curDir    = self:GetVelocity():GetNormalized()
            if curDir:IsZero() then curDir = toward end
            dir = LerpVector(0.08, curDir, toward):GetNormalized()
        else
            -- Прямолётный снаряд (Apex phase2 shots)
            dir = self:GetVelocity():GetNormalized()
            if dir:IsZero() then
                dir = IsValid(target) and (target:GetPos() - self:GetPos()):GetNormalized() or Vector(0,0,1)
            end
        end

        self:SetVelocity(dir * self.MoveSpeed)
        self:NextThink(CurTime())
        return true
    end

    -- FIX: PhysicsCollide НЕ срабатывает с MOVETYPE_FLY — нужен Touch
    function ENT:Touch(ent)
        if self.Hit then return end
        -- Не реагируем на владельца и союзников
        if IsValid(ent) and ent == self.Attacker then return end
        if IsValid(ent) and ent.IsNecoArc          then return end
        -- Только игроки и мир
        if not ent:IsWorld() and (not ent:IsPlayer() or not ent:Alive()) then return end

        self.Hit = true
        local pos      = self:GetPos()
        local attacker = IsValid(self.Attacker) and self.Attacker or self

        -- Прямое попадание по игроку
        if IsValid(ent) and ent:IsPlayer() and ent:Alive() then
            local dmg = self.PoisonDmg or SPORE_DAMAGE  -- FIX: поддержка PoisonDmg от Apex
            local d = DamageInfo()
            d:SetDamage(dmg)
            d:SetAttacker(attacker)
            d:SetInflictor(self)
            d:SetDamageType(DMG_POISON)
            ent:TakeDamageInfo(d)
        end

        -- Ядовитое облако (FIX: Apex передаёт PoisonDur = 0 → облако не создаём)
        local skipCloud = (self.PoisonDur ~= nil and self.PoisonDur == 0)
        if not skipCloud then
            local cloud = ents.Create("neco_proj_cloud")
            if IsValid(cloud) then
                cloud:SetPos(pos)
                cloud:SetNWInt("CloudRadius",  CLOUD_RADIUS)
                cloud:SetNWFloat("CloudEnd",   CurTime() + CLOUD_DURATION)
                cloud:SetNWInt("CloudDPS",     CLOUD_DPS)
                cloud.Attacker = attacker
                cloud:Spawn()
                cloud:Activate()
            end
        end

        -- Сетевой эффект попадания
        net.Start("NAA_SporeImpact")
            net.WriteVector(pos)
        net.Broadcast()

        self:EmitSound("npc/barnacle/barnacle_die1.wav", 80, 100)
        self:Remove()
    end
end
