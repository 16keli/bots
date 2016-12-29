local M = {}

-- Laning utilities -- but probably useful throughout the game lmao ---------------------

-- Determines the "probability" that this hero is being ganked. Larger rotations will result in larger values, so we can also use this to determine how many TP rotations are needed
-- Takes the range around self (1200) and time (3) as arguments
function M:beingGankedChance(range, time)
	local bot = GetBot();
	-- Nearby enemies, which we need for this function
	local nearby = bot:GetNearbyHeros(range, true, BOT_MODE_NONE);
	-- Check if they are advancing towards us or damaging us
	local advancingCount = 0;
	local damageCount = 0;
	for _,enemy in pairs(nearby) do
		-- Advancing
		-- I hope I'm doing this right lmao
		local vel = enemy:GetVelocity();
		local posdiff = enemy:GetLocation() - bot:GetLocation();
		local angle = math.acos(vel:Dot(posdiff) / (vel:Length() * posdiff:Length()));
		-- Check the angle between the two vectors using the definition of the dot product
		if (angle <= .5) then
			advancingCount = advancingCount + 1;
		end
		-- Damaging
		if (bot:WasRecentlyDamagedByHero(enemy, time)) then
			damageCount = damageCount + 1;
		end
	end
	local gankChance = (advancingCount + damageCount) / 10;
	-- Now add additional disables
	if (bot:IsHexed()) then
		gankChance = gankChance + .05;
	end
	if (bot:IsSilenced()) then
		gankChance = gankChance + .05;
	end
	if (bot:IsRooted()) then
		gankChance = gankChance + .05;
	end
	if (bot:IsStunned()) then
		gankChance = gankChance + .1;
	end
	return gankChance;
end

-- Checks whether we are being ganked
-- Takes same args as beingGankedChance()
function M:isBeingGanked(range, time)
	return M:beingGankedChance(range, time) >= .35;
end

-- Checks whether we are in danger of dying. Like the function name implies.
-- Specifically checks whether we were damanged recently, whether we're being ganked, and whether our HP or HP proportion is low.
function M:isInDangerOfDying(time)
	local npcBot = GetBot();
	return npcBot:TimeSinceDamagedByAnyHero() <= time and M:isBeingGanked() and ((npcBot:GetHealth() / npcBot:GetMaximumHealth()) <= .25 or (npcBot:GetHealth() <= 400));
end


-- Teamfight utilities -------------------------------------------------------------------

-- Checks whether there is a teamfight going on nearby by checking for the amount of allies attacking in a given range
function M:isTeamfightHappeningNearby(range)
	local npcBot = GetBot();
	local tableNearbyAttackingAlliedHeroes = npcBot:GetNearbyHeroes(range, false, BOT_MODE_ATTACK);
	return #tableNearbyAttackingAlliedHeroes >= 2;
end

-- Checks for the most dangerous enemy within a given range, using the specified damage type
function M:mostDangerousNearbyEnemy(range, damage)
	local npcBot = GetBot();
	local npcMostDangerousEnemy = nil;
	local nMostDangerousDamage = 0;
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(range, true, BOT_MODE_NONE);
	for _,npcEnemy in pairs(tableNearbyEnemyHeroes) do
		local nDamage = npcEnemy:GetEstimatedDamageToTarget(false, npcBot, 3.0, damage);
		if (nDamage > nMostDangerousDamage) then
			nMostDangerousDamage = nDamage;
			npcMostDangerousEnemy = npcEnemy;
		end
	end
end

-- Item utilities ------------------------------------------------------------------------

-- Retrieves the item in question or nil if the bot does not own it
function M:getItem(name)
	local npcBot = GetBot();
	if (M:hasItem(name)) then
		return npcBot:GetItemInSlot(M:getItemSlot(name));
	else
		return nil;
	end
end

-- Checks the slot this bot has this item in, and returns it or -1 if it does not have it
function M:getItemSlot(name)
	local npcBot = GetBot();
	for i = 0, 5 do
		if (npcBot:GetItemInSlot(i) ~= nil) then
			if (npcBot:GetItemInSlot(i):GetName() == name) then
				return i;
			end
		end
	end
	return -1;
end

-- Checks whether this bot owns this item
function M:hasItem(name)
	return M:getItemSlot(name) ~= -1;
end

-- General utilities ---------------------------------------------------------------------

-- Checks whether this unit is vulnerable to most spells and items
function M:isVulnerable(npcTarget)
	return M:isPiercingVulnerable(npcTarget) and not npcTarget:IsMagicImmune();
end

-- Checks whether this unit is vulnerable to spells and items that pierce magic immunity
function M:isPiercingVulnerable(npcTarget)
	return npcTarget:CanBeSeen() and not npcTarget:IsInvulnerable();
end

-- Gets the enemy team's enum
function M:getEnemyTeamEnum()
    if GetTeam() == TEAM_DIRE then
        return TEAM_RADIANT;
    else
        return TEAM_DIRE;
    end
end

-- Retrieves a table of enemy team members
function M:getEnemyTeamMembers()
	enemies = {};
	for i = 1, 5 do
		-- I hope the arguments are in the right order
		enemies[i] = GetTeamMember(M:getEnemyTeamEnum(), i);
	end
	return enemies;
end

-- Gets the number of visible enemy heroes
function M:getVisibleEnemyHeroes()
	local visible = 0;
	for _,enemy in pairs(M:getEnemyTeamMembers()) do
		if (enemy:CanBeSeen()) then
			visible = visible + 1;
		end
	end
	return visible;
end

-- Returns the "Danger Value" of this location
function M:getDangerAtLocation(location)
	local danger = 0;
	for _,enemy in pairs(M:getEnemyTeamMembers()) do
		if (not enemy:CanBeSeen()) then
			danger = danger + 1 + 1000 / (LocationToLocationDistance(location, enemy:GetLastSeenLocation())) + enemy:GetTimeSinceLastSeen() / 10;
		end
	end
	return danger;
end

-- Is this even Dota anymore ------------------------------------------------------------

function M:TableConcat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i];
    end
    return t1;
end

return M;