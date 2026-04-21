-- ============================================================
--  NECO ARC APOCALYPSE — neco_miniboss_colossus (init.lua)
-- ============================================================
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local MELEE_DIST = 200
    local MELEE_DMG = 45
    local ARMOR_MULT = 0.40
    local TAUNT_CD = 10
    local TAUNT_RADIUS = 600
    local TAUNT_FOG_DUR = 10
    local EMI_RADIUS = 800
    local EMI_THRESHOLD = 200
    local EMI_WINDOW = 2
    local EMI_CD = 6
    local EMI_DUR = 8
    local SHOCKWAVE_CD = 15
    local SHOCKWAVE_RADIUS = 300
    local SHOCKWAVE_DAMAGE = 20
    local REFLECT_CHANCE = 0.15
    local REFLECT_MULT = 0.30

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

        self:GiveWeapon("weapon_stunstick")

        self.NextMelee = 0
        self.NextTaunt = CurTime() + TAUNT_CD
        self.NextShockwave = CurTime() + SHOCKWAVE_CD
        self.NextStep = 0
        self.LastPain = 0

        self.DamageHistory = {}
        self.LastEMI = 0

        if DEBUG then
            print("[Colossus] Spawned with HP: " .. self:Health())
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

            if now >= self.NextStep then
                self.NextStep = now + 0.7
                util.ScreenShake(self:GetPos(), 3, 4, 0.5, 350)
                self:EmitSound("physics/flesh/flesh_impact_hard" .. math.random(1,2) .. ".wav", 120, 70)
            end

            if now >= self.NextTaunt then
                self:DoTaunt()
                self.NextTaunt = now + TAUNT_CD
            end

            if now >= self.NextShockwave then
                self:DoShockwave()
                self.NextShockwave = now + SHOCKWAVE_CD
            end

            if IsValid(target) then
                local dist = self:GetPos():Distance(target:GetPos())
                self:FaceTowards(target)

                if dist > MELEE_DIST then
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
        if not IsValid(target) then return end
        local dir = (target:GetPos() - self:GetPos()):GetNormalized()
        local ang = dir:Angle()
        self:SetAngles(Angle(0, ang.y, 0))
    end

    function ENT:DoTaunt()
        self:StopMoving()
        self:EmitSound("npc/combine_soldier/vo/coverme.wav", 135)

        -- Мощное продолжительное притяжение
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and ply:GetPos():Distance(self:GetPos()) < TAUNT_RADIUS then
                local dir = (self:GetPos() - ply:GetPos()):GetNormalized()
                dir.z = 0.3
                ply:SetVelocity(dir * 800 + Vector(0, 0, 150))
                -- Дополнительный импульс через 0.5 сек, чтобы игрок точно подлетел
                timer.Simple(0.5, function()
                    if IsValid(ply) and IsValid(self) then
                        local dir2 = (self:GetPos() - ply:GetPos()):GetNormalized()
                        dir2.z = 0.2
                        ply:SetVelocity(ply:GetVelocity() + dir2 * 400)
                    end
                end)
            end
        end

        self:SetNWBool("ColossusTaunt", true)
        timer.Simple(TAUNT_FOG_DUR, function()
            if IsValid(self) then self:SetNWBool("ColossusTaunt", false) end
        end)

        net.Start("NAA_SpecialAlert")
            net.WriteString("Колосс: ПРОВОКАЦИЯ!")
        net.Broadcast()

        if DEBUG then print("[Colossus] Taunt activated!") end
    end

    function ENT:DoShockwave()
        self:StopMoving()
        self:PlaySequence("melee_attack")

        local pos = self:GetPos()
        self:EmitSound("physics/metal/metal_barrel_impact_hard1.wav", 165, 60)
        util.ScreenShake(pos, 10, 15, 1.5, SHOCKWAVE_RADIUS + 200)

        self:SetNWBool("ColossusShockwave", true)
        timer.Simple(0.5, function()
            if IsValid(self) then self:SetNWBool("ColossusShockwave", false) end
        end)

        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local dist = ply:GetPos():Distance(pos)
                if dist < SHOCKWAVE_RADIUS then
                    local dmg = SHOCKWAVE_DAMAGE
                    local dmgInfo = DamageInfo()
                    dmgInfo:SetDamage(dmg)
                    dmgInfo:SetAttacker(self)
                    dmgInfo:SetInflictor(self)
                    dmgInfo:SetDamageType(DMG_BLAST)
                    ply:TakeDamageInfo(dmgInfo)

                    local dir = (ply:GetPos() - pos):GetNormalized()
                    dir.z = 0.3
                    ply:SetVelocity(dir * 300 + Vector(0, 0, 100))

                    ply.ColossusSlowedUntil = CurTime() + 3

                    if DEBUG then
                        print("[Colossus] Shockwave hit " .. ply:Nick() .. " for " .. dmg .. " damage")
                    end
                end
            end
        end

        if DEBUG then print("[Colossus] Shockwave performed!") end
    end

    function ENT:TryMeleeAttack(target)
        if CurTime() < self.NextMelee then return end

        self:PlaySequence("melee_attack")
        self:EmitSound("weapons/stunstick/stunstick_swing1.wav", 135, 80)

        timer.Simple(0.3, function()
            if not IsValid(self) or not IsValid(target) then return end
            if self:GetPos():Distance(target:GetPos()) > MELEE_DIST + 50 then return end

            local dmg = DamageInfo()
            dmg:SetDamage(MELEE_DMG)
            dmg:SetAttacker(self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_CLUB)
            target:TakeDamageInfo(dmg)

            local dir = (target:GetPos() - self:GetPos()):GetNormalized()
            dir.z = 0.3
            target:SetVelocity(dir * 400 + Vector(0, 0, 150))

            if DEBUG then
                print("[Colossus] Melee hit " .. target:Nick() .. " for " .. MELEE_DMG .. " damage")
            end
        end)

        self.NextMelee = CurTime() + self.MeleeCooldown
    end

    function ENT:UpdateDamageHistory(now)
        local threshold = now - EMI_WINDOW
        for i = #self.DamageHistory, 1, -1 do
            if self.DamageHistory[i].time < threshold then
                table.remove(self.DamageHistory, i)
            end
        end
    end

    function ENT:RecordDamage(amount)
        table.insert(self.DamageHistory, {time = CurTime(), amount = amount})
    end

    function ENT:TryEMI()
        local total = 0
        for _, v in ipairs(self.DamageHistory) do
            total = total + v.amount
        end
        if total >= EMI_THRESHOLD and (self.LastEMI or 0) < CurTime() then
            self:FireEMI()
            self.LastEMI = CurTime() + EMI_CD
            self.DamageHistory = {}
            return true
        end
        return false
    end

    function ENT:FireEMI()
        self:EmitSound("ambient/levels/labs/electric_explosion1.wav", 150)

        self:SetNWBool("ColossusEMI", true)
        timer.Simple(0.5, function()
            if IsValid(self) then self:SetNWBool("ColossusEMI", false) end
        end)

        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and ply:GetPos():Distance(self:GetPos()) < EMI_RADIUS then
                ply:ScreenFade(SCREENFADE.IN, Color(100, 180, 255, 180), 0.1, EMI_DUR)
                ply:SetVelocity(Vector(0, 0, -ply:GetVelocity().z * 0.5))
                ply.EMIActive = true
                ply.EMIEnd = CurTime() + EMI_DUR
            end
        end

        net.Start("NAA_SpecialAlert")
            net.WriteString("ЭМИ-ВСПЫШКА!")
        net.Broadcast()

        if DEBUG then print("[Colossus] EMI fired!") end
    end

    function ENT:OnTakeDamage(dmginfo)
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker.IsNecoArc then
            dmginfo:SetDamage(0)
            if DEBUG then print("[Colossus] Damage from ally NULLIFIED!") end
            return
        end

        local dmg = dmginfo:GetDamage()
        local originalDmg = dmg

        dmg = dmg * ARMOR_MULT

        if IsValid(attacker) and attacker:IsPlayer() then
            local toAttacker = (attacker:GetPos() - self:GetPos()):GetNormalized()
            local fwd = self:GetForward()
            if fwd:Dot(toAttacker) > 0 and math.random() < REFLECT_CHANCE then
                local reflectDmg = originalDmg * REFLECT_MULT
                local dmgInfo = DamageInfo()
                dmgInfo:SetDamage(reflectDmg)
                dmgInfo:SetAttacker(self)
                dmgInfo:SetInflictor(self)
                dmgInfo:SetDamageType(DMG_BULLET)
                attacker:TakeDamageInfo(dmgInfo)
                if DEBUG then print("[Colossus] Reflected " .. reflectDmg .. " damage to " .. attacker:Nick()) end
            end
        end

        self:RecordDamage(dmg)

        if (self.NecoBlessUntil or 0) > CurTime() and self.NecoBlessMult then
            dmg = dmg * self.NecoBlessMult
        end

        if DEBUG then
            print("[Colossus] Took " .. dmg .. " damage (original: " .. originalDmg .. ")")
        end

        dmginfo:SetDamage(dmg)
        self.BaseClass.OnTakeDamage(self, dmginfo)

        self:UpdateDamageHistory(CurTime())
        self:TryEMI()

        if self:Health() > 0 then
            if (self.LastPain or 0) < CurTime() then
                self:EmitSound("infection/neco/pain" .. math.random(1,3) .. ".mp3", 135, 80)
                self.LastPain = CurTime() + 0.5
            end
        end
    end

    function ENT:OnKilled(dmg)
        if DEBUG then print("[Colossus] OnKilled triggered!") end
        local attacker = dmg:GetAttacker()
        if NAA_OnNecoKilled then NAA_OnNecoKilled(self, attacker) end
        util.ScreenShake(self:GetPos(), 20, 25, 3.0, 800)
        self:Remove()
    end

    hook.Add("Think", "Colossus_Slow", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply.ColossusSlowedUntil then
                if CurTime() < ply.ColossusSlowedUntil then
                    ply:SetRunSpeed(ply:GetRunSpeed() * 0.6)
                    ply:SetWalkSpeed(ply:GetWalkSpeed() * 0.6)
                else
                    ply.ColossusSlowedUntil = nil
                    ply:SetRunSpeed(200)
                    ply:SetWalkSpeed(100)
                end
            end
        end
    end)

    function ENT:WhileAlive() end
end