include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")
local matBeam  = Material("sprites/laserbeam")

-- =========================================================
--  ОГНЕННЫЙ СЛЕД при броске (только когда KamikazeDashing)
-- =========================================================
local fireTrails = {}
local TRAIL_LEN  = 16
local TRAIL_STEP = 0.035

hook.Add("Think", "Kamikaze_TrailRecord", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_kamikaze")) do
        if not IsValid(ent) then continue end
        if not ent:GetNWBool("KamikazeDashing", false) then
            -- Сброс истории, когда не в рывке
            fireTrails[ent:EntIndex()] = nil
            continue
        end

        local idx  = ent:EntIndex()
        if not fireTrails[idx] then fireTrails[idx] = {} end
        local hist = fireTrails[idx]

        if (hist.lastTime or 0) + TRAIL_STEP < now then
            hist.lastTime = now
            table.insert(hist, 1, {
                pos  = ent:GetPos() + Vector(0, 0, 20),
                t    = now
            })
            if #hist > TRAIL_LEN then table.remove(hist) end
        end
    end
    for idx, _ in pairs(fireTrails) do
        if not IsValid(Entity(idx)) then fireTrails[idx] = nil end
    end
end)

-- =========================================================
--  ВЗРЫВ-ВСПЫШКА при смерти
-- =========================================================
hook.Add("EntityRemoved", "Kamikaze_DeathFlash", function(ent)
    if not IsValid(ent) then return end
    if ent:GetClass() ~= "neco_kamikaze" then return end

    local pos = ent:GetPos()
    for i = 1, 16 do
        timer.Simple(i * 0.05, function()
            local ef = EffectData()
            ef:SetOrigin(pos + Vector(
                math.random(-80, 80),
                math.random(-80, 80),
                math.random(0, 70)))
            ef:SetScale(1.8)
            util.Effect("Sparks", ef)
        end)
    end
end)

-- =========================================================
--  PostDraw: огненный шлейф
-- =========================================================
hook.Add("PostDrawTranslucentRenderables", "Kamikaze_FireTrail", function()
    local now = CurTime()

    for _, ent in ipairs(ents.FindByClass("neco_kamikaze")) do
        if not IsValid(ent) then continue end
        if not ent:GetNWBool("KamikazeDashing", false) then continue end

        local hist = fireTrails[ent:EntIndex()]
        if not hist or #hist == 0 then continue end

        -- Огненные клубы по истории позиций
        render.SetMaterial(matSmoke)
        for i, entry in ipairs(hist) do
            local frac  = i / #hist
            local age   = now - entry.t
            local alpha = math.floor(Lerp(frac, 160, 0))
            local sz    = Lerp(frac, 18, 80)
            local drift = age * 35
            local p     = entry.pos + Vector(0, 0, drift)

            -- Градиент: оранжевый → красный → тёмный
            local r = math.floor(255)
            local g = math.floor(Lerp(frac, 120, 20))
            render.DrawSprite(p, sz, sz, Color(r, g, 0, alpha))
        end

        -- Аддитивное свечение вокруг рывка
        local t     = now
        local pulse = 0.5 + 0.5 * math.sin(t * 18)
        local center = ent:GetPos() + ent:OBBCenter()
        render.SetMaterial(matGlow)
        render.DrawSphere(center, 48 + pulse * 14, 12, 12,
            Color(255, 100, 10, math.floor(140 + pulse * 80)))
        render.DrawSphere(center, 70 + pulse * 18, 12, 12,
            Color(255, 60, 5, math.floor(70 + pulse * 50)))
        render.DrawSprite(center, 130 + pulse * 30, 130 + pulse * 30,
            Color(255, 80, 10, math.floor(pulse * 110 + 30)))

        render.SetMaterial(matGlow)
    end
end)

-- =========================================================
--  ENT:Draw
-- =========================================================
function ENT:Draw()
    local t       = CurTime()
    local dashing = self:GetNWBool("KamikazeDashing", false)

    if dashing then
        -- Рывок: насыщенный огненно-оранжевый, быстрое мерцание
        local pulse = 0.5 + 0.5 * math.sin(t * 16)
        render.SetColorModulation(1.0, 0.28 + pulse * 0.10, 0.0)
        render.SetBlend(0.85 + pulse * 0.15)
        self:DrawModel()
        render.SetBlend(1)
    else
        -- Обычный: тёмно-оранжевый тлеющий оттенок
        local coal  = 0.5 + 0.5 * math.sin(t * 1.8)  -- медленное угасание
        render.SetColorModulation(0.82, 0.22 + coal * 0.08, 0.0)
        render.SetBlend(1)
        self:DrawModel()

        -- Тихий тлеющий спрайт
        local center = self:GetPos() + self:OBBCenter()
        render.SetMaterial(matGlow)
        render.DrawSprite(center, 30 + coal * 8, 30 + coal * 8,
            Color(255, 100, 10, math.floor(coal * 40 + 15)))
    end

    render.SetColorModulation(1, 1, 1)

    -- ── Опасный пульс во время рывка ───────────────────────
    if dashing then
        local pulse  = 0.5 + 0.5 * math.sin(t * 14)
        local center = self:GetPos() + self:OBBCenter()

        render.SetMaterial(matGlow)

        -- «Предупреждающее» кольцо у ног, расширяется и сжимается
        local groundPos = self:GetPos() + Vector(0, 0, 6)
        local ringR = 55 + pulse * 25
        render.DrawSphere(groundPos, ringR, 12, 12,
            Color(255, 60, 0, math.floor(90 + pulse * 70)))

        -- 3 вращающихся луча вокруг тела — «горящие искры»
        render.SetMaterial(matBeam)
        for i = 1, 3 do
            local ang = t * 200 + i * 120
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            render.DrawBeam(center, center + dir * (45 + pulse * 15), 3 + pulse, 0, 1,
                Color(255, 100 + math.floor(pulse * 60), 0,
                    math.floor(180 + pulse * 60)))
        end
        render.SetMaterial(matGlow)
    end
end
