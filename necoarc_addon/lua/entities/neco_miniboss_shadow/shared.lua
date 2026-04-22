if not DrGBase then return end

ENT.Base = "drgbase_nextbot"
ENT.PrintName = "Теневой Охотник"
ENT.Category = "Neco Arc Apocalypse"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Models = { "models/npc/nekoarc.mdl" }
ENT.Skins = { 0 }
ENT.ModelScale = 1.1
ENT.CollisionBounds = Vector(18, 18, 80)
ENT.BloodColor = BLOOD_COLOR_RED

ENT.SpawnHealth = 250
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
ENT.MeleeAttackRange = 90
ENT.MeleeDamage = 30
ENT.MeleeCooldown = 0.5

ENT.Factions = { "neco", "combine" }
ENT.Frightening = false

ENT.Acceleration = 600
ENT.Deceleration = 800
ENT.StepHeight = 20
ENT.MaxYawRate = 300
ENT.WalkSpeed = 240
ENT.RunSpeed = 240

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
ENT.NecoType = "neco_miniboss_shadow"
ENT.IsMiniBoss = true