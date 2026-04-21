-- ============================================================
--  NECO ARC APOCALYPSE — cl_menu.lua  (CLIENT)
-- ============================================================

NAA.ActivePanel = nil

local function MakeFrame(title, w, h)
    if IsValid(NAA.ActivePanel) then NAA.ActivePanel:Remove() end
    local sw, sh = ScrW(), ScrH()
    local f = vgui.Create("DFrame")
    f:SetSize(w, h)
    f:Center()
    f:SetTitle(title)
    f:SetDraggable(false)
    f:ShowCloseButton(false)
    f:MakePopup()
    NAA.ActivePanel = f
    return f
end

-- ============================================================
--  MAIN MENU (Lobby)
-- ============================================================
function NAA_ShowMenu()
    local sw, sh = ScrW(), ScrH()
    if IsValid(NAA.ActivePanel) then NAA.ActivePanel:Remove() end

    local f = vgui.Create("DFrame")
    f:SetSize(sw, sh)
    f:SetPos(0, 0)
    f:SetTitle("")
    f:ShowCloseButton(false)
    f:SetDraggable(false)
    f:MakePopup()
    NAA.ActivePanel = f

    f.Paint = function(s, w, h)
        surface.SetDrawColor(10, 5, 15, 230)
        surface.DrawRect(0, 0, w, h)
        -- Gradient top
        draw.RoundedBox(0, 0, 0, w, h/3, Color(30, 0, 0, 100))
        -- Title
        draw.SimpleText("NECO ARC", "NAA_Huge", w/2, h*0.22,
            Color(220, 40, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("APOCALYPSE", "NAA_Big", w/2, h*0.22+65,
            Color(255, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Нео-монет: " .. tostring((NAA.MetaData or {}).neo_coins or 0),
            "NAA_Med", w/2, h*0.22+110, Color(255,220,80), TEXT_ALIGN_CENTER)
    end

    local btnW, btnH = 320, 52
    local cx = sw/2 - btnW/2
    local by = sh*0.5

    local function MBtn(lbl, y, fn, col)
        local b = vgui.Create("DButton", f)
        b:SetPos(cx, y) b:SetSize(btnW, btnH)
        b:SetText(lbl) b:SetFont("NAA_Med")
        b:SetTextColor(Color(255,255,255))
        b.Paint = function(s, w, h)
            local c = col or Color(60,20,20)
            if s:IsHovered() then c=Color(c.r+30,c.g+30,c.b+30) end
            draw.RoundedBox(8,0,0,w,h,c)
        end
        b.DoClick = fn
        return b
    end

    MBtn(" НАЧАТЬ ЗАБЕГ", by,         function() surface.PlaySound("buttons/button9.wav") net.Start("NAA_StartGame") net.SendToServer() f:Remove() end, Color(140,20,20))
    MBtn(" НЕО-МАГАЗИН",  by+62,     function() NAA_ShowMetaShop() end, Color(60,40,100))
    MBtn(" РЕКОРДЫ",       by+124,    function() NAA_ShowRecords() end, Color(40,60,40))
end

-- ============================================================
--  CLASS SELECTION
-- ============================================================
function NAA_ShowClassSelect()
    local sw, sh = ScrW(), ScrH()
    local f = MakeFrame("Выбор класса", sw*0.88, sh*0.78)
    f.Paint = function(s,w,h)
        draw.RoundedBox(0,0,0,w,h,Color(12,8,18,240))
        draw.SimpleText("ВЫБЕРИ КЛАСС", "NAA_Big", w/2, 20, Color(255,80,80), TEXT_ALIGN_CENTER)
    end

    local classOrder = {"survivor","medic","berserker","hunter"}
    local cardW, cardH = math.floor((sw*0.88 - 80) / 4) - 12, sh*0.78 - 120
    local startX = 30

    for i, cid in ipairs(classOrder) do
        local cls     = NAA.Classes[cid]
        local unlocks = (NAA.MetaData or {}).unlocks or {}
        local locked  = cls.unlockCost > 0 and not unlocks["class_"..cid]
        local cx2     = startX + (i-1)*(cardW+12)

        local card = vgui.Create("DPanel", f)
        card:SetPos(cx2, 60) card:SetSize(cardW, cardH)

        card.Paint = function(s,w,h)
            local bg = locked and Color(30,20,20) or Color(20,15,30)
            if s:IsHovered() and not locked then bg=Color(35,25,50) end
            draw.RoundedBox(10,0,0,w,h,bg)
            -- Color stripe top
            local sc = locked and Color(80,80,80) or cls.color
            draw.RoundedBox(6,4,4,w-8,6,sc)
            -- Class name
            draw.SimpleText(cls.name, "NAA_Med", w/2, 26, locked and Color(100,100,100) or Color(255,255,255), TEXT_ALIGN_CENTER)
            -- Stats
            local sy = 60
            local statColor = locked and Color(80,80,80) or Color(180,180,180)
            draw.SimpleText(" HP: "..cls.hp,         "NAA_Small", 12, sy,    statColor)
            draw.SimpleText(" Броня: "..cls.armor,   "NAA_Small", 12, sy+22, statColor)
            draw.SimpleText(" Скорость: "..cls.speed,"NAA_Small", 12, sy+44, statColor)
            -- Passive
            draw.SimpleText("Пассивка:", "NAA_Tiny", 12, sy+74, Color(255,220,80))
            -- Word-wrapped passive text
            local lines = {}
            local words = string.Explode(" ", cls.passive)
            local line  = ""
            local maxW  = w - 20
            surface.SetFont("NAA_Tiny")
            for _, word in ipairs(words) do
                local test = line == "" and word or (line.." "..word)
                if surface.GetTextSize(test) > maxW then
                    lines[#lines+1] = line line = word
                else line = test end
            end
            if line ~= "" then lines[#lines+1] = line end
            for li, ln in ipairs(lines) do
                draw.SimpleText(ln, "NAA_Tiny", 12, sy+88+(li-1)*15, statColor)
            end
            -- Lock
            if locked then
                draw.SimpleText(""..cls.unlockCost.." Нео", "NAA_Small",
                    w/2, h-40, Color(200,160,80), TEXT_ALIGN_CENTER)
            end
        end

        if not locked then
            local btn = vgui.Create("DButton", card)
            btn:SetPos(8, cardH-44) btn:SetSize(cardW-16, 36)
            btn:SetText("ВЫБРАТЬ") btn:SetFont("NAA_Med")
            btn:SetTextColor(Color(255,255,255))
            btn.Paint = function(s,w,h)
                local c = s:IsHovered() and Color(180,30,30) or Color(140,20,20)
                draw.RoundedBox(6,0,0,w,h,c)
            end
            btn.DoClick = function()
                surface.PlaySound("buttons/button9.wav")
                net.Start("NAA_SelectClass") net.WriteString(cid) net.SendToServer()
                -- Mark locally as selected
                card.selected = true
                btn:SetText(" ВЫБРАНО")
                btn:SetEnabled(false)
            end
        end
    end
end

-- ============================================================
--  DIFFICULTY SELECTION
-- ============================================================
function NAA_ShowDiffSelect()
    local sw, sh = ScrW(), ScrH()
    local f = MakeFrame("Выбор сложности", 600, 560)
    f.Paint = function(s,w,h)
        draw.RoundedBox(0,0,0,w,h,Color(12,8,18,245))
        draw.SimpleText("СЛОЖНОСТЬ", "NAA_Big", w/2, 18, Color(255,80,80), TEXT_ALIGN_CENTER)
    end

    local diffOrder = {"easy","normal","hardcore","extreme","apocalypse"}
    local unlocks   = (NAA.MetaData or {}).unlocks or {}
    local by        = 60

    for _, did in ipairs(diffOrder) do
        local diff   = NAA.Difficulties[did]
        local locked = diff.unlockCost > 0 and not unlocks["diff_"..did]

        local row = vgui.Create("DButton", f)
        row:SetPos(20, by) row:SetSize(560, 74)
        row:SetText("")
        by = by + 82

        row.Paint = function(s, w, h)
            local bg = locked and Color(25,20,25) or Color(18,12,28)
            if s:IsHovered() and not locked then
                bg = Color(bg.r+20, bg.g+20, bg.b+20)
            end
            draw.RoundedBox(8, 0, 0, w, h, bg)
            -- Left stripe
            local sc = locked and Color(70,70,70) or diff.color
            draw.RoundedBox(4, 0, 0, 6, h, sc)
            -- Name
            draw.SimpleText(diff.name, "NAA_Med", 22, 10,
                locked and Color(80,80,80) or Color(255,255,255))
            -- Stats short
            local info = string.format("HP×%.1f  Врагов×%.1f  Жизни: %s  Нео-монеты: ×%.1f",
                diff.hpMult, diff.countMult,
                diff.lives>=999 and "∞" or tostring(diff.lives),
                diff.neoMult)
            draw.SimpleText(info, "NAA_Tiny", 22, 36, Color(160,160,160))
            if locked then
                draw.SimpleText("Требует "..diff.unlockCost.." Нео-монет", "NAA_Tiny",
                    w-12, h/2, Color(200,160,80), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        if not locked then
            row.DoClick = function()
                surface.PlaySound("buttons/button9.wav")
                net.Start("NAA_SelectDifficulty") net.WriteString(did) net.SendToServer()
                if IsValid(NAA.ActivePanel) then NAA.ActivePanel:Remove() NAA.ActivePanel=nil end
            end
        end
    end
end

-- ============================================================
--  RECORDS
-- ============================================================
function NAA_ShowRecords()
    local f = MakeFrame("Рекорды", 400, 340)
    f.Paint = function(s,w,h)
        draw.RoundedBox(0,0,0,w,h,Color(12,8,18,245))
    end

    local rec  = (NAA.MetaData or {}).records or {}
    local meta = NAA.MetaData or {}
    local info = {
        "  Лучшая волна:   " .. (rec.best_wave or 0),
        " Сложность:      " .. (rec.best_diff or "—"),
        "  Макс убийств:   " .. (rec.best_kills or 0),
        "  Всего забегов:  " .. (meta.total_runs or 0),
        " Всего убийств:  " .. (meta.total_kills or 0),
        " Нео-монет:      " .. (meta.neo_coins or 0),
    }
    for i, line in ipairs(info) do
        local lbl = vgui.Create("DLabel", f)
        lbl:SetPos(30, 50 + (i-1)*38) lbl:SetSize(340, 30)
        lbl:SetText(line) lbl:SetFont("NAA_Med")
        lbl:SetTextColor(Color(200,200,200))
    end

    local closeBtn = vgui.Create("DButton", f)
    closeBtn:SetPos(100, 290) closeBtn:SetSize(200, 36)
    closeBtn:SetText("Закрыть") closeBtn:SetFont("NAA_Med")
    closeBtn:SetTextColor(Color(255,255,255))
    closeBtn.Paint = function(s,w,h)
        draw.RoundedBox(6,0,0,w,h, s:IsHovered() and Color(80,30,30) or Color(50,20,20))
    end
    closeBtn.DoClick = function() f:Remove() NAA_ShowMenu() end
end
