-- ============================================================
--  NECO ARC APOCALYPSE — neco_miniboss_necromancer (init.lua)
-- ============================================================
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local BEAM_DPS = 15
    local BEAM_CHARGE = 3.0
    local BEAM_DUR = 3
    local BEAM_CD = 7
    local BEAM_TRACK_DELAY = 0.5

    local SUMMON_CD = 20
    local SUMMON_MINIONS = { "neco_normal", "neco_runner" }
    local SUMMON_COUNT_MIN = 5
    local SUMMON_COUNT_MAX = 9
    local SUMMON_DISTANCE = 300
    local SUMMON_BEAM_RADIUS = 200  -- радиус луча для спавна

    local SOUL_DRAIN_CD = 15
    local SOUL_DRAIN_RADIUS = 400
    local SOUL_DRAIN_HP = 30
    local SOUL_DRAIN_ALLY_PERCENT = 0.2

    local DEBUG = false

    function ENT:CustomInitialize()
        self:SetColor(Color(30, 30, 30))
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

        self.NextBeam = CurTime() + 5
        self.NextSummon = CurTime() + SUMMON_CD
        self.NextSoulDrain = CurTime() + SOUL_DRAIN_CD

        self.BeamCharging = false
        self.BeamActive = false
        self.BeamEnd = 0
        self.BeamTarget = nil
        self.BeamChargeEnd = 0
        self.BeamDamageNext = 0
        self.BeamCurrentPos = nil

        self.LastPain = 0

        if DEBUG then
            print("[Necromancer] Spawned with HP: " .. self:Health())
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

            if now >= self.NextSummon then
                self:OpenSummonBeam()
                self.NextSummon = now + SUMMON_CD
            end

            if now >= self.NextSoulDrain then
                self:TrySoulDrain()
                self.NextSoulDrain = now + SOUL_DRAIN_CD
            end

            if self.BeamCharging then
                if now >= self.BeamChargeEnd then
                    self:StartBeam()
                end
            elseif self.BeamActive then
                if now >= self.BeamEnd then
                    self:StopBeam()
                else
                    self:UpdateBeam(now)
                end
            else
                if now >= self.NextBeam and IsValid(target) then
                    self:ChargeBeam(target)
                end
            end

            if not self.BeamCharging and not self.BeamActive then
                local ally = self:FindNearestAlly()
                local enemy = target

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
                    if dist < 350 then
                        local awayDir = (self:GetPos() - enemy:GetPos()):GetNormalized()
                        self:MoveToPos(self:GetPos() + awayDir * 150)
                    else
                        self:StopMoving()
                    end
                    self:FaceTowards(enemy)
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

    function ENT:FindNearestAlly()
        local best, bestDist = nil, math.huge
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 1500)) do
            if IsValid(ent) and ent.IsNecoArc and ent ~= self and ent:Health() > 0 then
                local d = self:GetPos():DistToSqr(ent:GetPos())
                if d < bestDist then
                    bestDist = d
                    best = ent
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

    function ENT:ChargeBeam(target)
        self.BeamCharging = true
        self.BeamChargeEnd = CurTime() + BEAM_CHARGE
        self.BeamTarget = target
        self.BeamCurrentPos = target:GetPos() + target:OBBCenter()
        self:EmitSound("ambient/energy/zap1.wav", 80, 80)
        self:SetNWBool("NecroBeamCharging", true)
        net.Start("NAA_SpecialAlert")
            net.WriteString("Некромант: ЛУЧ СМЕРТИ!")
        net.Broadcast()
        if DEBUG then print("[Necromancer] Charging beam for " .. BEAM_CHARGE .. "s") end
    end

    function ENT:StartBeam()
        self.BeamCharging = false
        self.BeamActive = true
        self.BeamEnd = CurTime() + BEAM_DUR
        self.BeamDamageNext = CurTime()
        self.NextBeam = CurTime() + BEAM_CD
        self:SetNWBool("NecroBeamCharging", false)
        self:SetNWBool("NecroBeamActive", true)
        self:EmitSound("ambient/energy/zap1.wav", 90, 100)
        if DEBUG then print("[Necromancer] Beam started") end
    end

    function ENT:StopBeam()
        self.BeamActive = false
        self.BeamTarget = nil
        self:SetNWBool("NecroBeamActive", false)
        self:StopSound("ambient/energy/zap1.wav")
        if DEBUG then print("[Necromancer] Beam stopped") end
    end

    function ENT:UpdateBeam(now)
        local target = self.BeamTarget
        if not IsValid(target) then
            self:StopBeam()
            return
        end

        if not self:CanSee(target) then
            self:StopBeam()
            return
        end

        local targetPos = target:GetPos() + target:OBBCenter()
        self.BeamCurrentPos = LerpVector(BEAM_TRACK_DELAY, self.BeamCurrentPos or targetPos, targetPos)
        self:SetNWVector("NecroBeamPos", self.BeamCurrentPos)

        if now >= self.BeamDamageNext then
            self.BeamDamageNext = now + 1
            local dmg = DamageInfo()
            dmg:SetDamage(BEAM_DPS)
            dmg:SetAttacker(self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_ENERGYBEAM)
            target:TakeDamageInfo(dmg)

            local ef = EffectData()
            ef:SetOrigin(self.BeamCurrentPos)
            ef:SetScale(2)
            util.Effect("Sparks", ef)

            if DEBUG then print("[Necromancer] Beam dealt " .. BEAM_DPS .. " damage") end
        end
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

    function ENT:OpenSummonBeam()
        local selfPos = self:GetPos()
        local angle = math.random() * 360
        local offset = Vector(math.cos(math.rad(angle)) * SUMMON_DISTANCE, math.sin(math.rad(angle)) * SUMMON_DISTANCE, 0)
        local beamPos = selfPos + offset

        local tr = util.TraceLine({
            start = beamPos + Vector(0, 0, 100),
            endpos = beamPos - Vector(0, 0, 200),
            mask = MASK_SOLID_BRUSHONLY
        })
        if tr.Hit then
            beamPos = tr.HitPos + Vector(0, 0, 10)
        end

        local count = math.random(SUMMON_COUNT_MIN, SUMMON_COUNT_MAX)
        local diff = self.NAADiff or { hpMult = 1 }

        self:SetNWVector("NecroSummonBeamPos", beamPos)
        self:SetNWBool("NecroSummonBeam", true)
        timer.Simple(4, function()
            if IsValid(self) then self:SetNWBool("NecroSummonBeam", false) end
        end)

        self:EmitSound("ambient/energy/zap1.wav", 80, 60)

        for i = 1, count do
            timer.Simple(i * 0.4, function()
                if not IsValid(self) then return end
                local spawnPos = beamPos + Vector(math.random(-SUMMON_BEAM_RADIUS, SUMMON_BEAM_RADIUS), math.random(-SUMMON_BEAM_RADIUS, SUMMON_BEAM_RADIUS), 0)
                local minionType = SUMMON_MINIONS[math.random(#SUMMON_MINIONS)]
                local minion = ents.Create(minionType)
                if not IsValid(minion) then
                    minion = ents.Create("npc_combine_s")
                    if not IsValid(minion) then return end
                    minion:SetModel("models/npc/nekoarc.mdl")
                    minion:Give(minionType == "neco_runner" and "weapon_stunstick" or "weapon_pistol")
                end
                minion:SetPos(spawnPos)
                minion.NAADiff = diff
                minion.IsNecoArc = true
                minion:Spawn()
                minion:Activate()
                minion:SetModelScale(0.8)
                NAA.AliveEnemies = (NAA.AliveEnemies or 0) + 1
                if DEBUG then print("[Necromancer] Summon beam summoned " .. minionType) end
            end)
        end

        if DEBUG then print("[Necromancer] Opened summon beam, summoning " .. count .. " minions") end
    end

    function ENT:TrySoulDrain()
        local ally = nil
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), SOUL_DRAIN_RADIUS)) do
            if IsValid(ent) and ent.IsNecoArc and ent ~= self and ent:Health() > 0 then
                ally = ent
                break
            end
        end
        if not ally then return end

        local drainAmount = math.ceil(ally:Health() * SOUL_DRAIN_ALLY_PERCENT)
        ally:SetHealth(ally:Health() - drainAmount)
        self:SetHealth(math.min(self:Health() + SOUL_DRAIN_HP, self:GetMaxHealth()))

        self:SetNWBool("NecroSoulDrain", true)
        timer.Simple(1, function()
            if IsValid(self) then self:SetNWBool("NecroSoulDrain", false) end
        end)
        self:EmitSound("npc/zombie/zombie_voice_idle1.wav", 80, 60)
        if DEBUG then print("[Necromancer] Drained " .. drainAmount .. " HP from ally") end
    end

    function ENT:OnTakeDamage(dmginfo)
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker.IsNecoArc then
            dmginfo:SetDamage(0)
            if DEBUG then print("[Necromancer] Damage from ally NULLIFIED!") end
            return
        end

        local dmg = dmginfo:GetDamage()

        if (self.NecoBlessUntil or 0) > CurTime() and self.NecoBlessMult then
            dmg = dmg * self.NecoBlessMult
        end

        if DEBUG then
            print("[Necromancer] Took " .. dmg .. " damage (original: " .. dmginfo:GetDamage() .. ")")
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
        if DEBUG then print("[Necromancer] OnKilled triggered!") end

        local pos = self:GetPos()
        local diff = self.NAADiff or { hpMult = 1 }

        timer.Simple(0.5, function()
            local tank = ents.Create("neco_tank")
            if not IsValid(tank) then
                tank = ents.Create("npc_combine_s")
                if not IsValid(tank) then return end
                tank:SetModel("models/npc/nekoarc.mdl")
                tank:Give("weapon_stunstick")
                tank:SetModelScale(2.2)
            end
            tank:SetPos(pos)
            tank.NAADiff = diff
            tank.IsNecoArc = true
            tank:Spawn()
            tank:Activate()
            tank:SetColor(Color(80, 0, 120))
            tank:SetRenderMode(RENDERMODE_TRANSCOLOR)
            tank:SetMaxHealth(200)
            tank:SetHealth(200)
            tank.NecoDamageMult = 2.0
            tank.loco:SetDesiredSpeed(150)
            NAA.AliveEnemies = (NAA.AliveEnemies or 0) + 1

            net.Start("NAA_PortalEffect")
                net.WriteVector(pos)
            net.Broadcast()

            if DEBUG then print("[Necromancer] Elite Tank summoned at death!") end
        end)

        util.BlastDamage(self, self, pos, 200, 30)
        self:EmitSound("infection/neco/death" .. math.random(1,3) .. ".mp3", 100)

        local attacker = dmg:GetAttacker()
        if NAA_OnNecoKilled then NAA_OnNecoKilled(self, attacker) end

        self:Remove()
    end

    function ENT:WhileAlive() end
end