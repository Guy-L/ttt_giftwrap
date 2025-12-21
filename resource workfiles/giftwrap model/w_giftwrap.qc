$modelname "weapons/w_giftwrap.mdl"

$bodygroup "studio"
{
    studio "w_giftwrap_reference.smd"
}

$surfaceprop "crowbar"

$contents "solid"

$illumposition 1.857 10.65 0.762

$cdmaterials "models/ttt/giftwrap/"

$cbox 0 0 0 0 0 0

$bbox -34.613 -4.684 -4.153 16.011 6.644 5.777

$definebone "ValveBiped.Bip01_R_Hand" "" -0.631371 -6.659214 -3.65312 -74.60186 -163.122348 -102.294862 0 0 0 0 0 0


$sequence "idle" {
    "w_giftwrap_anims\giftwrap_idle.smd"
    activity "ACT_VM_IDLE" 1
    fadein 0.2
    fadeout 0.2
    fps 30
    loop
}

$sequence "attack1" {
    "w_giftwrap_anims\giftwrap_attack1.smd"
    fadein 0.2
    fadeout 0.2
    fps 30
}

$collisionmodel "w_giftwrap_physics.smd"
{
    $mass 2
    $inertia 3
    $damping 1
    $rotdamping 0.5
    $rootbone "ValveBiped.Bip01_R_Hand"
}
