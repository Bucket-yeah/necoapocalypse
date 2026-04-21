AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    util.AddNetworkString("NAA_BerserkerDash")
    util.AddNetworkString("NAA_BerserkerCry")
    util.AddNetworkString("NAA_BerserkerPhase2")
    util.AddNetworkString("NAA_SpecialAlert")

    local PHASE2_HP      = 0.50
    local MELEE_DIST     = 250
    local P1_MELEE_DMG   = 45
    local P2_MELEE_DMG   = 60
    local DASH_CD        = 7
    local DASH_WIND      = 0.5
    local DASH_DMG       = 40
    local DASH_STUN      = 1.5
    local CRY_CD         = 20
    local CRY_RADIUS     = 800
    local CRY_DUR        = 6
    local BERSERK_CD     = 25
    local BERSERK_DUR    = 8
    local BERSERK_LIFESTEAL = 15
    local INVULN_DUR     = 2
    local ALLY_SPEED_BOOST = 1.30
    local ALLY_DMG_BOOST   = 1.20

    local DEBUG = false

    function ENT:CustomInitialize()
        self:SetNWString("NecoType", self.NecoType)
        self:SetNWInt("NecoMaxHP", self.SpawnHealth)
        self:SetNWInt("BerserkerPhase", 1)
        self:SetNWBool("BerserkerDashing", false)
        self:SetNWBool("BerserkerCry", false)
        self:SetNWBool("BerserkerBerserk", false)
        self:SetNWBool("BerserkerInvulnerable", false)

        -- Отключаем коллизию с игроками и союзниками
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        if self.NAADiff then
            local hp = math.ceil(self.SpawnHealth * (self.NAADiff.hpMult or 1))
            self:SetMaxHealth(hp); self:SetHealth(hp)
            self:SetNWInt("NecoMaxHP", hp)
        end

        self.Phase       = 1
        self.NextMelee   = 0
        self.NextDash    = CurTime() + 4
        self.NextCry     = CurTime() + 8
        self.NextBerserk = CurTime() + BERSERK_CD
        self.Phase2Done  = false
        self.Invulnerable = false
        self.BerserkActive = false

        self.BuffList = {}  -- список забаффанных союзников

        if DEBUG then print("[Berserker Lord] Spawned, HP: " .. self:Health()) end
    end

    function ENT:BehaveStart()
        self.BehaveThread = coroutine.create(function() self:RunBehaviour() end)
    end

    function ENT:RunBehaviour()
        coroutine.wait(0.5)
        while true do
            local now    = CurTime()
            local target = self:FindTarget()

            if not self.Phase2Done and (self:Health() / self:GetMaxHealth()) <= PHASE2_HP then
                self:EnterPhase2()
            end

            if self.Phase == 2 and now >= self.NextBerserk and not self.BerserkActive then
                self:ActivateBerserk()
                self.NextBerserk = now + BERSERK_CD
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
                        if DEBUG then print("[Berserker Lord] Melee attack, dmg: " .. (self.Phase == 2 and P2_MELEE_DMG or P1_MELEE_DMG)) end
                    end
                end

                if now >= self.NextDash and dist > 180 and dist < 900 then
                    self:DoDash(target)
                    self.NextDash = now + DASH_CD
                    if DEBUG then print("[Berserker Lord] Dash to " .. target:Nick()) end
                end

                if now >= self.NextCry then
                    self:DoCry()
                    self.NextCry = now + CRY_CD
                    if DEBUG then print("[Berserker Lord] Battle Cry") end
                end
            else
                self:StopMoving()
                coroutine.wait(1)
            end

            -- Очистка мёртвых из списка баффов
            for i = #self.BuffList, 1, -1 do
                if not IsValid(self.BuffList[i]) or self.BuffList[i]:Health() <= 0 then
                    table.remove(self.BuffList, i)
                end
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

    function ENT:StopMoving() self.loco:SetDesiredSpeed(0) end

    function ENT:FaceTowards(ent)
        local a = (ent:GetPos() - self:GetPos()):Angle()
        self:SetAngles(Angle(0, a.y, 0))
    end

    function ENT:DoMelee(target)
        local dmg = (self.Phase == 2) and P2_MELEE_DMG or P1_MELEE_DMG
        if self.BerserkActive then dmg = dmg * 1.5 end
        self:PlaySequence("melee_attack")
        self:EmitSound("weapons/crowbar/crowbar_impact" .. math.random(1,2) .. ".wav", 140, 80)
        timer.Simple(0.25, function()
            if not IsValid(self) or not IsValid(target) then return end
            if self:GetPos():Distance(target:GetPos()) > MELEE_DIST + 60 then return end
            local d = DamageInfo()
            d:SetDamage(dmg); d:SetAttacker(self); d:SetInflictor(self); d:SetDamageType(DMG_CLUB)
            target:TakeDamageInfo(d)
            if self.BerserkActive then
                self:SetHealth(math.min(self:Health() + BERSERK_LIFESTEAL, self:GetMaxHealth()))
                if DEBUG then print("[Berserker Lord] Lifesteal: +" .. BERSERK_LIFESTEAL .. " HP") end
            end
            target:SetVelocity((target:GetPos()-self:GetPos()):GetNormalized() * 300 + Vector(0,0,150))
            util.ScreenShake(self:GetPos(), 5, 8, 0.4, 500)
        end)
        self.NextMelee = CurTime() + self.MeleeCooldown * (self.BerserkActive and 0.5 or 1)
    end

    function ENT:DoDash(target)
        self:SetNWBool("BerserkerDashing", true)
        self:EmitSound("npc/metropolice/vo/holdit.wav", 130, 90)
        local fromPos = self:GetPos()
        local toPos   = target:GetPos()

        net.Start("NAA_BerserkerDash")
            net.WriteVector(fromPos)
            net.WriteVector(toPos)
        net.Broadcast()

        coroutine.wait(DASH_WIND)
        if not IsValid(self) then return end

        local dir  = (toPos - fromPos):GetNormalized()
        local dist = fromPos:Distance(toPos)
        local steps = 12
        for i = 1, steps do
            if not IsValid(self) then return end
            local t = i / steps
            self:SetPos(LerpVector(t, fromPos, toPos - dir * 60))
            coroutine.wait(0.015)
        end

        self:SetNWBool("BerserkerDashing", false)
        util.ScreenShake(self:GetPos(), 8, 10, 0.5, 400)
        self:EmitSound("physics/metal/metal_barrel_impact_hard1.wav", 140, 90)

        if IsValid(target) and target:GetPos():Distance(self:GetPos()) < 150 then
            local d = DamageInfo()
            d:SetDamage(DASH_DMG); d:SetAttacker(self); d:SetInflictor(self); d:SetDamageType(DMG_CLUB)
            target:TakeDamageInfo(d)
            target.BerserkerStunnedUntil = CurTime() + DASH_STUN
        end
    end

    function ENT:DoCry()
        self:StopMoving()
        self:SetNWBool("BerserkerCry", true)
        self:EmitSound("npc/strider/striderx_alert2.wav", 155, 100)
        util.ScreenShake(self:GetPos(), 8, 10, 0.8, 1200)

        net.Start("NAA_BerserkerCry")
            net.WriteVector(self:GetPos())
        net.Broadcast()
        net.Start("NAA_SpecialAlert")
            net.WriteString("Берсерк Лорд: БОЕВОЙ КЛИЧ!")
        net.Broadcast()

        -- Очищаем старый список баффов
        self.BuffList = {}

        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), CRY_RADIUS)) do
            if IsValid(ent) and ent.IsNecoArc and ent ~= self then
                ent.BerserkerBuffEnd = CurTime() + CRY_DUR
                ent.BerserkerSpeedMult = ALLY_SPEED_BOOST
                ent.BerserkerDmgMult   = ALLY_DMG_BOOST
                table.insert(self.BuffList, ent)
                if DEBUG then print("[Berserker Lord] Buffed: " .. tostring(ent) .. " (" .. (ent.NecoType or "unknown") .. ")") end
            end
        end

        if DEBUG then print("[Berserker Lord] Total buffed allies: " .. #self.BuffList) end

        timer.Simple(2.0, function() if IsValid(self) then self:SetNWBool("BerserkerCry", false) end end)
    end

    function ENT:ActivateBerserk()
        self.BerserkActive = true
        self:SetNWBool("BerserkerBerserk", true)
        self:EmitSound("npc/strider/striderx_alert2.wav", 160, 80)
        net.Start("NAA_SpecialAlert")
            net.WriteString("Берсерк Лорд: БЕРСЕРК!")
        net.Broadcast()
        if DEBUG then print("[Berserker Lord] Berserk mode activated") end
        timer.Simple(BERSERK_DUR, function()
            if IsValid(self) then
                self.BerserkActive = false
                self:SetNWBool("BerserkerBerserk", false)
                if DEBUG then print("[Berserker Lord] Berserk mode ended") end
            end
        end)
    end

    function ENT:EnterPhase2()
        self.Phase2Done = true
        self.Phase      = 2
        self.Invulnerable = true
        self:SetNWInt("BerserkerPhase", 2)
        self:SetNWBool("BerserkerInvulnerable", true)
        self.WalkSpeed = 380; self.RunSpeed = 380
        self.MeleeCooldown = 0.8
        self:SetModelScale(2.8)

        self:EmitSound("npc/strider/strider_roar1.wav", 165, 70)
        util.ScreenShake(self:GetPos(), 15, 20, 2.5, 1500)
        net.Start("NAA_BerserkerPhase2")
        net.Broadcast()
        net.Start("NAA_SpecialAlert")
            net.WriteString("БЕРСЕРК ЛОРД ПЕРЕХОДИТ В РЕЖИМ ЯРОСТИ!")
        net.Broadcast()

        if DEBUG then print("[Berserker Lord] Phase 2 entered") end

        timer.Simple(INVULN_DUR, function()
            if IsValid(self) then
                self.Invulnerable = false
                self:SetNWBool("BerserkerInvulnerable", false)
                if DEBUG then print("[Berserker Lord] Invulnerability ended") end
            end
        end)
    end

    function ENT:OnTakeDamage(dmginfo)
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker.IsNecoArc then dmginfo:SetDamage(0); return end
        if self.Invulnerable then dmginfo:SetDamage(0); return end
        local dmg = dmginfo:GetDamage()
        if self.NecoBlessUntil and self.NecoBlessUntil > CurTime() then
            dmg = dmg * (self.NecoBlessMult or 1)
        end
        dmginfo:SetDamage(dmg)
        self.BaseClass.OnTakeDamage(self, dmginfo)
        if DEBUG then print("[Berserker Lord] Took " .. dmg .. " dmg, HP: " .. self:Health()) end
        self:EmitSound("infection/neco/pain" .. math.random(1,3) .. ".mp3", 140, 80)
    end

    function ENT:OnKilled(dmg)
        util.ScreenShake(self:GetPos(), 20, 25, 3.5, 1200)
        self:EmitSound("npc/strider/striderx_die1.wav", 165, 70)
        if DEBUG then print("[Berserker Lord] Killed") end
        if NAA_OnNecoKilled then NAA_OnNecoKilled(self, dmg:GetAttacker()) end
        self:Remove()
    end

    hook.Add("Think", "Berserker_StunEffect", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply.BerserkerStunnedUntil and CurTime() < ply.BerserkerStunnedUntil then
                ply:SetVelocity(-ply:GetVelocity() * 0.85)
            elseif ply.BerserkerStunnedUntil then
                ply.BerserkerStunnedUntil = nil
            end
        end
    end)

    function ENT:WhileAlive() end
end