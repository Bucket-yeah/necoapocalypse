include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")
local matBeam  = Material("sprites/laserbeam")

-- =========================================================
--  Шлейф скорости
-- =========================================================
local trailHistory = {}
local TRAIL_LEN  = 12
local TRAIL_STEP = 0.04

hook.Add("Think", "Runner_TrailRecord", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_runner")) do
        if not IsValid(ent) then continue end
        local idx  = ent:EntIndex()
        if not trailHistory[idx] then trailHistory[idx] = {} end
        local hist = trailHistory[idx]

        if (hist.lastTime or 0) + TRAIL_STEP < now then
            hist.lastTime = now
            local vel = ent:GetVelocity():Length()
            table.insert(hist, 1, {
                pos  = ent:GetPos() + Vector(0, 0, 22),
                t    = now,
                fast = vel > 120
            })
            if #hist > TRAIL_LEN then table.remove(hist) end
        end
    end
    for idx, _ in pairs(trailHistory) do
        if not IsValid(Entity(idx)) then trailHistory[idx] = nil end
    end
end)

-- =========================================================
--  Аура и линии стаи
-- =========================================================
hook.Add("PostDrawTranslucentRenderables", "Runner_TrailAndPack", function()
    local now = CurTime()
    local runners = ents.FindByClass("neco_runner")

    for _, ent in ipairs(runners) do
        if not IsValid(ent) then continue end

        local hist   = trailHistory[ent:EntIndex()]
        local center = ent:GetPos() + ent:OBBCenter()
        local t      = now

        -- ── Шлейф ──────────────────────────────────────────
        if hist and #hist > 0 then
            render.SetMaterial(matSmoke)
            for i, entry in ipairs(hist) do
                local frac  = i / #hist
                local alpha = math.floor(Lerp(frac, entry.fast and 120 or 65, 0))
                local sz    = Lerp(frac, entry.fast and 22 or 12, entry.fast and 60 or 32)
                local drift = (now - entry.t) * 10
                local p     = entry.pos + Vector(0, 0, drift)
                local col   = entry.fast
                    and Color(70, 210, 255, alpha)
                    or  Color(45, 150, 210, alpha)
                render.DrawSprite(p, sz, sz, col)
            end
        end

        -- ── Соединяющие линии к КАЖДОМУ соседнему бегуну ──
        --    Исправление: pack >= 1 (не 2), без break
        local lineCount = 0
        for _, other in ipairs(runners) do
            if not IsValid(other) or other == ent then continue end
            local dist = ent:GetPos():Distance(other:GetPos())
            if dist > 300 then continue end

            local s = ent:GetPos()   + Vector(0, 0, 28)
            local e = other:GetPos() + Vector(0, 0, 28)

            -- Яркость линии зависит от дистанции
            local proximity = 1 - (dist / 300)
            local lineAlpha = math.floor(60 + proximity * 100)

            render.SetMaterial(matBeam)
            -- Внешнее свечение линии
            render.DrawBeam(s, e, 3, 0, 1,
                Color(60, 190, 255, math.floor(lineAlpha * 0.4)))
            -- Основная линия
            render.DrawBeam(s, e, 1.5, 0, 1,
                Color(100, 220, 255, lineAlpha))
            lineCount = lineCount + 1
        end

        -- ── Аура стаи: яркость растёт с количеством соседей ──
        if lineCount > 0 then
            local pulse  = 0.5 + 0.5 * math.sin(t * 4 + ent:EntIndex() * 0.7)
            local aSize  = math.min(lineCount, 5) / 5

            render.SetMaterial(matGlow)
            render.DrawSphere(center, 20 + aSize * 18, 8, 8,
                Color(50, 190, 255,
                    math.floor((45 + aSize * 70) * (0.7 + 0.3 * pulse))))
            render.DrawSprite(center, 55 + aSize * 45, 55 + aSize * 45,
                Color(70, 210, 255,
                    math.floor((30 + aSize * 55) * (0.6 + 0.4 * pulse))))
        end
    end

    render.SetMaterial(matGlow)
end)

-- =========================================================
--  ENT:Draw
-- =========================================================
function ENT:Draw()
    local t   = CurTime()
    local vel = self:GetVelocity():Length()
    local fast = vel > 120

    if fast then
        render.SetColorModulation(0.28, 0.85, 1.0)
    else
        render.SetColorModulation(0.22, 0.68, 0.90)
    end
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    local center = self:GetPos() + self:OBBCenter()
    local pulse  = 0.5 + 0.5 * math.sin(t * 5 + self:EntIndex() * 1.2)

    render.SetMaterial(matGlow)
    if fast then
        render.DrawSprite(center, 40 + pulse * 12, 40 + pulse * 12,
            Color(60, 210, 255, math.floor(pulse * 90 + 35)))
        local back = center - self:GetForward() * 20
        render.DrawSprite(back, 26 + pulse * 7, 26 + pulse * 7,
            Color(80, 220, 255, math.floor(pulse * 65 + 25)))
    else
        render.DrawSprite(center, 28 + pulse * 6, 28 + pulse * 6,
            Color(50, 170, 220, math.floor(pulse * 38 + 12)))
    end
end
