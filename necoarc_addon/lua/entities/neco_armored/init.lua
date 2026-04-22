AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local SPEED = 160
    local SHOOT_DIST = 1000
    local PROVOKE_CD = 15
    local STOP_DISTANCE = 400
    local PROVOKE_RADIUS = 500       -- радиус замедления
    local PROVOKE_SLOW_MULT = 0.75   -- 25% замедление
    local PROVOKE_DURATION = 3       -- секунд

    local DEBUG = false

    function ENT:CustomInitialize()
        self:SetColor(Color(120, 160, 255))
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
        
        self.NextShoot = CurTime() + 1
        self.NextProvoke = CurTime() + PROVOKE_CD
        
        if DEBUG then
            print("[Armored] Spawned with Shotgun")
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
            
            if IsValid(target) then
                local dist = self:GetPos():Distance(target:GetPos())
                
                self:FaceTowards(target)
                
                if dist > STOP_DISTANCE then
                    self:MoveToPos(target:GetPos())
                else
                    self:StopMoving()
                end
                
                if now >= self.NextShoot and dist < SHOOT_DIST then
                    self:TryRangeAttack(target)
                end
                
                if now >= self.NextProvoke then
                    self:DoProvoke()
                    self.NextProvoke = now + PROVOKE_CD
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

    function ENT:DoProvoke()
        -- Максимально громкий звук (диапазон 0-511, 130 уже очень громко)
        self:EmitSound("npc/combine_soldier/vo/coverme.wav", 130)
        
        -- Визуальный эффект на клиенте (сфера на 3 секунды)
        self:SetNWBool("ArmoredProvoke", true)
        timer.Simple(PROVOKE_DURATION, function()
            if IsValid(self) then self:SetNWBool("ArmoredProvoke", false) end
        end)
        
        -- Замедление игроков в радиусе
        local myPos = self:GetPos()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local dist = ply:GetPos():Distance(myPos)
                if dist <= PROVOKE_RADIUS then
                    -- Сохраняем исходные скорости, если ещё не замедлен
                    if not ply.ArmoredSlowActive then
                        ply.ArmoredSlowActive = true
                        ply.ArmoredSlowCount = (ply.ArmoredSlowCount or 0) + 1
                        ply.ArmoredOriginalRun = ply:GetRunSpeed()
                        ply.ArmoredOriginalWalk = ply:GetWalkSpeed()
                    end
                    
                    -- Применяем замедление
                    ply:SetRunSpeed(ply.ArmoredOriginalRun * PROVOKE_SLOW_MULT)
                    ply:SetWalkSpeed(ply.ArmoredOriginalWalk * PROVOKE_SLOW_MULT)
                    
                    -- Через 3 секунды восстанавливаем скорость
                    timer.Simple(PROVOKE_DURATION, function()
                        if IsValid(ply) then
                            ply.ArmoredSlowCount = math.max((ply.ArmoredSlowCount or 1) - 1, 0)
                            if ply.ArmoredSlowCount == 0 then
                                ply.ArmoredSlowActive = false
                                ply:SetRunSpeed(ply.ArmoredOriginalRun)
                                ply:SetWalkSpeed(ply.ArmoredOriginalWalk)
                            end
                        end
                    end)
                end
            end
        end
        
        if DEBUG then
            print("[Armored] Provoke! Slowed players in " .. PROVOKE_RADIUS .. " units for " .. PROVOKE_DURATION .. "s")
        end
    end

    function ENT:TryRangeAttack(target)
        if not self:CanSee(target) then return end
        
        local trCheck = util.TraceLine({
            start = self:GetShootPos(),
            endpos = target:GetPos() + target:OBBCenter(),
            filter = function(ent)
                if ent == self or ent == target then return false end
                if ent.IsNecoArc then return true end
                return false
            end,
            mask = MASK_SHOT
        })
        if trCheck.Hit and IsValid(trCheck.Entity) and trCheck.Entity.IsNecoArc then
            if DEBUG then print("[Armored] Shot blocked by ally") end
            return
        end
        
        self:PlaySequence("range_attack")
        self:EmitSound("weapons/shotgun/shotgun_fire6.wav", 75, 100)
        
        local bullet = {}
        bullet.Num = 8
        bullet.Src = self:GetShootPos()
        bullet.Dir = (target:GetPos() + target:OBBCenter() - self:GetShootPos()):GetNormalized()
        bullet.Spread = Vector(0.25, 0.25, 0)
        bullet.Tracer = 1
        bullet.Force = 5
        bullet.Damage = self.RangeAttackDamage
        bullet.Attacker = self
        bullet.Callback = function(attacker, tr, dmginfo)
            if IsValid(tr.Entity) and tr.Entity.IsNecoArc then
                return false
            end
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
            if DEBUG then print("[Armored] Damage from ally NULLIFIED!") end
            return
        end
        
        local dmg = dmginfo:GetDamage()
        
        dmg = dmg * 0.5
        
        if IsValid(attacker) then
            local toAttacker = (attacker:GetPos() - self:GetPos()):GetNormalized()
            local fwd = self:GetForward()
            local dot = fwd:Dot(toAttacker)
            if dot > 0 then
                dmg = dmg * 0.5
                if DEBUG then
                    print("[Armored] Frontal shield active, damage reduced to " .. dmg)
                end
            end
        end
        
        if (self.NecoBlessUntil or 0) > CurTime() and self.NecoBlessMult then
            dmg = dmg * self.NecoBlessMult
        end
        
        if DEBUG then
            print("[Armored] Took " .. dmg .. " damage (original: " .. dmginfo:GetDamage() .. ")")
        end
        
        dmginfo:SetDamage(dmg)
        self.BaseClass.OnTakeDamage(self, dmginfo)
        
        if self:Health() <= 0 then
            if NAA_OnNecoKilled then
                NAA_OnNecoKilled(self, attacker)
            end
            self:Remove()
        end
    end

    function ENT:WhileAlive() end
end