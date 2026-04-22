-- ============================================================
--  NECO ARC APOCALYPSE — cl_upgrades.lua  (CLIENT)
-- ============================================================

NAA.UpgradePanel = nil
local CARD_W, CARD_H = 280, 380
local PANEL_W        = CARD_W*4 + 80 + 380

-- ============================================================
--  NET RECEIVE: cards offered
-- ============================================================
net.Receive("NAA_ShowUpgrades", function()
    local c1    = net.ReadString()
    local c2    = net.ReadString()
    local c3    = net.ReadString()
    local c4    = net.ReadString()
    local coins = net.ReadInt(16)
    NAA.ClientCoins = coins

    local cards = {}
    for _, c in ipairs({c1,c2,c3,c4}) do
        if c and c ~= "" then cards[#cards+1] = c end
    end

    NAA_ShowUpgradeScreen(cards, coins)
end)

-- ============================================================
--  WORD WRAP HELPER
-- ============================================================
local function WrapText(text, font, maxWidth)
    local words = string.Explode(" ", text)
    local lines = {}
    local line = ""
    
    surface.SetFont(font)
    for _, word in ipairs(words) do
        local test = line == "" and word or line .. " " .. word
        local w = surface.GetTextSize(test)
        if w > maxWidth then
            if line ~= "" then
                lines[#lines + 1] = line
            end
            line = word
        else
            line = test
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

-- ============================================================
--  UPGRADE SCREEN
-- ============================================================
function NAA_ShowUpgradeScreen(cards, coins)
    if IsValid(NAA.UpgradePanel) then NAA.UpgradePanel:Remove() end

    local sw, sh = ScrW(), ScrH()
    local hasSynergyPanel = (NAA.MetaData and NAA.MetaData.unlocks and NAA.MetaData.unlocks.synergy_panel) or true

    local numCards = #cards
    local totalW = numCards * (CARD_W + 20) + (hasSynergyPanel and 360 or 0) + 60
    local totalH = CARD_H + 180

    local f = vgui.Create("DFrame")
    f:SetSize(totalW, totalH)
    f:Center()
    f:SetTitle("")
    f:ShowCloseButton(false)
    f:SetDraggable(false)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    NAA.UpgradePanel = f

    local startTime = CurTime()
    local duration  = 20

    f.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(8, 4, 14, 250))
        
        draw.SimpleText("ВЫБЕРИ УЛУЧШЕНИЕ", "NAA_Big", w/2, 20, Color(255, 220, 80), TEXT_ALIGN_CENTER)
        
        local remaining = math.max(0, math.ceil(duration - (CurTime() - startTime)))
        local tcol = remaining <= 5 and Color(255, 80, 80) or Color(180, 180, 180)
        draw.SimpleText(remaining .. "с", "NAA_Med", w/2, h - 30, tcol, TEXT_ALIGN_CENTER)
        
        draw.SimpleText(NAA.ClientCoins, "NAA_Med", 20, h - 30, Color(255, 220, 80))
        
        draw.SimpleText("Кликните по карте чтобы выбрать", "NAA_Small", w - 20, h - 30, Color(140, 140, 160), TEXT_ALIGN_RIGHT)
    end

    local timerKey = "NAA_UpgradeTimeout"
    timer.Create(timerKey, duration, 1, function()
        if IsValid(f) then
            net.Start("NAA_ChooseUpgrade") net.WriteString(cards[1] or "") net.SendToServer()
            f:Remove()
        end
    end)
    f.OnRemove = function() timer.Remove(timerKey) end

    local hoveredCard = nil

    for i, cardId in ipairs(cards) do
        local upg = NAA.Upgrades[cardId]
        if not upg then continue end

        local rc = NAA.RarityConfig[upg.rarity]
        local catc = NAA.CategoryConfig[upg.category]
        local cx = 20 + (i-1) * (CARD_W + 20)
        local cy = 65

        local card = vgui.Create("DButton", f)
        card:SetPos(cx, cy)
        card:SetSize(CARD_W, CARD_H)
        card:SetText("")
        card:SetCursor("hand")

        card.Paint = function(s, w, h)
            local isHov = s:IsHovered()
            if isHov then hoveredCard = cardId end

            local bg = isHov and Color(30, 20, 45) or Color(18, 12, 30)
            draw.RoundedBox(12, 0, 0, w, h, bg)
            
            if isHov then
                draw.RoundedBox(12, -3, -3, w+6, h+6, Color(rc.color.r, rc.color.g, rc.color.b, 100))
            end
            
            draw.RoundedBox(8, 8, 8, w-16, 8, rc.color)
            
            draw.SimpleText(rc.name, "NAA_Tiny", w - 12, 12, rc.color, TEXT_ALIGN_RIGHT)
            
            draw.RoundedBox(6, 8, 24, w-16, 28, Color(catc.color.r, catc.color.g, catc.color.b, 80))
            draw.SimpleText(catc.icon .. " " .. catc.name, "NAA_Small", w/2, 38, catc.color, TEXT_ALIGN_CENTER)
            
            draw.SimpleText(upg.icon, "NAA_Big", w/2, 85, Color(255, 255, 255), TEXT_ALIGN_CENTER)
            
            draw.SimpleText(upg.name, "NAA_Med", w/2, 130, Color(255, 255, 255), TEXT_ALIGN_CENTER)
            
            local cur = (NAA.ClientUpgrades or {})[cardId] or 0
            if cur > 0 then
                draw.SimpleText("⭐" .. cur .. " → ⭐" .. (cur+1), "NAA_Small", w/2, 158, Color(255, 220, 80), TEXT_ALIGN_CENTER)
            else
                draw.SimpleText("Новое!", "NAA_Small", w/2, 158, Color(80, 200, 80), TEXT_ALIGN_CENTER)
            end
            
            surface.SetDrawColor(rc.color.r, rc.color.g, rc.color.b, 100)
            surface.DrawRect(w/2 - 40, 180, 80, 2)
            
            local lines = WrapText(upg.desc, "NAA_Small", w - 30)
            local startY = 195
            for li, ln in ipairs(lines) do
                if li <= 5 then
                    draw.SimpleText(ln, "NAA_Small", w/2, startY + (li-1) * 22, Color(200, 200, 200), TEXT_ALIGN_CENTER)
                end
            end
            
            if isHov then
                draw.RoundedBox(8, 12, h - 50, w - 24, 38, Color(140, 30, 30, 230))
                draw.SimpleText("ВЫБРАТЬ", "NAA_Med", w/2, h - 32, Color(255, 255, 255), TEXT_ALIGN_CENTER)
            end
        end

        card.DoClick = function()
            surface.PlaySound("buttons/button9.wav")
            net.Start("NAA_ChooseUpgrade") net.WriteString(cardId) net.SendToServer()
            timer.Remove(timerKey)
            f:Remove()
        end
        
        card.OnCursorEntered = function()
            hoveredCard = cardId
        end
        card.OnCursorExited = function()
            hoveredCard = nil
        end
    end

    local btnY = CARD_H + 80
    local btnX = 20
    local btnW = 140
    local btnH = 42

    local rerollBtn = vgui.Create("DButton", f)
    rerollBtn:SetPos(btnX, btnY)
    rerollBtn:SetSize(btnW, btnH)
    rerollBtn:SetText("Реролл 5")
    rerollBtn:SetFont("NAA_Small")
    rerollBtn:SetTextColor(Color(255, 255, 255))
    rerollBtn.Paint = function(s, w, h)
        local canAfford = NAA.ClientCoins >= 5
        local bg = canAfford and (s:IsHovered() and Color(70, 60, 30) or Color(50, 40, 20)) or Color(30, 25, 15)
        draw.RoundedBox(8, 0, 0, w, h, bg)
        if not canAfford then
            draw.SimpleText("❌", "NAA_Small", w - 12, h/2, Color(255, 80, 80), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
    rerollBtn.DoClick = function()
        if NAA.ClientCoins < 5 then 
            surface.PlaySound("buttons/button10.wav")
            return 
        end
        surface.PlaySound("buttons/button9.wav")
        net.Start("NAA_RerollCards") net.SendToServer()
        f:Remove()
    end

    local extraBtn = vgui.Create("DButton", f)
    extraBtn:SetPos(btnX + btnW + 10, btnY)
    extraBtn:SetSize(btnW + 20, btnH)
    extraBtn:SetText("4-я карта 15")
    extraBtn:SetFont("NAA_Small")
    extraBtn:SetTextColor(Color(255, 255, 255))
    extraBtn.Paint = function(s, w, h)
        local canAfford = NAA.ClientCoins >= 15
        local bg = canAfford and (s:IsHovered() and Color(50, 60, 80) or Color(35, 45, 65)) or Color(25, 30, 40)
        draw.RoundedBox(8, 0, 0, w, h, bg)
        if not canAfford then
            draw.SimpleText("❌", "NAA_Small", w - 12, h/2, Color(255, 80, 80), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
    extraBtn.DoClick = function()
        if NAA.ClientCoins < 15 then 
            surface.PlaySound("buttons/button10.wav")
            return 
        end
        if #cards >= 4 then return end
        surface.PlaySound("buttons/button9.wav")
        net.Start("NAA_BuyExtraCard") net.SendToServer()
        f:Remove()
    end

    local shopBtn = vgui.Create("DButton", f)
    shopBtn:SetPos(btnX + btnW*2 + 20, btnY)
    shopBtn:SetSize(btnW, btnH)
    shopBtn:SetText("Магазин")
    shopBtn:SetFont("NAA_Small")
    shopBtn:SetTextColor(Color(255, 255, 255))
    shopBtn.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and Color(60, 30, 70) or Color(40, 20, 50))
    end
    shopBtn.DoClick = function()
        NAA_ShowShop(f)
    end

    if hasSynergyPanel then
        local sx = numCards * (CARD_W + 20) + 30
        local sp = vgui.Create("DScrollPanel", f)
        sp:SetPos(sx, 65)
        sp:SetSize(340, CARD_H + 10)
        
        sp.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(12, 8, 22, 200))
        end
        
        sp.VBar.Paint = function(s, w, h) 
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 20, 50)) 
        end
        sp.VBar.btnUp.Paint = function() end
        sp.VBar.btnDown.Paint = function() end

        local synergyCanvas = sp:GetCanvas()
        local uy = 8

        local titleLbl = vgui.Create("DLabel", synergyCanvas)
        titleLbl:SetPos(8, uy)
        titleLbl:SetSize(320, 30)
        titleLbl:SetText("СИНЕРГИИ")
        titleLbl:SetFont("NAA_Med")
        titleLbl:SetTextColor(Color(255, 220, 80))
        uy = uy + 35

        local curUpg = NAA.ClientUpgrades or {}
        local curClass = LocalPlayer():GetNWString("NAA_Class", "survivor")
        local activeSyn = NAA.GetActiveSynergies(curUpg, curClass)

        for _, syn in ipairs(NAA.Synergies) do
            if syn.classRequired and syn.classRequired ~= curClass then continue end

            local isActive = activeSyn[syn.id]
            
            local reqCounts = {}
            for _, r in ipairs(syn.requires) do 
                reqCounts[r] = (reqCounts[r] or 0) + 1 
            end
            
            local metCount = 0
            local totalReq = 0
            for req, needed in pairs(reqCounts) do
                totalReq = totalReq + needed
                metCount = metCount + math.min((curUpg[req] or 0), needed)
            end

            local progress = totalReq > 0 and (metCount / totalReq) or 0

            local hovContrib = false
            if hoveredCard then
                for req, needed in pairs(reqCounts) do
                    if req == hoveredCard and (curUpg[req] or 0) < needed then
                        hovContrib = true
                        break
                    end
                end
            end

            local row = vgui.Create("DPanel", synergyCanvas)
            row:SetPos(8, uy)
            row:SetSize(320, 65)
            uy = uy + 72

            row.Paint = function(s, w, h)
                local bg = isActive and Color(20, 50, 20) or Color(18, 14, 30)
                if hovContrib then bg = Color(40, 30, 60) end
                draw.RoundedBox(8, 0, 0, w, h, bg)
                
                local ic = isActive and Color(80, 220, 80) or syn.color
                draw.RoundedBox(4, 0, 4, 6, h-8, ic)
                
                local nameColor = isActive and Color(100, 255, 100) or Color(220, 220, 220)
                draw.SimpleText(syn.name, "NAA_Small", 16, 8, nameColor)
                
                if not isActive and totalReq > 0 then
                    local barW = w - 32
                    local barH = 6
                    draw.RoundedBox(3, 16, 28, barW, barH, Color(30, 30, 40))
                    draw.RoundedBox(3, 16, 28, barW * progress, barH, syn.color)
                end
                
                local reqY = isActive and 32 or 42
                local reqStr = ""
                for req, needed in pairs(reqCounts) do
                    local u = NAA.Upgrades[req]
                    local have = math.min(curUpg[req] or 0, needed)
                    reqStr = reqStr .. (u and u.name or req) .. " " .. have .. "/" .. needed .. " "
                end
                
                if #reqStr > 35 then
                    reqStr = reqStr:sub(1, 35) .. "..."
                end
                
                draw.SimpleText(reqStr, "NAA_Tiny", 16, reqY, Color(160, 160, 180))
                
                if hovContrib then
                    draw.SimpleText("выбери!", "NAA_Tiny", w - 12, h/2, Color(255, 220, 80), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end
        end

        synergyCanvas:SetTall(uy + 15)
    end
end