AddCSLuaFile("shared.lua")
include("shared.lua")

if SERVER then
    local PACK_RADIUS = 300
    local MAX_PACK_BONUS = 0.40

    function ENT:CustomInitialize()
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
        
        -- 🎨 ПРАВИЛЬНЫЙ МЕТОД ОКРАШИВАНИЯ
        -- Шаг 1: Устанавливаем режим рендеринга, который заменяет текстуру цветом
        self:SetRenderMode(RENDERMODE_TRANSCOLOR)
        -- Шаг 2: Применяем нужный цвет
        self:SetColor(Color(100, 200, 255))
        
        self.NextPackCheck = 0
        self.PackBonus = 0
        self.BaseSpeed = self.RunSpeed
        self.NextMelee = 0
    end


    function ENT:BehaveStart()
        self.BehaveThread = coroutine.create(function() self:RunBehaviour() end)
    end

    function ENT:RunBehaviour()
        coroutine.wait(0.2)

        while true do
            local target = self:FindTarget()
            
            if IsValid(target) then
                self:FaceTowards(target)
                self:MoveToPos(target:GetPos())
                
                local dist = self:GetPos():Distance(target:GetPos())
                if dist <= self.MeleeAttackRange then
                    self:StopMoving()
                    self:TryMeleeAttack(target)
                end
            else
                self:StopMoving()
                coroutine.wait(1)
            end
            
            self:UpdatePackBonus()
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

    function ENT:UpdatePackBonus()
        local now = CurTime()
        if now < self.NextPackCheck then return end
        self.NextPackCheck = now + 0.5

        local cnt = 0
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), PACK_RADIUS)) do
            if IsValid(ent) and ent ~= self and ent.NecoType == "runner" then
                cnt = cnt + 1
                if cnt >= 4 then break end
            end
        end

        self.PackBonus = math.min(cnt * 0.10, MAX_PACK_BONUS)
        local newSpeed = self.BaseSpeed * (1 + self.PackBonus)
        self.loco:SetDesiredSpeed(newSpeed)
    end

    function ENT:StopMoving()
        self.loco:SetDesiredSpeed(0)
    end

    function ENT:FaceTowards(target)
        local dir = (target:GetPos() - self:GetPos()):GetNormalized()
        local ang = dir:Angle()
        self:SetAngles(Angle(0, ang.y, 0))
    end

    function ENT:TryMeleeAttack(target)
        if CurTime() < self.NextMelee then return end
        
        self:PlaySequence("melee_attack")
        self:EmitSound("weapons/stunstick/stunstick_swing" .. math.random(1,2) .. ".wav", 70)
        
        timer.Simple(0.2, function()
            if not IsValid(self) or not IsValid(target) then return end
            if self:GetPos():Distance(target:GetPos()) > self.MeleeAttackRange + 30 then return end
            
            local dmg = DamageInfo()
            dmg:SetDamage(self.MeleeDamage)
            dmg:SetAttacker(self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_CLUB)
            target:TakeDamageInfo(dmg)
            
            local kb = (target:GetPos() - self:GetPos()):GetNormalized() * 180
            kb.z = 80
            target:SetVelocity(kb)
        end)
        
        self.NextMelee = CurTime() + self.MeleeCooldown
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