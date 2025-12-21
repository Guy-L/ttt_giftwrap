$bodygroup "studio"
{
    studio "w_coal_reference.smd"
}

$surfaceprop "Rock"

$contents "solid"

$illumposition 1.857 10.65 0.762

$cdmaterials "models/ttt/giftwrap/"

$cbox 0 0 0 0 0 0

$bbox -34.613 -4.684 -4.153 16.011 6.644 5.777

$definebone "Box01" "" 6 -12 0 0 0 0 0 0 0 0 0 0

$sequence "idle" {
	"coal_anims\idle.smd"
	fadein 0.2
	fadeout 0.2
	fps 30
}

$collisionmodel "phys.smd"
{
    $mass 25
    $inertia 4
    $damping 1
    $rotdamping 1
}
