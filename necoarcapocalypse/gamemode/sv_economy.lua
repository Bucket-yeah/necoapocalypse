-- ============================================================
--  NECO ARC APOCALYPSE — sv_economy.lua (SERVER)
-- ============================================================

local ItemDropTable = {
    { class="item_healthkit", weight=50 },
    { class="item_battery",   weight=35 },
    { class="weapon_pistol",  weight=10 },
    { class="weapon_smg1",    weight=5  },
}

function NAA_TryDropItem(pos, diff, attacker)
    local baseChance = 0.10 * diff.itemChanceMult
    
    if IsValid(attacker) and attacker:IsPlayer() then
        local pd = NAA.GetPD(attacker)
        if pd and (pd.upgrades.lucky or 0) > 0 then
            baseChance = baseChance * (1 + 0.15 * pd.upgrades.lucky)
        end
        if pd and (pd.synergies or {}).lucky_magnet then
            baseChance = baseChance * 1.4
        end
    end

    if math.random() > baseChance then return end

    local total = 0
    for _, v in ipairs(ItemDropTable) do total = total + v.weight end
    local roll = math.random() * total
    local selected = ItemDropTable[1].class
    for _, v in ipairs(ItemDropTable) do
        roll = roll - v.weight
        if roll <= 0 then selected = v.class break end
    end

    local ent = ents.Create(selected)
    if IsValid(ent) then
        ent:SetPos(pos + Vector(0, 0, 20))
        ent:Spawn()
        ent:Activate()
        timer.Simple(30, function()
            if IsValid(ent) then ent:Remove() end
        end)
    end
end

function NAA_AddCoins(ply, amount)
    if not IsValid(ply) then return end
    local pd = NAA.GetPD(ply)
    pd.coins = (pd.coins or 0) + amount
    net.Start("NAA_SyncCoins")
        net.WriteInt(pd.coins, 16)
    net.Send(ply)
end

function NAA_SpendCoins(ply, amount)
    if not IsValid(ply) then return false end
    local pd = NAA.GetPD(ply)
    if (pd.coins or 0) < amount then return false end
    pd.coins = pd.coins - amount
    net.Start("NAA_SyncCoins")
        net.WriteInt(pd.coins, 16)
    net.Send(ply)
    return true
end

local ShopItems = {
    hp50 = { name="+50 HP", cost=8, fn=function(ply) ply:SetHealth(math.min(ply:GetHealth()+50, ply:GetMaxHealth())) end },
    armor50 = { name="+50 Armor", cost=6, fn=function(ply) ply:SetArmor(math.min(ply:GetArmor()+50, 100)) end },
    ammo = { name="All ammo", cost=4, fn=function(ply)
        ply:GiveAmmo(120,"SMG1") ply:GiveAmmo(16,"Buckshot") ply:GiveAmmo(60,"Pistol") ply:GiveAmmo(30,"AR2")
    end},
    weapon = { name="Random weapon", cost=10, fn=function(ply)
        local weps = {"weapon_smg1","weapon_shotgun","weapon_ar2","weapon_crossbow"}
        ply:Give(weps[math.random(#weps)])
    end},
}

net.Receive("NAA_BuyShop", function(len, ply)
    if NAA.Phase ~= NAA.PHASE_BETWEEN_WAVES then return end
    local itemId = net.ReadString()
    local item = ShopItems[itemId]
    if not item then return end
    if not NAA_SpendCoins(ply, item.cost) then return end
    item.fn(ply)
    net.Start("NAA_BetweenWave")
        net.WriteString("Bought: " .. item.name)
    net.Send(ply)
end)