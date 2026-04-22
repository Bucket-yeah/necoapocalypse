AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local MELEE_DIST = 180
    local MELEE_DMG = 20
    local SLAM_RAD = 400
    local SLAM_DMG_BASE = 25
    local SLAM_CD = 10
    local STOP_DIST = 210
    local PASSIVE_RESIST = 0.75
    local CRUSH_RAD = 100
    local CRUSH_DMG = 50
    local CRUSH_INTERVAL = 0.1

    local DEBUG = false

    function ENT:CustomInitialize()
        self:SetColor(Color(160, 80, 40))
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

        self:GiveWeapon("weapon_stunstick")

        self.NextMelee = 0
        self.NextSlam = CurTime() + SLAM_CD
        self.NextStep = 0
        self.LastPain = 0

        self:StartCrushCoroutine()

        if DEBUG then
            print("[Tank] Spawned with HP: " .. self:Health())
        end
    end

    function ENT:StartCrushCoroutine()
        timer.Create("TankCrush_" .. self:EntIndex(), CRUSH_INTERVAL, 0, function()
            if not IsValid(self) then
                timer.Remove("TankCrush_" .. self:EntIndex())
                return
            end
            self:CrushAllies()
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

            if now >= self.NextStep then
                self.NextStep = now + 0.6
                util.ScreenShake(self:GetPos(), 2, 3, 0.5, 350)
                self:EmitSound("physics/flesh/flesh_impact_hard" .. math.random(1,2) .. ".wav", 80, 70)
            end

            if now >= self.NextSlam then
                self:DoGroundSlam()
                self.NextSlam = now + SLAM_CD
            end

            if IsValid(target) then
                local dist = self:GetPos():Distance(target:GetPos())
                self:FaceTowards(target)

                if dist > STOP_DIST then
                    self:MoveToPos(target:GetPos())
                else
                    self:StopMoving()
                    if now >= self.NextMelee then
                        self:TryMeleeAttack(target)
                    end
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

    function ENT:CrushAllies()
        local pos = self:GetPos()
        local crushed = false
        for _, ent in ipairs(ents.FindInSphere(pos, CRUSH_RAD)) do
            -- Пропускаем боссов и мини-боссов, чтобы танк их не толкал
            if IsValid(ent) and ent.IsNecoArc and ent ~= self and ent:Health() > 0 and not ent.IsBoss and not ent.IsMiniBoss then
                local dmg = DamageInfo()
                dmg:SetDamage(CRUSH_DMG)
                dmg:SetAttacker(self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_CLUB)
                ent:TakeDamageInfo(dmg)

                local pushDir = (ent:GetPos() - pos):GetNormalized()
                pushDir.z = 0.2
                ent:SetVelocity(pushDir * 600 + Vector(0, 0, 150))

                crushed = true
                if DEBUG then
                    print("[Tank] Crushed ally: " .. tostring(ent))
                end
            end
        end

        if crushed then
            self:SetNWBool("TankCrush", true)
            timer.Simple(0.2, function()
                if IsValid(self) then self:SetNWBool("TankCrush", false) end
            end)
        end
    end

    function ENT:DoGroundSlam()
        self:StopMoving()
        self:PlaySequence("melee_attack")

        local pos = self:GetPos()
        self:EmitSound("physics/metal/metal_barrel_impact_hard1.wav", 110, 60)
        util.ScreenShake(pos, 15, 20, 2.0, SLAM_RAD + 300)

        self:SetNWBool("TankSlam", true)
        timer.Simple(0.5, function()
            if IsValid(self) then self:SetNWBool("TankSlam", false) end
        end)

        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local dist = ply:GetPos():Distance(pos)
                if dist < SLAM_RAD then
                    local dmgMult = 1.0 - (dist / SLAM_RAD) * 0.7
                    local dmg = SLAM_DMG_BASE * dmgMult

                    local dmgInfo = DamageInfo()
                    dmgInfo:SetDamage(dmg)
                    dmgInfo:SetAttacker(self)
                    dmgInfo:SetInflictor(self)
                    dmgInfo:SetDamageType(DMG_BLAST)
                    ply:TakeDamageInfo(dmgInfo)

                    local dir = (ply:GetPos() - pos):GetNormalized()
                    dir.z = 0.4
                    ply:SetVelocity(dir * 400 + Vector(0, 0, 150))

                    ply.TankSlowedUntil = CurTime() + 3

                    if DEBUG then
                        print("[Tank] Slam hit " .. ply:Nick() .. " for " .. dmg .. " damage")
                    end
                end
            end
        end

        for _, ent in ipairs(ents.FindInSphere(pos, 200)) do
            if IsValid(ent) and ent ~= self and not ent.IsNecoArc and ent:GetClass() ~= "player" then
                ent:TakeDamage(100, self, self)
            end
        end

        if DEBUG then
            print("[Tank] Ground slam performed!")
        end
    end

    function ENT:TryMeleeAttack(target)
        if CurTime() < self.NextMelee then return end

        self:PlaySequence("melee_attack")
        self:EmitSound("weapons/stunstick/stunstick_swing1.wav", 90, 80)

        timer.Simple(0.3, function()
            if not IsValid(self) or not IsValid(target) then return end
            if self:GetPos():Distance(target:GetPos()) > MELEE_DIST + 30 then return end

            local dmg = DamageInfo()
            dmg:SetDamage(MELEE_DMG)
            dmg:SetAttacker(self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_CLUB)
            target:TakeDamageInfo(dmg)

            local dir = (target:GetPos() - self:GetPos()):GetNormalized()
            dir.z = 0.3
            target:SetVelocity(dir * 400 + Vector(0, 0, 120))

            if DEBUG then
                print("[Tank] Melee hit " .. target:Nick() .. " for " .. MELEE_DMG .. " damage")
            end
        end)

        self.NextMelee = CurTime() + self.MeleeCooldown
    end

    function ENT:OnTakeDamage(dmginfo)
        local attacker = dmginfo:GetAttacker()

        if IsValid(attacker) and attacker.IsNecoArc then
            dmginfo:SetDamage(0)
            if DEBUG then print("[Tank] Damage from ally NULLIFIED!") end
            return
        end

        local dmg = dmginfo:GetDamage()
        dmg = dmg * PASSIVE_RESIST

        if (self.NecoBlessUntil or 0) > CurTime() and self.NecoBlessMult then
            dmg = dmg * self.NecoBlessMult
        end

        if DEBUG then
            print("[Tank] Took " .. dmg .. " damage (original: " .. dmginfo:GetDamage() .. ")")
        end

        dmginfo:SetDamage(dmg)
        self.BaseClass.OnTakeDamage(self, dmginfo)

        if self:Health() > 0 then
            if (self.LastPain or 0) < CurTime() then
                self:EmitSound("infection/neco/pain" .. math.random(1,3) .. ".mp3", 90, 70)
                self.LastPain = CurTime() + 0.5
            end
        end
    end

    function ENT:OnKilled(dmg)
        if DEBUG then print("[Tank] OnKilled triggered!") end

        local attacker = dmg:GetAttacker()
        if NAA_OnNecoKilled then
            NAA_OnNecoKilled(self, attacker)
        end

        util.ScreenShake(self:GetPos(), 20, 25, 3.0, 800)
        self:EmitSound("infection/neco/death1.mp3", 110, 80)

        local pos = self:GetPos()
        local ammoEnt = ents.Create("item_ammo_ar2_large")
        if IsValid(ammoEnt) then
            ammoEnt:SetPos(pos + Vector(0, 0, 20))
            ammoEnt:Spawn()
        end
        local armorEnt = ents.Create("item_battery")
        if IsValid(armorEnt) then
            armorEnt:SetPos(pos + Vector(30, 0, 20))
            armorEnt:Spawn()
        end

        timer.Remove("TankCrush_" .. self:EntIndex())
        self.BaseClass.OnKilled(self, dmg)
    end

    hook.Add("Think", "Tank_PlayerSlow", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply.TankSlowedUntil then
                if CurTime() < ply.TankSlowedUntil then
                    ply:SetRunSpeed(ply:GetRunSpeed() * 0.6)
                    ply:SetWalkSpeed(ply:GetWalkSpeed() * 0.6)
                else
                    ply.TankSlowedUntil = nil
                    ply:SetRunSpeed(200)
                    ply:SetWalkSpeed(100)
                end
            end
        end
    end)

    function ENT:WhileAlive() end
end