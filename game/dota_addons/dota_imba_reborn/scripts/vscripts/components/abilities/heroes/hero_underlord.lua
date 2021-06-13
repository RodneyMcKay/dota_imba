-- Created by Elfansoer
-- IMBAfication by EarthSalamander. Date 13/06/2021
--------------------------------------------------------------------------------
imba_abyssal_underlord_firestorm = imba_abyssal_underlord_firestorm or class({})
LinkLuaModifier( "modifier_imba_abyssal_underlord_firestorm", "components/abilities/heroes/hero_underlord", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_imba_abyssal_underlord_firestorm_thinker", "components/abilities/heroes/hero_underlord", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_imba_abyssal_underlord_blizzard", "components/abilities/heroes/hero_underlord", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Custom KV
-- AOE Radius
function imba_abyssal_underlord_firestorm:GetAOERadius()
	return self:GetVanillaAbilitySpecial( "radius" )
end

--------------------------------------------------------------------------------
-- Ability Phase Start
function imba_abyssal_underlord_firestorm:OnAbilityPhaseStart()
	local point = self:GetCursorPosition()

	self:PlayEffects( point )

	return true -- if success
end

function imba_abyssal_underlord_firestorm:OnAbilityPhaseInterrupted()
	self:StopEffects()
end

--------------------------------------------------------------------------------
-- Ability Start
function imba_abyssal_underlord_firestorm:OnSpellStart()
	if not IsServer() then return end

	self:StopEffects()

	-- unit identifier
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()

	-- create thinker
	CreateModifierThinker(
		caster, -- player source
		self, -- ability source
		"modifier_imba_abyssal_underlord_firestorm_thinker", -- modifier name
		{}, -- kv
		point,
		caster:GetTeamNumber(),
		false
	)
end

--------------------------------------------------------------------------------
function imba_abyssal_underlord_firestorm:PlayEffects( point )
	-- Get Resources
	local particle_cast = "particles/units/heroes/heroes_underlord/underlord_firestorm_pre.vpcf"
	local sound_cast = "Hero_AbyssalUnderlord.Firestorm.Start"

	-- get data
	local radius = self:GetVanillaAbilitySpecial( "radius" )

	-- Create Particle
	self.effect_cast = ParticleManager:CreateParticleForTeam( particle_cast, PATTACH_WORLDORIGIN, self:GetCaster(), self:GetCaster():GetTeamNumber() )
	ParticleManager:SetParticleControl( self.effect_cast, 0, point )
	ParticleManager:SetParticleControl( self.effect_cast, 1, Vector( 2, 2, 2 ) )

	-- Create Sound
	EmitSoundOnLocationWithCaster( point, sound_cast, self:GetCaster() )
end

function imba_abyssal_underlord_firestorm:StopEffects()
	ParticleManager:DestroyParticle( self.effect_cast, true )
	ParticleManager:ReleaseParticleIndex( self.effect_cast )
end

--------------------------------------------------------------------------------

modifier_imba_abyssal_underlord_firestorm_thinker = modifier_imba_abyssal_underlord_firestorm_thinker or class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_imba_abyssal_underlord_firestorm_thinker:IsHidden()
	return true
end

function modifier_imba_abyssal_underlord_firestorm_thinker:IsPurgable()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_imba_abyssal_underlord_firestorm_thinker:OnCreated( kv )
	self.caster = self:GetCaster()
	self.parent = self:GetParent()
	self.ability = self:GetAbility()

	-- references
	local damage = self.ability:GetVanillaAbilitySpecial( "wave_damage" )
	local delay = self.ability:GetVanillaAbilitySpecial( "first_wave_delay" )
	self.radius = self.ability:GetVanillaAbilitySpecial( "radius" )
	self.count = self.ability:GetVanillaAbilitySpecial( "wave_count" )
	self.interval = self.ability:GetVanillaAbilitySpecial( "wave_interval" )

	self.burn_duration = self.ability:GetVanillaAbilitySpecial( "burn_duration" )

	if not IsServer() then return end

	self.autocast_state = self.ability:GetAutoCastState()

	-- init
	self.wave = 0
	self.damageTable = {
		-- victim = target,
		attacker = self.caster,
		damage = damage,
		damage_type = self.ability:GetAbilityDamageType(),
		ability = self.ability, --Optional.
	}
	-- ApplyDamage(damageTable)

	-- Start interval
	self:StartIntervalThink( delay )
end

function modifier_imba_abyssal_underlord_firestorm_thinker:OnRefresh( kv )
	
end

function modifier_imba_abyssal_underlord_firestorm_thinker:OnRemoved()
end

function modifier_imba_abyssal_underlord_firestorm_thinker:OnDestroy()
	if not IsServer() then return end
	UTIL_Remove( self:GetParent() )
end

--------------------------------------------------------------------------------
-- Interval Effects
function modifier_imba_abyssal_underlord_firestorm_thinker:OnIntervalThink()
	if not self.delayed then
		self.delayed = true
		self:StartIntervalThink( self.interval )
		self:OnIntervalThink()
		return
	end

	-- find enemies
	local enemies = FindUnitsInRadius(
		self.caster:GetTeamNumber(),	-- int, your team number
		self.parent:GetOrigin(),	-- point, center point
		nil,	-- handle, cacheUnit. (not known)
		self.radius,	-- float, radius. or use FIND_UNITS_EVERYWHERE
		DOTA_UNIT_TARGET_TEAM_ENEMY,	-- int, team filter
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,	-- int, type filter
		0,	-- int, flag filter
		0,	-- int, order filter
		false	-- bool, can grow cache
	)

	for _,enemy in pairs(enemies) do
		-- damage
		self.damageTable.victim = enemy
		ApplyDamage( self.damageTable )

		local modifier_name = "modifier_imba_abyssal_underlord_firestorm"

		-- IMBAfication: Blizzard
		if self.autocast_state then
			modifier_name = "modifier_imba_abyssal_underlord_blizzard"
		end

--		local has_modifier = enemy:HasModifier(modifier_name)

		-- add debuff
		local modifier = enemy:AddNewModifier(
			self.caster, -- player source
			self.ability, -- ability source
			modifier_name, -- modifier name
			{
				duration = self.burn_duration,
			} -- kv
		)

		-- apply 1 stack on first hit?
--		if has_modifier == false then
--			modifier:SetStackCount(1)
--		end
	end

	-- play effects
	self:PlayEffects()

	-- count wave
	self.wave = self.wave + 1
	if self.wave>=self.count then
		self:Destroy()
	end
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_imba_abyssal_underlord_firestorm_thinker:PlayEffects()
	-- Get Resources
	local particle_cast = "particles/units/heroes/heroes_underlord/abyssal_underlord_firestorm_wave.vpcf"
	local sound_cast = "Hero_AbyssalUnderlord.Firestorm"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_WORLDORIGIN, nil )
	ParticleManager:SetParticleControl( effect_cast, 0, self.parent:GetOrigin() )
	ParticleManager:SetParticleControl( effect_cast, 4, Vector( self.radius, 0, 0 ) )
	ParticleManager:ReleaseParticleIndex( effect_cast )

	-- Create Sound
	EmitSoundOn( sound_cast, self.parent )
end

--------------------------------------------------------------------------------

modifier_imba_abyssal_underlord_firestorm = modifier_imba_abyssal_underlord_firestorm or class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_imba_abyssal_underlord_firestorm:IsHidden()
	return false
end

function modifier_imba_abyssal_underlord_firestorm:IsDebuff()
	return true
end

function modifier_imba_abyssal_underlord_firestorm:IsStunDebuff()
	return false
end

function modifier_imba_abyssal_underlord_firestorm:IsPurgable()
	return true
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_imba_abyssal_underlord_firestorm:OnCreated( kv )
	-- references
	if not IsServer() then return end
	self.damage_pct = (self:GetAbility():GetVanillaAbilitySpecial("burn_damage") + (self:GetAbility():GetSpecialValueFor("burn_damage_stack") * self:GetStackCount())) / 100

	print("Damage pct:", self.damage_pct)

	-- precache damage
	self.damageTable = {
		victim = self:GetParent(),
		attacker = self:GetCaster(),
		-- damage = damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self:GetAbility(), --Optional.
	}
	-- ApplyDamage(damageTable)

	-- Start interval
	self:StartIntervalThink(self:GetAbility():GetVanillaAbilitySpecial( "burn_interval" ))
end

function modifier_imba_abyssal_underlord_firestorm:OnRefresh( kv )
	if not IsServer() then return end

	self:IncrementStackCount()
	self.damage_pct = (self:GetAbility():GetVanillaAbilitySpecial("burn_damage") + (self:GetAbility():GetSpecialValueFor("burn_damage_stack") * self:GetStackCount())) / 100
	print("Damage pct:", self.damage_pct)
end

function modifier_imba_abyssal_underlord_firestorm:OnStackCountChanged(iStackCount)
	if not IsServer() then return end

	self.damage_pct = (self:GetAbility():GetVanillaAbilitySpecial("burn_damage") + (self:GetAbility():GetSpecialValueFor("burn_damage_stack") * self:GetStackCount())) / 100
	print("Damage pct:", self.damage_pct)
end

function modifier_imba_abyssal_underlord_firestorm:OnRemoved()
end

function modifier_imba_abyssal_underlord_firestorm:OnDestroy()
end

--------------------------------------------------------------------------------
-- Interval Effects
function modifier_imba_abyssal_underlord_firestorm:OnIntervalThink()
	-- check health
	local damage = self:GetParent():GetMaxHealth() * self.damage_pct

	-- apply damage
	self.damageTable.damage = damage
	ApplyDamage( self.damageTable )
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_imba_abyssal_underlord_firestorm:GetEffectName()
	return "particles/units/heroes/heroes_underlord/abyssal_underlord_firestorm_wave_burn.vpcf"
end

function modifier_imba_abyssal_underlord_firestorm:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

--------------------------------------------------------------------------------

modifier_imba_abyssal_underlord_blizzard = modifier_imba_abyssal_underlord_blizzard or class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_imba_abyssal_underlord_blizzard:IsHidden()
	return false
end

function modifier_imba_abyssal_underlord_blizzard:IsDebuff()
	return true
end

function modifier_imba_abyssal_underlord_blizzard:IsStunDebuff()
	return false
end

function modifier_imba_abyssal_underlord_blizzard:IsPurgable()
	return true
end

function modifier_imba_abyssal_underlord_blizzard:DeclareFunctions() return {
	MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE
} end

--------------------------------------------------------------------------------
-- Initializations
function modifier_imba_abyssal_underlord_blizzard:OnCreated( kv )
	-- references
	self.slow = self:GetAbility():GetSpecialValueFor("blizzard_slow_percentage")

	if not IsServer() then return end
	self.damage_pct = self:GetAbility():GetVanillaAbilitySpecial("burn_damage") / 100

	-- precache damage
	self.damageTable = {
		victim = self:GetParent(),
		attacker = self:GetCaster(),
		-- damage = damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self:GetAbility(), --Optional.
	}
	-- ApplyDamage(damageTable)
end

function modifier_imba_abyssal_underlord_blizzard:OnRefresh( kv )
	if not IsServer() then return end

	self:IncrementStackCount()
	self.damage_pct = self:GetAbility():GetVanillaAbilitySpecial("burn_damage") / 100
	self.slow = self:GetAbility():GetSpecialValueFor("blizzard_slow_percentage") + (self:GetAbility():GetSpecialValueFor("blizzard_slow_percentage_stack") * self:GetStackCount())
end

function modifier_imba_abyssal_underlord_blizzard:OnRemoved()
end

function modifier_imba_abyssal_underlord_blizzard:OnDestroy()
end

function modifier_imba_abyssal_underlord_blizzard:GetModifierMoveSpeedBonus_Percentage()
	print(self.slow * (-1))
	return self.slow * (-1)
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_imba_abyssal_underlord_blizzard:GetEffectName()
	return "particles/econ/courier/courier_wyvern_hatchling/courier_wyvern_hatchling_ice.vpcf"
end

function modifier_imba_abyssal_underlord_blizzard:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

--------------------------------------------------------------------------------
imba_abyssal_underlord_pit_of_malice = imba_abyssal_underlord_pit_of_malice or class({})
LinkLuaModifier( "modifier_imba_abyssal_underlord_pit_of_malice", "components/abilities/heroes/hero_underlord", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_imba_abyssal_underlord_pit_of_malice_cooldown", "components/abilities/heroes/hero_underlord", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_imba_abyssal_underlord_pit_of_malice_thinker", "components/abilities/heroes/hero_underlord", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Custom KV
-- AOE Radius
function imba_abyssal_underlord_pit_of_malice:GetAOERadius()
	return self:GetVanillaAbilitySpecial( "radius" )
end

--------------------------------------------------------------------------------
-- Ability Phase Start
function imba_abyssal_underlord_pit_of_malice:OnAbilityPhaseStart()
	-- create effects
	local point = self:GetCursorPosition()
	self:PlayEffects( point )

	return true -- if success
end
function imba_abyssal_underlord_pit_of_malice:OnAbilityPhaseInterrupted()
	-- kill effect
	ParticleManager:DestroyParticle( self.effect_cast, true )
	ParticleManager:ReleaseParticleIndex( self.effect_cast )

end

--------------------------------------------------------------------------------
-- Ability Start
function imba_abyssal_underlord_pit_of_malice:OnSpellStart()
	if not IsServer() then return end

	-- release cast effect
	ParticleManager:ReleaseParticleIndex( self.effect_cast )

	-- unit identifier
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()

	-- load data
	local duration = self:GetVanillaAbilitySpecial( "pit_duration" )

	-- create thinker
	CreateModifierThinker(
		caster, -- player source
		self, -- ability source
		"modifier_imba_abyssal_underlord_pit_of_malice_thinker", -- modifier name
		{ duration = duration }, -- kv
		point,
		caster:GetTeamNumber(),
		false
	)

end

--------------------------------------------------------------------------------
function imba_abyssal_underlord_pit_of_malice:PlayEffects( point )
	-- Get Resources
	local particle_cast = "particles/units/heroes/heroes_underlord/underlord_pitofmalice_pre.vpcf"
	local sound_cast = "Hero_AbyssalUnderlord.PitOfMalice.Start"

	-- Get Data
	local radius = self:GetVanillaAbilitySpecial( "radius" )

	-- Create Particle
	self.effect_cast = ParticleManager:CreateParticleForTeam( particle_cast, PATTACH_WORLDORIGIN, self:GetCaster(), self:GetCaster():GetTeamNumber() )
	ParticleManager:SetParticleControl( self.effect_cast, 0, point )
	ParticleManager:SetParticleControl( self.effect_cast, 1, Vector( radius, 1, 1 ) )
	-- ParticleManager:ReleaseParticleIndex( effect_cast )

	-- Create Sound
	EmitSoundOnLocationForAllies( point, sound_cast, self:GetCaster() )
end

--------------------------------------------------------------------------------
modifier_imba_abyssal_underlord_pit_of_malice_thinker = modifier_imba_abyssal_underlord_pit_of_malice_thinker or class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_imba_abyssal_underlord_pit_of_malice_thinker:IsHidden()
	return false
end

function modifier_imba_abyssal_underlord_pit_of_malice_thinker:IsDebuff()
	return false
end

function modifier_imba_abyssal_underlord_pit_of_malice_thinker:IsPurgable()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_imba_abyssal_underlord_pit_of_malice_thinker:OnCreated( kv )
	-- references
	self.radius = self:GetAbility():GetVanillaAbilitySpecial( "radius" )
	self.pit_damage = self:GetAbility():GetVanillaAbilitySpecial( "pit_damage" )
	self.duration = self:GetAbility():GetVanillaAbilitySpecial( "ensnare_duration" )

	if not IsServer() then return end
	self.caster = self:GetCaster()
	self.parent = self:GetParent()

	-- start interval
	self:StartIntervalThink( 0.033 )
	self:OnIntervalThink()

	-- play effects
	self:PlayEffects()

end

function modifier_imba_abyssal_underlord_pit_of_malice_thinker:OnRefresh( kv )
	
end

function modifier_imba_abyssal_underlord_pit_of_malice_thinker:OnRemoved()

end

function modifier_imba_abyssal_underlord_pit_of_malice_thinker:OnDestroy()
	if not IsServer() then return end
	UTIL_Remove( self:GetParent() )
end

--------------------------------------------------------------------------------
-- Interval Effects
function modifier_imba_abyssal_underlord_pit_of_malice_thinker:OnIntervalThink()
	-- Using aura's sticky duration doesn't allow it to be purged, so here we are

	-- find enemies
	local enemies = FindUnitsInRadius(
		self.caster:GetTeamNumber(),	-- int, your team number
		self.parent:GetOrigin(),	-- point, center point
		nil,	-- handle, cacheUnit. (not known)
		self.radius,	-- float, radius. or use FIND_UNITS_EVERYWHERE
		DOTA_UNIT_TARGET_TEAM_ENEMY,	-- int, team filter
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,	-- int, type filter
		0,	-- int, flag filter
		0,	-- int, order filter
		false	-- bool, can grow cache
	)

	for _,enemy in pairs(enemies) do
		-- check if not cooldown
		local modifier = enemy:FindModifierByNameAndCaster( "modifier_imba_abyssal_underlord_pit_of_malice_cooldown", self:GetCaster() )
		if not modifier then
			-- apply modifier
			enemy:AddNewModifier(
				self.caster, -- player source
				self:GetAbility(), -- ability source
				"modifier_imba_abyssal_underlord_pit_of_malice", -- modifier name
				{ duration = self.duration } -- kv
			)
		end
	end
end

-- --------------------------------------------------------------------------------
-- -- Aura Effects
-- function modifier_imba_abyssal_underlord_pit_of_malice_thinker:IsAura()
-- 	return true
-- end

-- function modifier_imba_abyssal_underlord_pit_of_malice_thinker:GetModifierAura()
-- 	return "modifier_imba_abyssal_underlord_pit_of_malice"
-- end

-- function modifier_imba_abyssal_underlord_pit_of_malice_thinker:GetAuraRadius()
-- 	return self.radius
-- end

-- function modifier_imba_abyssal_underlord_pit_of_malice_thinker:GetAuraDuration()
-- 	return self.duration
-- end

-- function modifier_imba_abyssal_underlord_pit_of_malice_thinker:GetAuraSearchTeam()
-- 	return DOTA_UNIT_TARGET_TEAM_ENEMY
-- end

-- function modifier_imba_abyssal_underlord_pit_of_malice_thinker:GetAuraSearchType()
-- 	return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
-- end

-- function modifier_imba_abyssal_underlord_pit_of_malice_thinker:GetAuraSearchFlags()
-- 	return 0
-- end

-- function modifier_imba_abyssal_underlord_pit_of_malice_thinker:GetAuraEntityReject( hEntity )
-- 	if not IsServer() then return false end

-- 	-- reject if cooldown
-- 	if hEntity:FindModifierByNameAndCaster( "modifier_imba_abyssal_underlord_pit_of_malice_cooldown", self:GetCaster() ) then
-- 		return true
-- 	end

-- 	return false
-- end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_imba_abyssal_underlord_pit_of_malice_thinker:PlayEffects()
	-- Get Resources
	local particle_cast = "particles/units/heroes/heroes_underlord/underlord_pitofmalice.vpcf"
	local sound_cast = "Hero_AbyssalUnderlord.PitOfMalice"

	-- Get Data
	local parent = self:GetParent()

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, parent )
	ParticleManager:SetParticleControl( effect_cast, 0, parent:GetOrigin() )
	ParticleManager:SetParticleControl( effect_cast, 1, Vector( self.radius, 1, 1 ) )
	ParticleManager:SetParticleControl( effect_cast, 2, Vector( self:GetDuration(), 0, 0 ) )

	-- buff particle
	self:AddParticle(
		effect_cast,
		false, -- bDestroyImmediately
		false, -- bStatusEffect
		-1, -- iPriority
		false, -- bHeroEffect
		false -- bOverheadEffect
	)

	-- Create Sound
	EmitSoundOn( sound_cast, parent )
end

--------------------------------------------------------------------------------
modifier_imba_abyssal_underlord_pit_of_malice_cooldown = modifier_imba_abyssal_underlord_pit_of_malice_cooldown or class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_imba_abyssal_underlord_pit_of_malice_cooldown:IsHidden()
	return true
end

function modifier_imba_abyssal_underlord_pit_of_malice_cooldown:IsDebuff()
	return true
end

function modifier_imba_abyssal_underlord_pit_of_malice_cooldown:IsPurgable()
	return false
end

function modifier_imba_abyssal_underlord_pit_of_malice_cooldown:GetAttributes()
	return MODIFIER_ATTRIBUTE_MULTIPLE 
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_imba_abyssal_underlord_pit_of_malice_cooldown:OnCreated( kv )

end

function modifier_imba_abyssal_underlord_pit_of_malice_cooldown:OnRefresh( kv )
	
end

function modifier_imba_abyssal_underlord_pit_of_malice_cooldown:OnRemoved()
end

function modifier_imba_abyssal_underlord_pit_of_malice_cooldown:OnDestroy()
end

--------------------------------------------------------------------------------
modifier_imba_abyssal_underlord_pit_of_malice = modifier_imba_abyssal_underlord_pit_of_malice or class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_imba_abyssal_underlord_pit_of_malice:IsHidden()
	return false
end

function modifier_imba_abyssal_underlord_pit_of_malice:IsDebuff()
	return true
end

function modifier_imba_abyssal_underlord_pit_of_malice:IsStunDebuff()
	return false
end

function modifier_imba_abyssal_underlord_pit_of_malice:IsPurgable()
	return true
end

function modifier_imba_abyssal_underlord_pit_of_malice:GetPriority()
	return MODIFIER_PRIORITY_HIGH
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_imba_abyssal_underlord_pit_of_malice:OnCreated( kv )
	-- references
	local interval = self:GetAbility():GetVanillaAbilitySpecial( "pit_interval" )

	if not IsServer() then return end

	-- create cooldown modifier
	self:GetParent():AddNewModifier(
		self:GetCaster(), -- player source
		self:GetAbility(), -- ability source
		"modifier_imba_abyssal_underlord_pit_of_malice_cooldown", -- modifier name
		{
			duration = interval,
		} -- kv
	)

	-- play effects
	local hero = self:GetParent():IsHero()
	local sound_cast = "Hero_AbyssalUnderlord.Pit.TargetHero"
	if not hero then
		sound_cast = "Hero_AbyssalUnderlord.Pit.Target"
	end
	EmitSoundOn( sound_cast, self:GetParent() )

end

function modifier_imba_abyssal_underlord_pit_of_malice:OnRefresh( kv )
	
end

function modifier_imba_abyssal_underlord_pit_of_malice:OnRemoved()
end

function modifier_imba_abyssal_underlord_pit_of_malice:OnDestroy()
end

--------------------------------------------------------------------------------
-- Status Effects
function modifier_imba_abyssal_underlord_pit_of_malice:CheckState()
	local state = {
		[MODIFIER_STATE_INVISIBLE] = false,
		[MODIFIER_STATE_ROOTED] = true,
	}

	return state
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_imba_abyssal_underlord_pit_of_malice:GetEffectName()
	return "particles/units/heroes/heroes_underlord/abyssal_underlord_pitofmalice_stun.vpcf"
end

function modifier_imba_abyssal_underlord_pit_of_malice:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

--------------------------------------------------------------------------------
imba_abyssal_underlord_atrophy_aura = imba_abyssal_underlord_atrophy_aura or class({})
LinkLuaModifier( "modifier_imba_abyssal_underlord_atrophy_aura", "components/abilities/heroes/hero_underlord", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_imba_abyssal_underlord_atrophy_aura_debuff", "components/abilities/heroes/hero_underlord", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_imba_abyssal_underlord_atrophy_aura_stack", "components/abilities/heroes/hero_underlord", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack", "components/abilities/heroes/hero_underlord", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_imba_abyssal_underlord_atrophy_aura_scepter", "components/abilities/heroes/hero_underlord", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Passive Modifier
function imba_abyssal_underlord_atrophy_aura:GetIntrinsicModifierName()
	return "modifier_imba_abyssal_underlord_atrophy_aura"
end

--------------------------------------------------------------------------------
modifier_imba_abyssal_underlord_atrophy_aura = modifier_imba_abyssal_underlord_atrophy_aura or class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_imba_abyssal_underlord_atrophy_aura:IsHidden()
	return self:GetStackCount()==0
end

function modifier_imba_abyssal_underlord_atrophy_aura:IsDebuff()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura:IsStunDebuff()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura:IsPurgable()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura:GetAttributes()
	return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_imba_abyssal_underlord_atrophy_aura:RemoveOnDeath()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura:DestroyOnExpire()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_imba_abyssal_underlord_atrophy_aura:OnCreated( kv )
	-- references
	self.radius = self:GetAbility():GetVanillaAbilitySpecial( "radius" )
	self.hero_bonus = self:GetAbility():GetVanillaAbilitySpecial( "bonus_damage_from_hero" )
	self.creep_bonus = self:GetAbility():GetVanillaAbilitySpecial( "bonus_damage_from_creep" )
	self.bonus = self:GetAbility():GetVanillaAbilitySpecial( "permanent_bonus" )
	self.duration = self:GetAbility():GetVanillaAbilitySpecial( "bonus_damage_duration" )
	self.duration_scepter = self:GetAbility():GetVanillaAbilitySpecial( "bonus_damage_duration_scepter" )

	if not IsServer() then return end

	-- create scepter modifier
	self.scepter_aura = self:GetParent():AddNewModifier(
		self:GetParent(), -- player source
		self:GetAbility(), -- ability source
		"modifier_imba_abyssal_underlord_atrophy_aura_scepter", -- modifier name
		{} -- kv
	)
end

function modifier_imba_abyssal_underlord_atrophy_aura:OnRefresh( kv )
	-- references
	self.radius = self:GetAbility():GetVanillaAbilitySpecial( "radius" )
	self.hero_bonus = self:GetAbility():GetVanillaAbilitySpecial( "bonus_damage_from_hero" )
	self.creep_bonus = self:GetAbility():GetVanillaAbilitySpecial( "bonus_damage_from_creep" )
	self.bonus = self:GetAbility():GetVanillaAbilitySpecial( "permanent_bonus" )
	self.duration = self:GetAbility():GetVanillaAbilitySpecial( "bonus_damage_duration" )
	self.duration_scepter = self:GetAbility():GetVanillaAbilitySpecial( "bonus_damage_duration_scepter" )

	if not IsServer() then return end

	-- refresh scepter modifier
	self.scepter_aura:ForceRefresh()
end

function modifier_imba_abyssal_underlord_atrophy_aura:OnRemoved()
end

function modifier_imba_abyssal_underlord_atrophy_aura:OnDestroy()
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_imba_abyssal_underlord_atrophy_aura:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_DEATH,
		
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
	}

	return funcs
end

function modifier_imba_abyssal_underlord_atrophy_aura:OnDeath( params )
	if not IsServer() then return end
	local parent = self:GetParent()

	-- cancel if break
	if parent:PassivesDisabled() then return end

	-- not illusion
	if params.unit:IsIllusion() then return end

	-- check if has modifier
	if not params.unit:FindModifierByNameAndCaster( "modifier_imba_abyssal_underlord_atrophy_aura_debuff", parent ) then return end

	local hero = params.unit:IsHero()
	local bonus
	if hero then
		bonus = self.hero_bonus
	else
		bonus = self.creep_bonus
	end

	-- set duration
	local duration
	if parent:HasScepter() then
		duration = self.duration_scepter
	else
		duration = self.duration
	end

	-- add stack
	self:SetStackCount( self:GetStackCount() + bonus )

	-- add expire modifier
	local modifier = parent:AddNewModifier(
		parent, -- player source
		self:GetAbility(), -- ability source
		"modifier_imba_abyssal_underlord_atrophy_aura_stack", -- modifier name
		{ duration = duration } -- kv
	)
	modifier.parent = self
	modifier.bonus = bonus

	-- add duration
	self:SetDuration( self.duration, true )

	-- add permanent bonus if hero
	if hero then
		parent:AddNewModifier(
			parent, -- player source
			self:GetAbility(), -- ability source
			"modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack", -- modifier name
			{ bonus = self.bonus } -- kv
		)
	end
end

function modifier_imba_abyssal_underlord_atrophy_aura:GetModifierPreAttack_BonusDamage()
	return self:GetStackCount()
end

--------------------------------------------------------------------------------
-- helper
function modifier_imba_abyssal_underlord_atrophy_aura:RemoveStack( value )
	self:SetStackCount( self:GetStackCount() - value )
end

--------------------------------------------------------------------------------
-- Aura Effects
function modifier_imba_abyssal_underlord_atrophy_aura:IsAura()
	return (not self:GetCaster():PassivesDisabled())
end

function modifier_imba_abyssal_underlord_atrophy_aura:GetModifierAura()
	return "modifier_imba_abyssal_underlord_atrophy_aura_debuff"
end

function modifier_imba_abyssal_underlord_atrophy_aura:GetAuraRadius()
	return self.radius
end

function modifier_imba_abyssal_underlord_atrophy_aura:GetAuraDuration()
	return 0.5
end

function modifier_imba_abyssal_underlord_atrophy_aura:GetAuraSearchTeam()
	return DOTA_UNIT_TARGET_TEAM_ENEMY
end

function modifier_imba_abyssal_underlord_atrophy_aura:GetAuraSearchType()
	return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_imba_abyssal_underlord_atrophy_aura:GetAuraSearchFlags()
	return DOTA_UNIT_TARGET_FLAG_INVULNERABLE
end

function modifier_imba_abyssal_underlord_atrophy_aura:IsAuraActiveOnDeath()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura:GetAuraEntityReject( hEntity )
	if IsServer() then
		if hEntity==self:GetCaster() then return true end
	end

	return false
end

--------------------------------------------------------------------------------
modifier_imba_abyssal_underlord_atrophy_aura_debuff = modifier_imba_abyssal_underlord_atrophy_aura_debuff or class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_imba_abyssal_underlord_atrophy_aura_debuff:IsHidden()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura_debuff:IsDebuff()
	return true
end

function modifier_imba_abyssal_underlord_atrophy_aura_debuff:IsStunDebuff()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura_debuff:IsPurgable()
	return true
end

function modifier_imba_abyssal_underlord_atrophy_aura_debuff:GetAttributes()
	return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE 
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_imba_abyssal_underlord_atrophy_aura_debuff:OnCreated( kv )
	-- references
	self.reduction = self:GetAbility():GetVanillaAbilitySpecial( "damage_reduction_pct" )

	if not IsServer() then return end
end

function modifier_imba_abyssal_underlord_atrophy_aura_debuff:OnRefresh( kv )
	-- references
	self.reduction = self:GetAbility():GetVanillaAbilitySpecial( "damage_reduction_pct" )	
end

function modifier_imba_abyssal_underlord_atrophy_aura_debuff:OnRemoved()
end

function modifier_imba_abyssal_underlord_atrophy_aura_debuff:OnDestroy()
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_imba_abyssal_underlord_atrophy_aura_debuff:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE,
	}

	return funcs
end

function modifier_imba_abyssal_underlord_atrophy_aura_debuff:GetModifierBaseDamageOutgoing_Percentage( params )
	return -self.reduction
end

--------------------------------------------------------------------------------
modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack = modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack or class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack:IsHidden()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack:IsDebuff()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack:IsPurgable()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack:GetAttributes()
	return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack:RemoveOnDeath()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack:OnCreated( kv )
	if not IsServer() then return end
	self:SetStackCount( kv.bonus )
end

function modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack:OnRefresh( kv )
	if not IsServer() then return end
	self:SetStackCount( self:GetStackCount() + kv.bonus )
end

function modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack:OnRemoved()
end

function modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack:OnDestroy()
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
	}

	return funcs
end

function modifier_imba_abyssal_underlord_atrophy_aura_permanent_stack:GetModifierPreAttack_BonusDamage()
	return self:GetStackCount()
end

--------------------------------------------------------------------------------
modifier_imba_abyssal_underlord_atrophy_aura_scepter = modifier_imba_abyssal_underlord_atrophy_aura_scepter or class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_imba_abyssal_underlord_atrophy_aura_scepter:IsHidden()
	return self:GetStackCount()==0
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:IsDebuff()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:IsStunDebuff()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:IsPurgable()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:RemoveOnDeath()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_imba_abyssal_underlord_atrophy_aura_scepter:OnCreated( kv )
	self.radius = self:GetAbility():GetVanillaAbilitySpecial( "radius" )
	self.bonus_pct = 50

	if not IsServer() then return end

	self.modifier = self:GetCaster():FindModifierByNameAndCaster( "modifier_imba_abyssal_underlord_atrophy_aura", self:GetCaster() )
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:OnRefresh( kv )
	self:OnCreated( kv )
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:OnRemoved()
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:OnDestroy()
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_imba_abyssal_underlord_atrophy_aura_scepter:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
	}

	return funcs
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:GetModifierPreAttack_BonusDamage()
	-- not applicable to original owner
	if self:GetParent()==self:GetCaster() then return 0 end

	-- calculate stack value
	if IsServer() then
		-- copy half of stack value
		local bonus = self.modifier:GetStackCount()
		bonus = math.floor( bonus*self.bonus_pct/100 )

		-- set stack
		self:SetStackCount( bonus )
	end

	return self:GetStackCount()
end

--------------------------------------------------------------------------------
-- Aura Effects
function modifier_imba_abyssal_underlord_atrophy_aura_scepter:IsAura()
	local caster = self:GetCaster()
	local parent = self:GetParent()

	-- scepter
	if not caster:HasScepter() then return false end

	-- only for original owner
	return self:GetParent()==self:GetCaster()
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:GetModifierAura()
	return "modifier_imba_abyssal_underlord_atrophy_aura_scepter"
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:GetAuraRadius()
	return self.radius
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:GetAuraDuration()
	return 0.5
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:GetAuraSearchTeam()
	return DOTA_UNIT_TARGET_TEAM_FRIENDLY
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:GetAuraSearchType()
	return DOTA_UNIT_TARGET_HERO
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:GetAuraSearchFlags()
	return 0
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:IsAuraActiveOnDeath()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura_scepter:GetAuraEntityReject( hEntity )
	if IsServer() then
		
	end

	return false
end

--------------------------------------------------------------------------------
modifier_imba_abyssal_underlord_atrophy_aura_stack = modifier_imba_abyssal_underlord_atrophy_aura_stack or class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_imba_abyssal_underlord_atrophy_aura_stack:IsHidden()
	return true
end

function modifier_imba_abyssal_underlord_atrophy_aura_stack:IsDebuff()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura_stack:IsPurgable()
	return false
end

function modifier_imba_abyssal_underlord_atrophy_aura_stack:GetAttributes()
	return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE 
end

function modifier_imba_abyssal_underlord_atrophy_aura_stack:RemoveOnDeath()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_imba_abyssal_underlord_atrophy_aura_stack:OnCreated( kv )

end

function modifier_imba_abyssal_underlord_atrophy_aura_stack:OnRefresh( kv )
	
end

function modifier_imba_abyssal_underlord_atrophy_aura_stack:OnRemoved()
end

function modifier_imba_abyssal_underlord_atrophy_aura_stack:OnDestroy()
	if not IsServer() then return end
	self.parent:RemoveStack( self.bonus )
end

--------------------------------------------------------------------------------
imba_abyssal_underlord_dark_rift = imba_abyssal_underlord_dark_rift or class({})
LinkLuaModifier( "modifier_imba_abyssal_underlord_dark_rift", "components/abilities/heroes/hero_underlord", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Ability Start
function imba_abyssal_underlord_dark_rift:OnSpellStart()
	if not IsServer() then return end

	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	local point = self:GetCursorPosition()

	-- search for closest target if it is a point
	if not target then
		local targets = FindUnitsInRadius(
			caster:GetTeamNumber(),	-- int, your team number
			point,	-- point, center point
			nil,	-- handle, cacheUnit. (not known)
			FIND_UNITS_EVERYWHERE,	-- float, radius. or use FIND_UNITS_EVERYWHERE
			DOTA_UNIT_TARGET_TEAM_FRIENDLY,	-- int, team filter
			DOTA_UNIT_TARGET_BUILDING + DOTA_UNIT_TARGET_CREEP,	-- int, type filter
			DOTA_UNIT_TARGET_FLAG_INVULNERABLE,	-- int, flag filter
			FIND_CLOSEST,	-- int, order filter
			false	-- bool, can grow cache
		)

		if #targets>0 then target = targets[1] end
	end

	-- if, somehow, for an exceptional miracle, there is still no target, then do nothing. This should be done on ability phase, but whatever
	if not target then return end

	-- load data
	local duration = self:GetVanillaAbilitySpecial( "teleport_delay" )

	-- add modifier to target
	local modifier = target:AddNewModifier(
		caster, -- player source
		self, -- ability source
		"modifier_imba_abyssal_underlord_dark_rift", -- modifier name
		{ duration = duration } -- kv
	)

	-- check sister ability
	local ability = caster:FindAbilityByName( "imba_abyssal_underlord_cancel_dark_rift" )
	if not ability then
		ability = caster:AddAbility( "imba_abyssal_underlord_cancel_dark_rift" )
		ability:SetStolen( true )
	end

	-- check ability level
	ability:SetLevel( 1 )

	-- give info about modifier
	ability.modifier = modifier

	-- switch ability layout
	caster:SwapAbilities(
		self:GetAbilityName(),
		ability:GetAbilityName(),
		false,
		true
	)
end

--------------------------------------------------------------------------------
-- Sub Ability
--------------------------------------------------------------------------------
imba_abyssal_underlord_cancel_dark_rift = imba_abyssal_underlord_cancel_dark_rift or class({})

--------------------------------------------------------------------------------
-- Ability Start
function imba_abyssal_underlord_cancel_dark_rift:OnSpellStart()
	if not IsServer() then return end

	-- kill modifier
	self.modifier:Cancel()
	self.modifier = nil
end

--------------------------------------------------------------------------------
modifier_imba_abyssal_underlord_dark_rift = modifier_imba_abyssal_underlord_dark_rift or class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_imba_abyssal_underlord_dark_rift:IsHidden()
	return false
end

function modifier_imba_abyssal_underlord_dark_rift:IsDebuff()
	return false
end

function modifier_imba_abyssal_underlord_dark_rift:IsPurgable()
	return false
end

function modifier_imba_abyssal_underlord_dark_rift:GetAttributes()
	return MODIFIER_ATTRIBUTE_MULTIPLE
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_imba_abyssal_underlord_dark_rift:OnCreated( kv )
	-- references
	self.radius = self:GetAbility():GetVanillaAbilitySpecial( "radius" )

	if not IsServer() then return end

	self.success = true

	self:PlayEffects1()
	self:PlayEffects2()
end

function modifier_imba_abyssal_underlord_dark_rift:OnRefresh( kv )
	
end

function modifier_imba_abyssal_underlord_dark_rift:OnRemoved()
	if not IsServer() then return end
	if not self.success then return end

	local caster = self:GetCaster()

	-- play effects
	self:PlayEffects3()

	-- success teleporting
	local targets = FindUnitsInRadius(
		caster:GetTeamNumber(),	-- int, your team number
		caster:GetOrigin(),	-- point, center point
		nil,	-- handle, cacheUnit. (not known)
		self.radius,	-- float, radius. or use FIND_UNITS_EVERYWHERE
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,	-- int, team filter
		DOTA_UNIT_TARGET_HERO,	-- int, type filter
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD,	-- int, flag filter
		0,	-- int, order filter
		false	-- bool, can grow cache
	)

	-- teleport units 
	local point = self:GetParent():GetOrigin()
	for _,target in pairs(targets) do
		-- disjoint
		ProjectileManager:ProjectileDodge( target )

		-- move to position
		FindClearSpaceForUnit( target, point, true )
	end

	-- switch ability layout
	local ability = self:GetCaster():FindAbilityByName( "imba_abyssal_underlord_cancel_dark_rift" )
	if not ability then return end

	caster:SwapAbilities(
		self:GetAbility():GetAbilityName(),
		ability:GetAbilityName(),
		true,
		false
	)
end

function modifier_imba_abyssal_underlord_dark_rift:OnDestroy()
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_imba_abyssal_underlord_dark_rift:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_DEATH,
	}

	return funcs
end

function modifier_imba_abyssal_underlord_dark_rift:OnDeath( params )
	if not IsServer() then return end

	if params.unit~=self:GetCaster() and params.unit~=self:GetParent() then return end

	-- either caster or target dies, destroy
	self:Cancel()
end

--------------------------------------------------------------------------------
-- Status Effects
function modifier_imba_abyssal_underlord_dark_rift:CheckState()
	local state = {
		[MODIFIER_STATE_LOW_ATTACK_PRIORITY] = true,
	}

	return state
end

--------------------------------------------------------------------------------
-- Helper
function modifier_imba_abyssal_underlord_dark_rift:Cancel()
	-- cancel teleport
	self.success = false

	-- switch ability layout
	local ability = self:GetCaster():FindAbilityByName( "imba_abyssal_underlord_cancel_dark_rift" )
	if not ability then return end
	self:GetCaster():SwapAbilities(
		self:GetAbility():GetAbilityName(),
		ability:GetAbilityName(),
		true,
		false
	)

	-- play effects
	self:PlayEffects4()

	-- destroy
	self:Destroy()
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_imba_abyssal_underlord_dark_rift:PlayEffects1()
	-- Get Resources
	local particle_cast = "particles/units/heroes/heroes_underlord/abyssal_underlord_darkrift_target.vpcf"
	local sound_cast = "Hero_AbyssalUnderlord.DarkRift.Target"

	-- Get Data
	local parent = self:GetParent()

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_OVERHEAD_FOLLOW, parent )
	ParticleManager:SetParticleControlEnt(
		effect_cast,
		6,
		parent,
		PATTACH_ABSORIGIN_FOLLOW,
		"attach_hitloc",
		Vector(0,0,0), -- unknown
		true -- unknown, true
	)

	-- buff particle
	self:AddParticle(
		effect_cast,
		false, -- bDestroyImmediately
		false, -- bStatusEffect
		-1, -- iPriority
		false, -- bHeroEffect
		false -- bOverheadEffect
	)

	-- Create Sound
	EmitSoundOn( sound_cast, parent )
end

function modifier_imba_abyssal_underlord_dark_rift:PlayEffects2()
	-- Get Resources
	local particle_cast = "particles/units/heroes/heroes_underlord/abbysal_underlord_darkrift_ambient.vpcf"
	local sound_cast = "Hero_AbyssalUnderlord.DarkRift.Cast"

	-- Get Data
	local caster = self:GetCaster()
	local parent = self:GetParent()

	-- Create Particle
	self.effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, caster )
	ParticleManager:SetParticleControl( self.effect_cast, 1, Vector( self.radius, 0, 0 ) )
	ParticleManager:SetParticleControlEnt(
		self.effect_cast,
		2,
		caster,
		PATTACH_ABSORIGIN_FOLLOW,
		"attach_hitloc",
		Vector(0,0,0), -- unknown
		true -- unknown, true
	)

	-- buff particle
	self:AddParticle(
		self.effect_cast,
		false, -- bDestroyImmediately
		false, -- bStatusEffect
		-1, -- iPriority
		false, -- bHeroEffect
		false -- bOverheadEffect
	)

	-- Create Sound
	EmitSoundOn( sound_cast, caster )
end

function modifier_imba_abyssal_underlord_dark_rift:PlayEffects3()
	-- Get Resources
	local sound_cast1 = "Hero_AbyssalUnderlord.DarkRift.Complete"
	local sound_cast2 = "Hero_AbyssalUnderlord.DarkRift.Aftershock"

	-- Get Data
	local caster = self:GetCaster()
	local parent = self:GetParent()

	-- Set Effect
	ParticleManager:SetParticleControl( self.effect_cast, 5, caster:GetOrigin() )

	-- Create Sound
	EmitSoundOn( sound_cast1, parent )
	EmitSoundOnLocationWithCaster( caster:GetOrigin(), sound_cast2, caster )
end

function modifier_imba_abyssal_underlord_dark_rift:PlayEffects4()
	-- Get Resources
	local sound_cast1 = "Hero_AbyssalUnderlord.DarkRift.Cast"
	local sound_cast2 = "Hero_AbyssalUnderlord.DarkRift.Target"
	local sound_cancel = "Hero_AbyssalUnderlord.DarkRift.Cancel"

	-- Get Data
	local caster = self:GetCaster()
	local parent = self:GetParent()

	-- Kill effect
	ParticleManager:DestroyParticle( self.effect_cast, true )

	-- Create Sound
	StopSoundOn( sound_cast1, caster )
	StopSoundOn( sound_cast2, parent )
	EmitSoundOn( sound_cancel, caster )
	EmitSoundOn( sound_cancel, parent )
end
