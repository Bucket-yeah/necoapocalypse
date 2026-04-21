AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local SPEED_NORM = 190
    local SPEED_RAGE = 285
    local DMG_NORM = 10
    local DMG_RAGE = 15
    local RAGE_THRESHOLD = 0.5
    local KILL_HEAL = 30
    local ROAR_CD = 4
    local INVULN_DURATION = 1.5
    local SHOOT_CD_NORM = 1.0
    local SHOOT_CD_RAGE = 1.0 / 1.5   -- ≈0.667 сек

    local DEBUG = false

    function ENT:CustomInitialize()
        self:SetColor(Color(255, 60, 60))
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

        self:GiveWeapon("weapon_shotgun")
        
        self.IsRaging = false
        self.RageThresholdHP = math.ceil(self:GetMaxHealth() * RAGE_THRESHOLD)
        self.NextShoot = CurTime() + 1
        self.NextRoar = 0
        self.InvulnUntil = 0
        
        if DEBUG then
            print("[Berserker] Spawned with Shotgun, HP: " .. self:Health() .. ", Rage threshold: " .. self.RageThresholdHP)
        end
    end

    function ENT:BehaveStart()
        self.BehaveThread = coroutine.create(function() self:RunBehaviour() end)
    end

    function ENT:RunBehaviour()
        coroutine.wait(0.2)

        while true do
            local now = CurTime()
            local target = self:FindTarget()
            
            if self.IsRaging and now >= self.NextRoar then
                self:DoRoar()
                self.NextRoar = now + ROAR_CD
            end
            
            if IsValid(target) then
                local dist = self:GetPos():Distance(target:GetPos())
                
                self:FaceTowards(target)
                self:MoveToPos(target:GetPos())
                
                local shootCD = self.IsRaging and SHOOT_CD_RAGE or SHOOT_CD_NORM
                if now >= self.NextShoot and dist < self.RangeAttackRange then
                    self:TryRangeAttack(target)
                    self.NextShoot = now + shootCD
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

    function ENT:DoRoar()
        self:EmitSound("npc/zombie/zombie_voice_idle" .. math.random(1,3) .. ".wav", 95)
        -- Сильная тряска экрана
        util.ScreenShake(self:GetPos(), 15, 10, 2.0, 600)
        if DEBUG then
            print("[Berserker] ROAR! Raging...")
        end
    end

    function ENT:EnterRage()
        if self.IsRaging then return end
        self.IsRaging = true
        self.loco:SetDesiredSpeed(SPEED_RAGE)
        
        self:SetNWBool("BerserkerRage", true)
        self:SetColor(Color(255, 60, 60))
        self:SetRenderMode(RENDERMODE_TRANSADD)
        
        self:EmitSound("npc/zombie/zombie_alert1.wav", 100)
        util.ScreenShake(self:GetPos(), 20, 15, 2.5, 800)
        
        net.Start("NAA_SpecialAlert")
            net.WriteString("Берсерк в ярости!")
        net.Broadcast()
        
        if DEBUG then
            print("[Berserker] Entered RAGE! Speed: " .. SPEED_RAGE .. ", Damage: " .. DMG_RAGE .. ", Shoot CD: " .. SHOOT_CD_RAGE)
        end
    end

    function ENT:TryRangeAttack(target)
        if not self:CanSee(target) then return end
        
        self:PlaySequence("range_attack")
        self:EmitSound("weapons/shotgun/shotgun_fire6.wav", 75, 100)
        
        local dmg = self.IsRaging and DMG_RAGE or DMG_NORM
        
        local bullet = {}
        bullet.Num = 8
        bullet.Src = self:GetShootPos()
        bullet.Dir = (target:GetPos() + target:OBBCenter() - self:GetShootPos()):GetNormalized()
        bullet.Spread = Vector(0.15, 0.15, 0)
        bullet.Tracer = 1
        bullet.Force = 5
        bullet.Damage = dmg
        bullet.Attacker = self
        bullet.Callback = function(attacker, tr, dmginfo)
            if IsValid(tr.Entity) and tr.Entity.IsNecoArc then return false end
            return true
        end
        self:FireBullets(bullet)
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

    function ENT:OnTakeDamage(dmginfo)
        local attacker = dmginfo:GetAttacker()
        
        if IsValid(attacker) and attacker.IsNecoArc then
            dmginfo:SetDamage(0)
            if DEBUG then print("[Berserker] Damage from ally NULLIFIED!") end
            return
        end
        
        if CurTime() < self.InvulnUntil then
            dmginfo:SetDamage(0)
            if DEBUG then print("[Berserker] Invulnerable after cheat death!") end
            return
        end
        
        local originalDmg = dmginfo:GetDamage()
        local dmg = originalDmg
        
        if self.IsRaging then
            dmg = dmg * 1.2
        end
        
        if (self.NecoBlessUntil or 0) > CurTime() and self.NecoBlessMult then
            dmg = dmg * self.NecoBlessMult
        end
        
        local newHealth = self:Health() - dmg
        
        if not self.IsRaging and newHealth <= 0 and self:Health() > self.RageThresholdHP then
            dmg = self:Health() - 1
            newHealth = 1
            self:EnterRage()
            self.InvulnUntil = CurTime() + INVULN_DURATION
            if DEBUG then
                print("[Berserker] Cheated death! Entered RAGE with 1 HP and invulnerability for " .. INVULN_DURATION .. "s!")
            end
        end
        
        if DEBUG then
            print("[Berserker] Took " .. dmg .. " damage (original: " .. originalDmg .. ")")
        end
        
        dmginfo:SetDamage(dmg)
        self.BaseClass.OnTakeDamage(self, dmginfo)
        
        if not self.IsRaging and self:Health() <= self.RageThresholdHP then
            self:EnterRage()
        end
        
        if self:Health() <= 0 then
            if NAA_OnNecoKilled then
                NAA_OnNecoKilled(self, attacker)
            end
            self:Remove()
        end
    end

    function ENT:OnKilledEnemy(enemy, dmginfo)
        if IsValid(enemy) and enemy:IsPlayer() then
            local heal = KILL_HEAL
            self:SetHealth(math.min(self:Health() + heal, self:GetMaxHealth()))
            if DEBUG then
                print("[Berserker] Killed player! Healed " .. heal .. " HP, now: " .. self:Health())
            end
        end
    end

    hook.Add("PlayerDeath", "Berserker_PlayerDeath", function(ply, inflictor, attacker)
        if IsValid(attacker) and attacker.IsNecoArc and attacker.NecoType == "berserker" then
            local heal = KILL_HEAL
            attacker:SetHealth(math.min(attacker:Health() + heal, attacker:GetMaxHealth()))
            if DEBUG then
                print("[Berserker] (Global hook) Killed player! Healed " .. heal .. " HP, now: " .. attacker:Health())
            end
        end
    end)

    function ENT:WhileAlive() end
end