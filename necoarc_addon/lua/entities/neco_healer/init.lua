AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local HEAL_RADIUS = 350
    local AURA_HEAL = 1
    local ACTIVE_HEAL = 15
    local ACTIVE_HEAL_CD = 5
    local FLEE_DIST = 250
    local BLESS_DURATION = 6
    local BLESS_RESIST = 0.80

    local DEBUG = false

    function ENT:CustomInitialize()
        self:SetColor(Color(80, 220, 80))
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
        
        self.NextAura = CurTime() + 1
        self.NextActiveHeal = CurTime() + ACTIVE_HEAL_CD
        self.NextShoot = CurTime() + 2
        
        if DEBUG then
            print("[Healer] Spawned at " .. tostring(self:GetPos()))
        end
    end

    function ENT:BehaveStart()
        self.BehaveThread = coroutine.create(function() self:RunBehaviour() end)
    end

    function ENT:RunBehaviour()
        coroutine.wait(0.2)

        while true do
            local now = CurTime()
            
            if now >= self.NextAura then
                self:ApplyPassiveAura()
                self.NextAura = now + 1
            end
            
            if now >= self.NextActiveHeal then
                self:ApplyActiveHeal()
                self.NextActiveHeal = now + ACTIVE_HEAL_CD
            end
            
            local ally = self:FindNearestAlly()
            local enemy = self:FindTarget()
            
            if IsValid(ally) then
                local dist = self:GetPos():Distance(ally:GetPos())
                if dist > 150 then
                    self:MoveToPos(ally:GetPos())
                else
                    self:StopMoving()
                end
                self:FaceTowards(ally)
            elseif IsValid(enemy) then
                local dist = self:GetPos():Distance(enemy:GetPos())
                if dist < FLEE_DIST then
                    self:RetreatFrom(enemy)
                else
                    self:StopMoving()
                end
                self:FaceTowards(enemy)
            else
                self:StopMoving()
                coroutine.wait(1)
            end
            
            if IsValid(enemy) and now >= self.NextShoot then
                self:TryRangeAttack(enemy)
            end
            
            coroutine.yield()
        end
    end

    function ENT:FindNearestAlly()
        local best, bestDist = nil, math.huge
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 1000)) do
            if not IsValid(ent) then continue end
            if ent.IsNecoArc and ent ~= self and ent:Health() > 0 then
                local d = self:GetPos():DistToSqr(ent:GetPos())
                if d < bestDist then
                    bestDist = d
                    best = ent
                end
            end
        end
        return best
    end

    function ENT:ApplyPassiveAura()
        local healed = 0
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), HEAL_RADIUS)) do
            if not IsValid(ent) then continue end
            if ent.IsNecoArc and ent ~= self and ent:Health() > 0 and ent:Health() < ent:GetMaxHealth() then
                ent:SetHealth(math.min(ent:Health() + AURA_HEAL, ent:GetMaxHealth()))
                healed = healed + 1
            end
        end
        if DEBUG and healed > 0 then
            print("[Healer] Passive aura healed " .. healed .. " allies")
        end
    end

    function ENT:ApplyActiveHeal()
        local healed = 0
        self:EmitSound("items/smallmedkit1.wav", 80)
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), HEAL_RADIUS)) do
            if not IsValid(ent) then continue end
            if ent.IsNecoArc and ent ~= self and ent:Health() > 0 then
                ent:SetHealth(math.min(ent:Health() + ACTIVE_HEAL, ent:GetMaxHealth()))
                healed = healed + 1
            end
        end
        local ef = EffectData()
        ef:SetOrigin(self:GetPos() + Vector(0, 0, 40))
        ef:SetScale(3)
        util.Effect("Sparks", ef)
        
        if DEBUG then
            print("[Healer] Active heal: " .. healed .. " allies healed for " .. ACTIVE_HEAL .. " HP")
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

    function ENT:RetreatFrom(target)
        if not IsValid(target) then return end
        local dir = (self:GetPos() - target:GetPos()):GetNormalized()
        local retreatPos = self:GetPos() + dir * 150
        self:MoveToPos(retreatPos)
        self:FaceTowards(target)
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
        self:EmitSound("weapons/pistol/pistol_fire2.wav", 65, 100)
        
        local bullet = {}
        bullet.Num = 1
        bullet.Src = self:GetShootPos()
        bullet.Dir = (target:GetPos() + target:OBBCenter() - self:GetShootPos()):GetNormalized()
        bullet.Spread = Vector(0.06, 0.06, 0)
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
        if not IsValid(target) then return false end
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

    function ENT:OnKilled(dmg)
        local deathPos = self:GetPos()
        local attacker = dmg:GetAttacker()

        if DEBUG then
            print("[Healer] OnKilled triggered at " .. tostring(deathPos))
        end

        if NAA_OnNecoKilled then
            NAA_OnNecoKilled(self, attacker)
        end

        self.BaseClass.OnKilled(self, dmg)

        timer.Simple(0, function()
            local blessed = 0
            for _, ent in ipairs(ents.FindInSphere(deathPos, HEAL_RADIUS)) do
                if not IsValid(ent) then continue end
                if ent.IsNecoArc then
                    ent.NecoBlessUntil = CurTime() + BLESS_DURATION
                    ent.NecoBlessMult = BLESS_RESIST
                    ent:SetNWBool("NecoBlessed", true)
                    ent:SetNWFloat("NecoBlessEnd", CurTime() + BLESS_DURATION)
                    blessed = blessed + 1
                    if DEBUG then
                        print("[Healer] Blessed: " .. tostring(ent) .. " (" .. (ent.NecoType or "unknown") .. ")")
                    end
                end
            end
            if DEBUG then
                print("[Healer] Death blessing applied to " .. blessed .. " allies")
            end
        end)
    end

    function ENT:OnTakeDamage(dmginfo)
        self.BaseClass.OnTakeDamage(self, dmginfo)
    end

    function ENT:WhileAlive() end
end