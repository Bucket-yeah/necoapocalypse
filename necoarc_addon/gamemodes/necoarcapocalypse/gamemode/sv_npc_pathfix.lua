-- sv_npc_pathfix.lua
-- Авто-телепортация застрявших врагов (работает без навмеша)
-- Исправлено: надёжный поиск земли, телепорт к игроку

local CHECK_INTERVAL = 2.0      -- проверка каждые 2 секунды
local STUCK_TIMEOUT = 5.0       -- если позиция не менялась 5 секунд — телепорт
local MIN_PLAYER_DIST = 400     -- не телепортируем, если враг уже близко

-- Храним предыдущую позицию и время для каждого NPC
local StuckData = {}

-- Надёжный поиск земли рядом с игроком (для телепорта)
local function FindEmergencyGroundPos(ply)
    if not IsValid(ply) then return nil end
    local plyPos = ply:GetPos()
    for attempt = 1, 30 do
        local angle = math.random() * 2 * math.pi
        local dist = math.random(300, 600)
        local testPos = plyPos + Vector(math.cos(angle) * dist, math.sin(angle) * dist, 0)

        local tr = util.TraceLine({
            start  = testPos + Vector(0, 0, 300),
            endpos = testPos - Vector(0, 0, 300),
            mask   = MASK_SOLID_BRUSHONLY
        })
        if tr.Hit and not tr.StartSolid then
            local ground = tr.HitPos + Vector(0, 0, 10)
            -- Проверяем, что над головой нет препятствий
            local trUp = util.TraceLine({
                start  = ground,
                endpos = ground + Vector(0, 0, 72),
                mask   = MASK_SOLID
            })
            if not trUp.Hit then
                return ground
            end
        end
    end
    -- Fallback — прямо на игрока
    return plyPos + Vector(0, 0, 32)
end

hook.Add("OnNPCKilled", "NAA_ClearStuckData", function(npc)
    if npc then
        StuckData[npc] = nil
    end
end)

timer.Create("NAA_CheckStuckNPC", CHECK_INTERVAL, 0, function()
    for _, npc in ipairs(ents.GetAll()) do
        if not IsValid(npc) then continue end
        if not (npc.IsNecoArc or npc.IsNecoBoss or npc.IsMiniBoss) then continue end
        if npc:Health() <= 0 then continue end

        -- Найти ближайшего живого игрока
        local nearestPlayer = nil
        local nearestDist = math.huge
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local dist = npc:GetPos():Distance(ply:GetPos())
                if dist < nearestDist then
                    nearestDist = dist
                    nearestPlayer = ply
                end
            end
        end
        if not nearestPlayer then continue end

        -- Если враг уже рядом с игроком — не трогаем
        if nearestDist < MIN_PLAYER_DIST then
            StuckData[npc] = nil
            continue
        end

        local currentPos = npc:GetPos()
        local data = StuckData[npc]

        if not data then
            -- Первый раз видим этого NPC
            StuckData[npc] = { pos = currentPos, time = CurTime() }
        else
            -- Проверяем, изменилась ли позиция (сравниваем квадрат расстояния)
            local distMoved = data.pos:DistToSqr(currentPos)
            if distMoved > 400 then  -- сдвинулся более чем на 20 юнитов
                -- Обновляем данные
                data.pos = currentPos
                data.time = CurTime()
            else
                -- Стоит на месте
                if CurTime() - data.time > STUCK_TIMEOUT then
                    -- Телепортируем ближе к игроку
                    local newPos = FindEmergencyGroundPos(nearestPlayer)
                    if newPos then
                        npc:SetPos(newPos)
                        if NAA.DebugMode then
                            print("[NAA] Teleported stuck NPC", npc, "to player", nearestPlayer:Nick())
                        end
                        -- Сбросить данные после телепорта
                        StuckData[npc] = nil
                        -- Визуальный эффект (опционально)
                        local ed = EffectData()
                        ed:SetOrigin(newPos)
                        ed:SetScale(1)
                        util.Effect("Sparks", ed)
                    end
                end
            end
        end
    end
end)