--Init stuff here
local util = require(GetScriptDirectory().."/util");


----------------------------------------------------------------------------------------------------

castLBDesire = 0;
castLSADesire = 0;
castDSDesire = 0;

function AbilityUsageThink()

	local npcBot = GetBot();

	-- Check if we're already using an ability
	if ( npcBot:IsUsingAbility() ) then return end;
	
	abilityLaser = npcBot:GetAbilityByName("tinker_laser");
	abilityMissiles = npcBot:GetAbilityByName("tinker_heat_seaking_missile");
	abilityMarch = npcBot:GetAbilityByName("tinker_march_of_the_machines");
	abilityRearm = npcBot:GetAbilityByName("tinker_rearm");

	-- Consider using each ability
	castLBDesire, castLBTarget = ConsiderLagunaBlade();
	castLSADesire, castLSALocation = ConsiderLightStrikeArray();
	castDSDesire, castDSLocation = ConsiderDragonSlave();

	if ( castLBDesire > castLSADesire and castLBDesire > castDSDesire ) 
	then
		npcBot:Action_UseAbilityOnEntity( abilityLB, castLBTarget );
		return;
	end

	if ( castLSADesire > 0 ) 
	then
		npcBot:Action_UseAbilityOnLocation( abilityLSA, castLSALocation );
		return;
	end

	if ( castDSDesire > 0 ) 
	then
		npcBot:Action_UseAbilityOnLocation( abilityDS, castDSLocation );
		return;
	end

end

-- Ability utilities ------------------------------------------------------------------------------

function isRearming() 
  return GetBot():HasModifier("tinker_rearm");
end

-- Checks if we can laser this target to blind him by returning the unit to laser to do it or nil if we cannot
function canBlindTarget(npcTarget)
	if (npcTarget:IsUnableToMiss()) then
		return nil;
	end
	local npcBot = GetBot();
	local castRange = abilityLaser:GetCastRange();
	local castPoint = abilityLaser:GetCastPoint();
	-- Simple, aghs-independent blinding is just a simple check
	if (UnitToLocationDistance(npcBot, npcTarget:GetExtrapolatedPosition(castPoint)) <= castRange) then
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
			local dist = UnitToLocationDistance(enemy, npcTarget:GetExtrapolatedPosition(castPoint));
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


----------------------------------------------------------------------------------------------------

function considerLaser()

	local npcBot = GetBot();

	-- Make sure it's castable
	if (not abilityLaser:IsFullyCastable()) then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end;

	local nCastRange = abilityLaser:GetCastRange();
	local nDamage = abilityLaser:GetAbilityDamage();

	--------------------------------------
	-- Global high-priorty usage
	--------------------------------------

	-- Save self or allies from enemies with high physical damage output or do massive damage in a teamfight
	-- TODO add maybe a saving team consideration
	if (util:isTeamfightHappeningNearby(1200)) then
		local dangerousEnemy = util:mostDangerousNearbyEnemy(1200, DAMAGE_TYPE_PHYSICAL);
		if (dangerousEnemy ~= nil) then
			local targetEnemy = canBlindTarget(dangerousEnemy);
			if (targetEnemy ~= nil) then
				return BOT_ACTION_DESIRE_HIGH, targetEnemy;
			end
		end
	end
	

	--------------------------------------
	-- Mode based usage
	--------------------------------------

	-- If we're farming and can kill 3+ creeps with LSA
	if ( npcBot:GetActiveMode() == BOT_MODE_FARM ) then
		local locationAoE = npcBot:FindAoELocation( true, false, npcBot:GetLocation(), nCastRange, nRadius, 0, nDamage );

		if ( locationAoE.count >= 3 ) then
			return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
		end
	end

	-- If we're pushing or defending a lane and can hit 4+ creeps, go for it
	if ( npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP or
		 npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID or
		 npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOTTOM or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_MID or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOTTOM ) 
	then
		local locationAoE = npcBot:FindAoELocation( true, false, npcBot:GetLocation(), nCastRange, nRadius, 0, 0 );

		if ( locationAoE.count >= 4 ) 
		then
			return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
		end
	end

	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if ( npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH ) 
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange + nRadius + 200, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) ) 
			then
				if ( CanCastLightStrikeArrayOnTarget( npcEnemy ) ) 
				then
					return BOT_ACTION_DESIRE_MODERATE, npcEnemy:GetLocation();
				end
			end
		end
	end

	-- If we're going after someone
	if ( npcBot:GetActiveMode() == BOT_MODE_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_GANK or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY ) 
	then
		local npcTarget = npcBot:GetTarget();

		if ( npcTarget ~= nil ) 
		then
			if ( CanCastLightStrikeArrayOnTarget( npcTarget ) )
			then
				return BOT_ACTION_DESIRE_HIGH, npcTarget:GetLocation();
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0;
end

----------------------------------------------------------------------------------------------------

function considerMissiles()

	local npcBot = GetBot();

	-- Make sure it's castable
	if ( not abilityDS:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end;

	-- If we want to cast Laguna Blade at all, bail
	if ( castLBDesire > 0 ) then
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	-- Get some of its values
	local nRadius = abilityDS:GetSpecialValueInt( "dragon_slave_width_end" );
	local nCastRange = abilityDS:GetCastRange();
	local nDamage = abilityDS:GetAbilityDamage();

	--------------------------------------
	-- Mode based usage
	--------------------------------------

	-- If we're farming and can kill 3+ creeps with LSA
	if ( npcBot:GetActiveMode() == BOT_MODE_FARM ) then
		local locationAoE = npcBot:FindAoELocation( true, false, npcBot:GetLocation(), nCastRange, nRadius, 0, nDamage );

		if ( locationAoE.count >= 3 ) then
			return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
		end
	end

	-- If we're pushing or defending a lane and can hit 4+ creeps, go for it
	if ( npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP or
		 npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID or
		 npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOTTOM or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_MID or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOTTOM ) 
	then
		local locationAoE = npcBot:FindAoELocation( true, false, npcBot:GetLocation(), nCastRange, nRadius, 0, 0 );

		if ( locationAoE.count >= 4 ) 
		then
			return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
		end
	end

	-- If we're going after someone
	if ( npcBot:GetActiveMode() == BOT_MODE_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_GANK or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY ) 
	then
		local npcTarget = npcBot:GetTarget();

		if ( npcTarget ~= nil ) 
		then
			if ( CanCastDragonSlaveOnTarget( npcTarget ) )
			then
				return BOT_ACTION_DESIRE_MODERATE, npcEnemy:GetLocation();
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0;

end


----------------------------------------------------------------------------------------------------

function considerMarch()

	local npcBot = GetBot();

	-- Make sure it's castable
	if ( not abilityLB:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	-- Get some of its values
	local nCastRange = abilityLB:GetCastRange();
	local nDamage = abilityDS:GetSpecialValueInt( "damage" );
	local eDamageType = npcBot:HasScepter() and DAMAGE_TYPE_PURE or DAMAGE_TYPE_MAGICAL;

	-- If a mode has set a target, and we can kill them, do it
	local npcTarget = npcBot:GetTarget();
	if ( npcTarget ~= nil and CanCastLagunaBladeOnTarget( npcTarget ) )
	then
		if ( npcTarget:GetActualDamage( nDamage, eDamageType ) > npcTarget:GetHealth() and UnitToUnitDistance( npcTarget, npcBot ) < ( nCastRange + 200 ) )
		then
			return BOT_ACTION_DESIRE_HIGH, npcTarget;
		end
	end

	-- If we're in a teamfight, use it on the scariest enemy
	local tableNearbyAttackingAlliedHeroes = npcBot:GetNearbyHeroes( 1000, false, BOT_MODE_ATTACK );
	if (#tableNearbyAttackingAlliedHeroes >= 2) then
		local npcMostDangerousEnemy = nil;
		local nMostDangerousDamage = 0;

		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( CanCastLagunaBladeOnTarget( npcEnemy ) )
			then
				local nDamage = npcEnemy:GetEstimatedDamageToTarget( false, npcBot, 3.0, DAMAGE_TYPE_ALL );
				if ( nDamage > nMostDangerousDamage )
				then
					nMostDangerousDamage = nDamage;
					npcMostDangerousEnemy = npcEnemy;
				end
			end
		end

		if ( npcMostDangerousEnemy ~= nil )
		then
			return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy;
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0;

end

function considerRearm()

end

