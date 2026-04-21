-- ============================================================
--  NECO ARC APOCALYPSE — sv_upgrades.lua (SERVER)
--  ИСПРАВЛЕННАЯ ВЕРСИЯ
-- ============================================================

-- ============================================================
--  ПЕРЕСЧЁТ СКОРОСТИ — единственный источник правды
-- ============================================================
function NAA_RecalcSpeed(ply)
    if not IsValid(ply) then return end
    local pd = NAA.GetPD(ply)
    if not pd then return end

    local upg  = pd.upgrades or {}
    local cls  = NAA.Classes[pd.class or "survivor"]
    local base = cls.speed

    if (upg.fast_feet or 0) > 0 then
        base = base + 18 * upg.fast_feet          -- +18 к базовой за стак
    end
    if (upg.slippery or 0) > 0 then
        base = base * (1 + 0.30 * upg.slippery)   -- +30% за стак
    end
    if (upg.lightning or 0) > 0 then
        base = base * (1.6 ^ upg.lightning)        -- ×1.6 ^ стаков
    end

    ply:SetRunSpeed(base)
    ply:SetWalkSpeed(base * 0.55)
    ply.NAA_BaseSpeed = base
end

-- ============================================================
--  ПРИМЕНЕНИЕ АПГРЕЙДА
-- ============================================================
function NAA.ApplyUpgrade(ply, upgradeId)
    local upg = NAA.GetUpgrade(upgradeId)
    if not upg then return end

    local pd = NAA.GetPD(ply)
    if not pd then return end

    local currentStack = pd.upgrades[upgradeId] or 0
    if currentStack >= (upg.maxStacks or 1) then return end

    pd.upgrades[upgradeId] = currentStack + 1
    local stack = pd.upgrades[upgradeId]

    -- ── Немедленные эффекты ─────────────────────────────────

    if upgradeId == "medkit" then
        ply:SetHealth(math.min(ply:GetHealth() + 35, ply:GetMaxHealth()))

    elseif upgradeId == "armor_pack" then
        local newMax = math.min(ply:GetMaxArmor() + 30, 300)
        ply:SetMaxArmor(newMax)
        ply:SetArmor(math.min(ply:GetArmor() + 30, newMax))

    elseif upgradeId == "double_jump" then
        ply:SetNWInt("NAA_ExtraJumps", stack)

    elseif upgradeId == "ally_neco" then
        NAA_SpawnAllyNeco(ply, pd)

    elseif upgradeId == "drone" then
        if stack == 1 then
            pd.droneTimer = CurTime() + 28
        end

    elseif upgradeId == "last_chance" then
        pd.lastChanceUsed = false  -- свежий шанс при новой карточке

    elseif upgradeId == "apocalypse_card" then
        pd.apocalypseUsed = false

    elseif upgradeId == "shield" then
        pd.shieldBroken = false
        pd.shieldKills  = 0
        pd.shieldCD     = 0
    end

    NAA_RecalcSpeed(ply)

    -- ── Синергии ────────────────────────────────────────────
    local oldSyn = pd.synergies or {}
    pd.synergies = NAA.GetActiveSynergies(pd.upgrades, pd.class)

    for _, syn in ipairs(NAA.Synergies) do
        if pd.synergies[syn.id] and not oldSyn[syn.id] then
            net.Start("NAA_SynergyAlert")
                net.WriteString(syn.name)
                net.WriteString(syn.desc)
            net.Send(ply)
        end
    end

    NAA.SyncUpgrades(ply)
end

-- ============================================================
--  HUNTER STACKS SYNC
-- ============================================================
function NAA_SyncHunterStacks(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local pd = NAA.GetPD(ply)
    if not pd then return end
    pd.hunterStacks = type(pd.hunterStacks) == "number" and pd.hunterStacks or 0
    net.Start("NAA_HunterStacks")
        net.WriteInt(math.Clamp(math.floor(pd.hunterStacks), 0, 32767), 16)
    net.Send(ply)
end

-- ============================================================
--  ДРОН-КАМИКАДЗЕ
-- ============================================================
function NAA_FireDrone(ply, pd)
    if not IsValid(ply) then return end

    local nearest, nearDist = nil, math.huge
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and (ent.IsNecoArc or ent.IsNecoBoss or ent.IsMiniBoss) then
            local d = ply:GetPos():DistToSqr(ent:GetPos())
            if d < nearDist then nearDist = d; nearest = ent end
        end
    end
    if not IsValid(nearest) then return end

    local syn    = pd.synergies or {}
    local radius = syn.drone_killer and 300 or 150
    local dmg    = syn.drone_killer and 160 or 80
    local startPos = ply:GetPos() + Vector(0, 0, 64)
    local tgt = nearest

    local drone = ents.Create("prop_physics")
    if not IsValid(drone) then
        timer.Simple(1.5, function()
            if IsValid(tgt) then
                util.BlastDamage(ply, ply, tgt:GetPos(), radius, dmg)
                util.ScreenShake(tgt:GetPos(), 6, 8, 0.8, 400)
                local ed = EffectData(); ed:SetOrigin(tgt:GetPos()); ed:SetScale(2)
                util.Effect("explosion", ed, true, true)
            end
        end)
        return
    end

    drone:SetModel("models/props_junk/PopCan01a.mdl")
    drone:SetPos(startPos)
    drone:SetColor(Color(255, 140, 30))
    drone.IsDrone      = true
    drone.DroneTarget  = tgt
    drone.DroneDmg     = dmg
    drone.DroneRadius  = radius
    drone.DroneOwner   = ply
    drone:Spawn()
    drone:Activate()

    local phys = drone:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableGravity(false)
        phys:Wake()
    end

    local idx = drone:EntIndex()
    timer.Create("NAA_Drone_" .. idx, 0.04, 175, function()
        if not IsValid(drone) then
            timer.Remove("NAA_Drone_" .. idx); return
        end
        if not IsValid(drone.DroneTarget) then
            drone:Remove(); timer.Remove("NAA_Drone_" .. idx); return
        end
        local p = drone:GetPhysicsObject()
        if IsValid(p) then
            local dir = (drone.DroneTarget:GetPos() + Vector(0,0,32) - drone:GetPos()):GetNormalized()
            p:SetVelocity(dir * 950)
        end
        if drone:GetPos():Distance(drone.DroneTarget:GetPos()) < 90 then
            util.BlastDamage(drone.DroneOwner, drone.DroneOwner, drone:GetPos(), drone.DroneRadius, drone.DroneDmg)
            util.ScreenShake(drone:GetPos(), 6, 8, 0.8, 400)
            local ed = EffectData(); ed:SetOrigin(drone:GetPos()); ed:SetScale(drone.DroneRadius/60)
            util.Effect("explosion", ed, true, true)
            drone:Remove()
            timer.Remove("NAA_Drone_" .. idx)
        end
    end)

    timer.Simple(7, function()
        if IsValid(drone) then drone:Remove() end
        timer.Remove("NAA_Drone_" .. idx)
    end)

    net.Start("NAA_SpecialAlert")
        net.WriteString("🚀 Дрон запущен!")
    net.Send(ply)
end

-- ============================================================
--  СОЮЗНАЯ НЕКО
-- ============================================================
function NAA_SpawnAllyNeco(ply, pd)
    if not IsValid(ply) then return end

    local angle    = math.random() * math.pi * 2
    local spawnPos = ply:GetPos() + Vector(math.cos(angle)*80, math.sin(angle)*80, 0)
    local tr = util.TraceLine({
        start  = spawnPos + Vector(0,0,200),
        endpos = spawnPos - Vector(0,0,200),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    if tr.Hit then spawnPos = tr.HitPos + Vector(0,0,5) end

    local ally = ents.Create("npc_citizen")
    if not IsValid(ally) then return end

    local mdl = util.IsValidModel("models/npc/nekoarc.mdl")
        and "models/npc/nekoarc.mdl" or "models/player/kleiner.mdl"

    ally:SetModel(mdl)
    ally:SetPos(spawnPos)
    ally:SetMaxHealth(150)
    ally:SetHealth(150)
    ally.IsAllyNeco = true
    ally.NecoOwner  = ply
    ally:Spawn()
    ally:Activate()
    ally:SetColor(Color(255, 160, 210))
    ally:Give("weapon_smg1")
    ally:SetNWString("NAA_AllyName", "❤ Неко (" .. ply:Nick() .. ")")

    for _, p in player.Iterator() do
        ally:AddEntityRelationship(p, D_LI, 99)
    end
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and (ent.IsNecoArc or ent.IsNecoBoss or ent.IsMiniBoss) then
            ally:AddEntityRelationship(ent, D_HT, 99)
        end
    end
end

-- ============================================================
--  ВРЕМЕННОЙ ПУЗЫРЬ
-- ============================================================
function NAA_ActivateTimeBubble(ply)
    if not IsValid(ply) then return end
    local pd = NAA.GetPD(ply)
    if not pd then return end

    local stack = (pd.upgrades or {}).time_bubble or 0
    if stack <= 0 then return end

    local now = CurTime()
    if (pd.timeBubbleCD or 0) > now then
        net.Start("NAA_SpecialAlert")
            net.WriteString("⏱ КД: " .. math.ceil(pd.timeBubbleCD - now) .. "с")
        net.Send(ply)
        return
    end

    pd.timeBubbleCD = now + 18
    local affected  = 0
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 300)) do
        if IsValid(ent) and (ent.IsNecoArc or ent.IsNecoBoss or ent.IsMiniBoss) then
            ent.NecoSlowed      = true
            ent.NecoSlowExpires = now + 4
            affected = affected + 1
        end
    end
    net.Start("NAA_SpecialAlert")
        net.WriteString("⏱ Временной пузырь! (" .. affected .. " врагов)")
    net.Send(ply)
end

-- ============================================================
--  ТИКИ ИГРОКА
-- ============================================================
local _upgradeTicksStarted = false
hook.Add("PostGamemodeLoaded", "NAA_UpgradeTicksInit", function()
    if _upgradeTicksStarted then return end
    _upgradeTicksStarted = true
    timer.Remove("NAA_PlayerFastTick")
    timer.Remove("NAA_PlayerSlowTick")
    timer.Remove("NAA_AllyNecoTick")

    -- Быстрый тик: флаги временных эффектов
    timer.Create("NAA_PlayerFastTick", 0.1, 0, function()
        local now = CurTime()
        for _, ply in player.Iterator() do
            if not IsValid(ply) or not ply:Alive() then continue end
            local pd = NAA.GetPD(ply)
            if not pd then continue end

            if pd.adrenalineActive and pd.adrenalineExpires <= now then
                pd.adrenalineActive = false
                NAA_RecalcSpeed(ply)
            end
            if pd.counterRushActive and pd.counterRushExpires <= now then
                pd.counterRushActive = false
                NAA_RecalcSpeed(ply)
            end
            if pd.ghostStepActive and (pd.ghostStepExpires or 0) <= now then
                pd.ghostStepActive = false
            end
            if pd.immortalityActive and (pd.immortalityExpires or 0) <= now then
                pd.immortalityActive = false
            end
        end
    end)

    -- Медленный тик: реген, бессмертие, дроны, медик
    timer.Create("NAA_PlayerSlowTick", 1, 0, function()
        local now = CurTime()
        for _, ply in player.Iterator() do
            if not IsValid(ply) or not ply:Alive() then continue end
            local pd  = NAA.GetPD(ply)
            if not pd then continue end
            local upg = pd.upgrades or {}
            local syn = pd.synergies or {}

            -- Регенерация
            if (upg.regen or 0) > 0 then
                local heal = syn.lifesteal_regen
                    and (2.0 * upg.regen)
                    or  (upg.regen * (1/3))
                ply:SetHealth(math.min(ply:GetHealth() + heal, ply:GetMaxHealth()))
            end

            -- Бессмертие при низком HP
            if (upg.immortality or 0) > 0 and not pd.immortalityActive then
                local hpPct = ply:Health() / math.max(ply:GetMaxHealth(), 1)
                if hpPct < 0.2 and (pd.immortalityCD or 0) <= now then
                    pd.immortalityCD     = now + 55
                    pd.immortalityActive = true
                    pd.immortalityExpires = now + 4 * upg.immortality
                    net.Start("NAA_SpecialAlert")
                        net.WriteString("🛡 Бессмертие!")
                    net.Send(ply)
                end
            end

            -- Щит: восстановление по таймеру
            if (upg.shield or 0) > 0 and pd.shieldBroken and not syn.regen_shield then
                if (pd.shieldCD or 0) <= now then
                    pd.shieldBroken = false
                    pd.shieldKills  = 0
                    net.Start("NAA_SpecialAlert")
                        net.WriteString("🛡 Щит восстановлен!")
                    net.Send(ply)
                end
            end

            -- Дрон
            if (upg.drone or 0) > 0 then
                local delay = syn.drone_killer and 20 or 28
                if (pd.droneTimer or 0) <= now then
                    pd.droneTimer = now + delay
                    NAA_FireDrone(ply, pd)
                end
            end

            -- Медик: аура
            if pd.class == "medic" then
                for _, other in player.Iterator() do
                    if IsValid(other) and other ~= ply and other:Alive() then
                        if other:GetPos():Distance(ply:GetPos()) < 350 then
                            other:SetHealth(math.min(other:GetHealth() + 2, other:GetMaxHealth()))
                        end
                    end
                end
            end
        end
    end)

    -- Тик союзных Неко
    timer.Create("NAA_AllyNecoTick", 5, 0, function()
        for _, ply in player.Iterator() do
            if not IsValid(ply) or not ply:Alive() then continue end
            local pd    = NAA.GetPD(ply)
            if not pd then continue end
            local stack = (pd.upgrades or {}).ally_neco or 0
            if stack <= 0 then continue end

            local maxAlly = (pd.synergies or {}).army and 2 or 1
            local count   = 0
            for _, ent in ipairs(ents.GetAll()) do
                if IsValid(ent) and ent.IsAllyNeco and ent.NecoOwner == ply then
                    count = count + 1
                end
            end
            while count < maxAlly do
                NAA_SpawnAllyNeco(ply, pd)
                count = count + 1
            end
        end
    end)
end)

-- ============================================================
--  МАГНИТ
-- ============================================================
timer.Create("NAA_MagnetTick", 0.2, 0, function()
    for _, ply in player.Iterator() do
        if not IsValid(ply) or not ply:Alive() then continue end
        local pd  = NAA.GetPD(ply)
        if not pd then continue end
        local upg = pd.upgrades or {}
        local syn = pd.synergies or {}
        local mag = upg.magnet or 0
        if mag <= 0 and not syn.lucky_magnet then continue end

        local radius = 280 * (1 + mag * 0.15)
        for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), radius)) do
            if not IsValid(ent) then continue end
            local cls    = ent:GetClass()
            local isItem = cls == "item_healthkit" or cls == "item_battery"
            local isWep  = cls:find("weapon_") ~= nil
            local isCoin = ent.IsNecoMoney == true
            if isItem or isWep or (syn.lucky_magnet and isCoin) then
                local dir  = (ply:GetPos() - ent:GetPos()):GetNormalized()
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then phys:SetVelocity(dir * 350) end
            end
        end
    end
end)

-- ============================================================
--  СИНЕРГИЯ ЗАРАЗА: яд перепрыгивает
-- ============================================================
timer.Create("NAA_PlagueTick", 2, 0, function()
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) or not ent.NecoPoisoned then continue end
        local owner = ent.NecoPoisonAttacker
        if not IsValid(owner) or not owner:IsPlayer() then continue end
        local pd = NAA.GetPD(owner)
        if not pd or not (pd.synergies or {}).plague then continue end

        for _, nearby in ipairs(ents.FindInSphere(ent:GetPos(), 200)) do
            if IsValid(nearby) and (nearby.IsNecoArc or nearby.IsNecoBoss)
                and nearby ~= ent and not nearby.NecoPoisoned then
                nearby.NecoPoisoned       = true
                nearby.NecoPoisonDmg      = ent.NecoPoisonDmg or 3
                nearby.NecoPoisonExpires  = CurTime() + 4
                nearby.NecoPoisonAttacker = owner
            end
        end
    end
end)

-- ============================================================
--  ХУК: УБИЙСТВО NPC — вторичные эффекты
-- ============================================================
hook.Add("OnNPCKilled", "NAA_UpgradeKillExtras", function(npc, attacker, inflictor)
    if not IsValid(npc) then return end
    if not IsValid(attacker) or not attacker:IsPlayer() then return end

    timer.Simple(0, function()
        if not IsValid(attacker) then return end

        local pd  = NAA.GetPD(attacker)
        if not pd then return end
        local upg = pd.upgrades or {}
        local syn = pd.synergies or {}
        local now = CurTime()
        local pos = IsValid(npc) and npc:GetPos() or attacker:GetPos()

        -- Адреналин
        if (upg.adrenaline or 0) > 0 then
            local cls  = NAA.Classes[pd.class or "survivor"]
            local base = attacker.NAA_BaseSpeed or cls.speed
            local mult = syn.sprinter and 2.2 or (1 + 0.20 * upg.adrenaline)
            attacker:SetRunSpeed(base * mult)
            pd.adrenalineActive  = true
            pd.adrenalineExpires = now + 4
        end

        -- Regen Shield
        if syn.regen_shield and (upg.shield or 0) > 0 and pd.shieldBroken then
            pd.shieldKills = (pd.shieldKills or 0) + 1
            if pd.shieldKills >= 5 then
                pd.shieldKills  = 0
                pd.shieldBroken = false
                net.Start("NAA_SpecialAlert")
                    net.WriteString("🛡 Щит восстановлен (5 убийств)!")
                net.Send(attacker)
            end
        end

        -- МОР
        if syn.plague_death and (upg.death_curse or 0) > 0
            and IsValid(npc) and npc.NecoPoisoned then
            local poisonDmg = (upg.poison or 1) * 3
            for _, nearby in ipairs(ents.FindInSphere(pos, 120)) do
                if IsValid(nearby) and (nearby.IsNecoArc or nearby.IsNecoBoss)
                    and nearby ~= npc and not nearby.NecoPoisoned then
                    nearby.NecoPoisoned       = true
                    nearby.NecoPoisonDmg      = poisonDmg
                    nearby.NecoPoisonExpires  = now + 4
                    nearby.NecoPoisonAttacker = attacker
                end
            end
        end
    end)
end)

-- ============================================================
--  ХУК: УРОН ИГРОКА — вторичные эффекты
-- ============================================================
hook.Add("EntityTakeDamage", "NAA_UpgradePlayerDefense", function(ent, dmginfo)
    if not IsValid(ent) or not ent:IsPlayer() then return end

    local pd = NAA.GetPD(ent)
    if not pd then return end
    local upg = pd.upgrades or {}
    local now = CurTime()

    if pd.devGodMode then
        dmginfo:SetDamage(0)
        return true
    end

    -- Адаптация
    if (upg.adaptation or 0) > 0 and dmginfo:GetDamage() > 0 then
        if not pd.adaptResist then pd.adaptResist = {} end
        local dtype   = tostring(dmginfo:GetDamageType())
        local current = pd.adaptResist[dtype] or 0
        local newRes  = math.min(current + 0.05 * upg.adaptation, 0.40)
        pd.adaptResist[dtype] = newRes
        if newRes > 0 then
            dmginfo:ScaleDamage(1 - newRes)
        end
    end

    -- Контратака
    if (upg.counter_rush or 0) > 0 and dmginfo:GetDamage() > 0 then
        local cls  = NAA.Classes[pd.class or "survivor"]
        local base = ent.NAA_BaseSpeed or cls.speed
        ent:SetRunSpeed(base * (1 + 0.40 * upg.counter_rush))
        pd.counterRushActive  = true
        pd.counterRushExpires = now + 2
    end
end)

-- ============================================================
--  ХУК: ДВОЙНОЙ ПРЫЖОК
-- ============================================================
hook.Add("OnPlayerJump", "NAA_DoubleJump", function(ply, hindered)
    local pd = NAA.GetPD(ply)
    if not pd then return end

    local extra = ply:GetNWInt("NAA_ExtraJumps", 0)
    if extra <= 0 then return end
    if ply:IsOnGround() then pd.airJumpsUsed = 0; return end

    if (pd.airJumpsUsed or 0) < extra then
        pd.airJumpsUsed = (pd.airJumpsUsed or 0) + 1
        local vel  = ply:GetVelocity(); vel.z = 320
        ply:SetVelocity(vel)

        if (pd.synergies or {}).acrobat and (pd.upgrades.dash or 0) > 0 then
            local fwd = ply:GetAimVector(); fwd.z = 0
            if fwd:Length() > 0.01 then
                fwd:Normalize()
                ply:SetVelocity(ply:GetVelocity() + fwd * 500)
            end
        end
    end
end)

hook.Add("OnPlayerHitGround", "NAA_ResetAirJumps", function(ply)
    local pd = NAA.GetPD(ply)
    if pd then pd.airJumpsUsed = 0 end
end)

-- ============================================================
--  ХУК: РЫВОК (Shift + W)
-- ============================================================
hook.Add("KeyPress", "NAA_Dash", function(ply, key)
    if key ~= IN_SPEED then return end
    local pd = NAA.GetPD(ply)
    if not pd then return end
    local stack = (pd.upgrades or {}).dash or 0
    if stack <= 0 then return end
    if not ply:KeyDown(IN_FORWARD) then return end

    local now = CurTime()
    local cd  = 8 / stack
    if (pd.dashCD or 0) > now then return end
    pd.dashCD = now + cd

    local fwd = ply:GetAimVector(); fwd.z = 0
    if fwd:Length() < 0.01 then fwd = ply:GetForward() end
    fwd:Normalize()
    ply:SetVelocity(fwd * 700)

    net.Start("NAA_SpecialAlert")
        net.WriteString("💨 Рывок!")
    net.Send(ply)
end)

-- ============================================================
--  SHARP EYE: уменьшение разброса
-- ============================================================
hook.Add("EntityFireBullets", "NAA_SharpEyeSpread", function(ent, data)
    if not SERVER then return end
    if not IsValid(ent) or not ent:IsPlayer() then return end
    local pd    = NAA.GetPD(ent)
    if not pd then return end
    local stack = (pd.upgrades or {}).sharp_eye or 0
    if stack <= 0 then return end
    data.Spread = data.Spread * math.max(1 - 0.05 * stack, 0.3)
end)

-- ============================================================
--  FAST TRIGGER: снижение задержки выстрела
-- ============================================================
hook.Add("EntityFireBullets", "NAA_FastTrigger", function(ent, data)
    if not SERVER then return end
    if not IsValid(ent) or not ent:IsPlayer() then return end
    local pd    = NAA.GetPD(ent)
    if not pd then return end
    local stack = (pd.upgrades or {}).fast_trigger or 0
    if stack <= 0 then return end

    local syn = pd.synergies or {}
    local hpPct = ent:Health() / math.max(ent:GetMaxHealth(), 1)
    local reduction = 0.15 * stack
    if syn.berserker_rush and pd.class == "berserker" and hpPct < 0.5 then
        reduction = reduction * 2
    end

    local wep = ent:GetActiveWeapon()
    if IsValid(wep) then
        timer.Simple(0, function()
            if IsValid(wep) then
                local nf = wep:GetNextPrimaryFire()
                wep:SetNextPrimaryFire(math.max(nf - reduction, CurTime() + 0.02))
            end
        end)
    end
end)