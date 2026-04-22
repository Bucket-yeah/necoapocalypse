-- ============================================================
--  NECO ARC APOCALYPSE — shared.lua
-- ============================================================

NAA = NAA or {}

-- ============================================================
--  GAME PHASES
-- ============================================================
NAA.PHASE_LOBBY         = "lobby"
NAA.PHASE_CLASS_SELECT  = "class_select"
NAA.PHASE_DIFF_SELECT   = "diff_select"
NAA.PHASE_WAVE          = "wave"
NAA.PHASE_BETWEEN_WAVES = "between_waves"
NAA.PHASE_GAME_OVER     = "game_over"

NAA.Phase        = NAA.PHASE_LOBBY
NAA.CurrentWave  = 0
NAA.AliveEnemies = 0
NAA.WaveEvent    = "normal"
NAA.ActiveBoss   = nil

-- ============================================================
--  NET STRINGS
-- ============================================================
NAA.NET = {
    -- Phase / game flow
    "NAA_Phase", "NAA_WaveUpdate", "NAA_BossHP", "NAA_BossAlert",
    "NAA_ShowUpgrades", "NAA_BetweenWave", "NAA_BetweenWaveTimer",
    -- Combat feedback
    "NAA_KillFeed", "NAA_KillStreak", "NAA_HitMarker",
    "NAA_Scores", "NAA_SpecialAlert", "NAA_SynergyAlert",
    -- Player state sync
    "NAA_SyncCoins", "NAA_SyncLives", "NAA_HunterStacks",
    "NAA_UpgradeList", "NAA_RunResult",
    -- Meta
    "NAA_MetaData",
    -- Client -> Server actions
    "NAA_SelectClass", "NAA_ConfirmClass",
    "NAA_VoteDiff",
    "NAA_ChooseUpgrade", "NAA_RerollCards", "NAA_BuyExtraCard",
    "NAA_StartGame", "NAA_BuyShop",
    "NAA_BuyMeta", "NAA_Ready", "NAA_RequestMeta",
    -- Server -> All: multiplayer sync
    "NAA_LobbyState",       -- JSON: {players=[{nick,sid,ready},...]}
    "NAA_ClassState",       -- JSON: {players=[{nick,sid,class,confirmed},...]}
    "NAA_DiffVoteState",    -- JSON: {votes={easy=N,...}, players=[{nick,voted},...], countdown=N}
    "NAA_UpgradeStatus",    -- JSON: {pending=[nick,...], done=[nick,...]}
    -- Dev
    "NAA_DevCommand", "NAA_DevStatus",
    "NAA_ForceReset",
    "NAA_SelectDifficulty",
}

-- ============================================================
--  CLASSES
-- ============================================================
NAA.Classes = {
    survivor = {
        id = "survivor", name = "Выживший",
        desc = "Универсал. Без слабых мест, без особых сил — просто выживи.",
        hp = 100, armor = 50, speed = 200,
        startWeapons = { "weapon_smg1", "weapon_pistol" },
        passive = "Каждые 10 волн +10 к максимальному HP",
        passiveID = "survivor_scaling", unlockCost = 0,
        color = Color(180, 180, 180),
    },
    medic = {
        id = "medic", name = "Медик",
        desc = "Лечит союзников аурой. При смерти соседнего игрока — получает всплеск HP.",
        hp = 140, armor = 20, speed = 185,
        startWeapons = { "weapon_shotgun", "weapon_pistol" },
        passive = "Аура: +2 HP/сек союзникам в радиусе 350. При смерти союзника: +25 HP.",
        passiveID = "medic_aura", unlockCost = 50,
        color = Color(80, 220, 120),
    },
    berserker = {
        id = "berserker", name = "Берсерк",
        desc = "Чем меньше HP — тем больнее бьёт. Убийство лечит.",
        hp = 150, armor = 0, speed = 230,
        startWeapons = { "weapon_shotgun" },
        passive = "Ярость: урон x1.0-x2.8 в зависимости от HP. +4 HP за убийство.",
        passiveID = "berserker_rage", unlockCost = 75,
        color = Color(220, 60, 60),
    },
    hunter = {
        id = "hunter", name = "Охотник",
        desc = "Собирает стаки убийств для роста урона. Серия — ваншот врага.",
        hp = 80, armor = 30, speed = 220,
        startWeapons = { "weapon_ar2", "weapon_pistol" },
        passive = "Стаки: каждое убийство +3% урона (до x2.5). При 10+ серии — следующее = ваншот.",
        passiveID = "hunter_stacks", unlockCost = 60,
        color = Color(100, 160, 255),
    },
}

-- ============================================================
--  DIFFICULTIES
-- ============================================================
NAA.Difficulties = {
    easy = {
        id = "easy", name = "Прогулка", hpMult = 0.6, countMult = 0.7,
        lives = 999, itemChanceMult = 1.5, rareBonus = 0, bossEvery = 10,
        neoMult = 0.8, unlockCost = 0, color = Color(80, 200, 120),
    },
    normal = {
        id = "normal", name = "Выживание", hpMult = 1.0, countMult = 1.0,
        lives = 5, itemChanceMult = 1.0, rareBonus = 0, bossEvery = 10,
        neoMult = 1.0, unlockCost = 0, color = Color(180, 180, 180),
    },
    hardcore = {
        id = "hardcore", name = "Хардкор", hpMult = 1.8, countMult = 1.4,
        lives = 3, itemChanceMult = 0.7, rareBonus = 5, bossEvery = 8,
        neoMult = 1.5, unlockCost = 0, color = Color(240, 160, 40),
    },
    extreme = {
        id = "extreme", name = "Экстрим", hpMult = 3.0, countMult = 2.0,
        lives = 1, itemChanceMult = 0.3, rareBonus = 10, bossEvery = 7,
        neoMult = 2.0, unlockCost = 50, color = Color(220, 60, 60),
    },
    apocalypse = {
        id = "apocalypse", name = "Апокалипсис", hpMult = 5.0, countMult = 3.0,
        lives = 1, itemChanceMult = 0.05, rareBonus = 15, bossEvery = 5,
        neoMult = 3.0, unlockCost = 200, color = Color(255, 40, 40),
    },
}

-- ============================================================
--  WAVE EVENTS
-- ============================================================
NAA.WaveEvents = {
    { id="normal",    name="Обычная волна",       desc="",                                   weight=30 },
    { id="swarm",     name="РОЙ!",                desc="Вдвое больше врагов, быстрый спавн", weight=16 },
    { id="berserk",   name="БЕРСЕРК-ОРДА!",       desc="Все враги x1.8 скорости",            weight=14 },
    { id="kamikaze",  name="КАМИКАДЗЕ!",           desc="Все враги взрываются при смерти",    weight=12 },
    { id="armored",   name="БРОНЯ!",               desc="Все враги получают -50% урона",      weight=10 },
    { id="healers",   name="ЛЕЧИТЕЛИ!",            desc="Враги лечат друг друга",             weight=9  },
    { id="ghost",     name="ПРИЗРАКИ!",            desc="Враги почти невидимы",               weight=5  },
    { id="elite",     name="ЭЛИТА!",               desc="Только мини-боссы и спецтипы",       weight=4  },
}

-- ============================================================
--  ENEMY TYPES
-- ============================================================
NAA.EnemyTypes = {
    normal    = { hp=5,  scale=1.0, spawnWeight=40, wepPool={"weapon_pistol","weapon_smg1"}, color=Color(220,220,220), unlockWave=1 },
    runner    = { hp=3,  scale=0.7, spawnWeight=20, wepPool={"weapon_stunstick"}, color=Color(100,200,255), unlockWave=2 },
    kamikaze  = { hp=4,  scale=1.0, spawnWeight=15, wepPool={"weapon_pistol"}, color=Color(255,80,0), unlockWave=3 },
    healer    = { hp=8,  scale=1.0, spawnWeight=10, wepPool={"weapon_pistol"}, color=Color(80,220,80), unlockWave=4 },
    armored   = { hp=6,  scale=1.0, spawnWeight=8,  wepPool={"weapon_smg1","weapon_shotgun"}, color=Color(120,160,255), unlockWave=5 },
    berserker = { hp=12, scale=1.2, spawnWeight=7,  wepPool={"weapon_shotgun"}, color=Color(255,60,60), unlockWave=6 },
    ghost     = { hp=4,  scale=0.9, spawnWeight=5,  wepPool={"weapon_pistol"}, color=Color(180,180,255), unlockWave=8 },
    tank      = { hp=60, scale=2.2, spawnWeight=3,  wepPool={"weapon_stunstick"}, color=Color(160,80,40), unlockWave=10 },
}

NAA.SpecialTypes = {
    { class="neco_sniper",   minWave=5, weight=6 },
    { class="neco_summoner", minWave=7, weight=4 },
}

NAA.MiniBosses = {
    shadow      = { class="neco_miniboss_shadow",      name="Теневой Охотник",           minWave=12, spawnChance=0.05, hp=250, scale=1.1, color=Color(80,0,120)    },
    colossus    = { class="neco_miniboss_colossus",    name="Бронированный Колосс",      minWave=15, spawnChance=0.05, hp=600, scale=2.5, color=Color(120,160,255) },
    necromancer = { class="neco_miniboss_necromancer", name="Некромант Неко",             minWave=18, spawnChance=0.05, hp=180, scale=1.0, color=Color(180,80,255)  },
    elemental   = { class="neco_miniboss_elemental",   name="Электрический Элементаль",  minWave=25, spawnChance=0.05, hp=350, scale=1.2, color=Color(80,160,255)  },
}

-- ============================================================
--  NPC INFO TABLE (used in stats menu)
-- ============================================================
NAA.NPCInfo = {
    -- Обычные враги
    { name="Обычная Неко",       type="normal",    cat="regular",  hp=5,   speed=160, scale=1.0,  wave=1,
      desc="Базовый враг. Стреляет из пистолета или SMG. Низкий HP, опасен в группе.",
      color=Color(220,220,220) },
    { name="Бегун Неко",         type="runner",    cat="regular",  hp=3,   speed=220, scale=0.7,  wave=2,
      desc="Маленький и быстрый. Атакует в ближнем бою. Гибнет быстро, но стая накрывает мгновенно.",
      color=Color(100,200,255) },
    { name="Камикадзе Неко",     type="kamikaze",  cat="regular",  hp=15,  speed=200, scale=1.0,  wave=3,
      desc="Бросается на цель и взрывается. Имеет рывок на последних HP. Держи дистанцию.",
      color=Color(255,80,0) },
    { name="Лекарь Неко",        type="healer",    cat="regular",  hp=8,   speed=160, scale=1.0,  wave=4,
      desc="Лечит ближайших союзников каждые несколько секунд. Приоритет уничтожения — высокий.",
      color=Color(80,220,80) },
    { name="Бронированная Неко", type="armored",   cat="regular",  hp=6,   speed=160, scale=1.0,  wave=5,
      desc="Получает -50% урона от обычных атак. Взрывчатка и дробовик — её слабость.",
      color=Color(120,160,255) },
    { name="Берсерк Неко",       type="berserker", cat="regular",  hp=30,  speed=190, scale=1.2,  wave=6,
      desc="Крупный боец ближнего боя. При низком HP ускоряется и наносит больше урона.",
      color=Color(255,60,60) },
    { name="Призрачная Неко",    type="ghost",     cat="regular",  hp=30,  speed=190, scale=0.9,  wave=8,
      desc="Почти полностью невидима. Высокий HP для своего тира. Сложна для прицеливания.",
      color=Color(180,180,255) },
    { name="Танк Неко",          type="tank",      cat="regular",  hp=60,  speed=170, scale=2.2,  wave=10,
      desc="Огромный, медленный, с мощным ударом ближнего боя. Требует сосредоточенного огня.",
      color=Color(160,80,40) },
    -- Специальные
    { name="Неко-Снайпер",       type="neco_sniper",   cat="special",  hp=8,   speed=190, scale=0.95, wave=5,
      desc="Ведёт прицельный огонь с дальней дистанции. Высокий разовый урон. Медленная перезарядка.",
      color=Color(255,220,40) },
    { name="Неко-Призыватель",   type="neco_summoner", cat="special",  hp=20,  speed=170, scale=1.1,  wave=7,
      desc="Регулярно призывает обычных Неко. Чем дольше живёт — тем больше врагов на карте.",
      color=Color(200,100,255) },
    -- Мини-боссы
    { name="Теневой Охотник",    type="neco_miniboss_shadow",      cat="miniboss", hp=250, speed=240, scale=1.1, wave=12,
      desc="Быстрый и сильный. Периодически становится невидимым и наносит удар из невидимости.",
      color=Color(80,0,120) },
    { name="Бронир. Колосс",     type="neco_miniboss_colossus",    cat="miniboss", hp=600, speed=140, scale=2.5, wave=15,
      desc="Живучее чудовище. Огромный радиус удара. Держи дистанцию и бей из-за укрытий.",
      color=Color(120,160,255) },
    { name="Некромант Неко",     type="neco_miniboss_necromancer", cat="miniboss", hp=180, speed=160, scale=1.0, wave=18,
      desc="Поднимает убитых врагов как зомби. Нейтрализуй в первую очередь, пока армия не выросла.",
      color=Color(180,80,255) },
    { name="Электро-Элементаль", type="neco_miniboss_elemental",   cat="miniboss", hp=350, speed=200, scale=1.2, wave=25,
      desc="Наносит урон молниями по площади. Создаёт электрические зоны на земле. Постоянно движется.",
      color=Color(80,160,255) },
    -- Боссы
    { name="Гигант Неко",        type="neco_boss_giant",     cat="boss", hp=2200, speed=90,  scale=2.2, wave=10,
      desc="Первый настоящий босс. Огромный, медленный. Удары сотрясают землю (AoE-урон вокруг).",
      color=Color(255,140,0) },
    { name="Берсерк Лорд",       type="neco_boss_berserker", cat="boss", hp=1200, speed=120, scale=2.5, wave=20,
      desc="Агрессивный босс ближнего боя. При HP ниже 40% — режим ярости: двойная скорость и урон.",
      color=Color(220,40,40) },
    { name="Гнездо Роя",         type="neco_boss_swarm",     cat="boss", hp=800,  speed=0,   scale=3.0, wave=30,
      desc="Неподвижен, но непрерывно рождает врагов. Волна не завершится, пока он жив. Приоритет.",
      color=Color(200,100,255) },
    { name="Апекс Неко",         type="neco_boss_apex",      cat="boss", hp=5000, speed=130, scale=5.0, wave=40,
      desc="Финальный босс. Колоссальный размер, несколько фаз атак, высокая скорость. Всё или ничего.",
      color=Color(255,40,40) },
}

-- ============================================================
--  UPGRADES
-- ============================================================
NAA.Upgrades = {
    -- ДВИЖЕНИЕ
    fast_feet     = { id="fast_feet",     name="Быстрые ноги",     category="move",    icon="", desc="+18 к базовой скорости",                               rarity="common",    maxStacks=10 },
    adrenaline    = { id="adrenaline",    name="Адреналин",        category="move",    icon="",  desc="+20% скорости на 4 сек после убийства",                rarity="common",    maxStacks=8  },
    light_step    = { id="light_step",    name="Лёгкая поступь",   category="move",    icon="",  desc="-15% отдача от оружия",                                rarity="common",    maxStacks=5  },
    double_jump   = { id="double_jump",   name="Двойной прыжок",   category="move",    icon="", desc="Сильный прыжок!",                                  rarity="uncommon",  maxStacks=3  },
    slippery      = { id="slippery",      name="Скользкое масло",  category="move",    icon="", desc="+30% скорость, но выше инерция",                       rarity="uncommon",  maxStacks=5  },
    dash          = { id="dash",          name="Уклонение",        category="move",    icon="", desc="Shift+W = рывок вперёд, кд 8 сек",                     rarity="rare",      maxStacks=3  },
    counter_rush  = { id="counter_rush",  name="Контратака",       category="move",    icon="",  desc="После получения урона: 2 сек +40% скорости",           rarity="rare",      maxStacks=4  },
    ghost_step    = { id="ghost_step",    name="Призрачный шаг",   category="move",    icon="", desc="1.5 сек неуязвимости после урона (кд 20 сек)",         rarity="epic",      maxStacks=2  },
    lightning     = { id="lightning",     name="Молния",           category="move",    icon="",  desc="Постоянная скорость x1.6 (стакается)",                 rarity="legendary", maxStacks=3  },
    -- АТАКА
    heavy_bullets     = { id="heavy_bullets",     name="Тяжёлые пули",     category="attack", icon="", desc="+18% урона",                                    rarity="common",    maxStacks=20 },
    sharp_eye         = { id="sharp_eye",         name="Острый глаз",      category="attack", icon="",  desc="+12% точность, -5% разброс",                   rarity="common",    maxStacks=10 },
    fast_trigger      = { id="fast_trigger",      name="Быстрый палец",    category="attack", icon="",  desc="+10% скорость стрельбы",                       rarity="common",    maxStacks=10 },
    vampirism         = { id="vampirism",          name="Вампиризм",        category="attack", icon="",   desc="+3 HP за убийство",                            rarity="uncommon",  maxStacks=10 },
    crit              = { id="crit",               name="Критический удар", category="attack", icon="",  desc="15% шанс x2.5 урона",                          rarity="rare",      maxStacks=5  },
    explosive_bullets = { id="explosive_bullets",  name="Взрывные пули",   category="attack", icon="",  desc="При попадании — взрыв радиус 70, урон 25",          rarity="rare",      maxStacks=4  },
    poison            = { id="poison",             name="Ядовитый",         category="attack", icon="",  desc="Враги горят 4 сек (3 урона/сек) после попадания", rarity="rare", maxStacks=5 },
    boss_hunter       = { id="boss_hunter",        name="Охота на боссов",  category="attack", icon="",  desc="+40% урона по мини-боссам и боссам",           rarity="epic",      maxStacks=5  },
    mega_shot         = { id="mega_shot",          name="МЕГА-УДАР",        category="attack", icon="", desc="Каждый 7-й выстрел — ваншот (не боссов)", rarity="legendary", maxStacks=2 },
    -- ЗАЩИТА
    medkit       = { id="medkit",       name="Аптечка",           category="defense", icon="", desc="Разово +35 HP",                                   rarity="common",    maxStacks=50 },
    armor_pack   = { id="armor_pack",   name="Укреплённая броня", category="defense", icon="", desc="+30 к максимальной броне, +30 текущей",           rarity="common",    maxStacks=10 },
    regen        = { id="regen",        name="Регенерация",       category="defense", icon="",  desc="+1 HP каждые 3 сек",                              rarity="uncommon",  maxStacks=10 },
    steel_skin   = { id="steel_skin",   name="Стальная кожа",     category="defense", icon="", desc="-10% входящего урона",                            rarity="uncommon",  maxStacks=6  },
    shield       = { id="shield",       name="Щит",               category="defense", icon="",  desc="Поглощает 1 попадание каждые 22 сек",             rarity="rare",      maxStacks=3  },
    last_chance  = { id="last_chance",  name="Последний шанс",    category="defense", icon="", desc="1 раз за забег: выжить с 1 HP вместо смерти",     rarity="epic",      maxStacks=1  },
    adaptation   = { id="adaptation",   name="Адаптация",         category="defense", icon="", desc="После урона: +5% сопротивление тому же типу (до 40%)", rarity="epic", maxStacks=3 },
    immortality  = { id="immortality",  name="Бессмертие",        category="defense", icon="", desc="4 сек неуязвимости каждые 55 сек при HP < 20%",   rarity="legendary", maxStacks=2  },
    -- ОСОБЫЕ
    magnet          = { id="magnet",          name="Магнит",           category="special", icon="",  desc="Предметы притягиваются в радиусе 280",          rarity="common",    maxStacks=5 },
    lucky           = { id="lucky",           name="Удача",            category="special", icon="",  desc="+20% к шансу дропа предметов",                  rarity="uncommon",  maxStacks=5 },
    coin_rain       = { id="coin_rain",       name="Монетный дождь",   category="special", icon="", desc="+1 монета за каждое убийство",                   rarity="uncommon",  maxStacks=5 },
    detective       = { id="detective",       name="Детектив",         category="special", icon="",  desc="Над врагами виден HP-бар",                       rarity="uncommon",  maxStacks=1 },
    time_bubble     = { id="time_bubble",     name="Временной пузырь", category="special", icon="", desc="E: враги  радиус 300 замедлены 4 сек, кд 18 сек", rarity="rare", maxStacks=3 },
    drone           = { id="drone",           name="Дрон-камикадзе",   category="special", icon="", desc="Каждые 28 сек: взрывной дрон к ближайшему врагу", rarity="rare",     maxStacks=4 },
    ally_neco       = { id="ally_neco",       name="Союзная Неко",     category="special", icon="", desc="Дружественная Неко Арк сражается за тебя",       rarity="epic",      maxStacks=3 },
    reflect         = { id="reflect",         name="Отражение",        category="special", icon="", desc="20% шанс отразить 30% урона обратно NPC",        rarity="epic",      maxStacks=4 },
    death_curse     = { id="death_curse",     name="Проклятие смерти", category="special", icon="", desc="Убитые враги взрываются, нанося 15 урона соседям радиус 120", rarity="epic", maxStacks=4 },
    apocalypse_card = { id="apocalypse_card", name="АПОКАЛИПСИС",      category="special", icon="", desc="При смерти: взрыв радиус 600, потом воскресение с 30 HP", rarity="legendary", maxStacks=1 },
}

-- ============================================================
--  SYNERGIES
-- ============================================================
NAA.Synergies = {
    {
        id="lifesteal_regen", name="Жизнелюб",
        desc="+5 HP за убийство вместо +3, +2 HP/сек вместо +1",
        requires={ "vampirism", "regen" }, color=Color(80,220,120),
    },
    {
        id="acrobat", name="Акробат",
        desc="3-й прыжок + рывок без кулдауна при двойном прыжке",
        requires={ "double_jump", "dash" }, color=Color(120,200,255),
    },
    {
        id="piercer", name="Пробойник",
        desc="Криты делают x4 урона вместо x2.5",
        requires={ "crit", "heavy_bullets" }, color=Color(255,120,40),
    },
    {
        id="sprinter", name="Спринтер",
        desc="Скорость после убийства x2.2 вместо x1.2",
        requires={ "adrenaline", "fast_feet" }, color=Color(120,255,200),
    },
    {
        id="berserker_rush", name="Ярость",
        desc="Скорость атаки x2 при HP < 50% (только Берсерк)",
        requires={ "adrenaline", "fast_trigger" }, classRequired="berserker", color=Color(220,40,40),
    },
    {
        id="regen_shield", name="Регенерирующий щит",
        desc="Щит восстанавливается за каждые 5 убийств (не по времени)",
        requires={ "shield", "vampirism" }, color=Color(80,140,255),
    },
    {
        id="immortal_berserk", name="Бессмертный берсерк",
        desc="После Последнего шанса: постоянный x2.8 урона",
        requires={ "last_chance", "heavy_bullets" }, classRequired="berserker", color=Color(220,60,200),
    },
    {
        id="lucky_magnet", name="Везунчик",
        desc="Монеты тоже притягиваются. +40% дроп вместо +20%",
        requires={ "magnet", "lucky" }, color=Color(255,220,40),
    },
    {
        id="sniper_crit", name="Снайпер поневоле",
        desc="Шанс крита x2 по врагам с видимым HP-баром",
        requires={ "detective", "crit" }, color=Color(40,160,255),
    },
    {
        id="time_bomb", name="Временная мина",
        desc="Взрывы при попадании замедляют врага на 2 сек",
        requires={ "time_bubble", "explosive_bullets" }, color=Color(180,100,255),
    },
    {
        id="drone_killer", name="Дрон-убийца",
        desc="Взрыв дрона в x2 радиусе и x2 уроне",
        requires={ "drone", "explosive_bullets" }, color=Color(255,80,0),
    },
    {
        id="army", name="Армия",
        desc="2 союзницы одновременно (нужно 2 стака Союзной Неко)",
        requires={ "ally_neco", "ally_neco" }, color=Color(200,160,255),
    },
    {
        id="plague_death", name="Мор",
        desc="Отравленные враги при смерти взрываются с ядом",
        requires={ "poison", "death_curse" }, color=Color(60,200,60),
    },
    {
        id="monster_hunter", name="Охотник на монстров",
        desc="МЕГА-УДАР работает на мини-боссов, x3 урона по боссам",
        requires={ "boss_hunter", "mega_shot" }, color=Color(255,200,0),
    },
}

-- ============================================================
--  RARITY & CATEGORY CONFIG
-- ============================================================
NAA.RarityConfig = {
    common     = { name="Обычная",   color=Color(180,180,180), baseWeight=55 },
    uncommon   = { name="Необычная", color=Color(80,200,100),  baseWeight=25 },
    rare       = { name="Редкая",    color=Color(80,140,255),  baseWeight=13 },
    epic       = { name="Эпическая", color=Color(180,80,255),  baseWeight=6  },
    legendary  = { name="Легенд.",   color=Color(255,210,40),  baseWeight=1  },
}

NAA.CategoryConfig = {
    move    = { name="Движение", color=Color(120,200,255), icon="" },
    attack  = { name="Атака",   color=Color(255,120,80),  icon="" },
    defense = { name="Защита",  color=Color(80,220,80),   icon="" },
    special = { name="Особые",  color=Color(220,160,255), icon="" },
}

-- ============================================================
--  UTILITY
-- ============================================================
function NAA.GetDiff(id) return NAA.Difficulties[id] or NAA.Difficulties.normal end
function NAA.GetClass(id) return NAA.Classes[id] or NAA.Classes.survivor end
function NAA.GetUpgrade(id) return NAA.Upgrades[id] end

function NAA.HasSynergy(upgrades, classId, syn)
    if syn.classRequired and syn.classRequired ~= classId then return false end
    local counts = {}
    for _, req in ipairs(syn.requires) do counts[req] = (counts[req] or 0) + 1 end
    for req, needed in pairs(counts) do
        if (upgrades[req] or 0) < needed then return false end
    end
    return true
end

function NAA.GetActiveSynergies(upgrades, classId)
    local active = {}
    for _, syn in ipairs(NAA.Synergies) do
        if NAA.HasSynergy(upgrades, classId, syn) then
            active[syn.id] = true
        end
    end
    return active
end

function NAA.PickCards(rareBonus, existingUpgrades)
    rareBonus = rareBonus or 0
    local pool = {}
    for id, upg in pairs(NAA.Upgrades) do
        local rc = NAA.RarityConfig[upg.rarity]
        local w  = rc.baseWeight
        local bonus = 0
        if upg.rarity == "rare"      then bonus = rareBonus end
        if upg.rarity == "epic"      then bonus = rareBonus * 0.5 end
        if upg.rarity == "legendary" then bonus = rareBonus * 0.2 end
        local current = (existingUpgrades or {})[id] or 0
        if current < (upg.maxStacks or 1) then
            pool[#pool+1] = { id=id, weight=w+bonus }
        end
    end
    local picked = {}
    local used   = {}
    for i = 1, 3 do
        local total = 0
        for _, e in ipairs(pool) do
            if not used[e.id] then total = total + e.weight end
        end
        if total == 0 then break end
        local roll = math.random() * total
        for _, e in ipairs(pool) do
            if not used[e.id] then
                roll = roll - e.weight
                if roll <= 0 then
                    picked[i] = e.id
                    used[e.id] = true
                    break
                end
            end
        end
    end
    return picked
end
