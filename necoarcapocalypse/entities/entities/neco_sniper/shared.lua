ENT = ENT or {}
if not DrGBase then return end
ENT.Base = "drgbase_nextbot"
-- ...
-- shared.lua (без изменений)
if not DrGBase then return end

ENT.Base = "drgbase_nextbot"
ENT.PrintName = "Неко-Снайпер"
ENT.Category = "Neco Arc Apocalypse"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Models = { "models/npc/nekoarc.mdl" }
ENT.Skins = { 0 }
ENT.ModelScale = 0.95
ENT.CollisionBounds = Vector(16, 16, 72)
ENT.BloodColor = BLOOD_COLOR_RED

ENT.SpawnHealth = 8
ENT.HealthRegen = 0

ENT.OnSpawnSounds = { "infection/neco/buranya.mp3" }
ENT.OnDamageSounds = {}
ENT.DamageSoundDelay = 0.5
ENT.OnDeathSounds = { "infection/neco/death" .. math.random(1,3) .. ".mp3" }

ENT.Omniscient = false
ENT.SpotDuration = 30
ENT.SightFOV = 150
ENT.SightRange = 15000
ENT.HearingCoefficient = 1

ENT.RangeAttackRange = 1200
ENT.RangeAttackMinRange = 0
ENT.RangeAttackCooldown = 2.5
ENT.RangeAttackDamage = 12
ENT.MeleeAttackRange = 0

ENT.Factions = { "neco", "combine" }
ENT.Frightening = false

ENT.Acceleration = 600
ENT.Deceleration = 800
ENT.StepHeight = 20
ENT.MaxYawRate = 300
ENT.WalkSpeed = 190
ENT.RunSpeed = 190

ENT.WalkAnimation = ACT_WALK
ENT.RunAnimation = ACT_RUN
ENT.IdleAnimation = ACT_IDLE
ENT.JumpAnimation = ACT_JUMP

ENT.UseWeapons = true
ENT.Weapons = { "weapon_crossbow" }
ENT.WeaponAttachment = "Anim_Attachment_RH"
ENT.DropWeaponOnDeath = false
ENT.AcceptPlayerWeapons = false

ENT.IgnoreCollisionWithAllies = true

ENT.IsNecoArc = true
ENT.NecoType = "neco_sniper"