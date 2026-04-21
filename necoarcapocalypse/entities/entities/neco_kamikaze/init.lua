AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local EXPLODE_RADIUS = 200
    local EXPLODE_DAMAGE = 50
    local CONTACT_RADIUS = 150
    local CONTACT_DAMAGE = 35          -- увеличено с 25
    local DASH_SPEED = 300
    local NORMAL_SPEED = 200
    local DASH_THRESHOLD_PERCENT = 0.20
    local CONTACT_DIST = 120           -- увеличено с 80

    function ENT:CustomInitialize()
        self:SetColor(Color(255, 80, 0))
        self:SetRenderMode(RENDERMODE_TRANSCOLOR)
        
        self:SetNWString("NecoType", self.NecoType)
        self:SetNWInt("NecoMaxHP", self.SpawnHealth)

        if self.NAADiff then
            local hpMult = self.NAADiff.hpMult or 1
            local newHp = math.ceil(self.SpawnHealth * hpMult)
            self:SetMaxHealth(newHp)
            self:SetHealth(newHp)
            self:SetNWInt("NecoMaxHP", newHp)
        end

        self:GiveWeapon("weapon_pistol")
        
        self.DashThreshold = math.max(1, math.floor(self:GetMaxHealth() * DASH_THRESHOLD_PERCENT))
        self.IsDashing = false
        self.BeepPlayed = false
        self.Exploded = false
        
        self.NextShoot = CurTime() + 3
    end

    function ENT:BehaveStart()
        self.BehaveThread = coroutine.create(function() self:RunBehaviour() end)
    end

    function ENT:RunBehaviour()
        coroutine.wait(0.2)

        while true do
            self:UpdateDashState()
            
            local target = self:FindTarget()
            
            if IsValid(target) then
                local dist = self:GetPos():Distance(target:GetPos())
                
                -- Контактный взрыв при приближении
                if dist <= CONTACT_DIST then
                    self:DoExplode(target, CONTACT_DAMAGE, CONTACT_RADIUS)
                    return
                end
                
                self:FaceTowards(target)
                self:MoveToPos(target:GetPos())
                
                if CurTime() >= self.NextShoot then
                    self:TryRangeAttack(target)
                end
            else
                self:StopMoving()
                coroutine.wait(1)
            end
            
            coroutine.yield()
        end
    end

    function ENT:UpdateDashState()
        local hp = self:Health()
        local threshold = self.DashThreshold
        
        if hp <= threshold and not self.IsDashing then
            self.IsDashing = true
            self.loco:SetDesiredSpeed(DASH_SPEED)
            
            if not self.BeepPlayed then
                self.BeepPlayed = true
                self:EmitSound("buttons/button17.wav", 90, 180)
            end
            
            self:SetNWBool("KamikazeDashing", true)
        elseif hp > threshold and self.IsDashing then
            self.IsDashing = false
            self.loco:SetDesiredSpeed(NORMAL_SPEED)
            self:SetNWBool("KamikazeDashing", false)
        end
    end

    function ENT:FindTarget()
        local best, bestDist = nil, math.huge
        for _, ply in player.Iterator() do
            if IsValid(ply) and ply:Alive() then
                local d = self:GetPos():DistToSqr(ply:GetPos())
                if d < bestDist then
                    bestDist = d
                    best = ply
                end
            end
        end
        return best
    end

    function ENT:StopMoving()
        self.loco:SetDesiredSpeed(0)
    end

    function ENT:FaceTowards(target)
        local dir = (target:GetPos() - self:GetPos()):GetNormalized()
        local ang = dir:Angle()
        self:SetAngles(Angle(0, ang.y, 0))
    end

    function ENT:TryRangeAttack(target)
        if not self:CanSee(target) then return end
        
        self:PlaySequence("range_attack")
        self:EmitSound("weapons/pistol/pistol_fire2.wav", 75, 120)
        
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
            if IsValid(tr.Entity) and tr.Entity.IsNecoArc then return false end
            return true
        end
        self:FireBullets(bullet)
        
        self.NextShoot = CurTime() + self.RangeAttackCooldown
    end

    function ENT:CanSee(target)
        local tr = util.TraceLine({
            start = self:GetShootPos(),
            endpos = target:EyePos(),
            filter = function(ent)
                if ent == self or ent == target or ent.IsNecoArc then return false end
                return true
            end,
            mask = MASK_SHOT
        })
        return not tr.Hit
    end

    function ENT:DoExplode(attacker, damage, radius)
        if self.Exploded then return end
        self.Exploded = true
        
        damage = damage or EXPLODE_DAMAGE
        radius = radius or EXPLODE_RADIUS
        
        local pos = self:GetPos()
        local dmgMult = (self.NAADiff and self.NAADiff.hpMult) or 1
        local finalDmg = damage * dmgMult
        
        util.BlastDamage(self, self, pos, radius, finalDmg)
        util.ScreenShake(pos, 8, 10, 1.0, radius + 150)
        
        local ef = EffectData()
        ef:SetOrigin(pos)
        ef:SetScale(2)
        util.Effect("Explosion", ef)
        
        self:EmitSound("infection/neco/death" .. math.random(1,3) .. ".mp3", 100)
        
        -- Цепная реакция
        for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
            if IsValid(ent) and ent ~= self and ent.NecoType == "kamikaze" and not ent.Exploded then
                timer.Simple(0.05, function()
                    if IsValid(ent) then
                        ent:DoExplode(attacker, ent.Exploded and nil or EXPLODE_DAMAGE, EXPLODE_RADIUS)
                    end
                end)
            end
        end
        
        if NAA_OnNecoKilled then
            NAA_OnNecoKilled(self, attacker)
        end
        
        self:Remove()
    end

    function ENT:OnTakeDamage(dmginfo)
        self.BaseClass.OnTakeDamage(self, dmginfo)
        
        if self:Health() <= 0 and not self.Exploded then
            self:DoExplode(dmginfo:GetAttacker())
        else
            self:UpdateDashState()
        end
    end

    function ENT:OnRemove()
        if not self.Exploded and self:Health() <= 0 then
            self:DoExplode(self:GetNWEntity("LastAttacker"))
        end
    end

    function ENT:WhileAlive() end
end