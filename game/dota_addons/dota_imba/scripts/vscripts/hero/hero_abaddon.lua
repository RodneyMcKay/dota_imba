--[[	Author: Broccoli
		Date: 26-3-2017		]]

CreateEmptyTalents("abaddon")

-----------------------------
--		Mist Coil          --
-----------------------------

imba_abaddon_mist_coil = class({})

function imba_abaddon_mist_coil:OnSpellStart()
	if IsServer() then
		local caster = self:GetCaster()
		local target = self:GetCursorTarget()
		local ability_name_curse_of_avernus = "imba_abaddon_curse_of_avernus"

		caster:EmitSound("Hero_Abaddon.DeathCoil.Cast")

		if caster:HasAbility(ability_name_curse_of_avernus) then
			-- Create the projectile
			local info = {
				Target = target,
				Source = caster,
				Ability = self,
				EffectName = "particles/units/heroes/hero_abaddon/abaddon_death_coil.vpcf",
				bDodgeable = false,
				bProvidesVision = true,
				bVisibleToEnemies = true,
				bReplaceExisting = false,
				iMoveSpeed = self:GetSpecialValueFor("projectile_speed"),
				iVisionRadius = 0,
				iVisionTeamNumber = caster:GetTeamNumber()
			}
			ProjectileManager:CreateTrackingProjectile( info )
		else
			-- Nether ward and rubick applies level 1 curse of avernus
			-- Hence there is a need to create a dummy unit to cast the spell while possessing both mist coil and curse of avernus abilities

			local dummy 					= CreateUnitByName('npc_dummy_unit', caster:GetAbsOrigin(), false, caster, caster, caster:GetTeamNumber())
			local dummy_mist_coil 			= dummy:AddAbility("imba_abaddon_mist_coil")
			local dummy_curse_of_avernus 	= dummy:AddAbility(ability_name_curse_of_avernus)
			dummy_mist_coil:SetLevel(self:GetLevel())
			dummy_curse_of_avernus:SetLevel(1)
			-- Allow casting of mist coil immediately
			dummy_mist_coil:SetOverrideCastPoint(0)
			dummy:CastAbilityOnTarget(target, dummy_mist_coil, caster:GetPlayerID())

			-- Destroy dummy after casting mist coil
			Timers:CreateTimer(1, function()
				UTIL_Remove(dummy)
			end)
		end
	end
end

function imba_abaddon_mist_coil:OnProjectileHit( hTarget, vLocation )
	if IsServer() then
		local caster = self:GetCaster()
		local target = hTarget
		local ability_level = self:GetLevel() - 1

		target:EmitSound("Hero_Abaddon.DeathCoil.Target")

        if target:GetTeam() ~= caster:GetTeam() then
			-- If target has Linken Sphere, block effect entirely
            if target:TriggerSpellAbsorb(self) then
                return nil
            end

			local damage = self:GetLevelSpecialValueFor("damage", ability_level)
			local damage_type = DAMAGE_TYPE_MAGICAL

			ApplyDamage({ victim = target, attacker = caster, damage = damage,	damage_type = damage_type })
			
			-- Apply curse of avernus debuff
			local curse_of_avernus = caster:FindAbilityByName("imba_abaddon_curse_of_avernus")
			if curse_of_avernus then
				-- TODO test if casting mist coil without curse will it have issues here
				local debuff_duration = curse_of_avernus:GetSpecialValueFor("debuff_duration")
				target:AddNewModifier(caster, curse_of_avernus, "modifier_imba_curse_of_avernus_debuff", { duration = debuff_duration })
			else
				--TODO remove after debug
				print("Mist coil casted without curse of avernus")
			end

		else
			local heal = self:GetLevelSpecialValueFor("heal", ability_level)

			-- heal allies or self
			target:Heal(heal, caster)
			SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, target, heal, nil)
        end
	end
end

-----------------------------
--	   Aphotic Shield      --
-----------------------------

imba_abaddon_aphotic_shield = class({})
LinkLuaModifier("modifier_aphotic_shield_buff", "hero/hero_abaddon", LUA_MODIFIER_MOTION_NONE)

function imba_abaddon_aphotic_shield:GetCastRange(Location, Target)
	local caster = self:GetCaster()
	return self:GetSpecialValueFor("cast_range")
end

function imba_abaddon_aphotic_shield:OnCreated()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	-- Strong Dispel
	target:Purge(false, true, false, true, false)

	local modifier_name_aphotic_shield = "modifier_aphotic_shield_buff"

	-- TODO check if it explodes if reapplied
	-- Remove previous aphotic shield
	target:RemoveModifierByNameAndCaster(modifier_name_aphotic_shield, caster)

	-- Add new modifier
	local duration = self:GetSpecialValueFor("duration")
	target:AddNewModifier(caster, self, modifier_name_aphotic_shield, { duration = duration })
end

modifier_aphotic_shield_buff = class({
	IsHidden				= function(self) return false end,
	IsPurgable	  			= function(self) return true end,
	IsDebuff	  			= function(self) return false end
})

function modifier_aphotic_shield_buff:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_TAKEDAMAGE
	}
 
	return funcs
end

function modifier_aphotic_shield_buff:OnCreated()
	local target = self:GetParent()
	local shield_size = target:GetModelRadius() * 0.7
	local ability = self:GetAbility()
	local ability_level = ability:GetLevel()

	self.shield_remaining = ability:GetLevelSpecialValueFor( "shield", ability_level )

	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_abaddon/abaddon_aphotic_shield.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
	local common_vector = Vector(shield_size,0,shield_size)
	ParticleManager:SetParticleControl(particle, 1, common_vector)
	ParticleManager:SetParticleControl(particle, 2, common_vector)
	ParticleManager:SetParticleControl(particle, 4, common_vector)
	ParticleManager:SetParticleControl(particle, 5, Vector(shield_size,0,0))	

	-- Proper Particle attachment courtesy of BMD. Only PATTACH_POINT_FOLLOW will give the proper shield position
	ParticleManager:SetParticleControlEnt(particle, 0, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)

	--void AddParticle(int i, bool bDestroyImmediately, bool bStatusEffect, int iPriority, bool bHeroEffect, bool bOverheadEffect)
	self:AddParticle(particle, false, false, -1, false, false)
end

function modifier_aphotic_shield_buff:OnRemoved()
	local target 				= self:GetParent()
	local caster 				= self:GetCaster()
	local ability 				= self:GetAbility()
	local ability_level 		= ability:GetLevel()
	local radius 				= ability:GetSpecialValueFor("radius")
	local explode_target_team 	= DOTA_UNIT_TARGET_TEAM_ENEMY
	local explode_target_type 	= DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC

	target:EmitSound("Hero_Abaddon.AphoticShield.Destroy")

	-- TODO
	--local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_abaddon/abaddon_aphotic_shield_explosion.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, radius, explode_target_team, explode_target_type, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	-- Deal damage to enemies around
	local damage = ability:GetLevelSpecialValueFor( "shield", ability_level )
	local damage_type = DAMAGE_TYPE_MAGICAL
	for _,enemy in pairs(enemies) do
		ApplyDamage({ victim = enemy, attacker = caster, damage = damage, damage_type = damage_type })
	end

	-- Apply debuff to enemies around
	local ability_name_curse_of_avernus 	= "imba_abaddon_curse_of_avernus"
	local curse_of_avernus 					= caster:FindAbilityByName(ability_name_curse_of_avernus)
	local spoof_caster
	if curse_of_avernus then
		spoof_caster 		= caster
	else
		--Apply debuff using dummy
		local dummy 		= CreateUnitByName('npc_dummy_unit', target:GetAbsOrigin(), false, caster, caster, caster:GetTeamNumber())
		curse_of_avernus 	= dummy:AddAbility(ability_name_curse_of_avernus)
		curse_of_avernus:SetLevel(1)
		spoof_caster 		= dummy

		-- Destroy dummy after applying debuff
		Timers:CreateTimer(1, function()
			UTIL_Remove(dummy)
		end)
	end

	local debuff_duration = curse_of_avernus:GetSpecialValueFor("debuff_duration")
	for _,enemy in pairs(enemies) do
		enemy:AddNewModifier(spoof_caster, curse_of_avernus, "modifier_imba_curse_of_avernus_debuff", { duration = debuff_duration })
	end
end

function modifier_aphotic_shield_buff:OnTakeDamage(kv)
	local target = self:GetParent()

	-- Absorb damage taken by unit which has this buff
	if target == kv.unit then
		-- Avoid calculation when borrowed time is active
		if target:HasModifier("modifier_borrowed_time_caster_buff") == false then
			local damage = kv.damage
			local shield_remaining = self.shield_remaining

			-- If the damage is bigger than what the shield can absorb, heal a portion
			local damage_block_amount
			if damage > shield_remaining then
				damage_block_amount = shield_remaining
			else
				damage_block_amount = damage
			end
			-- Show effect of damage blocked
			SendOverheadEventMessage(nil, OVERHEAD_ALERT_BLOCK, target, damage_block_amount, nil)
			-- Heal can fail due to modifiers preventing heal, set unit's health instead
			target:SetHealth(target:GetHealth() + damage_block_amount)

			self.shield_remaining = self.shield_remaining - damage
			if self.shield_remaining <= 0 then
				traget:RemoveModifierByName("modifier_aphotic_shield_buff")
			end
		end
	end
end

-----------------------------
--     Curse Of Avernus    --
-----------------------------

imba_abaddon_curse_of_avernus = class({
	GetIntrinsicModifierName = function(self) return "modifier_imba_curse_of_avernus_caster" end
})
LinkLuaModifier("modifier_imba_curse_of_avernus_caster", "hero/hero_abaddon", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_curse_of_avernus_debuff", "hero/hero_abaddon", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_curse_of_avernus_buff", "hero/hero_abaddon", LUA_MODIFIER_MOTION_NONE)

modifier_imba_curse_of_avernus_caster = class({
	IsHidden				= function(self) return true end,
	IsPurgable	  			= function(self) return false end,
	IsDebuff	  			= function(self) return false end,
	AllowIllusionDuplicate	= function(self) return false end
})

function modifier_imba_curse_of_avernus_caster:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_ATTACK
	}
 
	return funcs
end

function modifier_imba_curse_of_avernus_caster:OnAttack(kv)
	if IsServer() then
		local caster = self:GetCaster()
		local target = kv.target

		-- Do not apply curse if avernus if "break"
		if not caster:PassivesDisabled() then
			-- Apply curse of avernus to enemies
			if target:GetTeamNumber() ~= caster:GetTeamNumber() then
				-- Apply debuff if enemy
				local ability = self:GetAbility()
				local debuff_duration = ability:GetSpecialValueFor("debuff_duration")
				target:AddNewModifier(caster, ability, "modifier_imba_curse_of_avernus_debuff", { duration = debuff_duration })
			end
		end
	end
end

modifier_imba_curse_of_avernus_debuff = class({
	IsHidden				= function(self) return false end,
	IsPurgable	  			= function(self) return true end,
	IsDebuff	  			= function(self) return true end,
	GetEffectName			= function(self) return "particles/units/heroes/hero_abaddon/abaddon_frost_slow.vpcf" end,
	GetEffectAttachType		= function(self) return PATTACH_ABSORIGIN_FOLLOW end,
})
function modifier_imba_curse_of_avernus_debuff:_UpdateSlowValues()
	if IsServer() then
		local ability = self:GetAbility()
		local ability_level = ability:GetLevel() - 1

		self.move_slow = ability:GetLevelSpecialValueFor("move_slow", ability_level)
		self.attack_slow = ability:GetLevelSpecialValueFor("attack_slow", ability_level)
		self.heal_convert = ability:GetLevelSpecialValueFor("heal_convert", ability_level)
	end
end

function modifier_imba_curse_of_avernus_debuff:OnCreated()
	self:_UpdateSlowValues()
end

function modifier_imba_curse_of_avernus_debuff:OnRefresh()
	self:_UpdateSlowValues()
end

function modifier_imba_curse_of_avernus_debuff:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_EVENT_ON_ATTACK,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
 
	return funcs
end

function modifier_imba_curse_of_avernus_debuff:OnAttack(kv)
	if IsServer() then
		local caster 	= self:GetCaster()
		local attacker 	= keys.attacker
		local target 	= keys.target

		-- Apply buff to allies who hit the enemy with this debuff
		if target == self:GetParent() and caster:GetTeamNumber() == attacker:GetTeamNumber() then
			local ability = self:GetAbility()
			local ability_level = ability:GetLevel()
			local buff_duration = ability:GetLevelSpecialValueFor("buff_duration", ability_level)

			attacker:AddNewModifier(caster, ability, "modifier_imba_curse_of_avernus_buff", { duration = buff_duration })
		end
	end
end

function modifier_imba_curse_of_avernus_debuff:OnTakeDamage(kv)
	
	if IsServer() then

		-- Caster gain heal equal to damage to taken (heal_convert)
		local heal_convert = self.heal_convert

		-- Do not process if there is no heal convert
		if heal_convert > 0 then
			local target = self:GetParent()

			-- Unit having this debuff must be the one taking damage
			if target == kv.unit then
				local caster = self:GetCaster()
				local damage = kv.damage
				local target_health_left = target:GetHealth()

				-- Ensure that we do not heal over the target's health
				local heal_amount
				if damage > target_health_left then
					heal_amount = target_health_left
				else
					heal_amount = damage
				end
				heal_amount = heal_amount * heal_convert
				
				-- Heal caster equal to a percentage of damage taken by unit affected by this debuff
				caster:Heal(heal_amount, caster)

				-- TODO talent heal allies
				-- caster._borrowed_time_buffed_allies
			end
		end
	end
end

function modifier_imba_curse_of_avernus_debuff:GetModifierMoveSpeedBonus_Percentage() return self.move_slow end
function modifier_imba_curse_of_avernus_debuff:GetModifierAttackSpeedBonus_Constant() return self.attack_slow end

modifier_imba_curse_of_avernus_buff = class({
	IsHidden				= function(self) return false end,
	IsPurgable	  			= function(self) return true end,
	IsDebuff	  			= function(self) return false end,
	GetEffectName			= function(self) return "particles/units/heroes/hero_abaddon/abaddon_frost_buff.vpcf" end,
	GetEffectAttachType		= function(self) return PATTACH_ABSORIGIN_FOLLOW end,
})

function modifier_imba_curse_of_avernus_buff:_UpdateIncreaseValues()
	if IsServer() then
		local ability = self:GetAbility()
		local ability_level = ability:GetLevel() - 1

		self.move_increase = ability:GetLevelSpecialValueFor( "attack_increase" , ability_level)
	end
end

function modifier_imba_curse_of_avernus_buff:OnCreated()
	if IsServer() then
		self.move_increase = self:GetAbility():GetSpecialValueFor("move_increase")
		self:_UpdateIncreaseValues()
	end
end

function modifier_imba_curse_of_avernus_buff:OnRefresh()
	self:_UpdateIncreaseValues()
end

function modifier_imba_curse_of_avernus_buff:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT
	}
 
	return funcs
end

function modifier_imba_curse_of_avernus_buff:GetModifierMoveSpeedBonus_Percentage() return self.move_increase end
function modifier_imba_curse_of_avernus_buff:GetModifierAttackSpeedBonus_Constant() return self.attack_increase end

-----------------------------
--		Over Channel       --
-----------------------------

-----------------------------
--       Borrowed Time     --
-----------------------------
imba_abaddon_borrowed_time = class({
	GetIntrinsicModifierName = function(self) return "modifer_borrowed_time_caster_auto_cast" end
})
LinkLuaModifier("modifer_borrowed_time_caster_auto_cast", "hero/hero_abaddon", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_borrowed_time_caster_buff", "hero/hero_abaddon", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_borrowed_time_allies_buff", "hero/hero_abaddon", LUA_MODIFIER_MOTION_NONE)

function imba_abaddon_borrowed_time:OnCreated()
	if IsServer() then
		local caster = self:GetCaster()
		caster._borrowed_time_buffed_allies = {}
	end
end

function imba_abaddon_borrowed_time:OnSpellStart()
	if IsServer() then
		local caster = self:GetCaster()
		local ability = self:GetAbility()
		local ability_level = ability:GetLevel()
		local buff_duration = ability:GetLevelSpecialValueFor("duration", ability_level)
		caster:AddNewModifier(caster, self, "modifier_borrowed_time_caster_buff", { duration = buff_duration })
	end
end

modifer_borrowed_time_caster_auto_cast = class({
	IsHidden				= function(self) return true end,
	IsPurgable	  			= function(self) return false end,
	IsDebuff	  			= function(self) return false end,
	AllowIllusionDuplicate	= function(self) return false end,
})

function modifer_borrowed_time_caster_auto_cast:OnCreated()
	if IsServer() then
		self.hp_threshold = self:GetAbility():GetSpecialValueFor("hp_threshold")
	end
end

function modifer_borrowed_time_caster_auto_cast:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_TAKEDAMAGE,
		MODIFIER_EVENT_ON_STATE_CHANGED
	}
 
	return funcs
end

function modifer_borrowed_time_caster_auto_cast:_AutoActivate()
	local target = self:GetParent()
	local ability = self:GetAbility()
	target:CastAbilityImmediately(ability, target:GetPlayerID())
end

function modifer_borrowed_time_caster_auto_cast:OnTakeDamage(kv)
	
	if IsServer() then
		local target = self:GetParent()
		local ability = self:GetAbility()

		if target == kv.unit and ability:IsCooldownReady() and not target:IsSilenced() and not target:IsHexed() then
			-- Auto cast borrowed time if damage will bring target to lower than hp_threshold
			local damage = kv.damage
			local hp_threshold = self.hp_threshold
			local current_hp = target:GetHealth()
			local hp_left_after_damage = current_hp - damage
			if hp_left_after_damage < hp_threshold then
				-- TODO check if it prevents death
				self:_AutoActivate()
			end
		end
	end
	
end

function modifer_borrowed_time_caster_auto_cast:OnStateChanged(kv)
	-- Trigger borrowed time if health below hp_threshold after silence/hex
	if IsServer() then
		print("test", kv)
		local target = self:GetParent()
		local ability = self:GetAbility()

		-- Check state
		if ability:IsCooldownReady() and not target:IsSilenced() and not target:IsHexed() then
			local hp_threshold = self.hp_threshold
			local current_hp = target:GetHealth()
			if current_hp < hp_threshold then
				self:_AutoActivate()
			end
		end
	end
end

modifier_borrowed_time_caster_buff = class({
	IsHidden				= function(self) return false end,
	IsPurgable	  			= function(self) return false end,
	IsDebuff	  			= function(self) return false end,
	IsAura					= function(self) return true end,
	IsAuraActiveOnDeath		= function(self) return false end,
	GetModifierAura			= function(self) return "modifier_borrowed_time_allies_buff" end,
	GetAuraSearchType		= function(self) return DOTA_UNIT_TARGET_HERO end,
	GetAuraSearchTeam		= function(self) return DOTA_UNIT_TARGET_TEAM_FRIENDLY end,
	GetAuraRadius			= function(self) return self:GetAbility():GetSpecialValueFor("redirect_range") end,
	GetEffectName			= function(self) return "particles/units/heroes/hero_abaddon/abaddon_borrowed_time.vpcf",
	GetEffectAttachType		= function(self) return PATTACH_ABSORIGIN_FOLLOW end,
	GetStatusEffectName		= function(self) return "particles/status_fx/status_effect_abaddon_borrowed_time.vpcf",
	StatusEffectPriority	= function(self) return 15,
})

function modifier_borrowed_time_caster_buff:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_TAKEDAMAGE
	}
 
	return funcs
end

function modifier_borrowed_time_caster_buff:GetAuraEntityReject(hEntity)
	-- Do not apply aura to target
	return hEntity ~= self:GetParent()
end

function modifier_borrowed_time_caster_buff:OnCreated()
	if IsServer() then
		local target = self:GetParent()

		-- Play Sound
		target:EmitSound("Hero_Abaddon.BorrowedTime")

		-- Strong Dispel
		target:Purge(false, true, false, true, false)
	end	
end

function modifier_borrowed_time_caster_buff:OnTakeDamage(kv)
	if IsServer() then
		-- Ignore damage and convert to healing
		local target = self:GetParent()

		if target == kv.unit then
			local damage = kv.damage

			-- TODO Account for rapier damage amplification?

			-- Block incoming damage
			SendOverheadEventMessage(nil, OVERHEAD_ALERT_BLOCK, target, damage, nil)
			target:SetHealth(target:GetHealth() + damage)

			-- Heal blocked damage
			SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, target, damage, nil)
			target:Heal(damage, target)
		end
	end
end

modifier_borrowed_time_allies_buff = class({
	IsHidden				= function(self) return false end,
	IsPurgable	  			= function(self) return false end,
	IsDebuff	  			= function(self) return false end,
})

function modifier_borrowed_time_allies_buff:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_TAKEDAMAGE
	}
 
	return funcs
end

function modifier_borrowed_time_allies_buff:OnCreated()
	if IsServer() then
		local caster = self:GetCaster()
		local buff_list = caster._borrowed_time_buffed_allies
		if buff_list then
			_borrowed_time_buffed_allies[self:GetParent()] = true
		end
	end
end

function modifier_borrowed_time_allies_buff:OnRemoved()
	if IsServer() then
		local caster = self:GetCaster()
		local buff_list = caster._borrowed_time_buffed_allies
		if buff_list then
			_borrowed_time_buffed_allies[self:GetParent()] = nil
		end
	end
end

function modifier_borrowed_time_allies_buff:OnTakeDamage(kv)
	if IsServer() then
		local target = self:GetParent()

		-- Works for illusions as well
		if target == kv.unit then
			local caster = self:GetCaster()
			local ability = self:GetAbility()
			local ability_level = ability:GetLevel()
			local redirect = ability:GetLevelSpecialValueFor("redirect", ability_level)
			local damage = kv.damage
			local attacker = kv.attacker

			-- TODO Account for rapier damage amplification?

			-- Redirect damage to caster (which should heal when caster takes damage)
			local redirect_damage = damage * redirect
			-- TODO create link effect
			target:SetHealth(target:GetHealth() + redirect_damage)
			-- Redirect as pure damage else it will be reduced again by armour/magic resistance
			ApplyDamage({ victim = caster, attacker = attacker, damage = redirect_damage, damage_type = DAMAGE_TYPE_PURE })
		end
		
	end
	
end

--[[ TODO
		"Ability4"					"imba_abaddon_over_channel"

		"Ability10"					"special_bonus_imba_abaddon_1"
		"Ability11"					"special_bonus_imba_abaddon_2"
		"Ability12"					"special_bonus_imba_abaddon_3"
		"Ability13"					"special_bonus_imba_abaddon_4"
		"Ability14"					"special_bonus_imba_abaddon_5"
		"Ability15"					"special_bonus_imba_abaddon_6"
		"Ability16"					"special_bonus_imba_abaddon_7"
		"Ability17"					"special_bonus_imba_abaddon_8"
]]--