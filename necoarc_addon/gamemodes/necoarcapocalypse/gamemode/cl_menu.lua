-- ============================================================
--  NECO ARC APOCALYPSE — cl_menu.lua  (CLIENT)
--  Мультиплеер: лобби с готовностью, голосование, смена класса,
--  таблица НПС, переработанный дизайн
-- ============================================================

NAA.ActivePanel = nil

-- ============================================================
--  УТИЛИТЫ РИСОВАНИЯ
-- ============================================================
local function FBox(x,y,w,h,r,c) draw.RoundedBox(r,x,y,w,h,c) end
local function FTxt(s,f,x,y,c,ax,ay)
    draw.SimpleText(s,f,x,y,c,ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP)
end
local function WrapText(text, font, maxW)
    surface.SetFont(font)
    local words = string.Explode(" ", text)
    local lines, line = {}, ""
    for _, w in ipairs(words) do
        local test = line == "" and w or (line.." "..w)
        if surface.GetTextSize(test) > maxW then
            if line ~= "" then lines[#lines+1] = line end
            line = w
        else line = test end
    end
    if line ~= "" then lines[#lines+1] = line end
    return lines
end

local ACCENT   = Color(180,30,30)
local DARK_BG  = Color(8,4,14,252)
local PANEL_BG = Color(18,12,26,240)
local CARD_BG  = Color(24,16,36,240)

local function MakeBaseFrame(w, h)
    if IsValid(NAA.ActivePanel) then NAA.ActivePanel:Remove() end
    local sw, sh = ScrW(), ScrH()
    local f = vgui.Create("DFrame")
    f:SetSize(w, h) f:Center()
    f:SetTitle("") f:ShowCloseButton(false)
    f:SetDraggable(false) f:MakePopup()
    f:SetDeleteOnClose(true)
    NAA.ActivePanel = f
    f.Paint = function(s,pw,ph)
        FBox(0,0,pw,ph,0,DARK_BG)
    end
    return f
end

local function MakeBtn(parent, lbl, x, y, w, h, col, fn)
    local b = vgui.Create("DButton", parent)
    b:SetPos(x,y) b:SetSize(w,h)
    b:SetText(lbl) b:SetFont("NAA_Med")
    b:SetTextColor(Color(255,255,255))
    b.Paint = function(s,bw,bh)
        local c = col or ACCENT
        if s:IsHovered() then c=Color(c.r+28,c.g+28,c.b+28) end
        if s:IsDown() then c=Color(c.r-20,c.g-20,c.b-20) end
        FBox(0,0,bw,bh,7,c)
    end
    b.DoClick = fn or function() end
    return b
end

-- ============================================================
--  ГЛАВНОЕ МЕНЮ (Лобби)
-- ============================================================
function NAA_ShowMenu()
    local sw, sh = ScrW(), ScrH()
    if IsValid(NAA.ActivePanel) then NAA.ActivePanel:Remove() end

    local f = vgui.Create("DFrame")
    f:SetSize(sw,sh) f:SetPos(0,0)
    f:SetTitle("") f:ShowCloseButton(false)
    f:SetDraggable(false) f:MakePopup()
    NAA.ActivePanel = f

    f.Paint = function(s,w,h)
        FBox(0,0,w,h,0,Color(6,3,12,245))
        -- Верхний градиент
        FBox(0,0,w,h/3,0,Color(25,0,0,110))
        -- Заголовок
        FTxt("NECO ARC",    "NAA_Huge", w/2, h*0.18,   Color(220,40,40),   TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        FTxt("APOCALYPSE",  "NAA_Big",  w/2, h*0.18+65, Color(255,200,200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        FTxt("Нео-монет: "..tostring((NAA.MetaData or {}).neo_coins or 0),
            "NAA_Med", w/2, h*0.18+110, Color(255,215,80), TEXT_ALIGN_CENTER)
    end

    local btnW, btnH = 340, 54
    local cx = sw/2 - btnW/2

    MakeBtn(f, "НАЧАТЬ ИГРУ",   cx, sh*0.50,       btnW, btnH, Color(140,20,20),
        function()
            surface.PlaySound("buttons/button9.wav")
            net.Start("NAA_StartGame") net.SendToServer()
            f:Remove()
        end)
    MakeBtn(f, "НЕО-МАГАЗИН",  cx, sh*0.50+64,    btnW, btnH, Color(50,30,90),
        function() NAA_ShowMetaShop() end)
    MakeBtn(f, "СТАТИСТИКА НПС", cx, sh*0.50+128,  btnW, btnH, Color(30,60,40),
        function() NAA_ShowNPCStats() end)
    MakeBtn(f, "РЕКОРДЫ",       cx, sh*0.50+192,   btnW, btnH, Color(40,40,60),
        function() NAA_ShowRecords() end)
end

-- ============================================================
--  ЛОББИ (ожидание игроков / готовность)
-- ============================================================
NAA.LobbyData = {}  -- заполняется net-приёмниками

function NAA_ShowLobby()
    local sw, sh = ScrW(), ScrH()
    if IsValid(NAA.ActivePanel) then NAA.ActivePanel:Remove() end

    local f = vgui.Create("DFrame")
    f:SetSize(sw,sh) f:SetPos(0,0)
    f:SetTitle("") f:ShowCloseButton(false)
    f:SetDraggable(false) f:MakePopup()
    NAA.ActivePanel = f
    NAA.LobbyPanel  = f

    -- Статус готовности локального игрока
    local localReady = false

    local function RefreshList()
        -- очищаем старые label-ы игроков
    end

    f.Paint = function(s,w,h)
        FBox(0,0,w,h,0,Color(6,3,12,245))
        FBox(0,0,w,h/4,0,Color(25,0,0,90))

        FTxt("ЛОББИ", "NAA_Big",   w/2, 28, Color(255,80,80),   TEXT_ALIGN_CENTER)
        FTxt("Ожидаем готовности всех игроков", "NAA_Small", w/2, 76,
            Color(160,160,160), TEXT_ALIGN_CENTER)

        -- Список игроков
        local lobbyPls = NAA.LobbyData or {}
        local listX = w/2 - 300
        local listY = 120
        FBox(listX-10, listY-10, 620, math.max(#lobbyPls,1)*48+20, 8, Color(0,0,0,130))

        FTxt("Игрок",    "NAA_Small", listX,     listY-2, Color(140,140,140))
        FTxt("Статус",   "NAA_Small", listX+480, listY-2, Color(140,140,140), TEXT_ALIGN_RIGHT)

        for i, pd in ipairs(lobbyPls) do
            local ry = listY + 20 + (i-1)*48
            local rc = pd.ready and Color(70,210,80) or Color(200,200,100)
            local rs = pd.ready and "ГОТОВ" or "Ожидание..."
            FTxt(pd.nick or "?",  "NAA_Med",   listX,     ry, Color(230,230,230))
            FTxt(rs,              "NAA_Med",   listX+480, ry, rc, TEXT_ALIGN_RIGHT)
            surface.SetDrawColor(40,40,40,120)
            surface.DrawRect(listX-4, ry+38, 612, 1)
        end
    end

    -- Кнопка ГОТОВ / НЕ ГОТОВ
    local readyBtn = MakeBtn(f, "ГОТОВ", sw/2-170, sh-100, 340, 54,
        Color(40,120,40), function() end)
    readyBtn.DoClick = function()
        localReady = not localReady
        surface.PlaySound("buttons/button9.wav")
        net.Start("NAA_Ready")
            net.WriteBool(localReady)
        net.SendToServer()
        if localReady then
            readyBtn:SetText("НЕ ГОТОВ")
            readyBtn.Paint = function(s,w,h)
                FBox(0,0,w,h,7, s:IsHovered() and Color(130,40,40) or Color(100,30,30))
            end
        else
            readyBtn:SetText("ГОТОВ")
            readyBtn.Paint = function(s,w,h)
                FBox(0,0,w,h,7, s:IsHovered() and Color(60,160,60) or Color(40,120,40))
            end
        end
    end
end

-- ============================================================
--  ВЫБОР КЛАССА (с возможностью перевыбора до подтверждения)
-- ============================================================
NAA.ClassStateData = {}  -- {[sid]={nick,class,confirmed}}

function NAA_ShowClassSelect()
    local sw, sh = ScrW(), ScrH()
    if IsValid(NAA.ActivePanel) then NAA.ActivePanel:Remove() end

    local f = vgui.Create("DFrame")
    f:SetSize(sw, sh) f:SetPos(0,0)
    f:SetTitle("") f:ShowCloseButton(false)
    f:SetDraggable(false) f:MakePopup()
    NAA.ActivePanel = f
    NAA.ClassPanel  = f

    local selectedClass = nil
    local confirmed     = false

    local classOrder = { "survivor","medic","berserker","hunter" }
    local numCards   = #classOrder
    local cPad = 30
    local cardW = math.floor((sw - cPad*2 - (numCards-1)*18) / numCards)
    local cardH = sh - 260

    f.Paint = function(s,w,h)
        FBox(0,0,w,h,0,DARK_BG)
        FBox(0,0,w,40,0,Color(20,0,0,120))
        FTxt("ВЫБЕРИ КЛАСС", "NAA_Big", w/2, 10, Color(255,80,80), TEXT_ALIGN_CENTER)
        if confirmed then
            FTxt("Ждём остальных игроков...", "NAA_Small",
                w/2, h-110, Color(160,160,160), TEXT_ALIGN_CENTER)
        end

        -- Список других игроков и их выборов
        local stateList = NAA.ClassStateData or {}
        local sx = w/2 - (#stateList * 90)/2
        for i, pd in ipairs(stateList) do
            local cx2 = sx + (i-1)*90
            local cc  = pd.confirmed and Color(70,210,80) or Color(200,200,80)
            local cn  = NAA.Classes[pd.class or "survivor"]
            local clc = cn and cn.color or Color(180,180,180)
            FTxt(pd.nick or "?",             "NAA_AllySmall", cx2, h-76, Color(200,200,200), TEXT_ALIGN_CENTER)
            FTxt(cn and cn.name or "...",    "NAA_AllySmall", cx2, h-62, clc,                TEXT_ALIGN_CENTER)
            FTxt(pd.confirmed and "OK" or "...", "NAA_AllySmall", cx2, h-48, cc,             TEXT_ALIGN_CENTER)
        end
    end

    -- Карточки классов
    for i, cid in ipairs(classOrder) do
        local cls     = NAA.Classes[cid]
        local unlocks = (NAA.MetaData or {}).unlocks or {}
        local locked  = cls.unlockCost > 0 and not unlocks["class_"..cid]
        local cx2     = cPad + (i-1)*(cardW+18)

        local card = vgui.Create("DPanel", f)
        card:SetPos(cx2, 52) card:SetSize(cardW, cardH)

        local isSelected = false

        card.Paint = function(s,w,h)
            local bg  = locked and Color(24,16,24) or (isSelected and Color(32,22,50) or CARD_BG)
            if s:IsHovered() and not locked and not confirmed then
                bg = Color(bg.r+12,bg.g+12,bg.b+12)
            end
            FBox(0,0,w,h,10,bg)
            local sc = locked and Color(70,70,70) or cls.color
            -- Цветная полоска сверху
            FBox(0,0,w,6,4,sc)
            -- Рамка если выбран
            if isSelected then
                surface.SetDrawColor(sc.r,sc.g,sc.b,180)
                surface.DrawOutlinedRect(1,1,w-2,h-2,2)
            end

            local tc = locked and Color(90,90,90) or Color(255,255,255)
            FTxt(cls.name, "NAA_Med", w/2, 18, tc, TEXT_ALIGN_CENTER)

            -- Полоски характеристик
            local sy = 52
            local statC = locked and Color(70,70,70) or Color(170,170,170)

            -- HP
            FTxt("HP", "NAA_Tiny", 14, sy, statC)
            local hpMax = 200; local hpFr = cls.hp / hpMax
            FBox(60, sy+1, w-74, 11, 3, Color(25,25,25,200))
            if not locked then FBox(60, sy+1, math.floor((w-74)*hpFr), 11, 3, Color(70,200,70,200)) end
            FTxt(tostring(cls.hp), "NAA_Tiny", w-10, sy, statC, TEXT_ALIGN_RIGHT)

            -- Броня
            FTxt("Броня", "NAA_Tiny", 14, sy+20, statC)
            local arFr = cls.armor / 100
            FBox(60, sy+21, w-74, 11, 3, Color(25,25,25,200))
            if not locked then FBox(60, sy+21, math.floor((w-74)*arFr), 11, 3, Color(70,110,220,200)) end
            FTxt(tostring(cls.armor), "NAA_Tiny", w-10, sy+20, statC, TEXT_ALIGN_RIGHT)

            -- Скорость
            FTxt("Скорость", "NAA_Tiny", 14, sy+40, statC)
            local spFr = cls.speed / 300
            FBox(60, sy+41, w-74, 11, 3, Color(25,25,25,200))
            if not locked then FBox(60, sy+41, math.floor((w-74)*spFr), 11, 3, Color(100,180,255,200)) end
            FTxt(tostring(cls.speed), "NAA_Tiny", w-10, sy+40, statC, TEXT_ALIGN_RIGHT)

            -- Описание пассивки
            FTxt("Пассивка:", "NAA_Tiny", 14, sy+68, locked and Color(70,70,70) or Color(255,215,80))
            local wlines = WrapText(cls.passive, "NAA_Tiny", w-22)
            for li, ln in ipairs(wlines) do
                FTxt(ln, "NAA_Tiny", 14, sy+82+(li-1)*14, statC)
            end

            -- Описание класса
            local dlines = WrapText(cls.desc, "NAA_Tiny", w-22)
            for li, ln in ipairs(dlines) do
                FTxt(ln, "NAA_Tiny", 14, sy+82+#wlines*14+8+(li-1)*14, Color(130,130,130))
            end

            if locked then
                FTxt("Стоимость: "..cls.unlockCost.." Нео", "NAA_Small",
                    w/2, h-50, Color(200,160,80), TEXT_ALIGN_CENTER)
            end
        end

        if not locked then
            -- Кнопка выбрать / смена
            local selBtn = vgui.Create("DButton", card)
            selBtn:SetPos(8, cardH-46) selBtn:SetSize(cardW-16, 38)
            selBtn:SetText("ВЫБРАТЬ") selBtn:SetFont("NAA_Small")
            selBtn:SetTextColor(Color(255,255,255))
            selBtn.Paint = function(s,w,h)
                if isSelected then
                    FBox(0,0,w,h,6, s:IsHovered() and Color(60,130,60) or Color(40,100,40))
                else
                    FBox(0,0,w,h,6, s:IsHovered() and Color(170,30,30) or ACCENT)
                end
            end
            selBtn.DoClick = function()
                if confirmed then return end
                surface.PlaySound("buttons/button9.wav")
                -- Убираем выделение у остальных
                selectedClass = cid
                isSelected = true
                -- Сообщаем серверу о выборе (не подтверждение — сервер запомнит, но не стартует)
                net.Start("NAA_SelectClass") net.WriteString(cid) net.SendToServer()
                selBtn:SetText("ВЫБРАНО")
            end
            card._selBtn = selBtn
            card._cid    = cid
            -- Обновление кнопок при выборе
            card.Think = function(s)
                if selectedClass and selectedClass ~= cid and isSelected then
                    isSelected = false
                    selBtn:SetText("ВЫБРАТЬ")
                end
                if selectedClass == cid and not isSelected then
                    isSelected = true
                    selBtn:SetText("ВЫБРАНО")
                end
            end
        end
    end

    -- Кнопка ПОДТВЕРДИТЬ
    local confirmBtn = MakeBtn(f, "ПОДТВЕРДИТЬ", sw/2-200, sh-78, 400, 48,
        Color(40,100,40), function()
            if not selectedClass then
                -- Если ничего не выбрано — берём survivor
                selectedClass = "survivor"
                net.Start("NAA_SelectClass") net.WriteString("survivor") net.SendToServer()
            end
            if confirmed then return end
            confirmed = true
            surface.PlaySound("buttons/button9.wav")
            net.Start("NAA_ConfirmClass") net.SendToServer()
        end)
    confirmBtn.Paint = function(s,w,h)
        if confirmed then
            FBox(0,0,w,h,7,Color(30,70,30))
        else
            FBox(0,0,w,h,7, s:IsHovered() and Color(60,140,60) or Color(40,100,40))
        end
    end
end

-- ============================================================
--  ГОЛОСОВАНИЕ ЗА СЛОЖНОСТЬ
-- ============================================================
NAA.DiffVoteData = { votes={}, players={}, countdown=0 }

function NAA_ShowDiffSelect()
    local sw, sh = ScrW(), ScrH()
    if IsValid(NAA.ActivePanel) then NAA.ActivePanel:Remove() end

    local f = vgui.Create("DFrame")
    f:SetSize(sw, sh) f:SetPos(0,0)
    f:SetTitle("") f:ShowCloseButton(false)
    f:SetDraggable(false) f:MakePopup()
    NAA.ActivePanel  = f
    NAA.DiffPanel    = f

    local myVote     = nil
    local diffOrder  = { "easy","normal","hardcore","extreme","apocalypse" }
    local unlocks    = (NAA.MetaData or {}).unlocks or {}

    local rowH = 74
    local listW = 620
    local listX = sw/2 - listW/2
    local listY = 110

    f.Paint = function(s,w,h)
        FBox(0,0,w,h,0,DARK_BG)
        FBox(0,0,w,45,0,Color(20,0,0,120))
        FTxt("ГОЛОСОВАНИЕ ЗА СЛОЖНОСТЬ", "NAA_Big", w/2, 8, Color(255,80,80), TEXT_ALIGN_CENTER)
        FTxt("Победит сложность с наибольшим числом голосов", "NAA_Small",
            w/2, 54, Color(150,150,150), TEXT_ALIGN_CENTER)

        -- Таймер
        local vd = NAA.DiffVoteData or {}
        if (vd.countdown or 0) > 0 then
            FTxt("Голосование закончится через: "..(vd.countdown).."с", "NAA_Small",
                w/2, h - 48, Color(200,200,100), TEXT_ALIGN_CENTER)
        end

        -- Кто как проголосовал
        local playerList = vd.players or {}
        if #playerList > 0 then
            local ply_sx = w/2 - (#playerList*80)/2
            for i, pd in ipairs(playerList) do
                local px = ply_sx + (i-1)*80
                local vc = pd.voted and Color(70,210,80) or Color(160,160,160)
                FTxt(pd.nick or "?",            "NAA_AllySmall", px, h-90, Color(200,200,200), TEXT_ALIGN_CENTER)
                FTxt(pd.voted and "Голос дан" or "...", "NAA_AllySmall", px, h-76, vc, TEXT_ALIGN_CENTER)
            end
        end
    end

    -- Кнопки сложностей
    local voteButtons = {}
    for idx, did in ipairs(diffOrder) do
        local diff   = NAA.Difficulties[did]
        local locked = diff.unlockCost > 0 and not unlocks["diff_"..did]
        local ry     = listY + (idx-1)*(rowH + 10)

        local row = vgui.Create("DButton", f)
        row:SetPos(listX, ry) row:SetSize(listW, rowH) row:SetText("")
        voteButtons[did] = row

        row.Paint = function(s,w,h)
            local vd     = NAA.DiffVoteData or {}
            local votes  = (vd.votes or {})[did] or 0
            local isMyV  = (myVote == did)
            local bg = locked and Color(20,16,22) or Color(18,12,28)
            if s:IsHovered() and not locked then bg=Color(bg.r+15,bg.g+15,bg.b+15) end
            if isMyV then bg=Color(22,40,22) end
            FBox(0,0,w,h,8,bg)
            -- Левая полоска
            local sc = locked and Color(60,60,60) or diff.color
            FBox(0,0,6,h,4,sc)
            -- Рамка если выбрана
            if isMyV then
                surface.SetDrawColor(sc.r,sc.g,sc.b,160)
                surface.DrawOutlinedRect(0,0,w,h,2)
            end
            local tc = locked and Color(80,80,80) or Color(240,240,240)
            FTxt(diff.name, "NAA_Med", 22, 10, tc)
            local info = string.format("HP x%.1f   Врагов x%.1f   Жизни: %s   Нео x%.1f",
                diff.hpMult, diff.countMult,
                diff.lives>=999 and "inf" or tostring(diff.lives),
                diff.neoMult)
            FTxt(info, "NAA_Tiny", 22, 36, Color(150,150,150))
            if locked then
                FTxt("Требует "..diff.unlockCost.." Нео", "NAA_Tiny",
                    w-12, h/2, Color(200,160,80), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            else
                -- Голоса (полоска)
                local totalVotes = 0
                for _, n in pairs((vd.votes or {})) do totalVotes = totalVotes + n end
                if totalVotes > 0 and votes > 0 then
                    local vFrac = votes / totalVotes
                    FBox(w-100, h/2-6, 90, 12, 3, Color(30,30,30,200))
                    FBox(w-100, h/2-6, math.floor(90*vFrac), 12, 3, Color(sc.r,sc.g,sc.b,200))
                end
                FTxt(tostring(votes).." гол.", "NAA_Tiny",
                    w-12, 10, votes>0 and Color(200,255,120) or Color(100,100,100), TEXT_ALIGN_RIGHT)
            end
        end

        if not locked then
            row.DoClick = function()
                surface.PlaySound("buttons/button9.wav")
                myVote = did
                net.Start("NAA_VoteDiff") net.WriteString(did) net.SendToServer()
            end
        end
    end
end

-- ============================================================
--  СТАТИСТИКА НПС
-- ============================================================
function NAA_ShowNPCStats()
    local sw, sh = ScrW(), ScrH()
    local f = MakeBaseFrame(math.min(sw*0.97, 1200), math.min(sh*0.94, 820))

    local catTabs = { "all","regular","special","miniboss","boss" }
    local catNames= { all="Все", regular="Обычные", special="Спец.", miniboss="Мини-боссы", boss="Боссы" }
    local activeTab = "all"

    local catColors = {
        all      = Color(180,180,180),
        regular  = Color(200,200,200),
        special  = Color(255,220,40),
        miniboss = Color(180,80,255),
        boss     = Color(255,60,60),
    }

    local fw, fh = f:GetSize()
    local tabH   = 40
    local tabY   = 52

    f.Paint = function(s,w,h)
        FBox(0,0,w,h,0,DARK_BG)
        FBox(0,0,w,50,0,Color(20,0,0,120))
        FTxt("БЕСТИАРИЙ — СТАТИСТИКА НПС", "NAA_Med", w/2, 14, Color(255,80,80), TEXT_ALIGN_CENTER)
    end

    -- Кнопка закрыть
    local closeBtn = MakeBtn(f, "Назад", fw-130, 8, 120, 34, Color(50,20,20),
    function() 
        f:Remove() 
        NAA.ActivePanel = nil 
        NAA_ShowMenu()   -- возврат в главное меню
    end)

    -- Вкладки
    local tabBtns = {}
    local tabW    = (fw - 20) / #catTabs
    for i, cat in ipairs(catTabs) do
        local tb = vgui.Create("DButton", f)
        tb:SetPos(10 + (i-1)*tabW, tabY)
        tb:SetSize(tabW - 4, tabH)
        tb:SetText(catNames[cat]) tb:SetFont("NAA_Small")
        tb:SetTextColor(Color(255,255,255))
        tb.Paint = function(s,w,h)
            local isAct = (activeTab == cat)
            local cc    = catColors[cat]
            local bg    = isAct and Color(cc.r/4, cc.g/4, cc.b/4+8, 220) or Color(14,10,20,200)
            if s:IsHovered() and not isAct then bg=Color(24,18,34,220) end
            FBox(0,0,w,h,5,bg)
            if isAct then
                surface.SetDrawColor(cc.r,cc.g,cc.b,200)
                surface.DrawRect(0, h-3, w, 3)
            end
        end
        tabBtns[cat] = tb
    end

    -- Скролл-панель с карточками
    local scrollPanel = vgui.Create("DScrollPanel", f)
    scrollPanel:SetPos(10, tabY + tabH + 6)
    scrollPanel:SetSize(fw - 20, fh - tabY - tabH - 56)

    local listInner = vgui.Create("DPanel", scrollPanel)
    listInner:SetSize(fw - 36, 2000)
    listInner:Dock(TOP)
    listInner.Paint = function() end

    -- Заголовок таблицы
    local hdrPanel = vgui.Create("DPanel", listInner)
    hdrPanel:SetSize(fw - 36, 28) hdrPanel:DockPadding(0,0,0,0)
    hdrPanel.Paint = function(s,w,h)
        FBox(0,0,w,h,0,Color(0,0,0,140))
        local cols = { {txt="НПС",        x=56,  ax=TEXT_ALIGN_LEFT},
                       {txt="HP",         x=250, ax=TEXT_ALIGN_CENTER},
                       {txt="Скорость",   x=320, ax=TEXT_ALIGN_CENTER},
                       {txt="Размер",     x=400, ax=TEXT_ALIGN_CENTER},
                       {txt="Появл. с волны", x=480, ax=TEXT_ALIGN_CENTER} }
        for _, c in ipairs(cols) do
            FTxt(c.txt, "NAA_Tiny", c.x, 7, Color(140,140,140), c.ax)
        end
    end
    hdrPanel:Dock(TOP)

    local cards    = {}
    local cardPanels = {}

    local function BuildList()
        for _, cp in ipairs(cardPanels) do
            if IsValid(cp) then cp:Remove() end
        end
        cardPanels = {}

        local list = {}
        for _, npc in ipairs(NAA.NPCInfo or {}) do
            if activeTab == "all" or npc.cat == activeTab then
                list[#list+1] = npc
            end
        end

        listInner:SetSize(fw-36, #list * 84 + 34)

        for _, npc in ipairs(list) do
            local row = vgui.Create("DPanel", listInner)
            row:SetSize(fw-36, 82) row:Dock(TOP)
            row:DockMargin(0, 2, 0, 0)
            cardPanels[#cardPanels+1] = row

            local nc = npc.color or Color(180,180,180)
            local catLabel = {
                regular="обычный", special="спец.", miniboss="мини-босс", boss="БОСС"
            }

            row.Paint = function(s,w,h)
                FBox(0,0,w,h,6,Color(16,10,24,220))
                -- Цветная полоска слева
                surface.SetDrawColor(nc.r,nc.g,nc.b,200)
                surface.DrawRect(0,0,4,h)

                -- Маркер типа
                local catStr = catLabel[npc.cat] or ""
                local catC   = catColors[npc.cat] or Color(180,180,180)
                FTxt(catStr, "NAA_Tiny", 8, 4, catC)

                -- Имя
                FTxt(npc.name, "NAA_Med", 8, 18, Color(nc.r,nc.g,nc.b))

                -- Характеристики
                local hpTxt    = tostring(npc.hp).." HP"
                local spdTxt   = tostring(npc.speed)
                local scaleTxt = string.format("x%.1f", npc.scale)
                local waveTxt  = "~"..tostring(npc.wave)

                FTxt(hpTxt,    "NAA_Small", 250, 26, Color(80,220,80),  TEXT_ALIGN_CENTER)
                FTxt(spdTxt,   "NAA_Small", 320, 26, Color(100,180,255),TEXT_ALIGN_CENTER)
                FTxt(scaleTxt, "NAA_Small", 400, 26, Color(220,180,80), TEXT_ALIGN_CENTER)
                FTxt(waveTxt,  "NAA_Small", 480, 26, Color(180,180,180),TEXT_ALIGN_CENTER)

                -- HP bar мини
                local hpMax = npc.cat=="boss" and 5000 or (npc.cat=="miniboss" and 600 or 100)
                local hpFr  = math.Clamp(npc.hp/hpMax,0,1)
                FBox(240, 44, 280, 8, 3, Color(30,30,30,200))
                FBox(240, 44, math.floor(280*hpFr), 8, 3, Color(nc.r,nc.g,nc.b,180))

                -- Описание
                local descLines = WrapText(npc.desc, "NAA_Tiny", w - 26)
                for li, ln in ipairs(descLines) do
                    if li > 3 then break end
                    FTxt(ln, "NAA_Tiny", 8, 54+(li-1)*13, Color(150,150,150))
                end

                -- Разделитель снизу
                surface.SetDrawColor(40,30,55,160)
                surface.DrawRect(0, h-1, w, 1)
            end
        end
    end

    BuildList()

    for _, cat in ipairs(catTabs) do
        tabBtns[cat].DoClick = function()
            activeTab = cat
            surface.PlaySound("buttons/button9.wav")
            BuildList()
        end
    end
end

-- ============================================================
--  РЕКОРДЫ
-- ============================================================
function NAA_ShowRecords()
    local sw, sh = ScrW(), ScrH()
    local f = MakeBaseFrame(500, 420)

    f.Paint = function(s,w,h)
        FBox(0,0,w,h,0,DARK_BG)
        FBox(0,0,w,44,0,Color(20,0,0,100))
        FTxt("РЕКОРДЫ", "NAA_Big", w/2, 8, Color(255,80,80), TEXT_ALIGN_CENTER)
    end

    local rec  = (NAA.MetaData or {}).records or {}
    local meta = NAA.MetaData or {}

    local rows = {
        { label="Лучшая волна",    val=tostring(rec.best_wave or 0),         col=Color(255,220,40) },
        { label="Сложность",       val=tostring(rec.best_diff or "—"),        col=Color(200,140,80) },
        { label="Макс. убийств",   val=tostring(rec.best_kills or 0),         col=Color(255,100,100) },
        { label="Всего забегов",   val=tostring(meta.total_runs or 0),        col=Color(180,180,180) },
        { label="Всего убийств",   val=tostring(meta.total_kills or 0),       col=Color(180,180,180) },
        { label="Нео-монет всего", val=tostring(meta.neo_coins or 0),         col=Color(255,215,50) },
    }

    local fw, _ = f:GetSize()
    for i, row in ipairs(rows) do
        local lbl = vgui.Create("DPanel", f)
        lbl:SetPos(30, 56 + (i-1)*48) lbl:SetSize(fw-60, 42)
        local ry = i
        lbl.Paint = function(s,w,h)
            FBox(0,0,w,h,5,Color(0,0,0,110))
            FTxt(rows[ry].label, "NAA_Small", 14,  h/2, Color(160,160,160), TEXT_ALIGN_LEFT,  TEXT_ALIGN_CENTER)
            FTxt(rows[ry].val,   "NAA_Med",   w-14, h/2, rows[ry].col,      TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    MakeBtn(f, "Назад", fw/2-120, 370, 240, 38, Color(50,20,20),
        function() f:Remove() NAA_ShowMenu() end)
end
