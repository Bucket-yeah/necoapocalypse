include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matBeam  = Material("sprites/laserbeam")
local matSmoke = Material("particle/particle_smokegrenade")

-- =========================================================
--  ИСКРЫ — собственные частицы без util.Effect
--
--  ПОЧЕМУ НЕ ent:GetPos() В THINK:
--  На клиенте позиция NextBot'а в хуке Think может быть
--  Vector(0,0,0). Правильная позиция гарантирована только
--  в ENT:Draw(). Поэтому сохраняем её там как _drawPos.
-- =========================================================
local sparks = {}

hook.Add("Think", "Elemental_SparkSpawn", function()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("neco_miniboss_elemental")) do
        if not IsValid(ent) then continue end
        -- Используем позицию из ENT:Draw (всегда корректная)
        local entPos = ent._drawPos
        if not entPos then continue end  -- Draw ещё не вызывался

        if (ent._sparkNext or 0) > now then continue end
        ent._sparkNext = now + 0.10

        for _ = 1, math.random(3, 5) do
            local dir = VectorRand():GetNormalized()
            table.insert(sparks, {
                pos  = entPos + Vector(
                    math.random(-30, 30),
                    math.random(-30, 30),
                    math.random(10, 80)),
                vel  = dir * math.random(40, 120),
                t    = now,
                life = 0.15 + math.random() * 0.25,
                sz   = math.random(5, 12)
            })
        end
    end
    for i = #sparks, 1, -1 do
        if now - sparks[i].t > sparks[i].life then table.remove(sparks, i) end
    end
end)

-- =========================================================
--  ИСКРЫ СМЕРТИ
--  EntityRemoved: IsValid(ent) = false, поэтому НЕ проверяем
--  его, а сразу читаем GetClass/GetPos напрямую.
-- =========================================================
hook.Add("EntityRemoved", "Elemental_DeathSparks", function(ent)
    -- НЕ вызываем IsValid — в этом хуке ent уже невалиден,
    -- но GetClass() и _drawPos всё ещё доступны.
    if ent:GetClass() ~= "neco_miniboss_elemental" then return end

    -- Берём сохранённую позицию из Draw
    local deathPos = ent._drawPos
    if not deathPos then return end

    local now = CurTime()

    for _ = 1, 60 do
        local dir = VectorRand():GetNormalized()
        table.insert(sparks, {
            pos  = deathPos + Vector(0, 0, 50),
            vel  = dir * math.random(80, 280),
            t    = now,
            life = 0.4 + math.random() * 0.5,
            sz   = math.random(8, 22)
        })
    end
    for _ = 1, 30 do
        local ang = math.random(0, 360)
        local r   = math.random(20, 180)
        table.insert(sparks, {
            pos  = deathPos + Vector(
                math.cos(math.rad(ang)) * r,
                math.sin(math.rad(ang)) * r,
                math.random(5, 40)),
            vel  = Vector(0, 0, math.random(30, 100)),
            t    = now,
            life = 0.5 + math.random() * 0.6,
            sz   = math.random(6, 18)
        })
    end
end)

-- =========================================================
--  Цепная молния — все перескоки
-- =========================================================
local chainState = { active = false, primary = nil, hops = {}, endT = 0 }

hook.Add("Think", "Elemental_ChainTrack", function()
    for _, ent in ipairs(ents.FindByClass("neco_miniboss_elemental")) do
        if not IsValid(ent) then continue end
        local chainOn = ent:GetNWBool("ElementalChain", false)
        local primary = ent:GetNWEntity("ElementalChainTarget")

        if chainOn and IsValid(primary) then
            chainState.active  = true
            chainState.primary = primary
            chainState.endT    = CurTime() + 0.35

            chainState.hops = {}
            local CHAIN_RANGE = 350
            local hit  = { [primary] = true }
            local last = primary

            for _ = 1, 2 do
                local nextPly, nextD = nil, math.huge
                for _, ply in ipairs(player.GetAll()) do
                    if IsValid(ply) and ply:Alive() and not hit[ply] then
                        local d = last:GetPos():Distance(ply:GetPos())
                        if d < CHAIN_RANGE and d < nextD then
                            nextD = d; nextPly = ply
                        end
                    end
                end
                if not IsValid(nextPly) then break end
                table.insert(chainState.hops, { from = last, to = nextPly })
                hit[nextPly] = true
                last = nextPly
            end
        elseif CurTime() > chainState.endT then
            chainState.active  = false
            chainState.primary = nil
            chainState.hops    = {}
        end
    end
end)

-- =========================================================
--  PostDraw: искры + цепная молния
-- =========================================================
hook.Add("PostDrawTranslucentRenderables", "Elemental_PostDraw", function()
    local now = CurTime()

    -- 1. Искры
    render.SetMaterial(matGlow)
    for _, sp in ipairs(sparks) do
        local age  = now - sp.t
        local frac = age / sp.life
        local pos  = sp.pos + sp.vel * age - Vector(0, 0, age * age * 80)
        local a    = math.floor(Lerp(frac, 255, 0))
        local g    = math.floor(Lerp(frac, 255, 160))
        local b    = math.floor(Lerp(frac, 220, 0))
        local sz   = Lerp(frac, sp.sz, sp.sz * 0.3)
        render.DrawSprite(pos, sz, sz, Color(255, g, b, a))
    end

    -- 2. Цепная молния
    if not chainState.active then return end

    local t      = now
    local jitter = math.sin(t * 50) * 2.5

    local srcEnt = nil
    for _, ent in ipairs(ents.FindByClass("neco_miniboss_elemental")) do
        if IsValid(ent) then srcEnt = ent; break end
    end
    if not IsValid(srcEnt) then return end

    local src = srcEnt:GetPos() + srcEnt:OBBCenter()

    render.SetMaterial(matBeam)

    -- ── ИСПРАВЛЕНО: было "do" вместо "then" (синтаксическая ошибка!) ──
    if IsValid(chainState.primary) then
        -- Целимся в туловище, не в голову
        local tgt = chainState.primary:GetPos() + chainState.primary:OBBCenter()

        render.DrawBeam(src, tgt, 10,  0, 1, Color(255, 230, 30,  55))   -- широкое свечение
        render.DrawBeam(src, tgt,  4,  0, 1, Color(255, 220, 40, 255))   -- жёлтый
        render.DrawBeam(src, tgt,  1.5, 0, 1, Color(255, 255, 230, 255)) -- белая сердцевина

        render.SetMaterial(matGlow)
        render.DrawSprite(tgt, 32 + jitter, 32 + jitter, Color(255, 240, 100, 230))
        render.SetMaterial(matBeam)
    end

    for _, hop in ipairs(chainState.hops) do
        if not IsValid(hop.from) or not IsValid(hop.to) then continue end
        local s = hop.from:GetPos() + hop.from:OBBCenter()
        local e = hop.to:GetPos()   + hop.to:OBBCenter()

        render.DrawBeam(s, e, 7,   0, 1, Color(240, 210, 30,  70))
        render.DrawBeam(s, e, 3,   0, 1, Color(255, 225, 45, 210))
        render.DrawBeam(s, e, 1.2, 0, 1, Color(255, 255, 215, 200))

        render.SetMaterial(matGlow)
        render.DrawSprite(e, 22 + jitter, 22 + jitter, Color(255, 245, 90, 190))
        render.SetMaterial(matBeam)
    end

    render.SetMaterial(matGlow)
end)

-- =========================================================
--  ENT:Draw
-- =========================================================
function ENT:Draw()
    local t = CurTime()

    -- Сохраняем позицию — она корректна только здесь!
    self._drawPos = self:GetPos()

    render.SetColorModulation(1.0, 1.0, 0.72)
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    local center = self._drawPos + self:OBBCenter()
    local pulse  = 0.5 + 0.5 * math.sin(t * 3)

    if self:GetNWBool("ElementalField", false) then
        render.SetMaterial(matGlow)
        render.DrawSphere(self._drawPos, 320, 16, 16,
            Color(255, 255, 120, math.floor(60 + pulse * 30)))
        render.DrawSphere(self._drawPos, 345, 16, 16,
            Color(255, 255, 80, math.floor(25 + pulse * 15)))
        render.DrawSprite(self._drawPos, 700, 700,
            Color(255, 255, 100, math.floor(pulse * 30 + 10)))
    end

    if self:GetNWBool("ElementalShield", false) then
        local p2 = 0.5 + 0.5 * math.sin(t * 8)
        render.SetMaterial(matGlow)
        render.DrawSphere(center, 90 + p2 * 10, 16, 16,
            Color(255, 255, 80, math.floor(150 + p2 * 70)))
        render.DrawSphere(center, 115 + p2 * 10, 16, 16,
            Color(255, 255, 60, math.floor(70 + p2 * 40)))
        render.SetMaterial(matBeam)
        for i = 1, 4 do
            local ang = t * 180 + i * 90
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            render.DrawBeam(center, center + dir * 100, 2, 0, 1,
                Color(255, 255, 80, math.floor(160 + p2 * 60)))
        end
        render.SetMaterial(matGlow)
    end

    if self:GetNWBool("ElementalTeleport", false) then
        local p3  = 0.5 + 0.5 * math.sin(t * 20)
        local pos = self._drawPos + Vector(0, 0, 40)
        render.SetMaterial(matGlow)
        render.DrawSphere(pos, 110 + p3 * 30, 16, 16,
            Color(255, 255, 180, math.floor(180 + p3 * 60)))
        render.DrawSprite(pos, 300 + p3 * 40, 300 + p3 * 40,
            Color(255, 255, 200, math.floor(p3 * 120 + 40)))
    end

    render.SetMaterial(matGlow)
    render.DrawSprite(center, 50 + pulse * 10, 50 + pulse * 10,
        Color(255, 255, 120, math.floor(pulse * 40 + 20)))
end

hook.Add("Think", "Elemental_Slow", function()
    local ply = LocalPlayer()
    if IsValid(ply) and ply.ElementalSlowedUntil and CurTime() < ply.ElementalSlowedUntil then
        ply:SetRunSpeed(200 * 0.7)
        ply:SetWalkSpeed(100 * 0.7)
    elseif ply.ElementalSlowedUntil then
        ply.ElementalSlowedUntil = nil
        ply:SetRunSpeed(200)
        ply:SetWalkSpeed(100)
    end
end)
