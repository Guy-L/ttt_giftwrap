local L = LANG.GetLanguageTableReference("en")

-- General
L["wrap_instruction_lmb"] = "Wrap gift"
L["wrap_instruction_r"] = "Undo wrap"
L["giftwrap_instruction_rmb"] = "Gift options"
L["gift_instruction_wrapper_lmb"] = "Throw gift"
L["gift_instruction_all_lmb"] = "Open gift"
L["gift_instruction_all_rmb"] = "Shake gift"

L["gift_mv_giftee"] = "A gift just for you!"
L["gift_mv_wrapper"] = "Your thrown gift"
L["gift_mv_wrapper_giftee"] = "Your gift for {giftee}"
L["gift_mv_tp"] = "Gift teleported"
L["gift_mv_tp_desc"] = "This gift was moved back in-bounds."
L["gift_mv_tp_time"] = "Notice disappears in: {timeLeft}s"

L["gift_unwrap_notif_wrapper"] = "{giftee} opened your gift!"
L["gift_unwrap_notif_random"] = "Someone unwrapped a random gift!"
L["gift_unwrap_notif_rare"] = "Someone unwrapped a random Super Rare gift!"

-- Settings Forms
L["label_giftwrap_balance_form"] = "Custom Balance Settings"
L["label_giftwrap_corpse_stink_enable"] = "Gifts containing fleshy ragdolls eventually start to stink (particles + sound)"
L["label_giftwrap_corpse_stink_delay"] = "Delay before stink begins (seconds)"

L["label_giftwrap_random_gifts_form"] = "Natural Random Gifts"
L["label_giftwrap_random_gifts_desc"] = [[If your server has the YoWaddup General Fixes addon installed, this addon will replace the 3 gifts next to its naturally generating Christmas Tree with gifts bearing random gifts. See the addon's workshop or GitHub page for the current random gift pool.

Note that this menu may be improved in the future to show the random gift pool visually.]]
L["label_giftwrap_enable_random_gifts"] = "Spawn random gifts as described above if possible"
L["label_giftwrap_replace_snuffles_gift"] = "Replace (rather than add to) YoWaddup presents"
L["label_giftwrap_all_served_chime_vol_desc"] = "A bell chime will emanate from YoWaddup Christmas Trees at round start if as many gifts from this addon spawn as there are players."
L["label_giftwrap_all_served_chime_vol"] = "Christmas bell chime volume (%)"
L["label_giftwrap_timezone_offset"] = "Timezone offset when determining whether it's Christmas"
L["label_giftwrap_bonus_gifts_desc"] = "Probabilities for bonus gifts to spawn, per YoWaddup present. A third bonus gift can only spawn if the second one also spawned."
L["label_giftwrap_second_gift_chance"] = "Second bonus gift spawn chance"
L["label_giftwrap_third_gift_chance"] = "Third bonus gift spawn chance"
L["label_giftwrap_second_gift_chance_xmas"] = "Second bonus gift spawn chance (Christmas day only)"
L["label_giftwrap_third_gift_chance_xmas"] = "Third bonus gift spawn chance (Christmas day only)"
L["label_giftwrap_match_playercount_desc"] = "The below two chances override the above 4 if they trigger; instead, as many gifts spawn around the Christmas Tree as there are players at round start."
L["label_giftwrap_match_playercount"] = "Chance for playercount-matched round"
L["label_giftwrap_match_playercount_xmas"] = "Chance for playercount-matched round (Christmas day only)"
L["label_giftwrap_weights_desc"] = [[These determine the general likelihood of each of the main gift classes appearing.
Note that I'm aware it's not very intuitive how setting these affects the gift pool, and I plan to improve this menu to help with that.
The category assignments (and possible pool in general) are also designed around the YoWaddup server. I also plan to add more control over this for other servers.]]
L["label_giftwrap_prop_weight"] = "Weight multiplier for physics prop gifts"
L["label_giftwrap_floor_weight"] = "Weight multiplier for floor SWEP gifts"
L["label_giftwrap_special_weight"] = "Weight multiplier for special entity & event gifts"
L["label_giftwrap_shop_weight"] = "Weight multiplier for shop SWEP gifts"

L["label_giftwrap_vdfix_form"] = "Vehicle Damage Fix"
L["label_vehicle_damagefix_desc"] = [[Gift Wrap packages a general fix for cases of vehicle riders being functionally invincible:
 • Driver: Without the fix, damage dealt to any part of the vehicle other than the driver's seat is divided by 10000.
 • Passenger: Without the fix, damage dealt to any part of the vehicle is not carried over to passengers in non-driver seats.
The below slider allow you to select the damage multiplier (from a weapon's base damage) when fixing damage for drivers and for passengers.]]
L["label_vehicle_damagefix_enable"] = "Enable vehicle damage fix"
L["label_vehicle_damagefix_driver_mult"] = "Driver damage multiplier (%)"
L["label_vehicle_damagefix_passenger_mult"] = "Passenger damage multiplier (%)"

L["label_giftwrap_tweaks_form"] = "Third-Party Addon Tweaks"
L["label_giftwrap_tweaks_desc"] = [[Gift Wrap packages various miscellaneous tweaks to third-party addons to make them work better with itself.
It is not recommended to disable them, but you can do so here if any cause issues.
The toggles will take effect on map reload.]]

L["label_giftwrap_misc_form"] = "Debugging & Miscellaneous"
L["label_giftwrap_give_guy_access"] = "Allow author to change Gift Wrap convars & shop config"
L["label_giftwrap_debug"] = "Enable debug mode (not recommended)"

-- Gift Options Menu
L["gift_opt_title"] = "Gift Options"
L["gift_opt_error"] = "Error (invalid gift ref)"

L["gift_opt_appearance_title"] = "Appearance"
L["gift_opt_color_form"] = "Gift Colors"
L["gift_opt_color_form_reroll_desc"] = "Reroll colors"
L["gift_opt_color_form_reroll"] = "Reroll Colors"
L["gift_opt_color_form_box"] = "Box Color"
L["gift_opt_color_form_ribbon"] = "Ribbons Color"

L["gift_opt_contents_title"] = "Contents"
L["gift_opt_current_content"] = "Current Contents"
L["gift_opt_change_content_form"] = "Change Contents"
L["gift_opt_change_form_error_nocred"] = "No credits left."
L["gift_opt_change_form_error_full"] = "Something else is already wrapped."

L["gift_opt_change_form_drop_desc"] = "Drop contents"
L["gift_opt_change_form_drop"] = "Drop Contents"
L["gift_opt_change_form_drop_error_none"] = "Nothing to drop!"
L["gift_opt_change_form_drop_error_block"] = "Can't drop this kind of thing."
L["gift_opt_change_form_drop_error_random"] = "Can't drop things you didn't wrap manually. Give it to someone else!"

L["gift_opt_change_form_random_desc"] = "Wrap a random gift (cost: 1 credit)"
L["gift_opt_change_form_random"] = "Random Gift"

L["gift_opt_change_form_shop_desc"] = "Wrap something from your Shop"
L["gift_opt_change_form_shop"] = "Shop for Gift"
L["gift_opt_change_form_shop_error_role"] = "Your role doesn't have a shop."

L["gift_opt_debug_title"] = "Debug"
L["gift_opt_debug_form"] = "Debug Options"
L["gift_opt_debug_form_anonymize_desc"] = "Remove wrapper SID"
L["gift_opt_debug_form_anonymize"] = "Make Anonymous"
L["gift_opt_debug_form_select_label"] = "Select gift contents"
L["gift_opt_debug_form_delete_desc"] = "Delete gift or wrap"
L["gift_opt_debug_form_delete"] = "Delete"

L["gift_opt_giftee_title"] = "Giftee"
L["gift_opt_giftee_form"] = "Giftee Selection"
L["gift_opt_giftee_form_select_desc"] = "If you select a giftee, only that player will be able to pick up and open the gift.\nThey'll also be pointed towards it!"
L["gift_opt_giftee_form_select"] = "Who's this gift for?"
L["gift_opt_giftee_form_any"] = "Anyone"
L["gift_opt_giftee_form_unident"] = "You can't select a giftee for an unidentified body gift."
L["gift_opt_unwrap_form"] = "Unwrap Effects"
L["gift_opt_unwrap_form_note"] = "Leave them a note!"

L["gift_status_rarity"] = "Rarity"
L["gift_status_rarity_common"] = "Common"
L["gift_status_rarity_uncommon"] = "Uncommon"
L["gift_status_rarity_rare"] = "Rare"
L["gift_status_rarity_very_rare"] = "Very Rare"
L["gift_status_rarity_super_rare"] = "Super Rare"
L["gift_status_rarity_legendary"] = "Legendary"
L["gift_status_rarity_mythical"] = "Mythical"
L["gift_status_quality"] = "Quality"
L["gift_status_type"] = "Category"
L["gift_status_fire"] = "On fire!"