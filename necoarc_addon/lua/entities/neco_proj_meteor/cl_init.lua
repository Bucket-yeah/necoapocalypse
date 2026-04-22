include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")
local matBeam  = Material("sprites/laserbeam")

-- История позиций метеоритов для трейла
local meteorTrails = {}

hook.Add("Think", "Meteor_TrailUpdate", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_proj_meteor")) do
        if not IsValid(ent) then continue end
        local idx = ent:EntIndex()
        if not meteorTrails[idx] then meteorTrails[idx] = { parts = {}, lastT = 0 } end
        local trail = meteorTrails[idx]
        if trail.lastT + 0.032 < now then
            trail.lastT = now
            table.insert(trail.parts, 1, { pos = ent:GetPos(), t = now })
            if #trail.parts > 18 then table.remove(trail.parts) end
        end
    end
    for idx, _ in pairs(meteorTrails) do
        if not IsValid(Entity(idx)) then meteorTrails[idx] = nil end
    end
end)

hook.Add("PostDrawTranslucentRenderables", "Meteor_TrailDraw", function()
    local now = CurTime()

    for _, ent in ipairs(ents.FindByClass("neco_proj_meteor")) do
        if not IsValid(ent) then continue end
        local trail = meteorTrails[ent:EntIndex()]
        if not trail or #trail.parts < 2 then continue end

        -- Дымовой шлейф (тёмный → оранжевый)
        render.SetMaterial(matSmoke)
        for i, entry in ipairs(trail.parts) do
            local frac = i / #trail.parts   -- 0 = свежий, 1 = старый
            local a    = math.floor(Lerp(frac, 210, 0))
            local sz   = Lerp(frac, 28, 160)
            -- Цвет: яркий оранжевый спереди, тёмный дым позади
            local r = math.floor(Lerp(frac, 200, 50))
            local g = math.floor(Lerp(frac, 85,  20))
            local b = math.floor(Lerp(frac, 12,   8))
            render.DrawSprite(entry.pos, sz, sz, Color(r, g, b, a))
        end

        -- Огненный beam-core (ближние точки)
        local endIdx = math.min(6, #trail.parts)
        if endIdx >= 2 then
            render.SetMaterial(matBeam)
            -- Широкий оранжевый
            render.DrawBeam(trail.parts[1].pos, trail.parts[endIdx].pos, 16, 0, 1,
                Color(255, 110, 20, 200))
            -- Узкое жёлтое ядро
            render.DrawBeam(trail.parts[1].pos, trail.parts[endIdx].pos, 5, 0, 1,
                Color(255, 230, 110, 230))
            -- Тонкое белое ядро
            render.DrawBeam(trail.parts[1].pos, trail.parts[endIdx].pos, 1.5, 0, 1,
                Color(255, 255, 220, 240))
        end

        render.SetMaterial(matGlow)
    end
end)

function ENT:Draw()
    self._drawPos = self:GetPos()
    local t     = CurTime()
    local pulse  = 0.5 + 0.5 * math.sin(t * 14)
    local pulse2 = 0.5 + 0.5 * math.sin(t * 8.5 + 1.1)

    -- Раскалённая порода
    render.SetColorModulation(1.0, 0.38, 0.08)
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    local center = self._drawPos
    render.SetMaterial(matGlow)

    -- Сердцевина: насыщенный огненный шар
    render.DrawSphere(center, 30 + pulse*12, 8, 8,
        Color(255, 130, 25, math.floor(170+pulse*70)))
    -- Внешнее glow
    render.DrawSprite(center, 110+pulse*28, 110+pulse*28,
        Color(255, 155, 40, math.floor(pulse*150+50)))
    -- Мягкое оранжевое halo
    render.DrawSprite(center, 200+pulse2*40, 200+pulse2*40,
        Color(255, 80, 10, math.floor(pulse2*60+18)))
end
