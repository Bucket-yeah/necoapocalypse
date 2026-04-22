AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    util.AddNetworkString("NAA_ApexNova")
    util.AddNetworkString("NAA_ApexMeteor")
    util.AddNetworkString("NAA_ApexApocalypse")
    util.AddNetworkString("NAA_ApexPhase")
    util.AddNetworkString("NAA_ApexTeleport")
    util.AddNetworkString("NAA_SpecialAlert")
    util.AddNetworkString("NAA_ApexDeath")
    util.AddNetworkString("NAA_ApexDeathBurst")

    local P2_THRESHOLD  = 0.60
    local P3_THRESHOLD  = 0.25

    local STRIKE_DMG    = { 50, 70, 75 }
    local STRIKE_CD     = { 4.5, 3.5, 2.5 }
    local STRIKE_RADIUS = 350
    local TELE_CD       = { 20, 15, 12 }
    local SUMMON_COUNT  = { 4, 6, 8 }
    local SUMMON_CD     = { 18, 15, 10 }
    local SHOT_CD       = 3
    local SHOT_COUNT    = 3
    local SHOT_DMG      = 25
    local NOVA_CD       = 10                 -- увеличен кулдаун
    local NOVA_BEAMS    = 12
    local NOVA_DMG      = 35
    local APOC_CD       = 35                 -- увеличен кулдаун
    local APOC_DUR      = 8
    local METEOR_COUNT  = 12
    local METEOR_DMG    = 50
    local METEOR_RADIUS = 150
    local MELEE_DIST    = 400

    local SUMMON_TYPES = {
        "neco_normal",
        "neco_runner",
        "neco_kamikaze",
        "neco_armored",
        "neco_berserker"
    }

    local DEBUG = false

    function ENT:CustomInitialize()
        self:SetNWString("NecoType",    self.NecoType)
        self:SetNWInt("NecoMaxHP",      self.SpawnHealth)
        self:SetNWInt("ApexPhase",      1)
        self:SetNWBool("ApexNova",      false)
        self:SetNWBool("ApexApocalypse",false)
        self:SetNWBool("ApexTeleporting",false)
        self:SetNWBool("ApexShot",      false)

        self:SetRenderMode(RENDERMODE_TRANSADD)
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        if self.NAADiff then
            local hp = math.ceil(self.SpawnHealth * (self.NAADiff.hpMult or 1))
            self:SetMaxHealth(hp); self:SetHealth(hp)
            self:SetNWInt("NecoMaxHP", hp)
        end

        self.Phase        = 1
        self.NextMelee    = 0
        self.NextStrike   = CurTime() + 3
        self.NextTele     = CurTime() + 10
        self.NextSummon   = CurTime() + 6
        self.NextShot     = CurTime() + 5
        self.NextNova     = CurTime() + 15
        self.NextApoc     = CurTime() + APOC_CD
        self.P2Done       = false
        self.P3Done       = false
        self.ApocActive   = false
        self.NovaActive   = false
        self.Busy         = false      -- блокировка других действий
        self.StepTimer    = 0

        if DEBUG then print("[Apex] Spawned, HP: " .. self:Health() .. ", Phase: 1") end
    end

    function ENT:BehaveStart()
        self.BehaveThread = coroutine.create(function() self:RunBehaviour() end)
    end

    function ENT:RunBehaviour()
        coroutine.wait(0.5)
        while true do
            -- Если идёт супер-атака, ждём
            if self.ApocActive or self.NovaActive or self.Busy then
                coroutine.yield()
                continue
            end

            local now    = CurTime()
            local target = self:FindTarget()
            local p      = self.Phase

            local hpPct = self:Health() / self:GetMaxHealth()
            if not self.P2Done and hpPct <= P2_THRESHOLD then self:TransitionPhase(2) end
            if not self.P3Done and hpPct <= P3_THRESHOLD then self:TransitionPhase(3) end

            if now >= self.StepTimer then
                self.StepTimer = now + 0.8
                util.ScreenShake(self:GetPos(), 6, 8, 0.5, 800)
                self:EmitSound("physics/concrete/concrete_impact_hard" .. math.random(1,3) .. ".wav", 140, 45)
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
                        if DEBUG then print("[Apex] Melee attack on " .. target:Nick() .. ", dmg: " .. (50 + (self.Phase - 1) * 20)) end
                    end
                end

                -- Все атаки проверяют self.Busy
                if not self.Busy then
                    if now >= self.NextStrike then
                        self:DoStrike()
                        self.NextStrike = now + STRIKE_CD[p] + 0.5
                    end

                    if now >= self.NextTele then
                        self:DoTeleport(target)
                        self.NextTele = now + TELE_CD[p] + 0.5
                    end

                    if now >= self.NextSummon then
                        self:DoSummon()
                        self.NextSummon = now + SUMMON_CD[p] + 0.5
                    end

                    if p >= 2 and now >= self.NextShot then
                        self:DoShots(target)
                        self.NextShot = now + SHOT_CD + 0.5
                    end

                    if p == 3 and now >= self.NextNova then
                        self:DoNova()
                        self.NextNova = now + NOVA_CD
                    end

                    if p == 3 and now >= self.NextApoc then
                        self:DoApocalypse()
                        self.NextApoc = now + APOC_CD
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
        local plys = {}
        for _, ply in player.Iterator() do
            if IsValid(ply) and ply:Alive() then table.insert(plys, ply) end
        end
        if #plys == 0 then return nil end
        if self.Phase == 3 then return plys[math.random(#plys)] end
        local best, bestD = nil, math.huge
        for _, ply in ipairs(plys) do
            local d = self:GetPos():DistToSqr(ply:GetPos())
            if d < bestD then bestD = d; best = ply end
        end
        return best
    end

    function ENT:StopMoving() self.loco:SetDesiredSpeed(0) end

    function ENT:FaceTowards(ent)
        local a = (ent:GetPos() - self:GetPos()):Angle()
        self:SetAngles(Angle(0, a.y, 0))
    end

    function ENT:DoMelee(target)
        local dmg = 50 + (self.Phase - 1) * 20
        self:PlaySequence("melee_attack")
        self:EmitSound("weapons/crowbar/crowbar_impact" .. math.random(1,2) .. ".wav", 150, 55)
        timer.Simple(0.3, function()
            if not IsValid(self) or not IsValid(target) then return end
            if self:GetPos():Distance(target:GetPos()) > MELEE_DIST + 100 then return end
            local d = DamageInfo()
            d:SetDamage(dmg); d:SetAttacker(self); d:SetInflictor(self); d:SetDamageType(DMG_CLUB)
            target:TakeDamageInfo(d)
            target:SetVelocity((target:GetPos()-self:GetPos()):GetNormalized() * 400 + Vector(0,0,220))
            util.ScreenShake(self:GetPos(), 8, 10, 0.6, 600)
        end)
        self.NextMelee = CurTime() + self.MeleeCooldown
    end

    function ENT:DoStrike()
        self.Busy = true
        self:StopMoving()
        self:PlaySequence("melee_attack")
        self:EmitSound("physics/metal/metal_barrel_impact_hard1.wav", 165, 50)
        util.ScreenShake(self:GetPos(), 10, 12, 1.0, STRIKE_RADIUS + 200)

        local pos = self:GetPos()
        self:SetNWBool("ApexNova", true)
        timer.Simple(0.4, function() if IsValid(self) then self:SetNWBool("ApexNova", false) end end)

        local dmg = STRIKE_DMG[self.Phase]
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:Alive() then continue end
            local dist = ply:GetPos():Distance(pos)
            if dist > STRIKE_RADIUS then continue end
            local d = DamageInfo()
            d:SetDamage(dmg * (1 - dist/STRIKE_RADIUS * 0.4))
            d:SetAttacker(self); d:SetInflictor(self); d:SetDamageType(DMG_BLAST)
            ply:TakeDamageInfo(d)
            local dir = (ply:GetPos() - pos):GetNormalized(); dir.z = 0.4
            ply:SetVelocity(dir * 450 + Vector(0,0,250))
        end

        net.Start("NAA_ApexNova")
            net.WriteVector(pos)
            net.WriteBool(false)
        net.Broadcast()

        timer.Simple(1.0, function() if IsValid(self) then self.Busy = false end end)
        if DEBUG then print("[Apex] Strike AOE, phase: " .. self.Phase) end
    end

    function ENT:DoTeleport(target)
        self.Busy = true
        local plys = {}
        for _, ply in player.Iterator() do
            if IsValid(ply) and ply:Alive() then table.insert(plys, ply) end
        end
        if #plys == 0 then self.Busy = false; return end
        local destPly = plys[math.random(#plys)]
        local destPos = destPly:GetPos() + destPly:GetForward() * -180 + Vector(0,0,5)

        self:SetNWBool("ApexTeleporting", true)
        self:EmitSound("ambient/machines/teleport1.wav", 150)

        net.Start("NAA_ApexTeleport")
            net.WriteVector(self:GetPos())
            net.WriteVector(destPos)
        net.Broadcast()

        timer.Simple(0.4, function()
            if not IsValid(self) then return end
            self:SetPos(destPos)
            self:SetNWBool("ApexTeleporting", false)
            util.ScreenShake(destPos, 12, 15, 1.0, 600)
            self.Busy = false
        end)
        if DEBUG then print("[Apex] Teleported to random player") end
    end

    function ENT:DoSummon()
        self.Busy = true
        local diff  = self.NAADiff or { hpMult = 1 }
        local count = SUMMON_COUNT[self.Phase]
        for i = 1, count do
            timer.Simple(i * 0.25, function()
                if not IsValid(self) then return end
                local ang   = math.random(0, 360)
                local r     = math.random(80, 200)
                local spawn = self:GetPos() + Vector(math.cos(math.rad(ang))*r, math.sin(math.rad(ang))*r, 0)
                local tr    = util.TraceLine({ start=spawn+Vector(0,0,100), endpos=spawn-Vector(0,0,200), mask=MASK_SOLID_BRUSHONLY })
                spawn = tr.Hit and (tr.HitPos+Vector(0,0,5)) or spawn

                local enemyType = SUMMON_TYPES[math.random(#SUMMON_TYPES)]
                local minion = ents.Create(enemyType)
                if not IsValid(minion) then return end
                minion:SetPos(spawn); minion.NAADiff = diff
                minion.IsNecoArc = true; minion.IsSummonedBy = self
                minion:Spawn(); minion:Activate()
                minion:SetModelScale(0.8)
                if DEBUG then print("[Apex] Summoned " .. enemyType) end
            end)
        end
        self:EmitSound("ambient/energy/zap1.wav", 120)
        timer.Simple(1.5, function() if IsValid(self) then self.Busy = false end end)
        if DEBUG then print("[Apex] Summoned " .. count .. " minions") end
    end

    function ENT:DoShots(target)
        if not IsValid(target) then return end
        self.Busy = true
        self:SetNWBool("ApexShot", true)
        timer.Simple(0.2, function() if IsValid(self) then self:SetNWBool("ApexShot", false) end end)

        local offsets = { Vector(0,0,0), Vector(20,0,0), Vector(-20,0,0) }
        for i = 1, SHOT_COUNT do
            timer.Simple(i * 0.12, function()
                if not IsValid(self) or not IsValid(target) then return end
                local proj = ents.Create("neco_proj_spore")
                if not IsValid(proj) then return end
                proj.IsHoming  = false
                proj.MoveSpeed = 900
                proj.PoisonDmg = SHOT_DMG
                proj.PoisonDur = 0
                proj.Target    = target
                proj.Attacker  = self
                proj:SetPos(self:GetPos() + Vector(0,0,100) + (offsets[i] or Vector(0,0,0)))
                proj:Spawn()
                proj:Activate()
            end)
        end
        timer.Simple(1.0, function() if IsValid(self) then self.Busy = false end end)
        if DEBUG then print("[Apex] Fired 3 shots at " .. target:Nick()) end
    end

    function ENT:DoNova()
        self.Busy = true
        self.NovaActive = true
        self:StopMoving()
        self:EmitSound("ambient/levels/labs/electric_explosion1.wav", 165)
        util.ScreenShake(self:GetPos(), 15, 20, 2.0, 1000)

        net.Start("NAA_ApexNova")
            net.WriteVector(self:GetPos())
            net.WriteBool(true)
        net.Broadcast()
        net.Start("NAA_SpecialAlert")
            net.WriteString("АПЕКС НЕКО: НОВА!")
        net.Broadcast()

        local pos = self:GetPos()
        for i = 0, NOVA_BEAMS - 1 do
            local ang     = i * (360 / NOVA_BEAMS)
            local dir     = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            local beam_end = pos + dir * 1000
            local tr      = util.TraceLine({ start = pos, endpos = beam_end, mask = MASK_SOLID })

            for _, ply in ipairs(player.GetAll()) do
                if not IsValid(ply) or not ply:Alive() then continue end
                local closest = pos + dir * math.max(0, (ply:GetPos() - pos):Dot(dir))
                if closest:Distance(ply:GetPos()) < 60 then
                    local d = DamageInfo()
                    d:SetDamage(NOVA_DMG); d:SetAttacker(self); d:SetInflictor(self)
                    d:SetDamageType(DMG_ENERGYBEAM)
                    ply:TakeDamageInfo(d)
                end
            end
        end

        timer.Simple(3.0, function()
            if IsValid(self) then
                self.NovaActive = false
                self.Busy = false
            end
        end)
        if DEBUG then print("[Apex] NOVA!") end
    end

    function ENT:DoApocalypse()
        if self.ApocActive then return end
        self.Busy = true
        self.ApocActive = true
        self:SetNWBool("ApexApocalypse", true)
        self:StopMoving()
        self:EmitSound("npc/strider/striderx_alert2.wav", 175, 55)
        net.Start("NAA_ApexApocalypse")
            net.WriteBool(true)
        net.Broadcast()
        net.Start("NAA_SpecialAlert")
            net.WriteString("⚠ АПЕКС НЕКО: КОНЕЦ СВЕТА!")
        net.Broadcast()

        local basePos = self:GetPos()
        local liftH   = 350
        for i = 1, 20 do
            timer.Simple(i * 0.05, function()
                if not IsValid(self) then return end
                self:SetPos(basePos + Vector(0, 0, liftH * (i/20)))
            end)
        end

        local players = {}
        for _, ply in player.Iterator() do
            if IsValid(ply) and ply:Alive() then table.insert(players, ply) end
        end

        for i = 1, METEOR_COUNT do
            timer.Simple(1.0 + i * (APOC_DUR / METEOR_COUNT), function()
                if #players == 0 then return end
                local ply = players[math.random(#players)]
                if not IsValid(ply) then return end
                local angle = math.random(0, 360)
                local dist = math.random(100, 400)
                local target = ply:GetPos() + Vector(math.cos(math.rad(angle))*dist, math.sin(math.rad(angle))*dist, 0)

                net.Start("NAA_ApexMeteor")
                    net.WriteVector(target)
                net.Broadcast()

                timer.Simple(1.5, function()
                    if not IsValid(self) then return end
                    local meteor = ents.Create("neco_proj_meteor")
                    if IsValid(meteor) then
                        meteor:SetPos(target + Vector(0, 0, 900))
                        meteor.TargetPos = target
                        meteor.Attacker  = self
                        meteor.ImpactDmg = METEOR_DMG
                        meteor.ImpactRad = METEOR_RADIUS
                        meteor:Spawn(); meteor:Activate()
                    end
                end)
            end)
        end

        timer.Simple(APOC_DUR + 1.2, function()
            if not IsValid(self) then return end
            self:SetPos(basePos)
            self.ApocActive = false
            self:SetNWBool("ApexApocalypse", false)
            net.Start("NAA_ApexApocalypse")
                net.WriteBool(false)
            net.Broadcast()
            util.ScreenShake(basePos, 25, 30, 3.0, 2000)
            self:EmitSound("physics/metal/metal_barrel_impact_hard1.wav", 175, 40)
            self.Busy = false
        end)
        if DEBUG then print("[Apex] APOCALYPSE!") end
    end

    function ENT:TransitionPhase(newPhase)
        if newPhase == 2 then self.P2Done = true elseif newPhase == 3 then self.P3Done = true end
        self.Phase = newPhase
        self:SetNWInt("ApexPhase", newPhase)

        local scales = { 5.0, 5.5, 6.0 }
        local speeds = { 130, 200, 320 }
        self:SetModelScale(scales[newPhase])
        self.WalkSpeed = speeds[newPhase]; self.RunSpeed = speeds[newPhase]

        self:SetRenderMode(RENDERMODE_TRANSADD)

        self:EmitSound("npc/strider/striderx_alert2.wav", 170, 65 - newPhase * 5)
        util.ScreenShake(self:GetPos(), 20, 25, 3.0, 2000)
        net.Start("NAA_ApexPhase")
            net.WriteInt(newPhase, 4)
        net.Broadcast()
        net.Start("NAA_SpecialAlert")
            net.WriteString("АПЕКС НЕКО: ФАЗА " .. newPhase .. "!")
        net.Broadcast()

        if DEBUG then print("[Apex] Entered Phase " .. newPhase .. ", Scale: " .. scales[newPhase] .. ", Speed: " .. speeds[newPhase]) end
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
        if DEBUG then print("[Apex] Took " .. dmg .. " dmg, HP: " .. self:Health()) end
        self:EmitSound("infection/neco/pain" .. math.random(1,3) .. ".mp3", 150, 70)
    end

    function ENT:OnKilled(dmg)
        if DEBUG then print("[Apex] Killed! GRAND FINALE!") end

        local pos      = self:GetPos()
        local attacker = IsValid(dmg:GetAttacker()) and dmg:GetAttacker() or nil

        -- Заморозить босса на месте
        self.Busy      = true
        self.ApocActive = false
        self.NovaActive = false
        self:StopMoving()
        self:SetNWBool("ApexApocalypse", false)

        -- Уведомить клиентов: начало грандиозного финала
        net.Start("NAA_ApexDeath")
            net.WriteVector(pos)
            net.WriteInt(self.Phase or 3, 4)
        net.Broadcast()

        net.Start("NAA_SpecialAlert")
            net.WriteString("☠ АПЕКС НЕКО ПАЛА!")
        net.Broadcast()

        -- [0.0s] Первый удар — смертельный вопль + начальная тряска
        util.ScreenShake(pos, 45, 55, 5.0, 5000)
        self:EmitSound("npc/strider/striderx_die1.wav", 185, 45)
        self:EmitSound("infection/neco/death" .. math.random(1,3) .. ".mp3", 185, 60)

        -- [0.2–3.0s] Серия нарастающих взрывов вокруг тела
        local BURST_TIMES = { 0.20, 0.55, 0.90, 1.20, 1.55, 1.85, 2.15, 2.50, 2.80, 3.05 }
        for idx, bt in ipairs(BURST_TIMES) do
            timer.Simple(bt, function()
                if not IsValid(self) then return end
                local spread = 120 + idx * 18
                local bpos   = pos + Vector(
                    math.random(-spread, spread),
                    math.random(-spread, spread),
                    math.random(0, 200)
                )
                self:EmitSound("ambient/explosions/explode_" .. math.random(1,9) .. ".wav",
                    180, math.random(42, 70))
                util.ScreenShake(bpos, 22 + idx * 2, 28, 1.2, 2200)

                -- Мини-взрывные волны урона (не дамажим, только визуально)
                net.Start("NAA_ApexDeathBurst")
                    net.WriteVector(bpos)
                    net.WriteFloat(idx / #BURST_TIMES)
                net.Broadcast()
            end)
        end

        -- [1.5s] Рёв из самых глубин — Страйдер на минимальной ноте
        timer.Simple(1.5, function()
            if not IsValid(self) then return end
            self:EmitSound("npc/strider/striderx_alert2.wav", 185, 38)
        end)

        -- [3.5s] Предфинальная вспышка — самая сильная тряска
        timer.Simple(3.5, function()
            if not IsValid(self) then return end
            util.ScreenShake(pos, 70, 90, 9.0, 8000)
            self:EmitSound("ambient/levels/labs/electric_explosion1.wav", 185, 38)
            self:EmitSound("ambient/explosions/explode_" .. math.random(1,9) .. ".wav", 185, 38)

            -- Финальный сигнал клиентам: колоссальная вспышка
            net.Start("NAA_ApexDeathBurst")
                net.WriteVector(pos + Vector(0,0,80))
                net.WriteFloat(1.0)   -- 1.0 = финал
            net.Broadcast()
        end)

        -- [5.0s] Последнее эхо взрыва
        timer.Simple(5.0, function()
            if not IsValid(self) then return end
            self:EmitSound("ambient/explosions/explode_" .. math.random(1,9) .. ".wav", 175, 42)
            util.ScreenShake(pos, 25, 30, 3.0, 4000)
        end)

        -- [6.5s] Удалить, вызвать колбэк
        timer.Simple(6.5, function()
            if NAA_OnNecoKilled then NAA_OnNecoKilled(self, attacker) end
            if IsValid(self) then self:Remove() end
        end)
    end

    function ENT:WhileAlive() end
end