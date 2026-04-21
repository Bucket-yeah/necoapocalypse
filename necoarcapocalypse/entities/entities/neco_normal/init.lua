AddCSLuaFile("shared.lua")
include("shared.lua")

if SERVER then
    -- Параметры из ТЗ (с корректировками)
    local BASE_SPEED = 180
    local ATTACK_DAMAGE_PISTOL = 2
    local ATTACK_DAMAGE_SMG = 3
    local ATTACK_COOLDOWN_PISTOL = 0.9
    local ATTACK_COOLDOWN_SMG = 0.25
    local STOP_DISTANCE = 650
    local TOO_CLOSE_DISTANCE = 250

    function ENT:CustomInitialize()
        self:SetColor(Color(220, 220, 220))
        self:SetNWString("NecoType", self.NecoType)
        self:SetNWInt("NecoMaxHP", self.SpawnHealth)

        if self.NAADiff then
            local hpMult = self.NAADiff.hpMult or 1
            local newHp = math.ceil(self.SpawnHealth * hpMult)
            self:SetMaxHealth(newHp)
            self:SetHealth(newHp)
            self:SetNWInt("NecoMaxHP", newHp)
        end

        self.UseSmg = math.random() < 0.5
        self.AttackDamage = self.UseSmg and ATTACK_DAMAGE_SMG or ATTACK_DAMAGE_PISTOL
        self.AttackCooldown = self.UseSmg and ATTACK_COOLDOWN_SMG or ATTACK_COOLDOWN_PISTOL

        self.NextAttack = 0
        
        -- Разрешаем NPC игнорировать коллизию друг с другом (если не установлено в shared)
        if not self.IgnoreCollisionWithAllies then
            self.IgnoreCollisionWithAllies = true
        end
    end

    function ENT:BehaveStart()
        self.BehaveThread = coroutine.create(function() self:RunBehaviour() end)
    end

    function ENT:RunBehaviour()
        coroutine.wait(0.2)

        while true do
            local target = self:FindTarget()
            
            if IsValid(target) then
                local dist = self:GetPos():Distance(target:GetPos())
                
                self:FaceTowards(target)

                if dist < TOO_CLOSE_DISTANCE then
                    self:RetreatFrom(target, 150)
                elseif dist > STOP_DISTANCE then
                    self:MoveToPos(target:GetPos())
                else
                    self:StopMoving()
                end

                self:TryShoot(target)
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

    function ENT:RetreatFrom(target, distance)
        local dir = (self:GetPos() - target:GetPos()):GetNormalized()
        local retreatPos = self:GetPos() + dir * distance
        self:MoveToPos(retreatPos)
    end

    function ENT:StopMoving()
        self.loco:SetDesiredSpeed(0)
    end

    function ENT:FaceTowards(target)
        local dir = (target:GetPos() - self:GetPos()):GetNormalized()
        local ang = dir:Angle()
        self:SetAngles(Angle(0, ang.y, 0))
    end

    function ENT:TryShoot(target)
        if CurTime() < self.NextAttack then return end
        if not self:CanSee(target) then return end

        self:PlaySequence("range_attack")
        
        if self.UseSmg then
            self:EmitSound("weapons/smg1/smg1_fire1.wav", 70, 110)
        else
            self:EmitSound("weapons/pistol/pistol_fire2.wav", 75, 120)
        end

        local bullet = {}
        bullet.Num = 1
        bullet.Src = self:GetShootPos()
        bullet.Dir = (target:GetPos() + target:OBBCenter() - self:GetShootPos()):GetNormalized()
        bullet.Spread = Vector(0.12, 0.12, 0)
        bullet.Tracer = 1
        bullet.Force = 5
        bullet.Damage = self.AttackDamage
        bullet.Attacker = self
        -- Игнорируем всех союзных NPC при стрельбе
        bullet.IgnoreEntity = self -- начнём с себя
        -- Дополнительно передадим функцию фильтрации (если поддерживается)
        bullet.Callback = function(attacker, tr, dmginfo)
            -- Если попали в союзного неко, пропускаем (не наносим урон)
            if IsValid(tr.Entity) and tr.Entity.IsNecoArc then
                return false
            end
            return true
        end
        self:FireBullets(bullet)

        self.NextAttack = CurTime() + self.AttackCooldown
    end

    -- Проверка прямой видимости, игнорируя других неко
    function ENT:CanSee(target)
        local tr = util.TraceLine({
            start = self:GetShootPos(),
            endpos = target:EyePos(),
            filter = function(ent)
                -- Пропускаем самого стреляющего, цель и всех других неко
                if ent == self or ent == target or (ent.IsNecoArc) then
                    return false
                end
                return true
            end,
            mask = MASK_SHOT
        })
        return not tr.Hit
    end

    function ENT:OnTakeDamage(dmginfo)
        self.BaseClass.OnTakeDamage(self, dmginfo)
        if self:Health() <= 0 then
            local attacker = dmginfo:GetAttacker()
            if NAA_OnNecoKilled then
                NAA_OnNecoKilled(self, attacker)
            end
        end
    end

    function ENT:WhileAlive() end
end