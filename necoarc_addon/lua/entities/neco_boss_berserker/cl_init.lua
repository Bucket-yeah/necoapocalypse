include("shared.lua")

local matGlow  = Material("sprites/light_glow02_add")
local matSmoke = Material("particle/particle_smokegrenade")
local matBeam  = Material("sprites/laserbeam")

-- Dash trail
local dashTrails = {}
net.Receive("NAA_BerserkerDash", function()
    local from = net.ReadVector()
    local to   = net.ReadVector()
    table.insert(dashTrails, { from = from, to = to, t = CurTime() })
    util.ScreenShake(LocalPlayer():GetPos(), 6, 8, 0.5, 600)
end)

-- Cry wave
local cryWaves = {}
net.Receive("NAA_BerserkerCry", function()
    table.insert(cryWaves, { pos = net.ReadVector(), t = CurTime() })
end)

-- Phase 2 flash
local p2Flash = false
net.Receive("NAA_BerserkerPhase2", function()
    p2Flash = true
    timer.Simple(3.5, function() p2Flash = false end)
end)

-- Dash particles
local dashParticles = {}

hook.Add("Think", "Berserker_DashParticles", function()
    local now = CurTime()
    for _, dt in ipairs(dashTrails) do
        local age = now - dt.t
        if age > 0.8 then continue end
        local frac = age / 0.8
        local pos = LerpVector(frac, dt.from, dt.to)
        for _ = 1, 3 do
            table.insert(dashParticles, {
                pos  = pos + Vector(math.random(-25,25), math.random(-25,25), math.random(0,60)),
                t    = now, life = 0.35, sz = math.random(20, 55)
            })
        end
    end
    for i = #dashParticles, 1, -1 do
        if now - dashParticles[i].t > dashParticles[i].life then table.remove(dashParticles, i) end
    end
    for i = #dashTrails, 1, -1 do
        if now - dashTrails[i].t > 1.5 then table.remove(dashTrails, i) end
    end
    for i = #cryWaves, 1, -1 do
        if now - cryWaves[i].t > 2.5 then table.remove(cryWaves, i) end
    end
end)

hook.Add("PostDrawTranslucentRenderables", "Berserker_PostDraw", function()
    local now = CurTime()

    -- Dash blood trail
    render.SetMaterial(matSmoke)
    for _, p in ipairs(dashParticles) do
        local age  = now - p.t
        local frac = age / p.life
        local a    = math.floor(Lerp(frac, 200, 0))
        render.DrawSprite(p.pos, Lerp(frac, p.sz, p.sz*2), Lerp(frac, p.sz, p.sz*2),
            Color(220, 20, 20, a))
    end

    -- Dash beam line
    render.SetMaterial(matBeam)
    for _, dt in ipairs(dashTrails) do
        local age  = now - dt.t
        local frac = math.min(age / 0.8, 1)
        local a    = math.floor(Lerp(frac, 220, 0))
        render.DrawBeam(dt.from, dt.to, 8*(1-frac*0.7), 0, 1, Color(220, 40, 20, a))
        render.DrawBeam(dt.from, dt.to, 2.5*(1-frac*0.7), 0, 1, Color(255, 180, 160, a))
    end

    -- Cry expanding shockwave
    render.SetMaterial(matGlow)
    for _, cw in ipairs(cryWaves) do
        local age  = now - cw.t
        local frac = math.min(age / 2.0, 1)
        local r    = frac * 900
        local a    = math.floor(Lerp(frac, 200, 0))

        render.DrawSphere(cw.pos, r, 16, 16, Color(220, 60, 20, math.floor(a*0.25)))
        render.DrawSprite(cw.pos + Vector(0,0,60), r*0.8, r*0.8, Color(255, 80, 30, math.floor(a*0.2)))

        render.SetMaterial(matBeam)
        for i = 1, 12 do
            local ang = i * 30 + age * 20
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
            render.DrawBeam(cw.pos + Vector(0,0,40), cw.pos + Vector(0,0,40) + dir * r, 4*(1-frac), 0, 1,
                Color(255, 60, 20, a))
        end
        render.SetMaterial(matGlow)
    end
end)

function ENT:Draw()
    self._drawPos = self:GetPos()
    local t     = CurTime()
    local phase = self:GetNWInt("BerserkerPhase", 1)
    local bsrk  = self:GetNWBool("BerserkerBerserk", false)
    local inv   = self:GetNWBool("BerserkerInvulnerable", false)
    local dash  = self:GetNWBool("BerserkerDashing", false)
    local pulse = 0.5 + 0.5 * math.sin(t * 3)

    if p2Flash then
        local fp = 0.5 + 0.5 * math.sin(t * 18)
        render.SetColorModulation(1.0, 0.15 + fp*0.1, 0.10)
    elseif bsrk then
        local bp = 0.5 + 0.5 * math.sin(t * 12)
        render.SetColorModulation(1.0, 0.35 + bp*0.15, 0.05)
    elseif phase == 2 then
        render.SetColorModulation(0.92, 0.15, 0.10)
    else
        render.SetColorModulation(0.75, 0.10, 0.08)
    end
    render.SetBlend(inv and 0.6 or 1.0)
    self:DrawModel()
    render.SetColorModulation(1,1,1)
    render.SetBlend(1)

    local center = self._drawPos + self:OBBCenter()

    -- Berserk fire aura
    if bsrk then
        local bp = 0.5 + 0.5 * math.sin(t * 14)
        render.SetMaterial(matGlow)
        render.DrawSphere(center, 130+bp*30, 12, 12, Color(255, 80, 10, math.floor(100+bp*80)))
        render.DrawSphere(center, 180+bp*40, 12, 12, Color(255, 50, 5, math.floor(50+bp*50)))
        render.DrawSprite(center, 380+bp*60, 380+bp*60, Color(255, 60, 15, math.floor(bp*100+25)))
        render.SetMaterial(matBeam)
        for i = 1, 8 do
            local ang = t*150 + i*45
            local dir = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0.15)
            render.DrawBeam(center, center + dir:GetNormalized()*(120+bp*25), 4+bp*2, 0, 1,
                Color(255, 70, 10, math.floor(180+bp*60)))
        end
        render.SetMaterial(matGlow)
    end

    -- Cry radiance
    if self:GetNWBool("BerserkerCry", false) then
        local cp = 0.5 + 0.5 * math.sin(t * 6)
        render.SetMaterial(matGlow)
        render.DrawSphere(center, 200+cp*40, 16, 16, Color(255, 60, 20, math.floor(80+cp*60)))
        render.DrawSprite(center, 600+cp*80, 600+cp*80, Color(255, 80, 30, math.floor(cp*80+20)))
    end

    -- Dash afterimage
    if dash then
        local dp = 0.5 + 0.5 * math.sin(t * 25)
        render.SetMaterial(matGlow)
        render.DrawSprite(center, 200+dp*40, 200+dp*40, Color(255, 30, 10, math.floor(dp*160+40)))
    end

    -- Invulnerability golden glow
    if inv then
        local ip = 0.5 + 0.5 * math.sin(t * 10)
        render.SetMaterial(matGlow)
        render.DrawSphere(center, 150+ip*20, 12, 12, Color(255, 200, 50, math.floor(100+ip*80)))
        render.DrawSprite(center, 350+ip*50, 350+ip*50, Color(255, 220, 80, math.floor(ip*120+40)))
    end

    -- Ambient
    render.SetMaterial(matGlow)
    local ac = phase == 2 and Color(220, 40, 20, math.floor(pulse*35+12)) or Color(180, 30, 15, math.floor(pulse*22+8))
    render.DrawSprite(center, 80+pulse*18, 80+pulse*18, ac)
end
