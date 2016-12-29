--Core Items required every single game
local tableCoreItems = {
  --Laning Items
  "item_tango",
  "item_null_talisman",
  --Early Items
  "item_boots",
  "item_ring_of_regen",
  "item_sobi_mask",
  "item_recipe_soul_ring",
  "item_soul_ring",
  "item_bottle",
  --Core Items
  "item_recipe_travel_boots",
  "item_travel_boots_1",
  "item_blink",
};

--Standard Tinker Items
local tableStandardItems = {
  --Aether Lens
  {
    "item_energy_booster",
    "item_ring_of_health",
    "item_recipe_aether_lens",
    "item_aether_lens",
  },
  --Aghs
  {
    "item_point_booster",
    "item_staff_of_wizardry",
    "item_ogre_axe",
    "item_blade_of_alacrity",
    "item_ultimate_scepter"
  },
  --Dagon 1-5
  {
    "item_staff_of_wizardry",
    "item_recipe_dagon",
    "item_dagon_1",
    "item_recipe_dagon",
    "item_dagon_2",
    "item_recipe_dagon",
    "item_dagon_3",
    "item_recipe_dagon",
    "item_dagon_4",
    "item_recipe_dagon",
    "item_dagon_5",
  },
  --EBlade
  {
    "item_ghost",
    "item_eagle",
    "item_ethereal_blade"
  },
  --Bloodstone
  {
    "item_energy_booster",
    "item_point_booster",
    "item_vitality_booster",
    "item_soul_booster",
    "item_recipe_bloodstone",
    "item_bloodstone",
  },
  --Hex
  {
    "item_ultimate_orb",
    "item_mystic_staff",
    "item_void_stone",
    "item_sheepstick"
  },
  --Shivas
  {
    "item_platemail",
    "item_mystic_staff",
    "item_recipe_shivas_guard",
    "item_shivas_guard",
  },
  --BoT2's
  {
    "item_recipe_travel_boots",
    "item_travel_boots_2",
  },
};

--Highly situational items
local tableSituationalItems = {
  --BKB
  {
    "item_ogre_axe",
    "item_mithril_hammer",
    "item_recipe_black_king_bar",
    "item_black_king_bar",
  },
  --Orchid
  {
    "item_sobi_mask",
    "item_robe",
    "item_quarterstaff",
    "item_sobi_mask",
    "item_robe",
    "item_quarterstaff",
    "item_recipe_orchid",
    "item_orchid",
  },
  --Critstick
  {
    "item_broadsword",
    "item_blades_of_attack",
    "item_recipe_lesser_crit",
    "item_lesser_crit",
  },
  --Bloodthorne
  {
    "item_recipe_bloodthorn",
    "item_bloodthorn",
  },
  --Eul's
  {
    "item_staff_of_wizardry",
    "item_wind_lace",
    "item_void_stone",
    "item_recipe_cyclone",
    "item_cyclone",
  },
  --Force Staff
  {
    "item_staff_of_wizardry",
    "item_ring_of_regen",
    "item_recipe_force_staff",
    "item_force_staff",
  },
  --Linken's
  {
    "item_ring_of_health",
    "item_void_stone",
    "item_ultimate_orb",
    "item_recipe_sphere",
    "item_sphere",
  },
  --Lotus
  {
    "item_ring_of_health",
    "item_void_stone",
    "item_platemail",
    "item_energy_booster",
  },
  --Manta
  {
    "item_blade_of_alacrity",
    "item_boots_of_elves",
    "item_recipe_yasha",
    "item_ultimate_orb",
    "item_recipe_manta",
    "item_manta",
  },
  --Octarine
  {
    "item_point_booster",
    "item_vitality_booster",
    "item_energy_booster",
    "item_mystic_staff",
  },
  --Greaves
  {
    "item_boots",
    "item_energy_booster",
    "item_ring_of_regen",
    "item_branches",
    "item_recipe_headdress",
    "item_platemail",
    "item_branches",
    "item_recipe_buckler",
    "item_recipe_mekansm",
    "item_recipe_guardian_greaves",
    "item_guardian_greaves",
  },
  --Necrobook
  {
    "item_staff_of_wizardry",
    "item_belt_of_strength",
    "item_recipe_necronomicon",
    "item_necronomicon_1",
    "item_recipe_necronomicon",
    "item_necronomicon_2",
    "item_recipe_necronomicon",
    "item_necronomicon_3",
  },
  --Shadow Blade
  {
    "item_claymore",
    "item_shadow_amulet",
  },

};


----------------------------------------------------------------------------------------------------

function ItemPurchaseThink()

  local npcBot = GetBot();
  --Ensure we have our core items bought first
  if (#tableCoreItems ~= 0) then
    --If we're in trouble, then buy out the cheapest items
    if (#GetNearbyHeros(1000, true, BOT_MODE_NONE) >= 2 and GetHealth()/GetMaxHealth() <= .2) then
      for i = 1,#tableCoreItems do --I hope this updates dynamically
        local nextItem = tableItemsToBuy[i];
        if (npcBot:GetGold() >= GetItemCost(nextItem)) then --Use all our unreliable so we don't lose gold. Volvo pls
          npcBot:SetNextItemPurchaseValue(GetItemCost(nextItem));
          npcBot:Action_PurchageItem(nextItem);
          table.remove(tableCoreItems, i);
        end
      end
    else

    end
  end
  if ( #tableItemsToBuy == 0 )
  then
    npcBot:SetNextItemPurchaseValue( 0 );
    return;
  end

  local sNextItem = tableItemsToBuy[1];

  npcBot:SetNextItemPurchaseValue( GetItemCost( sNextItem ) );

  if ( npcBot:GetGold() >= GetItemCost( sNextItem ) )
  then
    npcBot:Action_PurchaseItem( sNextItem );
    table.remove( tableItemsToBuy, 1 );
  end

end









----------------------------------------------------------------------------------------------------
