if not DrGBase then return end

ENT.Base = "drgbase_nextbot"
ENT.PrintName = "Неко-Призыватель"
ENT.Category = "Neco Arc Apocalypse"
ENT.Spawnable = true
ENT.AdminOnly = false

-- Внешний вид (ТЗ: размер 1.1, фиолетовый)
ENT.Models = { "models/npc/nekoarc.mdl" }
ENT.Skins = { 0 }
ENT.ModelScale = 1.1
ENT.CollisionBounds = Vector(18, 18, 80)
ENT.BloodColor = BLOOD_COLOR_RED

-- Характеристики (ТЗ: HP=20, скорость 170)
ENT.SpawnHealth = 20
ENT.HealthRegen = 0

ENT = ENT or {}
if not DrGBase then return end
ENT.Base = "drgbase_nextbot"
-- ...
-- Звуки
ENT.OnSpawnSounds = { "infection/neco/buranya.mp3" }
ENT.OnDamageSounds = { "infection/neco/pain1.mp3", "infection/neco/pain2.mp3", "infection/neco/pain3.mp3" }
ENT.DamageSoundDelay = 0.5
ENT.OnDeathSounds = { "infection/neco/death1.mp3", "infection/neco/death2.mp3", "infection/neco/death3.mp3" }

-- ИИ (не атакует сам)
ENT.Omniscient = false
ENT.SpotDuration = 30
ENT.SightFOV = 150
ENT.SightRange = 15000
ENT.HearingCoefficient = 1

ENT.RangeAttackRange = 0
ENT.MeleeAttackRange = 0

-- Фракции
ENT.Factions = { "neco", "combine" }
ENT.Frightening = false

-- Передвижение
ENT.Acceleration = 600
ENT.Deceleration = 800
ENT.StepHeight = 20
ENT.MaxYawRate = 300
ENT.WalkSpeed = 170
ENT.RunSpeed = 170

-- Анимации
ENT.WalkAnimation = ACT_WALK
ENT.RunAnimation = ACT_RUN
ENT.IdleAnimation = ACT_IDLE
ENT.JumpAnimation = ACT_JUMP

-- Оружие (нет)
ENT.UseWeapons = false

-- Игнорирование коллизий с союзниками
ENT.IgnoreCollisionWithAllies = true

-- Кастомные переменные
ENT.IsNecoArc = true
ENT.NecoType = "neco_summoner"