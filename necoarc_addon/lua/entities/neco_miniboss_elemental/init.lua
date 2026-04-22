AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local CHAIN_DMG = 25
    local CHAIN_BOUNCE = 15
    local CHAIN_CD = 5
    local CHAIN_RANGE = 800
    local CHAIN_BOUNCE_RANGE = 400

    local FIELD_RAD = 320
    local FIELD_DPS = 8
    local FIELD_CD = 15
    local FIELD_DUR = 5
    local FIELD_SLOW = 0.7

    local DISCHARGE_CHANCE = 0.05
    local DISCHARGE_DMG = 10

    local SHIELD_CD = 20
    local SHIELD_DUR = 4
    local SHIELD_REFLECT = 0.5

    local TELEPORT_CD = 12
    local TELEPORT_MIN_DIST = 700
    local TELEPORT_OFFSET = 300

    local SPARK_COUNT = 8
    local SPARK_DMG = 15
    local SPARK_SPEED = 400

    local DEBUG = false

    function ENT:CustomInitialize()
        self:SetColor(Color(255, 255, 200))
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

        self.NextChain = CurTime() + 3
        self.NextField = CurTime() + FIELD_CD
        self.NextShield = CurTime() + SHIELD_CD
        self.NextTeleport = CurTime() + TELEPORT_CD

        self.FieldActive = false
        self.FieldEnd = 0
        self.FieldDmgNext = 0

        self.ShieldActive = false
        self.ShieldEnd = 0

        self.LastPain = 0

        if DEBUG then
            print("[Elemental] Spawned with HP: " .. self:Health())
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

            if self.FieldActive then
                if now > self.FieldEnd then
                    self.FieldActive = false
                    self:SetNWBool("ElementalField", false)
                else
                    self:UpdateField(now)
                end
            elseif now >= self.NextField then
                self:ActivateField()
                self.NextField = now + FIELD_CD
            end

            if self.ShieldActive then
                if now > self.ShieldEnd then
                    self.ShieldActive = false
                    self:SetNWBool("ElementalShield", false)
                    if DEBUG then print("[Elemental] Shield deactivated") end
                end
            elseif now >= self.NextShield then
                self:ActivateShield()
                self.NextShield = now + SHIELD_CD
            end

            if IsValid(target) and now >= self.NextTeleport then
                local dist = self:GetPos():Distance(target:GetPos())
                if dist > TELEPORT_MIN_DIST then
                    self:TeleportToTarget(target)
                    self.NextTeleport = now + TELEPORT_CD
                end
            end

            if IsValid(target) and now >= self.NextChain then
                if self:CanSee(target) then
                    self:FireChainLightning(target)
                    self.NextChain = now + CHAIN_CD
                end
            end

            if not self.FieldActive and not self.ShieldActive then
                if IsValid(target) then
                    local dist = self:GetPos():Distance(target:GetPos())
                    self:FaceTowards(target)

                    if dist < 400 then
                        local awayDir = (self:GetPos() - target:GetPos()):GetNormalized()
                        self:MoveToPos(self:GetPos() + awayDir * 200)
                    elseif dist > 500 then
                        self:MoveToPos(target:GetPos())
                    else
                        self:StopMoving()
                    end
                else
                    self:StopMoving()
                    coroutine.wait(1)
                end
            else
                self:StopMoving()
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
        if not IsValid(target) then return end
        local dir = (target:GetPos() - self:GetPos()):GetNormalized()
        local ang = dir:Angle()
        self:SetAngles(Angle(0, ang.y, 0))
    end

    function ENT:CanSee(target)
        local tr = util.TraceLine({
            start = self:EyePos(),
            endpos = target:EyePos(),
            filter = {self, target},
            mask = MASK_SHOT
        })
        return not tr.Hit
    end

    function ENT:ActivateField()
        self.FieldActive = true
        self.FieldEnd = CurTime() + FIELD_DUR
        self.FieldDmgNext = CurTime() + 0.5
        self:SetNWBool("ElementalField", true)
        self:EmitSound("ambient/energy/zap1.wav", 90, 80)  -- заменён
        net.Start("NAA_SpecialAlert")
            net.WriteString("Элементаль: ЭЛЕКТРОПОЛЕ!")
        net.Broadcast()
        if DEBUG then print("[Elemental] Electric Field activated") end
    end

    function ENT:UpdateField(now)
        if now >= self.FieldDmgNext then
            self.FieldDmgNext = now + 1
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:Alive() then
                    if self:GetPos():Distance(ply:GetPos()) < FIELD_RAD then
                        local dmg = DamageInfo()
                        dmg:SetDamage(FIELD_DPS)
                        dmg:SetAttacker(self)
                        dmg:SetInflictor(self)
                        dmg:SetDamageType(DMG_SHOCK)
                        ply:TakeDamageInfo(dmg)

                        ply.ElementalSlowedUntil = CurTime() + 1.5
                        if DEBUG then print("[Elemental] Field damaged " .. ply:Nick()) end
                    end
                end
            end
        end
    end

    function ENT:ActivateShield()
        self.ShieldActive = true
        self.ShieldEnd = CurTime() + SHIELD_DUR
        self:SetNWBool("ElementalShield", true)
        self:EmitSound("ambient/energy/zap1.wav", 85, 100)
        net.Start("NAA_SpecialAlert")
            net.WriteString("Элементаль: ЭЛЕКТРИЧЕСКИЙ ЩИТ!")
        net.Broadcast()
        if DEBUG then print("[Elemental] Electric Shield activated") end
    end

    function ENT:TeleportToTarget(target)
        local tPos = target:GetPos()
        local dir = (self:GetPos() - tPos):GetNormalized()
        local telePos = tPos + dir * TELEPORT_OFFSET
        telePos.z = tPos.z

        local tr = util.TraceLine({ start = telePos + Vector(0,0,100), endpos = telePos - Vector(0,0,200), mask = MASK_SOLID_BRUSHONLY })
        if tr.Hit then telePos = tr.HitPos + Vector(0,0,10) end

        self:SetPos(telePos)
        self:EmitSound("ambient/energy/zap1.wav", 90, 100)
        self:SetNWBool("ElementalTeleport", true)
        timer.Simple(0.5, function()
            if IsValid(self) then self:SetNWBool("ElementalTeleport", false) end
        end)
        if DEBUG then print("[Elemental] Teleported to target") end
    end

    function ENT:FireChainLightning(primaryTarget)
        if not IsValid(primaryTarget) then return end

        local dmg = DamageInfo()
        dmg:SetDamage(CHAIN_DMG)
        dmg:SetAttacker(self)
        dmg:SetInflictor(self)
        dmg:SetDamageType(DMG_SHOCK)
        primaryTarget:TakeDamageInfo(dmg)
        self:EmitSound("ambient/energy/zap1.wav", 85, 140)  -- заменён

        self:SetNWBool("ElementalChain", true)
        self:SetNWEntity("ElementalChainTarget", primaryTarget)
        timer.Simple(0.3, function()
            if IsValid(self) then self:SetNWBool("ElementalChain", false) end
        end)

        local hit = { [primaryTarget] = true }
        local last = primaryTarget
        for _ = 1, 2 do
            local next, nextDist = nil, math.huge
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:Alive() and not hit[ply] then
                    local d = last:GetPos():Distance(ply:GetPos())
                    if d < CHAIN_BOUNCE_RANGE and d < nextDist then
                        nextDist = d
                        next = ply
                    end
                end
            end
            if not IsValid(next) then break end
            hit[next] = true
            local bdmg = DamageInfo()
            bdmg:SetDamage(CHAIN_BOUNCE)
            bdmg:SetAttacker(self)
            bdmg:SetInflictor(self)
            bdmg:SetDamageType(DMG_SHOCK)
            next:TakeDamageInfo(bdmg)
            last = next
        end

        if DEBUG then print("[Elemental] Chain lightning fired") end
    end

    function ENT:OnTakeDamage(dmginfo)
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker.IsNecoArc then
            dmginfo:SetDamage(0)
            if DEBUG then print("[Elemental] Damage from ally NULLIFIED!") end
            return
        end

        local dmg = dmginfo:GetDamage()

        if self.ShieldActive then
            local reflectDmg = dmg * SHIELD_REFLECT
            if IsValid(attacker) and attacker:IsPlayer() then
                local dmgInfo = DamageInfo()
                dmgInfo:SetDamage(reflectDmg)
                dmgInfo:SetAttacker(self)
                dmgInfo:SetInflictor(self)
                dmgInfo:SetDamageType(DMG_SHOCK)
                attacker:TakeDamageInfo(dmgInfo)
                if DEBUG then print("[Elemental] Shield reflected " .. reflectDmg .. " damage") end
            end
            dmg = dmg * (1 - SHIELD_REFLECT)
        end

        if math.random() < DISCHARGE_CHANCE and IsValid(attacker) and attacker:IsPlayer() then
            local sdmg = DamageInfo()
            sdmg:SetDamage(DISCHARGE_DMG)
            sdmg:SetAttacker(self)
            sdmg:SetInflictor(self)
            sdmg:SetDamageType(DMG_SHOCK)
            attacker:TakeDamageInfo(sdmg)
            attacker.ElementalSlowedUntil = CurTime() + 1.5
            util.ScreenShake(attacker:GetPos(), 5, 5, 0.5, 200)
            self:EmitSound("ambient/energy/zap1.wav", 70, 140)
            if DEBUG then print("[Elemental] Discharge triggered on " .. attacker:Nick()) end
        end

        if (self.NecoBlessUntil or 0) > CurTime() and self.NecoBlessMult then
            dmg = dmg * self.NecoBlessMult
        end

        if DEBUG then
            print("[Elemental] Took " .. dmg .. " damage (original: " .. dmginfo:GetDamage() .. ")")
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
        if DEBUG then print("[Elemental] OnKilled triggered!") end

        local pos = self:GetPos()
        for i = 1, SPARK_COUNT do
            local angle = (i / SPARK_COUNT) * 360
            local dir = Vector(math.cos(math.rad(angle)), math.sin(math.rad(angle)), 0.2):GetNormalized()

            timer.Simple(i * 0.05, function()
                if not IsValid(self) then return end
                local spark = ents.Create("prop_physics")
                if not IsValid(spark) then return end
                spark:SetModel("models/props_junk/watermelon01.mdl")
                spark:SetPos(pos + Vector(0,0,40))
                spark:Spawn()
                spark:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
                spark:SetColor(Color(255, 255, 200))
                spark:SetMaterial("models/shiny")
                spark:SetVelocity(dir * SPARK_SPEED)

                timer.Simple(3, function()
                    if IsValid(spark) then spark:Remove() end
                end)

                -- Отслеживание столкновений через таймер
                timer.Create("SparkCollide_" .. spark:EntIndex(), 0.1, 0, function()
                    if not IsValid(spark) then
                        timer.Remove("SparkCollide_" .. spark:EntIndex())
                        return
                    end
                    for _, ply in ipairs(player.GetAll()) do
                        if IsValid(ply) and ply:Alive() and spark:GetPos():Distance(ply:GetPos()) < 50 then
                            local sdmg = DamageInfo()
                            sdmg:SetDamage(SPARK_DMG)
                            sdmg:SetAttacker(self)
                            sdmg:SetDamageType(DMG_SHOCK)
                            ply:TakeDamageInfo(sdmg)
                            spark:Remove()
                            timer.Remove("SparkCollide_" .. spark:EntIndex())
                            break
                        end
                    end
                end)
            end)
        end

        util.BlastDamage(self, self, pos, 200, 30)
        self:EmitSound("infection/neco/death" .. math.random(1,3) .. ".mp3", 100)

        local attacker = dmg:GetAttacker()
        if NAA_OnNecoKilled then NAA_OnNecoKilled(self, attacker) end

        self:Remove()
    end

    function ENT:WhileAlive() end
end