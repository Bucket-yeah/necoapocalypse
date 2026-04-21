-- ============================================================
--  NECO ARC APOCALYPSE — cl_shop.lua  (CLIENT)
-- ============================================================

local ShopItemsDef = {
    { id="hp50",     name="+50 HP",          cost=8,  desc="Восстанавливает 50 HP"        },
    { id="armor50",  name="+50 Броня",       cost=6,  desc="Восстанавливает 50 брони"     },
    { id="ammo",     name="Все патроны",       cost=4,  desc="Пополняет весь боезапас"      },
    { id="weapon",   name="Случайное оружие",  cost=10, desc="Случайное оружие из арсенала" },
}

function NAA_ShowShop(parent)
    local f = vgui.Create("DFrame", parent)
    f:SetSize(380, 340)
    f:Center()
    f:SetTitle(" Магазин")
    f:MakePopup()
    f:ShowCloseButton(true)

    f.Paint = function(s,w,h)
        draw.RoundedBox(0,0,0,w,h,Color(10,6,18,240))
        draw.SimpleText("Монет: "..NAA.ClientCoins, "NAA_Med", w/2, 34,
            Color(255,220,80), TEXT_ALIGN_CENTER)
    end

    local by = 60
    for _, item in ipairs(ShopItemsDef) do
        local row = vgui.Create("DButton", f)
        row:SetPos(16, by) row:SetSize(348, 50)
        row:SetText("")
        by = by + 58

        row.Paint = function(s,w,h)
            local canBuy = NAA.ClientCoins >= item.cost
            local bg = canBuy and (s:IsHovered() and Color(35,25,50) or Color(20,14,32)) or Color(15,10,22)
            draw.RoundedBox(8,0,0,w,h,bg)
            draw.SimpleText(item.name, "NAA_Med", 12, 6, canBuy and Color(255,255,255) or Color(100,100,100))
            draw.SimpleText(item.desc, "NAA_Tiny", 12, 30, Color(160,160,160))
            draw.SimpleText(""..item.cost, "NAA_Med", w-12, h/2,
                canBuy and Color(255,220,80) or Color(100,80,30), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        row.DoClick = function()
            if NAA.ClientCoins < item.cost then return end
            surface.PlaySound("buttons/button9.wav")
            net.Start("NAA_BuyShop") net.WriteString(item.id) net.SendToServer()
            NAA.ClientCoins = NAA.ClientCoins - item.cost
        end
    end
end
