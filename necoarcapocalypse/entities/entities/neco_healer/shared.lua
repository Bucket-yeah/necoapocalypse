if not DrGBase then return end

ENT.Base = "drgbase_nextbot"
ENT.PrintName = "Лекарь Неко"
ENT.Category = "Neco Arc Apocalypse"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Models = { "models/npc/nekoarc.mdl" }
ENT.Skins = { 0 }
ENT.ModelScale = 1.0
ENT.CollisionBounds = Vector(16, 16, 72)
ENT.BloodColor = BLOOD_COLOR_RED

ENT.SpawnHealth = 8
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

ENT.RangeAttackRange = 700
ENT.RangeAttackMinRange = 250
ENT.RangeAttackCooldown = 2.5
ENT.RangeAttackDamage = 4
ENT.MeleeAttackRange = 0
ENT.KeepDistance = true
ENT.PreferredRange = 400

ENT.Factions = { "neco", "combine" }
ENT.Frightening = false

ENT.Acceleration = 600
ENT.Deceleration = 800
ENT.StepHeight = 20
ENT.MaxYawRate = 250
ENT.WalkSpeed = 160
ENT.RunSpeed = 160

ENT.WalkAnimation = ACT_WALK
ENT.RunAnimation = ACT_RUN
ENT.IdleAnimation = ACT_IDLE
ENT.JumpAnimation = ACT_JUMP

ENT.UseWeapons = true
ENT.Weapons = { "weapon_pistol" }
ENT.WeaponAttachment = "Anim_Attachment_RH"
ENT.DropWeaponOnDeath = true
ENT.AcceptPlayerWeapons = false

ENT.IgnoreCollisionWithAllies = true

ENT.IsNecoArc = true
ENT.NecoType = "healer"