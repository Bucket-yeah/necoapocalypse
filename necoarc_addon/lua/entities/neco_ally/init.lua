AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local STOP_DISTANCE = 650
    local TOO_CLOSE_DISTANCE = 250

    function ENT:CustomInitialize()
        self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
        self:SetNWInt("ShadowAlpha", 25)

        self:SetNWString("NecoType", "ally")
        self:SetNWInt("NecoMaxHP", self.SpawnHealth)

        self:GiveWeapon("weapon_smg1")

        self.NextShoot = CurTime() + 1

        timer.Simple(0.1, function()
            if not IsValid(self) then return end
            for _, ent in ipairs(ents.GetAll()) do
                if IsValid(ent) and ent:IsNPC() and (ent.IsNecoArc or ent:GetClass():find("neco_")) and not ent.IsAllyNeco then
                    self:AddEntityRelationship(ent, D_HT, 99)
                    ent:AddEntityRelationship(self, D_LI, 99)
                end
            end
        end)
    end

    function ENT:BehaveStart()
        self.BehaveThread = coroutine.create(function() self:RunBehaviour() end)
    end

    function ENT:RunBehaviour()
        coroutine.wait(0.2)
        while true do
            local now = CurTime()
            local target = self:FindTarget()

            if IsValid(target) then
                -- Дополнительная проверка (на случай удаления цели в тот же кадр)
                if not IsValid(target) then
                    self:StopMoving()
                    coroutine.wait(0.5)
                    continue
                end

                local dist = self:GetPos():Distance(target:GetPos())
                self:FaceTowards(target)

                if dist < TOO_CLOSE_DISTANCE then
                    local awayDir = (self:GetPos() - target:GetPos()):GetNormalized()
                    self:MoveToPos(self:GetPos() + awayDir * 150)
                elseif dist > STOP_DISTANCE then
                    self:MoveToPos(target:GetPos())
                else
                    self:StopMoving()
                end

                if now >= self.NextShoot and dist <= self.RangeAttackRange and IsValid(target) then
                    self:TryRangeAttack(target)
                end
            else
                self:StopMoving()
                coroutine.wait(1)
            end
            coroutine.yield()
        end
    end

    function ENT:FindTarget()
        local best, bestDist = nil, math.huge
        for _, ent in ipairs(ents.GetAll()) do
            if not IsValid(ent) or ent == self then continue end
            if ent:IsPlayer() then continue end
            if ent.IsNecoArc and not ent.IsAllyNeco and ent:Health() > 0 then
                local d = self:GetPos():DistToSqr(ent:GetPos())
                if d < bestDist then
                    bestDist = d
                    best = ent
                end
            end
        end
        return IsValid(best) and best or nil
    end

    function ENT:StopMoving()
        self.loco:SetDesiredSpeed(0)
    end

    function ENT:FaceTowards(target)
        if not IsValid(target) then return end
        local dir = (target:GetPos() - self:GetPos()):GetNormalized()
        local ang = dir:Angle()
        self:SetAngles(Angle(0, ang.y, 0))
    end

    function ENT:TryRangeAttack(target)
        if not IsValid(target) then return end
        if not self:CanSee(target) then return end

        self:PlaySequence("range_attack")
        self:EmitSound("weapons/smg1/smg1_fire1.wav", 70, 100)

        local bullet = {}
        bullet.Num = 1
        bullet.Src = self:GetShootPos()
        bullet.Dir = (target:GetPos() + target:OBBCenter() - self:GetShootPos()):GetNormalized()
        bullet.Spread = Vector(0.08, 0.08, 0)
        bullet.Tracer = 1
        bullet.Force = 5
        bullet.Damage = self.RangeAttackDamage
        bullet.Attacker = self
        bullet.Callback = function(attacker, tr, dmginfo)
            if IsValid(tr.Entity) and (tr.Entity.IsAllyNeco or tr.Entity:GetClass() == "neco_ally") then
                return false
            end
            return true
        end
        self:FireBullets(bullet)

        self.NextShoot = CurTime() + self.RangeAttackCooldown
    end

    function ENT:CanSee(target)
        if not IsValid(target) then return false end
        local tr = util.TraceLine({
            start = self:GetShootPos(),
            endpos = target:EyePos(),
            filter = function(ent)
                if ent == self or ent == target or ent.IsAllyNeco or ent:GetClass() == "neco_ally" then
                    return false
                end
                return true
            end,
            mask = MASK_SHOT
        })
        return not tr.Hit
    end

    function ENT:OnTakeDamage(dmginfo)
        dmginfo:SetDamage(0)
    end

    function ENT:OnKilled(dmg) end

    hook.Add("OnEntityCreated", "AllyNeco_Relationship", function(ent)
        if not IsValid(ent) then return end
        if ent.IsNecoArc and not ent.IsAllyNeco then
            timer.Simple(0.1, function()
                if not IsValid(ent) then return end
                for _, ally in ipairs(ents.FindByClass("neco_ally")) do
                    if IsValid(ally) then
                        ally:AddEntityRelationship(ent, D_HT, 99)
                        ent:AddEntityRelationship(ally, D_LI, 99)
                    end
                end
            end)
        end
    end)

    function ENT:WhileAlive() end
end