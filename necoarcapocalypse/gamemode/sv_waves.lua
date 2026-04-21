-- ============================================================
--  NECO ARC APOCALYPSE — sv_waves.lua (SERVER)
--  ФИНАЛЬНАЯ СТАБИЛЬНАЯ ВЕРСИЯ (исправлена ошибка GetHealth)
-- ============================================================

util.AddNetworkString("NAA_BetweenWaveTimer")

local NECO_MODEL = "models/npc/nekoarc.mdl"

local EnemyTypes = NAA.EnemyTypes

local DeathSounds = {
    "infection/neco/death1.mp3","infection/neco/death2.mp3","infection/neco/death3.mp3",
    "infection/neco/pain1.mp3","infection/neco/pain2.mp3","infection/neco/pain3.mp3",
}
local HurtSounds  = { "infection/neco/pain1.mp3","infection/neco/pain2.mp3","infection/neco/pain3.mp3" }
local SpawnSounds = { "infection/neco/buranya.mp3","infection/neco/dori.mp3" }

NAA.WaveSpawning = false
NAA.ShotCounter  = NAA.ShotCounter or {}

-- ============================================================
--  ПОИСК ПОЗИЦИИ ДЛЯ СПАВНА
-- ============================================================
local function FindSpawnPos(ply)
    if not IsValid(ply) then return nil end
    local plyPos = ply:GetPos()
    local areas = navmesh.Find(plyPos, 3500, 128, 128)
    local pool  = {}
    if areas then
        local plyEye = ply:EyePos()
        for _, v in ipairs(areas) do
            if IsValid(v) then
                local apos = v:GetCenter()
                local dist = plyPos:Distance(apos)
                if dist > 600 and dist < 3200 and not v:IsVisible(plyEye) then
                    pool[#pool+1] = apos
                end
            end
        end
    end
    if #pool == 0 then
        for i = 1, 16 do
            local angle = math.random() * 360
            local dist  = math.random(800, 2000)
            pool[#pool+1] = plyPos + Vector(math.cos(math.rad(angle))*dist, math.sin(math.rad(angle))*dist, 0)
        end
    end
    for attempt = 1, math.min(8, #pool) do
        local idx = math.random(#pool)
        local candidate = pool[idx]
        table.remove(pool, idx)
        local trDown = util.TraceLine({ start=candidate+Vector(0,0,500), endpos=candidate+Vector(0,0,-500), mask=MASK_SOLID_BRUSHONLY })
        if trDown.Hit and not trDown.StartSolid then
            local spawnPos = trDown.HitPos + Vector(0,0,32)
            local trUp = util.TraceLine({ start=spawnPos, endpos=spawnPos+Vector(0,0,72), mask=MASK_SOLID })
            if not trUp.Hit then
                local trAir = util.TraceLine({ start=spawnPos+Vector(0,0,36), endpos=spawnPos+Vector(0,0,36), mask=MASK_SOLID })
                if not trAir.StartSolid then return spawnPos end
            end
        end
    end
    if NAA.DebugMode then print("[NAA] WARN: Could not find safe spawn position, using fallback") end
    return plyPos + Vector(math.random(-200,200), math.random(-200,200), 10)
end

-- ============================================================
--  НАСТРОЙКА AI
-- ============================================================
local function SetupNPCChase(npc)
    if not IsValid(npc) then return end
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            pcall(function() npc:AddEntityRelationship(ply, D_HT, 99) end)
        end
    end
    pcall(function() npc:SetNPCState(NPC_STATE_ALERT) end)
end

-- ============================================================
--  ЗАМЕДЛЕНИЕ ДЛЯ TIME BUBBLE
-- ============================================================
hook.Add("Think", "NAA_TimeBubbleSlow", function()
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent.IsNecoArc and ent.NecoSlowed then
            if CurTime() <= (ent.NecoSlowExpires or 0) then
                local vel = ent:GetVelocity()
                ent:SetVelocity(vel * 0.5)
            else
                ent.NecoSlowed = false
            end
        end
    end
end)

local function ScheduleCorpseCleanup(npc)
    timer.Simple(8, function() if IsValid(npc) then npc:Remove() end end)
end

-- ============================================================
--  ГЛОБАЛЬНЫЙ КОЛБЭК СМЕРТИ
-- ============================================================
function NAA_OnNecoKilled(npc, attacker)
    if not IsValid(npc) then return end
    if npc.NAAKillHandled then return end
    npc.NAAKillHandled = true

    local pos  = npc:GetPos()
    local diff = NAA.GetDiff(NAA.Difficulty)

    NAA.AliveEnemies = math.max((NAA.AliveEnemies or 1) - 1, 0)
    npc:EmitSound(DeathSounds[math.random(#DeathSounds)], 100)

    timer.Simple(0.05, function()
        for _, ent in ipairs(ents.FindInSphere(pos, 80)) do
            if IsValid(ent) and ent:GetClass():find("weapon_") and not IsValid(ent:GetOwner()) then
                ent:Remove()
            end
        end
    end)

    NAA_TryDropItem(pos, diff, attacker)

    if IsValid(NAA.ActiveBoss) and NAA.ActiveBoss == npc then NAA.ActiveBoss = nil end

    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    local pd = NAA.GetPD(attacker)
    if not pd then return end

    pcall(function()
        pd.kills = (pd.kills or 0) + 1
        local necoType = npc:GetNWString("NecoType", "normal")

        local coins = 1
        if necoType == "tank"         then coins = 3 end
        if necoType == "neco_sniper" or necoType == "neco_summoner" then coins = 4 end
        if npc.IsMiniBoss             then coins = 8 end
        if npc.IsNecoBoss             then coins = 15 end
        if (pd.upgrades.coin_rain or 0) > 0 then coins = coins + math.floor(0.5 * pd.upgrades.coin_rain) end
        NAA_AddCoins(attacker, math.floor(coins))

        net.Start("NAA_KillFeed")
            net.WriteString(attacker:Nick())
            net.WriteString(necoType)
        net.Broadcast()

        if pd.class == "berserker" then
            attacker:SetHealth(math.min(attacker:GetHealth() + 4, attacker:GetMaxHealth()))
        end
        if pd.class == "hunter" then
            pd.hunterStacks  = math.min((pd.hunterStacks  or 0) + 1, 50)
            pd.hunterStreak  = (pd.hunterStreak  or 0) + 1
            pd.nextIsOneshot = pd.hunterStreak >= 10
            if pd.hunterStreak >= 10 then
                pd.hunterStreak  = 0
                pd.nextIsOneshot = true
                net.Start("NAA_SpecialAlert")
                    net.WriteString("🎯 ВАНШОТ ГОТОВ! (серия 10)")
                net.Send(attacker)
            end
            NAA_SyncHunterStacks(attacker)
        end

        local vamp = pd.upgrades.vampirism or 0
        if vamp > 0 then
            local heal = vamp * 2
            if (pd.synergies or {}).lifesteal_regen then heal = 5 + (3 * (vamp - 1)) end
            attacker:SetHealth(math.min(attacker:GetHealth() + heal, attacker:GetMaxHealth()))
        end

        if (pd.upgrades.death_curse or 0) > 0 then
            local dmg = 15 * pd.upgrades.death_curse
            for _, ent in ipairs(ents.FindInSphere(pos, 120)) do
                if IsValid(ent) and ent.IsNecoArc then
                    timer.Simple(0, function()
                        if IsValid(ent) then
                            ent:TakeDamage(dmg, attacker, attacker)
                        end
                    end)
                end
            end
        end

        if IsValid(attacker) then
            NAA_CheckStreak(attacker, pd)
        end

        if (pd.synergies or {}).regen_shield then
            pd.shieldKills = (pd.shieldKills or 0) + 1
            if pd.shieldKills >= 5 then pd.shieldKills = 0 pd.shieldBroken = false end
        end

        if (pd.upgrades.adrenaline or 0) > 0 then
            local mult = (pd.synergies or {}).sprinter and 2.2 or (1 + 0.20 * pd.upgrades.adrenaline)
            local cls  = NAA.Classes[pd.class or "survivor"]
            attacker:SetRunSpeed(cls.speed * mult)
            attacker:SetWalkSpeed(cls.speed * mult * 0.55)
            timer.Create("NAA_AdrenStop_"..attacker:EntIndex(), 4, 1, function()
                if IsValid(attacker) then NAA_RecalcSpeed(attacker) end
            end)
        end

        NAA.SyncUpgrades(attacker)
    end)
end

-- ============================================================
--  СПАВН МИНИБОССА
-- ============================================================
local function SpawnMiniBoss(pos, wave, diff, mbData)
    local ent = ents.Create(mbData.class)
    if not IsValid(ent) then
        print("[NAA] ERROR: Failed to create miniboss " .. mbData.class)
        return nil
    end
    ent:SetPos(pos)
    ent.IsNecoArc  = true
    ent.IsMiniBoss = true
    ent.NAAWave    = wave
    ent.NAADiff    = diff
    ent:Spawn()
    ent:Activate()
    local finalHP = math.ceil(mbData.hp * diff.hpMult)
    ent:SetMaxHealth(finalHP)
    ent:SetHealth(finalHP)
    ent:SetModelScale(mbData.scale)
    ent:SetColor(mbData.color)
    ent:SetNWString("NecoType", mbData.class)
    ent:SetNWInt("NecoMaxHP", finalHP)
    sound.Play(SpawnSounds[math.random(#SpawnSounds)], pos)
    NAA.AliveEnemies = (NAA.AliveEnemies or 0) + 1
    SetupNPCChase(ent)
    net.Start("NAA_SpecialAlert")
        net.WriteString("Появился " .. mbData.name .. "!")
    net.Broadcast()
    print("[NAA] Miniboss spawned: " .. mbData.class .. " HP=" .. finalHP)
    return ent
end

-- ============================================================
--  СПАВН ОДНОГО ВРАГА
-- ============================================================
local function SpawnEnemy(pos, wave, eventID, pool, diff)
    local total = 0
    for _, e in ipairs(pool) do total = total + e.weight end
    local roll = math.random() * total
    local pick = pool[1]
    for _, e in ipairs(pool) do
        roll = roll - e.weight
        if roll <= 0 then pick = e break end
    end
    if not pick then return end

    if pick.source == "miniboss" then
        return SpawnMiniBoss(pos, wave, diff, pick.mbData)
    end

    if pick.source == "special" then
        local ent = ents.Create(pick.class)
        if not IsValid(ent) then print("[NAA] ERROR: Failed to create " .. pick.class) return end
        ent:SetPos(pos)
        ent.IsNecoArc     = true
        ent.IsNecoSpecial = true
        ent.NAAWave       = wave
        ent.NAADiff       = diff
        ent:Spawn()
        ent:Activate()
        ent:SetNWString("NecoType", pick.class)
        sound.Play(SpawnSounds[math.random(#SpawnSounds)], pos)
        NAA.AliveEnemies = (NAA.AliveEnemies or 0) + 1
        SetupNPCChase(ent)
        return ent
    end

    local typeName = pick.typeName
    local data = EnemyTypes[typeName]
    if not data then return end

    local entClass = "neco_" .. typeName
    local npc = ents.Create(entClass)
    if not IsValid(npc) then
        print("[NAA] ERROR: Entity class not found: '" .. entClass .. "'")
        return
    end

    npc:SetPos(pos)
    npc.IsNecoArc = true
    npc.NecoType  = typeName
    npc.NAAWave   = wave
    npc.NAADiff   = diff
    npc:Spawn()
    npc:Activate()

    local hp = math.max(1, math.ceil(data.hp * diff.hpMult))
    npc:SetHealth(hp)
    npc:SetMaxHealth(hp)
    npc:SetNWInt("NecoMaxHP", hp)
    npc:SetNWString("NecoType", typeName)

    sound.Play(SpawnSounds[math.random(#SpawnSounds)], pos)
    NAA.AliveEnemies = (NAA.AliveEnemies or 0) + 1
    SetupNPCChase(npc)
    return npc
end

-- ============================================================
--  ВЫБОР СОБЫТИЯ ВОЛНЫ
-- ============================================================
local function GetAvailableWaveEvents(wave)
    local available = {}
    for _, ev in ipairs(NAA.WaveEvents) do
        local ok = true
        if ev.id == "healers" then
            local healerType = NAA.EnemyTypes["healer"]
            if not healerType or wave < (healerType.unlockWave or 1) then ok = false end
        elseif ev.id == "armored" then
            local armoredType = NAA.EnemyTypes["armored"]
            if not armoredType or wave < (armoredType.unlockWave or 1) then ok = false end
        elseif ev.id == "kamikaze" then
            local kamikazeType = NAA.EnemyTypes["kamikaze"]
            if not kamikazeType or wave < (kamikazeType.unlockWave or 1) then ok = false end
        elseif ev.id == "ghost" then
            local ghostType = NAA.EnemyTypes["ghost"]
            if not ghostType or wave < (ghostType.unlockWave or 1) then ok = false end
        end
        if ok then
            for i = 1, ev.weight do
                available[#available+1] = ev.id
            end
        end
    end
    return available
end

local function PickWaveEvent(wave)
    if wave <= 1 then return "normal" end
    local pool = GetAvailableWaveEvents(wave)
    if #pool == 0 then return "normal" end
    return pool[math.random(#pool)]
end

-- ============================================================
--  ПОСТРОЕНИЕ ПУЛА СПАВНА
-- ============================================================
local function BuildSpawnPool(wave, eventID)
    local pool = {}
    for typeName, data in pairs(EnemyTypes) do
        local unlockWave = data.unlockWave or 1
        if wave >= unlockWave then
            local w = data.spawnWeight
            if eventID == "kamikaze" and typeName ~= "kamikaze" then
                w = w * 0.05
            elseif eventID == "armored" and typeName ~= "armored" then
                w = w * 0.4
            elseif eventID == "healers" and typeName ~= "healer" then
                w = w * 0.4
            elseif eventID == "ghost" and typeName ~= "ghost" then
                w = w * 0.2
            elseif eventID == "berserk" and typeName ~= "berserker" then
                w = w * 0.4
            elseif eventID == "elite" and (typeName == "normal" or typeName == "runner") then
                w = 0
            end
            if eventID == "berserk" and typeName == "berserker" then
                w = w * 3
            end
            if w > 0 then
                pool[#pool+1] = { source="npc", typeName=typeName, weight=w }
            end
        end
    end
    for _, sp in ipairs(NAA.SpecialTypes) do
        if wave >= sp.minWave then
            local w = sp.weight
            if eventID == "elite" then
                w = w * 2
            end
            pool[#pool+1] = { source="special", class=sp.class, weight=w }
        end
    end
    for _, mb in pairs(NAA.MiniBosses) do
        if wave >= mb.minWave then
            local chance = mb.spawnChance + (wave - mb.minWave) * 0.01
            if math.random() < chance then
                local w = 1
                if eventID == "elite" then
                    w = 3
                end
                pool[#pool+1] = { source="miniboss", mbData=mb, weight=w }
            end
        end
    end
    return pool
end

-- ============================================================
--  БОССЫ
-- ============================================================
local BossClasses = { [10]="neco_boss_giant", [20]="neco_boss_swarm", [30]="neco_boss_berserker", [50]="neco_boss_apex" }
local BossBaseHP  = { [10]=600, [20]=0, [30]=1200, [50]=5000 }

local function SpawnBoss(wave, diff)
    local bossClass = BossClasses[wave]
    if not bossClass then return nil end
    local plys = player.GetAll()
    if #plys == 0 then return nil end
    local pos = FindSpawnPos(plys[math.random(#plys)])
    if not pos then return nil end
    local boss = ents.Create(bossClass)
    if not IsValid(boss) then print("[NAA] ERROR: Failed to create boss " .. bossClass) return nil end
    boss:SetPos(pos)
    boss.IsNecoArc  = true
    boss.IsNecoBoss = true
    boss.NAADiff    = diff
    boss:Spawn()
    boss:Activate()
    local finalHP = math.ceil((BossBaseHP[wave] or 600) * diff.hpMult)
    boss:SetMaxHealth(finalHP)
    boss:SetHealth(finalHP)
    boss:SetNWInt("NecoMaxHP", finalHP)
    NAA.ActiveBoss   = boss
    NAA.AliveEnemies = (NAA.AliveEnemies or 0) + 1
    net.Start("NAA_BossAlert") net.WriteInt(wave, 16) net.Broadcast()
    timer.Simple(0.5, function() if IsValid(boss) then SetupNPCChase(boss) end end)
    print("[NAA] Boss spawned: " .. bossClass .. " HP=" .. finalHP)
    return boss
end

-- ============================================================
--  ЗАПУСК ВОЛНЫ
-- ============================================================
function NAA.SpawnWave(waveNum)
    if NAA.Phase ~= NAA.PHASE_WAVE then return end

    NAA.AliveEnemies = 0
    NAA.WaveSpawning = true

    local diff       = NAA.GetDiff(NAA.Difficulty)
    local eventID    = PickWaveEvent(waveNum)
    NAA.WaveEvent    = eventID
    local isBossWave = BossClasses[waveNum] ~= nil

    local waveSize = math.floor((6 + waveNum * 3) * diff.countMult)
    if eventID == "swarm"  then waveSize = waveSize * 2 end
    if isBossWave          then waveSize = math.floor(waveSize * 0.4) end
    if waveSize <= 0       then waveSize = 1 end

    local spawnDelay = eventID == "swarm" and 0.3 or 0.8

    net.Start("NAA_WaveUpdate")
        net.WriteInt(waveNum, 16)
        net.WriteInt(0, 16)
        net.WriteString(eventID)
    net.Broadcast()

    print("[NAA] Wave " .. waveNum .. " | Event=" .. eventID .. " | Size=" .. waveSize .. " | Boss=" .. tostring(isBossWave))

    local pool = BuildSpawnPool(waveNum, eventID)

    timer.Create("NAA_WaveSpawn", spawnDelay, waveSize, function()
        if NAA.Phase ~= NAA.PHASE_WAVE then
            timer.Remove("NAA_WaveSpawn")
            NAA.WaveSpawning = false
            return
        end
        local plys = player.GetAll()
        if #plys == 0 then return end
        local pos = FindSpawnPos(plys[math.random(#plys)])
        if not pos then return end
        SpawnEnemy(pos, waveNum, eventID, pool, diff)
        if timer.RepsLeft("NAA_WaveSpawn") == 0 then NAA.WaveSpawning = false end
    end)

    if isBossWave then
        timer.Simple(spawnDelay * waveSize * 0.5 + 2, function()
            if NAA.Phase == NAA.PHASE_WAVE then SpawnBoss(waveNum, diff) end
        end)
    end
end

-- ============================================================
--  KEYPRESS ДЛЯ TIME BUBBLE
-- ============================================================
hook.Add("KeyPress", "NAA_TimeBubbleKey", function(ply, key)
    if key ~= IN_USE then return end
    if not IsValid(ply) then return end
    local pd = NAA.GetPD(ply)
    if not pd then return end
    if (pd.upgrades.time_bubble or 0) <= 0 then return end
    if (pd.timeBubbleCD or 0) > CurTime() then return end
    NAA_ActivateTimeBubble(ply)
end)

-- ============================================================
--  ОСНОВНОЙ ТАЙМЕР ПРОВЕРКИ ВОЛНЫ (ИСПРАВЛЕН)
-- ============================================================
function NAA.StartPlayerTick()
    local waveClearing = false

    timer.Create("NAA_WaveCheck", 0.5, 0, function()
        -- Защита от ошибок при удалении сущностей
        local success, err = pcall(function()
            if NAA.Phase ~= NAA.PHASE_WAVE then return end

            local alive = 0
            -- Безопасный подсчёт живых врагов
            for _, e in ipairs(ents.GetAll()) do
                if IsValid(e) and e.IsNecoArc then
                    -- Дополнительная проверка: является ли сущность NPC и имеет ли метод Health
                    if e:IsNPC() and e.Health then
                        local hp = e:Health()
                        if hp > 0 then
                            alive = alive + 1
                        end
                    elseif e.Health then
                        -- На случай, если не NPC, но есть Health (например, проп)
                        local hp = e:Health()
                        if hp > 0 then
                            alive = alive + 1
                        end
                    end
                end
            end
            NAA.AliveEnemies = alive

            if NAA.DebugMode then
                print("[NAA] WaveCheck: alive=" .. alive .. " | WaveSpawning=" .. tostring(NAA.WaveSpawning))
            end

            -- Безопасная проверка босса
            if IsValid(NAA.ActiveBoss) and NAA.ActiveBoss.IsNecoBoss then
                local bossAlive = false
                if NAA.ActiveBoss:IsNPC() and NAA.ActiveBoss.Health then
                    bossAlive = NAA.ActiveBoss:Health() > 0
                end
                if not bossAlive then
                    NAA.ActiveBoss = nil
                end
            else
                NAA.ActiveBoss = nil
            end

            -- Отправка счёта
            local scores = {}
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) then
                    local pd = NAA.GetPD(p)
                    scores[p:Nick()] = pd.kills or 0
                end
            end
            net.Start("NAA_Scores")
            net.WriteString(util.TableToJSON(scores))
            net.Broadcast()

            net.Start("NAA_WaveUpdate")
            net.WriteInt(NAA.CurrentWave, 16)
            net.WriteInt(alive, 16)
            net.WriteString(NAA.WaveEvent or "normal")
            net.Broadcast()

            -- Бонус выжившему
            if NAA.CurrentWave > 0 and NAA.CurrentWave % 10 == 0 then
                for _, p in ipairs(player.GetAll()) do
                    if not IsValid(p) then continue end
                    local pd = NAA.GetPD(p)
                    if pd.class == "survivor" and not pd.survivorScaled then
                        pd.survivorScaled = true
                        local newMax = p:GetMaxHealth() + 10
                        p:SetMaxHealth(newMax)
                        p:SetHealth(math.min(p:GetHealth() + 10, newMax))
                    end
                end
            end

            -- Проверка завершения волны
            if alive == 0 and not NAA.WaveSpawning then
                if not waveClearing then
                    waveClearing = true
                    print("[NAA] Wave " .. NAA.CurrentWave .. " cleared!")
                    NAA.ActiveBoss = nil
                    local diff = NAA.GetDiff(NAA.Difficulty)
                    local supplyChance = ({easy=0.6,normal=0.35,hardcore=0.15,extreme=0.05,apocalypse=0.02})[NAA.Difficulty] or 0.35
                    if math.random() < supplyChance then
                        for _, p in ipairs(player.GetAll()) do
                            if IsValid(p) and p:Alive() then
                                -- Безопасное получение HP
                                local curHP = p:Health()
                                local maxHP = p:GetMaxHealth()
                                p:SetHealth(math.min(curHP + 25, maxHP))
                                p:GiveAmmo(60, "SMG1")
                                p:GiveAmmo(20, "Pistol")
                            end
                        end
                        net.Start("NAA_BetweenWave")
                        net.WriteString("Supply drop: +HP +Ammo for all players")
                        net.Broadcast()
                    end
                    timer.Simple(2, function()
                        if NAA.Phase == NAA.PHASE_WAVE then
                            waveClearing = false
                            NAA.StartBetweenWaves()
                        end
                    end)
                end
            else
                waveClearing = false
            end
        end)

        if not success then
            -- Логируем ошибку, но не даём таймеру сломаться
            print("[NAA] ERROR in WaveCheck: " .. tostring(err))
            if NAA.DebugMode then
                print(debug.traceback())
            end
        end
    end)
end

-- ============================================================
--  EntityTakeDamage (убраны глобальные эффекты событий)
-- ============================================================
hook.Add("EntityTakeDamage", "NAA_DamageModify", function(ent, dmginfo)
    if not IsValid(ent) then return end

    if ent.IsNecoArc then
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() then
            local pd  = NAA.GetPD(attacker)
            local upg = pd.upgrades or {}
            local dmg = dmginfo:GetDamage()

            if (upg.heavy_bullets or 0) > 0 then dmg = dmg * (1 + 0.20*upg.heavy_bullets) end
            if (upg.boss_hunter or 0) > 0 and (ent.IsNecoBoss or ent.IsNecoSpecial or ent.IsMiniBoss) then
                dmg = dmg * (1 + 0.40*upg.boss_hunter)
            end
            if pd.class == "berserker" then
                local rMult = math.Lerp(attacker:Health()/math.max(attacker:GetMaxHealth(),1), 2.8, 1.0)
                if pd.immortalBerserkActive then rMult = 2.8 end
                dmg = dmg * rMult
            end
            if pd.class == "hunter" then
                local hStacks = pd.hunterStacks or 0
                local hMult   = math.min(1 + 0.03 * hStacks, 2.5)
                dmg = dmg * hMult
                if pd.nextIsOneshot == true then
                    if not ent.IsNecoBoss then
                        dmg = 99999
                        pd.nextIsOneshot = false
                        net.Start("NAA_SpecialAlert")
                            net.WriteString("💀 ВАНШОТ!")
                        net.Send(attacker)
                    else
                        if (pd.synergies or {}).monster_hunter then
                            dmg = dmg * 3
                        end
                    end
                end
            end
            if attacker.NecoDeathMark then
                attacker.NecoDeathMark = nil
                dmg = dmg * 2
                net.Start("NAA_SpecialAlert") net.WriteString("МЕТКА СМЕРТИ: x2 урона!") net.Send(attacker)
            end
            if (upg.crit or 0) > 0 then
                local chance = 0.15 * math.min(upg.crit, 5)
                local isCrit = math.random() < chance
                if isCrit then dmg = dmg * ((pd.synergies or {}).piercer and 4.0 or 2.5) end
                net.Start("NAA_HitMarker") net.WriteBool(isCrit) net.Send(attacker)
            else
                net.Start("NAA_HitMarker") net.WriteBool(false) net.Send(attacker)
            end
            if (upg.poison or 0) > 0 then
                ent.NecoPoisoned=true ent.NecoPoisonDmg=3*upg.poison
                ent.NecoPoisonExpires=CurTime()+4 ent.NecoPoisonAttacker=attacker
            end
            if (upg.explosive_bullets or 0) > 0 then
                local bDmg = 25*upg.explosive_bullets
                timer.Simple(0, function()
                    if IsValid(ent) then
                        util.BlastDamage(attacker, attacker, ent:GetPos(), 70, bDmg)
                        if (pd.synergies or {}).time_bomb then
                            ent.NecoSlowed=true ent.NecoSlowExpires=CurTime()+2
                        end
                    end
                end)
            end
            if (upg.chain_lightning or 0) > 0 then
                local chainDmg = dmg * 0.6
                local chained  = 0
                for _, nearby in ipairs(ents.FindInSphere(ent:GetPos(), 200)) do
                    if chained >= upg.chain_lightning+1 then break end
                    if IsValid(nearby) and nearby.IsNecoArc and nearby ~= ent then
                        nearby:TakeDamage(chainDmg, attacker, attacker)
                        if (pd.synergies or {}).nuclear then util.BlastDamage(attacker, attacker, nearby:GetPos(), 70, 20) end
                        chained = chained + 1
                    end
                end
            end
            if (upg.penetrating or 0) > 0 then
                local rem = upg.penetrating
                local last = ent
                while rem > 0 do
                    local nxt, nd = nil, math.huge
                    local sd = (attacker:GetShootPos()-last:GetPos()):GetNormalized()
                    for _, p in ipairs(ents.FindInSphere(last:GetPos(), 150)) do
                        if IsValid(p) and p.IsNecoArc and p ~= last then
                            if sd:Dot((p:GetPos()-last:GetPos()):GetNormalized()) > 0.7 then
                                local d = last:GetPos():Distance(p:GetPos())
                                if d < nd then nd=d nxt=p end
                            end
                        end
                    end
                    if IsValid(nxt) then nxt:TakeDamage(dmg*0.5, attacker, attacker) last=nxt rem=rem-1 else break end
                end
            end
            if (upg.mega_shot or 0) > 0 then
                local sid = attacker:SteamID()
                NAA.ShotCounter[sid] = (NAA.ShotCounter[sid] or 0) + 1
                if NAA.ShotCounter[sid] >= 7 then
                    NAA.ShotCounter[sid] = 0
                    dmg = not ent.IsNecoBoss and 99999 or dmg*3
                    net.Start("NAA_SpecialAlert") net.WriteString("MEGA SHOT!") net.Send(attacker)
                end
            end
            if ent.NecoDamageMult then dmg = dmg * ent.NecoDamageMult end
            dmginfo:SetDamage(dmg)
        end
        if (ent.NecoBlessUntil or 0) > CurTime() and ent.NecoBlessMult then
            dmginfo:SetDamage(dmginfo:GetDamage() * ent.NecoBlessMult)
        end
        if (ent.LastHurt or 0) < CurTime() then
            ent:EmitSound(HurtSounds[math.random(#HurtSounds)], 90)
            ent.LastHurt = CurTime() + 0.5
        end
    end

    if ent:IsPlayer() then
        local pd  = NAA.GetPD(ent)
        local upg = pd.upgrades or {}
        local dmg = dmginfo:GetDamage()
        if (upg.steel_skin or 0) > 0 then dmg = dmg * (1 - 0.05*math.min(upg.steel_skin,6)) end
        if pd.ghostStepActive then dmg = 0 end
        if pd.immortalityActive then dmg = 0 end
        if (upg.shield or 0) > 0 and not pd.shieldBroken and dmg > 0 then
            if not (pd.synergies or {}).regen_shield then
                pd.shieldBroken = true
                timer.Simple(22, function() if pd then pd.shieldBroken = false end end)
            else pd.shieldBroken = true end
            dmg = 0
        end
        if (upg.reflect or 0) > 0 and math.random() < 0.20*math.min(upg.reflect,4) then
            local src = dmginfo:GetAttacker()
            if IsValid(src) and src.IsNecoArc then
                timer.Simple(0, function()
                    if IsValid(src) then src:TakeDamage(dmg*0.3, ent, ent) end
                end)
            end
        end
        if dmg > 0 and (upg.ghost_step or 0) > 0 and (pd.ghostStepCD or 0) <= CurTime() then
            pd.ghostStepActive=true pd.ghostStepExpires=CurTime()+1.5 pd.ghostStepCD=CurTime()+20
        end
        dmginfo:SetDamage(dmg)
    end
end)

-- ============================================================
--  OnNPCKilled
-- ============================================================
hook.Add("OnNPCKilled", "NAA_NPCDeath", function(npc, attacker, inflictor)
    if not IsValid(npc) or not npc.IsNecoArc then return end
    if npc.NAAKillHandled then return end
    NAA_OnNecoKilled(npc, attacker)
    ScheduleCorpseCleanup(npc)
end)

-- ============================================================
--  СТАТУС-ЭФФЕКТЫ
-- ============================================================
timer.Create("NAA_PoisonTick", 1, 0, function()
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent.IsNecoArc and ent.NecoPoisoned then
            if CurTime() > (ent.NecoPoisonExpires or 0) then
                ent.NecoPoisoned = false
            else
                local atk = IsValid(ent.NecoPoisonAttacker) and ent.NecoPoisonAttacker or ent
                timer.Simple(0, function()
                    if IsValid(ent) then
                        ent:TakeDamage(ent.NecoPoisonDmg or 3, atk, atk)
                    end
                end)
            end
        end
    end
end)

timer.Create("NAA_SlowTick", 0.5, 0, function()
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent.IsNecoArc and ent.NecoSlowed then
            if (ent.NecoSlowExpires or 0) <= CurTime() then ent.NecoSlowed = false end
        end
    end
end)

timer.Create("NAA_RevivedTick", 1, 0, function()
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent.IsNecoArc and ent.RevivedUntil then
            if CurTime() > ent.RevivedUntil then
                ent.RevivedUntil = nil
                ent:TakeDamage(99999, ent, ent)
            end
        end
    end
end)