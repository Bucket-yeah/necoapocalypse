AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local IDEAL_DIST = 1200
    local MIN_DIST = 800
    local SHOOT_DIST = 2000
    local AIM_TIME = 8
    local RELOAD_TIME = 6
    local MARK_DURATION = 19  -- увеличено до 15 секунд
    local MARK_DAMAGE_MULT = 1.5
    local LASER_SMOOTH_SPEED = 3

    local DEBUG = false

    function ENT:CustomInitialize()
        self:SetColor(Color(255, 220, 40))
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

        self:GiveWeapon("weapon_crossbow")

        self.State = "idle"
        self.StateEnd = 0
        self.AimTarget = nil
        self.LastPain = 0
        self.LaserPos = Vector(0, 0, 0)

        if DEBUG then
            print("[Sniper] Spawned with HP: " .. self:Health())
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

                if self.State == "idle" then
                    if dist < SHOOT_DIST and self:CanSee(target) then
                        self.State = "aiming"
                        self.StateEnd = now + AIM_TIME
                        self.AimTarget = target
                        self:SetNWBool("SniperAiming", true)
                        self:SetNWEntity("SniperTarget", target)
                        self.LaserPos = target:GetPos() + target:OBBCenter()
                        if DEBUG then print("[Sniper] Started aiming") end
                    end
                elseif self.State == "aiming" then
                    if IsValid(self.AimTarget) then
                        local targetPos = self.AimTarget:GetPos() + self.AimTarget:OBBCenter()
                        self.LaserPos = LerpVector(FrameTime() * LASER_SMOOTH_SPEED, self.LaserPos, targetPos)
                        self:SetNWVector("SniperLaserPos", self.LaserPos)
                    end

                    if now >= self.StateEnd then
                        self:Shoot(self.AimTarget)
                        self.State = "reloading"
                        self.StateEnd = now + RELOAD_TIME
                        self:SetNWBool("SniperAiming", false)
                        if DEBUG then print("[Sniper] Fired, reloading") end
                    end
                elseif self.State == "reloading" then
                    if now >= self.StateEnd then
                        self.State = "idle"
                        if DEBUG then print("[Sniper] Ready to fire again") end
                    end
                end

                if self.State == "idle" then
                    if dist < MIN_DIST then
                        local awayDir = (self:GetPos() - target:GetPos()):GetNormalized()
                        self:MoveToPos(self:GetPos() + awayDir * 200)
                    elseif dist > IDEAL_DIST + 200 then
                        self:MoveToPos(target:GetPos())
                    else
                        self:StopMoving()
                    end
                else
                    self:StopMoving()
                end
            else
                self:StopMoving()
                self:SetNWBool("SniperAiming", false)
                self.State = "idle"
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

    function ENT:Shoot(target)
        self:PlaySequence("range_attack")
        self:EmitSound("weapons/crossbow/hit1.wav", 80, 120)  -- звук арбалета

        local dmg = self.RangeAttackDamage
        if target:GetNWBool("SniperMarked", false) then
            dmg = dmg * MARK_DAMAGE_MULT
            target:SetNWBool("SniperMarked", false)
            if DEBUG then
                print("[Sniper] Marked shot hit for " .. dmg .. " damage!")
            end
        end

        local bulletDir = (self.LaserPos - self:GetShootPos()):GetNormalized()

        local bullet = {}
        bullet.Num = 1
        bullet.Src = self:GetShootPos()
        bullet.Dir = bulletDir
        bullet.Spread = Vector(0, 0, 0)
        bullet.Tracer = 1
        bullet.Force = 10
        bullet.Damage = dmg
        bullet.Attacker = self
        bullet.Callback = function(attacker, tr, dmginfo)
            if IsValid(tr.Entity) and tr.Entity.IsNecoArc then return false end
            if tr.Entity == target then
                util.ScreenShake(target:GetPos(), 10, 10, 1, 200)
                target:SetNWBool("SniperMarked", true)
                timer.Simple(MARK_DURATION, function()
                    if IsValid(target) then target:SetNWBool("SniperMarked", false) end
                end)
                if DEBUG then
                    print("[Sniper] Hit " .. target:Nick() .. "! Mark applied.")
                end
            end
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
            if DEBUG then print("[Sniper] Damage from ally NULLIFIED!") end
            return
        end

        local dmg = dmginfo:GetDamage()
        if (self.NecoBlessUntil or 0) > CurTime() and self.NecoBlessMult then
            dmg = dmg * self.NecoBlessMult
        end

        if DEBUG then
            print("[Sniper] Took " .. dmg .. " damage (original: " .. dmginfo:GetDamage() .. ")")
        end

        dmginfo:SetDamage(dmg)
        self.BaseClass.OnTakeDamage(self, dmginfo)

        if self:Health() > 0 then
            if (self.LastPain or 0) < CurTime() then
                self:EmitSound("infection/neco/pain" .. math.random(1,3) .. ".mp3", 90)
                self.LastPain = CurTime() + 0.5
            end
        end
    end

    function ENT:OnKilled(dmg)
        if DEBUG then print("[Sniper] OnKilled triggered!") end
        local attacker = dmg:GetAttacker()
        if NAA_OnNecoKilled then
            NAA_OnNecoKilled(self, attacker)
        end
        self:Remove()
    end

    function ENT:WhileAlive() end
end