include("shared.lua")

local matSmoke = Material("particle/particle_smokegrenade")
local matGlow  = Material("sprites/light_glow02_add")

-- История позиций для дымового шлейфа
local trailHistory = {}  -- [entIndex] = { {pos, time}, ... }
local TRAIL_LEN    = 12
local TRAIL_STEP   = 0.06   -- сек между точками

hook.Add("Think", "Ghost_TrailRecord", function()
    for _, ent in ipairs(ents.FindByClass("neco_ghost")) do
        if not IsValid(ent) then continue end
        local idx = ent:EntIndex()
        if not trailHistory[idx] then trailHistory[idx] = {} end
        local hist = trailHistory[idx]
        local now  = CurTime()

        if (hist.lastTime or 0) + TRAIL_STEP < now then
            hist.lastTime = now
            table.insert(hist, 1, { pos = ent:GetPos() + Vector(0, 0, 30), t = now })
            if #hist > TRAIL_LEN then table.remove(hist) end
        end
    end
    -- Чистим записи удалённых сущностей
    for idx, _ in pairs(trailHistory) do
        if not IsValid(Entity(idx)) then trailHistory[idx] = nil end
    end
end)

hook.Add("PostDrawTranslucentRenderables", "Ghost_SmokeTrail", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_ghost")) do
        if not IsValid(ent) then continue end
        local idx  = ent:EntIndex()
        local hist = trailHistory[idx]
        if not hist then continue end

        render.SetMaterial(matSmoke)
        for i, entry in ipairs(hist) do
            local age    = now - entry.t
            local frac   = i / #hist           -- 0 (свежий) → 1 (старый)
            local alpha  = math.floor(Lerp(frac, 90, 0))
            local size   = Lerp(frac, 18, 60)
            -- Дрейф вверх по мере старения
            local p = entry.pos + Vector(0, 0, age * 12)
            render.DrawSprite(p, size, size, Color(15, 0, 25, alpha))
        end
        render.SetMaterial(matGlow)
    end
end)

function ENT:Draw()
    local phasing = self:GetNWBool("GhostPhasing", false)

    if phasing then
        -- В фазе: почти невидимый (alpha 0.12)
        render.SetColorModulation(0.65, 0.65, 1.0)
        render.SetBlend(0.12)
        self:DrawModel()
        render.SetBlend(1)
    else
        -- Вне фазы: полупрозрачный сиреневый (alpha ~0.55)
        render.SetColorModulation(0.65, 0.60, 1.0)
        render.SetBlend(0.55)
        self:DrawModel()
        render.SetBlend(1)

        -- Мягкое сиреневое свечение вне фазы
        local pulse = 0.5 + 0.5 * math.sin(CurTime() * 2)
        local pos   = self:GetPos() + self:OBBCenter()
        render.SetMaterial(matGlow)
        render.DrawSprite(pos, 70, 70, Color(160, 100, 255, math.floor(pulse * 50 + 20)))
    end
    render.SetColorModulation(1, 1, 1)
end

hook.Add("EntityFireBullets", "Ghost_DebuffSpread", function(ent, data)
    if IsValid(ent) and ent:IsPlayer()
        and ent.NecoGhostDebuffUntil and ent.NecoGhostDebuffUntil > CurTime() then
        data.Spread = data.Spread * 5
        return true
    end
end)
