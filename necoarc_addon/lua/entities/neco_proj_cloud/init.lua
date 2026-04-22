AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/Items/AR2_Grenade.mdl")
        self:SetModelScale(0.01)
        self:SetSolid(SOLID_NONE)
        self:SetMoveType(MOVETYPE_NONE)
        self:DrawShadow(false)

        self.CloudRadius = self:GetNWInt("CloudRadius", 120)
        self.CloudEnd = self:GetNWFloat("CloudEnd", CurTime() + 5)
        self.CloudDPS = self:GetNWInt("CloudDPS", 3)
        self.Attacker = self.Attacker or self

        self.NextDamage = CurTime() + 1
    end

    function ENT:Think()
        if CurTime() > self.CloudEnd then
            self:Remove()
            return
        end

        if CurTime() >= self.NextDamage then
            self.NextDamage = CurTime() + 1
            local pos = self:GetPos()
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:Alive() and ply:GetPos():Distance(pos) < self.CloudRadius then
                    local d = DamageInfo()
                    d:SetDamage(self.CloudDPS)
                    d:SetAttacker(IsValid(self.Attacker) and self.Attacker or self)
                    d:SetInflictor(self)
                    d:SetDamageType(DMG_POISON)
                    ply:TakeDamageInfo(d)
                end
            end
        end

        self:NextThink(CurTime())
        return true
    end
end