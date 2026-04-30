$modelname "weapons/prop_gift.mdl"

$bodygroup "studio"
{
    studio "prop_gift_reference.smd"
}

$surfaceprop "Item"
$contents "solid"
$illumposition 1.857 10.65 0.762
$cdmaterials "models/ttt/giftwrap/"
$cbox 0 0 0 0 0 0

$sequence "idle" {
    "w_gift_anims\gift_idle.smd"
    fps 1
    loop
}

$collisionmodel "prop_gift_physics.smd"
{
    $mass 5
    $inertia 4
    $damping 1
    $rotdamping 1
    $surfaceprop "Wood"
}
