AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    -- Локальные ссылки на глобальные функции NAA
    local function AddCoins(ply, amt) NAA_AddCoins(ply, amt) end
    local function AddNeoCoins(ply, amt) NAA.AddNeoCoins(ply, amt) end
    local function GetDiff(diff) return NAA.GetDiff(diff) end
    local function PickCards(bonus, upgs) return NAA.PickCards(bonus, upgs) end
    local function GetPD(ply) return NAA.GetPD(ply) end
    local function ApplyUpgrade(ply, id) NAA.ApplyUpgrade(ply, id) end
    local function GetUpgrade(id) return NAA.GetUpgrade(id) end

    local REWARDS = {
        {"coins", 25, 10, 30, function(ply)
            local amt = math.random(10,30)
            AddCoins(ply, amt)
            timer.Simple(0, function()
                if IsValid(ply) then
                    net.Start("NAA_BetweenWave")
                    net.WriteString("+" .. amt .. " монет!")
                    net.Send(ply)
                end
            end)
        end},
        {"ammo_random", 35, nil, nil, function(ply)
            local wepTypes = {"SMG1", "Buckshot", "Pistol", "AR2", "XBowBolt"}
            local t = wepTypes[math.random(#wepTypes)]
            ply:GiveAmmo(math.random(10,30), t)
            timer.Simple(0, function()
                if IsValid(ply) then
                    net.Start("NAA_BetweenWave")
                    net.WriteString("Патроны: " .. t)
                    net.Send(ply)
                end
            end)
        end},
        {"ammo_all", 15, nil, nil, function(ply)
            ply:GiveAmmo(30, "SMG1") ply:GiveAmmo(8, "Buckshot")
            ply:GiveAmmo(20, "Pistol") ply:GiveAmmo(15, "AR2") ply:GiveAmmo(2, "XBowBolt")
            timer.Simple(0, function()
                if IsValid(ply) then
                    net.Start("NAA_BetweenWave")
                    net.WriteString("Патроны для всего оружия!")
                    net.Send(ply)
                end
            end)
        end},
        {"neocoins", 10, 1, 5, function(ply)
            local amt = math.random(1,5)
            AddNeoCoins(ply, amt)
            timer.Simple(0, function()
                if IsValid(ply) then
                    net.Start("NAA_BetweenWave")
                    net.WriteString("+" .. amt .. " Нео-монет!")
                    net.Send(ply)
                end
            end)
        end},
        {"weapon", 8, nil, nil, function(ply)
            local weps = {"weapon_smg1","weapon_shotgun","weapon_ar2","weapon_crossbow","weapon_rpg"}
            local w = weps[math.random(#weps)]
            ply:Give(w)
            timer.Simple(0, function()
                if IsValid(ply) then
                    net.Start("NAA_BetweenWave")
                    net.WriteString("Оружие: " .. w)
                    net.Send(ply)
                end
            end)
        end},
        {"card", 5, nil, nil, function(ply)
            local diff = GetDiff(NAA.Difficulty)
            local cards = PickCards(diff.rareBonus, GetPD(ply).upgrades)
            if cards and #cards > 0 then
                local chosen = cards[math.random(#cards)]
                ApplyUpgrade(ply, chosen)
                local upg = GetUpgrade(chosen)
                timer.Simple(0, function()
                    if IsValid(ply) then
                        net.Start("NAA_BetweenWave")
                        net.WriteString("Получено улучшение: " .. (upg and upg.name or chosen))
                        net.Send(ply)
                    end
                end)
            end
        end},
        {"kamikaze", 2, nil, nil, function(ply)
            local spawnPos = ply:GetPos() + Vector(math.random(-100,100), math.random(-100,100), 0)
            local e = ents.Create("neco_kamikaze")
            if IsValid(e) then e:SetPos(spawnPos); e:Spawn(); e:Activate() end
            timer.Simple(0, function()
                if IsValid(ply) then
                    net.Start("NAA_BetweenWave")
                    net.WriteString("О нет! Камикадзе!")
                    net.Send(ply)
                end
            end)
        end},
    }

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetColor(self.CrateColor)
        self:SetUseType(SIMPLE_USE)
        self:SetHealth(9999)
        self:SetNWBool("Used", false)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end

        self.Lifetime = CurTime() + 45
    end

    function ENT:Think()
    if self:GetNWBool("Used", false) then
        self:Remove()
        return
    end
    if CurTime() > self.Lifetime then
        -- Ящик исчезает по таймеру
        net.Start("NAA_BetweenWave")
            net.WriteString("О нет! Ящик снабжения сгорел!")
        net.Broadcast()
        self:Remove()
        return
    end
end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        if self:GetNWBool("Used", false) then return end
        self:SetNWBool("Used", true)

        local total = 0
        for _, v in ipairs(REWARDS) do total = total + v[2] end
        local r = math.random() * total
        local reward = REWARDS[1]
        for _, v in ipairs(REWARDS) do
            r = r - v[2]
            if r <= 0 then reward = v break end
        end

        reward[5](activator)
        self:EmitSound("buttons/button9.wav")
        self:Remove()
    end
end