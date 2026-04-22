if not DrGBase then return end

ENT.Base = "drgbase_nextbot"
ENT.PrintName = "Танк Неко"
ENT.Category = "Neco Arc Apocalypse"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Models = { "models/npc/nekoarc.mdl" }
ENT.Skins = { 0 }
ENT.ModelScale = 2.2
ENT.CollisionBounds = Vector(35, 35, 160)
ENT.BloodColor = BLOOD_COLOR_RED

ENT.SpawnHealth = 60
ENT.HealthRegen = 0

ENT.OnSpawnSounds = { "infection/neco/buranya.mp3" }
ENT.OnDamageSounds = {}
ENT.DamageSoundDelay = 0.5
ENT.OnDeathSounds = { "infection/neco/death1.mp3" }

ENT.Omniscient = false
ENT.SpotDuration = 30
ENT.SightFOV = 150
ENT.SightRange = 15000
ENT.HearingCoefficient = 1

ENT.RangeAttackRange = 0
ENT.MeleeAttackRange = 180
ENT.MeleeDamage = 20
ENT.MeleeCooldown = 1.5

ENT.Factions = { "neco", "combine" }
ENT.Frightening = false

ENT.Acceleration = 400
ENT.Deceleration = 600
ENT.StepHeight = 30
ENT.MaxYawRate = 200
ENT.WalkSpeed = 170
ENT.RunSpeed = 170

ENT.WalkAnimation = ACT_WALK
ENT.RunAnimation = ACT_RUN
ENT.IdleAnimation = ACT_IDLE
ENT.JumpAnimation = ACT_JUMP
ENT.MeleeAnimation = ACT_MELEE_ATTACK1

ENT.UseWeapons = true
ENT.Weapons = { "weapon_stunstick" }
ENT.WeaponAttachment = "Anim_Attachment_RH"
ENT.DropWeaponOnDeath = false
ENT.AcceptPlayerWeapons = false

ENT.IgnoreCollisionWithAllies = true

ENT.IsNecoArc = true
ENT.NecoType = "tank"