-- ============================================================
--  NECO ARC APOCALYPSE — cl_death.lua  (CLIENT)
--  Исправлено: убрана кнопка "Попробовать снова"
-- ============================================================

function NAA_ShowDeath()
    local sw, sh = ScrW(), ScrH()
    if IsValid(NAA.ActivePanel) then NAA.ActivePanel:Remove() end

    local f = vgui.Create("DFrame")
    f:SetSize(sw, sh) f:SetPos(0,0)
    f:SetTitle("") f:ShowCloseButton(false)
    f:SetDraggable(false) f:MakePopup()
    NAA.ActivePanel = f

    local res = NAA.RunResult or {}
    local wave= res.wave or NAA.ClientWave or 0
    local kills=res.kills or 0
    local diff = res.difficulty or NAA.ClientDifficulty or "normal"
    local neo  = res.neo or 0
    local upgs = res.upgrades or {}
    local syns = res.synergies or {}

    f.Paint = function(s,w,h)
        surface.SetDrawColor(5,0,10,220)
        surface.DrawRect(0,0,w,h)

        -- Title
        draw.SimpleText(" ТЫ ПОГИБ", "NAA_Huge", w/2, h*0.12,
            Color(220,40,40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Stats
        local by = h*0.25
        local stats = {
            { "Волна:",        tostring(wave) },
            { "Убийств:",      tostring(kills) },
            { "Сложность:",    (NAA.Difficulties[diff] or {}).name or diff },
            { "Нео-монет:",    "+" .. neo },
        }
        for _, st in ipairs(stats) do
            draw.SimpleText(st[1], "NAA_Med", w/2-120, by, Color(180,180,180), TEXT_ALIGN_RIGHT)
            draw.SimpleText(st[2], "NAA_Med", w/2+10,  by, Color(255,255,255))
            by = by + 38
        end

        -- Upgrades list
        by = by + 10
        draw.SimpleText("Улучшения этого забега:", "NAA_Med", w/2, by, Color(255,220,80), TEXT_ALIGN_CENTER)
        by = by + 30

        local listed = 0
        for id, cnt in pairs(upgs) do
            if listed >= 12 then break end
            local u = NAA.Upgrades[id]
            if u then
                local col = NAA.RarityConfig[u.rarity].color
                draw.SimpleText(u.icon.." "..u.name.." ×"..cnt, "NAA_Small",
                    w/2, by, col, TEXT_ALIGN_CENTER)
                by = by + 20
                listed = listed + 1
            end
        end

        -- Synergies
        local synCount = 0
        for _ in pairs(syns) do synCount=synCount+1 end
        if synCount > 0 then
            by = by + 8
            local synText = "Синергии: "
            for sid, _ in pairs(syns) do
                for _, syn in ipairs(NAA.Synergies) do
                    if syn.id == sid then synText = synText .. syn.name .. "  " break end
                end
            end
            draw.SimpleText(synText, "NAA_Small", w/2, by, Color(200,100,255), TEXT_ALIGN_CENTER)
        end
    end

    -- Единственная кнопка: Главное меню (по центру)
    local btnW, btnH = 260, 48
    local cx = sw/2 - btnW/2

    local menuBtn = vgui.Create("DButton", f)
    menuBtn:SetPos(cx, sh*0.82) 
    menuBtn:SetSize(btnW, btnH)
    menuBtn:SetText(" Главное меню") 
    menuBtn:SetFont("NAA_Med")
    menuBtn:SetTextColor(Color(255,255,255))
    menuBtn.Paint = function(s,w,h)
        draw.RoundedBox(8,0,0,w,h, s:IsHovered() and Color(40,30,60) or Color(25,18,42))
    end
    menuBtn.DoClick = function()
        surface.PlaySound("buttons/button9.wav")
        net.Start("NAA_ForceReset")
        net.SendToServer()
        if IsValid(f) then f:Remove() end
        NAA_ShowMenu()
    end
end