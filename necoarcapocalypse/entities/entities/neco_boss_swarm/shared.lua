ENT = ENT or {}
if not DrGBase then return end

ENT.Base       = "drgbase_nextbot"
ENT.PrintName  = "Гнездо Роя"
ENT.Category   = "Neco Arc Apocalypse"
ENT.Spawnable  = true
ENT.AdminOnly  = false

ENT.Models     = { "models/npc/nekoarc.mdl" }
ENT.Skins      = { 0 }
ENT.ModelScale = 3.0
ENT.CollisionBounds = Vector(60, 60, 280)
ENT.BloodColor = BLOOD_COLOR_GREEN

ENT.SpawnHealth = 800
ENT.HealthRegen = 0

ENT.OnSpawnSounds  = { "infection/neco/buranya.mp3" }
ENT.OnDamageSounds = { "infection/neco/pain1.mp3", "infection/neco/pain2.mp3" }
ENT.DamageSoundDelay = 1.0
ENT.OnDeathSounds  = { "infection/neco/death1.mp3", "infection/neco/death2.mp3" }

ENT.Omniscient = true
ENT.SightFOV   = 360
ENT.SightRange = 20000

ENT.MeleeAttackRange = 0
ENT.MeleeDamage      = 0
ENT.MeleeCooldown    = 99

ENT.Factions = { "neco", "combine" }
ENT.Frightening = false

ENT.Acceleration = 0
ENT.Deceleration = 0
ENT.StepHeight   = 0
ENT.MaxYawRate   = 30
ENT.WalkSpeed    = 0
ENT.RunSpeed     = 0

ENT.UseWeapons           = false
ENT.DropWeaponOnDeath    = false
ENT.IgnoreCollisionWithAllies = true

ENT.IsNecoArc  = true
ENT.NecoType   = "neco_boss_swarm"
ENT.IsBoss     = true

ENT.Mass = 100000  -- огромная масса, чтобы танк не сдвинул