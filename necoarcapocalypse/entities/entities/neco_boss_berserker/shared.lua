ENT = ENT or {}
if not DrGBase then return end

ENT.Base       = "drgbase_nextbot"
ENT.PrintName  = "Берсерк Лорд"
ENT.Category   = "Neco Arc Apocalypse"
ENT.Spawnable  = true
ENT.AdminOnly  = false

ENT.Models     = { "models/npc/nekoarc.mdl" }
ENT.Skins      = { 0 }
ENT.ModelScale = 2.5
ENT.CollisionBounds = Vector(50, 50, 220)
ENT.BloodColor = BLOOD_COLOR_RED

ENT.SpawnHealth = 1200
ENT.HealthRegen = 0

ENT.OnSpawnSounds  = { "infection/neco/buranya.mp3" }
ENT.OnDamageSounds = { "infection/neco/pain1.mp3", "infection/neco/pain2.mp3", "infection/neco/pain3.mp3" }
ENT.DamageSoundDelay = 0.5
ENT.OnDeathSounds  = { "infection/neco/death1.mp3", "infection/neco/death2.mp3" }

ENT.Omniscient = true
ENT.SightFOV   = 180
ENT.SightRange = 20000

ENT.MeleeAttackRange = 250
ENT.MeleeDamage      = 45
ENT.MeleeCooldown    = 1.0

ENT.Factions = { "neco", "combine" }
ENT.Frightening = false

ENT.Acceleration = 600
ENT.Deceleration = 800
ENT.StepHeight   = 30
ENT.MaxYawRate   = 250
ENT.WalkSpeed    = 120
ENT.RunSpeed     = 120

ENT.WalkAnimation  = ACT_WALK
ENT.RunAnimation   = ACT_RUN
ENT.IdleAnimation  = ACT_IDLE
ENT.MeleeAnimation = ACT_MELEE_ATTACK1

ENT.UseWeapons           = false
ENT.DropWeaponOnDeath    = false
ENT.IgnoreCollisionWithAllies = true

ENT.IsNecoArc  = true
ENT.NecoType   = "neco_boss_berserker"
ENT.IsBoss     = true
ENT.Mass       = 50000  -- огромная масса, чтобы не сдвигали