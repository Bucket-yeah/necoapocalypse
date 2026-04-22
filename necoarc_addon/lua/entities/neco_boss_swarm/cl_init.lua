-- ============================================================
-- neco_boss_swarm/cl_init.lua — улучшенные спецэффекты
-- ============================================================
include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")
local matBeam  = Material("sprites/laserbeam")

local deathBlasts    = {}   -- { pos, t }
local sporeLines     = {}   -- { from, to, t }
local cloudParticles = {}   -- { pos, vel, t, life, sz, kind }

net.Receive("NAA_SwarmDeathBlast", function()
    table.insert(deathBlasts, { pos = net.ReadVector(), t = CurTime() })
end)

net.Receive("NAA_SwarmSpore", function()
    table.insert(sporeLines, { from = net.ReadVector(), to = net.ReadVector(), t = CurTime() })
end)

hook.Add("Think", "Swarm_CloudParticles", function()
    local now = CurTime()

    for _, ent in ipairs(ents.FindByClass("neco_boss_swarm")) do
        if not IsValid(ent) or not ent:GetNWBool("SwarmCloud", false) then continue end
        if (ent._cloudNext or 0) > now then continue end
        ent._cloudNext = now + 0.055

        local pos = ent:GetPos()

        -- Крупные тёмно-зелёные клубы (kind = 1)
        local r1 = math.random(40, 680)
        local a1 = math.random(0, 360)
        table.insert(cloudParticles, {
            pos  = pos + Vector(math.cos(math.rad(a1))*r1, math.sin(math.rad(a1))*r1, math.random(10, 150)),
            vel  = Vector(math.random(-22,22), math.random(-22,22), math.random(6, 28)),
            t    = now, life = 1.6 + math.random()*1.2, sz = math.random(75, 190), kind = 1
        })

        -- Мелкие ядовито-жёлтые капли (kind = 2)
        for _ = 1, 3 do
            local r2 = math.random(15, 660)
            local a2 = math.random(0, 360)
            table.insert(cloudParticles, {
                pos  = pos + Vector(math.cos(math.rad(a2))*r2, math.sin(math.rad(a2))*r2, math.random(5, 90)),
                vel  = Vector(math.random(-10,10), math.random(-10,10), math.random(4, 14)),
                t    = now, life = 0.7 + math.random()*0.7, sz = math.random(16, 48), kind = 2
            })
        end
    end

    for i = #cloudParticles, 1, -1 do
        if now - cloudParticles[i].t > cloudParticles[i].life then table.remove(cloudParticles, i) end
    end
    for i = #deathBlasts, 1, -1 do
        if now - deathBlasts[i].t > 5.5 then table.remove(deathBlasts, i) end
    end
    for i = #sporeLines, 1, -1 do
        if now - sporeLines[i].t > 0.9 then table.remove(sporeLines, i) end
    end
end)

hook.Add("PostDrawTranslucentRenderables", "Swarm_PostDraw", function()
    local now = CurTime()

    -- 1. Облако — двухслойные частицы
    render.SetMaterial(matSmoke)
    for _, p in ipairs(cloudParticles) do
        local age  = now - p.t
        local frac = age / p.life
        local pos2 = p.pos + p.vel * age
        if p.kind == 1 then
            -- Тёмно-зелёный клуб: медленно расширяется
            local a  = math.floor(Lerp(frac, 145, 0))
            local sz = Lerp(frac, p.sz, p.sz * 2.4)
            render.DrawSprite(pos2, sz, sz, Color(12, 68, 12, a))
        else
            -- Ядовито-жёлто-зелёная капля: быстрая, яркая
            local a  = math.floor(Lerp(frac, 190, 0))
            local sz = Lerp(frac, p.sz, p.sz * 1.6)
            render.DrawSprite(pos2, sz, sz, Color(85, 195, 35, a))
        end
    end

    -- 2. Луч выстрела споры — двойной (фиолетовый + белое ядро)
    render.SetMaterial(matBeam)
    for _, sl in ipairs(sporeLines) do
        local age  = now - sl.t
        local frac = age / 0.9
        local a    = math.floor(Lerp(frac, 230, 0))
        local w    = 7 * (1 - frac)
        render.DrawBeam(sl.from, sl.to, w,       0, 1, Color(110, 30, 200, a))
        render.DrawBeam(sl.from, sl.to, w * 0.3, 0, 1, Color(230, 190, 255, math.floor(a * 0.8)))
    end

    -- 3. Взрыв смерти — 3 кольца + осколки + оседающее облако
    render.SetMaterial(matGlow)
    for _, blast in ipairs(deathBlasts) do
        local age  = now - blast.t
        local frac = math.min(age / 5.5, 1)
        local expF = math.min(age / 0.45, 1)
        local r    = expF * 740
        local a    = math.floor(Lerp(frac, 235, 0))

        -- Основная расширяющаяся сфера
        render.DrawSphere(blast.pos + Vector(0,0,35), r, 16, 16,
            Color(45, 155, 12, math.floor(a * 0.28)))

        -- 3 дополнительных кольца с разной скоростью
        for ring = 1, 3 do
            local rf   = math.min(age / (0.28 + ring * 0.16), 1)
            local rr   = rf * (480 + ring * 100)
            local ra   = math.floor(Lerp(rf, 185, 0))
            -- Кольца разных оттенков
            local rg = ring == 1 and Color(110, 240, 30) or
                        ring == 2 and Color(50,  190, 20) or
                                      Color(25,  120, 12)
            render.DrawSphere(blast.pos + Vector(0,0, 18 + ring*18), rr, 10, 10,
                Color(rg.r, rg.g, rg.b, math.floor(ra * 0.22)))
        end

        -- Вспышка в начале
        if expF < 1 then
            render.DrawSprite(blast.pos + Vector(0,0,65),
                1500*(1-expF), 1500*(1-expF),
                Color(130, 255, 40, math.floor((1-expF)*215)))
        end

        -- 24 осколочных спрайта по спирали
        render.SetMaterial(matSmoke)
        for i = 1, 24 do
            local ang = i * 15 + age * 58
            local sp  = blast.pos + Vector(
                math.cos(math.rad(ang)) * r * 0.82,
                math.sin(math.rad(ang)) * r * 0.82,
                age * 35 + (i % 6) * 18
            )
            local dsz = Lerp(frac, 35, 200)
            local da  = math.floor(a * (1 - (i / 28)))
            render.DrawSprite(sp, dsz, dsz, Color(20, 105, 14, da))
        end

        -- Оседающее ядовитое облако на земле (появляется после взрыва)
        if age > 0.7 then
            render.SetMaterial(matGlow)
            local settle = math.min((age - 0.7) / 0.6, 1)
            local ga     = math.floor(Lerp(frac, 75, 0) * settle)
            render.DrawSphere(blast.pos + Vector(0,0,18), settle * 720, 12, 12,
                Color(18, 95, 10, ga))
        end

        render.SetMaterial(matGlow)
    end

    render.SetMaterial(matGlow)
end)

function ENT:Draw()
    self._drawPos = self:GetPos()
    local t      = CurTime()
    local cloud  = self:GetNWBool("SwarmCloud", false)
    local spore  = self:GetNWBool("SwarmSpore", false)
    local pulse  = 0.5 + 0.5 * math.sin(t * 1.8)
    local pulse2 = 0.5 + 0.5 * math.sin(t * 3.2 + 0.7)

    -- Тинт модели: ярче при активном облаке
    if cloud then
        render.SetColorModulation(0.16, 0.52, 0.16)
    else
        render.SetColorModulation(0.21, 0.46, 0.15)
    end
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    local center = self._drawPos + self:OBBCenter()

    -- Многослойная аура гнезда
    render.SetMaterial(matGlow)
    render.DrawSphere(center, 78 + pulse*16,  10, 10, Color(28, 145, 18, math.floor(48+pulse*38)))
    render.DrawSphere(center, 115 + pulse*22, 10, 10, Color(38, 112, 14, math.floor(22+pulse*18)))
    render.DrawSprite(center, 250+pulse*48, 250+pulse*48, Color(52, 195, 20, math.floor(pulse*58+14)))

    -- 6 орбитальных «яичных мешков» — эллиптические орбиты
    for i = 1, 6 do
        local orbit_spd = 22 + i * 2.8
        local tilt_ang  = i * 60   -- угол наклона каждой орбиты
        -- Эллиптическая орбита: a > b
        local a_ax = 118 + math.sin(t * 0.9 + i) * 12
        local b_ax = 72  + math.sin(t * 1.3 + i * 0.7) * 10
        local phase_t = t * orbit_spd / 57.3 + i * math.pi / 3  -- в радианах
        local ox = a_ax * math.cos(phase_t)
        local oy = b_ax * math.sin(phase_t)
        -- Поворот орбиты на tilt_ang градусов
        local cr = math.cos(math.rad(tilt_ang))
        local sr = math.sin(math.rad(tilt_ang))
        local z  = math.sin(t * 1.4 + i * 1.1) * 30 + math.sin(t*0.55 + i) * 12
        local op = center + Vector(ox*cr - oy*sr, ox*sr + oy*cr, z)

        -- Сам яичный мешок: внешний + внутренний слой
        local egg_p = 0.5 + 0.5 * math.sin(t * (2.6 + i * 0.28) + i)
        render.DrawSprite(op, 25 + egg_p*9, 25 + egg_p*9,
            Color(45, 185, 28, math.floor(145 + egg_p*65)))
        render.DrawSprite(op, 11 + egg_p*5, 11 + egg_p*5,
            Color(190, 245, 100, math.floor(egg_p*130 + 45)))

        -- Луч к центру
        render.SetMaterial(matBeam)
        render.DrawBeam(center, op, 1.2, 0, 1,
            Color(38, 165, 18, math.floor(28 + pulse*22)))
        render.SetMaterial(matGlow)
    end

    -- Индикатор зоны облака (мягкое свечение)
    if cloud then
        render.DrawSphere(center, 700, 14, 14, Color(14, 85, 8, math.floor(28+pulse2*18)))
        render.DrawSprite(center, 1450, 1450, Color(22, 105, 11, math.floor(pulse2*22 + 7)))
        -- Пульсирующее кольцо на краю зоны
        render.DrawSphere(center, 700 + pulse2*18, 10, 10,
            Color(40, 160, 20, math.floor(pulse2*35)))
    end

    -- Вспышка заряда споры (двойной слой)
    if spore then
        local sp = 0.5 + 0.5 * math.sin(t * 28)
        render.DrawSprite(center, 340+sp*75, 340+sp*75,
            Color(130, 45, 210, math.floor(sp*185 + 55)))
        render.DrawSprite(center, 165+sp*45, 165+sp*45,
            Color(230, 180, 255, math.floor(sp*145 + 35)))
    end
end
