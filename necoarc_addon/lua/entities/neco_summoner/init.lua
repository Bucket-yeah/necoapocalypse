AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local SUMMON_CD = 10
    local SUMMON_COUNT = 3
    local MINION_HP_MULT = 1.0
    local ELITE_RUNNER_HP_MULT = 1.5
    local ELITE_RUNNER_DMG_MULT = 1.3
    local RITUAL_HP_RESTORE = 30
    local RITUAL_CAST_TIME = 3
    local SACRIFICE_CD = 15
    local SACRIFICE_HP_RESTORE = 15
    local SACRIFICE_SPEED_BOOST = 1.5
    local SACRIFICE_SPEED_DUR = 5
    local SACRIFICE_RADIUS = 300
    local TELEPORT_CD = 12
    local TELEPORT_MIN_DIST = 300
    local AURA_SPEED_BOOST = 1.1

    local DEBUG = false
	
    function ENT:CustomInitialize()
        self:SetColor(Color(200, 100, 255))
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

        self.SummonedMinions = {}
        self.NextSummon = CurTime() + SUMMON_CD
        self.NextSacrifice = CurTime() + SACRIFICE_CD
        self.NextTeleport = CurTime() + TELEPORT_CD
        self.IsRitualCasting = false
        self.RitualEndTime = 0
        self.BaseSpeed = self.RunSpeed

        timer.Create("SummonerAura_" .. self:EntIndex(), 0.5, 0, function()
            if not IsValid(self) then
                timer.Remove("SummonerAura_" .. self:EntIndex())
                return
            end
            self:ApplyAura()
        end)

        if DEBUG then print("[Summoner] Spawned with HP: " .. self:Health()) end
    end

    function ENT:BehaveStart()
        self.BehaveThread = coroutine.create(function() self:RunBehaviour() end)
    end

    function ENT:RunBehaviour()
        coroutine.wait(0.2)
        while true do
            local now = CurTime()
            local target = self:FindTarget()
            self:CleanMinionList()

            if IsValid(target) and now >= self.NextTeleport then
                if self:GetPos():Distance(target:GetPos()) < TELEPORT_MIN_DIST then
                    self:TryTeleport(target)
                    self.NextTeleport = now + TELEPORT_CD
                end
            end

            if now >= self.NextSacrifice then
                self:TrySacrifice()
                self.NextSacrifice = now + SACRIFICE_CD
            end

            if self.IsRitualCasting then
                if now >= self.RitualEndTime then
                    self:FinishRitual()
                else
                    self:StopMoving()
                    self:SetNWBool("SummonerRitual", true)
                    coroutine.yield()
                end
            else
                self:SetNWBool("SummonerRitual", false)
                if now >= self.NextSummon then
                    if #self.SummonedMinions == 0 and self:Health() < self:GetMaxHealth() then
                        self:StartRitual()
                    else
                        self:DoSummon()
                        self.NextSummon = now + SUMMON_CD
                    end
                end
            end

            if not self.IsRitualCasting then
                local ally = self:FindNearestAlly()
                local enemy = target
                if IsValid(ally) then
                    local dist = self:GetPos():Distance(ally:GetPos())
                    if dist > 150 then self:MoveToPos(ally:GetPos()) else self:StopMoving() end
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
            end
            coroutine.yield()
        end
    end

    function ENT:FindTarget()
        local best, bestDist = nil, math.huge
        for _, ply in player.Iterator() do
            if IsValid(ply) and ply:Alive() then
                local d = self:GetPos():DistToSqr(ply:GetPos())
                if d < bestDist then bestDist, best = d, ply end
            end
        end
        return best
    end

    function ENT:FindNearestAlly()
        local best, bestDist = nil, math.huge
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 1500)) do
            if IsValid(ent) and ent.IsNecoArc and ent ~= self and ent:Health() > 0 then
                local d = self:GetPos():DistToSqr(ent:GetPos())
                if d < bestDist then bestDist, best = d, ent end
            end
        end
        return best
    end

    function ENT:StopMoving() self.loco:SetDesiredSpeed(0) end

    function ENT:FaceTowards(target)
        if not IsValid(target) then return end
        local ang = (target:GetPos() - self:GetPos()):Angle()
        self:SetAngles(Angle(0, ang.y, 0))
    end

    function ENT:CleanMinionList()
        for i = #self.SummonedMinions, 1, -1 do
            if not IsValid(self.SummonedMinions[i]) or self.SummonedMinions[i]:Health() <= 0 then
                table.remove(self.SummonedMinions, i)
            end
        end
    end

    function ENT:ApplyAura()
        for _, minion in ipairs(self.SummonedMinions) do
            if IsValid(minion) and minion:Health() > 0 and not minion.SummonerAuraApplied then
                minion.SummonerAuraApplied = true
                minion.loco:SetDesiredSpeed(minion.RunSpeed * AURA_SPEED_BOOST)
            end
        end
    end

    local function FindSafeSpawnPos(center)
        for _ = 1, 10 do
            local candidate = center + Vector(math.random(-150, 150), math.random(-150, 150), 0)
            local tr = util.TraceLine({
                start = candidate + Vector(0, 0, 100),
                endpos = candidate + Vector(0, 0, -200),
                mask = MASK_SOLID_BRUSHONLY
            })
            if tr.Hit then return tr.HitPos + Vector(0, 0, 10) end
        end
        return center
    end

    function ENT:DoSummon()
        self:EmitSound("ambient/energy/zap1.wav", 95)
        self:SetNWBool("SummonerSummon", true)
        timer.Simple(0.5, function() if IsValid(self) then self:SetNWBool("SummonerSummon", false) end end)

        local diff = self.NAADiff or { hpMult = 1 }
        for i = 1, SUMMON_COUNT do
            timer.Simple(i * 0.3, function()
                if not IsValid(self) then return end
                local spawnPos = FindSafeSpawnPos(self:GetPos())
                local minion = ents.Create("neco_normal")
                if not IsValid(minion) then
                    minion = ents.Create("npc_combine_s")
                    if not IsValid(minion) then return end
                    minion:SetModel("models/npc/nekoarc.mdl")
                    minion:Give("weapon_pistol")
                end
                minion:SetPos(spawnPos)
                minion.NAADiff = diff
                minion.IsNecoArc = true
                minion.IsSummonedBy = self
                minion:Spawn()
                minion:Activate()
                minion:SetModelScale(0.75)
                minion:SetColor(Color(180, 180, 180))
                minion:SetRenderMode(RENDERMODE_TRANSCOLOR)
                local hp = math.ceil(5 * diff.hpMult * MINION_HP_MULT)
                minion:SetMaxHealth(hp)
                minion:SetHealth(hp)
                minion:SetNWInt("NecoMaxHP", hp)
                table.insert(self.SummonedMinions, minion)
                NAA.AliveEnemies = (NAA.AliveEnemies or 0) + 1
                if DEBUG then print("[Summoner] Summoned minion, total: " .. #self.SummonedMinions) end
            end)
        end
    end

    function ENT:StartRitual()
        self.IsRitualCasting = true
        self.RitualEndTime = CurTime() + RITUAL_CAST_TIME
        self:SetNWBool("SummonerRitual", true)
        self:EmitSound("ambient/energy/zap1.wav", 95)
        if DEBUG then print("[Summoner] Started Dark Ritual!") end
    end

    function ENT:FinishRitual()
        self.IsRitualCasting = false
        self:SetNWBool("SummonerRitual", false)
        self:SetHealth(math.min(self:Health() + RITUAL_HP_RESTORE, self:GetMaxHealth()))
        local diff = self.NAADiff or { hpMult = 1 }
        for i = 1, 5 do
            timer.Simple(i * 0.2, function()
                if not IsValid(self) then return end
                local spawnPos = FindSafeSpawnPos(self:GetPos())
                local minion = ents.Create("neco_runner")
                if not IsValid(minion) then
                    minion = ents.Create("npc_combine_s")
                    if not IsValid(minion) then return end
                    minion:SetModel("models/npc/nekoarc.mdl")
                    minion:Give("weapon_stunstick")
                    minion:SetModelScale(0.7)
                end
                minion:SetPos(spawnPos)
                minion.NAADiff = diff
                minion.IsNecoArc = true
                minion.IsSummonedBy = self
                minion:Spawn()
                minion:Activate()
                minion:SetColor(Color(160, 160, 160))
                minion:SetRenderMode(RENDERMODE_TRANSCOLOR)
                local hp = math.ceil(3 * diff.hpMult * ELITE_RUNNER_HP_MULT)
                minion:SetMaxHealth(hp)
                minion:SetHealth(hp)
                minion.NecoDamageMult = (minion.NecoDamageMult or 1) * ELITE_RUNNER_DMG_MULT
                minion:SetNWInt("NecoMaxHP", hp)
                table.insert(self.SummonedMinions, minion)
                NAA.AliveEnemies = (NAA.AliveEnemies or 0) + 1
            end)
        end
        self.NextSummon = CurTime() + SUMMON_CD
        if DEBUG then print("[Summoner] Ritual finished! HP restored, 5 elite runners summoned.") end
    end

    function ENT:TrySacrifice()
        if self:Health() >= self:GetMaxHealth() * 0.5 then return end
        local sacrifice = nil
        for _, minion in ipairs(self.SummonedMinions) do
            if IsValid(minion) and minion:Health() > 0 and self:GetPos():Distance(minion:GetPos()) < SACRIFICE_RADIUS then
                sacrifice = minion
                break
            end
        end
        if not sacrifice then return end

        local sacrificePos = sacrifice:GetPos()
        sacrifice:Remove()
        self:SetHealth(math.min(self:Health() + SACRIFICE_HP_RESTORE, self:GetMaxHealth()))
        self.loco:SetDesiredSpeed(self.BaseSpeed * SACRIFICE_SPEED_BOOST)
        self:SetNWBool("SummonerSacrifice", true)
        timer.Simple(SACRIFICE_SPEED_DUR, function()
            if IsValid(self) then
                self.loco:SetDesiredSpeed(self.BaseSpeed)
                self:SetNWBool("SummonerSacrifice", false)
            end
        end)

        self:SetNWVector("SummonerSacrificeBeamPos", sacrificePos)
        self:SetNWBool("SummonerSacrificeBeam", true)
        timer.Simple(4, function()
            if IsValid(self) then self:SetNWBool("SummonerSacrificeBeam", false) end
        end)

        if DEBUG then print("[Summoner] Sacrificed minion! HP restored, speed boosted.") end
    end

    function ENT:TryTeleport(enemy)
        local ally = self:FindNearestAlly()
        if IsValid(ally) then
            self:SetPos(ally:GetPos() + Vector(math.random(-100, 100), math.random(-100, 100), 0))
            self:EmitSound("ambient/energy/zap1.wav", 90)
            if DEBUG then print("[Summoner] Teleported to ally!") end
        end
    end

    function ENT:OnTakeDamage(dmginfo)
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker.IsNecoArc then
            dmginfo:SetDamage(0)
            if DEBUG then print("[Summoner] Damage from ally NULLIFIED!") end
            return
        end
        local dmg = dmginfo:GetDamage()
        if (self.NecoBlessUntil or 0) > CurTime() and self.NecoBlessMult then dmg = dmg * self.NecoBlessMult end
        if DEBUG then print("[Summoner] Took " .. dmg .. " damage (original: " .. dmginfo:GetDamage() .. ")") end
        dmginfo:SetDamage(dmg)
        self.BaseClass.OnTakeDamage(self, dmginfo)
        if self:Health() > 0 and (self.LastPain or 0) < CurTime() then
            self:EmitSound("infection/neco/pain" .. math.random(1,3) .. ".mp3", 90)
            self.LastPain = CurTime() + 0.5
        end
    end

    function ENT:OnKilled(dmg)
        if DEBUG then print("[Summoner] OnKilled triggered!") end
        local attacker = dmg:GetAttacker()
        if NAA_OnNecoKilled then NAA_OnNecoKilled(self, attacker) end
        timer.Remove("SummonerAura_" .. self:EntIndex())
        self:Remove()
    end

    function ENT:WhileAlive() end
end