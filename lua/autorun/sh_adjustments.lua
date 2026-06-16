include("sh_giftwrap_utils.lua")
local utils = GW_Utils
local dbg   = GW_DBG

local MAT_INFO = "vgui/ttt/menu/icon_info"
local MAT_WARN = "vgui/ttt/menu/icon_warn"

local CORPSE_STINK_ENABLE = utils.Cvar("ttt2_giftwrap_corpse_stink_enable", "1", 0, 1, "Whether gifts containing fleshy ragdolls will start to stink (particles+sound).")
local CORPSE_STINK_DELAY  = utils.Cvar("ttt2_giftwrap_corpse_stink_delay", "15", 0, 120, "Delay before gifts containing fleshy ragdolls start to stink if enabled, in seconds.")

utils.adjustments = {
    grenade = {
        desc = "Stores detonation time on wrap, applies it with an extra delay on unwrap. Used for weapon_tttbasegrenade SENTs.",
        on_wrap = function(ent)
            local curTime = CurTime()

            ent:SetNWFloat("StoredExplodeTime", ent:GetExplodeTime() - curTime)
            ent:SetExplodeTime(curTime + 1e9)
        end,

        on_spawn = function(ent, ply)
            if ent.GetThrower and not IsValid(ent:GetThrower()) then
                ent:SetThrower(ply)
            end
        end,

        on_unwrap = function(ent, _, args)
            local storedExplodeTime = ent:GetNWFloat("StoredExplodeTime", 1.5)
            local addedTime = args.explosion_delay or 1.5
            ent:SetDetonateTimer(storedExplodeTime + addedTime)
        end,

        info = function(giftEnt, args)
            local wrappedEnt = giftEnt:GetStoredGift()
            local explodeTime = IsValid(wrappedEnt) and wrappedEnt:GetNWFloat("StoredExplodeTime", 1.5) or 1.5
            explodeTime = explodeTime + (args.explosion_delay or 1.5)

            if explodeTime < 1000 and not args.no_info then
                return { img = MAT_WARN, msg = "Will detonate "..(math.Round(explodeTime, 1)).."s after unwrap." }
            end
        end,
    },

    grenade_auto = {
        desc = "Nullifies explosion method while wrapped and calls it after a delay on unwrap. Used for grenades that use timer.Simple & an Explode method.",
        on_wrap = function(ent)
            ent._StoredExplode = ent.Explode
            ent.Explode = function(s) end
        end,

        on_unwrap = function(ent, _, args)
            if not ent._StoredExplode then return end

            local fuse = args.explosion_delay or 2
            ent.Explode = ent._StoredExplode

            timer.Simple(fuse, function()
                if IsValid(ent) then
                    ent:Explode()
                end
            end)
        end,

        info = function(_, args)
            local explodeTime = args.explosion_delay or 2
            return { img = MAT_WARN, msg = "Will detonate "..(math.Round(explodeTime, 1)).."s after unwrap." }
        end,
    },

    item_buy = {
        desc = "Calls an item's Bought method when spawned by Gift Wrap.",
        on_spawn = function(_, ply, args)
            items.GetStored(args.val):Bought(ply)
        end,
    },

    set_owner = {
        desc = "Sets the entity's owner when spawned by Gift Wrap.",
        on_spawn = function(ent, ply)
            ent:SetOwner(ply)

            ent.Owner = ply
            ent.owner = ply
        end,
    },

    set_thrower = {
        desc = "Sets the entity's thrower/originator when spawned by Gift Wrap.",
        on_spawn = function(ent, ply)
            if ent.SetThrower then ent:SetThrower(ply) end
            if ent.SetOriginator then ent:SetOriginator(ply) end
        end,
    },

    set_angles = {
        desc = "Sets the entity's angles when unwrapped.",
        on_unwrap = function(ent, _, args)
            ent:SetAngles(args.val)
        end,
    },

    set_mass = {
        desc = "Sets the entity's mass when unwrapped.",
        on_unwrap = function(ent, _, args)
            local phys = ent:GetPhysicsObject()

            if IsValid(phys) then
                phys:SetMass(args.val)
            end
        end,
    },

    break_constraints = {
        desc = "Removes constraints attached to the entity upon wrap.",
        on_wrap = function(ent)
            constraint.RemoveAll(ent)
        end,
    },

    no_physwake = {
        desc = "Tells Gift Wrap not to wake up the entity's physics on unwrap.",
        on_unwrap = function(ent)
            ent._DontWake = true
        end,
    },

    mark_invalid = {
        desc = "Makes the entity fail validity checks while wrapped.", -- cf. isvalid_condition in sh_tweaks
        on_wrap = function(ent)
            ent._Invalid = true
        end,

        on_unwrap = function(ent)
            ent._Invalid = false
        end,
    },

    wrap_sleep = {
        desc = "Prevents entity from calling its Think method while wrapped.",
        on_wrap = function(ent)
            ent:NextThink(CurTime() + 1e9)
        end,

        on_unwrap = function(ent)
            ent:NextThink(CurTime())
        end,
    },

    auto_fire_chance = {
        desc = "Chance to set the gift's contents ablaze when auto-wrapped.",
        on_autowrap = function(_, _, args)
            local p = args.val or 0.5

            if math.random() < p then
                args.giftbox:SetIsContentsOnFire(true)
            end
        end,
    },

    stick_to_ground = {
        desc = "Sticks the entity to the ground directly under where it's unwrapped.",
        on_unwrap = function(ent, _, args)
            local groundTr = utils.GetGroundHit(utils.GetEntCenter(ent), ent)

            if groundTr.Hit then
                ent:SetPos(groundTr.HitPos)

                timer.Simple(0, function()
                    ent:SetAngles(groundTr.HitNormal:Angle() + (args.ground_angles and args.ground_angles or Angle(90, 0, 0)))
                    if ent.WeldToSurface then ent:WeldToSurface(true) end
                end)
                ent:SetMoveType(MOVETYPE_NONE)

                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    phys:AddGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)
                end
            end
        end,
    },

    up_throw = {
        desc = "Gives the entity some upwards velocity on unwrap.",
        on_unwrap = function(ent, _, args)
            local upMin = args.min or 10
            local upMax = args.max or upMin
            local upAmt = math.Rand(upMin, upMax)
            local vel   = utils.GetRandomUpwardsVel(upAmt) * args.vel
            local angle_vel = args.angvel or -500

            timer.Simple(0, function()
                local phys = ent:GetPhysicsObject()

                phys:EnableMotion(true)
                phys:Wake()
                phys:SetVelocity(vel)
                phys:AddAngleVelocity(Vector(0, angle_vel, 0))
                ent:SetAngles(vel:Angle())
            end)
        end,

        info = function(_, args)
            if not args.max and not args.min then
                return { img = MAT_INFO, msg = "Will fling upwards when unwrapped." }
            else
                return { img = MAT_INFO, msg = "Will fling upwards in a random direction when unwrapped." }
            end
        end,
    },

    follow_gift = {
        desc = "Makes the entity's position match that of its parent giftbox while wrapped.",
        on_wrap = function(ent)
            dbg.Log("Setting "..tostring(ent).." to track its giftbox...")
            local hookName = "TTT_GiftWrapSV_WrappedEntFollowBox_"..ent:EntIndex()

            hook.Add("Think", hookName, function()
                if not IsValid(ent) then
                    hook.Remove("Think", hookName)
                    return
                end

                local parentGift = ent:GetNW2Entity("WrappedByGift")
                if IsValid(parentGift) then
                    local pos = parentGift:GetPos()

                    if parentGift:IsWeapon() then
                        pos = pos + Vector(0, 0, 30)
                    end

                    ent:SetPos(pos)
                    ent.LastPos = pos -- c4

                    if ent.IsADisguise then -- prop disguiser
                        ent.TiedPly:SetNWFloat("PD_TimeLeft", CurTime() + ent.TiedPly.StoredTimeLeft)
                    end
                end
            end)
        end,

        on_unwrap = function(ent)
            hook.Remove("Think", "TTT_GiftWrapSV_WrappedEntFollowBox_"..ent:EntIndex())
        end,
    },

    spawn_info = {
        desc = "Extra custom options menu info for gift behavior when spawned by Gift Wrap.",
        info = function(giftEnt, args)
            local wrappedEnt = giftEnt:GetStoredGift()

            if not IsValid(wrappedEnt) or (IsValid(wrappedEnt:GetNWEntity("GW_Spawner")) and args.post_spawn) then
                return { img = args.warn and MAT_WARN or MAT_INFO, msg = args.msg }
            end
        end
    },

    produce_flies = {
        desc = "Flies will emanate from the giftbox after a delay (until it's unwrapped).",
        on_wrap = function(ent)
            if not CORPSE_STINK_ENABLE:GetBool() then return end

            local stinkDelay = CORPSE_STINK_DELAY:GetFloat()
            ent:SetNWFloat("FliesArrival", CurTime() + stinkDelay)

            timer.Create("GWCorpseStink"..ent:EntIndex(), stinkDelay, 1, function()
                if IsValid(ent) then
                    utils.StartStink(ent:GetNW2Entity("WrappedByGift"))
                end
            end)
        end,

        on_autowrap = function(_, _, args)
            if CORPSE_STINK_ENABLE:GetBool() then
                utils.StartStink(args.giftbox)
            end
        end,

        on_unwrap = function(ent)
            timer.Remove("GWCorpseStink"..ent:EntIndex())
        end,

        info = function(giftEnt, args)
            local wrappedEnt = giftEnt:GetStoredGift()
            local self = utils.adjustments.produce_flies.info

            if not IsValid(wrappedEnt) or giftEnt:GetNW2Bool("GWStinky") then
                return { img = MAT_INFO, msg = "Flies have amassed...", fn = self }
            else
                local stinkTime = wrappedEnt:GetNWFloat("FliesArrival", -1)

                if stinkTime == -1 then
                    return { img = MAT_WARN, msg = "Flies will swarm the giftbox soon...", fn = self }
                else
                    return { img = MAT_WARN, msg = "Flies will swarm the giftbox in "..(math.Round(stinkTime - CurTime(), 1)).."s.", fn = self }
                end
            end
        end,
    },

    --------------------------------------------
    -- Common Traps

    ambush_giftee = {
        desc = "Places the entity on the ground on unwrap, facing the giftee. If unwrap is an undo from the wrapper, it faces away from them by default.",
        on_unwrap = function(ent, ply, args)
            local groundTr = utils.GetGroundHit(utils.GetEntCenter(ent), ent)

            if groundTr.Hit then
                local ang = groundTr.HitNormal:Angle() + Angle(90, 0, 0)

                local dir = (ply:GetPos() - ent:GetPos()):GetNormalized()
                dir = (dir - groundTr.HitNormal * dir:Dot(groundTr.HitNormal)):GetNormalized()

                local forward = ang:Forward()
                local rot = math.deg(math.atan2(
                    forward:Cross(dir):Dot(groundTr.HitNormal),
                    forward:Dot(dir)
                ))

                if args.is_undo and not args.face_wrapper then
                    rot = rot + 180
                end

                ang:RotateAroundAxis(groundTr.HitNormal, rot + (args.angle or 0))
                ent:SetAngles(ang)
                ent:SetPos(groundTr.HitPos + Vector(0, 0, args.y_off or 0))
            else
                ent:SetAngles(Angle(0, ang.y - 90, 0))
            end
        end,

        info = function(_, args)
            if args.face_wrapper or args.cant_undo then
                return { img = MAT_WARN, msg = "Spawns on the ground in front of the player who unwraps it, facing them." }
            else
                return { img = MAT_WARN, msg = "Spawns on the ground in front of the player who unwraps it, facing them.\nIf you drop the contents, it'll face away from you instead." }
            end
        end,
    },

    under_giftee = {
        desc = "Places the entity under the giftee on unwrap. Does nothing if unwrap is an undo from the wrapper.",
        on_unwrap = function(ent, ply, args)
            if args.is_undo then return end

            local curMoveType = ent:GetMoveType()
            ent:SetMoveType(MOVETYPE_VPHYSICS)
            ent:SetPos(ply:GetPos())
            ent:SetMoveType(curMoveType)
        end,

        info = function(_, args)
            if args.cant_undo then
                return { img = MAT_WARN, msg = "Spawns directly under the player who unwraps it." }
            else
                return { img = MAT_WARN, msg = "Spawns directly under the player who unwraps it, unless that player is you." }
            end
        end,
    },

    auto_drive = {
        desc = "Makes giftee enter the vehicle on unwrap. Does nothing if unwrap is an undo from the wrapper.",
        on_unwrap = function(ent, ply, args)
            if args.is_undo then return end
            ply:EnterVehicle(ent)

            timer.Simple(1.5, function()
                if ply:InVehicle() then
                    utils.NonSpamMessage(ply, "AutoDriveHint", "Hint: Press the use key to exit the vehicle.")
                end
            end)
        end,

        info = function(_, args)
            if args.cant_undo then
                return { img = MAT_WARN, msg = "The player who unwraps this vehicle will automatically enter it." }
            else
                return { img = MAT_WARN, msg = "The player who unwraps this vehicle will automatically enter it, unless that player is you." }
            end
        end,
    },

    unwrap_throw = {
        desc = "Throws the entity in the direction the giftee is looking on unwrap after a delay and with some random offset. The delay is lower and the offset is removed if the entity was considered \"parried\" by being wrapped mid-flight.",
        on_wrap = function(ent)
            if ent.dt and ent.dt.Collided then -- hwapoon
                ent:SetNWBool("WasParried", false)
            else
                ent:SetNWBool("WasParried", true)
            end
        end,

        on_unwrap = function(ent, ply, args)
            local phys = ent:GetPhysicsObject()
            local isParry = ent:GetNWBool("WasParried")

            timer.Simple(isParry and 0.5 or args.delay, function()
                if phys:IsValid() then
                    local aim = ply:GetAimVector()
                    local randVec = args.up_only and utils.GetRandomUpwardsVel(0) or VectorRand()
                    local randMult = isParry and 0 or args.rngMult
                    local finalVel = (aim + randVec * randMult):GetNormalized() * args.force

                    phys:Wake()
                    phys:EnableMotion(true)
                    phys:SetVelocity(finalVel)
                end
            end)
        end,

        info = function(giftEnt, args)
            local wrappedEnt = giftEnt:GetStoredGift()

            if IsValid(wrappedEnt) and wrappedEnt:GetNWBool("WasParried") then
                return { img = MAT_WARN, msg = "Successfully parried! Directly thrown forward when unwrapped." }
            elseif args.delay > 0 then
                return { img = MAT_INFO, msg = "Thrown forward when unwrapped, with a random angle offset, after a short delay." }
            else
                return { img = MAT_INFO, msg = "Thrown forward when unwrapped with a random angle offset." }
            end
        end,
    },

    --------------------------------------------
    -- Entity-Specific Setups

    bunger_setup = {
        desc = "Fixes visibility of Bunger model overlay on wrap/unwrap; also sets up friendly bunger gift (random spawn).",
        on_wrap = function(ent)
            local bungerChild = utils.GetEntChildAt(ent, 1)

            if IsValid(bungerChild) then
                bungerChild:SetNoDraw(true)
            end
        end,

        on_spawn = function(ent, ply)
            -- copied from bunger addon
            ent:SetNPCState(2)
            ent:SetNoDraw(true)
            ent:SetNWEntity("Thrower", ply)
            ent:SetNWBool("GWFriendlyBunger", true)

            local bunger = ents.Create("prop_dynamic")
            bunger:SetModel("models/betterbunger.mdl")
            bunger:SetPos(ent:GetPos())
            bunger:SetAngles(Angle(0, 270 ,0))
            bunger:SetParent(ent)
            bunger:SetModelScale(2, 0) -- for cute

            local hat = ents.Create("prop_dynamic")
            hat:SetModel("models/ttt/propeller_hat/propeller_hat.mdl")
            hat:SetPos(bunger:GetPos() + Vector(2, 0, 20.5))
            hat:SetAngles(Angle(0, 270, 1))
            hat:SetParent(bunger)
            hat:SetModelScale(3.5, 0)

            hat:Spawn()
            hat:SetSequence("spin_max")
            hat:ResetSequence("spin_max")
        end,

        on_unwrap = function(ent)
            local bungerChildren = ent:GetChildren()
            if #bungerChildren <= 0 then return end
            local bungerChild = bungerChildren[1]

            if IsValid(bungerChild) then
                bungerChild:SetNoDraw(false)
                ent:SetNoDraw(true)
            end

            -- npc health must be set after spawning
            if ent:GetNWBool("GWFriendlyBunger") then
                ent:SetMaxHealth(1200)
                ent:SetHealth(1200)
            end
        end,

        gift_desc = function(ent)
            if not IsValid(ent) or ent:GetNWBool("GWFriendlyBunger") then
                return "a pet Bunger"
            else
                return "an angry Bunger"
            end
        end
    },

    timed_molotov_wrap = {
        desc = "Prevents Timed Molotovs exploding & their fire trail rendering while wrapped.",
        on_wrap = function(ent)
            local curTime = CurTime()

            ent:SetNWFloat("StoredFuse", math.max(2.5, 5 - (curTime - ent.SpawnTime)))
            ent.SpawnTime = curTime + 1e9

            local trail = utils.GetEntChildAt(ent, 1)
            if IsValid(trail) then
                trail:Remove()
            end
        end,

        on_unwrap = function(ent)
            ent.SpawnTime = CurTime() - ent:GetNWFloat("StoredFuse", 1)

            local trail = utils.GetEntChildAt(ent, 1)
            if not IsValid(trail) then
                trail = ents.Create("env_fire_trail")
                trail:SetPos(ent:GetPos())
                trail:SetParent(ent)
                trail:Spawn()
                trail:Activate()
            end
        end,

        info = function(giftEnt, args)
            local ent = giftEnt:GetStoredGift()
            local explodeTime = IsValid(ent) and ent:GetNWFloat("StoredFuse", 1) or 1

            return { img = MAT_WARN, msg = "Will detonate "..(math.Round(explodeTime + 0.5, 1)).."s after unwrap." }
        end,
    },

    moon_grenade_setup = {
        desc = "Prevents Moon Grenade exploding while wrapped & fixes spawning new ones.",
        on_wrap = function(ent)
            timer.Remove(ent.FuseID)
            timer.Remove("MG_Unwrap_"..ent:EntIndex())
            ent:SetNWFloat("FuseTime", math.max(1.5, ent.FuseTime))
        end,

        on_spawn = function(ent, ply)
            ent.GrenadeOwner = ply
        end,

        on_unwrap = function(ent)
            timer.Create("MG_Unwrap_"..ent:EntIndex(), ent:GetNWFloat("FuseTime", 5), 1, function()
                if IsValid(ent) then
                    ent:DoBoom()
                end
            end)
        end,

        info = function(giftEnt, args)
            local ent = giftEnt:GetStoredGift()
            local explodeTime = IsValid(ent) and ent:GetNWFloat("FuseTime", 5) or 5

            return { img = MAT_WARN, msg = "Will detonate "..(math.Round(explodeTime, 1)).."s after unwrap." }
        end,
    },

    manhack_stop_control = {
        desc = "Stops the Manhack remote control upon wrap.",
        on_wrap = function(ent)
            local owner = ent:GetPlayerController()
            ent:StopControlling()

            if IsValid(owner) then
                owner:ChatPrint("Your manhack was wrapped into a giftbox!")
            end
        end,

        info = function(giftEnt, args)
            local wrappedEnt = giftEnt:GetStoredGift()

            if IsValid(wrappedEnt) then
                local owner = wrappedEnt:GetPlayerController()

                if owner == LocalPlayer() then
                    return { img = MAT_INFO, msg = "Can remotely detonate the Manhack inside the giftbox by pressing "..Key("+reload").."." }
                else
                    return { img = MAT_WARN, msg = "Can be remotely detonated by the player who deployed it!" }
                end
            end
        end,
    },

    green_demon_wrap = {
        desc = "Resets Green Demon's state on unwrap (half the usual wake up time if it was already moving).",
        on_wrap = function(ent)
            if ent.Solidified then
                ent.LoopSound:Stop()
                ent:SetNWBool("Awoken", true)
            else
                ent.ActivateTime = CurTime() + 1e9
                ent:SetNWBool("Awoken", false)
            end
        end,

        on_unwrap = function(ent)
            local wakeUpTime = GetConVar("sv_ttt2_greendemon_spawn_delay"):GetFloat()

            if ent.Solidified then
                ent.Solidified = false
                wakeUpTime = wakeUpTime / 2
            end

            ent:EmitSound(ent.SpawnSound)
            ent.ActivateTime = CurTime() + wakeUpTime
        end,

        info = function(giftEnt, args)
            local ent = giftEnt:GetStoredGift()
            local wakeUpTime = GetConVar("sv_ttt2_greendemon_spawn_delay"):GetFloat()

            if IsValid(ent) and ent:GetNWBool("Awoken") then
                return { img = MAT_WARN, msg = "Will start moving "..(math.Round(wakeUpTime / 2, 1)).."s after unwrap (moving speed reset)." }
            else
                return { img = MAT_WARN, msg = "Will start moving "..(math.Round(wakeUpTime, 1)).."s after unwrap." }
            end
        end,
    },

    seekgull_wrap = {
        desc = "Freezes Seekgull while it's wrapped.",
        on_wrap = function(ent)
            ent.SecondsPerTick = 1e9
        end,

        on_unwrap = function(ent)
            ent.SecondsPerTick = 0.01
            ent:NextThink(CurTime())
        end,
    },

    starburst_ent_wrap = {
        desc = "Freezes Starburst while it's wrapped & resets its explosion counter on unwrap.",
        on_wrap = function(ent)
            ent:NextThink(CurTime() + 1e9)
            timer.Remove("killPlasmaBurster2AfterTime")
        end,

        on_unwrap = function(ent, ply)
            ent.Trail = util.SpriteTrail(ent, 0, Color(255, 100, 0), false, 32, 1, 0.3, 0.01, "trails/plasma.vmt")
            ent.charges = GetConVar("ttt_plasmaburster_bounces"):GetInt()
            ent:NextThink(CurTime() + 0.1)
        end,
    },

    harpoon_unwrap = {
        desc = "Gives the Harpoon a random angle on unwrap and changes its unwrap distance + allow original thrower to be hit.",
        on_unwrap = function(ent, ply)
            ent:Initialize()
            local aim = ply:GetAimVector()
            ent:SetAngles(aim:Angle())
            ent:SetOwner(ply)

            local targetPos = ply:EyePos() + Vector(aim.x, aim.y, 0):GetNormalized() * 150
            local phys = ent:GetPhysicsObject()

            if phys:IsValid() then
                phys:Sleep()
                phys:SetPos(targetPos)
            end
        end,
    },

    barnacle_setup = {
        desc = "Fix for wrapping Barnacle with player in its clutches, notify player that random-made Barnacle can be shot, fix for unwrapping Barnacle (creates a new one, on top of the giftee unless it's an undo).",
        on_wrap = function(ent)
            ent:Fire("LetGo")
            local enemy = ent:GetInternalVariable("m_hEnemy")

            if IsValid(enemy) and enemy:IsPlayer() and enemy:Alive() then
                enemy:RemoveEFlags(EFL_IS_BEING_LIFTED_BY_BARNACLE)
            end
        end,

        on_spawn = function(_, ply)
            timer.Simple(1.5, function()
                if IsValid(ply) and ply:Alive() and ply:IsEFlagSet(EFL_IS_BEING_LIFTED_BY_BARNACLE) then
                    ply:ChatPrint("NOTE: You CAN shoot it to escape!")
                end
            end)
        end,

        on_unwrap = function(ent, ply, args)
            local pos = ent:GetPos()
            local ang = ent:GetAngles()
            local owner = ent:GetDamageOwner()
            ent:Remove() --tried very hard to properly move it but it's too involved

            local startPos = args.is_undo and pos or ply:GetPos()
            local upTr = util.TraceLine({
                start = startPos,
                endpos = startPos + Vector(0, 0, 10000),
                filter = ply,
                mask = MASK_SOLID_BRUSHONLY
            })

            local newPos = upTr.Hit and upTr.HitPos or startPos + Vector(0, 0, 100)
            local newBarnacleOwner = IsValid(owner) and owner or ply
            local newBarnacle = ents.Create("npc_barnacle")
            newBarnacle:SetPos(newPos)
            newBarnacle:SetAngles(ang)
            newBarnacle:SetNWEntity("owner", newBarnacleOwner)
            newBarnacle:SetDamageOwner(newBarnacleOwner)
            newBarnacle:SetRenderMode(RENDERMODE_TRANSALPHA)
            newBarnacle:SetColor(Color(0,0,0,30))
            newBarnacle:SetKeyValue("RestDist",50)
            newBarnacle:Spawn()
            newBarnacle:Activate()
            newBarnacle:SetHealth(50)
            newBarnacle:Fire("SetDropTongueSpeed", 100)

            local timerName = newBarnacle:EntIndex().."_timer" --recreate barnacle addon logic
            timer.Create(timerName, 0.1, 0, function()
                if not IsValid(newBarnacle) then
                    timer.Remove(timerName)
                    return
                end

                local enemy = newBarnacle:GetInternalVariable("m_hEnemy")
                if IsValid(enemy) and enemy:IsPlayer() and enemy:Alive() then
                    newBarnacle:SetColor(Color(255, 255, 255, 255))
                    if IsValid(owner) then enemy:SelectWeapon('weapon_ttt_unarmed') end

                elseif not newBarnacle.Health or newBarnacle:Health() <= 0 then
                    newBarnacle:SetColor(Color(255, 255, 255, 255))
                    timer.Remove(timerName)

                else
                    newBarnacle:SetColor(Color(0, 0, 0, 25))
                end
            end)
        end,

        info = function(giftEnt, args)
            local ent = giftEnt:GetStoredGift()

            if not IsValid(ent) then
                return { img = MAT_WARN, msg = "Spawns directly above the player who unwraps it, who can shoot it to escape." }
            elseif args.cant_undo then
                return { img = MAT_WARN, msg = "Spawns directly above the player who unwraps it." }
            else
                return { img = MAT_WARN, msg = "Spawns directly above the player who unwraps it, unless that player is you." }
            end
        end,
    },

    force_shield_sfx = {
        desc = "Stops the Force Shield's SFX while it's wrapped & restart it on unwrap.",
        on_wrap = function(ent)
            ent:StopSound("ambient/machines/combine_shield_touch_loop1.wav")

            if ent._LoopSound then
                ent._LoopSound:Stop()
            end
        end,

        on_unwrap = function(ent)
            --ent:EmitSound("ambient/machines/combine_shield_touch_loop1.wav", 55)

            -- switching to CSoundPatch was less glitchy (StopSound didn't work the second/third/etc. time around)
            ent._LoopSound = CreateSound(ent, "ambient/machines/combine_shield_touch_loop1.wav")
            ent._LoopSound:SetSoundLevel(55)
            ent._LoopSound:Play()
        end
    },

    icegrenade_wrap = {
        desc = "Prevents Ice Grenade exploding while wrapped.",
        on_wrap = function(ent)
            local timerID = ent:EntIndex().."_timer"
            ent:SetNWFloat("StoredFuse", timer.TimeLeft(timerID) + 1)
            timer.Remove(timerID)
        end,

        on_unwrap = function(ent)
            ent:iceexplode(ent:GetNWFloat("StoredFuse", 1.8))
        end,

        info = function(giftEnt, args)
            local ent = giftEnt:GetStoredGift()
            local explodeTime = IsValid(ent) and ent:GetNWFloat("StoredFuse", 1.8) or 1.8

            return { img = MAT_WARN, msg = "Will detonate "..(math.Round(explodeTime, 1)).."s after unwrap." }
        end,
    },

    flame_wrap = {
        desc = "Prevents flame from dying while wrapped. Giftbox is also set ablaze (based on data label).",
        on_wrap = function(ent)
            ent:SetDieTime(CurTime() + 1e9)
        end,

        on_unwrap = function(ent)
            ent:SetDieTime(CurTime() + 30)
            ent:StartFire()
        end,

        info = function(giftEnt, args)
            return { img = MAT_WARN, msg = "You probably shouldn't spend time reading this unless you have fire damage immunity..." }
        end,
    },

    fireball_wrap = {
        desc = "Freezes Fireball while wrapped & allows detecting it.",
        on_wrap = function(ent)
            ent._StoredCallback = ent:GetCallbacks("PhysicsCollide")[1]
            ent:RemoveCallback("PhysicsCollide", 1)
            timer.Pause("FireBallLife"..ent.Time)
        end,

        on_unwrap = function(ent, ply)
            ent:AddCallback("PhysicsCollide", ent._StoredCallback)
            timer.UnPause("FireBallLife"..ent.Time)
        end,

        detect = function(ent)
            return ent:GetName() == "Fireball"
        end,
    },

    fart_grenade_setup = {
        desc = "Disables Fart Grenade while it's wrapped, restarts it on unwrap, allows spawning new ones & detecting it.",
        on_wrap = function(ent)
            if timer.Exists("fartsmoke_"..ent:EntIndex()) then
                timer.Pause("fartsmoke_"..ent:EntIndex())
                ent:SetNWBool("FartingStarted", true)

            else
                timer.Simple(2, function()
                    if IsValid(ent) and timer.Exists("fartsmoke_"..ent:EntIndex()) then
                        timer.Pause("fartsmoke_"..ent:EntIndex())
                    end
                end)
            end
        end,

        on_spawn = function(ent, ply)
            local fart_grenade = weapons.GetStored("weapon_fartgrenade")
            fart_grenade:CreateGrenade(Vector(0, 0, 0), Angle(0, 0, 0), Vector(0, 0, 0), Vector(0, 0, 0), ply)

            return ents.GetAll()[#ents.GetAll()]
        end,

        on_unwrap = function(ent)
            local delay = ent:GetNWBool("FartingStarted") and 1.2 or 2.5
            dbg.Log("Resuming fart in", delay)

            timer.Simple(delay, function()
                if timer.Exists("fartsmoke_"..ent:EntIndex()) then
                    timer.UnPause("fartsmoke_"..ent:EntIndex())

                    ParticleEffect("fartsmoke", ent:GetPos() + Vector(-80, -40, 0), Angle(0, 0, 0), nil)
                    ent:EmitSound(Sound("fart_1.wav"))
                end
            end)
        end,

        detect = function(ent)
            -- no better check unfortunately
            return ent:GetModel() == "models/weapons/w_grenade.mdl"
              and utils.NearEquals(ent:GetGravity(), 0.4)
              and utils.NearEquals(ent:GetFriction(), 0.2)
              and utils.NearEquals(ent:GetElasticity(), 0.45)
        end,

        can_spawn = function()
            return weapons.GetStored("weapon_fartgrenade") ~= nil
        end,

        info = function(giftEnt, args)
            local ent = giftEnt:GetStoredGift()

            if IsValid(ent) and ent:GetNWBool("FartingStarted") then
                return { img = MAT_WARN, msg = "Farting will resume 1.2s after unwrap." }
            else
                return { img = MAT_WARN, msg = "Farting will commence 2.5s after unwrap." }
            end
        end,
    },

    conc_mine_wrap = {
        desc = "Allows wrapping Concussion Mines after they're set off (but before they explode).",
        on_wrap = function(ent)
            if ent.setoff then
                ent:NextThink(CurTime() + 1e9)
                ent:SetNWBool("SetOff", true)
            end
        end,

        on_unwrap = function(ent)
            if ent.setoff then
                ent:StartFuse()
                ent:NextThink(CurTime() + 0.1)
            end
        end,

        info = function(giftEnt, args)
            local ent = giftEnt:GetStoredGift()

            if IsValid(ent) and ent:GetNWBool("SetOff") then
                return { img = MAT_WARN, msg = "Mine has been set off; will immediately detonate when it's unwrapped." }
            end
        end,
    },

    cannonball_wrap = {
        desc = "Freezes Cannonballs while wrapped.",
        on_wrap = function(ent)
            ent.Stuck = true
            ent._DontKill = true
        end,

        on_unwrap = function(ent, ply)
            ent.StartPos = ply:GetPos() + Vector(0, 0, 10000) -- ensure explosion
            ent.Stuck = false
        end,
    },

    c4_wrap = {
        desc = "Add 10s to C4 on wrap & explode giftbox if wrapped when clock reaches 0. Also prevents Lua errors.",
        on_wrap = function(ent)
            ent:SetDetonateTimer(ent:GetExplodeTime() - CurTime() + 10)
            ent.LastPos = ent:GetPos()
            ent._OGThink = ent.Think
            ent._OGExplode = ent.Explode

            ent.Explode = function(self, tr)
                local wrap = utils.GetTopmostWrap(self)
                self:RemoveCallOnRemove(WRAPPED_GIFT_REMOVE)
                ent._OGExplode(self, tr)

                if IsValid(wrap) then
                    wrap:Remove()
                end
            end
        end,

        on_unwrap = function(ent)
            ent.LastPos = ent:GetPos()

            if ent._OGExplode then
                ent.Explode = ent._OGExplode
            end
        end,

        info = function(giftEnt, args)
            local ent = giftEnt:GetStoredGift()
            local self = utils.adjustments.c4_wrap.info


            if IsValid(ent) and ent:GetArmed() then
                return { img = MAT_WARN, msg = "Not frozen; will detonate from inside the giftbox in "..(math.Round(ent:GetExplodeTime() - CurTime(), 1)).."s...", fn = self }
            else
                return { img = MAT_INFO, msg = "Not armed.", fn = self }
            end
        end,
    },

    groovitron_wrap = {
        desc = "Stops Groovitron music & removes its spotlights on wrap.",
        on_wrap = function(ent)
            if ent.Collided then
                ent:StopSound(ent.MusicName)
                ent:StopSound(ent.MusicName)

                for _, ent in ipairs(ents.FindInSphere(ent._GWStoredPos, 3)) do
                    if ent:GetClass() == "beam_spotlight" then
                        ent:Remove()
                    end
                end
            end
        end,
    },

    explo_barrel_unwrap = {
        desc = "Heals barrel by a bit on unwrap & makes it attribute its damage to the wrapper.",
        on_unwrap = function(ent, _, args)
            local wrapper = utils.GetWrapper(args.giftbox)
            local onFire = ent:IsOnFire() or args.giftbox:GetIsContentsOnFire()

            if wrapper and onFire then
                local dmg = DamageInfo()
                dmg:SetDamage(0)
                dmg:SetAttacker(wrapper)
                ent:TakeDamageInfo(dmg)
                ent:SetHealth(math.min(ent:Health() + 6, ent:GetMaxHealth()))
            end
        end
    },

    fortnite_struct_setup = {
        desc = "Picks a random structure on autowrap, spawns it, unwraps it in custom position, and overrides its desc/smell/visuals.",

        on_autowrap = function(_, _, args)
            local giftObj = args.giftbox
            local mat = math.random(0, 2)
            local mode = math.max(math.random(-1, 3), 0) -- bias to wall
            if mode == FORTNITE_FLOOR then mode = 0 end  -- bias to wall + floors on the floor are weird

            local matStr = ({
                [FORTNITE_WOOD]  = "wood",
                [FORTNITE_STONE] = "brick",
                [FORTNITE_METAL] = "metal",
            })[mat]

            local modeStr = ({
                [FORTNITE_WALL]   = "wall",
                [FORTNITE_FLOOR]  = "floor",
                [FORTNITE_STAIRS] = "stairw",
                [FORTNITE_ROOF]   = "roofc",
            })[mode]

            giftObj:SetNW2String("fortnite_model", "models/fortnitea31/buildingparts/pbw/"..matStr .."/"..matStr.."_"..modeStr..".mdl")
            giftObj:SetNW2Int("fortnite_mode", mode)
            giftObj:SetNW2Int("fortnite_mat", mat)
        end,

        on_spawn = function(ent, _, args)
            local giftObj = args.giftbox

            ent:SetModel(giftObj:GetNW2String("fortnite_model", "models/fortnitea31/buildingparts/pbw/wood/wood_wall.mdl"))
            ent.Mode    = giftObj:GetNW2Int("fortnite_mode", FORTNITE_WALL)
            ent.Material = giftObj:GetNW2Int("fortnite_mat", FORTNITE_WOOD)
            ent.Neighbours = {}
        end,

        on_unwrap = function(ent, ply, args)
            local model = IsValid(ent) and ent:GetModel() or args.giftbox:GetNW2String("fortnite_model")
            local pushDist = string.EndsWith(model, "wall.mdl") and 150 or 300

            local aim = ply:GetAimVector()
            local targetPos = ply:EyePos() + Vector(aim.x, aim.y, 0):GetNormalized() * pushDist

            local yaw = (ply:GetPos() - targetPos):Angle().y
            ent:SetAngles(Angle(0, yaw, 0))

            local groundTr = utils.GetGroundHit(targetPos, ent)
            if groundTr.Hit and groundTr.HitPos:Distance(targetPos) <= 150 then
                ent:SetPos(groundTr.HitPos)

            else
                local yAdj = string.EndsWith(model, "wall.mdl") and 75 or 50
                ent:SetPos(targetPos - Vector(0, 0, yAdj))
            end
        end,

        gift_desc = function(ent, giftObj)
            local model = IsValid(ent) and ent:GetModel() or giftObj:GetNW2String("fortnite_model")

            if string.EndsWith(model, "wall.mdl") then
                return "a wall"
            elseif string.EndsWith(model, "floor.mdl") then
                return "a floor"
            elseif string.EndsWith(model, "stairw.mdl") then
                return "a staircase"
            elseif string.EndsWith(model, "roofc.mdl") then
                return "a roof"
            end
        end,

        gift_smell = function(ent, giftObj)
            local model = IsValid(ent) and ent:GetModel() or giftObj:GetNW2String("fortnite_model")

            if string.StartsWith(model, "models/fortnitea31/buildingparts/pbw/wood") then
                return GiftSmell.Woody
            elseif string.StartsWith(model, "models/fortnitea31/buildingparts/pbw/brick") then
                return GiftSmell.Clay
            elseif string.StartsWith(model, "models/fortnitea31/buildingparts/pbw/metal") then
                return GiftSmell.Metallic
            else
                return GiftSmell.Nondescript
            end
        end,

        gift_visuals = function(_, giftObj)
            return giftObj:GetNW2String("fortnite_model")
        end,

        info = function(_, args)
            return { img = MAT_INFO, msg = "Snaps to the ground if ground is nearby, but doesn't otherwise." }
        end,
    },

    bouncy_ball_random_size = {
        desc = "Spawns bouncy ball entity with a random size.",
        on_spawn = function(ent)
            ent:SetBallSize(math.random(20, 50))
        end,
    },

    shield_deployer_spawn = {
        desc = "Fixes Lua error when spawning Force Shield deployer.",
        on_spawn = function(ent, ply)
            ent.shieldDeployAngleYaw = ply:GetEyeTrace().Normal:Angle().yaw
        end,
    },

    fan_spawn = {
        desc = "Fixes spawning Fans & ensures they aren't invincible.",
        on_spawn = function(ent, ply)
            ent:SetName("ttt_fan")
            ent.Owner = ply -- for some reason set_owner messes with health setup
        end,

        on_unwrap = function(ent)
            local health = ent:GetNWInt("health")

            if not health or health == 0 then --newly spawned
                ent:SetNWInt("health", TTT_FAN.CVARS.fan_health)
            end
        end,
    },

    random_gift_spawn = {
        desc = "Makes newly spawned Gift random & have boosted odds.",
        on_spawn = function(ent, ply)
            local newLabel, newData = GetRandomGiftData(ply, 10)
            ent:SetCachedDataLabel(newLabel)
            newData:ApplyOnAutoWrapAdjustments(ent)

            ent:SetIsRandomGift(true)
            ent:SetWrapperSID("WORLD")
            RollGiftColors(ent)
        end,

        info = function(giftEnt, args)
            local ent = giftEnt:GetStoredGift()

            if not IsValid(ent) or ent:GetIsRandomGift() then
                return { img = MAT_INFO, msg = "Contains a random gift!" }
            end
        end,
    },

    snuffles_present_spawn = {
        desc = "Selects a random model for Snuffles presents.",
        on_autowrap = function(_, _, args)
            local presentModels = {
                "models/katharsmodels/present/type-2/big/present.mdl",
                "models/katharsmodels/present/type-2/big/present2.mdl",
                "models/katharsmodels/present/type-2/big/present3.mdl"
            }

            args.giftbox:SetNW2String("snuffles_present_mdl", presentModels[math.random(#presentModels)])
        end,

        on_spawn = function(ent, _, args)
            ent.Model = args.giftbox:GetNW2String("snuffles_present_mdl")
        end,

        gift_visuals = function(_, giftObj)
            return giftObj:GetNW2String("snuffles_present_mdl")
        end
    },

    slam_spawn = {
        desc = "Sets the SLAM's placer on spawn to allow pickup.",
        on_spawn = function(ent, ply)
            ent:SetPlacer(ply)
        end,

        info = function(giftEnt, args)
            local wrappedEnt = giftEnt:GetStoredGift()

            if IsValid(wrappedEnt) then
                return { img = MAT_WARN, msg = "Can be remotely detonated by the player who placed it!" }
            end
        end,
    },

    moonball_spawn = {
        desc = "Selects a random skin for the Moonball and sets its owner.",
        on_spawn = function(ent, ply)
            local skindex = math.random(0, 18) -- awesome var name from the original addon

            ent:SetSkin(skindex)
            ent:SetMoonballSkin(skindex)
            ent:SetNWEntity("MoonballOwner", ply)
        end,
    },

    pog_set_role = {
        desc = "Sets the role associated with a Live Pot of Greedier to the giftee's.",
        on_spawn = function(ent, ply)
            -- may be unnecessary?
            ent:SetRole(ply:GetSubRole())
        end,
    },

    pog_shard_role = {
        desc = "Sets the role associated with a Shard of Greed to the giftee's, or Detective if giftee has no shop.",
        on_spawn = function(ent, ply)
            local gifteeRole = ply:GetSubRole()
            local gifteeRoleData = utils.GetSubRoleData(gifteeRole)

            if not gifteeRoleData or not gifteeRoleData:IsShoppingRole() then
                ent.Role = ROLE_DETECTIVE
            else
                ent.Role = gifteeRole
            end
        end,
    },

    pap_setup = {
        desc = "Makes PaP upgrade the type of weapon the player is using to open the gift (hands/holstered or crowbar).",
        on_spawn = function(_, ply, args)
            local giftObj = args.giftbox

            local preferredWepName = giftObj:GetClass() == SWEP_CLASS_NAME and "weapon_ttt_unarmed" or "weapon_zm_improvised"
            local preferredWep = ply:GetWeapon(preferredWepName)

            if IsValid(preferredWep) and not preferredWep.PAPUpgrade then
                ply:SelectWeapon(preferredWepName)
                giftObj._UpgradeGiftWep = preferredWepName
            else
                ply:SelectWeapon("weapon_zm_improvised")
                giftObj._UpgradeGiftWep = "weapon_zm_improvised"
            end
            TTTPAP:OrderPAP(ply, true)

            -- note: copied from pap's OrderedEquipment hook (i would've called it directly,
            --       but I need to know the old numeric ID EQUIP_PAP which somehow becomes nil over the namespace
            timer.Simple(0.1, function()
                if ply.RemoveEquipmentItem then
                    ply:RemoveEquipmentItem("ttt2_pap_item")
                else
                    ply.equipment_items = bit.bxor(ply.equipment_items, "ttt2_pap_item")
                    ply:SendEquipment()
                end
            end)
        end,

        gift_desc = function(ent, giftObj)
            if giftObj._UpgradeGiftWep == "weapon_zm_improvised" then
                return "a fresh coat of paint for your crowbar"
            elseif giftObj._UpgradeGiftWep == "weapon_ttt_unarmed" then
                return "yellow bodypaint"
            end
        end,

        can_spawn = function(_, _, ply)
            -- player must have non-PaP crowbar or holstered
            local foundUpgradeable = false

            for _, wep in ipairs(ply:GetWeapons()) do
                if IsValid(wep) and not wep.PAPUpgrade and wep:GetClass() == "weapon_zm_improvised"
                  or wep:GetClass() == "weapon_ttt_unarmed" then
                    foundUpgradeable = true
                    break
                end
            end

            if not foundUpgradeable then return false end
        end,

        info = function()
            return { img = MAT_WARN, msg = "Upgrades Crowbar if opened via crowbar, or Holstered if opened in the player's hands." }
        end,
    },

    sopd_spawn = {
        desc = "Custom description for SoPD & nerfs ones spawned by Gift Wrap.",
        on_purchase = function(_, _, args)
            args.giftbox:SetNW2Bool("SwordBought", true) -- yeah this sucks i know
        end,

        on_spawn = function(ent, _, args)
            if ent.SetGrabbedFromCorpse and not args.giftbox:GetNW2Bool("SwordBought") then
                ent:SetGrabbedFromCorpse(true)
            end
        end,

        gift_desc = function(_, _, ply)
            if ply:SteamID64() == swordTarget.SID64 then
                return "a sword meant just for you"
            elseif swordTarget.name and swordTarget.name ~= "" then
                if IsPlayer(swordTarget.player)
                  and not utils.IsLivingPlayer(swordTarget.player) then
                    return "a posthumous gift for "..swordTarget.name
                else
                    return "a gift for "..swordTarget.name
                end
            else
                return "a loud sword"
            end
        end,

        info = function(giftEnt)
            if giftEnt:GetNW2Bool("SwordBought") then return end
            local wrappedEnt = giftEnt:GetStoredGift()

            if not IsValid(wrappedEnt) then
                return { img = MAT_INFO, msg = "Doesn't grant speed boost." }
            elseif not wrappedEnt:IsWeapon() or wrappedEnt:GetGrabbedFromCorpse() then
                return { img = MAT_INFO, msg = "Doesn't grant speed boost nor destroys DNA on stab." }
            end
        end
    },

    baron_hat_drop = {
        desc = "Makes the Baron Hat properly drop when spawned.",
        on_spawn = function(ent)
            timer.Simple(0, function() ent:Drop() end)
        end,
    },

    sandwich_spoil = {
        desc = "Spoils sandwich after a short delay & notifies giftee.",
        on_spawn = function(ent, ply)
            local delay = math.random(2, 5)
            ply:ChatPrint("Grab it while it's still fresh! ("..delay.." seconds)")

            timer.Simple(delay, function()
                if IsValid(ent) then
                    ent:OnDrop()
                end
            end)
        end,
    },

    shellmet_phys = {
        desc = "Sets up physics for a newly spawned Shellmet entity.",
        on_unwrap = function(ent, ply)
            -- commented out: making the shellmet spawn auto-equipped
            --if ply:HasEquipmentItem("item_ttt2_shellmet") then
                -- lifted from addon
            if not IsValid(ent:GetPhysicsObject()) then
                ent:SetBeingWorn(false)
                ent:SetUseType(SIMPLE_USE)
                ent:PhysicsInit(SOLID_VPHYSICS)
                ent:SetSolid(SOLID_VPHYSICS)
                ent:SetMoveType(MOVETYPE_VPHYSICS)
            end

            --else
            --    ent:WearHat(ply)
            --end
        end,
    },

    amaterasu_buy = {
        desc = "Prevents Amaterasu applying when bought for gift, and properly applies it on unwrap.",
        on_purchase = function(_, ply)
            ply:SetNWBool("TTTAmaterasu", false)
        end,

        on_unwrap = function(_, ply)
            ply:SetNWBool("TTTAmaterasu", true)
            SetGlobalBool("TTTAmaterasuBought", true)
        end,
    },

    paper_plane_mass = {
        desc = "Fixes Paper Planes having extreme speed when spawned by Gift Wrap.",
        on_unwrap = function(ent)
            local phys = ent:GetPhysicsObject()

            -- otherwise it'll zoom at mach speed towards its target
            if IsValid(phys) then
                phys:SetMass(200)
            end
        end,
    },

    baron_hat_buy = {
        desc = "Prevents Baron Hat being equipped when bought for gift.",
        on_purchase = function(_, ply)
            ply.baron_hat:Remove()
            ply.baron_hat = nil
            ply:RemoveEquipmentItem("item_ttt2_baron_hat")
        end,
    },

    poison_station_desc = {
        desc = "Reveals what the station is in its name/description for evil-role players.",
        gift_desc = function(_, _, ply, args)
            if PS2_Utils and PS2_Utils.IsMainEvil(ply) and not args.for_others then
                return "a poisonous microwave"
            else
                return "a healing microwave"
            end
        end,

        gift_name = function(_, _, ply)
            if PS2_Utils and PS2_Utils.IsMainEvil(ply) then
                return "Live Poison Station"
            else
                return "Live Health Station"
            end
        end,
    },

    giftwrap_desc = {
        desc = "Matches description of Gift Wrap with whether it stores a gift. Note that wrapping a Gift Wrap SWEP with a gift in it (as opposed to a Gift SENT) is normally impossible.",
        gift_desc = function(ent)
            if ent.HasGift and ent:HasGift() then
                return "another gift"
            else
                return "more wrapping paper"
            end
        end
    },

    tesla_bolt_wrap = {
        desc = "Allows wrapping & spawning Tesla Bow bolts.",
        on_wrap = function(ent)
            ent._OGTouch = ent.Touch
            ent.Touch = function() end
            ent:NextThink(CurTime() + 1e9)
            ent.Impact = 0
        end,

        on_spawn = function(ent, ply)
            ent:SetPos(ply:GetShootPos())
            ent:SetAngles(ply:EyeAngles() + Angle( 90, 0, 0))
            ent:SetGravity(math.random(0.5, 0.8))

            util.SpriteTrail(ent, 0, Color(255, 155, 0), false, 20, 0, 0.6, 0.1, "trails/laser")
        end,

        on_unwrap = function(ent, ply)
            ent:SetNoDraw(true)
            ent:SetMoveType(MOVETYPE_VPHYSICS)
            ent:SetOwner(ply)

            if not ent.origin then
                ent.origin = ent
                ent.dmg = 60
            end

            timer.Simple(0, function()
                ent:NextThink(CurTime())

                if ent._OGTouch then
                    ent.Touch = ent._OGTouch
                end
            end)
        end,
    },

    holy_watermelon_detect = {
        desc = "Detection function for the Holy Watermelon on ttt_sky_resort.",
        detect = function(ent, _, _, _, args)
            local children = ent:GetChildren()

            if #children == 1 and children[1]:GetName() == "godcrown" then
                return args.is_holy
            end
        end,
    },

    turtle_cap_desc = {
        desc = "Renders heart emoji in Plush Turtle Cap description if possible.",
        gift_desc = function(_, _, _, args)
            local customChatEnable = GetConVar("custom_chat_enable")

            if not args.for_menu and customChatEnable and customChatEnable:GetBool() then
                return "an \"I :heart: Turtle\" cap"
            else
                return "an \"I Love Turtle\" cap"
            end
        end,
    },

    rollermine_mute = {
        desc = "Mutes Rollermine for clients while wrapped.",
        on_wrap = function(ent)
            ent:StopSound("npc/roller/mine/combine_mine_active_loop1.wav")
            ent:StopSound("npc/roller/mine/rmine_movefast_loop1.wav")
            ent:StopSound("npc/roller/mine/rmine_moveslow_loop1.wav")
            ent:StopSound("npc/roller/mine/rmine_seek_loop2.wav")
        end,
    },

    cscanner_mute = {
        desc = "Mutes City Scanner for clients while wrapped.",
        on_wrap = function(ent)
            ent:StopSound("npc/scanner/cbot_fly_loop.wav")
            ent:StopSound("npc/scanner/combat_scan_loop1.wav")
            ent:StopSound("npc/scanner/combat_scan_loop2.wav")
            ent:StopSound("npc/scanner/combat_scan_loop4.wav")
            ent:StopSound("npc/scanner/combat_scan_loop6.wav")
            ent:StopSound("npc/scanner/scanner_combat_loop1.wav")
            ent:StopSound("npc/scanner/scanner_scan_loop1.wav")
            ent:StopSound("npc/scanner/scanner_scan_loop2.wav")
        end,
    },

    secret_formula_detect = {
        desc = "Detection function for the Secret Formula on ttt_bikinibottom.",
        detect = function(ent, _, _, _, args)
            if ent:GetName() == "secretformula" then
                return args.is_secret
            end
        end,
    },
}

function utils.ApplyAdjustments(event, ent, ply, adjs, giftObj)
    if not adjs then return end
    local ret

    for name, defaultArgs in pairs(adjs) do
        local adjData = utils.adjustments[name]
        local eventName = (type(event) == "table") and event.name or event

        if adjData and adjData["on_"..eventName] then
            local args = utils.PrepareArgs(defaultArgs)
            args.is_undo = event.state
            args.giftbox = giftObj

            local retEnt = adjData["on_"..eventName](ent, ply, args)
            if retEnt and not IsValid(ret) then
                ret = retEnt
            end
        end
    end

    return ret
end

function utils.AdjustmentRun(func, ent, adjs, giftObj, ply, args)
    if not adjs then return end

    for name, defaultArgs in pairs(adjs) do
        local adjData = utils.adjustments[name]

        if adjData and adjData[func] then
            return adjData[func](ent, giftObj, ply, args, defaultArgs)
        end
    end
end

function utils.PrepareArgs(baseArgs)
    local args = {}

    if type(baseArgs) == "table" then -- create copy
        for k, v in pairs(baseArgs) do
            args[k] = v
        end
    else
        args.val = baseArgs
    end

    return args
end

function utils.CollectInfo(giftData, giftEnt)
    if not giftData then
        giftData = GetGiftDataFromLabel(giftEnt:GetCachedDataLabel())
    end

    local info = {}
    local cantUndo = giftEnt:IsWeapon() and (not giftEnt:HasGift() or giftEnt:GetIsOpening()
      or giftEnt:GetPaperOnUndo() <= 0 or not giftEnt:OwnedByWrapper() or giftEnt:GetIsRandomGift())

    if giftData then
        if giftData.adjustments then
            for name, defaultArgs in pairs(giftData.adjustments) do
                local adjData = utils.adjustments[name]

                if adjData and adjData.info then
                    local args = utils.PrepareArgs(defaultArgs)
                    args.cant_undo = cantUndo

                    local newInfo = adjData.info(giftEnt, args)
                    if newInfo then
                        table.insert(info, newInfo)
                    end
                end
            end
        end

        if giftData.category == GiftCategory.Ragdoll then
            local wrappedEnt = giftEnt:GetStoredGift()

            if not giftData.disable_flies or CORPSE.IsValidBody(wrappedEnt) then
                table.insert(info, utils.adjustments.produce_flies.info(giftEnt))
            end
        end
    end

    return info
end