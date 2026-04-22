-- shared.lua (обновлён)
ENT = ENT or {}
if not DrGBase then return end

ENT.Base       = "drgbase_nextbot"
ENT.PrintName  = "Гигант Неко"
ENT.Category   = "Neco Arc Apocalypse"
ENT.Spawnable  = true
ENT.AdminOnly  = false

ENT.Models     = { "models/npc/nekoarc.mdl" }
ENT.Skins      = { 0 }
ENT.ModelScale = 2.2                     -- размер как у танка
ENT.CollisionBounds = Vector(40, 40, 200) -- уменьшены
ENT.BloodColor = BLOOD_COLOR_RED

ENT.SpawnHealth = 2200
ENT.HealthRegen = 0

ENT.OnSpawnSounds  = { "infection/neco/buranya.mp3" }
ENT.OnDamageSounds = { "infection/neco/pain1.mp3", "infection/neco/pain2.mp3", "infection/neco/pain3.mp3" }
ENT.DamageSoundDelay = 0.8
ENT.OnDeathSounds  = { "infection/neco/death1.mp3" }

ENT.Omniscient = true
ENT.SightFOV   = 180
ENT.SightRange = 20000

ENT.MeleeAttackRange = 250
ENT.MeleeDamage      = 70
ENT.MeleeCooldown    = 1.2

ENT.Factions = { "neco", "combine" }
ENT.Frightening = false

ENT.Acceleration = 350
ENT.Deceleration = 500
ENT.StepHeight   = 50
ENT.MaxYawRate   = 100
ENT.WalkSpeed    = 90
ENT.RunSpeed     = 90

ENT.WalkAnimation  = ACT_WALK
ENT.RunAnimation   = ACT_RUN
ENT.IdleAnimation  = ACT_IDLE
ENT.MeleeAnimation = ACT_MELEE_ATTACK1

ENT.UseWeapons           = false
ENT.DropWeaponOnDeath    = false
ENT.IgnoreCollisionWithAllies = true  -- игнорировать коллизию с союзниками

ENT.IsNecoArc  = true
ENT.NecoType   = "neco_boss_giant"
ENT.IsBoss     = true