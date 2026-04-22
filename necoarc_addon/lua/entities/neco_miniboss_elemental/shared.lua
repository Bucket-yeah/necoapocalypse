if not DrGBase then return end

ENT.Base = "drgbase_nextbot"
ENT.PrintName = "Электрический Элементаль"
ENT.Category = "Neco Arc Apocalypse"
ENT.Spawnable = true
ENT.AdminOnly = false

-- Внешний вид: бледно-жёлтый
ENT.Models = { "models/npc/nekoarc.mdl" }
ENT.Skins = { 0 }
ENT.ModelScale = 1.2
ENT.CollisionBounds = Vector(20, 20, 86)
ENT.BloodColor = BLOOD_COLOR_RED

ENT.SpawnHealth = 350
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

ENT.RangeAttackRange = 800   -- для цепной молнии
ENT.MeleeAttackRange = 0
ENT.RangeAttackCooldown = 5.0
ENT.RangeAttackDamage = 25

ENT.Factions = { "neco", "combine" }
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

ENT.UseWeapons = false   -- атакует молниями

ENT.IgnoreCollisionWithAllies = true

ENT.IsNecoArc = true
ENT.NecoType = "neco_miniboss_elemental"
ENT.IsMiniBoss = true