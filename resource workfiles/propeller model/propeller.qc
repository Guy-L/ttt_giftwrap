$modelname "propeller_hat.mdl"

$bodygroup "studio"
{
    studio "propeller_reference.smd"
}

$cdmaterials "models/ttt/propeller_hat"

$surfaceprop "plastic"

$sequence "idle" "anims/idle.smd" fps 1
$sequence "spin_slow" "anims/spin.smd" loop fps 6
$sequence "spin_med"  "anims/spin.smd" loop fps 14
$sequence "spin_fast" "anims/spin.smd" loop fps 28
$sequence "spin_max"  "anims/spin.smd" loop fps 60