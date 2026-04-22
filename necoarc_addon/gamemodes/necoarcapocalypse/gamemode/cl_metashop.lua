-- ============================================================
--  NECO ARC APOCALYPSE — cl_metashop.lua  (CLIENT)
-- ============================================================

local MetaItemsDef = {
    { id="class_medic",     name="Класс:  Медик",               neoCost=50,  desc="HP 140, броня 20. Аура лечения союзников." },
    { id="class_berserker", name="Класс: ️ Берсерк",            neoCost=75,  desc="HP 150, броня 0. Урон растёт с потерей HP." },
    { id="class_hunter",    name="Класс:  Охотник",             neoCost=60,  desc="HP 80, скорость 220. Стаки убийств = урон." },
    { id="bonus_reroll",    name="Стартовый бесплатный реролл",   neoCost=30,  desc="1 бесплатный реролл карт в начале каждого забега." },
    { id="bonus_hp",        name="Стартовый бонус: +25 HP",       neoCost=40,  desc="+25 к максимальному HP в начале забега." },
    { id="bonus_coins",     name="Стартовый бонус: +15 монет",    neoCost=25,  desc="+15 монет в начале каждого забега." },
    { id="bonus_rare",      name="Гарантированная  карта",      neoCost=60,  desc="Первая карта в волне 1 — минимум Необычная." },
    { id="diff_extreme",    name="Разблокировка: ️ Экстрим",     neoCost=50,  desc="Открывает сложность Экстрим." },
    { id="diff_apocalypse", name="Разблокировка:  Апокалипсис", neoCost=200, desc="Открывает сложность Апокалипсис. ×3 Нео-монеты." },
    { id="synergy_panel",   name="Панель синергий",                neoCost=20,  desc="Показывает синергии во время выбора карт." },
}

function NAA_ShowMetaShop()
    local sw, sh = ScrW(), ScrH()
    if IsValid(NAA.ActivePanel) then NAA.ActivePanel:Remove() end

    local f = vgui.Create("DFrame")
    f:SetSize(640, 620) f:Center()
    f:SetTitle("") f:ShowCloseButton(false)
    f:SetDraggable(false) f:MakePopup()
    NAA.ActivePanel = f

    f.Paint = function(s,w,h)
        draw.RoundedBox(0,0,0,w,h,Color(10,6,20,248))
        draw.SimpleText("НЕО-МАГАЗИН", "NAA_Big", w/2, 16, Color(255,220,80), TEXT_ALIGN_CENTER)
        draw.SimpleText("Нео-монет: "..(( NAA.MetaData or {}).neo_coins or 0),
            "NAA_Med", w/2, 55, Color(255,200,80), TEXT_ALIGN_CENTER)
    end

    local scroll = vgui.Create("DScrollPanel", f)
    scroll:SetPos(10, 80) scroll:SetSize(620, 480)
    scroll.VBar.Paint = function(s,w,h) draw.RoundedBox(4,0,0,w,h,Color(20,15,30)) end
    scroll.VBar.btnUp.Paint   = function() end
    scroll.VBar.btnDown.Paint = function() end

    local canvas = scroll:GetCanvas()
    local uy = 4

    for _, item in ipairs(MetaItemsDef) do
        local unlocks = (NAA.MetaData or {}).unlocks or {}
        local owned   = unlocks[item.id]
        local canAfford = ((NAA.MetaData or {}).neo_coins or 0) >= item.neoCost

        local row = vgui.Create("DPanel", canvas)
        row:SetPos(4, uy) row:SetSize(606, 62)
        uy = uy + 68

        row.Paint = function(s,w,h)
            local bg = owned and Color(15,30,15) or Color(16,10,28)
            draw.RoundedBox(8,0,0,w,h,bg)
            -- Left stripe
            local sc = owned and Color(80,200,80) or (canAfford and Color(100,60,200) or Color(50,50,80))
            draw.RoundedBox(4,0,0,5,h,sc)
            -- Name
            draw.SimpleText(item.name, "NAA_Med", 16, 8,
                owned and Color(100,220,100) or Color(220,220,220))
            -- Desc
            draw.SimpleText(item.desc, "NAA_Tiny", 16, 34, Color(140,140,160))
            -- Cost / owned
            if owned then
                draw.SimpleText("Куплено", "NAA_Small", w-12, h/2, Color(80,220,80), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            else
                local col = canAfford and Color(255,220,80) or Color(120,100,40)
                draw.SimpleText(""..item.neoCost, "NAA_Med", w-12, h/2, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        if not owned then
            local btn = vgui.Create("DButton", row)
            btn:SetPos(0,0) btn:SetSize(606, 62)
            btn:SetText("")
            btn.Paint = function() end
            btn.DoClick = function()
                if not canAfford then
                    surface.PlaySound("buttons/button10.wav")
                    return
                end
                surface.PlaySound("buttons/button9.wav")
                net.Start("NAA_BuyMeta") net.WriteString(item.id) net.SendToServer()
                -- Optimistic update
                if NAA.MetaData then
                    NAA.MetaData.neo_coins = (NAA.MetaData.neo_coins or 0) - item.neoCost
                    NAA.MetaData.unlocks   = NAA.MetaData.unlocks or {}
                    NAA.MetaData.unlocks[item.id] = true
                end
                f:Remove()
                NAA_ShowMetaShop()
            end
        end
    end

    canvas:SetTall(uy + 8)

    -- Back button
    local backBtn = vgui.Create("DButton", f)
    backBtn:SetPos(190, 570) backBtn:SetSize(260, 40)
    backBtn:SetText("Назад") backBtn:SetFont("NAA_Med")
    backBtn:SetTextColor(Color(255,255,255))
    backBtn.Paint = function(s,w,h)
        draw.RoundedBox(6,0,0,w,h, s:IsHovered() and Color(50,30,70) or Color(30,18,50))
    end
    backBtn.DoClick = function()
        surface.PlaySound("buttons/button9.wav")
        f:Remove()
        NAA_ShowMenu()
    end
end
