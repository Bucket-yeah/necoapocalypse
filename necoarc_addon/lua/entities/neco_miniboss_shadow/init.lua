-- shared.lua (если нужен, но предположительно у вас уже есть общий shared.lua для всех неко)
-- В shared.lua должны быть определения ENT.Base = "base_nextbot" и т.д.

-- init.txt (серверная часть)
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    local MELEE_DIST = 90
    local MELEE_DMG = 30
    local CRIT_MULT = 2
    local TELEPORT_CD = 10
    local TELEPORT_MAX_DIST = 1000
    local SHIELD_HP = 500
    local SHIELD_SPEED_BOOST = 1.5
    local FLEE_DUR = 3
    local FLEE_DUR_NORMAL = 1.5
    local SHADOW_STEP_CD = 20
    local SHADOW_STEP_WINDOW = 2
    local FEAR_RADIUS = 300

    local DEBUG = false

    -- Вспомогательная функция: устанавливает альфу через NW-переменную
    -- Щит переопределяет всё на клиенте, поэтому здесь только ShadowAlpha
    local function SetAlpha(ent, alpha)
        ent:SetNWInt("ShadowAlpha", alpha)
    end

    function ENT:CustomInitialize()
        -- Убираем серверный SetColor/SetRenderMode полностью.
        -- Клиент сам читает ShadowAlpha и рисует нужный цвет.
        SetAlpha(self, 180) -- обычное состояние: видим (180)
        self:SetNWBool("ShadowShield", false)

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

        self.BaseSpeed = self.RunSpeed
        self.NextAttack = 0
        self.NextTeleport = CurTime() + TELEPORT_CD
        self.ShieldActive = false
        self.ShieldUsed = false
        self.ShieldHP = 0
        self.IsFleeing = false
        self.FleeEnd = 0
        self.DamageHistory = {}
        self.NextShadowStep = CurTime() + SHADOW_STEP_CD
        self.LastPain = 0

        if DEBUG then
            print("[Shadow] Spawned with HP: " .. self:Health())
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

            self:UpdateDamageHistory(now)

            if IsValid(target) then
                local dist = self:GetPos():Distance(target:GetPos())
                self:FaceTowards(target)

                if self.IsFleeing then
                    if now < self.FleeEnd then
                        local awayDir = (self:GetPos() - target:GetPos()):GetNormalized()
                        self:MoveToPos(self:GetPos() + awayDir * 150)
                        coroutine.yield()
                    else
                        self.IsFleeing = false
                        -- Отступление закончено → снова видим (180)
                        -- Если щит ещё активен, клиент сам применит его цвет
                        if not self.ShieldActive then
                            SetAlpha(self, 180)
                        end
                    end
                else
                    if dist > MELEE_DIST then
                        self:MoveToPos(target:GetPos())
                    else
                        self:StopMoving()
                        if now >= self.NextAttack then
                            self:TryMeleeAttack(target)
                        end
                    end

                    if now >= self.NextTeleport and dist <= TELEPORT_MAX_DIST then
                        self:DoTeleportStrike(target)
                        self.NextTeleport = now + TELEPORT_CD
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
        local ang = (target:GetPos() - self:GetPos()):Angle()
        self:SetAngles(Angle(0, ang.y, 0))
    end

    function ENT:UpdateDamageHistory(now)
        local threshold = now - SHADOW_STEP_WINDOW
        for i = #self.DamageHistory, 1, -1 do
            if self.DamageHistory[i] < threshold then
                table.remove(self.DamageHistory, i)
            end
        end
    end

    function ENT:RecordDamage(amount)
        table.insert(self.DamageHistory, CurTime())
    end

    function ENT:TryShadowStep()
        if CurTime() < self.NextShadowStep then return false end
        if #self.DamageHistory >= 3 then
            self:DoShadowStep()
            self.NextShadowStep = CurTime() + SHADOW_STEP_CD
            self.DamageHistory = {}
            return true
        end
        return false
    end

    function ENT:DoShadowStep()
        local target = self:FindTarget()
        local telePos = self:GetPos()
        if IsValid(target) then
            local angle = math.random() * 360
            local dist = math.random(300, 400)
            local offset = Vector(math.cos(math.rad(angle)) * dist, math.sin(math.rad(angle)) * dist, 0)
            telePos = target:GetPos() + offset
        else
            telePos = self:GetPos() + Vector(math.random(-400, 400), math.random(-400, 400), 0)
        end

        local tr = util.TraceLine({ start = telePos + Vector(0,0,100), endpos = telePos - Vector(0,0,200), mask = MASK_SOLID_BRUSHONLY })
        if tr.Hit then telePos = tr.HitPos + Vector(0, 0, 10) end

        self:SetPos(telePos)
        self:EmitSound("ambient/machines/teleport1.wav", 80)

        -- Shadow Step: прерывает отступление, становится полностью видимым (180)
        self.IsFleeing = false
        self.FleeEnd = 0
        if not self.ShieldActive then
            SetAlpha(self, 180)
        end

        if DEBUG then print("[Shadow] Shadow Step activated!") end
    end

    function ENT:DoTeleportStrike(target)
        local tPos = target:GetPos()
        local behind = tPos + target:GetForward() * -80
        behind.z = tPos.z

        local tr = util.TraceLine({ start = behind + Vector(0,0,100), endpos = behind - Vector(0,0,200), mask = MASK_SOLID_BRUSHONLY })
        local telePos = tr.Hit and (tr.HitPos + Vector(0, 0, 5)) or behind

        self:EmitSound("ambient/machines/teleport1.wav", 80)
        self:SetPos(telePos)

        -- Телепортировались за спину: момент удара — видимый (180)
        if not self.ShieldActive then
            SetAlpha(self, 180)
        end
        self.IsFleeing = false

        timer.Simple(0.15, function()
            if not IsValid(self) or not IsValid(target) then return end
            if self:GetPos():Distance(target:GetPos()) > 150 then return end

            local dmg = DamageInfo()
            dmg:SetDamage(MELEE_DMG * CRIT_MULT)
            dmg:SetAttacker(self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_CLUB)
            target:TakeDamageInfo(dmg)
            self:EmitSound("weapons/stunstick/stunstick_swing2.wav", 85)

            if DEBUG then print("[Shadow] Teleport critical strike!") end

            -- После крит-удара: уходим в тень (30), отступаем 3 сек
            self.IsFleeing = true
            self.FleeEnd = CurTime() + FLEE_DUR
            if not self.ShieldActive then
                SetAlpha(self, 30)
            end
        end)

        self.NextTeleport = CurTime() + TELEPORT_CD
    end

    function ENT:TryMeleeAttack(target)
        if CurTime() < self.NextAttack then return end

        self:PlaySequence("melee_attack")
        self:EmitSound("weapons/stunstick/stunstick_swing" .. math.random(1,2) .. ".wav", 75)

        timer.Simple(0.2, function()
            if not IsValid(self) or not IsValid(target) then return end
            if self:GetPos():Distance(target:GetPos()) > MELEE_DIST + 30 then return end

            local dmg = DamageInfo()
            dmg:SetDamage(MELEE_DMG)
            dmg:SetAttacker(self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_CLUB)
            target:TakeDamageInfo(dmg)

            if DEBUG then print("[Shadow] Normal melee attack") end

            -- После обычного удара: уходим в тень (30), отступаем 1.5 сек
            self.IsFleeing = true
            self.FleeEnd = CurTime() + FLEE_DUR_NORMAL
            if not self.ShieldActive then
                SetAlpha(self, 30)
            end
        end)

        self.NextAttack = CurTime() + self.MeleeCooldown
    end

    function ENT:OnTakeDamage(dmginfo)
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker.IsNecoArc then
            dmginfo:SetDamage(0)
            if DEBUG then print("[Shadow] Damage from ally NULLIFIED!") end
            return
        end

        local dmg = dmginfo:GetDamage()
        self:RecordDamage(dmg)

        if self.ShieldActive then
            self.ShieldHP = self.ShieldHP - dmg
            if DEBUG then
                print("[Shadow] Shield hit! Damage: " .. dmg .. ", Shield HP left: " .. self.ShieldHP)
            end
            if self.ShieldHP <= 0 then
                self.ShieldActive = false
                self.loco:SetDesiredSpeed(self.BaseSpeed)
                self:SetNWBool("ShadowShield", false)
                self:ClearFearEffect()
                self:EmitSound("ambient/machines/teleport1.wav", 70)
                -- Щит сломан: восстанавливаем прозрачность по текущему состоянию
                SetAlpha(self, self.IsFleeing and 30 or 180)
                if DEBUG then print("[Shadow] Shield broken") end
            end
            return
        end

        if (self.NecoBlessUntil or 0) > CurTime() and self.NecoBlessMult then
            dmg = dmg * self.NecoBlessMult
        end

        if DEBUG then
            print("[Shadow] Took " .. dmg .. " damage (original: " .. dmginfo:GetDamage() .. ")")
        end

        dmginfo:SetDamage(dmg)
        self.BaseClass.OnTakeDamage(self, dmginfo)

        if not self.ShieldUsed and self:Health() <= math.ceil(self:GetMaxHealth() * 0.30) then
            self:ActivateShield()
        end

        self:TryShadowStep()

        if self:Health() > 0 then
            if (self.LastPain or 0) < CurTime() then
                self:EmitSound("infection/neco/pain" .. math.random(1,3) .. ".mp3", 90)
                self.LastPain = CurTime() + 0.5
            end
        end
    end

    function ENT:ActivateShield()
        self.ShieldUsed = true
        self.ShieldActive = true
        self.ShieldHP = SHIELD_HP
        self.loco:SetDesiredSpeed(self.BaseSpeed * SHIELD_SPEED_BOOST)
        self:SetNWBool("ShadowShield", true)
        -- ShadowAlpha при щите не важен: клиент использует цвет щита (20,0,60,220)
        -- Но на всякий случай выставим 220, чтобы не путаться
        SetAlpha(self, 220)
        self:EmitSound("ambient/atmosphere/thunder1.wav", 90)
        self:ApplyFearEffect()

        net.Start("NAA_SpecialAlert")
            net.WriteString("Теневой щит активирован!")
        net.Broadcast()

        if DEBUG then
            print("[Shadow] Shadow Shield activated! Shield HP: " .. SHIELD_HP)
        end
    end

    function ENT:ApplyFearEffect()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and ply:GetPos():Distance(self:GetPos()) < FEAR_RADIUS then
                ply.ShadowFearActive = true
                ply.ShadowFearEnd = math.huge
            end
        end
    end

    function ENT:ClearFearEffect()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                ply.ShadowFearActive = false
                ply.ShadowFearEnd = 0
            end
        end
    end

    function ENT:OnKilled(dmg)
        if DEBUG then print("[Shadow] OnKilled triggered!") end
        self:ClearFearEffect()
        local attacker = dmg:GetAttacker()
        if NAA_OnNecoKilled then NAA_OnNecoKilled(self, attacker) end
        self:Remove()
    end

    function ENT:WhileAlive() end
end