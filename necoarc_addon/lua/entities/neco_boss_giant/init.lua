-- init.lua (обновлён)
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    util.AddNetworkString("NAA_GiantStomp")
    util.AddNetworkString("NAA_GiantThrow")
    util.AddNetworkString("NAA_GiantPhase2")
    util.AddNetworkString("NAA_SpecialAlert")

    local PHASE2_THRESHOLD  = 0.30
    local STOMP_CD          = 6
    local STOMP_RADIUS      = 250
    local STOMP_DAMAGE      = 60
    local THROW_CD          = 10
    local THROW_RANGE       = 550
    local THROW_DAMAGE      = 45
    local THROW_STUN        = 1.2
    local MELEE_DIST        = 250
    local P1_MELEE_DMG      = 70
    local P2_MELEE_DMG      = 95
    local SUMMON_INTERVAL   = 4
    local SUMMON_COUNT      = 3
    local MAX_RUNNERS       = 100
    local SLOW_DUR          = 3
    local SLOW_MULT         = 0.6
    local RAGE_PER_HIT      = 0.02
    local RAGE_MAX          = 0.50
    local RAGE_RESET_TIME   = 5
    local STEP_CD           = 0.7

    local DEBUG = true

    function ENT:CustomInitialize()
        self:SetNWString("NecoType", self.NecoType)
        self:SetNWInt("NecoMaxHP", self.SpawnHealth)
        self:SetNWInt("GiantPhase", 1)
        self:SetNWBool("GiantStomp", false)
        self:SetNWBool("GiantRage", false)
        self:SetNWBool("GiantEnraging", false)

        -- Игнорируем коллизию с игроками и физическими объектами
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        if self.NAADiff then
            local hp = math.ceil(self.SpawnHealth * (self.NAADiff.hpMult or 1))
            self:SetMaxHealth(hp); self:SetHealth(hp)
            self:SetNWInt("NecoMaxHP", hp)
        end

        self.Phase         = 1
        self.NextMelee     = 0
        self.NextStomp     = CurTime() + 3
        self.NextThrow     = CurTime() + 5
        self.NextStep      = 0
        self.NextSummon    = CurTime() + SUMMON_INTERVAL
        self.RageBonus     = 0
        self.LastHitTime   = 0
        self.SummonedCount = 0
        self.Phase2Done    = false

        if DEBUG then print("[Giant] Spawned, HP: " .. self:Health() .. ", Scale: " .. self:GetModelScale()) end
    end

    function ENT:BehaveStart()
        self.BehaveThread = coroutine.create(function() self:RunBehaviour() end)
    end

    function ENT:RunBehaviour()
        coroutine.wait(0.5)
        while true do
            local now    = CurTime()
            local target = self:FindTarget()

            if now >= self.NextStep then
                self.NextStep = now + STEP_CD
                util.ScreenShake(self:GetPos(), 4, 5, 0.4, 600)
                self:EmitSound("physics/concrete/concrete_impact_hard" .. math.random(1,3) .. ".wav", 140, 55)
            end

            if not self.Phase2Done and (self:Health() / self:GetMaxHealth()) <= PHASE2_THRESHOLD then
                self:EnterPhase2()
            end

            if self.Phase == 2 and self.RageBonus > 0 and (now - self.LastHitTime) > RAGE_RESET_TIME then
                self.RageBonus = 0
                if DEBUG then print("[Giant] Rage bonus reset") end
            end

            if self.Phase == 2 and now >= self.NextSummon and self.SummonedCount < MAX_RUNNERS then
                for i = 1, SUMMON_COUNT do
                    timer.Simple(i * 0.3, function()
                        if IsValid(self) then self:SummonRunner() end
                    end)
                end
                self.NextSummon = now + SUMMON_INTERVAL
            end

            if IsValid(target) then
                local dist = self:GetPos():Distance(target:GetPos())
                self:FaceTowards(target)

                if dist > MELEE_DIST then
                    self.loco:SetDesiredSpeed(self.WalkSpeed)
                    self:MoveToPos(target:GetPos())
                else
                    self:StopMoving()
                    if now >= self.NextMelee then
                        self:DoMelee(target)
                    end
                end

                if now >= self.NextStomp then
                    self:DoStomp()
                    self.NextStomp = now + STOMP_CD
                end

                if self.Phase == 1 and now >= self.NextThrow and dist > THROW_RANGE then
                    self:DoThrow(target)
                    self.NextThrow = now + THROW_CD
                end
            else
                self:StopMoving()
                coroutine.wait(1)
            end

            coroutine.yield()
        end
    end

    function ENT:FindTarget()
        local best, bestD = nil, math.huge
        for _, ply in player.Iterator() do
            if IsValid(ply) and ply:Alive() then
                local d = self:GetPos():DistToSqr(ply:GetPos())
                if d < bestD then bestD = d; best = ply end
            end
        end
        return best
    end

    function ENT:StopMoving()
        self.loco:SetDesiredSpeed(0)
    end

    function ENT:FaceTowards(ent)
        if not IsValid(ent) then return end
        local a = (ent:GetPos() - self:GetPos()):Angle()
        self:SetAngles(Angle(0, a.y, 0))
    end

    function ENT:DoMelee(target)
        local dmg = (self.Phase == 2) and P2_MELEE_DMG or P1_MELEE_DMG
        local cd  = self.MeleeCooldown * (1 - self.RageBonus)
        self:PlaySequence("melee_attack")
        self:EmitSound("weapons/crowbar/crowbar_impact" .. math.random(1,2) .. ".wav", 140, 60)
        if DEBUG then print("[Giant] Melee attack, dmg=" .. dmg .. ", cd=" .. cd) end
        timer.Simple(0.3, function()
            if not IsValid(self) or not IsValid(target) then return end
            if self:GetPos():Distance(target:GetPos()) > MELEE_DIST + 80 then return end
            local d = DamageInfo()
            d:SetDamage(dmg); d:SetAttacker(self); d:SetInflictor(self)
            d:SetDamageType(DMG_CLUB)
            target:TakeDamageInfo(d)
            target:SetVelocity((target:GetPos() - self:GetPos()):GetNormalized() * 350 + Vector(0,0,200))
        end)
        self.NextMelee = CurTime() + cd
    end

    function ENT:DoStomp()
        self:StopMoving()
        self:PlaySequence("melee_attack")
        self:EmitSound("physics/metal/metal_barrel_impact_hard1.wav", 175, 40)
        util.ScreenShake(self:GetPos(), 12, 18, 1.5, STOMP_RADIUS + 300)

        self:SetNWBool("GiantStomp", true)
        timer.Simple(0.6, function() if IsValid(self) then self:SetNWBool("GiantStomp", false) end end)

        net.Start("NAA_GiantStomp")
            net.WriteVector(self:GetPos())
        net.Broadcast()

        if DEBUG then print("[Giant] Stomp!") end

        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:Alive() then continue end
            local dist = ply:GetPos():Distance(self:GetPos())
            if dist > STOMP_RADIUS then continue end
            local d = DamageInfo()
            d:SetDamage(STOMP_DAMAGE * (1 - dist/STOMP_RADIUS * 0.5))
            d:SetAttacker(self); d:SetInflictor(self); d:SetDamageType(DMG_BLAST)
            ply:TakeDamageInfo(d)
            local dir = (ply:GetPos() - self:GetPos()):GetNormalized()
            dir.z = 0.4
            ply:SetVelocity(dir * 500 + Vector(0,0,200))
            ply.GiantSlowedUntil = CurTime() + SLOW_DUR
        end
    end

    function ENT:DoThrow(target)
        self:StopMoving()
        self:EmitSound("physics/concrete/concrete_impact_hard1.wav", 130, 80)

        net.Start("NAA_GiantThrow")
            net.WriteVector(self:GetPos() + Vector(0, 0, 120))
            net.WriteVector(target:GetPos())
        net.Broadcast()

        if DEBUG then print("[Giant] Throw rock at " .. target:Nick()) end

        local rock = ents.Create("prop_physics")
        if not IsValid(rock) then return end
        rock:SetModel("models/props_junk/rock001a.mdl")
        rock:SetPos(self:GetPos() + Vector(0, 0, 120))
        rock:Spawn(); rock:Activate()
        local phys = rock:GetPhysicsObject()
        if IsValid(phys) then
            local dir = (target:GetPos() + Vector(0,0,60) - rock:GetPos()):GetNormalized()
            phys:SetVelocity(dir * 1400)
        end
        timer.Simple(0.8, function()
            if not IsValid(rock) then return end
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:Alive() and ply:GetPos():Distance(rock:GetPos()) < 120 then
                    local d = DamageInfo()
                    d:SetDamage(THROW_DAMAGE); d:SetAttacker(self); d:SetInflictor(self)
                    d:SetDamageType(DMG_CLUB)
                    ply:TakeDamageInfo(d)
                    ply.GiantStunnedUntil = CurTime() + THROW_STUN
                end
            end
            timer.Simple(0.5, function() if IsValid(rock) then rock:Remove() end end)
        end)
    end

    function ENT:EnterPhase2()
        self.Phase2Done = true
        self.Phase      = 2
        self:SetNWInt("GiantPhase", 2)
        self:SetNWBool("GiantEnraging", true)
        self.WalkSpeed  = 160; self.RunSpeed = 160
        self.loco:SetDesiredSpeed(160)
        self:SetModelScale(2.4)

        timer.Simple(2.5, function()
            if IsValid(self) then self:SetNWBool("GiantEnraging", false) end
        end)

        self:EmitSound("npc/strider/striderx_alert2.wav", 160, 70)
        util.ScreenShake(self:GetPos(), 20, 25, 3.0, 2000)
        net.Start("NAA_SpecialAlert")
            net.WriteString("ГИГАНТ ВЗБЕШЁН!")
        net.Broadcast()
        net.Start("NAA_GiantPhase2")
        net.Broadcast()

        if DEBUG then print("[Giant] Entered Phase 2! Scale: " .. self:GetModelScale()) end
    end

    function ENT:SummonRunner()
        local spawn = self:GetPos() + VectorRand() * 120
        spawn.z = self:GetPos().z
        local tr = util.TraceLine({ start = spawn + Vector(0,0,100), endpos = spawn - Vector(0,0,200), mask = MASK_SOLID_BRUSHONLY })
        spawn = tr.Hit and (tr.HitPos + Vector(0,0,5)) or spawn

        local runner = ents.Create("neco_runner")
        if not IsValid(runner) then return end
        runner:SetPos(spawn)
        runner.NAADiff  = self.NAADiff
        runner.IsNecoArc = true
        runner:Spawn(); runner:Activate()
        self.SummonedCount = self.SummonedCount + 1
        if DEBUG then print("[Giant] Summoned runner, total: " .. self.SummonedCount) end
    end

    function ENT:OnTakeDamage(dmginfo)
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker.IsNecoArc then dmginfo:SetDamage(0); return end

        local dmg = dmginfo:GetDamage()
        if self.NecoBlessUntil and self.NecoBlessUntil > CurTime() then
            dmg = dmg * (self.NecoBlessMult or 1)
        end
        dmginfo:SetDamage(dmg)
        self.BaseClass.OnTakeDamage(self, dmginfo)

        if self.Phase == 2 then
            self.RageBonus   = math.min(self.RageBonus + RAGE_PER_HIT, RAGE_MAX)
            self.LastHitTime = CurTime()
            if self.RageBonus > 0.01 then self:SetNWBool("GiantRage", true)
            else self:SetNWBool("GiantRage", false) end
        end

        if DEBUG then print("[Giant] Took " .. dmg .. " dmg, HP: " .. self:Health()) end

        if self:Health() > 0 then
            self:EmitSound("infection/neco/pain" .. math.random(1,3) .. ".mp3", 140, 70)
        end
    end

    function ENT:OnKilled(dmg)
        util.ScreenShake(self:GetPos(), 25, 30, 4.0, 1500)
        self:EmitSound("npc/strider/striderx_die1.wav", 170, 60)
        if DEBUG then print("[Giant] Killed!") end
        if NAA_OnNecoKilled then NAA_OnNecoKilled(self, dmg:GetAttacker()) end
        self:Remove()
    end

    hook.Add("Think", "Giant_PlayerEffects", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                if ply.GiantSlowedUntil and CurTime() < ply.GiantSlowedUntil then
                    ply:SetRunSpeed(ply:GetRunSpeed() * SLOW_MULT)
                    ply:SetWalkSpeed(ply:GetWalkSpeed() * SLOW_MULT)
                elseif ply.GiantSlowedUntil then
                    ply.GiantSlowedUntil = nil
                    ply:SetRunSpeed(200); ply:SetWalkSpeed(100)
                end
                if ply.GiantStunnedUntil and CurTime() < ply.GiantStunnedUntil then
                    ply:SetVelocity(-ply:GetVelocity() * 0.8)
                elseif ply.GiantStunnedUntil then
                    ply.GiantStunnedUntil = nil
                end
            end
        end
    end)

    function ENT:WhileAlive() end
end