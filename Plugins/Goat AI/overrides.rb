class Battle
    alias old_initialize initialize
    def initialize(scene, p1, p2, player, opponent)
        old_initialize(scene, p1, p2, player, opponent)
        @battleAI = GoatAI.new(self)
    end

    def pbCommandPhaseLoop(isPlayer)
		# NOTE: Doing some things (e.g. running, throwing a Poké Ball) takes up all
		#       your actions in a round.
		actioned = []
		idxBattler = -1
		# DemICE store all damages in a hash for better efficiency.
		# @battleAI.registerDamagesAI if isPlayer
		loop do
			break if @decision != 0   # Battle ended, stop choosing actions
			idxBattler += 1
			break if idxBattler >= @battlers.length
			next if !@battlers[idxBattler] || pbOwnedByPlayer?(idxBattler) != isPlayer
			next if @choices[idxBattler][0] != :None    # Action is forced, can't choose one
			next if !pbCanShowCommands?(idxBattler)   # Action is forced, can't choose one
			if !@controlPlayer && pbOwnedByPlayer?(idxBattler)
				# Player chooses an action
				actioned.push(idxBattler)
				commandsEnd = false   # Whether to cancel choosing all other actions this round
				loop do
					cmd = pbCommandMenu(idxBattler, actioned.length == 1)
					# If being Sky Dropped, can't do anything except use a move
					if cmd > 0 && @battlers[idxBattler].effects[PBEffects::SkyDrop] >= 0
						pbDisplay(_INTL("Sky Drop won't let {1} go!", @battlers[idxBattler].pbThis(true)))
						next
					end
					case cmd
					when 0    # Fight
						break if pbFightMenu(idxBattler)
					when 1    # Bag
						if pbItemMenu(idxBattler, actioned.length == 1)
							commandsEnd = true if pbItemUsesAllActions?(@choices[idxBattler][1])
							break
						end
					when 2    # Pokémon
						break if pbPartyMenu(idxBattler)
					when 3    # Run
						# NOTE: "Run" is only an available option for the first battler the
						#       player chooses an action for in a round. Attempting to run
						#       from battle prevents you from choosing any other actions in
						#       that round.
						if pbRunMenu(idxBattler)
							commandsEnd = true
							break
						end
					when 4    # Call
						break if pbCallMenu(idxBattler)
					when -2   # Debug
						pbDebugMenu
						next
					when -1   # Go back to previous battler's action choice
						next if actioned.length <= 1
						actioned.pop   # Forget this battler was done
						idxBattler = actioned.last - 1
						pbCancelChoice(idxBattler + 1)   # Clear the previous battler's choice
						actioned.pop   # Forget the previous battler was done
						break
					end
					pbCancelChoice(idxBattler)
				end
			else 
				# DemICE moved the AI decision after player decision.
				# AI controls this battler
                print(@battlers[0].pokemon)
				@battleAI.pbDefaultChooseEnemyCommand(idxBattler)
			end 
			break if commandsEnd
		end
	end
end

# class Battle::Battler
#     def inspect
#         attributes = instance_variables.map do |var|
#           value = instance_variable_get(var)
#           "#{var}=#{value.inspect}"
#         end
        
#         "#<#{self.class}:#{object_id} #{attributes.join(', ')}>"
#       end
# end

class Battle::Move
  
    def pbReduceDamage(user, target)
		damage = target.damageState.calcDamage
		echo "damage initial: #{damage}\n"
		# Substitute takes the damage
		if target.damageState.substitute
		  damage = target.effects[PBEffects::Substitute] if damage > target.effects[PBEffects::Substitute]
		  target.damageState.hpLost       = damage
		  target.damageState.totalHPLost += damage
		  return damage
		end
		# Disguise/Ice Face takes the damage
		return if target.damageState.disguise || target.damageState.iceFace
		# Target takes the damage
		if damage >= target.hp
		  damage = target.hp
		  # Survive a lethal hit with 1 HP effects
		  if nonLethal?(user, target)
			damage -= 1
		  elsif target.effects[PBEffects::Endure]
			target.damageState.endured = true
			damage -= 1
		  elsif damage == target.totalhp
			if target.hasActiveAbility?(:STURDY) && !@battle.moldBreaker
			  target.damageState.sturdy = true
			  damage -= 1
			elsif target.hasActiveItem?(:FOCUSSASH) && target.hp == target.totalhp
			  target.damageState.focusSash = true
			  damage -= 1
			elsif target.hasActiveItem?(:FOCUSBAND) && @battle.pbRandom(100) < 10
			  target.damageState.focusBand = true
			  damage -= 1
			elsif Settings::AFFECTION_EFFECTS && @battle.internalBattle &&
				  target.pbOwnedByPlayer? && !target.mega?
			  chance = [0, 0, 0, 10, 15, 25][target.affection_level]
			  if chance > 0 && @battle.pbRandom(100) < chance
				target.damageState.affection_endured = true
				damage -= 1
			  end
			end
		  end
		end
		damage = 0 if damage < 0
		target.damageState.hpLost       = damage
		target.damageState.totalHPLost += damage
		echo "pbreduce dmg after: #{damage}\n"
		return damage
    end
end

# class Battle::AI
# 	alias old_pbDefaultChooseEnemyCommand pbDefaultChooseEnemyCommand
# 	def pbDefaultChooseEnemyCommand(idxBattler)
# 		pbProcessAITurn
# 		pbChooseMoves(idxBattler)
# 	end
# end

class GoatAI
	def pbDefaultChooseEnemyCommand(idxBattler)
		pbProcessAITurn
		# Battle::AI.pbDefaultChooseEnemyCommand(idxBattler)
	end
end