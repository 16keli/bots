--Init stuff here
local util = require(GetScriptDirectory().."/util");

----------------------------------------------------------------------------------------------------

castLaserDesire = 0;
castMissilesDesire = 0;
castMarchDesire = 0;
castRearmDesire = 0;

function AbilityUsageThink()

	local npcBot = GetBot();

	-- Check if we're already using an ability
	if (npcBot:IsUsingAbility() or isRearming()) then return end;
	
	abilityLaser = npcBot:GetAbilityByName("tinker_laser");
	abilityMissiles = npcBot:GetAbilityByName("tinker_heat_seeking_missile");
	abilityMarch = npcBot:GetAbilityByName("tinker_march_of_the_machines");
	abilityRearm = npcBot:GetAbilityByName("tinker_rearm");

	-- Consider using each ability
	castLaserDesire, castLaserTarget = considerLaser();
	castMissilesDesire = considerMissiles();
	castMarchDesire, castMarchLocation = considerMarch();
	castRearmDesire = considerRearm();
	
	-- Cast missiles first cuz of the 0 cast time
	if (castMissilesDesire > 0) then
		if (not abilityMissiles:IsCooldownReady()) then
			castRearmDesire = castRearmDesire + .05;
		else
			considerSoulRing();
			npcBot:Action_UseAbility(abilityMissiles);
		end
	end
	
	-- Then laser and march
	if (castLaserDesire > 0) then
		if (not abilityLaser:IsCooldownReady()) then
			castRearmDesire = castRearmDesire + .05;
		else
			considerSoulRing();
			npcBot:Action_UseAbilityOnEntity(abilityLaser, castLaserTarget);
		end
	end
	
	if (castMarchDesire > 0) then
		if (not abilityMarch:IsCooldownReady()) then
			castRearmDesire = castRearmDesire + .05;
		else
			considerSoulRing();
			npcBot:Action_UseAbilityOnLocation(abilityMarch, castMarchLocation);
		end
	end
	
	-- Do not waste rearm!
	if (castRearmDesire > castLaserDesire and castRearmDesire > castMarchDesire and castRearmDesire > BOT_ACTION_DESIRE_LOW) then
		considerSoulRing();
		npcBot:Action_UseAbility(abilityRearm);
		lastRearm = GameTime();
		npcBot:Action_Chat("Last rearm time was "..lastRearm, false);
	end
end

-- Ability utilities ------------------------------------------------------------------------------

function isRearming() 
  return GetBot():HasModifier("tinker_rearm");
end

-- Checks if we can laser this target to blind him by returning the unit to laser to do it or nil if we cannot
function canBlindTarget(npcTarget)
	-- Unsure about this check. Perhaps it becomes less relevant with Aghs, as the bounce does so much anyways
	if (npcTarget:IsUnableToMiss()) then
		return nil;
	end
	local npcBot = GetBot();
	local castRange = abilityLaser:GetCastRange();
	local castPoint = abilityLaser:GetCastPoint();
	-- Simple, aghs-independent blinding is just a simple check
	if (GetUnitToUnitDistance(npcBot, npcTarget) <= castRange) then
		return npcTarget;
	end
	if (npcBot:HasScepter()) then
		-- This is really complicated with aghs... We could implement something like A* but that might kill Valve's servers or something
		local bounceRange = abilityLaser:GetSpecialValueInt("cast_range_scepter");
		-- First check initial targets, which include both creeps and heroes
		local initialTargets = util:TableConcat(GetNearbyHeroes(castRange, true, BOT_MODE_NONE), GetNearbyCreeps(castRange, true));
		-- Check for the minimum distance to give ourselves the highest chance of ensuring the bounce because cast point is stupid at .4 seconds
		local minDist = bounceRange;
		local minTarget = nil;
		for _,enemy in pairs(initialTargets) do
			-- We only perform checks for one jump cuz I'm lazy af
			local dist = GetUnitToUnitDistance(enemy, npcTarget);
			if (dist < minDist) then
				minDist = dist;
				minTarget = enemy;
			end
		end
		if (minDist >= bounceRange) then
			return minTarget;
		end
	end
	return nil;
end

-- Gets the location to cast march on in order to zone enemies the best, or nil if not applicable
function getMarchZoningLocation()
	local npcBot = GetBot();
	-- Get some of its values
	local castRange = abilityMarch:GetCastRange();
	local range = abilityMarch:GetSpecialValueInt("distance") / 2;
	-- Get all enemies within radius of Tinker
	local nearbyEnemies = npcBot:GetNearbyHeroes(castRange + range, true, BOT_MODE_NONE);
	local centerVector = Vector(0, 0);
	if (#nearbyEnemies ~= 0) then
		-- Sum the relative vectors to get an average relative vector
		for _,enemy in pairs(nearbyEnemies) do
			centerVector = centerVector + (enemy:GetLocation() - npcBot:GetLocation()) + 2 * enemy:GetVelocity();
		end
		local norm = centerVector:Normalized();
		local targetVector = Vector(norm.x * castRange, norm.y * castRange);
		DebugDrawLine(npcBot:GetLocation(), npcBot:GetLocation() + targetVector, 255, 0, 0);
		return npcBot:GetLocation() + targetVector;
	else
		return nil;
	end
end

-- Gets the location to cast march on in order to farm creeps the best, or nil if not applicable, as well as the number of creeps nearby
function getMarchFarmingLocation()
	local npcBot = GetBot();
	-- Get some of its values
	local castRange = abilityMarch:GetCastRange();
	local range = abilityMarch:GetSpecialValueInt("distance") / 2;
	-- Get all enemies within radius of Tinker
	local nearbyEnemies = npcBot:GetNearbyCreeps(castRange + range, true);
	local centerVector = Vector(0, 0);
	if (#nearbyEnemies ~= 0) then
		-- Sum the relative vectors to get an average relative vector
		for _,enemy in pairs(nearbyEnemies) do
			centerVector = centerVector + (enemy:GetLocation() - npcBot:GetLocation()) + 2 * enemy:GetVelocity();
		end
		local norm = centerVector:Normalized();
		local targetVector = Vector(norm.x * castRange, norm.y * castRange);
		DebugDrawLine(npcBot:GetLocation(), npcBot:GetLocation() + targetVector, 255, 0, 0);
		return #nearbyEnemies, npcBot:GetLocation() + targetVector;
	else
		return 0, nil;
	end
end


-- Ability casting considerations ----------------------------------------------------------------------------
-- General consideration for casting Tinker's laser
function considerLaser()

	local npcBot = GetBot();

	local castRange = abilityLaser:GetCastRange();
	local damage = npcBot:GetActualDamage(abilityLaser:GetSpecialValueFloat("laser_damage"), DAMAGE_TYPE_PURE);
	

	--------------------------------------
	-- Global high-priorty usage
	--------------------------------------

	-- Save self or allies from enemies with high physical damage output or do massive damage in a teamfight
	-- TODO add maybe a saving team consideration
	if (util:isTeamfightHappeningNearby(1200)) then
		-- Save allies and stuff
		local dangerousEnemy = util:mostDangerousNearbyEnemy(1200, DAMAGE_TYPE_PHYSICAL);
		if (dangerousEnemy ~= nil) then
			local targetEnemy = canBlindTarget(dangerousEnemy);
			if (targetEnemy ~= nil) then
				npcBot:Action_Chat("I'll save you!", false);
				return BOT_ACTION_DESIRE_HIGH, targetEnemy;
			end
		end
	end
	
	-- Finish off low HP targets
	local nearbyEnemies = npcBot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE);
	for _,enemy in pairs(nearbyEnemies) do
		-- Check if we can combo with missiles
		if (abilityMissiles:IsFullyCastable()) then
			damage = damage + npcBot:GetActualDamage(abilityMissiles:GetAbilityDamage(), DAMAGE_TYPE_MAGICAL);
		end
		-- Then do the damage
		if (enemy:GetHealth() < damage) then
			npcBot:Action_Chat("Pew pew pew!", true);
			return BOT_ACTION_DESIRE_HIGH, enemy;
		end
	end
	

	--------------------------------------
	-- Mode based usage
	--------------------------------------

	-- If we're farming, in a dangerous area, and can kill a creep with laser
	if (npcBot:GetActiveMode() == BOT_MODE_FARM) then
		local nearbyCreeps = npcBot:GetNearbyCreeps(castRange, true);
		for _,creep in pairs(nearbyCreeps) do
			if (creep:GetHealth() <= damage) then
				return BOT_ACTION_DESIRE_LOW, creep;
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0;
end

----------------------------------------------------------------------------------------------------

-- General consideration for casting Tinker's "heat seaking" missiles
function considerMissiles()

	local npcBot = GetBot();

	-- Get some of its values
	local castRange = 1600;
	local damage = npcBot:GetActualDamage(abilityMissiles:GetAbilityDamage(), DAMAGE_TYPE_MAGICAL);

	--------------------------------------
	-- Global high-priorty usage
	--------------------------------------

	-- We only really use these if we're teamfighting or to get kills
	-- If we can finish off an enemy with these, then fire!
	local validTargets = 0;
	local nearbyEnemies = npcBot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE);
	if (#nearbyEnemies > 0) then
		for _,enemy in pairs(nearbyEnemies) do
			-- TODO account for HP Regen and missile travel time? That may be a bit much
			if (util:isVulnerable(enemy)) then
				if (enemy:GetHealth() <= damage * .9) then
					npcBot:Action_Chat("KS Time!", true);
					return BOT_ACTION_DESIRE_HIGH;
				end
				validTargets = validTargets + 1;
			end
		end
		-- Otherwise, check how many we can hit right now
		if (npcBot:HasScepter()) then
			if (validTargets >= 3) then
				npcBot:Action_Chat("I see you!", true);
				return BOT_ACTION_DESIRE_MODERATE;
			end
		else
			if (validTargets >= 2) then
				npcBot:Action_Chat("I see you!", true);
				return BOT_ACTION_DESIRE_MODERATE;
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE;

end


----------------------------------------------------------------------------------------------------

-- General consideration for casting Tinker's March of the Machines
function considerMarch()

	local npcBot = GetBot();

	-- Make sure it's castable
	if (not abilityMarch:IsFullyCastable()) then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	--------------------------------------
	-- Global high-priorty usage
	--------------------------------------
	
	-- If there's a teamfight, cast march such that the machines will cut off the enemy. This will have to take into consideration map bounds, relative location, and all that fun stuff
	if (util:isTeamfightHappeningNearby(1200)) then
		local zoningLocation = getMarchZoningLocation();
		if (zoningLocation ~= nil) then
			npcBot:Action_Chat("Marching to zone", false);
			return BOT_ACTION_DESIRE_MODERATE, zoningLocation;
		end
	end
	
	--------------------------------------
	-- Mode based usage
	--------------------------------------
	
	-- If we're farming or pushing, then we also want to march to help out
	if (npcBot:GetActiveMode() == BOT_MODE_FARM or
		npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP or
		npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID or
		npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOTTOM or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_MID or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOTTOM) then
		local creepCount, farmingLocation = getMarchFarmingLocation();
		if (creepCount >= 3) then
			npcBot:Action_Chat("Marching to farm", false);
			return BOT_ACTION_DESIRE_LOW, farmingLocation;
		else
			return BOT_ACTION_DESIRE_NONE, 0;
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0;

end

-- General consideration for casting Tinker's Rearm
function considerRearm()
	-- Prevent the fateful multi-rearm by accounting for the cast point of rearm
	if (lastRearm ~= nil) then
		npcBot:Action_Chat("Attempting rearm at "..GameTime());
		if ((GameTime() - lastRearm) < (abilityRearm:GetChannelTime() + abilityRearm:GetCastPoint() + .05)) then
			return BOT_ACTION_DESIRE_NONE;
		end
	end
	local rearmDesire = 0;
	local npcBot = GetBot();
	for i = 0, 5 do
		local item = npcBot:GetItemInSlot(i);
		if (item ~= nil) then
			if (not item:IsCooldownReady()) then
				rearmDesire = rearmDesire + item:GetCooldownTimeRemaining() / 30;
			end
		end
	end
	if (not abilityLaser:IsCooldownReady()) then
		rearmDesire = rearmDesire + abilityLaser:GetCooldownTimeRemaining() / 14;
	end
	if (not abilityMissiles:IsCooldownReady()) then
		rearmDesire = rearmDesire + abilityMissiles:GetCooldownTimeRemaining() / 25;
	end
	if (not abilityMarch:IsCooldownReady()) then
		rearmDesire = rearmDesire + abilityMarch:GetCooldownTimeRemaining() / 35;
	end
	return rearmDesire / 10 + .1;
end

function considerSoulRing()
	local npcBot = GetBot();
	local soulRing = util:getItem("item_soul_ring");
	if (soulRing ~= nil and soulRing:IsFullyCastable() and npcBot:GetHealth() / npcBot:GetMaxHealth() > .4) then
		npcBot:Action_UseAbility(soulRing);
	end
end

