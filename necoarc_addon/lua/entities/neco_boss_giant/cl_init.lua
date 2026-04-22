-- cl_init.lua (без изменений)
include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")
local matBeam  = Material("sprites/laserbeam")

-- Stomp shockwave rings (from net message)
local stompWaves = {}
net.Receive("NAA_GiantStomp", function()
    table.insert(stompWaves, { pos = net.ReadVector(), t = CurTime() })
end)

-- Throw trail
local throwTrails = {}
net.Receive("NAA_GiantThrow", function()
    table.insert(throwTrails, { from = net.ReadVector(), to = net.ReadVector(), t = CurTime() })
end)

-- Phase 2 flash
local phase2Flash = false
net.Receive("NAA_GiantPhase2", function()
    phase2Flash = true
    timer.Simple(3, function() phase2Flash = false end)
end)

-- Debris trail particles
local debrisParticles = {}

hook.Add("Think", "Giant_DebrisParticles", function()
    local now = CurTime()
    for _, tr in ipairs(throwTrails) do
        local age = now - tr.t
        if age > 1.5 then continue end
        local frac = age / 1.5
        local pos = LerpVector(frac, tr.from, tr.to) + Vector(math.random(-20,20), math.random(-20,20), math.random(-10,20))
        table.insert(debrisParticles, { pos = pos, t = now, life = 0.4, sz = math.random(20, 50) })
    end
    for i = #debrisParticles, 1, -1 do
        if now - debrisParticles[i].t > debrisParticles[i].life then table.remove(debrisParticles, i) end
    end
    for i = #stompWaves, 1, -1 do
        if now - stompWaves[i].t > 1.2 then table.remove(stompWaves, i) end
    end
    for i = #throwTrails, 1, -1 do
        if now - throwTrails[i].t > 2 then table.remove(throwTrails, i) end
    end
end)

hook.Add("PostDrawTranslucentRenderables", "Giant_PostDraw", function()
    local now = CurTime()

    -- 1. Stomp shockwave rings
    for _, wave in ipairs(stompWaves) do
        local age  = now - wave.t
        local frac = math.min(age / 0.9, 1)
        local r    = frac * 280
        local a    = math.floor(Lerp(frac, 220, 0))

        render.SetMaterial(matSmoke)
        for i = 1, 20 do
            local ang = i * 18
            local p   = wave.pos + Vector(math.cos(math.rad(ang))*r, math.sin(math.rad(ang))*r, 6)
            render.DrawSprite(p, Lerp(frac, 30, 100), Lerp(frac, 30, 100), Color(160, 130, 90, a))
        end

        -- Inner ground flash
        render.SetMaterial(matGlow)
        if frac < 0.3 then
            local ff = frac / 0.3
            render.DrawSprite(wave.pos + Vector(0,0,10), 600*(1-ff), 600*(1-ff), Color(220, 180, 100, math.floor((1-ff)*150)))
        end

        -- Radial dust beams
        render.SetMaterial(matBeam)
        for i = 1, 10 do
            local ang = i * 36 + age * 40
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            render.DrawBeam(wave.pos, wave.pos + dir * r, 6*(1-frac), 0, 1,
                Color(180, 140, 80, math.floor(a * 0.8)))
        end
        render.SetMaterial(matGlow)
    end

    -- 2. Debris dust trail
    render.SetMaterial(matSmoke)
    for _, p in ipairs(debrisParticles) do
        local age  = now - p.t
        local frac = age / p.life
        local a    = math.floor(Lerp(frac, 180, 0))
        render.DrawSprite(p.pos, Lerp(frac, p.sz, p.sz*2.5), Lerp(frac, p.sz, p.sz*2.5), Color(140, 110, 70, a))
    end

    render.SetMaterial(matGlow)
end)

function ENT:Draw()
    self._drawPos = self:GetPos()
    local t       = CurTime()
    local phase   = self:GetNWInt("GiantPhase", 1)

    -- Phase 2 flash effect
    if phase2Flash then
        local pulse = 0.5 + 0.5 * math.sin(t * 20)
        render.SetColorModulation(1.0, 0.25 + pulse*0.1, 0.15 + pulse*0.05)
    elseif phase == 2 then
        local pulse = 0.5 + 0.5 * math.sin(t * 3)
        render.SetColorModulation(0.86 + pulse*0.05, 0.38, 0.38)
    else
        render.SetColorModulation(0.60, 0.50, 0.42)  -- серо-коричневый
    end
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1,1,1)

    local center = self._drawPos + self:OBBCenter()
    local pulse  = 0.5 + 0.5 * math.sin(t * 1.5)

    -- Stomp shockwave on entity
    if self:GetNWBool("GiantStomp", false) then
        local sp = 0.5 + 0.5 * math.sin(t * 30)
        render.SetMaterial(matGlow)
        render.DrawSprite(self._drawPos + Vector(0,0,20), 500+sp*80, 500+sp*80, Color(220, 180, 100, math.floor(sp*130+40)))
        render.DrawSphere(self._drawPos, 120, 12, 12, Color(200, 160, 80, math.floor(180+sp*60)))
    end

    -- Rage aura (phase 2)
    if self:GetNWBool("GiantRage", false) then
        local rp = 0.5 + 0.5 * math.sin(t * 10)
        render.SetMaterial(matGlow)
        render.DrawSphere(center, 160 + rp*30, 12, 12, Color(255, 60, 20, math.floor(80+rp*60)))
        render.DrawSprite(center, 380+rp*60, 380+rp*60, Color(255, 80, 30, math.floor(rp*80+20)))
        -- Rage sparks radiating outward
        render.SetMaterial(matBeam)
        for i = 1, 6 do
            local ang = t*80 + i*60
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0.2)
            render.DrawBeam(center, center + dir:GetNormalized()*(120+rp*30), 4+rp*2, 0, 1,
                Color(255, 80, 20, math.floor(160+rp*60)))
        end
        render.SetMaterial(matGlow)
    end

    -- Enrage transition: blinding pulse
    if self:GetNWBool("GiantEnraging", false) then
        local ep = 0.5 + 0.5 * math.sin(t * 15)
        render.SetMaterial(matGlow)
        render.DrawSprite(center, 800+ep*200, 800+ep*200, Color(255, 100, 60, math.floor(ep*180+40)))
        render.DrawSphere(center, 280+ep*60, 16, 16, Color(255, 80, 40, math.floor(120+ep*80)))
    end

    -- Ambient size-appropriate glow
    render.SetMaterial(matGlow)
    local ambCol = phase == 2 and Color(220, 80, 60, math.floor(pulse*30+10))
                               or Color(160, 130, 90, math.floor(pulse*20+8))
    render.DrawSprite(center, 100+pulse*25, 100+pulse*25, ambCol)
end