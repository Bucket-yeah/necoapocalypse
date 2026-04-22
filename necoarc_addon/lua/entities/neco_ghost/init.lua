AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local PHASE_CD = 8
    local PHASE_DUR = 5
    local PHASE_RESIST = 0.1
    local CONTACT_DMG = 10
    local CONTACT_CD = 0.5
    local SCREAM_RAD = 400
    local DEBUFF_DUR = 5

    local DEBUG = false

    function ENT:CustomInitialize()
        -- Вне фазы: сиреневый без прозрачности (альфа 255)
        self:SetRenderMode(RENDERMODE_TRANSCOLOR)
        self:SetColor(Color(180, 180, 255, 255))

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
        
        self.IsPhasing = false
        self.NextPhase = CurTime() + PHASE_CD
        self.PhaseEnd = 0
        self.NextContact = 0
        self.NextShoot = CurTime() + 1.5
        
        if DEBUG then
            print("[Ghost] Spawned with HP: " .. self:Health())
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
            
            if self.IsPhasing then
                if now > self.PhaseEnd then
                    self:ExitPhase()
                else
                    self:DuringPhase(target)
                end
            elseif now > self.NextPhase then
                self:EnterPhase()
            end
            
            if not self.IsPhasing and IsValid(target) then
                local dist = self:GetPos():Distance(target:GetPos())
                self:FaceTowards(target)
                self:MoveToPos(target:GetPos())
                if now >= self.NextShoot and dist < self.RangeAttackRange then
                    self:TryRangeAttack(target)
                end
            elseif not self.IsPhasing then
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

    function ENT:EnterPhase()
        self.IsPhasing = true
        self.PhaseEnd = CurTime() + PHASE_DUR
        
        -- В фазе: очень прозрачный сиреневый (альфа 10)
        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        self:SetColor(Color(180, 180, 255, 10))
        self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
        
        self:EmitSound("npc/zombie/zombie_voice_idle" .. math.random(1,3) .. ".wav", 75, 150)
        
        self:SetNWBool("GhostPhasing", true)
        
        if DEBUG then
            print("[Ghost] Entered PHASE! Resists 90% damage, can pass through players.")
        end
    end

    function ENT:DuringPhase(target)
        if IsValid(target) then
            local dist = self:GetPos():Distance(target:GetPos())
            if dist < 60 and CurTime() >= self.NextContact then
                local dmg = DamageInfo()
                dmg:SetDamage(CONTACT_DMG)
                dmg:SetAttacker(self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_CLUB)
                target:TakeDamageInfo(dmg)
                self.NextContact = CurTime() + CONTACT_CD
                if DEBUG then
                    print("[Ghost] Contact damage: " .. CONTACT_DMG .. " to " .. target:Nick())
                end
            end
            self:FaceTowards(target)
            self:MoveToPos(target:GetPos())
        end
    end

    function ENT:ExitPhase()
        self.IsPhasing = false
        -- Выходим из фазы: возвращаем непрозрачный сиреневый
        self:SetRenderMode(RENDERMODE_TRANSCOLOR)
        self:SetColor(Color(180, 180, 255, 255))
        self:SetCollisionGroup(COLLISION_GROUP_NPC)
        self.NextPhase = CurTime() + PHASE_CD
        self:SetNWBool("GhostPhasing", false)
        
        if DEBUG then
            print("[Ghost] Exited PHASE. Next phase in " .. PHASE_CD .. "s.")
        end
    end

    function ENT:TryRangeAttack(target)
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
            if DEBUG then print("[Ghost] Damage from ally NULLIFIED!") end
            return
        end
        
        local dmg = dmginfo:GetDamage()
        
        if self.IsPhasing then
            dmg = dmg * PHASE_RESIST
            if DEBUG then
                print("[Ghost] PHASE resist: reduced " .. dmginfo:GetDamage() .. " -> " .. dmg)
            end
        end
        
        if (self.NecoBlessUntil or 0) > CurTime() and self.NecoBlessMult then
            dmg = dmg * self.NecoBlessMult
        end
        
        if DEBUG then
            print("[Ghost] Took " .. dmg .. " damage (original: " .. dmginfo:GetDamage() .. ")")
        end
        
        dmginfo:SetDamage(dmg)
        self.BaseClass.OnTakeDamage(self, dmginfo)
    end

    function ENT:OnKilled(dmg)
        if DEBUG then print("[Ghost] OnKilled triggered!") end
        
        local attacker = dmg:GetAttacker()
        if NAA_OnNecoKilled then
            NAA_OnNecoKilled(self, attacker)
        end

        self:EmitSound("npc/zombie/zombie_voice_idle" .. math.random(1,3) .. ".wav", 100, 80)
        
        local myPos = self:GetPos()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:GetPos():Distance(myPos) < SCREAM_RAD then
                ply:ScreenFade(SCREENFADE.IN, Color(255, 255, 255, 80), 0.2, DEBUFF_DUR)
                ply.NecoGhostDebuffUntil = CurTime() + DEBUFF_DUR
                if DEBUG then
                    print("[Ghost] Death scream affected " .. ply:Nick() .. " for " .. DEBUFF_DUR .. "s")
                end
            end
        end
        
        self.BaseClass.OnKilled(self, dmg)
    end

    function ENT:WhileAlive() end
end