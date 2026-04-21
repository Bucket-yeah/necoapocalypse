-- ============================================================
--  NECO ARC APOCALYPSE — cl_devmode.lua (CLIENT)
--  Режим разработчика — красивый интерфейс
--  Открывается на F9 (только при sv_cheats 1)
-- ============================================================
if not CLIENT then return end

NAA_DEV = NAA_DEV or {}
NAA_DEV.GodMode = false
NAA_DEV.Cheats  = false
NAA_DEV.Open    = false

-- ============================================================
--  ШРИФТЫ
-- ============================================================
surface.CreateFont("NAA_Dev_Title", {
    font="Trebuchet MS", size=28, weight=900, antialias=true,
})
surface.CreateFont("NAA_Dev_H2", {
    font="Trebuchet MS", size=18, weight=700, antialias=true,
})
surface.CreateFont("NAA_Dev_Body", {
    font="Trebuchet MS", size=14, weight=500, antialias=true,
})
surface.CreateFont("NAA_Dev_Small", {
    font="Trebuchet MS", size=12, weight=600, antialias=true,
})
surface.CreateFont("NAA_Dev_Mono", {
    font="Courier New", size=13, weight=400, antialias=true,
})
surface.CreateFont("NAA_Dev_Icon", {
    font="Trebuchet MS", size=20, weight=900, antialias=true,
})

-- ============================================================
--  ЦВЕТОВАЯ ПАЛИТРА
-- ============================================================
local C = {
    bg        = Color(5,  3,  14,  252),
    panel     = Color(11, 7,  22,  240),
    tab_bg    = Color(9,  6,  18),
    tab_act   = Color(190, 25, 85),
    tab_hov   = Color(30, 18, 48),
    sep       = Color(55,  30, 85),
    accent1   = Color(255, 50, 120),
    accent2   = Color(50, 215, 255),
    text      = Color(230, 220, 255),
    text_dim  = Color(110, 90, 145),
    gold      = Color(255, 210, 40),
    green     = Color(60,  220, 130),
    red       = Color(255, 55,  80),
    orange    = Color(255, 150, 30),
    border    = Color(65,  30,  100),
    -- Редкости
    common    = Color(180, 180, 180),
    uncommon  = Color(80,  200, 100),
    rare      = Color(80,  145, 255),
    epic      = Color(185, 80,  255),
    legendary = Color(255, 210, 40),
}

-- Утилита: рисуем кнопку
local function DrawBtn(x, y, w, h, label, font, hovered, active, acol)
    local bg = active and (acol or C.accent1) or
               (hovered and Color(35, 22, 55) or Color(16, 10, 30))
    draw.RoundedBox(5, x, y, w, h, bg)
    surface.SetDrawColor(active and (acol or C.accent1) or C.sep)
    surface.DrawOutlinedRect(x, y, w, h)
    draw.SimpleText(label, font or "NAA_Dev_Body", x + w/2, y + h/2,
        hovered and Color(255,255,255) or C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- ============================================================
--  ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ОТПРАВКИ КОМАНДЫ
-- ============================================================
local function SendDev(cmd, args)
    net.Start("NAA_DevCommand")
        net.WriteString(cmd)
        net.WriteString(util.TableToJSON(args or {}))
    net.SendToServer()
end

-- ============================================================
--  СОЗДАНИЕ ПАНЕЛИ
-- ============================================================
local DevPanel  = nil
local PW, PH    = 980, 660
local TAB_W     = 162
local CONT_X    = TAB_W + 6
local CONT_Y    = 44
local CONT_W, CONT_H = PW - CONT_X - 6, PH - CONT_Y - 6

local TABS = {
    { id="player",    icon="👤", label="ИГРОК"    },
    { id="upgrades",  icon="⚡", label="АПГРЕЙДЫ" },
    { id="waves",     icon="🌊", label="ВОЛНЫ"    },
    { id="economy",   icon="💰", label="МОНЕТЫ"   },
    { id="synergies", icon="✨", label="СИНЕРГИИ" },
    { id="spawn",     icon="💥", label="СПАВН"    },
}

-- ============================================================
--  ТАБ: ИГРОК
-- ============================================================
local function BuildPlayerTab(parent)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(0, 0); p:SetSize(CONT_W, CONT_H)
    p.Paint = function() end

    -- Заголовок
    local lbl = vgui.Create("DLabel", p)
    lbl:SetPos(16, 12); lbl:SetSize(CONT_W - 32, 24)
    lbl:SetText("ПАРАМЕТРЫ ИГРОКА"); lbl:SetFont("NAA_Dev_H2")
    lbl:SetColor(C.accent2)

    -- Класс
    local lblCls = vgui.Create("DLabel", p)
    lblCls:SetPos(16, 48); lblCls:SetSize(120, 18)
    lblCls:SetText("Класс:"); lblCls:SetFont("NAA_Dev_Body"); lblCls:SetColor(C.text_dim)

    local clsX = 16
    for _, cls in ipairs({"survivor", "medic", "berserker", "hunter"}) do
        local info = NAA.Classes[cls]
        local btn  = vgui.Create("DButton", p)
        btn:SetPos(clsX, 68); btn:SetSize(148, 34); btn:SetText("")
        local cid = cls
        btn.Paint = function(s, w, h)
            local isActive = (LocalPlayer():GetNWString("NAA_Class","") == cid)
            local bg = isActive and C.tab_act or (s:IsHovered() and C.tab_hov or Color(14,9,26))
            draw.RoundedBox(5, 0, 0, w, h, bg)
            surface.SetDrawColor(isActive and C.accent1 or C.sep)
            surface.DrawOutlinedRect(0, 0, w, h)
            draw.SimpleText(info.name, "NAA_Dev_Small", w/2, h/2, C.text,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function() SendDev("set_class", {class=cid}) end
        clsX = clsX + 154
    end

    -- HP / Armor слайдеры
    local function MakeSlider(labelText, ypos, min_, max_, startVal, cb)
        local lbPanel = vgui.Create("DPanel", p)
        lbPanel:SetPos(16, ypos); lbPanel:SetSize(CONT_W - 32, 36)
        lbPanel.Paint = function() end

        local lb = vgui.Create("DLabel", lbPanel)
        lb:SetPos(0, 8); lb:SetSize(80, 20); lb:SetText(labelText)
        lb:SetFont("NAA_Dev_Body"); lb:SetColor(C.text_dim)

        local sl = vgui.Create("DNumSlider", lbPanel)
        sl:SetPos(85, 4); sl:SetSize(CONT_W - 230, 28)
        sl:SetMin(min_); sl:SetMax(max_); sl:SetValue(startVal)
        sl:SetDecimals(0)
        -- Стиль
        sl:SetText("")

        local apply = vgui.Create("DButton", lbPanel)
        apply:SetPos(CONT_W - 140, 4); apply:SetSize(80, 28)
        apply:SetText("ПРИМЕНИТЬ"); apply:SetFont("NAA_Dev_Small")
        apply:SetTextColor(C.text)
        apply.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(40,20,70) or Color(20,12,38))
            surface.SetDrawColor(C.sep); surface.DrawOutlinedRect(0,0,w,h)
        end
        apply.DoClick = function() cb(sl:GetValue()) end

        return sl
    end

    local slHP    = MakeSlider("HP:", 118, 1, 9999, 100, function(v)
        SendDev("set_hp", {hp=math.floor(v)})
    end)
    local slArmor = MakeSlider("Броня:", 162, 0, 500, 100, function(v)
        SendDev("set_armor", {armor=math.floor(v)})
    end)
    local slSpeed = MakeSlider("Скорость:", 206, 50, 3000, 200, function(v)
        SendDev("set_speed", {speed=math.floor(v)})
    end)
    local slLives = MakeSlider("Жизни:", 250, 0, 999, 5, function(v)
        SendDev("set_lives", {lives=math.floor(v)})
    end)

    -- Кнопки быстрых действий
    local BTN_Y = 302
    local BTNS = {
        {label="❤ Полное лечение",  cmd="heal_full",      args={}},
        {label="💥 God Mode",        cmd="godmode",        args={}},
        {label="🔫 Полные патроны",  cmd="full_ammo",      args={}},
        {label="💀 Убить себя",       cmd="kill_self",      args={}},
        {label="🗡 Сбросить оружие", cmd="strip_weapons",  args={}},
    }
    local bx = 16
    for _, bd in ipairs(BTNS) do
        local bdata = bd
        local btn   = vgui.Create("DButton", p)
        btn:SetPos(bx, BTN_Y); btn:SetSize(170, 36); btn:SetText("")
        btn.Paint = function(s, w, h)
            local isGod = (bdata.cmd == "godmode" and NAA_DEV.GodMode)
            local bg = isGod and Color(120, 20, 50) or
                       (s:IsHovered() and Color(30, 18, 48) or Color(14, 9, 24))
            draw.RoundedBox(5, 0, 0, w, h, bg)
            surface.SetDrawColor(isGod and C.accent1 or C.sep)
            surface.DrawOutlinedRect(0, 0, w, h)
            draw.SimpleText(bdata.label, "NAA_Dev_Small", w/2, h/2,
                isGod and C.accent1 or C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function() SendDev(bdata.cmd, bdata.args) end
        bx = bx + 176
    end

    -- Статус (правая часть)
    local statPanel = vgui.Create("DPanel", p)
    statPanel:SetPos(CONT_W - 250, 48); statPanel:SetSize(240, 240)
    statPanel.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(8, 5, 18))
        surface.SetDrawColor(C.sep); surface.DrawOutlinedRect(0,0,w,h)
        draw.SimpleText("СТАТУС", "NAA_Dev_H2", w/2, 12, C.accent2, TEXT_ALIGN_CENTER)

        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local lines = {
            {"HP:",    math.floor(ply:Health()) .. "/" .. math.floor(ply:GetMaxHealth()), C.green},
            {"Броня:", math.floor(ply:Armor()),  C.accent2},
            {"Скорость:", math.floor(ply:GetVelocity():Length2D()), C.gold},
            {"Класс:", ply:GetNWString("NAA_Class","?"), C.text},
            {"Волна:", tostring(NAA and NAA.CurrentWave or 0), C.orange},
        }

        for i, row in ipairs(lines) do
            local yy = 40 + (i-1) * 36
            draw.SimpleText(row[1], "NAA_Dev_Body", 12, yy, C.text_dim)
            draw.SimpleText(tostring(row[2]), "NAA_Dev_Body", w - 12, yy, row[3], TEXT_ALIGN_RIGHT)
        end

        -- God mode индикатор
        if NAA_DEV.GodMode then
            draw.RoundedBox(4, 8, h-32, w-16, 24, Color(120, 20, 50, 200))
            draw.SimpleText("⚡ GOD MODE ACTIVE", "NAA_Dev_Small", w/2, h-20,
                C.accent1, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    return p
end

-- ============================================================
--  ТАБ: АПГРЕЙДЫ
-- ============================================================
local function BuildUpgradesTab(parent)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(0, 0); p:SetSize(CONT_W, CONT_H)
    p.Paint = function() end

    -- Фильтры по категории
    local filterCat = "all"
    local CATS = {
        {id="all",    label="ВСЕ",       col=C.text},
        {id="move",   label="ДВИЖЕНИЕ",  col=NAA.CategoryConfig.move.color},
        {id="attack", label="АТАКА",     col=NAA.CategoryConfig.attack.color},
        {id="defense",label="ЗАЩИТА",    col=NAA.CategoryConfig.defense.color},
        {id="special",label="ОСОБЫЕ",    col=NAA.CategoryConfig.special.color},
    }

    local filterBtns = {}
    local fx = 8
    for _, cat in ipairs(CATS) do
        local cdat = cat
        local btn  = vgui.Create("DButton", p)
        btn:SetPos(fx, 8); btn:SetSize(120, 28); btn:SetText("")
        filterBtns[#filterBtns+1] = {btn=btn, id=cdat.id}
        btn.Paint = function(s, w, h)
            local isAct = filterCat == cdat.id
            draw.RoundedBox(4, 0, 0, w, h, isAct and cdat.col or
                (s:IsHovered() and C.tab_hov or Color(12,8,22)))
            surface.SetDrawColor(cdat.col); surface.DrawOutlinedRect(0,0,w,h)
            draw.SimpleText(cdat.label, "NAA_Dev_Small", w/2, h/2,
                isAct and Color(0,0,0) or cdat.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            filterCat = cdat.id
            -- Обновить видимость карточек
            for _, row in ipairs(p.UpgradeRows or {}) do
                if IsValid(row.panel) then
                    local show = filterCat == "all" or row.cat == filterCat
                    row.panel:SetVisible(show)
                end
            end
            -- Перестроить layout
            if IsValid(p.ScrollPanel) then
                p.ScrollPanel:InvalidateLayout(true)
            end
        end
        fx = fx + 126
    end

    -- Кнопки массовых действий
    local massX = fx + 10
    local massActions = {
        {label="🎁 ВСЕ (×1)",    cmd="give_all_upgrades", args={}},
        {label="❌ СБРОСИТЬ",     cmd="reset_upgrades",    args={}},
    }
    for _, ma in ipairs(massActions) do
        local mdat = ma
        local btn  = vgui.Create("DButton", p)
        btn:SetPos(massX, 8); btn:SetSize(130, 28); btn:SetText("")
        btn.Paint = function(s, w, h)
            local col = mdat.cmd == "reset_upgrades" and C.red or C.green
            draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and col or Color(12,8,22))
            surface.SetDrawColor(col); surface.DrawOutlinedRect(0,0,w,h)
            draw.SimpleText(mdat.label, "NAA_Dev_Small", w/2, h/2,
                s:IsHovered() and Color(0,0,0) or col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function() SendDev(mdat.cmd, mdat.args) end
        massX = massX + 136
    end

    -- Прокручиваемый список апгрейдов
    local scroll = vgui.Create("DScrollPanel", p)
    scroll:SetPos(4, 44); scroll:SetSize(CONT_W - 8, CONT_H - 50)
    p.ScrollPanel = scroll

    -- Стиль скроллбара
    local sbar = scroll:GetVBar()
    sbar:SetWide(6)
    function sbar:Paint(w, h) draw.RoundedBox(3,0,0,w,h, Color(15,10,28)) end
    function sbar.btnUp:Paint(w, h) end
    function sbar.btnDown:Paint(w, h) end
    function sbar.btnGrip:Paint(w, h) draw.RoundedBox(3,0,0,w,h, C.accent1) end

    -- Сетка карточек апгрейдов
    local layout = vgui.Create("DIconLayout", scroll)
    layout:SetPos(0, 4)
    layout:SetSize(CONT_W - 14, CONT_H - 54)
    layout:SetSpaceX(4); layout:SetSpaceY(4)

    local CARD_W, CARD_H = 182, 100
    p.UpgradeRows = {}

    -- Сортируем по редкости
    local rarityOrder = {common=1, uncommon=2, rare=3, epic=4, legendary=5}
    local upgList = {}
    for id, upg in pairs(NAA.Upgrades) do
        upgList[#upgList+1] = {id=id, upg=upg}
    end
    table.sort(upgList, function(a, b)
        local ra = rarityOrder[a.upg.rarity] or 0
        local rb = rarityOrder[b.upg.rarity] or 0
        if ra ~= rb then return ra < rb end
        return a.id < b.id
    end)

    for _, entry in ipairs(upgList) do
        local id  = entry.id
        local upg = entry.upg
        local rc  = NAA.RarityConfig[upg.rarity]
        local cat = NAA.CategoryConfig[upg.category]

        local card = vgui.Create("DPanel", layout)
        card:SetSize(CARD_W, CARD_H)
        card.cat = upg.category
        p.UpgradeRows[#p.UpgradeRows+1] = {panel=card, cat=upg.category}

        card.Paint = function(s, w, h)
            local curStacks = (NAA.ClientUpgrades or {})[id] or 0
            local maxStacks = upg.maxStacks or 1

            -- Фон
            draw.RoundedBox(5, 0, 0, w, h, Color(10, 7, 20))

            -- Полоска редкости сверху
            surface.SetDrawColor(rc.color)
            surface.DrawRect(0, 0, w, 3)

            -- Фон иконки категории
            draw.SimpleText(upg.icon or "•", "NAA_Dev_Icon", 14, 26,
                cat.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Название
            draw.SimpleText(upg.name, "NAA_Dev_Small", w/2 + 6, 14,
                Color(240, 235, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Редкость
            draw.SimpleText(rc.name, "NAA_Dev_Small", w - 6, 6,
                rc.color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

            -- Описание (кратко)
            local shortDesc = upg.desc
            if #shortDesc > 40 then shortDesc = shortDesc:sub(1,37) .. "..." end
            draw.SimpleText(shortDesc, "NAA_Dev_Small", 4, 26,
                C.text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- Стаки: прогресс-бар
            local barW = w - 8
            local prog = curStacks / maxStacks
            draw.RoundedBox(3, 4, h - 22, barW, 8, Color(20, 12, 35))
            if prog > 0 then
                local col = curStacks >= maxStacks and C.gold or rc.color
                draw.RoundedBox(3, 4, h - 22, math.floor(barW * prog), 8, col)
            end
            draw.SimpleText(curStacks .. "/" .. maxStacks, "NAA_Dev_Small",
                w/2, h - 11, curStacks >= maxStacks and C.gold or C.text_dim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Рамка при стаках
            if curStacks > 0 then
                surface.SetDrawColor(rc.color.r, rc.color.g, rc.color.b, 80)
                surface.DrawOutlinedRect(0, 0, w, h)
            end
        end

        -- Кнопки +/-/MAX
        local btnY = CARD_H + 2

        local btnMinus = vgui.Create("DButton", card)
        btnMinus:SetPos(2, CARD_H - 40); btnMinus:SetSize(28, 20); btnMinus:SetText("-")
        btnMinus:SetFont("NAA_Dev_H2"); btnMinus:SetTextColor(C.red)
        btnMinus.Paint = function(s, w, h)
            draw.RoundedBox(3, 0, 0, w, h, s:IsHovered() and Color(50, 15, 25) or Color(18,10,28))
        end
        btnMinus.DoClick = function() SendDev("remove_upgrade", {id=id}) end

        local btnPlus = vgui.Create("DButton", card)
        btnPlus:SetPos(32, CARD_H - 40); btnPlus:SetSize(28, 20); btnPlus:SetText("+")
        btnPlus:SetFont("NAA_Dev_H2"); btnPlus:SetTextColor(C.green)
        btnPlus.Paint = function(s, w, h)
            draw.RoundedBox(3, 0, 0, w, h, s:IsHovered() and Color(15, 50, 25) or Color(18,10,28))
        end
        btnPlus.DoClick = function() SendDev("give_upgrade", {id=id, count=1}) end

        local btnMax = vgui.Create("DButton", card)
        btnMax:SetPos(62, CARD_H - 40); btnMax:SetSize(50, 20); btnMax:SetText("МАКС")
        btnMax:SetFont("NAA_Dev_Small"); btnMax:SetTextColor(C.gold)
        btnMax.Paint = function(s, w, h)
            draw.RoundedBox(3, 0, 0, w, h, s:IsHovered() and Color(50, 38, 10) or Color(18,10,28))
        end
        btnMax.DoClick = function() SendDev("max_upgrade", {id=id}) end
    end

    return p
end

-- ============================================================
--  ТАБ: ВОЛНЫ
-- ============================================================
local function BuildWavesTab(parent)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(0, 0); p:SetSize(CONT_W, CONT_H)
    p.Paint = function() end

    local lbl = vgui.Create("DLabel", p)
    lbl:SetPos(16, 12); lbl:SetSize(300, 24)
    lbl:SetText("УПРАВЛЕНИЕ ВОЛНАМИ"); lbl:SetFont("NAA_Dev_H2"); lbl:SetColor(C.accent2)

    -- Текущая волна
    p.Paint = function(s, w, h)
        -- Инфо панель
        draw.RoundedBox(6, 12, 44, 280, 80, Color(8, 5, 18))
        surface.SetDrawColor(C.sep); surface.DrawOutlinedRect(12, 44, 280, 80)

        draw.SimpleText("Текущая волна:", "NAA_Dev_Body", 24, 64, C.text_dim)
        draw.SimpleText(tostring(NAA and NAA.CurrentWave or 0), "NAA_Dev_Title",
            200, 78, C.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        draw.SimpleText("Враги живые:", "NAA_Dev_Body", 24, 98, C.text_dim)
        draw.SimpleText(tostring(NAA and NAA.AliveEnemies or 0), "NAA_Dev_H2",
            200, 98, C.red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        draw.SimpleText("Фаза:", "NAA_Dev_Body", 24, 116, C.text_dim)
        draw.SimpleText(tostring(NAA and NAA.Phase or "?"), "NAA_Dev_Body",
            200, 116, C.accent2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Поле ввода номера волны
    local waveLbl = vgui.Create("DLabel", p)
    waveLbl:SetPos(16, 140); waveLbl:SetSize(160, 20)
    waveLbl:SetText("Перейти на волну:"); waveLbl:SetFont("NAA_Dev_Body"); waveLbl:SetColor(C.text)

    local waveEntry = vgui.Create("DTextEntry", p)
    waveEntry:SetPos(16, 164); waveEntry:SetSize(100, 30)
    waveEntry:SetText("1"); waveEntry:SetFont("NAA_Dev_H2")
    waveEntry:SetTextColor(C.gold)
    waveEntry.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(12, 8, 22))
        surface.SetDrawColor(C.sep); surface.DrawOutlinedRect(0,0,w,h)
        s:DrawTextEntryText(C.gold, Color(80,60,120), Color(255,255,255))
    end

    local setWaveBtn = vgui.Create("DButton", p)
    setWaveBtn:SetPos(120, 164); setWaveBtn:SetSize(100, 30); setWaveBtn:SetText("ПЕРЕЙТИ")
    setWaveBtn:SetFont("NAA_Dev_Small"); setWaveBtn:SetTextColor(C.text)
    setWaveBtn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and C.tab_act or Color(16,10,28))
        surface.SetDrawColor(C.sep); surface.DrawOutlinedRect(0,0,w,h)
    end
    setWaveBtn.DoClick = function()
        local wave = tonumber(waveEntry:GetText()) or 1
        SendDev("set_wave", {wave=math.Clamp(wave,1,999)})
    end

    -- Быстрые кнопки волн
    local quickY = 210
    local quickBtns = {
        {label="⏭ Пропустить волну",    cmd="skip_wave",          args={}},
        {label="🎁 Между волнами",       cmd="force_between_waves",args={}},
        {label="▶ Начать игру (1 волна)",cmd="start_game",         args={difficulty="normal"}},
    }
    for _, qb in ipairs(quickBtns) do
        local qdat = qb
        local btn  = vgui.Create("DButton", p)
        btn:SetPos(16, quickY); btn:SetSize(260, 36); btn:SetText("")
        btn.Paint = function(s, w, h)
            draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and C.tab_hov or Color(12,8,22))
            surface.SetDrawColor(C.sep); surface.DrawOutlinedRect(0,0,w,h)
            draw.SimpleText(qdat.label, "NAA_Dev_Body", w/2, h/2, C.text,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function() SendDev(qdat.cmd, qdat.args) end
        quickY = quickY + 42
    end

    -- Выбор сложности
    local diffLbl = vgui.Create("DLabel", p)
    diffLbl:SetPos(300, 44); diffLbl:SetSize(200, 20)
    diffLbl:SetText("Сложность:"); diffLbl:SetFont("NAA_Dev_H2"); diffLbl:SetColor(C.accent2)

    local dy = 70
    for did, diff in pairs(NAA.Difficulties) do
        local ddat = diff
        local btn  = vgui.Create("DButton", p)
        btn:SetPos(300, dy); btn:SetSize(200, 32); btn:SetText("")
        btn.Paint = function(s, w, h)
            local isActive = (NAA and NAA.Difficulty == ddat.id)
            draw.RoundedBox(4, 0, 0, w, h, isActive and Color(ddat.color.r, ddat.color.g, ddat.color.b, 150)
                or (s:IsHovered() and C.tab_hov or Color(12,8,22)))
            surface.SetDrawColor(ddat.color); surface.DrawOutlinedRect(0,0,w,h)
            draw.SimpleText(ddat.name, "NAA_Dev_Body", w/2, h/2, C.text,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            SendDev("start_game", {difficulty=ddat.id})
        end
        dy = dy + 38
    end

    return p
end

-- ============================================================
--  ТАБ: МОНЕТЫ
-- ============================================================
local function BuildEconomyTab(parent)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(0, 0); p:SetSize(CONT_W, CONT_H)
    p.Paint = function(s, w, h)
        draw.RoundedBox(6, 12, 44, 300, 90, Color(8, 5, 18))
        surface.SetDrawColor(C.sep); surface.DrawOutlinedRect(12, 44, 300, 90)

        draw.SimpleText("Монеты:", "NAA_Dev_Body", 24, 64, C.text_dim)
        draw.SimpleText(tostring(NAA.ClientCoins or 0), "NAA_Dev_Title",
            200, 84, C.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local lbl = vgui.Create("DLabel", p)
    lbl:SetPos(16, 12); lbl:SetSize(300, 24)
    lbl:SetText("ЭКОНОМИКА"); lbl:SetFont("NAA_Dev_H2"); lbl:SetColor(C.gold)

    -- Ввод количества монет
    local coinLbl = vgui.Create("DLabel", p)
    coinLbl:SetPos(16, 150); coinLbl:SetSize(200, 20)
    coinLbl:SetText("Установить монеты:"); coinLbl:SetFont("NAA_Dev_Body"); coinLbl:SetColor(C.text)

    local coinEntry = vgui.Create("DTextEntry", p)
    coinEntry:SetPos(16, 174); coinEntry:SetSize(120, 32)
    coinEntry:SetText("100"); coinEntry:SetFont("NAA_Dev_H2")
    coinEntry:SetTextColor(C.gold)
    coinEntry.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(12, 8, 22))
        surface.SetDrawColor(C.gold); surface.DrawOutlinedRect(0,0,w,h)
        s:DrawTextEntryText(C.gold, Color(80,60,30), Color(255,255,255))
    end

    local setBtn = vgui.Create("DButton", p)
    setBtn:SetPos(142, 174); setBtn:SetSize(90, 32); setBtn:SetText("УСТАНОВИТЬ")
    setBtn:SetFont("NAA_Dev_Small"); setBtn:SetTextColor(C.text)
    setBtn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and C.tab_act or Color(16,10,28))
        surface.SetDrawColor(C.sep); surface.DrawOutlinedRect(0,0,w,h)
    end
    setBtn.DoClick = function()
        local coins = tonumber(coinEntry:GetText()) or 0
        SendDev("set_coins", {coins=coins})
    end

    -- Быстрые кнопки добавления монет
    local addLbl = vgui.Create("DLabel", p)
    addLbl:SetPos(16, 220); addLbl:SetSize(200, 20)
    addLbl:SetText("Добавить монеты:"); addLbl:SetFont("NAA_Dev_Body"); addLbl:SetColor(C.text)

    local addAmounts = {10, 50, 100, 500, 1000}
    local ax = 16
    for _, amount in ipairs(addAmounts) do
        local amt = amount
        local btn = vgui.Create("DButton", p)
        btn:SetPos(ax, 244); btn:SetSize(80, 32); btn:SetText("+" .. amt)
        btn:SetFont("NAA_Dev_Body"); btn:SetTextColor(C.gold)
        btn.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(50, 38, 10) or Color(14,10,22))
            surface.SetDrawColor(C.gold); surface.DrawOutlinedRect(0,0,w,h)
        end
        btn.DoClick = function() SendDev("add_coins", {amount=amt}) end
        ax = ax + 86
    end

    -- Neo Coins
    local neoLbl = vgui.Create("DLabel", p)
    neoLbl:SetPos(16, 300); neoLbl:SetSize(300, 20)
    neoLbl:SetText("Добавить НЕО-монеты:"); neoLbl:SetFont("NAA_Dev_Body"); neoLbl:SetColor(C.accent2)

    local neoAmounts = {50, 100, 500}
    local nx = 16
    for _, amount in ipairs(neoAmounts) do
        local amt = amount
        local btn = vgui.Create("DButton", p)
        btn:SetPos(nx, 324); btn:SetSize(90, 32); btn:SetText("+" .. amt)
        btn:SetFont("NAA_Dev_Body"); btn:SetTextColor(C.accent2)
        btn.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(10, 38, 55) or Color(14,10,22))
            surface.SetDrawColor(C.accent2); surface.DrawOutlinedRect(0,0,w,h)
        end
        btn.DoClick = function() SendDev("add_neocoin", {amount=amt}) end
        nx = nx + 96
    end

    return p
end

-- ============================================================
--  ТАБ: СИНЕРГИИ
-- ============================================================
local function BuildSynergiesTab(parent)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(0, 0); p:SetSize(CONT_W, CONT_H)
    p.Paint = function() end

    local lbl = vgui.Create("DLabel", p)
    lbl:SetPos(16, 12); lbl:SetSize(300, 24)
    lbl:SetText("СИНЕРГИИ"); lbl:SetFont("NAA_Dev_H2"); lbl:SetColor(C.accent2)

    local scroll = vgui.Create("DScrollPanel", p)
    scroll:SetPos(4, 44); scroll:SetSize(CONT_W - 8, CONT_H - 50)
    local sbar = scroll:GetVBar()
    sbar:SetWide(5)
    function sbar:Paint(w, h) draw.RoundedBox(3,0,0,w,h, Color(15,10,28)) end
    function sbar.btnUp:Paint(w, h) end
    function sbar.btnDown:Paint(w, h) end
    function sbar.btnGrip:Paint(w, h) draw.RoundedBox(3,0,0,w,h, C.accent1) end

    local innerW = CONT_W - 22
    local sy = 4
    for _, syn in ipairs(NAA.Synergies) do
        local syndat = syn
        local card   = vgui.Create("DPanel", scroll)
        card:SetPos(4, sy); card:SetSize(innerW, 72)
        card.Paint = function(s, w, h)
            local active = (NAA.ClientSynergies or {})[syndat.id]
            local col    = syndat.color or C.accent1
            local bg     = active and Color(col.r/6, col.g/6, col.b/6, 220) or Color(8,5,18,220)

            draw.RoundedBox(5, 0, 0, w, h, bg)
            surface.SetDrawColor(active and col or C.sep)
            surface.DrawOutlinedRect(0, 0, w, h)

            -- Индикатор активности
            if active then
                surface.SetDrawColor(col)
                surface.DrawRect(0, 0, 4, h)
                draw.SimpleText("✔ АКТИВНА", "NAA_Dev_Small", w - 8, 10,
                    col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            else
                draw.SimpleText("○ неактивна", "NAA_Dev_Small", w - 8, 10,
                    C.text_dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end

            draw.SimpleText(syndat.name, "NAA_Dev_H2", 16, 14,
                active and col or C.text_dim)

            draw.SimpleText(syndat.desc, "NAA_Dev_Body", 16, 36,
                active and C.text or C.text_dim)

            -- Требования
            local reqStr = "Требует: " .. table.concat(syndat.requires, " + ")
            if syndat.classRequired then
                reqStr = reqStr .. "  |  Класс: " .. syndat.classRequired
            end
            draw.SimpleText(reqStr, "NAA_Dev_Small", 16, 56, C.text_dim)
        end
        sy = sy + 78
    end

    -- Подгоняем высоту layout
    local inner = vgui.Create("DPanel", scroll)
    inner:SetSize(innerW, sy + 4)
    inner.Paint = function() end

    -- Перенести карточки в inner
    -- (Уже в scroll, этот panel только для высоты)

    return p
end

-- ============================================================
--  ТАБ: СПАВН ВРАГОВ
-- ============================================================
local function BuildSpawnTab(parent)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(0, 0); p:SetSize(CONT_W, CONT_H)
    p.Paint = function() end

    local lbl = vgui.Create("DLabel", p)
    lbl:SetPos(16, 12); lbl:SetSize(300, 24)
    lbl:SetText("СПАВН ВРАГОВ"); lbl:SetFont("NAA_Dev_H2"); lbl:SetColor(C.red)

    -- Количество
    local countLbl = vgui.Create("DLabel", p)
    countLbl:SetPos(16, 44); countLbl:SetSize(100, 20)
    countLbl:SetText("Количество:"); countLbl:SetFont("NAA_Dev_Body"); countLbl:SetColor(C.text)

    local countSlider = vgui.Create("DNumSlider", p)
    countSlider:SetPos(120, 40); countSlider:SetSize(250, 28)
    countSlider:SetMin(1); countSlider:SetMax(50); countSlider:SetValue(1)
    countSlider:SetDecimals(0); countSlider:SetText("")

    -- Стандартные типы врагов
    local ENEMY_LIST = {}
    for id, edata in pairs(NAA.EnemyTypes) do
        ENEMY_LIST[#ENEMY_LIST+1] = {id=id, name=id:gsub("^%l", string.upper), col=edata.color or C.text}
    end
    -- Специальные
    for _, st in ipairs(NAA.SpecialTypes or {}) do
        ENEMY_LIST[#ENEMY_LIST+1] = {id=st.class, name=st.class:gsub("neco_",""), col=C.accent2}
    end
    -- Мини-боссы
    for id, mb in pairs(NAA.MiniBosses or {}) do
        ENEMY_LIST[#ENEMY_LIST+1] = {id=mb.class, name=mb.name, col=Color(mb.color.r, mb.color.g, mb.color.b)}
    end

    table.sort(ENEMY_LIST, function(a,b) return a.name < b.name end)

    -- Сетка кнопок спавна
    local ex, ey = 8, 78
    local colCount = 0
    for _, edata in ipairs(ENEMY_LIST) do
        local ed = edata
        local btn = vgui.Create("DButton", p)
        btn:SetPos(ex, ey); btn:SetSize(190, 42); btn:SetText("")
        btn.Paint = function(s, w, h)
            draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and
                Color(ed.col.r/5, ed.col.g/5, ed.col.b/5, 220) or Color(10,7,20))
            surface.SetDrawColor(ed.col); surface.DrawOutlinedRect(0,0,w,h)
            draw.SimpleText("⚡ " .. ed.name:upper(), "NAA_Dev_Small", w/2, h/2 - 4,
                ed.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("нажми для спавна", "NAA_Dev_Small", w/2, h/2 + 10,
                C.text_dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            local count = math.floor(countSlider:GetValue())
            SendDev("spawn_enemy", {etype=ed.id, count=count})
        end
        colCount = colCount + 1
        if colCount >= 4 then
            colCount = 0
            ex = 8
            ey = ey + 48
        else
            ex = ex + 196
        end
    end

    -- Быстрые оружия
    local wepLbl = vgui.Create("DLabel", p)
    wepLbl:SetPos(16, ey + 60); wepLbl:SetSize(300, 20)
    wepLbl:SetText("Выдать оружие:"); wepLbl:SetFont("NAA_Dev_H2"); wepLbl:SetColor(C.accent2)

    local WEAPONS = {
        {id="weapon_smg1",   label="SMG1"},
        {id="weapon_shotgun",label="Дробовик"},
        {id="weapon_ar2",    label="AR2"},
        {id="weapon_pistol", label="Пистолет"},
        {id="weapon_crossbow",label="Арбалет"},
        {id="weapon_rpg",    label="РПГ"},
    }
    local wx = 16
    for _, wd in ipairs(WEAPONS) do
        local wdat = wd
        local btn  = vgui.Create("DButton", p)
        btn:SetPos(wx, ey + 84); btn:SetSize(115, 30); btn:SetText(wdat.label)
        btn:SetFont("NAA_Dev_Small"); btn:SetTextColor(C.text)
        btn.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and C.tab_hov or Color(12,8,22))
            surface.SetDrawColor(C.sep); surface.DrawOutlinedRect(0,0,w,h)
        end
        btn.DoClick = function() SendDev("give_weapon", {weapon=wdat.id}) end
        wx = wx + 121
    end

    return p
end

-- ============================================================
--  СОЗДАНИЕ ГЛАВНОЙ ПАНЕЛИ
-- ============================================================
function NAA_CreateDevPanel()
    if IsValid(DevPanel) then DevPanel:Remove() end

    local f = vgui.Create("DFrame")
    f:SetSize(PW, PH)
    f:Center()
    f:SetTitle("")
    f:ShowCloseButton(false)
    f:SetDraggable(true)
    f:MakePopup()
    DevPanel = f

    -- Scan-line анимация
    local scanY   = 0
    local scanTime = CurTime()

    f.Paint = function(s, w, h)
        -- Основной фон
        draw.RoundedBox(8, 0, 0, w, h, C.bg)

        -- Сетка фона (декоративная)
        surface.SetDrawColor(20, 12, 35, 60)
        for i = 0, w, 32 do surface.DrawLine(i, 0, i, h) end
        for i = 0, h, 32 do surface.DrawLine(0, i, w, i) end

        -- Scan-line эффект
        scanY = (CurTime() * 120) % (h + 20) - 10
        surface.SetDrawColor(255, 50, 120, 12)
        surface.DrawRect(0, scanY, w, 3)
        surface.SetDrawColor(255, 50, 120, 5)
        surface.DrawRect(0, scanY - 2, w, 1)
        surface.DrawRect(0, scanY + 3, w, 1)

        -- Шапка
        draw.RoundedBoxEx(8, 0, 0, w, 40, Color(14, 8, 28), true, true, false, false)
        surface.SetDrawColor(C.accent1)
        surface.DrawRect(0, 39, w, 1)

        -- Логотип/заголовок
        draw.SimpleText("⚡ NAA", "NAA_Dev_Title", 14, 20, C.accent1, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("DEVELOPER MODE", "NAA_Dev_H2", 94, 20, C.accent2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Статус читов
        local statusCol = NAA_DEV.Cheats and C.green or C.red
        local statusTxt = NAA_DEV.Cheats and "● sv_cheats ON" or "✕ sv_cheats OFF"
        draw.SimpleText(statusTxt, "NAA_Dev_Small", w - 140, 14, statusCol)

        -- Время
        draw.SimpleText(os.date("%H:%M:%S"), "NAA_Dev_Mono", w - 140, 26, C.text_dim)

        -- Разделитель контента/табов
        surface.SetDrawColor(C.sep)
        surface.DrawRect(TAB_W + 2, 44, 1, h - 44)

        -- Тень таб-бара
        surface.SetDrawColor(6, 3, 14)
        surface.DrawRect(0, 40, TAB_W + 2, h - 40)
    end

    -- Кнопка закрытия
    local closeBtn = vgui.Create("DButton", f)
    closeBtn:SetPos(PW - 34, 8); closeBtn:SetSize(26, 24)
    closeBtn:SetText("✕"); closeBtn:SetFont("NAA_Dev_H2"); closeBtn:SetTextColor(C.text_dim)
    closeBtn.Paint = function(s, w, h)
        if s:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, Color(80, 15, 25))
            s:SetTextColor(C.red)
        else
            s:SetTextColor(C.text_dim)
        end
    end
    closeBtn.DoClick = function() f:Remove(); DevPanel = nil; NAA_DEV.Open = false end

    -- ═══════════ ВКЛАДКИ ═══════════
    local activeTab = "player"
    local tabPanels = {}

    local function SwitchTab(id)
        activeTab = id
        for tid, tp in pairs(tabPanels) do
            if IsValid(tp) then tp:SetVisible(tid == id) end
        end
    end

    -- Кнопки вкладок
    for i, tab in ipairs(TABS) do
        local tdat = tab
        local btn  = vgui.Create("DButton", f)
        btn:SetPos(2, 44 + (i-1) * 52); btn:SetSize(TAB_W - 2, 48)
        btn:SetText("")

        btn.Paint = function(s, w, h)
            local isActive = activeTab == tdat.id
            local hovered  = s:IsHovered()
            local bg = isActive  and C.tab_act or
                       (hovered and C.tab_hov or C.tab_bg)
            draw.RoundedBox(4, 0, 0, w, h, bg)

            if isActive then
                -- Активная полоска справа
                surface.SetDrawColor(C.accent1)
                surface.DrawRect(w - 3, 0, 3, h)
                -- Свечение
                surface.SetDrawColor(255, 50, 120, 30)
                surface.DrawRect(0, 0, w - 3, h)
            end

            local col = isActive and Color(255,255,255) or
                        (hovered and Color(200, 190, 240) or C.text_dim)

            draw.SimpleText(tdat.icon, "NAA_Dev_Icon", 22, h/2 - 4, col,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(tdat.label, "NAA_Dev_Small", w/2 + 8, h/2 + 7, col,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function() SwitchTab(tdat.id) end
    end

    -- ═══════════ КОНТЕНТ-ПАНЕЛИ ═══════════
    local function WrapContent(buildFn)
        local container = vgui.Create("DPanel", f)
        container:SetPos(CONT_X + 2, CONT_Y + 2)
        container:SetSize(CONT_W - 4, CONT_H - 4)
        container.Paint = function() end
        local inner = buildFn(container)
        if IsValid(inner) then
            inner:SetParent(container)
            inner:SetPos(0, 0)
            inner:SetSize(CONT_W - 4, CONT_H - 4)
        end
        return container
    end

    tabPanels.player    = WrapContent(BuildPlayerTab)
    tabPanels.upgrades  = WrapContent(BuildUpgradesTab)
    tabPanels.waves     = WrapContent(BuildWavesTab)
    tabPanels.economy   = WrapContent(BuildEconomyTab)
    tabPanels.synergies = WrapContent(BuildSynergiesTab)
    tabPanels.spawn     = WrapContent(BuildSpawnTab)

    -- Изначально показываем Player таб
    SwitchTab("player")

    -- Обновление синергий каждые 0.5 сек
    timer.Create("NAA_DevSynUpdate", 0.5, 0, function()
        if not IsValid(f) then
            timer.Remove("NAA_DevSynUpdate")
            return
        end
        NAA.ClientSynergies = NAA.GetActiveSynergies(
            NAA.ClientUpgrades or {},
            LocalPlayer():GetNWString("NAA_Class", "survivor")
        )
    end)
    f.OnRemove = function() timer.Remove("NAA_DevSynUpdate") end

    NAA_DEV.Open = true
    return f
end

-- ============================================================
--  ОТКРЫТИЕ/ЗАКРЫТИЕ
-- ============================================================
local function ToggleDevPanel()
    if not NAA_DEV.Cheats then
        -- Визуальный намёк
        surface.PlaySound("buttons/button10.wav")
        chat.AddText(Color(255,80,80), "[NAA DEV] Требуется sv_cheats 1")
        return
    end

    if IsValid(DevPanel) then
        DevPanel:Remove()
        DevPanel = nil
        NAA_DEV.Open = false
    else
        DevPanel = NAA_CreateDevPanel()
        surface.PlaySound("buttons/button9.wav")
    end
end

-- ============================================================
--  ПРИВЯЗКА КЛАВИШИ F9
-- ============================================================
hook.Add("KeyPress", "NAA_DevKey", function(ply, key)
    -- ply — локальный игрок на клиенте
    if key == KEY_F9 then
        ToggleDevPanel()
    end
end)

-- ============================================================
--  NET: ПОЛУЧЕНИЕ СТАТУСА СЕРВЕРА
-- ============================================================
net.Receive("NAA_DevStatus", function()
    local data = util.JSONToTable(net.ReadString()) or {}
    NAA_DEV.Cheats  = data.cheats  or false
    NAA_DEV.GodMode = data.godmode or false

    if data.phase   then NAA.Phase        = data.phase   end
    if data.wave    then NAA.CurrentWave  = data.wave    end
    if data.enemies then NAA.AliveEnemies = data.enemies end
end)

-- ============================================================
--  HINT НА ЭКРАНЕ (если есть читы)
-- ============================================================
hook.Add("HUDPaint", "NAA_DevHint", function()
    if not NAA_DEV.Cheats then return end
    if NAA_DEV.Open then return end

    -- Маленький индикатор девмода
    draw.RoundedBox(4, 8, ScrH() - 32, 180, 22, Color(6, 3, 15, 180))
    surface.SetDrawColor(C.accent1); surface.DrawOutlinedRect(8, ScrH()-32, 180, 22)
    draw.SimpleText("⚡ DEV [F9]", "NAA_Dev_Small", 18, ScrH() - 21,
        C.accent1, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- God mode индикатор
    if NAA_DEV.GodMode then
        draw.RoundedBox(4, 196, ScrH() - 32, 120, 22, Color(80, 10, 30, 200))
        surface.SetDrawColor(C.red); surface.DrawOutlinedRect(196, ScrH()-32, 120, 22)
        draw.SimpleText("⚡ GOD MODE", "NAA_Dev_Small", 206, ScrH() - 21, C.red)
    end
end)

-- ============================================================
--  LIGHT STEP: плавное уменьшение отдачи (клиент)
-- ============================================================
hook.Add("Think", "NAA_LightStepClient", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local upgs  = NAA.ClientUpgrades or {}
    local stack = upgs.light_step or 0
    if stack <= 0 then return end

    -- Уменьшаем ViewPunch пропорционально стакам
    local punch = ply:GetViewPunchAngles()
    local factor = 0.85 ^ stack
    if punch:Length() > 0.01 then
        ply:ViewPunch(Angle(
            -punch.p * (1 - factor),
            -punch.y * (1 - factor) * 0.5,
            0
        ))
    end
end)

-- ============================================================
--  ДЕТЕКТИВ: HP-бары над врагами
-- ============================================================
hook.Add("PostDrawOpaqueRenderables", "NAA_DetectiveHPBars", function()
    local ply  = LocalPlayer()
    if not IsValid(ply) then return end

    local upgs = NAA.ClientUpgrades or {}
    if (upgs.detective or 0) <= 0 then return end

    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        if not ent.IsNecoArc and not ent:GetClass():find("neco_") then continue end
        if not ent:IsNPC() then continue end

        local hp    = ent:Health()
        local maxhp = ent:GetMaxHealth()
        if maxhp <= 0 then continue end

        -- Позиция над головой
        local pos    = ent:GetPos() + Vector(0, 0, ent:OBBMaxs().z + 16)
        local screen = pos:ToScreen()
        if not screen.visible then continue end

        local x, y  = screen.x, screen.y
        local barW  = 60
        local barH  = 8
        local prog  = math.Clamp(hp / maxhp, 0, 1)

        -- Фон
        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(x - barW/2 - 1, y - barH/2 - 1, barW + 2, barH + 2)

        -- Полоска HP
        local r = 255 - math.floor(prog * 200)
        local g = math.floor(prog * 220)
        surface.SetDrawColor(r, g, 30, 230)
        surface.DrawRect(x - barW/2, y - barH/2, math.floor(barW * prog), barH)

        -- Текст
        draw.SimpleText(hp .. "/" .. maxhp, "NAA_Dev_Small",
            x, y - barH - 4, Color(255, 255, 255, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end
end)

-- ============================================================
--  КОНСОЛЬНАЯ КОМАНДА ДЛЯ ПРИНУДИТЕЛЬНОГО ОТКРЫТИЯ МЕНЮ
-- ============================================================
concommand.Add("naa_devmenu", function(ply)
    -- Если команда вызвана от игрока на клиенте, ply = nil, поэтому проверяем иначе
    if not GetConVar("sv_cheats"):GetBool() then
        chat.AddText(Color(255,80,80), "[NAA DEV] Требуется sv_cheats 1")
        return
    end
    ToggleDevPanel()
end)

-- Отладочный вывод
local oldToggle = ToggleDevPanel
function ToggleDevPanel()
    print("[NAA DEV] ToggleDevPanel called, cheats=" .. tostring(NAA_DEV.Cheats) .. ", open=" .. tostring(NAA_DEV.Open))
    oldToggle()
end

-- Исправленный хук на F9 (клиентский)
hook.Add("KeyPress", "NAA_DevKey", function(ply, key)
    if key == KEY_F9 then
        ToggleDevPanel()
    end
end)

print("[NAA] cl_devmode.lua загружен — нажмите F9 (нужен sv_cheats 1)")
