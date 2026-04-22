-- ============================================================
--  NECO ARC APOCALYPSE — init.lua (SERVER) — Мультиплеер-патч
--  Добавлены: Ready-лобби, выбор класса с подтверждением,
--  голосование за сложность, синхронизация статуса апгрейдов
-- ============================================================
DeriveGamemode("base")
GM.Name   = "Neco Arc Apocalypse"
GM.Author = "NAA"

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_hud.lua")
AddCSLuaFile("cl_menu.lua")
AddCSLuaFile("cl_upgrades.lua")
AddCSLuaFile("cl_shop.lua")
AddCSLuaFile("cl_death.lua")
AddCSLuaFile("cl_metashop.lua")
AddCSLuaFile("cl_devmode.lua")

include("shared.lua")
include("sv_meta.lua")
include("sv_economy.lua")
include("sv_upgrades.lua")
include("sv_waves.lua")
include("sv_devmode.lua")

-- Net strings
for _, name in ipairs(NAA.NET) do
    util.AddNetworkString(name)
	util.AddNetworkString("NAA_LastNecoPos")
end

-- ============================================================
--  ГЛОБАЛЬНЫЕ СЧЁТЧИКИ / СОСТОЯНИЕ
-- ============================================================
NAA.Difficulty        = "normal"
NAA.ReadyPlayers      = {}   -- [sid] = true/false  (в лобби)
NAA.ClassConfirmed    = {}   -- [sid] = true         (класс подтверждён)
NAA.DiffVotes         = {}   -- [sid] = "easy"/...   (голос за сложность)
NAA.PlayerData        = {}
NAA.ShotCounter       = NAA.ShotCounter or {}

-- ============================================================
--  NEW PLAYER DATA
-- ============================================================
local function NewPD()
    return {
        class              = "survivor",
        upgrades           = {},
        synergies          = {},
        _prevSyn           = {},
        coins              = 0,
        lives              = 5,
        freeRerolls        = 0,
        cardOptions        = {},
        kills              = 0,
        killStreak         = 0,
        hunterStacks       = 0,
        hunterStreak       = 0,
        nextIsOneshot      = false,
        survivorScaled     = false,
        immortalBerserkActive = false,
        airJumpsUsed       = 0,
        dashCD             = 0,
        adrenalineActive   = false,
        adrenalineExpires  = 0,
        counterRushActive  = false,
        counterRushExpires = 0,
        ghostStepActive    = false,
        ghostStepExpires   = 0,
        ghostStepCD        = 0,
        immortalityActive  = false,
        immortalityExpires = 0,
        immortalityCD      = 0,
        shieldBroken       = false,
        shieldCD           = 0,
        shieldKills        = 0,
        timeBubbleCD       = 0,
        droneTimer         = 0,
        adaptResist        = {},
        lastChanceUsed     = false,
        apocalypseUsed     = false,
        dead               = false,
        spectating         = false,
        devGodMode         = false,
        regenAccum         = 0,
    }
end

local _fallbackPD = nil
local function GetPD(ply)
    if not IsValid(ply) then
        if not _fallbackPD then _fallbackPD = NewPD() end
        return _fallbackPD
    end
    local sid = ply:SteamID()
    if not NAA.PlayerData[sid] then
        NAA.PlayerData[sid] = NewPD()
    end
    local pd      = NAA.PlayerData[sid]
    local default = NewPD()
    for k, v in pairs(default) do
        if pd[k] == nil then pd[k] = v end
    end
    return pd
end
NAA.GetPD = GetPD

-- ============================================================
--  УТИЛИТЫ СИНХРОНИЗАЦИИ
-- ============================================================
local PISTOL_RESERVE_AMMO = 999

local function EnsurePistolAmmo(ply)
    if not IsValid(ply) then return end
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and wep:GetClass():find("pistol") then
            local ammoType = wep:GetPrimaryAmmoType()
            if ammoType >= 0 then ply:SetAmmo(PISTOL_RESERVE_AMMO, ammoType) end
        end
    end
end

local function BroadcastPhase()
    net.Start("NAA_Phase")
        net.WriteString(NAA.Phase)
        net.WriteInt(NAA.CurrentWave, 16)
        net.WriteString(NAA.Difficulty)
    net.Broadcast()
end

local function SyncCoins(ply)
    if not IsValid(ply) then return end
    net.Start("NAA_SyncCoins")
        net.WriteInt(GetPD(ply).coins or 0, 16)
    net.Send(ply)
end

local function SyncLives(ply)
    if not IsValid(ply) then return end
    net.Start("NAA_SyncLives")
        net.WriteInt(GetPD(ply).lives or 0, 16)
    net.Send(ply)
end

local function SyncUpgrades(ply)
    if not IsValid(ply) then return end
    net.Start("NAA_UpgradeList")
        net.WriteString(util.TableToJSON(GetPD(ply).upgrades))
    net.Send(ply)
end
NAA.SyncUpgrades = SyncUpgrades

-- ============================================================
--  РАССЫЛКА СОСТОЯНИЯ ЛОББИ
-- ============================================================
local function BroadcastLobbyState()
    local players = {}
    for _, p in player.Iterator() do
        if not IsValid(p) then continue end
        local nick = p:Nick()
        if #nick > 20 then nick = nick:sub(1,20) end
        players[#players+1] = {
            nick  = nick,
            sid   = p:SteamID(),
            ready = NAA.ReadyPlayers[p:SteamID()] == true,
        }
    end
    local json = util.TableToJSON({ players = players })
    net.Start("NAA_LobbyState")
        net.WriteString(json)
    net.Broadcast()
end

local function BroadcastClassState()
    local players = {}
    for _, p in player.Iterator() do
        if not IsValid(p) then continue end
        local nick = p:Nick()
        if #nick > 20 then nick = nick:sub(1,20) end
        players[#players+1] = {
            nick      = nick,
            sid       = p:SteamID(),
            class     = GetPD(p).class or "survivor",
            confirmed = NAA.ClassConfirmed[p:SteamID()] == true,
        }
    end
    local json = util.TableToJSON({ players = players })
    net.Start("NAA_ClassState")
        net.WriteString(json)
    net.Broadcast()
end

local function BroadcastDiffVoteState(countdown)
    local votes   = {}
    local players = {}
    for _, p in player.Iterator() do
        if not IsValid(p) then continue end
        local sid  = p:SteamID()
        local vote = NAA.DiffVotes[sid]
        local nick = p:Nick()
        if #nick > 20 then nick = nick:sub(1,20) end
        if vote then votes[vote] = (votes[vote] or 0) + 1 end
        players[#players+1] = { nick=nick, voted=(vote ~= nil) }
    end
    local json = util.TableToJSON({ votes=votes, players=players, countdown=countdown or 0 })
    net.Start("NAA_DiffVoteState")
        net.WriteString(json)
    net.Broadcast()
end

local function BroadcastUpgradeStatus()
    local pending = {}
    for _, p in player.Iterator() do
        if not IsValid(p) then continue end
        local pd = GetPD(p)
        if pd.cardOptions and #pd.cardOptions > 0 then
            local nick = p:Nick()
            if #nick > 16 then nick = nick:sub(1,16) end
            pending[#pending+1] = nick
        end
    end
    net.Start("NAA_UpgradeStatus")
        net.WriteString(util.TableToJSON({ pending=pending }))
    net.Broadcast()
end

-- ============================================================
--  GM:PlayerInitialSpawn
-- ============================================================
function GM:PlayerInitialSpawn(ply)
    timer.Simple(0.5, function()
        if not IsValid(ply) then return end
        net.Start("NAA_Phase")
            net.WriteString(NAA.Phase)
            net.WriteInt(NAA.CurrentWave, 16)
            net.WriteString(NAA.Difficulty)
        net.Send(ply)
        -- Если уже в лобби, отправляем его состояние
        if NAA.Phase == NAA.PHASE_LOBBY then
            BroadcastLobbyState()
        end
    end)
end

-- ============================================================
--  СБРОС СЧЁТЧИКОВ ВОЛНЫ
-- ============================================================
local function ResetWaveCounters()
    NAA.ShotCounter = {}
    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        local pd = GetPD(ply)
        pd.airJumpsUsed      = 0
        pd.adrenalineActive  = false
        pd.counterRushActive = false
        pd.ghostStepActive   = false
        pd.immortalityActive = false
    end
end

-- ============================================================
--  МЕЖДУ ВОЛНАМИ
-- ============================================================
function NAA.StartBetweenWaves()
    NAA.Phase = NAA.PHASE_BETWEEN_WAVES
    BroadcastPhase()

    local diff = NAA.GetDiff(NAA.Difficulty)
    local betweenDur = 30  -- 30 секунд максимум

    net.Start("NAA_BetweenWaveTimer")
        net.WriteInt(betweenDur, 8)
    net.Broadcast()

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        local pd = GetPD(ply)

        if ply:GetObserverMode() ~= OBS_MODE_NONE then ply:UnSpectate() end
        if not ply:Alive() then ply:Spawn() end
        pd.dead      = false
        pd.spectating = false

        if pd.class == "survivor" and NAA.CurrentWave > 0 and NAA.CurrentWave % 10 == 0 then
            local newMax = ply:GetMaxHealth() + 10
            ply:SetMaxHealth(newMax)
            ply:SetHealth(newMax)
            net.Start("NAA_SpecialAlert")
                net.WriteString("Survivor: +10 макс HP!")
            net.Send(ply)
        end

        ply:GiveAmmo(30, "SMG1")
        ply:GiveAmmo(4,  "Buckshot")
        ply:GiveAmmo(15, "Pistol")
        ply:GiveAmmo(10, "AR2")
        ply:GiveAmmo(1,  "XBowBolt")

        local cards = NAA.PickCards(diff.rareBonus, pd.upgrades)
        pd.cardOptions = cards

        net.Start("NAA_ShowUpgrades")
            net.WriteString(cards[1] or "")
            net.WriteString(cards[2] or "")
            net.WriteString(cards[3] or "")
            net.WriteString("")
            net.WriteInt(pd.coins, 16)
        net.Send(ply)

        SyncCoins(ply)
        SyncLives(ply)
    end

    BroadcastUpgradeStatus()

    -- Таймер-фолбэк: если кто-то не выбрал — назначить случайный
    timer.Create("NAA_BetweenWaveTimer", betweenDur, 1, function()
        if NAA.Phase ~= NAA.PHASE_BETWEEN_WAVES then return end
        for _, ply in player.Iterator() do
            if not IsValid(ply) then continue end
            local pd = GetPD(ply)
            if pd.cardOptions and #pd.cardOptions > 0 then
                NAA.ApplyUpgrade(ply, pd.cardOptions[math.random(#pd.cardOptions)])
                pd.cardOptions = {}
            end
        end
        NAA.StartNextWave()
    end)
end

-- ============================================================
--  СЛЕДУЮЩАЯ ВОЛНА
-- ============================================================
function NAA.StartNextWave()
    timer.Remove("NAA_BetweenWaveTimer")
    NAA.CurrentWave = NAA.CurrentWave + 1
    NAA.Phase       = NAA.PHASE_WAVE
    ResetWaveCounters()
    BroadcastPhase()
    NAA.SpawnWave(NAA.CurrentWave)
end

-- ============================================================
--  КОНЕЦ ИГРЫ
-- ============================================================
function NAA.GameOver()
    NAA.Phase = NAA.PHASE_GAME_OVER
    BroadcastPhase()

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        local pd   = GetPD(ply)
        local diff = NAA.GetDiff(NAA.Difficulty)
        local neo  = math.floor(
            (NAA.CurrentWave * 2 + math.floor((pd.kills or 0) * 0.05)) * diff.neoMult
        )
        NAA.AddNeoCoins(ply, neo)
        hook.Run("NAA_RunEnd", ply, NAA.CurrentWave, pd.kills or 0, NAA.Difficulty)

        net.Start("NAA_RunResult")
            net.WriteString(util.TableToJSON({
                wave       = NAA.CurrentWave,
                kills      = pd.kills or 0,
                difficulty = NAA.Difficulty,
                neo        = neo,
                upgrades   = pd.upgrades,
                synergies  = pd.synergies,
            }))
        net.Send(ply)
    end
end

-- ============================================================
--  ПОЛНЫЙ СБРОС ИГРЫ
-- ============================================================
function NAA.ResetGame()
    NAA.Phase         = NAA.PHASE_LOBBY
    NAA.CurrentWave   = 0
    NAA.AliveEnemies  = 0
    NAA.WaveEvent     = "normal"
    NAA.ActiveBoss    = nil
    NAA.PlayerData    = {}
    NAA.ReadyPlayers  = {}
    NAA.ClassConfirmed= {}
    NAA.DiffVotes     = {}
    NAA.ShotCounter   = {}

    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) then
            if ent.IsNecoArc or ent:GetClass():find("neco_")
                or ent.IsAllyNeco or ent.IsDrone then
                ent:Remove()
            end
        end
    end

    timer.Remove("NAA_BetweenWaveTimer")
    timer.Remove("NAA_WaveCheck")
    timer.Remove("NAA_WaveSpawn")
    timer.Remove("NAA_PlayerFastTick")
    timer.Remove("NAA_PlayerSlowTick")
    timer.Remove("NAA_AllyNecoTick")
    timer.Remove("NAA_DiffVoteTimer")

    for _, ply in player.Iterator() do
        if IsValid(ply) then
            if ply:GetObserverMode() ~= OBS_MODE_NONE then ply:UnSpectate() end
            ply:StripWeapons()
            ply:SetNWString("NAA_Class", "")
            local pd = GetPD(ply)
            if pd then
                pd.dead = false; pd.spectating = false
                pd.respawnTime = 0; pd.lives = 5
            end
            ply:Spawn()
        end
    end

    BroadcastPhase()
    timer.Simple(0.3, BroadcastLobbyState)
end

-- ============================================================
--  NET: ЛОББИ — КНОПКА ГОТОВ
-- ============================================================
net.Receive("NAA_StartGame", function(len, ply)
    -- Совместимость: одиночная — один нажал, сразу переходим
    if NAA.Phase ~= NAA.PHASE_LOBBY then return end
    local count = 0
    for _ in player.Iterator() do count = count + 1 end
    if count <= 1 then
        NAA.Phase = NAA.PHASE_CLASS_SELECT
        NAA.ReadyPlayers  = {}
        NAA.ClassConfirmed= {}
        NAA.DiffVotes     = {}
        BroadcastPhase()
    else
        -- В мультиплеере кнопка НАЧАТЬ = кнопка ГОТОВ (сервер)
        NAA.ReadyPlayers[ply:SteamID()] = true
        BroadcastLobbyState()
        local allReady = true
        for _, p in player.Iterator() do
            if IsValid(p) and not NAA.ReadyPlayers[p:SteamID()] then
                allReady = false; break
            end
        end
        if allReady then
            NAA.Phase         = NAA.PHASE_CLASS_SELECT
            NAA.ReadyPlayers  = {}
            NAA.ClassConfirmed= {}
            NAA.DiffVotes     = {}
            BroadcastPhase()
            timer.Simple(0.1, BroadcastClassState)
        end
    end
end)

net.Receive("NAA_Ready", function(len, ply)
    -- В лобби — это кнопка Готов/Не готов
    if NAA.Phase ~= NAA.PHASE_LOBBY then return end
    local isReady = net.ReadBool()
    NAA.ReadyPlayers[ply:SteamID()] = isReady
    BroadcastLobbyState()

    -- Все готовы?
    local anyPlayer = false
    local allReady  = true
    for _, p in player.Iterator() do
        if not IsValid(p) then continue end
        anyPlayer = true
        if not NAA.ReadyPlayers[p:SteamID()] then allReady = false end
    end
    if anyPlayer and allReady then
        timer.Simple(0.5, function()
            if NAA.Phase ~= NAA.PHASE_LOBBY then return end
            NAA.Phase         = NAA.PHASE_CLASS_SELECT
            NAA.ReadyPlayers  = {}
            NAA.ClassConfirmed= {}
            NAA.DiffVotes     = {}
            BroadcastPhase()
            timer.Simple(0.1, BroadcastClassState)
        end)
    end
end)

-- ============================================================
--  NET: ВЫБОР КЛАССА (без немедленного перехода)
-- ============================================================
net.Receive("NAA_SelectClass", function(len, ply)
    if NAA.Phase ~= NAA.PHASE_CLASS_SELECT then return end
    local cid = net.ReadString()
    if not NAA.Classes[cid] then return end

    local meta    = NAA.LoadMeta(ply)
    local cls     = NAA.Classes[cid]
    local unlocks = (meta and meta.unlocks) or {}
    if cls.unlockCost > 0 and not unlocks["class_"..cid] then return end

    local pd = GetPD(ply)
    pd.class = cid
    ply:SetNWString("NAA_Class", cid)
    -- Сохраняем выбор, но не ставим confirmed
    timer.Simple(0, function() BroadcastClassState() end)
end)

-- ============================================================
--  NET: ПОДТВЕРЖДЕНИЕ КЛАССА
-- ============================================================
net.Receive("NAA_ConfirmClass", function(len, ply)
    if NAA.Phase ~= NAA.PHASE_CLASS_SELECT then return end
    local sid = ply:SteamID()
    -- Если класс не выбран — ставим survivor
    if not GetPD(ply).class or GetPD(ply).class == "" then
        GetPD(ply).class = "survivor"
        ply:SetNWString("NAA_Class", "survivor")
    end
    NAA.ClassConfirmed[sid] = true
    BroadcastClassState()

    -- Проверяем всех
    local allConfirmed = true
    for _, p in player.Iterator() do
        if IsValid(p) and not NAA.ClassConfirmed[p:SteamID()] then
            allConfirmed = false; break
        end
    end
    if allConfirmed then
        NAA.Phase = NAA.PHASE_DIFF_SELECT
        BroadcastPhase()
        timer.Simple(0.1, function()
            -- Запускаем таймер голосования (30 сек)
            NAA.DiffVotes = {}
            BroadcastDiffVoteState(30)
            local voteCountdown = 30
            timer.Create("NAA_DiffVoteTimer", 1, 30, function()
                voteCountdown = voteCountdown - 1
                BroadcastDiffVoteState(voteCountdown)
                if voteCountdown <= 0 then
                    -- Выбираем победителя
                    local counts  = {}
                    local highest = 0
                    local winner  = "normal"
                    for _, sid2 in pairs(NAA.DiffVotes) do
                        counts[sid2] = (counts[sid2] or 0) + 1
                        if counts[sid2] > highest then
                            highest = counts[sid2]
                            winner  = sid2
                        end
                    end
                    -- Если никто не голосовал — normal
                    NAA_StartGame(winner)
                end
            end)
        end)
    end
end)

-- ============================================================
--  NET: ГОЛОС ЗА СЛОЖНОСТЬ
-- ============================================================
net.Receive("NAA_VoteDiff", function(len, ply)
    if NAA.Phase ~= NAA.PHASE_DIFF_SELECT then return end
    local did = net.ReadString()
    if not NAA.Difficulties[did] then return end

    local meta    = NAA.LoadMeta(ply)
    local diff    = NAA.Difficulties[did]
    local unlocks = (meta and meta.unlocks) or {}
    if diff.unlockCost > 0 and not unlocks["diff_"..did] then return end

    NAA.DiffVotes[ply:SteamID()] = did
    BroadcastDiffVoteState(0)  -- обновляем картинку (таймер сохранится у клиентов)

    -- Все проголосовали?
    local totalPlayers = 0
    local totalVoted   = 0
    for _, p in player.Iterator() do
        if not IsValid(p) then continue end
        totalPlayers = totalPlayers + 1
        if NAA.DiffVotes[p:SteamID()] then totalVoted = totalVoted + 1 end
    end
    if totalVoted >= totalPlayers and totalPlayers > 0 then
        -- Все проголосовали — считаем немедленно
        timer.Remove("NAA_DiffVoteTimer")
        local counts  = {}
        local highest = 0
        local winner  = "normal"
        for _, vote in pairs(NAA.DiffVotes) do
            counts[vote] = (counts[vote] or 0) + 1
            if counts[vote] > highest then
                highest = counts[vote]
                winner  = vote
            end
        end
        NAA_StartGame(winner)
    end
end)

-- ============================================================
--  ЗАПУСК ИГРЫ (после голосования)
-- ============================================================
function NAA_StartGame(did)
    if NAA.Phase ~= NAA.PHASE_DIFF_SELECT then return end
    timer.Remove("NAA_DiffVoteTimer")

    if not NAA.Difficulties[did] then did = "normal" end
    NAA.Difficulty = did

    for _, p in player.Iterator() do
        if not IsValid(p) then continue end
        local chosenClass = GetPD(p).class or "survivor"
        local fresh       = NewPD()
        NAA.PlayerData[p:SteamID()] = fresh
        fresh.class = chosenClass

        local pmeta    = NAA.LoadMeta(p)
        local munlocks = (pmeta and pmeta.unlocks) or {}
        if munlocks.bonus_reroll then fresh.freeRerolls = 1 end
        if munlocks.bonus_coins  then fresh.coins = 15 end

        local diff2 = NAA.GetDiff(did)
        fresh.lives = diff2.lives
        NAA.ShotCounter[p:SteamID()] = 0

        local cls = NAA.Classes[chosenClass]
        p:Spawn()
        if munlocks.bonus_hp then
            p:SetMaxHealth(cls.hp + 25)
            p:SetHealth(cls.hp + 25)
        end

        SyncCoins(p)
        SyncLives(p)
        SyncUpgrades(p)
    end

    NAA.CurrentWave = 0
    NAA.Phase       = NAA.PHASE_WAVE
    BroadcastPhase()
    timer.Simple(0.5, function()
        NAA.StartPlayerTick()
        NAA.StartNextWave()
    end)
end

-- ============================================================
--  СОВМЕСТИМОСТЬ: одиночный NAA_SelectDifficulty
-- ============================================================
net.Receive("NAA_SelectDifficulty", function(len, ply)
    -- Фолбэк для одиночной игры (сервер с 1 игроком без голосования)
    if NAA.Phase ~= NAA.PHASE_DIFF_SELECT then return end
    local did = net.ReadString()
    if not NAA.Difficulties[did] then return end
    local count = 0
    for _ in player.Iterator() do count = count + 1 end
    if count <= 1 then
        timer.Remove("NAA_DiffVoteTimer")
        NAA_StartGame(did)
    else
        -- В мультиплеере переводим как голос
        NAA.DiffVotes[ply:SteamID()] = did
        BroadcastDiffVoteState(0)
    end
end)

-- ============================================================
--  NET: ВЫБОР АПГРЕЙДА
-- ============================================================
net.Receive("NAA_ChooseUpgrade", function(len, ply)
    if NAA.Phase ~= NAA.PHASE_BETWEEN_WAVES then return end
    local upgradeId = net.ReadString()
    local pd = GetPD(ply)

    local valid = false
    for _, cid in ipairs(pd.cardOptions or {}) do
        if cid == upgradeId then valid = true; break end
    end
    if not valid then return end

    pd.cardOptions = {}
    NAA.ApplyUpgrade(ply, upgradeId)

    BroadcastUpgradeStatus()

    -- Все выбрали?
    local allChose = true
    for _, p in player.Iterator() do
        if IsValid(p) and #(GetPD(p).cardOptions or {}) > 0 then
            allChose = false; break
        end
    end
    if allChose then
        timer.Remove("NAA_BetweenWaveTimer")
        NAA.StartNextWave()
    end
end)

net.Receive("NAA_RerollCards", function(len, ply)
    if NAA.Phase ~= NAA.PHASE_BETWEEN_WAVES then return end
    local pd   = GetPD(ply)
    local cost = 5
    if (pd.freeRerolls or 0) > 0 then pd.freeRerolls = pd.freeRerolls - 1; cost = 0 end
    if pd.coins < cost then return end
    pd.coins = pd.coins - cost
    SyncCoins(ply)
    local diff  = NAA.GetDiff(NAA.Difficulty)
    local cards = NAA.PickCards(diff.rareBonus, pd.upgrades)
    pd.cardOptions = cards
    net.Start("NAA_ShowUpgrades")
        net.WriteString(cards[1] or "")
        net.WriteString(cards[2] or "")
        net.WriteString(cards[3] or "")
        net.WriteString("")
        net.WriteInt(pd.coins, 16)
    net.Send(ply)
end)

-- ============================================================
--  ПРИНУДИТЕЛЬНЫЙ СБРОС
-- ============================================================
net.Receive("NAA_ForceReset", function(len, ply)
    NAA.ResetGame()
end)

-- ============================================================
--  GM:PlayerSpawn
-- ============================================================
function GM:PlayerSpawn(ply)
    if not IsValid(ply) then return end
    local pd = GetPD(ply)
    if not pd then return end
    if ply:GetObserverMode() ~= OBS_MODE_NONE then ply:UnSpectate() end
    local cls = NAA.Classes[pd.class or "survivor"]
    ply:SetModel("models/player/kleiner.mdl")
    ply:SetNWString("NAA_Class", pd.class or "survivor")
    ply:SetMaxHealth(cls.hp)
    ply:SetHealth(cls.hp)
    ply:SetMaxArmor(300)
    ply:SetArmor(cls.armor)
    NAA_RecalcSpeed(ply)
    ply:SetJumpPower(200)
    ply:SetNWInt("NAA_ExtraJumps", pd.upgrades.double_jump or 0)
    ply:StripWeapons()
    for _, wep in ipairs(cls.startWeapons or {}) do ply:Give(wep) end
    ply:GiveAmmo(120, "SMG1")
    ply:GiveAmmo(16,  "Buckshot")
    ply:GiveAmmo(60,  "Pistol")
    ply:GiveAmmo(30,  "AR2")
    EnsurePistolAmmo(ply)
    NAA_SyncHunterStacks(ply)
    SyncUpgrades(ply)
    SyncCoins(ply)
    SyncLives(ply)
    pd.airJumpsUsed = 0
    pd.dead = false
    pd.spectating = false
end

-- ============================================================
--  GM:PlayerDeath
-- ============================================================
function GM:PlayerDeath(ply, inflictor, attacker)
    if not IsValid(ply) then return end
    local pd = GetPD(ply)

    if pd.devGodMode then
        timer.Simple(0.1, function()
            if IsValid(ply) then ply:Spawn(); ply:SetHealth(9999) end
        end)
        return
    end

    if (pd.upgrades.apocalypse_card or 0) >= 1 and not pd.apocalypseUsed then
        pd.apocalypseUsed = true
        util.BlastDamage(ply, ply, ply:GetPos(), 600, 10000)
        local ed = EffectData(); ed:SetOrigin(ply:GetPos()); ed:SetScale(15)
        util.Effect("explosion", ed, true, true)
        timer.Simple(0.6, function()
            if IsValid(ply) then
                ply:Spawn(); ply:SetHealth(30)
                net.Start("NAA_SpecialAlert")
                    net.WriteString("АПОКАЛИПСИС! Воскрешение с 30 HP!")
                net.Send(ply)
            end
        end)
        return
    end

    if (pd.upgrades.last_chance or 0) >= 1 and not pd.lastChanceUsed then
        pd.lastChanceUsed = true
        timer.Simple(0.1, function()
            if IsValid(ply) then
                ply:Spawn(); ply:SetHealth(1)
                if (pd.synergies or {}).immortal_berserk and pd.class == "berserker" then
                    pd.immortalBerserkActive = true
                    net.Start("NAA_SpecialAlert")
                        net.WriteString("БЕССМЕРТНЫЙ БЕРСЕРК! x2.8 урона НАВСЕГДА!")
                    net.Send(ply)
                end
                net.Start("NAA_SpecialAlert")
                    net.WriteString("Последний шанс! Остался 1 HP!")
                net.Send(ply)
            end
        end)
        return
    end

    pd.lives        = math.max((pd.lives or 1) - 1, 0)
    pd.hunterStreak = 0
    pd.hunterStacks = math.max((pd.hunterStacks or 0) - 5, 0)
    pd.nextIsOneshot= false
    pd.killStreak   = 0
    SyncLives(ply)

    if pd.lives <= 0 then
        pd.dead       = true
        pd.spectating = true
        timer.Simple(0.5, function()
            if IsValid(ply) then ply:Spectate(OBS_MODE_ROAMING) end
        end)
        local anyAlive = false
        for _, p in player.Iterator() do
            if IsValid(p) and not GetPD(p).dead then anyAlive = true; break end
        end
        if not anyAlive then
            timer.Simple(2, function() NAA.GameOver() end)
        end
    else
        pd.dead = false; pd.spectating = false
    end
end

-- ============================================================
--  GM:PlayerDisconnected
-- ============================================================
function GM:PlayerDisconnected(ply)
    if IsValid(ply) then
        local sid = ply:SteamID()
        NAA.PlayerData[sid]    = nil
        NAA.ShotCounter[sid]   = nil
        NAA.ReadyPlayers[sid]  = nil
        NAA.ClassConfirmed[sid]= nil
        NAA.DiffVotes[sid]     = nil
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and ent.NecoOwner == ply then ent:Remove() end
        end
        -- Обновляем лобби
        if NAA.Phase == NAA.PHASE_LOBBY then
            BroadcastLobbyState()
        end
    end
end

function GM:ShowSpawnMenu() end
function GM:PlayerNoClip(ply) return false end

hook.Add("PostEntityCreated", "NAA_RemoveNPCWeaponDrops", function(ent)
    if not IsValid(ent) then return end
    if ent:GetClass():find("weapon_") then
        timer.Simple(0, function()
            if IsValid(ent) and not IsValid(ent:GetOwner()) then ent:Remove() end
        end)
    end
end)

hook.Add("PlayerDeath", "NAA_MedicAllyBonus", function(ply, inflictor, attacker)
    for _, other in player.Iterator() do
        if not IsValid(other) or other == ply then continue end
        local pd = GetPD(other)
        if pd.class == "medic" and other:Alive() then
            if other:GetPos():Distance(ply:GetPos()) < 600 then
                other:SetHealth(math.min(other:GetHealth() + 25, other:GetMaxHealth()))
                net.Start("NAA_SpecialAlert")
                    net.WriteString("Медик: +25 HP за смерть союзника")
                net.Send(other)
            end
        end
    end
end)

timer.Create("NAA_InfinitePistolCheck", 60, 0, function()
    for _, ply in ipairs(player.GetAll()) do EnsurePistolAmmo(ply) end
end)

hook.Add("PlayerSpawn",   "NAA_InfinitePistolOnSpawn",  function(ply) timer.Simple(0.1, function() EnsurePistolAmmo(ply) end) end)
hook.Add("WeaponEquip",   "NAA_InfinitePistolOnPickup", function(weapon, ply)
    if IsValid(weapon) and weapon:GetClass():find("pistol") then
        timer.Simple(0.1, function() EnsurePistolAmmo(ply) end)
    end
end)

concommand.Add("naa_debug", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    NAA.DebugMode = not NAA.DebugMode
    print("[NAA] Debug mode: "..tostring(NAA.DebugMode))
    if IsValid(ply) then ply:ChatPrint("[NAA] Debug mode: "..tostring(NAA.DebugMode)) end
end)

concommand.Add("naa_skipwave", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    if not GetConVar("sv_cheats"):GetBool() then return end
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and (ent.IsNecoArc or ent:GetClass():find("neco_")) then ent:Remove() end
    end
    NAA.AliveEnemies = 0
end)

concommand.Add("naa_godmode", function(ply)
    if not IsValid(ply) then return end
    if not GetConVar("sv_cheats"):GetBool() then ply:ChatPrint("[NAA] Requires sv_cheats 1"); return end
    local pd = GetPD(ply); pd.devGodMode = not pd.devGodMode
    if pd.devGodMode then ply:SetHealth(9999); ply:SetMaxHealth(9999); ply:SetArmor(500) end
    ply:ChatPrint("[NAA] God mode: "..tostring(pd.devGodMode))
end)

concommand.Add("naa_givecoins", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not GetConVar("sv_cheats"):GetBool() then ply:ChatPrint("[NAA] Requires sv_cheats 1"); return end
    NAA_AddCoins(ply, tonumber(args[1]) or 100)
end)

concommand.Add("naa_setwave", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    if not GetConVar("sv_cheats"):GetBool() then return end
    local wave = tonumber(args[1]); if not wave then return end
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and (ent.IsNecoArc or ent:GetClass():find("neco_")) then ent:Remove() end
    end
    NAA.AliveEnemies = 0; NAA.CurrentWave = wave - 1
    timer.Simple(0.5, function() NAA.StartNextWave() end)
end)

concommand.Add("naa_status", function(ply)
    print("[NAA] Phase="..tostring(NAA.Phase))
    print("[NAA] Wave="..tostring(NAA.CurrentWave))
    print("[NAA] Alive="..tostring(NAA.AliveEnemies))
    print("[NAA] Difficulty="..tostring(NAA.Difficulty))
    for _, p in player.Iterator() do
        if IsValid(p) then
            local pd = GetPD(p)
            print(string.format("  %s | class=%s lives=%d kills=%d coins=%d",
                p:Nick(), pd.class or "?", pd.lives or 0, pd.kills or 0, pd.coins or 0))
        end
    end
end)

-- Покупка 4-й карты (дополнительный выбор улучшения)
net.Receive("NAA_BuyExtraCard", function(len, ply)
    if not IsValid(ply) then return end
    if NAA.Phase ~= NAA.PHASE_BETWEEN_WAVES then return end

    local pd = NAA.GetPD(ply)
    if not pd then return end

    -- Проверяем, что игрок ещё не получил 4 карты
    if #(pd.cardOptions or {}) >= 4 then return end

    local cost = 15
    if (pd.coins or 0) < cost then return end

    -- Списываем монеты
    pd.coins = pd.coins - cost
    net.Start("NAA_SyncCoins")
        net.WriteInt(pd.coins, 16)
    net.Send(ply)

    -- Генерируем 4-ю карту
    local diff = NAA.GetDiff(NAA.Difficulty)
    local cards = NAA.PickCards(diff.rareBonus, pd.upgrades)
    if #cards < 4 then
        -- Если PickCards вернула меньше 4, добираем случайными картами
        local allUpgrades = {}
        for id, upg in pairs(NAA.Upgrades) do
            if (pd.upgrades[id] or 0) < (upg.maxStacks or 1) then
                allUpgrades[#allUpgrades + 1] = id
            end
        end
        while #cards < 4 and #allUpgrades > 0 do
            local randId = allUpgrades[math.random(#allUpgrades)]
            cards[#cards + 1] = randId
            -- удаляем из allUpgrades, чтобы не повторяться (опционально)
        end
    end

    pd.cardOptions = cards

    -- Отправляем клиенту обновлённый набор карт (уже 4 штуки)
    net.Start("NAA_ShowUpgrades")
        net.WriteString(cards[1] or "")
        net.WriteString(cards[2] or "")
        net.WriteString(cards[3] or "")
        net.WriteString(cards[4] or "")  -- 4-я карта
        net.WriteInt(pd.coins, 16)
    net.Send(ply)
end)

hook.Add("PostGamemodeLoaded", "NAA_Init", function()
    print("[NAA] Neco Arc Apocalypse — SERVER LOADED")
    print("[NAA] Multiplayer ready: lobby, class vote, diff vote")
end)
