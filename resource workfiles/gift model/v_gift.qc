$modelname "Weapons/v_gift.mdl"

$bodygroup "studio"
{
    studio "v_gift_reference.smd"
    blank
}

$surfaceprop "default"

$contents "solid"

$illumposition 0 0 0
$cdmaterials "models/ttt/giftwrap/"

$hboxset "default"

$bonemerge "ValveBiped.Bip01_Spine4"
$bonemerge "ValveBiped.Bip01_R_Clavicle"
$bonemerge "ValveBiped.Bip01_R_UpperArm"
$bonemerge "ValveBiped.Bip01_R_Forearm"
$bonemerge "ValveBiped.Bip01_R_Hand"
$bonemerge "ValveBiped.Bip01_Neck1"
$bonemerge "ValveBiped.Bip01_Head1"
$bonemerge "ValveBiped.Bip01_L_Clavicle"
$bonemerge "ValveBiped.Bip01_L_UpperArm"
$bonemerge "ValveBiped.Bip01_L_Forearm"
$bonemerge "ValveBiped.Bip01_L_Hand"
$bonemerge "ValveBiped.Bip01_L_Finger4"
$bonemerge "ValveBiped.Bip01_L_Finger41"
$bonemerge "ValveBiped.Bip01_L_Finger42"
$bonemerge "ValveBiped.Bip01_L_Finger3"
$bonemerge "ValveBiped.Bip01_L_Finger31"
$bonemerge "ValveBiped.Bip01_L_Finger32"
$bonemerge "ValveBiped.Bip01_L_Finger2"
$bonemerge "ValveBiped.Bip01_L_Finger21"
$bonemerge "ValveBiped.Bip01_L_Finger22"
$bonemerge "ValveBiped.Bip01_L_Finger1"
$bonemerge "ValveBiped.Bip01_L_Finger11"
$bonemerge "ValveBiped.Bip01_L_Finger12"
$bonemerge "ValveBiped.Bip01_L_Finger0"
$bonemerge "ValveBiped.Bip01_L_Finger01"
$bonemerge "ValveBiped.Bip01_L_Finger02"
$bonemerge "ValveBiped.Bip01_R_Finger4"
$bonemerge "ValveBiped.Bip01_R_Finger41"
$bonemerge "ValveBiped.Bip01_R_Finger42"
$bonemerge "ValveBiped.Bip01_R_Finger3"
$bonemerge "ValveBiped.Bip01_R_Finger31"
$bonemerge "ValveBiped.Bip01_R_Finger32"
$bonemerge "ValveBiped.Bip01_R_Finger2"
$bonemerge "ValveBiped.Bip01_R_Finger21"
$bonemerge "ValveBiped.Bip01_R_Finger22"
$bonemerge "ValveBiped.Bip01_R_Finger1"
$bonemerge "ValveBiped.Bip01_R_Finger11"
$bonemerge "ValveBiped.Bip01_R_Finger12"
$bonemerge "ValveBiped.Bip01_R_Finger0"
$bonemerge "ValveBiped.Bip01_R_Finger01"
$bonemerge "ValveBiped.Bip01_R_Finger02"

$sequence "idle" {
    "v_gift_anims\idle.smd"
    activity "ACT_VM_IDLE" 1
    fadein 0.2
    fadeout 0.2
    node "Ready"
    snap
    fps 30
    loop
}

$sequence "draw" {
    "v_gift_anims\deploy.smd"
    activity "ACT_VM_DRAW" 1
    fadein 0.2
    fadeout 0.2
    snap
    fps 30
}

$sequence "holster" {
    "v_gift_anims\holster.smd"
    activity "ACT_VM_HOLSTER" 1
    fadein 0.2
    fadeout 0.2
    snap
    fps 30
}

$sequence "primary" {
    "v_gift_anims\primary.smd"
    activity "ACT_VM_PRIMARYATTACK" 1
    fadein 0.2
    fadeout 0.2
    snap
    fps 30
}

$sequence "shake_h" {
    "v_gift_anims\shake_h.smd"
    activity "ACT_VM_SECONDARYATTACK" 1
    fadein 0.2
    fadeout 0.2
    snap
    fps 25
}

$sequence "shake_v" {
    "v_gift_anims\shake_v.smd"
    activity "ACT_VM_SECONDARYATTACK" 1
    fadein 0.2
    fadeout 0.2
    snap
    fps 25
}