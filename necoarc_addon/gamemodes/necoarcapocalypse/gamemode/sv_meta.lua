-- ============================================================
--  NECO ARC APOCALYPSE — sv_meta.lua  (SERVER)
--  Исправлено: добавлен net.Receive для NAA_BuyMeta
-- ============================================================

local DATA_DIR = "necoarc/"

file.CreateDir(DATA_DIR)

local MetaItems = {
    class_medic    = { name="Класс: Медик",               neoCost=50  },
    class_berserker= { name="Класс: Берсерк",             neoCost=75  },
    class_hunter   = { name="Класс: Охотник",             neoCost=60  },
    bonus_reroll   = { name="Стартовый бесплатный реролл",neoCost=30  },
    bonus_hp       = { name="Стартовый бонус: +25 HP",    neoCost=40  },
    bonus_coins    = { name="Стартовый бонус: +15 монет", neoCost=25  },
    bonus_rare     = { name="Гарантированная карта",      neoCost=60  },
    diff_extreme   = { name="Сложность: Экстрим",         neoCost=50  },
    diff_apocalypse= { name="Сложность: Апокалипсис",     neoCost=200 },
    synergy_panel  = { name="Панель синергий в магазине", neoCost=20  },
}

function NAA.LoadMeta(ply)
    local sid  = ply:SteamID64()
    local path = DATA_DIR .. "meta_" .. sid .. ".json"
    if not file.Exists(path, "DATA") then
        return { neo_coins=0, unlocks={}, records={best_wave=0,best_kills=0,best_diff=""}, total_runs=0, total_kills=0 }
    end
    local raw = file.Read(path, "DATA")
    return util.JSONToTable(raw) or { neo_coins=0, unlocks={}, records={best_wave=0,best_kills=0,best_diff=""}, total_runs=0, total_kills=0 }
end

function NAA.SaveMeta(ply, meta)
    local sid  = ply:SteamID64()
    local path = DATA_DIR .. "meta_" .. sid .. ".json"
    file.Write(path, util.TableToJSON(meta))
end

function NAA.AddNeoCoins(ply, amount)
    local meta = NAA.LoadMeta(ply)
    meta.neo_coins = (meta.neo_coins or 0) + amount
    NAA.SaveMeta(ply, meta)
    net.Start("NAA_MetaData")
        net.WriteString(util.TableToJSON(meta))
    net.Send(ply)
end

function NAA.PurchaseMeta(ply, itemId)
    local item = MetaItems[itemId]
    if not item then return false end

    local meta = NAA.LoadMeta(ply)
    meta.unlocks = meta.unlocks or {}

    if meta.unlocks[itemId] then
        return false -- уже куплено
    end

    if (meta.neo_coins or 0) < item.neoCost then
        return false -- не хватает монет
    end

    meta.neo_coins  = meta.neo_coins - item.neoCost
    meta.unlocks[itemId] = true
    NAA.SaveMeta(ply, meta)

    -- Отправляем обновлённые мета-данные клиенту
    net.Start("NAA_MetaData")
        net.WriteString(util.TableToJSON(meta))
    net.Send(ply)

    return true
end

hook.Add("NAA_RunEnd", "NAA_SaveRecord", function(ply, wave, kills, diff)
    local meta = NAA.LoadMeta(ply)
    meta.records = meta.records or {}
    if wave > (meta.records.best_wave or 0) then
        meta.records.best_wave = wave
        meta.records.best_diff = diff
    end
    if kills > (meta.records.best_kills or 0) then
        meta.records.best_kills = kills
    end
    meta.total_runs  = (meta.total_runs  or 0) + 1
    meta.total_kills = (meta.total_kills or 0) + kills
    NAA.SaveMeta(ply, meta)
    net.Start("NAA_MetaData")
        net.WriteString(util.TableToJSON(meta))
    net.Send(ply)
end)

-- ============================================================
--  ОТПРАВКА МЕТА-ДАННЫХ КЛИЕНТУ ПО ЗАПРОСУ
-- ============================================================
net.Receive("NAA_RequestMeta", function(len, ply)
    local meta = NAA.LoadMeta(ply)
    net.Start("NAA_MetaData")
        net.WriteString(util.TableToJSON(meta))
    net.Send(ply)
end)

-- ============================================================
--  ПОКУПКА В МАГАЗИНЕ (обработчик клиентского запроса)
-- ============================================================
net.Receive("NAA_BuyMeta", function(len, ply)
    local itemId = net.ReadString()
    local success = NAA.PurchaseMeta(ply, itemId)
    if success then
        net.Start("NAA_BetweenWave")
            net.WriteString(" Куплено: " .. (MetaItems[itemId] and MetaItems[itemId].name or itemId))
        net.Send(ply)
    else
        net.Start("NAA_BetweenWave")
            net.WriteString(" Не удалось купить предмет.")
        net.Send(ply)
    end
end)

-- Отправка мета-данных сразу после входа игрока
hook.Add("PlayerInitialSpawn", "NAA_SendMetaOnJoin", function(ply)
    timer.Simple(0.5, function()
        if IsValid(ply) then
            local meta = NAA.LoadMeta(ply)
            net.Start("NAA_MetaData")
                net.WriteString(util.TableToJSON(meta))
            net.Send(ply)
        end
    end)
end)