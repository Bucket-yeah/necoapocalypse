include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")
local matBeam  = Material("sprites/laserbeam")

-- История позиций спор для трейла
local sporeTrails  = {}
-- Эффекты попаданий
local sporeImpacts = {}

net.Receive("NAA_SporeImpact", function()
    table.insert(sporeImpacts, { pos = net.ReadVector(), t = CurTime() })
end)

hook.Add("Think", "Spore_FXThink", function()
    local now = CurTime()

    -- Обновляем трейлы для всех летящих спор
    for _, ent in ipairs(ents.FindByClass("neco_proj_spore")) do
        if not IsValid(ent) then continue end
        local idx = ent:EntIndex()
        if not sporeTrails[idx] then
            sporeTrails[idx] = { parts = {}, lastT = 0 }
        end
        local trail = sporeTrails[idx]
        if trail.lastT + 0.038 < now then
            trail.lastT = now
            table.insert(trail.parts, 1, { pos = ent:GetPos(), t = now })
            if #trail.parts > 16 then table.remove(trail.parts) end
        end
    end

    -- Чистим мёртвые трейлы
    for idx, _ in pairs(sporeTrails) do
        if not IsValid(Entity(idx)) then sporeTrails[idx] = nil end
    end
    -- Чистим старые взрывы
    for i = #sporeImpacts, 1, -1 do
        if now - sporeImpacts[i].t > 2.2 then table.remove(sporeImpacts, i) end
    end
end)

hook.Add("PostDrawTranslucentRenderables", "Spore_FXDraw", function()
    local now = CurTime()

    -- 1. Ядовитые трейлы: пурпурный → зелёный градиент
    render.SetMaterial(matSmoke)
    for _, trail in pairs(sporeTrails) do
        local parts = trail.parts
        if #parts < 2 then continue end
        for i, p in ipairs(parts) do
            local frac = i / #parts     -- 0 = самый свежий, 1 = самый старый
            local a    = math.floor(Lerp(frac, 200, 0))
            local sz   = Lerp(frac, 10, 48)
            -- Цвет: пурпурный у головы → ядовито-зелёный у хвоста
            local r = math.floor(Lerp(frac, 180, 25))
            local g = math.floor(Lerp(frac, 30,  160))
            local b = math.floor(Lerp(frac, 240, 50))
            render.DrawSprite(p.pos, sz, sz, Color(r, g, b, a))
        end
        -- Светящийся core-beam у передней части трейла
        local endIdx = math.min(5, #parts)
        if endIdx >= 2 then
            render.SetMaterial(matBeam)
            render.DrawBeam(parts[1].pos, parts[endIdx].pos, 7,  0, 1, Color(140, 30, 230, 190))
            render.DrawBeam(parts[1].pos, parts[endIdx].pos, 2,  0, 1, Color(240, 200, 255, 220))
            render.SetMaterial(matSmoke)
        end
    end

    -- 2. Эффект попадания: ядовитый всплеск
    render.SetMaterial(matGlow)
    for _, imp in ipairs(sporeImpacts) do
        local age  = now - imp.t
        local frac = math.min(age / 2.0, 1)
        local ef   = math.min(age / 0.22, 1)   -- быстрое расширение вспышки
        local a    = math.floor(Lerp(frac, 210, 0))
        local r    = ef * 190

        -- Центральная вспышка
        if ef < 1 then
            local flashA = math.floor((1 - ef) * 230)
            render.DrawSprite(imp.pos + Vector(0,0,12),
                Lerp(ef, 460, 55), Lerp(ef, 460, 55),
                Color(90, 230, 40, flashA))
        end

        -- Расширяющийся ядовитый шар
        render.DrawSphere(imp.pos + Vector(0,0,6), r, 10, 10,
            Color(25, 150, 15, math.floor(a * 0.38)))

        -- Разлетающиеся капли яда по кольцу
        render.SetMaterial(matSmoke)
        for i = 1, 10 do
            local ang = i * 36 + age * 50
            local drop = imp.pos + Vector(
                math.cos(math.rad(ang)) * r * 0.75,
                math.sin(math.rad(ang)) * r * 0.75,
                math.sin(age * 4 + i) * 18 + age * 18
            )
            local dsz = Lerp(frac, 20, 70)
            render.DrawSprite(drop, dsz, dsz, Color(20, 170, 30, math.floor(a * (1 - i/14))))
        end

        -- Второй пузырь (задержка)
        if age > 0.15 then
            render.SetMaterial(matGlow)
            local age2  = age - 0.15
            local frac2 = math.min(age2 / 1.6, 1)
            local r2    = frac2 * 130
            local a2    = math.floor(Lerp(frac2, 160, 0))
            render.DrawSphere(imp.pos + Vector(0,0,8), r2, 8, 8,
                Color(60, 200, 40, math.floor(a2 * 0.5)))
            render.SetMaterial(matSmoke)
        end

        render.SetMaterial(matGlow)
    end

    render.SetMaterial(matGlow)
end)

function ENT:Draw()
    local pos = self:GetPos()
    local t   = CurTime()
    local p1  = 0.5 + 0.5 * math.sin(t * 11)
    local p2  = 0.5 + 0.5 * math.sin(t * 7.4 + 1.3)
    local p3  = 0.5 + 0.5 * math.sin(t * 4.8 + 2.1)

    -- Тинтованная модель: насыщенный яд/пурпур
    render.SetColorModulation(0.5, 0.12, 0.78)
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    -- Многослойное свечение: ядовитый пурпур + зелёный орбитальный гало
    render.SetMaterial(matGlow)
    -- Плотная ядовитая сердцевина
    render.DrawSphere(pos, 12 + p1*4, 5, 5,
        Color(100, 20, 190, math.floor(110 + p1*70)))
    -- Основной пульсирующий спрайт
    render.DrawSprite(pos, 32 + p1*12, 32 + p1*12,
        Color(190, 55, 255, math.floor(170 + p1*60)))
    -- Мягкое внешнее glow
    render.DrawSprite(pos, 55 + p2*16, 55 + p2*16,
        Color(80, 200, 40, math.floor(55 + p2*45)))
    -- Яркая быстрая точка в центре (частота другая)
    render.DrawSprite(pos, 15 + p3*5, 15 + p3*5,
        Color(255, 220, 255, math.floor(p3*150 + 40)))
end
