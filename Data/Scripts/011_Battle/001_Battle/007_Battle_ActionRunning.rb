class Battle
  #=============================================================================
  # Running from battle
  #=============================================================================
  def pbCanRun?(idxBattler)
    return false if trainerBattle?
    battler = @battlers[idxBattler]
    return false if !@canRun && !battler.opposes?
    return true if battler.pbHasType?(:GHOST) && Settings::MORE_TYPE_EFFECTS
    return true if battler.abilityActive? &&
                   Battle::AbilityEffects.triggerCertainEscapeFromBattle(battler.ability, battler)
    return true if battler.itemActive? &&
                   Battle::ItemEffects.triggerCertainEscapeFromBattle(battler.item, battler)
    return false if battler.trappedInBattle?
    allOtherSideBattlers(idxBattler).each do |b|
      return false if b.abilityActive? &&
                      Battle::AbilityEffects.triggerTrappingByTarget(b.ability, battler, b, self)
      return false if b.itemActive? &&
                      Battle::ItemEffects.triggerTrappingByTarget(b.item, battler, b, self)
    end
    return true
  end

  # Return values:
  # -1: Failed fleeing
  #  0: Wasn't possible to attempt fleeing, continue choosing action for the round
  #  1: Succeeded at fleeing, battle will end
  # duringBattle is true for replacing a fainted Pokémon during the End Of Round
  # phase, and false for choosing the Run command.
  def pbRun(idxBattler, duringBattle = false)
    battler = @battlers[idxBattler]
    if battler.opposes?
      return 0 if trainerBattle?
      @choices[idxBattler][0] = :Run
      @choices[idxBattler][1] = 0
      @choices[idxBattler][2] = nil
      return -1
    end
    # Fleeing from trainer battles
    if trainerBattle?
      if $DEBUG && Input.press?(Input::CTRL)
        if pbDisplayConfirm(_INTL("Treat this battle as a win?"))
          @decision = 1
          return 1
        elsif pbDisplayConfirm(_INTL("Treat this battle as a loss?"))
          @decision = 2
          return 1
        end
      #elsif @internalBattle
      #  pbDisplayPaused(_INTL("No! There's no running from a Trainer battle!"))
      elsif pbDisplayConfirm(_INTL("Would you like to forfeit the match and quit now?"))
        pbSEPlay("Battle flee")
        pbDisplay(_INTL("{1} forfeited the match!", self.pbPlayer.name))
        if @noforfeit
          @decision = 2
          @moneyGain = false if !@alwayslosemoney
        else
          @decision = 6
        end
        # @canLose = false
        # $game_temp.battle_rules["canLose"] = false
        return 1
      end
      return 0
    end
    # Fleeing from wild battles
    if $DEBUG && Input.press?(Input::CTRL)
      pbSEPlay("Battle flee")
      pbDisplayPaused(_INTL("You got away safely!"))
      @decision = 3
      return 1
    end
    if !@canRun
      pbDisplayPaused(_INTL("You can't escape!"))
      return 0
    end
    if !duringBattle
      if battler.pbHasType?(:GHOST) && Settings::MORE_TYPE_EFFECTS
        pbSEPlay("Battle flee")
        pbDisplayPaused(_INTL("You got away safely!"))
        @decision = 3
        return 1
      end
      # Abilities that guarantee escape
      if battler.abilityActive? &&
         Battle::AbilityEffects.triggerCertainEscapeFromBattle(battler.ability, battler)
        pbShowAbilitySplash(battler, true)
        pbHideAbilitySplash(battler)
        pbSEPlay("Battle flee")
        pbDisplayPaused(_INTL("You got away safely!"))
        @decision = 3
        return 1
      end
      # Held items that guarantee escape
      if battler.itemActive? &&
         Battle::ItemEffects.triggerCertainEscapeFromBattle(battler.item, battler)
        pbSEPlay("Battle flee")
        pbDisplayPaused(_INTL("{1} fled using its {2}!", battler.pbThis, battler.itemName))
        @decision = 3
        return 1
      end
      # Other certain trapping effects
      if battler.trappedInBattle?
        pbDisplayPaused(_INTL("You can't escape!"))
        return 0
      end
      # Trapping abilities/items
      allOtherSideBattlers(idxBattler).each do |b|
        next if !b.abilityActive?
        if Battle::AbilityEffects.triggerTrappingByTarget(b.ability, battler, b, self)
          pbDisplayPaused(_INTL("{1} prevents escape with {2}!", b.pbThis, b.abilityName))
          return 0
        end
      end
      allOtherSideBattlers(idxBattler).each do |b|
        next if !b.itemActive?
        if Battle::ItemEffects.triggerTrappingByTarget(b.item, battler, b, self)
          pbDisplayPaused(_INTL("{1} prevents escape with {2}!", b.pbThis, b.itemName))
          return 0
        end
      end
    end
    # Fleeing calculation
    # Get the speeds of the Pokémon fleeing and the fastest opponent
    # NOTE: Not pbSpeed, because using unmodified Speed.
    @runCommand += 1 if !duringBattle   # Make it easier to flee next time
    speedPlayer = @battlers[idxBattler].speed
    speedEnemy = 1
    allOtherSideBattlers(idxBattler).each do |b|
      speed = b.speed
      speedEnemy = speed if speedEnemy < speed
    end
    # Compare speeds and perform fleeing calculation
    if speedPlayer > speedEnemy
      rate = 256
    else
      rate = (speedPlayer * 128) / speedEnemy
      rate += @runCommand * 30
    end
    if rate >= 256 || @battleAI.pbAIRandom(256) < rate
      pbSEPlay("Battle flee")
      pbDisplayPaused(_INTL("You got away safely!"))
      @decision = 3
      return 1
    end
    pbDisplayPaused(_INTL("You couldn't get away!"))
    return -1
  end
end
