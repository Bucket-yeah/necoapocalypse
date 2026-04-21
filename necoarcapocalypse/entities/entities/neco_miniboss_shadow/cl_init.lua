include("shared.lua")

local matSmoke = Material("particle/particle_smokegrenade")
local matGlow  = Material("sprites/light_glow02_add")
local matBeam  = Material("sprites/laserbeam")

-- =========================================================
--  Шлейф — история позиций
-- =========================================================
local trailHistory = {}
local TRAIL_LEN  = 22      -- длиннее — шлейф заметнее
local TRAIL_STEP = 0.04    -- чаще — гуще

hook.Add("Think", "Shadow_TrailRecord", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_miniboss_shadow")) do
        if not IsValid(ent) then continue end
        local idx  = ent:EntIndex()
        if not trailHistory[idx] then trailHistory[idx] = {} end
        local hist = trailHistory[idx]

        if (hist.lastTime or 0) + TRAIL_STEP < now then
            hist.lastTime = now
            table.insert(hist, 1, {
                pos = ent:GetPos() + Vector(0, 0, 30),
                t   = now
            })
            if #hist > TRAIL_LEN then table.remove(hist) end
        end
    end
    for idx, _ in pairs(trailHistory) do
        if not IsValid(Entity(idx)) then trailHistory[idx] = nil end
    end
end)

-- =========================================================
--  ДЕТЕКТОР ТЕЛЕПОРТАЦИИ — клиентский, без net message
--  (Сервер не посылает NAA_ShadowTeleport, поэтому
--   определяем прыжок позиции самостоятельно)
-- =========================================================
local TELEPORT_JUMP_SQ = 150 * 150   -- если за кадр прыгнул > 150 юнитов
local teleportPuffs = {}             -- { pos, t }

hook.Add("Think", "Shadow_TeleportDetect", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_miniboss_shadow")) do
        if not IsValid(ent) then continue end
        local idx    = ent:EntIndex()
        local curPos = ent:GetPos()

        if ent._lastKnownPos then
            local distSq = curPos:DistToSqr(ent._lastKnownPos)
            if distSq > TELEPORT_JUMP_SQ then
                -- Телепорт зафиксирован: дым на старом и новом месте
                table.insert(teleportPuffs, { pos = ent._lastKnownPos, t = now })
                table.insert(teleportPuffs, { pos = curPos,             t = now })
                -- Очищаем шлейф — после прыжка он не нужен
                trailHistory[idx] = nil
            end
        end
        ent._lastKnownPos = curPos
    end

    -- Чистим старые вспышки (живут 2.5 сек)
    for i = #teleportPuffs, 1, -1 do
        if now - teleportPuffs[i].t > 2.5 then table.remove(teleportPuffs, i) end
    end
end)

-- =========================================================
--  PostDraw: шлейф + дым телепорта
-- =========================================================
hook.Add("PostDrawTranslucentRenderables", "Shadow_SmokeEffects", function()
    local now = CurTime()

    -- 1. Шлейф из тёмного дыма (фиолетово-серый, хорошо виден)
    for _, ent in ipairs(ents.FindByClass("neco_miniboss_shadow")) do
        if not IsValid(ent) then continue end
        local hist = trailHistory[ent:EntIndex()]
        if not hist then continue end

        render.SetMaterial(matSmoke)
        for i, entry in ipairs(hist) do
            local frac  = i / #hist              -- 0=свежий, 1=старый
            local alpha = math.floor(Lerp(frac, 160, 0))   -- было 110, теперь 160
            local size  = Lerp(frac, 30, 110)               -- было 24→80, теперь крупнее
            local age   = now - entry.t
            local drift = age * 16

            -- Небольшое боковое качание
            local wave = math.sin(i * 1.7 + now * 0.8) * 8
            local p = entry.pos + Vector(wave, wave * 0.5, drift)

            -- Тёмно-фиолетовый оттенок (был почти чёрный — невидим)
            render.DrawSprite(p, size, size, Color(25, 5, 45, alpha))
        end
    end

    -- 2. Взрыв дыма при телепортации
    render.SetMaterial(matSmoke)
    for _, puff in ipairs(teleportPuffs) do
        local age  = now - puff.t
        local frac = age / 2.5

        -- 16 клубов дыма, расширяются и поднимаются
        for i = 1, 16 do
            local seed = i * 137.5            -- квази-случайный угол
            local ang  = seed % 360
            local r    = Lerp(frac, 10, 120)
            local p    = puff.pos + Vector(
                math.cos(math.rad(ang)) * r,
                math.sin(math.rad(ang)) * r,
                age * 35 + i * 3)
            local a = math.floor(Lerp(frac, 210, 0))
            local sz = Lerp(frac, 20, 100)
            render.DrawSprite(p, sz, sz, Color(20, 0, 38, a))
        end
    end

    -- Фиолетовые вспышки-спрайты в точках телепорта
    render.SetMaterial(matGlow)
    for _, puff in ipairs(teleportPuffs) do
        local age  = now - puff.t
        local frac = math.min(age / 0.4, 1)
        if frac >= 1 then continue end
        local a   = math.floor(Lerp(frac, 220, 0))
        local sz  = Lerp(frac, 60, 200)
        render.DrawSprite(puff.pos + Vector(0, 0, 40), sz, sz,
            Color(120, 0, 200, a))
    end

    render.SetMaterial(matGlow)
end)

-- =========================================================
--  ENT:Draw
-- =========================================================
function ENT:Draw()
    local shieldActive = self:GetNWBool("ShadowShield", false)
    local alpha        = self:GetNWInt("ShadowAlpha", 180)
    local t            = CurTime()

    local r, g, b
    if shieldActive then
        r, g, b = 15, 0, 45
        alpha   = 220
    else
        r, g, b = 65, 0, 100
    end

    render.SetColorModulation(r / 255, g / 255, b / 255)
    render.SetBlend(alpha / 255)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)
    render.SetBlend(1)

    local pulse  = 0.5 + 0.5 * math.sin(t * 1.8)
    local center = self:GetPos() + self:OBBCenter()

    render.SetMaterial(matGlow)
    render.DrawSprite(center, 60 + pulse * 18, 60 + pulse * 18,
        Color(90, 0, 155, math.floor(pulse * 60 + 25)))

    if shieldActive then
        local p2 = 0.5 + 0.5 * math.sin(t * 5)
        render.SetMaterial(matGlow)
        render.DrawSphere(center, 65 + p2 * 8, 16, 16,
            Color(100, 0, 180, math.floor(130 + p2 * 50)))
        render.DrawSphere(center, 80 + p2 * 10, 16, 16,
            Color(80, 0, 160, math.floor(60 + p2 * 30)))

        render.SetMaterial(matBeam)
        for i = 1, 3 do
            local ang = t * 90 + i * 120
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            render.DrawBeam(center, center + dir * 76, 2, 0, 1,
                Color(130, 0, 220, math.floor(160 + p2 * 60)))
        end
        render.SetMaterial(matGlow)
    end
end

hook.Add("Think", "Shadow_FearEffect", function()
    local ply = LocalPlayer()
    if IsValid(ply) and ply.ShadowFearActive then
        ply:ScreenFade(SCREENFADE.MODULATE, Color(0, 0, 0, 100), 0.1, 0)
    end
end)
