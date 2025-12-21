----------------------------------
---- CONSTANTS & UPGRADE INIT ----
----------------------------------
local UPGRADE = {}
UPGRADE.id    = "pap_giftwrap"
UPGRADE.class = "weapon_ttt_giftwrap"

----------------------------------
----- PAP UPGRADE DEFINITION -----
----------------------------------
function UPGRADE:Condition()
    return false
end

function UPGRADE:Apply(SWEP)
    if CLIENT then
        self.name = "Fancy " .. SWEP.PrintName
        self.desc = "Gives your gift a golden PaP texture!"
    end
end

TTTPAP:Register(UPGRADE)