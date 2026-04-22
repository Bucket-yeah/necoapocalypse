-- ============================================================
--  NECO ARC APOCALYPSE — sv_devmode.lua (SERVER)
--  Исправленная версия: добавлены недостающие команды,
--  корректный спавн врагов, полный сброс апгрейдов и пр.
-- ============================================================

util.AddNetworkString("NAA_DevCommand")
util.AddNetworkString("NAA_DevStatus")

-- ============================================================
--  ПРОВЕРКА ЧИТОВ
-- ============================================================
local function CheckCheats(ply)
    if not GetConVar("sv_cheats"):GetBool() then
        if IsValid(ply) then ply:ChatPrint("⚠ [NAA DEV] Требуется sv_cheats 1") end
        return false
    end
    return true
end

-- ============================================================
--  КОНСОЛЬНАЯ КОМАНДА ДЛЯ СПАВНА ВРАГОВ (вызывается из девменю)
-- ============================================================
concommand.Add("naa_spawnenemy", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not GetConVar("sv_cheats"):GetBool() then
        ply:ChatPrint("[NAA DEV] Требуется sv_cheats 1")
        return
    end
    local etype = args[1] or "normal"
    local count = tonumber(args[2]) or 1
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local dist = 300 + math.random() * 200
        local pos = ply:GetPos() + Vector(math.cos(angle)*dist, math.sin(angle)*dist, 0)
        -- Трассировка вниз
        local tr = util.TraceLine({ start = pos + Vector(0,0,500), endpos = pos - Vector(0,0,500), mask = MASK_SOLID_BRUSHONLY })
        if tr.Hit then pos = tr.HitPos + Vector(0,0,5) end
        if NAA.SpawnEnemy then
            NAA.SpawnEnemy(etype, pos)
        else
            -- fallback
            local npc = ents.Create("npc_citizen")
            if IsValid(npc) then
                npc:SetPos(pos)
                npc.IsNecoArc = true
                npc.NecoType = etype
                npc:Spawn()
                npc:Activate()
                NAA.AliveEnemies = (NAA.AliveEnemies or 0) + 1
            end
        end
    end
    ply:ChatPrint(string.format("[NAA DEV] Спавнено %d x %s", count, etype))
end)

-- ============================================================
--  ОСНОВНОЙ ОБРАБОТЧИК КОМАНД
-- ============================================================
net.Receive("NAA_DevCommand", function(len, ply)
    if not CheckCheats(ply) then return end

    local cmd  = net.ReadString()
    local args = util.JSONToTable(net.ReadString()) or {}

    -- === АПГРЕЙДЫ ===
    if cmd == "give_upgrade" then
        local id    = tostring(args.id or "")
        local count = tonumber(args.count) or 1
        local upg   = NAA.Upgrades[id]
        if not upg then return end
        local pd = NAA.GetPD(ply)
        for i = 1, count do
            local cur = pd.upgrades[id] or 0
            if cur < (upg.maxStacks or 1) then
                NAA.ApplyUpgrade(ply, id)
            end
        end

    elseif cmd == "remove_upgrade" then
        local id = tostring(args.id or "")
        if not NAA.Upgrades[id] then return end
        local pd = NAA.GetPD(ply)
        if (pd.upgrades[id] or 0) > 0 then
            pd.upgrades[id] = pd.upgrades[id] - 1
            if pd.upgrades[id] == 0 then pd.upgrades[id] = nil end
        end
        pd.synergies = NAA.GetActiveSynergies(pd.upgrades, pd.class)
        NAA_RecalcSpeed(ply)
        NAA.SyncUpgrades(ply)

    elseif cmd == "max_upgrade" then
        local id  = tostring(args.id or "")
        local upg = NAA.Upgrades[id]
        if not upg then return end
        local pd  = NAA.GetPD(ply)
        local cur = pd.upgrades[id] or 0
        local max = upg.maxStacks or 1
        for i = cur + 1, max do
            NAA.ApplyUpgrade(ply, id)
        end

    elseif cmd == "reset_upgrades" then
        local pd = NAA.GetPD(ply)
        pd.upgrades         = {}
        pd.synergies        = {}
        pd.adaptResist      = {}
        NAA.ShotCounter[ply:SteamID()] = 0
        pd.hunterStacks     = 0
        pd.hunterStreak     = 0
        pd.nextIsOneshot    = false
        pd.lastChanceUsed   = false
        pd.apocalypseUsed   = false
        pd.dashCD           = 0
        pd.timeBubbleCD     = 0
        pd.droneTimer       = 0
        pd.ghostStepActive  = false
        pd.ghostStepCD      = 0
        pd.immortalityActive = false
        pd.immortalityCD    = 0
        pd.shieldBroken     = false
        pd.shieldKills      = 0
        pd.shieldCD         = 0
        pd.adrenalineActive = false
        pd.counterRushActive = false
        pd.immortalBerserkActive = false
        ply:SetNWInt("NAA_ExtraJumps", 0)
        pd.airJumpsUsed = 0
        -- Удалить союзных Неко
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and ent.IsAllyNeco and ent.NecoOwner == ply then
                ent:Remove()
            end
        end
        -- Сброс характеристик до базовых класса
        local cls = NAA.Classes[pd.class or "survivor"]
        ply:SetMaxHealth(cls.hp)
        ply:SetHealth(cls.hp)
        ply:SetArmor(cls.armor)
        NAA_RecalcSpeed(ply)
        NAA.SyncUpgrades(ply)
        NAA_SyncHunterStacks(ply)
        ply:ChatPrint("⚠ [NAA DEV] Все апгрейды и их эффекты сброшены")

    elseif cmd == "give_all_upgrades" then
        local pd = NAA.GetPD(ply)
        for id, upg in pairs(NAA.Upgrades) do
            local cur = pd.upgrades[id] or 0
            local maxStacks = upg.maxStacks or 1
            for i = cur + 1, maxStacks do
                NAA.ApplyUpgrade(ply, id)
            end
        end
        ply:ChatPrint("✅ [NAA DEV] Все апгрейды максимальны")

    -- === ХАРАКТЕРИСТИКИ ===
    elseif cmd == "set_hp" then
        local hp = math.Clamp(tonumber(args.hp) or 100, 1, 9999)
        if hp > ply:GetMaxHealth() then ply:SetMaxHealth(hp) end
        ply:SetHealth(hp)

    elseif cmd == "set_armor" then
        local armor = math.Clamp(tonumber(args.armor) or 0, 0, 500)
        ply:SetArmor(armor)

    elseif cmd == "heal_full" then
        ply:SetHealth(ply:GetMaxHealth())
        ply:SetArmor(100)

    elseif cmd == "kill_self" then
        ply:Kill()

    elseif cmd == "godmode" then
        local pd = NAA.GetPD(ply)
        pd.devGodMode = not (pd.devGodMode or false)
        if pd.devGodMode then
            ply:SetHealth(9999); ply:SetMaxHealth(9999); ply:SetArmor(500)
        else
            local cls = NAA.Classes[pd.class or "survivor"]
            ply:SetMaxHealth(cls.hp)
            ply:SetHealth(cls.hp)
            ply:SetArmor(cls.armor)
        end
        net.Start("NAA_DevStatus")
            net.WriteTable({ godmode = pd.devGodMode, cheats = true })
        net.Send(ply)

    elseif cmd == "full_ammo" then
        ply:GiveAmmo(999, "SMG1")
        ply:GiveAmmo(200, "Buckshot")
        ply:GiveAmmo(500, "Pistol")
        ply:GiveAmmo(300, "AR2")
        ply:ChatPrint("✅ [NAA DEV] Патроны пополнены")

    elseif cmd == "set_speed" then
        local spd = math.Clamp(tonumber(args.speed) or 200, 50, 5000)
        ply:SetRunSpeed(spd)
        ply:SetWalkSpeed(spd * 0.55)

    -- === КЛАСС ===
    elseif cmd == "set_class" then
        local cid = tostring(args.class or "survivor")
        if not NAA.Classes[cid] then return end
        local pd = NAA.GetPD(ply)
        pd.class = cid
        ply:SetNWString("NAA_Class", cid)
        local clsData = NAA.Classes[cid]
        ply:SetMaxHealth(clsData.hp)
        ply:SetHealth(clsData.hp)
        ply:SetArmor(clsData.armor)
        NAA_RecalcSpeed(ply)
        ply:StripWeapons()
        for _, wep in ipairs(clsData.startWeapons or {}) do
            ply:Give(wep)
        end
        ply:GiveAmmo(120, "SMG1")
        ply:GiveAmmo(16, "Buckshot")
        ply:GiveAmmo(60, "Pistol")
        ply:GiveAmmo(30, "AR2")
        ply:ChatPrint("✅ [NAA DEV] Класс изменён на " .. clsData.name)

    -- === МОНЕТЫ ===
    elseif cmd == "set_coins" then
        local coins = math.Clamp(tonumber(args.coins) or 0, 0, 99999)
        local pd    = NAA.GetPD(ply)
        pd.coins    = coins
        net.Start("NAA_SyncCoins")
            net.WriteInt(coins, 16)
        net.Send(ply)

    elseif cmd == "add_coins" then
        local amount = math.Clamp(tonumber(args.amount) or 10, 0, 9999)
        NAA_AddCoins(ply, amount)

    elseif cmd == "add_neocoin" then
        local amount = math.Clamp(tonumber(args.amount) or 50, 0, 9999)
        NAA.AddNeoCoins(ply, amount)

    -- === ВОЛНЫ ===
    elseif cmd == "skip_wave" then
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and (ent.IsNecoArc or ent:GetClass():find("neco_")) then
                ent:Remove()
            end
        end
        NAA.AliveEnemies = 0

    elseif cmd == "set_wave" then
        local wave = math.Clamp(tonumber(args.wave) or 1, 1, 999)
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and (ent.IsNecoArc or ent:GetClass():find("neco_")) then
                ent:Remove()
            end
        end
        NAA.AliveEnemies = 0
        NAA.CurrentWave  = wave - 1
        timer.Simple(0.5, function()
            if NAA.Phase == NAA.PHASE_WAVE or NAA.Phase == NAA.PHASE_BETWEEN_WAVES then
                NAA.StartNextWave()
            else
                -- если игра ещё не активна, просто обновляем волну
                NAA.CurrentWave = wave
                net.Start("NAA_WaveUpdate")
                    net.WriteInt(NAA.CurrentWave, 16)
                    net.WriteInt(0, 16)
                    net.WriteString("normal")
                net.Broadcast()
            end
        end)

    elseif cmd == "force_between_waves" then
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and (ent.IsNecoArc or ent:GetClass():find("neco_")) then
                ent:Remove()
            end
        end
        NAA.AliveEnemies = 0
        timer.Simple(0.3, function()
            -- Сброс выбранных карт у игроков, чтобы меню открылось заново
            for _, p in player.Iterator() do
                if IsValid(p) then
                    local pd = NAA.GetPD(p)
                    pd.cardOptions = {}
                end
            end
            NAA.StartBetweenWaves()
        end)

    elseif cmd == "start_game" then
        if NAA.Phase == NAA.PHASE_LOBBY or NAA.Phase == NAA.PHASE_CLASS_SELECT then
            local pd = NAA.GetPD(ply)
            if not pd.class then pd.class = "survivor" end
            NAA.Difficulty  = args.difficulty or NAA.Difficulty or "normal"
            NAA.CurrentWave = 0
            NAA.Phase       = NAA.PHASE_WAVE
            net.Start("NAA_Phase")
                net.WriteString(NAA.Phase)
                net.WriteInt(NAA.CurrentWave, 16)
                net.WriteString(NAA.Difficulty)
            net.Broadcast()
            timer.Simple(0.5, function()
                NAA.StartPlayerTick()
                NAA.StartNextWave()
            end)
        end

    -- === ПРОЧЕЕ ===
    elseif cmd == "spawn_enemy" then
        local etype = tostring(args.etype or "normal")
        local count = math.Clamp(tonumber(args.count) or 1, 1, 50)
        RunConsoleCommand("naa_spawnenemy", etype, tostring(count))

    elseif cmd == "give_weapon" then
        local wep = tostring(args.weapon or "")
        if wep ~= "" then ply:Give(wep) end

    elseif cmd == "strip_weapons" then
        ply:StripWeapons()
        local pd  = NAA.GetPD(ply)
        local cls = NAA.Classes[pd.class or "survivor"]
        for _, w in ipairs(cls.startWeapons or {}) do
            ply:Give(w)
        end

    elseif cmd == "set_lives" then
        local lives = math.Clamp(tonumber(args.lives) or 5, 0, 999)
        local pd    = NAA.GetPD(ply)
        pd.lives    = lives
        pd.dead     = (lives <= 0)
        net.Start("NAA_SyncLives")
            net.WriteInt(lives, 16)
        net.Send(ply)
    end
end)

-- ============================================================
--  GOD MODE — хук защиты
-- ============================================================
hook.Add("EntityTakeDamage", "NAA_DevGodMode", function(ent, dmginfo)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    local pd = NAA.GetPD(ent)
    if pd and pd.devGodMode then
        dmginfo:SetDamage(0)
        return true
    end
end)

-- ============================================================
--  СИНХРОНИЗАЦИЯ СТАТУСА (каждые 2 сек, отправка таблицей)
-- ============================================================
timer.Create("NAA_DevStatusBroadcast", 2, 0, function()
    local cheats = GetConVar("sv_cheats"):GetBool()
    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        local pd = NAA.GetPD(ply)
        local data = {
            cheats  = cheats,
            godmode = pd and pd.devGodMode or false,
            phase   = NAA.Phase,
            wave    = NAA.CurrentWave,
            enemies = NAA.AliveEnemies,
            diff    = NAA.Difficulty,
            lives   = pd and pd.lives or 5,
            coins   = pd and pd.coins or 0,
        }
        net.Start("NAA_DevStatus")
            net.WriteTable(data)
        net.Send(ply)
    end
end)

print("[NAA] sv_devmode.lua загружен (исправленная версия)")