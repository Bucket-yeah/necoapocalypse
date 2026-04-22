AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    util.AddNetworkString("NAA_SwarmDeathBlast")
    util.AddNetworkString("NAA_SwarmSpore")
    util.AddNetworkString("NAA_SpecialAlert")

    local SPORE_CD      = 8
    local CLOUD_CD      = 15
    local CLOUD_RADIUS  = 700
    local CLOUD_DMG     = 2
    local CLOUD_DUR     = 10
    local SUMMON_CD     = 4
    local DEATH_RADIUS  = 600
    local DEATH_DAMAGE  = 200

    local SUMMON_TYPES = {
        "neco_normal",
        "neco_runner",
        "neco_kamikaze",
        "neco_healer",
        "neco_armored",
        "neco_tank"
    }

    local DEBUG = false

    function ENT:CustomInitialize()
        self:SetNWString("NecoType", self.NecoType)
        self:SetNWInt("NecoMaxHP", self.SpawnHealth)
        self:SetNWBool("SwarmCloud", false)
        self:SetNWBool("SwarmSpore", false)

        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        self:SetMoveType(MOVETYPE_NONE)

        if self.NAADiff then
            local hp = math.ceil(self.SpawnHealth * (self.NAADiff.hpMult or 1))
            self:SetMaxHealth(hp); self:SetHealth(hp)
            self:SetNWInt("NecoMaxHP", hp)
        end

        self.NextSpore  = CurTime() + 4
        self.NextCloud  = CurTime() + 8
        self.NextSummon = CurTime() + 2
        self.CloudActive = false
        self.CloudEnd    = 0

        if DEBUG then print("[Swarm] Spawned, HP: " .. self:Health()) end
    end

    function ENT:BehaveStart()
        self.BehaveThread = coroutine.create(function() self:RunBehaviour() end)
    end

    function ENT:RunBehaviour()
        coroutine.wait(0.5)
        while true do
            local now = CurTime()
            self.loco:SetDesiredSpeed(0)

            local target = self:FindTarget()
            if IsValid(target) then self:FaceTowards(target) end

            if self.CloudActive and now < self.CloudEnd then
                for _, ply in ipairs(player.GetAll()) do
                    if IsValid(ply) and ply:Alive() and ply:GetPos():Distance(self:GetPos()) < CLOUD_RADIUS then
                        local d = DamageInfo()
                        d:SetDamage(CLOUD_DMG * 0.1)
                        d:SetAttacker(self); d:SetInflictor(self); d:SetDamageType(DMG_POISON)
                        ply:TakeDamageInfo(d)
                    end
                end
            elseif self.CloudActive then
                self.CloudActive = false
                self:SetNWBool("SwarmCloud", false)
                if DEBUG then print("[Swarm] Cloud ended") end
            end

            if IsValid(target) and now >= self.NextSpore then
                self:FireSpore(target)
                self.NextSpore = now + SPORE_CD
            end

            if now >= self.NextCloud then
                self:DoCloud()
                self.NextCloud = now + CLOUD_CD
            end

            if now >= self.NextSummon then
                self:SummonEnemy()
                self.NextSummon = now + SUMMON_CD
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

    function ENT:FaceTowards(ent)
        local a = (ent:GetPos() - self:GetPos()):Angle()
        self:SetAngles(Angle(0, a.y, 0))
    end

    function ENT:FireSpore(target)
        self:EmitSound("npc/zombie/zombie_voice_idle" .. math.random(1,2) .. ".wav", 100, 60)
        self:SetNWBool("SwarmSpore", true)
        timer.Simple(0.3, function() if IsValid(self) then self:SetNWBool("SwarmSpore", false) end end)

        net.Start("NAA_SwarmSpore")
            net.WriteVector(self:GetPos() + Vector(0,0,80))
            net.WriteVector(target:GetPos())
        net.Broadcast()

        local spore = ents.Create("neco_proj_spore")
        if IsValid(spore) then
            spore:SetPos(self:GetPos() + Vector(0,0,80))
            spore.Target = target
            spore.Attacker = self
            spore:Spawn()
            spore:Activate()
            if DEBUG then print("[Swarm] Fired spore at " .. target:Nick()) end
        else
            if DEBUG then print("[Swarm] ERROR: Failed to create spore!") end
        end
    end

    function ENT:DoCloud()
        self.CloudActive = true
        self.CloudEnd    = CurTime() + CLOUD_DUR
        self:SetNWBool("SwarmCloud", true)
        self:EmitSound("ambient/wind/wind1.wav", 100, 50)
        net.Start("NAA_SpecialAlert")
            net.WriteString("Рой: ТОКСИЧНОЕ ОБЛАКО!")
        net.Broadcast()
        if DEBUG then print("[Swarm] Toxic cloud activated, radius: " .. CLOUD_RADIUS) end
    end

    function ENT:SummonEnemy()
        local ang    = math.random(0, 360)
        local r      = math.random(60, 200)
        local spawn  = self:GetPos() + Vector(math.cos(math.rad(ang))*r, math.sin(math.rad(ang))*r, 0)
        local tr     = util.TraceLine({ start=spawn+Vector(0,0,100), endpos=spawn-Vector(0,0,200), mask=MASK_SOLID_BRUSHONLY })
        spawn = tr.Hit and (tr.HitPos+Vector(0,0,5)) or spawn

        local enemyType = SUMMON_TYPES[math.random(#SUMMON_TYPES)]
        local enemy = ents.Create(enemyType)
        if not IsValid(enemy) then
            if DEBUG then print("[Swarm] ERROR: Failed to create " .. enemyType) end
            return
        end
        enemy:SetPos(spawn)
        enemy.NAADiff   = self.NAADiff
        enemy.IsNecoArc = true
        enemy:Spawn()
        enemy:Activate()
        if DEBUG then print("[Swarm] Summoned " .. enemyType .. " at " .. tostring(spawn)) end
    end

    function ENT:OnTakeDamage(dmginfo)
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker.IsNecoArc then dmginfo:SetDamage(0); return end
        self.BaseClass.OnTakeDamage(self, dmginfo)
        self:EmitSound("infection/neco/pain" .. math.random(1,3) .. ".mp3", 140, 60)
        if DEBUG then print("[Swarm] Took " .. dmginfo:GetDamage() .. " dmg, HP: " .. self:Health()) end
    end

    function ENT:OnKilled(dmg)
        local pos = self:GetPos()
        util.ScreenShake(pos, 30, 40, 5.0, 2000)
        self:EmitSound("ambient/explosions/explode_" .. math.random(1,9) .. ".wav", 180, 50)

        net.Start("NAA_SwarmDeathBlast")
            net.WriteVector(pos)
        net.Broadcast()

        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:Alive() then continue end
            local dist = ply:GetPos():Distance(pos)
            if dist > DEATH_RADIUS then continue end
            local d = DamageInfo()
            d:SetDamage(DEATH_DAMAGE * (1 - dist/DEATH_RADIUS * 0.5))
            d:SetAttacker(self); d:SetInflictor(self); d:SetDamageType(DMG_BLAST)
            ply:TakeDamageInfo(d)
            local dir = (ply:GetPos() - pos):GetNormalized(); dir.z = 0.5
            ply:SetVelocity(dir * 800 + Vector(0,0,300))
        end

        if DEBUG then print("[Swarm] Killed! Death blast triggered") end
        if NAA_OnNecoKilled then NAA_OnNecoKilled(self, dmg:GetAttacker()) end
        self:Remove()
    end

    function ENT:WhileAlive() end
end