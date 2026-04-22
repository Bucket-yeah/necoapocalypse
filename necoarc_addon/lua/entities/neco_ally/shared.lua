if not DrGBase then return end

ENT.Base = "drgbase_nextbot"
ENT.PrintName = "Союзная Неко"
ENT.Category = "Neco Arc Apocalypse"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Models = { "models/npc/nekoarc.mdl" }
ENT.Skins = { 0 }
ENT.ModelScale = 1.0
ENT.CollisionBounds = Vector(16, 16, 72)
ENT.BloodColor = BLOOD_COLOR_RED

ENT.SpawnHealth = 9999
ENT.HealthRegen = 0

ENT.OnSpawnSounds = { "infection/neco/buranya.mp3" }
ENT.OnDamageSounds = {}
ENT.DamageSoundDelay = 0.5
ENT.OnDeathSounds = {}

ENT.Omniscient = false
ENT.SpotDuration = 30
ENT.SightFOV = 150
ENT.SightRange = 15000
ENT.HearingCoefficient = 1

ENT.RangeAttackRange = 800
ENT.RangeAttackMinRange = 0
ENT.RangeAttackCooldown = 0.2
ENT.RangeAttackDamage = 5
ENT.MeleeAttackRange = 0

ENT.Factions = { "neco_ally" }
ENT.Frightening = false

ENT.Acceleration = 600
ENT.Deceleration = 800
ENT.StepHeight = 20
ENT.MaxYawRate = 300
ENT.WalkSpeed = 200
ENT.RunSpeed = 200

ENT.WalkAnimation = ACT_WALK
ENT.RunAnimation = ACT_RUN
ENT.IdleAnimation = ACT_IDLE
ENT.JumpAnimation = ACT_JUMP

ENT.UseWeapons = true
ENT.Weapons = { "weapon_smg1" }
ENT.WeaponAttachment = "Anim_Attachment_RH"
ENT.DropWeaponOnDeath = false
ENT.AcceptPlayerWeapons = false

ENT.IgnoreCollisionWithAllies = true

ENT.IsNecoArc = false
ENT.IsAllyNeco = true