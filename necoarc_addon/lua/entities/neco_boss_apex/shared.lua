ENT = ENT or {}
if not DrGBase then return end
ENT.Base       = "drgbase_nextbot"
-- ...
if not DrGBase then return end

ENT.Base       = "drgbase_nextbot"
ENT.PrintName  = "Апекс Неко"
ENT.Category   = "Neco Arc Apocalypse"
ENT.Spawnable  = true
ENT.AdminOnly  = false

ENT.Models     = { "models/npc/nekoarc.mdl" }
ENT.Skins      = { 0 }
ENT.ModelScale = 5.0
ENT.CollisionBounds = Vector(100, 100, 460)
ENT.BloodColor = BLOOD_COLOR_RED

ENT.SpawnHealth = 5000
ENT.HealthRegen = 0

ENT.OnSpawnSounds  = { "infection/neco/buranya.mp3" }
ENT.OnDamageSounds = { "infection/neco/pain1.mp3", "infection/neco/pain2.mp3", "infection/neco/pain3.mp3" }
ENT.DamageSoundDelay = 0.8
ENT.OnDeathSounds  = { "infection/neco/death1.mp3", "infection/neco/death2.mp3", "infection/neco/death3.mp3" }

ENT.Omniscient = true
ENT.SightFOV   = 360
ENT.SightRange = 30000

ENT.MeleeAttackRange = 400
ENT.MeleeDamage      = 50
ENT.MeleeCooldown    = 1.2

ENT.Factions = { "neco", "combine" }
ENT.Frightening = false

ENT.Acceleration = 400
ENT.Deceleration = 600
ENT.StepHeight   = 80
ENT.MaxYawRate   = 100
ENT.WalkSpeed    = 130
ENT.RunSpeed     = 130

ENT.WalkAnimation  = ACT_WALK
ENT.RunAnimation   = ACT_RUN
ENT.IdleAnimation  = ACT_IDLE
ENT.MeleeAnimation = ACT_MELEE_ATTACK1

ENT.UseWeapons           = false
ENT.DropWeaponOnDeath    = false
ENT.IgnoreCollisionWithAllies = true

ENT.IsNecoArc  = true
ENT.NecoType   = "neco_boss_apex"
ENT.IsBoss     = true
