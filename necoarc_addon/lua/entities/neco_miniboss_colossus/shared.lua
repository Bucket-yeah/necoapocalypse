-- ============================================================
--  NECO ARC APOCALYPSE — neco_miniboss_colossus (shared.lua)
-- ============================================================
if not DrGBase then return end

ENT.Base = "drgbase_nextbot"
ENT.PrintName = "Бронированный Колосс"
ENT.Category = "Neco Arc Apocalypse"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Models = { "models/npc/nekoarc.mdl" }
ENT.Skins = { 0 }
ENT.ModelScale = 2.5
ENT.CollisionBounds = Vector(40, 40, 180)
ENT.BloodColor = BLOOD_COLOR_RED

ENT.SpawnHealth = 600
ENT.HealthRegen = 0

ENT.OnSpawnSounds = { "infection/neco/buranya.mp3" }
ENT.OnDamageSounds = { "infection/neco/pain1.mp3", "infection/neco/pain2.mp3", "infection/neco/pain3.mp3" }
ENT.DamageSoundDelay = 0.5
ENT.OnDeathSounds = { "infection/neco/death1.mp3", "infection/neco/death2.mp3", "infection/neco/death3.mp3" }

ENT.Omniscient = false
ENT.SpotDuration = 30
ENT.SightFOV = 150
ENT.SightRange = 15000
ENT.HearingCoefficient = 1

ENT.RangeAttackRange = 0
ENT.MeleeAttackRange = 200
ENT.MeleeDamage = 45
ENT.MeleeCooldown = 1.0

ENT.Factions = { "neco", "combine" }
ENT.Frightening = false

ENT.Acceleration = 400
ENT.Deceleration = 600
ENT.StepHeight = 30
ENT.MaxYawRate = 200
ENT.WalkSpeed = 140   -- Немного быстрее
ENT.RunSpeed = 140

ENT.WalkAnimation = ACT_WALK
ENT.RunAnimation = ACT_RUN
ENT.IdleAnimation = ACT_IDLE
ENT.JumpAnimation = ACT_JUMP
ENT.MeleeAnimation = ACT_MELEE_ATTACK1

ENT.UseWeapons = true
ENT.Weapons = { "weapon_stunstick" }
ENT.WeaponAttachment = "Anim_Attachment_RH"
ENT.DropWeaponOnDeath = true
ENT.AcceptPlayerWeapons = false

ENT.IgnoreCollisionWithAllies = true

ENT.IsNecoArc = true
ENT.NecoType = "neco_miniboss_colossus"
ENT.IsMiniBoss = true