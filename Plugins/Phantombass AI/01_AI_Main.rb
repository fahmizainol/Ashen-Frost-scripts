module Phantombass_AI
  VERSION = '9.0'
end

class PBAI
  attr_reader :battle, :sides

  # If this is true, the AI will know your moves, held items, and abilities
  # before they are revealed.
  OMNISCIENT_AI = true
  AI_KNOWS_ABILITY = true

  def initialize(battle, wild_battle)
    @battle = battle
    @sides = [Side.new(self, 0), Side.new(self, 1, wild_battle)]
    $d_switch = 0
    $doubles_switch = nil
    $switch_flags = {}
    $self_calc = {}
    $chosen_move = nil
    $spam_block_flags = {
      haze_flag: [], # A pokemon has haze, so the AI registers what mon knows Haze until it is gone
      switches: [],
      moves: [],
      flags_set: [],
      triple_switch: [], # Player switches 3 times in a row
      no_attacking: [], # Target has no attacking moves
      double_recover: [], # Target uses a recovery move twice in a row
      choiced_flag: [], # Target is choice-locked
      same_move: [], # Target uses same move 3 times in a row
      initiative_flag: [], # Target uses an initiative move 2 times in a row
      double_intimidate: [], # Target pivots between 2 Intimidators
      protect_switch: [],
      no_priority_flag: [],
      fake_out_ghost_flag: [],
      yawn: [],
      protect_switch_add: 0,
      yawn_add: 0,
      choice: nil,
      counter: 0
    }
    $learned_flags = {
      setup_fodder: [],
      has_setup: [],
      should_taunt: [],
      move: nil
    }
    $ai_flags = {}
    $threat_flags = {}
    $threat_scores = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
    $spam_block_triggered = false
    $test_trigger = false
    $score_msg = ''
    PBAI.log('AI initialized')
  end

  def self.spam_block_reset
    $spam_block_flags[:triple_switch] = []
    $spam_block_flags[:double_recover] = []
    $spam_block_flags[:same_move] = []
    $spam_block_flags[:initiative_flag] = []
    $spam_block_flags[:protect_switch] = []
    $spam_block_flags[:fake_out_ghost_flag] = []
    $spam_block_flags[:yawn] = []
    $spam_block_flags[:yawn_add] = 0
    $spam_block_flags[:protect_switch_add] = 0
  end

  def self.spam_block_countdown
    $spam_block_flags[:counter] -= 1
    $spam_block_triggered = false if $spam_block_flags[:counter] == 0
  end

  def self.spam_block_add(num)
    $spam_block_flags[:counter] += num
  end

  def self.battler_to_proj_index(battlerIndex)
    if battlerIndex.even? # Player side: 0, 2, 4 -> 0, 1, 2
      battlerIndex / 2
    else # Opponent side: 1, 3, 5 -> 0, 1, 2
      (battlerIndex - 1) / 2
    end
  end

  def self.weighted_rand(weights)
    num = rand(weights.sum)
    for i in 0...weights.size
      return i if num < weights[i]

      num -= weights[i]

    end
    nil
  end

  def self.get_weights(factor, weights)
    avg = (weights.sum / weights.size).to_f
    weights.map do |e|
      diff = e - avg
      ret = begin
        [0, ((e - diff * factor) * 100).floor].max
      rescue StandardError
        FloatDomainError
      end
      next 0 if ret.nil?

      next ret
    end
  end

  def self.weighted_factored_rand(factor, weights)
    avg = (weights.sum / weights.size).to_f
    test = 0
    lower_test = 0
    weights.each do |w|
      test += 1 if w > weights.sum / 2
    end
    weights.each do |x|
      lower_test += 1 if x >= weights.sum * 0.3
    end
    newweights = weights.map do |e|
      e = 0 if e < weights.sum / 2 && test > 0
      e = 0 if e < weights.sum * 0.3 && lower_test > 0
      diff = e - avg
      next 0 unless (e - diff) >= 0

      ret = begin
        [0, ((e - diff * factor) * 100).floor].max
      rescue StandardError
        FloatDomainError
      end
      next 0 if ret.nil?

      next ret
    end
    weighted_rand(newweights)
  end

  def self.move_choice(scores)
    choices = []
    idx = 0
    for i in 0...scores.length
      choices.push(idx) if scores[i] > 0
      idx += 1
    end
    if choices.length > 1
      newlist = []
      choicestemp = []
      choices.each do |choice|
        choicestemp.push(scores[choice])
        choicestemp.push(choice)
        newlist.push(choicestemp)
        choicestemp = []
      end
      newlist.sort! do |a, b|
        ret = (b[0] <=> a[0])
        next ret
      end
      newlist[0][1]
    else
      choices[0]
    end
  end

  def self.log(msg)
    echoln msg
  end

  def self.log_ai(msg)
    echoln '[AI] ' + msg
  end

  def self.log_switch(pkmn, msg)
    echoln "[Switch][#{pkmn}] " + msg
  end

  def self.log_switch_out(score, msg)
    mod = score < 0 ? '' : '+'
    echoln "[Switch] #{mod}#{score}: " + msg
  end

  def battler_to_projection(battler)
    @sides.each do |side|
      side.battlers.each do |projection|
        return projection if projection && projection.pokemon == battler.pokemon
      end
      side.party.each do |projection|
        return projection if projection && projection.pokemon == battler.pokemon
      end
    end
    nil
  end

  # NOTE: Seems like this is returning Battler based on the passed pokemon
  def pokemon_to_projection(pokemon)
    @sides.each do |side|
      side.battlers.each do |projection|
        return projection if projection && projection.pokemon == pokemon
      end
      side.party.each do |projection|
        return projection if projection && projection.pokemon == pokemon
      end
    end
    nil
  end

  def pbMakeFakeBattler(pokemon, batonpass = false)
    return nil if pokemon.nil?

    pokemon = pokemon.clone
    battler = Battle::Battler.new(@battle, @index)
    return if battler.pokemon == pokemon

    battler.pbInitPokemon(pokemon, @index)
    battler.pbInitEffects(batonpass)
    battler
  end

  def register_damage(move, user, target, damage)
    user = battler_to_projection(user)
    target = battler_to_projection(target)
    user.register_damage_dealt(move, target, damage)
    target.register_damage_taken(move, user, damage)
  end

  def faint_battler(battler)
    # Remove the battler from the AI's list of the active battlers
    @sides.each do |side|
      side.battlers.each_with_index do |proj, index|
        next unless proj && proj.battler == battler

        # Decouple the projection from the battler
        side.recall(battler.index)
        side.battlers[index] = nil
        break
      end
    end
  end

  def end_of_round
    @sides.each { |side| side.end_of_round }
  end

  def reveal_ability(battler)
    @sides.each do |side|
      side.battlers.each do |proj|
        next if proj.nil?
        next if proj.fainted?

        next unless proj && proj.battler == battler && !proj.shown_ability

        proj.shown_ability = true
        PBAI.log("#{proj.pokemon.name}'s ability was revealed.")
        break
      end
    end
  end

  def reveal_item(battler)
    @sides.each do |side|
      side.battlers.each do |proj|
        next if proj.nil?
        next if proj.fainted?

        next unless proj.battler == battler && !proj.shown_item

        proj.shown_item = true
        PBAI.log("#{proj.pokemon.name}'s item was revealed.")
        break
      end
    end
  end

  def pbAIRandom(x)
    rand(x)
  end

  # processAIturn in rejuv?
  def pbDefaultChooseEnemyCommand(idxBattler)
    sideIndex = idxBattler % 2
    index = PBAI.battler_to_proj_index(idxBattler)
    side = @sides[sideIndex]
    projection = side.battlers[index]
    # Choose move
    data = projection.choose_move
    if data.nil? && !@battle.wildBattle?
      # Struggle
      @battle.pbAutoChooseMove(idxBattler)
    elsif data.nil? && @battle.wildBattle?
      move = []
      idx = -1
      for i in projection.battler.moves
        idx += 1
        move.push(idx) if i.pp > 0
      end
      if move.length == 0
        @battle.pbAutoChooseMove(idxBattler)
      else
        move_index = move[rand(move.length)]
        move_target = 0
        data = [move_index, move_target]
        @battle.pbRegisterMegaEvolution(idxBattler) if projection.should_mega_evolve?(idxBattler)
        # Register our move
        @battle.pbRegisterMove(idxBattler, move_index, false)
        # Register the move's target
        @battle.pbRegisterTarget(idxBattler, move_target)
      end
    elsif data[0] == :SWITCH
      # [:SWITCH, pokemon_index]
      @battle.pbRegisterSwitch(idxBattler, data[1])
    # elsif data[0] == :FLEE
    #   pbSEPlay("Battle flee")
    #   @battle.pbDisplay(_INTL("{1} fled from battle!",projection.pbThis))
    #   @battle.decision = 3
    #   @battle.scene.clearMessageWindow
    #   @battle.scene.pbEndBattle(@battle.decision)
    else
      # [move_index, move_target]
      if data[0] == :ITEM
        move = []
        idx = -1
        for i in projection.battler.moves
          idx += 1
          move.push(idx) if i.pp > 0
        end
        if move.length == 0
          @battle.pbAutoChooseMove(idxBattler)
        else
          move_index = move[rand(move.length)]
          move_target = 0
          data = [move_index, move_target]
        end
      end
      move_index, move_target = data if move_index.nil?
      # Mega evolve if we determine that we should
      @battle.pbRegisterMegaEvolution(idxBattler) if projection.should_mega_evolve?(idxBattler)
      # Register our move
      @battle.pbRegisterMove(idxBattler, move_index, false)
      # Register the move's target
      @battle.pbRegisterTarget(idxBattler, move_target)
    end
  end

  #=============================================================================
  # Choose a replacement Pokémon
  #=============================================================================
  def pbDefaultChooseNewEnemy(idxBattler, party)
    proj = battler_to_projection(@battle.battlers[idxBattler])
    scores = proj.get_best_switch_choice
    scores.each do |_, _, proj|
      pkmn = proj.pokemon
      index = @battle.pbParty(idxBattler).index(pkmn)
      return index if @battle.pbCanSwitchLax?(idxBattler, index)
    end
    -1
  end

  class AI_Move
    attr_accessor :ai, :battler, :target, :move, :type, :ai_index, :side, :pokemon, :powerBoost, :category, :function,
                  :flags

    def initialize(ai, move)
      @ai = ai
      @battle = @ai.battle
      @move = move
      @type = move.type
      @battler = nil
      @ai_index = nil
      @powerBoost = false
      @category = move.category
      @function = move.function
      @flags = {}
    end

    def self.setup_move?(move)
      list = %i[SWORDSDANCE WORKUP NASTYPLOT GROWTH HOWL BULKUP CALMMIND TAILGLOW AGILITY ROCKPOLISH AUTOTOMIZE
                SHELLSMASH SHIFTGEAR QUIVERDANCE VICTORYDANCE CLANGOROUSSOUL CHARGE COIL HONECLAWS IRONDEFENSE COSMICPOWER AMNESIA DRAGONDANCE
                FILLETAWAY BELLYDRUM CURSE TIDYUP]
      m = move.is_a?(Symbol) ? move : move.id
      list.include?(m)
    end

    def self.defense_setup_move?(move)
      list = %i[BULKUP CALMMIND QUIVERDANCE VICTORYDANCE CLANGOROUSSOUL CHARGE COIL IRONDEFENSE COSMICPOWER
                AMNESIA CURSE]
      m = move.is_a?(Symbol) ? move : move.id
      list.include?(m)
    end

    def self.offense_setup_move?(move)
      list = %i[SWORDSDANCE WORKUP NASTYPLOT GROWTH HOWL BULKUP CALMMIND TAILGLOW SHELLSMASH SHIFTGEAR QUIVERDANCE VICTORYDANCE
                CLANGOROUSSOUL CHARGE COIL HONECLAWS IRONDEFENSE COSMICPOWER AMNESIA DRAGONDANCE CURSE TIDYUP]
      m = move.is_a?(Symbol) ? move : move.id
      list.include?(m)
    end

    def self.speed_setup_move?(move)
      list = %i[AGILITY ROCKPOLISH AUTOTOMIZE SHELLSMASH SHIFTGEAR QUIVERDANCE VICTORYDANCE CLANGOROUSSOUL
                DRAGONDANCE FILLETAWAY TIDYUP]
      m = move.is_a?(Symbol) ? move : move.id
      list.include?(m)
    end

    def self.status_condition_move?(move)
      list = %i[WILLOWISP DEEPFREEZE SPORE SING SLEEPPOWDER YAWN HYPNOSIS DARKVOID POISONGAS TOXIC
                POISONPOWDER TOXICTHREAD GLARE THUNDERWAVE STUNSPORE]
      m = move.is_a?(Symbol) ? move : move.id
      list.include?(m)
    end

    def self.weather_terrain_move?(move)
      list = %i[RAINDANCE SUNNYDAY SNOWSCAPE HAIL SANDSTORM CHILLYRECEPTION ELECTRICTERRAIN MISTYTERRAIN
                PSYCHICTERRAIN GRASSYTERRAIN]
      m = move.is_a?(Symbol) ? move : move.id
      list.include?(m)
    end

    def pbBaseType(user)
      ret = @type
      ret = PBAI::AbilityEffects.triggerModifyMoveBaseType(user.ability, user, @move, ret) if ret
      ret
    end

    def pbBaseDamage(baseDmg, user, target)
      move = @move
      baseDmg = move.baseDamage
      # baseDmg = 60 if baseDmg == 1
      # Covers all function codes which have their own def pbBaseDamage
      case @function
      # Sonic Boom, Dragon Rage, Super Fang, Night Shade, Endeavor
      when 'FixedDamage20', 'FixedDamage40', 'FixedDamageHalfTargetHP',
           'FixedDamageUserLevel', 'LowerTargetHPToUserHP'
        baseDmg = move.pbFixedDamage(user, target)
      when 'FixedDamageUserLevelRandom' # Psywave
        baseDmg = user.level
      when 'OHKO', 'OHKOIce', 'OHKOHitsUndergroundTarget'
        baseDmg = 200
      when 'CounterPhysicalDamage', 'CounterSpecialDamage', 'CounterDamagePlusHalf'
        baseDmg = 60
      # when "IncreasePowerEachFaintedAlly"
      #  baseDmg =
      when 'DoublePowerIfTargetUnderwater', 'DoublePowerIfTargetUnderground',
           'BindTargetDoublePowerIfTargetUnderwater'
        baseDmg = move.pbModifyDamage(baseDmg, user, target)
      # Gust, Twister, Venoshock, Smelling Salts, Wake-Up Slap, Facade, Hex, Brine,
      # Retaliate, Weather Ball, Return, Frustration, Eruption, Crush Grip,
      # Stored Power, Punishment, Hidden Power, Fury Cutter, Echoed Voice,
      # Trump Card, Flail, Electro Ball, Low Kick, Fling, Spit Up
      when 'DoublePowerIfTargetInSky',
           'FlinchTargetDoublePowerIfTargetInSky',
           'DoublePowerIfTargetPoisoned',
           'DoublePowerIfTargetParalyzedCureTarget',
           'DoublePowerIfTargetAsleepCureTarget',
           'DoublePowerIfUserPoisonedBurnedParalyzed',
           'DoublePowerIfTargetStatusProblem',
           'DoublePowerIfTargetHPLessThanHalf',
           'DoublePowerIfAllyFaintedLastTurn',
           'TypeAndPowerDependOnWeather',
           'PowerHigherWithUserHappiness',
           'PowerLowerWithUserHappiness',
           'PowerHigherWithUserHP',
           'PowerHigherWithTargetHP',
           'PowerHigherWithUserPositiveStatStages',
           'PowerHigherWithTargetPositiveStatStages',
           'TypeDependsOnUserIVs',
           'PowerHigherWithConsecutiveUse',
           'PowerHigherWithConsecutiveUseOnUserSide',
           'PowerHigherWithLessPP',
           'PowerLowerWithUserHP',
           'PowerHigherWithUserFasterThanTarget',
           'PowerHigherWithTargetWeight',
           'ThrowUserItemAtTarget',
           'PowerDependsOnUserStockpile',
           'IncreasePowerEachFaintedAlly',
           'IncreasePowerEachTimeHit',
           'DoublePowerInElectricTerrain',
           'DoublePowerInMistyTerrain',
           'UserFaintsPowersUpInMistyTerrainExplosive',
           'HitsAllFoesAndPowersUpInPsychicTerrain'
        baseDmg = move.pbBaseDamage(baseDmg, user, target)
      when 'DoublePowerIfUserHasNoItem' # Acrobatics
        baseDmg *= 2 if !user.item || user.hasActiveItem?(:FLYINGGEM)
      when 'PowerHigherWithTargetFasterThanUser' # Gyro Ball
        targetSpeed = target.effective_speed
        userSpeed = user.effective_speed
        baseDmg = [[(25 * targetSpeed / userSpeed).floor, 150].min, 1].max
      when 'RandomlyDamageOrHealTarget' # Present
        baseDmg = 50
      when 'RandomPowerDoublePowerIfTargetUnderground' # Magnitude
        baseDmg = 71
        baseDmg *= 2 if target.inTwoTurnAttack?('TwoTurnAttackInvulnerableUnderground') # Dig
      when 'TypeAndPowerDependOnUserBerry' # Natural Gift
        baseDmg = move.pbNaturalGiftBaseDamage(user.item_id)
      when 'PowerHigherWithUserHeavierThanTarget' # Heavy Slam
        baseDmg = move.pbBaseDamage(baseDmg, user, target)
        baseDmg *= 2 if Settings::MECHANICS_GENERATION >= 7 && target.effects[PBEffects::Minimize]
      when 'AlwaysCriticalHit', 'HitTwoTimes', 'HitTwoTimesPoisonTarget' # Frost Breath, Double Kick, Twineedle
        baseDmg *= 2
      when 'HitThreeTimesPowersUpWithEachHit' # Triple Kick
        baseDmg *= 6 # Hits do x1, x2, x3 baseDmg in turn, for x6 in total
      when 'HitTwoToFiveTimes' # Fury Attack
        if user.hasActiveAbility?(:SKILLLINK)
          baseDmg *= 5
        else
          baseDmg = (baseDmg * 31 / 10).floor # Average damage dealt
        end
      when 'HitTwoToFiveTimesOrThreeForAshGreninja'
        if user.isSpecies?(:GRENINJA) && user.form == 2
          baseDmg *= 4 # 3 hits at 20 power = 4 hits at 15 power
        elsif user.hasActiveAbility?(:SKILLLINK)
          baseDmg *= 5
        else
          baseDmg = (baseDmg * 31 / 10).floor # Average damage dealt
        end
      # when "HitOncePerUserTeamMember"   # Beat Up
      #   mult = 0
      #   party = @battle.pbParty(user.index)
      #   party.each do |pkmn|
      #     mult += 1 if pkmn&.able? && pkmn.status == :NONE
      #   end
      #   baseDmg *= mult
      when 'HitOncePerUserTeamMember' # DemICE beat up was being calculated very wrong.
        beatUpList = []
        @battle.eachInTeamFromBattlerIndex(user.index) do |pkmn, i|
          next if !pkmn.able? || pkmn.status != :NONE

          beatUpList.push(i)
        end
        baseDmg = 0
        for i in beatUpList
          atk = @battle.pbParty(user.index)[i].baseStats[:ATTACK]
          # echoln "atk: #{atk}"
          baseDmg += 5 + (atk / 10)
        end
        # echoln "beatup baseDmg: #{baseDmg}"
        baseDmg *= 1.5 if user.hasActiveAbility?(:TECHNICIAN)
      when 'TwoTurnAttackOneTurnInSun' # Solar Beam
        baseDmg = move.pbBaseDamageMultiplier(baseDmg, user, target)
      when 'MultiTurnAttackPowersUpEachTurn' # Rollout
        baseDmg *= 2 if user.effects[PBEffects::DefenseCurl]
      when 'MultiTurnAttackBideThenReturnDoubleDamage' # Bide
        baseDmg = 40
      when 'UserFaintsFixedDamageUserHP' # Final Gambit
        baseDmg = user.hp
      when 'EffectivenessIncludesFlyingType'   # Flying Press
        if GameData::Type.exists?(:FLYING)
          targetTypes = target.pbTypes(true)
          mult = Effectiveness.calculate(
            :FLYING, targetTypes[0], targetTypes[1], targetTypes[2]
          )
          baseDmg = (baseDmg.to_f * mult / Effectiveness::NORMAL_EFFECTIVE).round
        end
        baseDmg *= 2 if target.effects[PBEffects::Minimize]
      when 'DoublePowerIfUserLastMoveFailed'   # Stomping Tantrum
        baseDmg *= 2 if user.lastRoundMoveFailed
      when 'HitTwoTimesFlinchTarget' # Double Iron Bash
        baseDmg *= 2
        baseDmg *= 2 if target.effects[PBEffects::Minimize]
      end
      baseDmg
    end

    def pbBaseDamageMultiplier(damageMult, user, target)
      damageMult
    end

    def pbModifyDamage(damageMult, user, target)
      damageMult
    end

    def pbGetAttackStats(user, target)
      if @move.specialMove?
        return user.attack, user.stages[:SPECIAL_ATTACK] + 6 if user.hasActiveAbility?(:VOCALFRY) && @move.soundMove?

        return user.spatk, user.stages[:SPECIAL_ATTACK] + 6
      end
      [user.attack, user.stages[:ATTACK] + 6]
    end

    def pbGetDefenseStats(user, target)
      return target.spdef, target.stages[:SPECIAL_DEFENSE] + 6 if @move.specialMove?

      [target.defense, target.stages[:DEFENSE] + 6]
    end

    def pbCritialOverride(user, target)
      0
    end

    def pbIsCritical?(user, target)
      return false if target.item == :MITHRILSHIELD && !%w[AlwaysCriticalHit
                                                           HitThreeTimesAlwaysCriticalHit].include?(@move.function)
      return false if target.pbOwnSide.effects[PBEffects::LuckyChant] > 0

      # Set up the critical hit ratios
      ratios = Settings::NEW_CRITICAL_HIT_RATE_MECHANICS ? [24, 8, 2, 1] : [16, 8, 4, 3, 2]
      c = 0
      # Ability effects that alter critical hit rate
      if c >= 0 && user.abilityActive?
        c = PBAI::AbilityEffects.triggerCriticalCalcFromUser(user.ability, user, target, c)
      end
      if c >= 0 && target.abilityActive? && !@battle.moldBreaker
        c = PBAI::AbilityEffects.triggerCriticalCalcFromTarget(target.ability, user, target, c)
      end
      # Item effects that alter critical hit rate
      c = PBAI::ItemEffects.triggerCriticalCalcFromUser(user.item, user, target, c) if c >= 0 && user.itemActive?
      c = PBAI::ItemEffects.triggerCriticalCalcFromTarget(target.item, user, target, c) if c >= 0 && target.itemActive?
      return false if c < 0

      # Move-specific "always/never a critical hit" effects
      case pbCritialOverride(user, target)
      when 1  then return true
      when -1 then return false
      end
      # Other effects
      return true if c > 50 # Merciless
      return true if user.effects[PBEffects::LaserFocus] > 0

      c += 1 if @move.highCriticalRate?
      c += user.effects[PBEffects::FocusEnergy]
      c += 1 if user.inHyperMode? && @move.type == :SHADOW
      c = ratios.length - 1 if c >= ratios.length
      # Calculation
      return true if ratios[c] == 1

      r = @battle.pbRandom(ratios[c])
      return true if r == 0

      if r == 1 && Settings::AFFECTION_EFFECTS && @battle.internalBattle &&
         user.pbOwnedByPlayer? && user.affection_level == 5 && !target.mega?
        target.damageState.affection_critical = true
        return true
      end
      false
    end

    def pbCalcType(user)
      @powerBoost = false
      ret = @move.pbBaseType(user)
      if ret && GameData::Type.exists?(:ELECTRIC)
        if @battle.field.effects[PBEffects::IonDeluge] && ret == :NORMAL
          ret = :ELECTRIC
          @powerBoost = false
        end
        if user.effects[PBEffects::Electrify]
          ret = :ELECTRIC
          @powerBoost = false
        end
      end
      ret
    end

    def pbCalcTypeMod(moveType, user, target)
      # echoln "moveType: #{moveType}"
      # echoln "user: #{user.name}"
      # echoln "target: #{target.name}"
      return Effectiveness::NORMAL_EFFECTIVE unless moveType
      return Effectiveness::NORMAL_EFFECTIVE if moveType == :GROUND &&
                                                target.pbHasType?(:FLYING) &&
                                                target.hasActiveItem?(:IRONBALL)

      # Determine types
      tTypes = target.pbTypes(true)
      # Get effectivenesses
      typeMods = [Effectiveness::NORMAL_EFFECTIVE_ONE] * 3 # 3 types max
      if moveType == :SHADOW
        typeMods[0] = if target.shadowPokemon?
                        Effectiveness::NOT_VERY_EFFECTIVE_ONE
                      else
                        Effectiveness::SUPER_EFFECTIVE_ONE
                      end
      else
        tTypes.each_with_index do |type, i|
          typeMods[i] = pbCalcTypeModSingle(moveType, type, user, target)
        end
      end
      # Multiply all effectivenesses together
      ret = 1
      typeMods.each { |m| ret *= m }
      ret *= 2 if target.effects[PBEffects::TarShot] && moveType == :FIRE
      if target.hasActiveAbility?(:TERASHELL) || target.hasActiveAbility?(:REVERSEROOM) || target.hasActiveAbility?(:TERAFORMZERO2)
        ret = PBAI::AbilityEffects.triggerModifyTypeEffectiveness(target.ability, user, target, @move, @battle, ret)
      end
      ret
    end

    def pbCalcTypeModSingle(moveType, defType, user, target)
      ret = Effectiveness.calculate_one(moveType, defType)
      if Effectiveness.ineffective_type?(moveType, defType)
        # Ring Target
        ret = Effectiveness::NORMAL_EFFECTIVE_ONE if target.hasActiveItem?(:RINGTARGET)
        # Foresight
        if (user.hasActiveAbility?(:SCRAPPY) || target.effects[PBEffects::Foresight]) &&
           defType == :GHOST
          ret = Effectiveness::NORMAL_EFFECTIVE_ONE
        end
        if user.hasActiveAbility?(:NITRIC) && defType == :STEEL && @move.pbDamagingMove?
          ret = Effectiveness::NORMAL_EFFECTIVE_ONE
        end
        if user.hasActiveAbility?(:SLAYER) && defType == :FAIRY && @move.pbDamagingMove?
          ret = Effectiveness::NORMAL_EFFECTIVE_ONE
        end
        # KIV
        if target.airborne? && moveType == :GROUND
          # if target.airborne? && @move.boneMove? && moveType == :GROUND
          ret = Effectiveness::NORMAL_EFFECTIVE_ONE
        end
        # Miracle Eye
        ret = Effectiveness::NORMAL_EFFECTIVE_ONE if target.effects[PBEffects::MiracleEye] && defType == :DARK
      elsif Effectiveness.super_effective_type?(moveType, defType)
        # Delta Stream's weather
        ret = Effectiveness::NORMAL_EFFECTIVE_ONE if target.effectiveWeather == :StrongWinds && defType == :FLYING
      end
      if defType == :WATER && @move.function == 'FreezeTargetSuperEffectiveAgainstWater'
        ret = Effectiveness::SUPER_EFFECTIVE_ONE
      end
      ret = Effectiveness::SUPER_EFFECTIVE_ONE if defType == :ICE && @move.function == 'ScaldSuperEffectiveAgainstIce'
      if defType == :ELECTRIC && @move.function == 'SuperEffectiveAgainstElectric'
        ret = Effectiveness::SUPER_EFFECTIVE_ONE
      end
      ret = Effectiveness::NORMAL_EFFECTIVE_ONE if defType == :FAIRY && @move.function == 'EffectiveAgainstFairy'
      ret = Effectiveness::NORMAL_EFFECTIVE_ONE if defType == :GROUND && @move.function == 'EffectiveAgainstElectric'
      # Grounded Flying-type Pokémon become susceptible to Ground moves
      ret = Effectiveness::NORMAL_EFFECTIVE_ONE if !target.airborne? && defType == :FLYING && moveType == :GROUND
      ret
    end

    def pbCalcDamage(user, target, numTargets = 1)
      return 0 if @move.statusMove?

      $test_trigger = true
      if target.damageState.disguise || target.damageState.iceFace
        dmg = 1
        return dmg
      end
      stageMul = [2, 2, 2, 2, 2, 2, 2, 3, 4, 5, 6, 7, 8]
      stageDiv = [8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2]
      # Get the move's type
      type = @move.calcType # nil is treated as physical
      # Calculate whether this hit deals critical damage
      target.damageState.critical = pbIsCritical?(user, target)
      # Calcuate base power of move
      # echoln "move name: #{@move.name}"
      # echoln "base dmg b4: #{@move.baseDamage}"
      baseDmg = pbBaseDamage(@move.baseDamage, user, target)
      # echoln "base dmg aft: #{baseDmg}"
      # Calculate user's attack stat
      atk, atkStage = pbGetAttackStats(user, target)
      if !target.hasActiveAbility?(:UNAWARE) || @battle.moldBreaker
        atkStage = 6 if target.damageState.critical && atkStage < 6
        atk = (atk.to_f * stageMul[atkStage] / stageDiv[atkStage]).floor
      end
      # Calculate target's defense stat
      defense, defStage = pbGetDefenseStats(user, target)
      unless user.hasActiveAbility?(:UNAWARE)
        defStage = 6 if target.damageState.critical && defStage > 6
        defense = (defense.to_f * stageMul[defStage] / stageDiv[defStage]).floor
      end
      # Calculate all multiplier effects
      multipliers = {
        base_damage_multiplier: 1.0,
        attack_multiplier: 1.0,
        defense_multiplier: 1.0,
        final_damage_multiplier: 1.0
      }
      mult = pbCalcDamageMultipliers(user, target, numTargets, @move.type, baseDmg, multipliers)

      # Main damage calculation
      baseDmg = [(baseDmg * mult[:base_damage_multiplier]).round, 1].max
      atk     = [(atk     * mult[:attack_multiplier]).round, 1].max
      defense = [(defense * mult[:defense_multiplier]).round, 1].max
      damage  = ((((2.0 * user.level / 5) + 2).floor * baseDmg * atk / defense).floor / 50).floor + 2
      dmg = [(damage * mult[:final_damage_multiplier]).round, 1].max
      # echoln "\nmovename #{@move.name} mult: #{mult} dmg: #{dmg}"
      $test_trigger = false
      dmg
    end

    def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
      %i[TABLETSOFRUIN SWORDOFRUIN VESSELOFRUIN BEADSOFRUIN].each_with_index do |abil, i|
        category = i < 2 ? @move.physicalMove? : @move.specialMove?
        category = !category if i.odd? && @battle.field.effects[PBEffects::WonderRoom] > 0
        mult = i.even? ? multipliers[:attack_multiplier] : multipliers[:defense_multiplier]
        mult *= 0.75 if @battle.pbCheckGlobalAbility(abil) && !user.hasActiveAbility?(abil) && category
      end
      if @battle.field.terrain == :Electric && user.affectedByTerrain? &&
         @function == 'IncreasePowerInElectricTerrain'
        multipliers[:base_damage_multiplier] *= 1.5
      end
      case user.effectiveWeather
      when :Sun, :HarshSun
        if @function == 'IncreasePowerInSunWeather'
          multipliers[:final_damage_multiplier] *= type == :WATER ? 3 : 1.5
        end
      when :Hail
        if Settings::HAIL_WEATHER_TYPE > 0 && target.pbHasType?(:ICE) &&
           (@move.physicalMove? || @move.function == 'UseTargetDefenseInsteadOfTargetSpDef')
          multipliers[:defense_multiplier] *= 1.5
        end
      end
      multipliers[:final_damage_multiplier] /= 2 if %i[FROZEN FROSTBITE].include?(user.status) && @move.specialMove?
      multipliers[:final_damage_multiplier] *= 4 / 3.0 if target.status == :DROWSY
      multipliers[:final_damage_multiplier] *= 2 if target.effects[PBEffects::GlaiveRush] > 0
      # Global abilities
      if (@battle.pbCheckGlobalAbility(:DARKAURA) && type == :DARK) ||
         (@battle.pbCheckGlobalAbility(:FAIRYAURA) && type == :FAIRY) || (@battle.pbCheckGlobalAbility(:GAIAFORCE) && type == :GROUND) || ((@battle.pbCheckGlobalAbility(:FEVERPITCH) || $gym_fever) && type == :POISON)
        multipliers[:base_damage_multiplier] *= if @battle.pbCheckGlobalAbility(:AURABREAK)
                                                  2 / 3.0
                                                else
                                                  4 / 3.0
                                                end
      end
      # Ability effects that alter damage
      if user.abilityActive?
        PBAI::AbilityEffects.triggerDamageCalcFromUser(
          user.ability, user, target, @move, multipliers, baseDmg, type
        )
      end
      unless @battle.moldBreaker
        # NOTE: It's odd that the user's Mold Breaker prevents its partner's
        #       beneficial abilities (i.e. Flower Gift boosting Atk), but that's
        #       how it works.
        user.allAllies.each do |b|
          next unless b.abilityActive?

          PBAI::AbilityEffects.triggerDamageCalcFromAlly(
            b.ability, user, target, @move, multipliers, baseDmg, type
          )
        end
        if target.abilityActive?
          PBAI::AbilityEffects.triggerDamageCalcFromTarget(
            target.ability, user, target, @move, multipliers, baseDmg, type
          )
          PBAI::AbilityEffects.triggerDamageCalcFromTargetNonIgnorable(
            target.ability, user, target, @move, multipliers, baseDmg, type
          )
        end
        target.allAllies.each do |b|
          next unless b.abilityActive?

          PBAI::AbilityEffects.triggerDamageCalcFromTargetAlly(
            b.ability, user, target, @move, multipliers, baseDmg, type
          )
        end
      end
      # Item effects that alter damage
      if user.itemActive?
        PBAI::ItemEffects.triggerDamageCalcFromUser(
          user.item, user, target, @move, multipliers, baseDmg, type
        )
      end
      if target.itemActive?
        PBAI::ItemEffects.triggerDamageCalcFromTarget(
          target.item, user, target, @move, multipliers, baseDmg, type
        )
      end
      # Parental Bond's second attack
      if user.effects[PBEffects::ParentalBond] == 1
        multipliers[:base_damage_multiplier] /= Settings::MECHANICS_GENERATION >= 7 ? 4 : 2
      end
      # if user.effects[PBEffects::EchoChamber] == 1
      #   multipliers[:base_damage_multiplier] /= (Settings::MECHANICS_GENERATION >= 7) ? 4 : 2
      # end
      # if user.effects[PBEffects::Ambidextrous] == 1
      #   multipliers[:base_damage_multiplier] /= (Settings::MECHANICS_GENERATION >= 7) ? 4 : 2
      # end
      # Other
      multipliers[:base_damage_multiplier] *= 1.5 if user.effects[PBEffects::MeFirst]
      if user.effects[PBEffects::HelpingHand] && !@move.is_a?(Battle::Move::Confusion)
        multipliers[:base_damage_multiplier] *= 1.5
      end
      # if (user.effects[PBEffects::Charge] > 0 || user.charge > 0) && type == :ELECTRIC
      #   multipliers[:base_damage_multiplier] *= 2
      # end
      # Mud Sport
      if type == :ELECTRIC
        multipliers[:base_damage_multiplier] /= 3 if @battle.allBattlers.any? { |b| b.effects[PBEffects::MudSport] }
        multipliers[:base_damage_multiplier] /= 3 if @battle.field.effects[PBEffects::MudSportField] > 0
      end
      # Water Sport
      if type == :FIRE
        multipliers[:base_damage_multiplier] /= 3 if @battle.allBattlers.any? { |b| b.effects[PBEffects::WaterSport] }
        multipliers[:base_damage_multiplier] /= 3 if @battle.field.effects[PBEffects::WaterSportField] > 0
      end
      # Terrain moves
      terrain_multiplier = Settings::MECHANICS_GENERATION >= 8 ? 1.3 : 1.5
      case @battle.field.terrain
      when :Electric
        multipliers[:base_damage_multiplier] *= terrain_multiplier if type == :ELECTRIC && user.affectedByTerrain?
      when :Grassy
        multipliers[:base_damage_multiplier] *= terrain_multiplier if type == :GRASS && user.affectedByTerrain?
      when :Psychic
        multipliers[:base_damage_multiplier] *= terrain_multiplier if type == :PSYCHIC && user.affectedByTerrain?
      when :Misty
        multipliers[:base_damage_multiplier] /= 2 if type == :DRAGON && target.affectedByTerrain?
      end
      # Badge multipliers
      if @battle.internalBattle
        if user.pbOwnedByPlayer?
          if @move.physicalMove? && @battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_ATTACK
            multipliers[:attack_multiplier] *= 1.1
          elsif @move.specialMove? && @battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_SPATK
            multipliers[:attack_multiplier] *= 1.1
          end
        end
        if target.pbOwnedByPlayer?
          if @move.physicalMove? && @battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_DEFENSE
            multipliers[:defense_multiplier] *= 1.1
          elsif @move.specialMove? && @battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_SPDEF
            multipliers[:defense_multiplier] *= 1.1
          end
        end
      end
      # Multi-targeting attacks
      multipliers[:final_damage_multiplier] *= 0.75 if numTargets > 1
      # Weather
      case user.effectiveWeather
      when :Sun, :HarshSun
        case type
        when :FIRE
          multipliers[:final_damage_multiplier] *= 1.5
        when :WATER
          multipliers[:final_damage_multiplier] *= 0.5 unless user.hasActiveAbility?(:STEAMPOWERED)
        else
          multipliers[:final_damage_multiplier] *= 1.0
        end
      when :Rain, :HeavyRain
        case type
        when :FIRE
          multipliers[:final_damage_multiplier] *= 0.5 unless user.hasActiveAbility?(:STEAMPOWERED)
        when :WATER
          multipliers[:final_damage_multiplier] *= 1.5
        else
          multipliers[:final_damage_multiplier] *= 1.0
        end
      when :Sandstorm
        if target.pbHasType?(:ROCK) && @move.specialMove? && @move.function != 'UseTargetDefenseInsteadOfTargetSpDef'
          multipliers[:defense_multiplier] *= 1.5
        end
      end
      # Critical hits
      if target.damageState.critical
        multipliers[:final_damage_multiplier] *= if Settings::NEW_CRITICAL_HIT_RATE_MECHANICS
                                                   1.5
                                                 else
                                                   2
                                                 end
      end
      # Random variance
      unless @move.is_a?(Battle::Move::Confusion)
        offset = 5 # to account for low dmg roll prediction
        random = 85 + @battle.pbRandom(9)
        multipliers[:final_damage_multiplier] *= random / 100.0
      end
      # STAB
      if type && user.pbHasType?(type)
        multipliers[:final_damage_multiplier] *= if user.hasActiveAbility?(:ADAPTABILITY)
                                                   2
                                                 else
                                                   1.5
                                                 end
      end
      # Type effectiveness
      # echoln "final damage before: #{multipliers[:final_damage_multiplier]}"
      # echoln "typemod: #{target.damageState.typeMod.to_f}"
      # echoln "effectiveness #{Effectiveness::NORMAL_EFFECTIVE}\n"

      multipliers[:final_damage_multiplier] *= target.damageState.typeMod.to_f / Effectiveness::NORMAL_EFFECTIVE
      # echoln "final damage after: #{multipliers[:final_damage_multiplier]}"

      # Burn
      if user.status == :BURN && @move.physicalMove? && @move.damageReducedByBurn? &&
         !user.hasActiveAbility?(:GUTS)
        multipliers[:final_damage_multiplier] /= 2
      end
      # Aurora Veil, Reflect, Light Screen
      if !@move.ignoresReflect? && !target.damageState.critical &&
         !user.hasActiveAbility?(:INFILTRATOR)
        if target.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
          if @battle.pbSideBattlerCount(target) > 1
            multipliers[:final_damage_multiplier] *= 2 / 3.0
          else
            multipliers[:final_damage_multiplier] /= 2
          end
        elsif target.pbOwnSide.effects[PBEffects::Reflect] > 0 && @move.physicalMove?
          if @battle.pbSideBattlerCount(target) > 1
            multipliers[:final_damage_multiplier] *= 2 / 3.0
          else
            multipliers[:final_damage_multiplier] /= 2
          end
        elsif target.pbOwnSide.effects[PBEffects::LightScreen] > 0 && @move.specialMove?
          if @battle.pbSideBattlerCount(target) > 1
            multipliers[:final_damage_multiplier] *= 2 / 3.0
          else
            multipliers[:final_damage_multiplier] /= 2
          end
        end
      end
      # Minimize
      multipliers[:final_damage_multiplier] *= 2 if target.effects[PBEffects::Minimize] && @move.tramplesMinimize?
      # Move-specific base damage modifiers
      multipliers[:base_damage_multiplier] =
        pbBaseDamageMultiplier(multipliers[:base_damage_multiplier], user, target)
      # Move-specific final damage modifiers
      multipliers[:final_damage_multiplier] = pbModifyDamage(multipliers[:final_damage_multiplier], user, target)
      multipliers
    end
  end

  class AI_Learn
    attr_accessor :battler, :attacker, :opponent, :used_moves, :shown_item, :shown_ability, :ai_index
    attr_reader :side, :pokemon, :calc, :self_calc, :flags

    def initialize(side, pokemon, wild_pokemon = false)
      @side = side
      @pokemon = pokemon
      @battler = nil
      @ai = @side.ai
      @battle = @ai.battle
      @calc = {}
      @self_calc = {}
      @damage_taken = []
      @damage_dealt = []
      @ai_index = nil
      @used_moves = []
      @shown_ability = false
      @shown_item = false
      @skill = wild_pokemon && !$game_switches[990] ? 0 : 200
      @flags = {}
      # @pokemon.assign_roles
    end

    alias original_missing method_missing
    def method_missing(name, *args, &block)
      if @battler.respond_to?(name)
        # PBAI.log("WARNING: Deferring method `#{name}` to @battler.")
        @battler.send(name, *args, &block)
      else
        original_missing(name, *args, &block)
      end
    end

    def opposing_side
      @side.opposing_side
    end

    def index
      return 0 if $spam_block_triggered && @side.index == 0

      @side.index == 0 ? @ai_index * 2 : @ai_index * 2 + 1
    end

    def pbMakeFakeBattler(pokemon, batonpass = false)
      return nil if pokemon.nil?

      pokemon = pokemon.clone
      battler = Battle::Battler.new(@battle, @index)
      battler.pbInitPokemon(pokemon, @index)
      battler.pbInitEffects(batonpass)
      battler
    end

    def pbMakeFakeObject(pokemon)
      return nil if pokemon.nil?

      opposing_side.party.find { |mon| mon && mon.pokemon == pokemon }
    end

    def hp
      @battler.hp
    end

    def fainted?
      @pokemon.fainted?
    end

    def egg?
      @pokemon.egg?
    end

    def roles
      @battler.roles
    end

    def has_role?(role)
      x = []
      for i in @battler.roles
        x.push(i)
        next unless role.is_a?(Array)
        return true if role.include?(i)
      end
      x.include?(role) && !role.is_a?(Array)
    end

    def defensive?
      has_role?(%i[TANK PHAZER SCREENS DEFENSIVEPIVOT OFFENSIVEPIVOT PHYSICALWALL SPECIALWALL
                   TOXICSTALLER STALLBREAKER TRICKROOMSETTER TARGETALLY REDIRECTION CLERIC LEAD SKILLSWAPALLY])
    end

    def setup?
      has_role?(%i[SETUPSWEEPER WINCON PHYSICALBREAKER SPECIALBREAKER])
    end

    def pivot?
      has_role?(%i[DEFENSIVEPIVOT OFFENSIVEPIVOT])
    end

    def priority_blocking?
      hasActiveAbility?(%i[QUEENLYMAJESTY DAZZLING ARMORTAIL])
    end

    def immune_to_status?(target)
      hasActiveAbility?(:GOODASGOLD) || (types.include?(:DARK) && target.hasActiveAbility?(:PRANKSTER))
    end

    def totalhp
      @battler.totalhp
    end

    def status
      @battler.status
    end

    def statusCount
      @battler.statusCount
    end

    def burned?
      @battler.burned?
    end

    def poisoned?
      @battler.poisoned?
    end

    def paralyzed?
      @battler.paralyzed?
    end

    def frozen?
      @battler.frozen?
    end

    def frostbitten?
      @battler.status == :FROSTBITE
    end

    def asleep?
      @battler.asleep?
    end

    def confused?
      @battler.effects[PBEffects::Confusion] > 0
    end

    def level
      @battler.level
    end

    def active?
      !@battler.nil?
    end

    def owned_by_player?
      pokemon.owner.id == $player.id
    end

    def effective_attack
      mon = is_a?(AI_Learn) ? pbMakeFakeBattler(pokemon) : @battler
      stageMul = [2, 2, 2, 2, 2, 2, 2, 3, 4, 5, 6, 7, 8]
      stageDiv = [8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2]
      stage = mon.stages[:ATTACK] + 6
      (mon.attack.to_f * stageMul[stage] / stageDiv[stage]).floor
    end

    def effective_defense
      mon = is_a?(AI_Learn) ? pbMakeFakeBattler(pokemon) : @battler
      stageMul = [2, 2, 2, 2, 2, 2, 2, 3, 4, 5, 6, 7, 8]
      stageDiv = [8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2]
      stage = mon.stages[:DEFENSE] + 6
      (mon.defense.to_f * stageMul[stage] / stageDiv[stage]).floor
    end

    def effective_spatk
      mon = is_a?(AI_Learn) ? pbMakeFakeBattler(pokemon) : @battler
      stageMul = [2, 2, 2, 2, 2, 2, 2, 3, 4, 5, 6, 7, 8]
      stageDiv = [8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2]
      stage = mon.stages[:SPECIAL_ATTACK] + 6
      (mon.spatk.to_f * stageMul[stage] / stageDiv[stage]).floor
    end

    def effective_spdef
      mon = is_a?(AI_Learn) ? pbMakeFakeBattler(pokemon) : @battler
      stageMul = [2, 2, 2, 2, 2, 2, 2, 3, 4, 5, 6, 7, 8]
      stageDiv = [8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2]
      stage = mon.stages[:SPECIAL_DEFENSE] + 6
      (mon.spdef.to_f * stageMul[stage] / stageDiv[stage]).floor
    end

    def effective_speed
      mon = is_a?(AI_Learn) ? pbMakeFakeBattler(pokemon) : @battler
      stageMul = [2, 2, 2, 2, 2, 2, 2, 3, 4, 5, 6, 7, 8]
      stageDiv = [8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2]
      stage = mon.stages[:SPEED] + 6
      stage -= 1 if mon != @battler && mon.pbOwnSide.effects[PBEffects::StickyWeb]
      mults_abil = 1.0
      mults_item = 1.0
      mults = 1.0
      mults_abil = Battle::AbilityEffects.triggerSpeedCalc(mon.ability, mon, mults) if mon.abilityActive?
      # Item effects that alter calculated Speed
      mults_item = Battle::ItemEffects.triggerSpeedCalc(mon.item, mon, mults) if mon.itemActive?
      mults *= 2 if own_side.effects[PBEffects::Tailwind] > 0
      mults /= 2 if mon.status == :PARALYSIS
      speed = (mon.speed.to_f * stageMul[stage] / stageDiv[stage]).floor
      speed * mults_abil * mults_item * mults
    end

    def faster_than?(target)
      t = target.is_a?(Battle::Battler) ? @ai.pokemon_to_projection(target) : target
      trick_room = @battle.field.effects[PBEffects::TrickRoom] != 0
      return false if t.nil?

      if trick_room
        effective_speed < t.effective_speed
      else
        effective_speed > t.effective_speed
      end
    end

    def has_non_volatile_status?
      burned? || poisoned? || paralyzed? || frozen? || asleep?
    end

    # If this is true, this Pokémon will be treated as being a physical attacker.
    # This means that the Pokémon will be more likely to try to use attack-boosting and
    # defense-lowering status moves, and will be even more likely to use strong physical moves
    # if any of these status boosts are active.
    def is_physical_attacker?
      stats = [effective_attack, effective_spatk]
      avg = stats.sum / stats.size.to_f
      min = (avg + (stats.max - avg) / 4 * 3).floor
      avg = avg.floor
      # min is the value the base attack must be above (3/4th avg) in order to for
      # attack to be seen as a "high" value.
      # Count the number of physical moves
      physcount = 0
      attackBoosters = 0
      moves.each do |move|
        next if move.pp == 0

        physcount += 1 if move.physicalMove?
        next unless move.statUp

        for i in 0...move.statUp.size / 2
          attackBoosters += move.statUp[i * 2 + 1] if move.statUp[i * 2] == :ATTACK
        end
      end
      # If the user doesn't have any physical moves, the Pokémon can never be
      # a physical attacker.
      return false if physcount == 0
      if effective_attack >= min
        # Has high attack stat
        # All physical moves would be a solid bet since we have a high attack stat.
        return true
      elsif effective_attack >= avg
        # Attack stat is not high, but still above average
        # If this Pokémon has any attack-boosting moves, or more than 1 physical move,
        # we consider this Pokémon capable of being a physical attacker.
        return true if physcount > 1
        return true if attackBoosters >= 1
        return true if has_role?(:PHYSICALBREAKER)
      end

      false
    end

    # If this is true, this Pokémon will be treated as being a special attacker.
    # This means that the Pokémon will be more likely to try to use spatk-boosting and
    # spdef-lowering status moves, and will be even more likely to use strong special moves
    # if any of these status boosts are active.
    def is_special_attacker?
      stats = [effective_attack, effective_spatk]
      avg = stats.sum / stats.size.to_f
      min = (avg + (stats.max - avg) / 4 * 3).floor
      avg = avg.floor
      # min is the value the base attack must be above (3/4th avg) in order to for
      # attack to be seen as a "high" value.
      # Count the number of physical moves
      speccount = 0
      spatkBoosters = 0
      moves.each do |move|
        next if move.pp == 0

        speccount += 1 if move.specialMove?
        next unless move.statUp

        for i in 0...move.statUp.size / 2
          spatkBoosters += move.statUp[i * 2 + 1] if move.statUp[i * 2] == :SPECIAL_ATTACK
        end
      end
      # If the user doesn't have any physical moves, the Pokémon can never be
      # a physical attacker.
      return false if speccount == 0
      if effective_spatk >= min
        # Has high spatk stat
        # All special moves would be a solid bet since we have a high spatk stat.
        return true
      elsif effective_spatk >= avg
        # Spatk stat is not high, but still above average
        # If this Pokémon has any spatk-boosting moves, or more than 1 special move,
        # we consider this Pokémon capable of being a special attacker.
        return true if speccount > 1
        return true if spatkBoosters >= 1
        return true if has_role?(:SPECIALBREAKER)
      end

      false
    end

    # Whether the pokemon should mega-evolve
    def should_mega_evolve?(idx)
      # Always mega evolve if the pokemon is able to
      @battle.pbCanMegaEvolve?(@battler.index)
    end

    def check_spam_block
      return false if !$game_switches[LvlCap::Expert] && !$game_switches[901]
      return false if @battle.doublebattle

      flag = $spam_block_triggered
      flag_second = 0
      if $spam_block_triggered == false
        opposing_side.battlers.each do |target|
          next if target.nil?

          flag = PBAI::SpamHandler.trigger(flag, @ai, @battler, target)
        end
      end
      if $spam_block_triggered
        opposing_side.battlers.each do |target|
          next if target.nil?

          flag_second = PBAI::SpamHandler.trigger_secondary(flag_second, @ai, @battler, target)
        end
      end
      PBAI.log('Spam Block Triggered') if flag
      PBAI.log("Spam Block Extended by #{flag_second} turns") if flag_second > 0
      PBAI.spam_block_add(flag_second)
      flag
    end

    def set_calc(target, hash)
      @calc[target.pokemon.species] = hash
    end

    def set_self_calc(target, hash)
      @self_calc[target.pokemon.species] = hash
    end

    def calc_all(target)
      return if @ai.battle.wildBattle? && !$game_switches[908]

      str = '=' * 30
      str += "\nNow calcing all party members vs #{target.pokemon.name}\n"
      str += '=' * 30
      party = @ai.battle.pbParty(index)
      party.each do |pkmn|
        next if pkmn.fainted?

        mon = begin
          pkmn == pokemon ? self : @ai.pbMakeFakeBattler(pkmn)
        rescue StandardError
          nil
        end
        pk = pkmn == pokemon ? self : @ai.pokemon_to_projection(pkmn)
        new_hash = {}
        if mon.nil?
          target.moves.each do |move|
            next if move.category == 2

            new_hash[move.id] = 0
            str += "\nDamage could not be calculated..."
          end
        else
          target.moves.each do |move|
            next if move.category == 2

            mov = move.is_a?(Pokemon::Move) ? Battle::Move.from_pokemon_move(@ai.battle, move) : move
            dmg = target.get_potential_move_damage(mon, mov)
            new_hash[move.id] = dmg
            str += "\nDamage from #{target.pokemon.name} to #{pkmn.name} using #{move.name} => #{dmg}"
          end
        end
        pk.set_calc(target, new_hash)
      end
      PBAI.log(str)
    end

    def calc_all_self(target)
      str = '=' * 30
      str += "\nNow calcing all opposing party members vs #{pokemon.name}\n"
      str += '=' * 30
      party = @ai.battle.doublebattle ? @ai.battle.pbParty(target.index) : @ai.battle.pbParty(0)
      party.each do |pkmn|
        next if pkmn.fainted?
        next unless pkmn

        mon = begin
          pkmn == target.pokemon ? target : @ai.pbMakeFakeBattler(pkmn)
        rescue StandardError
          nil
        end
        pk = pkmn == target.pokemon ? target : @ai.pokemon_to_projection(pkmn)
        new_hash = {}
        if mon.nil?
          moves.each do |move|
            next if move.category == 2

            new_hash[move.id] = 0
            str += "\nDamage could not be calculated...\n"
          end
        else
          moves.each do |move|
            next if move.category == 2

            mov = move.is_a?(Pokemon::Move) ? Battle::Move.from_pokemon_move(@ai.battle, move) : move
            dmg = get_potential_move_damage(mon, mov)
            new_hash[move.id] = dmg
            str += "\nDamage from #{pokemon.name} to #{mon.name} using #{move.name} => #{dmg}\n"
          end
        end
        pk.set_self_calc(target, new_hash)
      end
      PBAI.log(str)
    end

    def calc_self(target)
      return if @ai.battle.wildBattle? && !$game_switches[908]

      str = '=' * 30
      str += "\nNow calcing all moves vs #{target.pokemon.name}\n"
      str += '=' * 30
      calc = {}
      moves.each do |move|
        calc[move.id] = if target_is_immune?(move, target)
                          0
                        else
                          get_potential_move_damage(target, move)
                        end
        str += "\n#{move.name} => #{calc[move.id]}"
      end
      set_self_calc(target, calc)
      PBAI.log(str)
    end

    def get_calc(target, move)
      return 0 if move.category == 2
      return 0 if @ai.battle.wildBattle? && !$game_switches[908]

      me = is_a?(Pokemon) ? @ai.pokemon_to_projection(self) : self
      if @calc[target.pokemon.species][move.id].nil?
        @calc[target.pokemon.species][move.id] = target.get_potential_move_damage(me, move)
      end
      @calc[target.pokemon.species][move.id]
    end

    def get_calc_self(target, move)
      return 0 if move.category == 2
      return 0 if @ai.battle.wildBattle? && !$game_switches[908]

      me = is_a?(Pokemon) ? @ai.pokemon_to_projection(self) : self
      if @self_calc[target.pokemon.species][move.id].nil?
        @self_calc[target.pokemon.species][move.id] = me.get_potential_move_damage(target, move)
      end
      @self_calc[target.pokemon.species][move.id]
    end

    def calc_target(target)
      str = '=' * 30
      str += "\nNow calcing all moves from #{target.pokemon.name}\n"
      str = '=' * 30
      calc = {}
      target.moves.each do |move|
        calc[move.id] = target.get_potential_move_damage(self, move)
        str += "\n#{move.name} => #{calc[move.id]}\n"
      end
      set_calc(target, calc)
      PBAI.log(str)
    end

    def assess_threats(target)
      score = 0
      if @ai.battle.wildBattle? && !$game_switches[908]
        PBAI.log_ai('Threat assessment skipped for being a wild battle')
        return score
      end
      score += PBAI.threat_damage(self, target)
      score += target.set_up_score
      PBAI.log_threat(target.battler, target.set_up_score, 'to factor in set up')
      score
    end

    def determine_move_choice(scores, random = false, immune)
      if random == false
        m_ind = -1
        s_ind = []
        scrs = []
        scr_ind = -1
        scr = 0
        skip = 0
        for mv in scores
          m_ind += 1
          scrs << [mv, m_ind]
          scr += 1 if mv[1] > -1
          skip += 1 if mv[1] < 1
        end
        uh = scrs.length - skip
        random = true if uh == 0
        if scr == 0 && random == false
          if scrs.length > 1
            scrs.sort! do |a, b|
              ret = b[0][1] <=> a[0][1]
              next ret if ret != 0

              next b[0][2] <=> a[0][2]
            end
            if scrs[0][1] == scrs[1][1]
              midx = rand(2)
              scrs[midx][1] = 0
              scores[[scrs][midx][2]] = scrs[midx]
            end
          end
          for mov in scores
            next if scrs.length <= 1
            next if mov[1] == 0
            next if mov == scrs[0][0]

            mov[1] = 0
          end
        else
          for i in scores
            scr_ind += 1
            s_ind << [i, scr_ind] if i[1] > 0
          end
          if s_ind.length > 1
            s_ind.sort! do |a, b|
              ret = b[0][1] <=> a[0][1]
              next ret if ret != 0

              next b[0][2] <=> a[0][2]
            end
            if s_ind[0][1] == s_ind[1][1]
              indx = rand(2)
              s_ind[indx][1] = 0
              scores[[s_ind][indx][2]] = s_ind[indx]
            end
          end
          for mvs in scores
            next if s_ind.length <= 1
            next if mvs[1] == 0
            next if mvs == s_ind[0][0]

            mvs[1] = 0
          end
        end
      end
      if scores.size == 0 || random == true
        # Then just try to use the very first move with pp
        move = []
        sts = 0
        if @battler.moves.length == 1
          move.push(@battler.moves[0])
        else
          for i in 0...@battler.moves.length
            m = @battler.moves[i]
            sts += 1 if m.statusMove?
            disabled = @battler.effects[PBEffects::DisableMove] if @battler.effects[PBEffects::DisableMove] == m.id
            tormented = @battler.lastRegularMoveUsed if @battler.effects[PBEffects::Torment]
            choiced = @battler.effects[PBEffects::ChoiceBand]
            if !choiced
              move.push(i) if m.pp > 0 && m && !m.statusMove? && disabled != m.id && tormented != m && !%i[FAKEOUT
                                                                                                           FIRSTIMPRESSION].include?(m.id) && !immune.include?(i)
            elsif choiced == m
              move.push(i)
            end
          end
          if sts == @battler.moves.length || move.length == 0
            mov = rand(@battler.moves.length)
            move.push(mov)
          end
          if @battler.effects[PBEffects::Encore] > 0
            move = []
            @battler.moves.each_with_index do |mv, idx2|
              move.push(idx2) if @battler.effects[PBEffects::EncoreMove] == mv.id
            end
          end
        end
        $rand_move = move[rand(move.length)]
        scores << [$rand_move, 1, 0, 'random']
        if $DEBUG
          move_name = $rand_move.is_a?(Integer) ? @battler.moves[$rand_move].name : GameData::Move.get($rand_move).name
          PBAI.log("Random offensive move: #{move_name} << CHOSEN")
        end
      end
      [scores, random]
    end

    def choose_move
      # An array of scores in the format of [move_index, score, target]
      scores = []
      target_choice = $spam_block_flags[:choice]
      spam_block = false # check_spam_block: now removed for AI consistency
      $target = []
      $target_ind = -1
      rand_trigger = false
      immune = []

      # Calculates whether to use an item
      # item_score = get_item_score
      item_score = [0, 0]
      # Yields [score, item, target&]
      scores << [:ITEM, *item_score]

      targets = opposing_side.battlers.clone
      @side.battlers.each do |proj|
        next if proj == self || proj.nil? || proj.index == index + 2 || proj.index == index - 2

        targets << proj
      end

      skip_switch = false
      targets.each do |t|
        next unless t && !t.fainted?

        calc_target(t)
        calc_self(t)
      end

      targets.each do |targ|
        next unless targ

        if hp <= totalhp / 2 # TODO: could be extended to preserve fast pokes or sth
          skip_switch = true
          echoln 'skip cuz low'
          break
        end
        if target_has_killing_prio_move?(targ)
          echoln 'target has killing prio'
          break
        end
        next unless has_killing_move?(targ) && faster_than?(targ)

        skip_switch = true
        echoln "\n i have killing move"
        break
      end

      # Calculates whether to switch
      switch_score = [0, 0]
      # Yields [score, pokemon_index]
      scores << [:SWITCH, *switch_score]
      #    if @battle.rules["alwaysflee"] == true && !self.trapped?
      #     flee_score = 100000
      #  elsif !@battle.wildBattle?
      #    flee_score = 0
      #  else
      #    flee_score = 0
      #  end
      #  scores << [:FLEE, *flee_score]

      PBAI.log('=' * 10 + " Turn #{@battle.turnCount + 1} " + '=' * 10)
      # Gets the battler projections of the opposing side
      # Calculate a score for each possible target

      targets.each do |target|
        next if target.nil?
        next if target.fainted?

        $threat_scores[index][target.index] = assess_threats(target)
        PBAI.log('Threat assessment overridden by Spam Block being triggered') if $spam_block_triggered
        PBAI.log("#{target.pokemon.name}'s threat score against #{@battler.pokemon.name} => #{$threat_scores[index][target.index]}")
        # target.battler = pbMakeFakeBattler(target_choice) if spam_block && target_choice.is_a?(Pokemon)
        $target.push(target)
        set_flags(target) if (spam_block == false) && target.index != 1 && target.index != 3
        # if target.hp < target.totalhp/5 && !$spam_block_flags[:no_priority_flag].include?(target) && self.turnCount > 0 && @battle.doublebattle == false && !$spam_block_triggered
        #  rand_trigger = true
        # end
        rand_trigger = true if @battle.wildBattle? && $game_switches[908] == false
        PBAI.log("Moves for #{@battler.pokemon.name} against #{target.pokemon.name}")
        # Calculate a score for all the user's moves
        for i in 0...@battler.moves.length
          move = @battler.moves[i]
          next if move.nil?
          next if move.pp <= 0

          target_type = move.pbTarget(@battler)
          target_index = spam_block ? 0 : target.index
          immune.push(i) if !spam_block && target_is_immune?(move, target)
          if %i[None User FoeSide BothSides UserSide].include?(GameData::Target.get(target_type).id)
            # If move has no targets, affects the user, a side or the whole field
            target_index = -1
          elsif !@battle.pbMoveCanTarget?(@battler.index, target.index, target_type)
            next
          end
          # Get the move score given a user and a target
          score = get_move_score(target, move)
          next if score.nil?

          scores << [i, score.round, target_index, target.pokemon.name]
        end
      end
      move_choice_data = determine_move_choice(scores, rand_trigger, immune)
      final_scores = move_choice_data[0]
      rand_trigger = move_choice_data[1]
      switch_score = skip_switch ? [0, 0] : get_switch_score(final_scores)
      # Yields [score, pokemon_index]
      scores[1] = [:SWITCH, *switch_score]
      echoln "scores = #{scores}"
      # Generate a choice based on the score weights
      idx = PBAI.move_choice(scores.map { |e| e[1] })
      str = '=' * 30
      weights = scores.map { |e| e[1] }
      total = weights.sum
      logga = true
      if logga == true
        # if true
        scores.each_with_index do |e, i|
          # finalPerc = total == 0 ? 0 : (weights[i] / total.to_f * 100).round
          if i == 0
            # Item
            next if item_score == [0, 0]

            name = GameData::Item.get(e[2]).name
            score = e[1]
            if score > 0
              str += "\nITEM #{name}: #{score} =>"
              str += ' << CHOSEN' if idx == 0 && rand_trigger == false
              str += "\n"
            end
          elsif i == 1
            # Switch
            name = @battle.pbParty(@battler.index)[e[2]].name
            score = e[1]
            if score > 0
              str += "\nSWITCH #{name}: #{score}"
              str += ' << CHOSEN' if idx == 1 && rand_trigger == false
              str += "\n"
            end
          # elsif i == -1
          #  str += "STRUGGLE: 100%"
          else
            move_index, score, target, target_name = e
            name = move_index.is_a?(Battle::Move) ? move_index.name : @battler.moves[move_index].name
            str += "\nMOVE(#{target_name}) #{name}: #{score}"
            str += ' << CHOSEN' if i == idx && rand_trigger == false
            str += "\n"
          end
        end
      end
      str += '=' * 30
      PBAI.log(str)
      if idx == 0
        # Index 0 means an item was chosen
        ret = [:ITEM, scores[0][2]]
        ret << scores[0][3] if scores[0][3] # Optional target
        # TODO: Set to-be-healed flag so Heal Pulse doesn't also heal after healing by item
        healing_item = scores[0][4]
        flags[:will_be_healed] if healing_item
        return ret
      elsif idx == 1
        # Index 1 means switching was chosen
        return [:SWITCH, scores[1][2]]
      end
      # Return [move_index, move_target]
      wild = @battle.wildBattle? && $game_switches[908] == false
      return unless idx && !wild

      choice = scores[idx]
      m = !choice[0].is_a?(Integer) ? choice[0] : choice[0].round
      if m.is_a?(Symbol)
        ind = -1
        @battler.moves.each do |move|
          ind += 1
          if ($game_switches[902] || $game_switches[903]) && move.id == choice[0] && move.id == :FAKEOUT
            $spam_block_flags[:fake_out_ghost_flag].push(move.id)
          end
          break if move.id == choice[0]
        end
        choice[0] = ind
      end
      oof = choice[0].to_int
      if oof.is_a?(Symbol)
        indxx = -1
        @battler.moves.each do |move|
          indxx += 1
          break if move.id == choice[0]
        end
        choice[0] = indxx
      end
      if @battle.doublebattle
        move = @battler.moves[choice[0]]
        target = $target[$target_ind % 2]
        if %w[CureTargetStatusHealUserHalfOfTotalHP HealUserHalfOfTotalHP
              HealUserHalfOfTotalHPLoseFlyingTypeThisTurn HealUserPositionNextTurn HealUserDependingOnWeather HealUserFullyAndFallAsleep].include?(move.function)
          flags[:will_be_healed] = true
        elsif move.function == 'HealTargetHalfOfTotalHP'
          target.flags[:will_be_healed] = true
        # elsif move.function == "StartPreventCriticalHitsAgainstUserSide"
        #   @side.flags[:will_luckychant] = true
        # elsif move.function == "StartWeakenPhysicalDamageAgainstUserSide"
        #   @side.flags[:will_reflect] = true
        # elsif move.function == "StartWeakenSpecialDamageAgainstUserSide"
        #   @side.flags[:will_lightscreen] = true
        # elsif move.function == "ResetAllBattlersStatStages"
        #   @side.flags[:will_haze] = true
        # elsif move.function == "StartWeakenDamageAgainstUserSideIfHail"
        # @side.flags[:will_auroraveil] = true
        elsif move.function == 'DisableTargetStatusMoves'
          target.flags[:will_be_taunted] = true
        elsif move.function == 'DisableTargetLastMoveUsed'
          target.flags[:will_be_disabled] = true
        end
      end
      [choice[0], choice[2]]

      # No choice could be made
      # Caller will make sure Struggle is used
    end

    def get_item_score
      # Yields [score, item, optional_target, healing_item]
      items = @battle.pbGetOwnerItems(@battler.index)
      # Item categories
      hpItems = {
        POTION: 20,
        SUPERPOTION: 50,
        HYPERPOTION: 200,
        MAXPOTION: -1,
        BERRYJUICE: 20,
        SWEETHEART: 20,
        FRESHWATER: 50,
        SODAPOP: 60,
        LEMONADE: 80,
        MOOMOOMILK: 100,
        ORANBERRY: 10,
        SITRUSBERRY: totalhp / 4,
        ENERGYPOWDER: 50,
        ENERGYROOT: 200,
        FULLRESTORE: -1
      }
      hpItems[:RAGECANDYBAR] = 20 if Settings::MECHANICS_GENERATION < 7
      singleStatusCuringItems = {
        AWAKENING: :SLEEP,
        CHESTOBERRY: :SLEEP,
        BLUEFLUTE: :SLEEP,
        ANTIDOTE: :POISON,
        PECHABERRY: :POISON,
        BURNHEAL: :BURN,
        RAWSTBERRY: :BURN,
        PARALYZEHEAL: :PARALYSIS,
        CHERIBERRY: :PARALYSIS,
        ICEHEAL: :FROZEN,
        ASPEARBERRY: :FROZEN
      }
      allStatusCuringItems = %i[
        FULLRESTORE
        FULLHEAL
        LAVACOOKIE
        OLDGATEAU
        CASTELIACONE
        LUMIOSEGALETTE
        SHALOURSABLE
        BIGMALASADA
        LUMBERRY
        HEALPOWDER
      ]
      xItems = {
        XATTACK: [:ATTACK, Settings::MECHANICS_GENERATION >= 7 ? 2 : 1],
        XATTACK2: [:ATTACK, 2],
        XATTACK3: [:ATTACK, 3],
        XATTACK6: [:ATTACK, 6],
        XDEFENSE: [:DEFENSE, Settings::MECHANICS_GENERATION >= 7 ? 2 : 1],
        XDEFENSE2: [:DEFENSE, 2],
        XDEFENSE3: [:DEFENSE, 3],
        XDEFENSE6: [:DEFENSE, 6],
        XSPATK: [:SPECIAL_ATTACK, Settings::MECHANICS_GENERATION >= 7 ? 2 : 1],
        XSPATK2: [:SPECIAL_ATTACK, 2],
        XSPATK3: [:SPECIAL_ATTACK, 3],
        XSPATK6: [:SPECIAL_ATTACK, 6],
        XSPDEF: [:SPECIAL_DEFENSE, Settings::MECHANICS_GENERATION >= 7 ? 2 : 1],
        XSPDEF2: [:SPECIAL_DEFENSE, 2],
        XSPDEF3: [:SPECIAL_DEFENSE, 3],
        XSPDEF6: [:SPECIAL_DEFENSE, 6],
        XSPEED: [:SPEED, Settings::MECHANICS_GENERATION >= 7 ? 2 : 1],
        XSPEED2: [:SPEED, 2],
        XSPEED3: [:SPEED, 3],
        XSPEED6: [:SPEED, 6],
        XACCURACY: [:ACCURACY, Settings::MECHANICS_GENERATION >= 7 ? 2 : 1],
        XACCURACY2: [:ACCURACY, 2],
        XACCURACY3: [:ACCURACY, 3],
        XACCURACY6: [:ACCURACY, 6]
      }
      scores = items.map do |item|
        if item != :REVIVE && item != :MAXREVIVE
          # Don't try to use the item if we can't use it on this Pokémon (e.g. due to Embargo)
          next [0, item] unless @battle.pbCanUseItemOnPokemon?(item, @battler.pokemon, @battler, nil, false)

          # Don't try to use the item if it doesn't have any effect, or some other condition that is not met
          unless ItemHandlers.triggerCanUseInBattle(item, @battler.pokemon, @battler, nil, false, @battle,
                                                    nil, false)
            next [0,
                  item]
          end
        end

        score = 0
        # The item is a healing item
        if hpToGain = hpItems[item]
          hpLost = totalhp - hp
          hpToGain = hpLost if hpToGain == -1 || hpToGain > hpLost
          hpFraction = hpToGain / totalhp.to_f
          # If hpFraction is high, then this item will heal almost all our HP.
          # If it is low, then this item will heal very little of our total HP.
          # We now factor the effectiveness of using this item into this fraction.
          # Because using HP items at full health should not be an option, whereas
          # using it at 1 HP should always be preferred.
          itemEff = hpToGain / hpLost.to_f
          itemEff = 0 if hpLost == 0
          delayEff = 1.0
          if !may_die_next_round?
            # If we are likely to survive another hit of the last-used move,
            # then we should discourage using healing items this turn because
            # we can heal more if we use it later.
            delayEff = 0.3
          else
            # If we are likely to die next round, we have a choice to make.
            # It can occur that the target is also a one-shot from this point,
            # which will make move scores skyrocket which can mean we won't use our item.
            # So, if we are slower than our opponent, we will likely die first without using
            # our item and without using our move. So if this is the case, we dramatically increase
            # the score of using our item.
            last_dmg = last_damage_taken
            delayEff = 2.5 if last_dmg && !faster_than?(last_dmg[0])
          end
          finalFrac = hpFraction * itemEff * delayEff
          score = (finalFrac * 200).round
        end

        # Single-status-curing items
        if (statusToCure = singleStatusCuringItems[item]) && (status == statusToCure)
          factor = 1.0
          factor = 0.5 if statusToCure == :PARALYSIS # Paralysis is not that serious
          factor = 1.5 if statusToCure == :BURN && is_physical_attacker? # Burned while physical attacking
          factor = 2.0 if statusToCure == :POISON && statusCount > 0 # Toxic
          score += (140 * factor).round
        end

        # All-status-curing items
        if allStatusCuringItems.include?(item) && (status != :NONE)
          factor = 1.0
          factor = 0.5 if status == :PARALYSIS # Paralysis is not that serious
          factor = 1.5 if status == :BURN && is_physical_attacker? # Burned while physical attacking
          factor = 2.0 if status == :POISON && statusCount > 0 # Toxic
          score += (120 * factor).round
        end

        # X-Items
        if xStatus = xItems[item]
          stat, increase = xStatus
          # Only use X-Items on the battler's first turn
          if @battler.turnCount == 0
            factor = 1.0
            factor = 2.0 if stat == :ATTACK && is_physical_attacker? ||
                            stat == :SPECIAL_ATTACK && is_special_attacker?
            score = (80 * factor * increase).round
          end
        end

        # Revive
        if %i[REVIVE MAXREVIVE].include?(item)
          party = @battle.pbParty(@battler.index)
          candidate = nil
          party.each do |pkmn|
            if pkmn.fainted?
              if candidate
                candidate = pkmn if pkmn.level > candidate.level
              else
                candidate = pkmn
              end
            end
          end
          if candidate
            score = if items.include?(:MAXREVIVE) && item == :REVIVE
                      200
                    else
                      400
                    end
            index = party.index(candidate)
            next [score, item, index]
          end
        end

        next [score, item]
      end
      max_score = 0
      chosen_item = 0
      chosen_target = nil
      scores.each do |score, item, target|
        next unless score >= max_score

        max_score = score
        chosen_item = item
        chosen_target = target
      end
      if chosen_item != 0
        return [max_score, chosen_item, chosen_target, !hpItems[chosen_item].nil?] if chosen_target

        return [max_score, chosen_item, nil, !hpItems[chosen_item].nil?]
      end
      [0, 0]
    end

    def choice_locked?
      return true unless effects[PBEffects::ChoiceBand].nil?

      false
    end

    def single_move_choiced?
      (%i[CHOICEBAND CHOICESCARF
          CHOICESPECS].include?(item) || ability == :GORILLATACTICS) && moves.length == 1
    end

    def can_switch?
      party = @ai.battle.pbParty(battler.index)
      fainted = 0
      for i in party
        fainted += 1
      end
      return false if fainted == party.length - 1

      true
    end

    def flags_set?(target)
      $spam_block_flags[:flags_set].include?(target)
    end

    def set_flags(target)
      str = ''
      str += 'Checking flags...'
      if !flags_set?(target)
        str += "\nNo flags found."
        str += "\nSetting flags..."
        off_move = target.moves.length
        prio = 0
        for i in target.moves
          if %w[ResetAllBattlersStatStages UserStealTargetPositiveStatStages].include?(i.function)
            $spam_block_flags[:haze_flag].push(target)
            str += "\n#{target.name} has been assigned Haze flag"
          end
          off_move -= 1 if i.statusMove?
          prio += 1 if i.priority > 0
        end
        if target.hasActiveAbility?(:UNAWARE)
          $spam_block_flags[:haze_flag].push(target)
          str += "\n#{target.name} has been assigned Haze flag"
        end
        str += "\nOffensive Move Count: #{off_move}"
        str += "\nPriority Move Count: #{prio}"
        if off_move == 0
          $spam_block_flags[:no_attacking].push(target)
          str += "\n#{target.name} has been assigned No Attacking Flag"
        end
        if off_move < target.moves.length - 2
          $learned_flags[:should_taunt].push(target)
          str += "\n#{target.name} has been assigned Should Taunt flag"
        end
        if prio == 0
          $spam_block_flags[:no_priority_flag].push(target)
          str += "\n#{target.name} has been assigned No Priority flag"
        end
        $spam_block_flags[:choiced_flag].push(target) if target.choice_locked?
        $spam_block_flags[:flags_set].push(target)
        str += "\nEnd flag assignment."
      else
        str += "Flags found.\nEnd flag search"
        # str += "\n#{$spam_block_flags}\n\n"
        # echoln $spam_block_flags
      end
      PBAI.log(str)
    end

    def set_up_score
      stats = %i[ATTACK DEFENSE SPEED SPECIAL_ATTACK SPECIAL_DEFENSE]
      boosts = []
      score = 0
      for stat in stats
        if (is_physical_attacker? && stat != :SPECIAL_ATTACK) || (is_special_attacker? && stat != :ATTACK)
          boosts.push(battler.stages[stat])
        end
      end
      for i in boosts
        score += i
      end
      score += 1 if battler.effects[PBEffects::ParadoxStat]
      score
    end

    def set_up_max?(move)
      if AI_Move.offense_setup_move?(move)
        max = battler.stages[:ATTACK] == 6 || battler.stages[:SPECIAL_ATTACK] == 6
      elsif AI_Move.defense_setup_move?(move)
        max = battler.stages[:DEFENSE] == 6 || battler.stages[:SPECIAL_DEFENSE] == 6
      elsif AI_Move.speed_setup_move?(move)
        max = battler.stages[:SPEED] == 6
      end
      max
    end

    def ai_should_switch?(scores)
      return false if @ai.battle.doublebattle

      $switch_flags = {}
      score = 0
      party = @battle.pbParty(index)
      highest_move_score = scores[-1]
      self_party = []
      party.each do |mon|
        next if mon.fainted?

        prj = @ai.pokemon_to_projection(mon)
        raise "No projection for #{mon.name}" unless prj

        self_party.push(mon) if prj.pokemon.owner.id == pokemon.owner.id
      end
      return false if self_party.length == 1
      return false if self_party.length <= 2 && @battle.doublebattle

      opposing_side.battlers.each do |target|
        next if target.nil?

        score = PBAI::SwitchHandler.trigger_out(score, @ai, self, target)
      end
      PBAI.log_ai("Switch out Score: #{score}")
      switch = score > highest_move_score
      $switch_flags[:score] = score
      nope = switch ? '' : 'not'
      PBAI.log_ai("The AI will #{nope} try to switch.")
      switch
    end

    def get_switch_score(final_scores)
      move_scores = final_scores.map { |e| e[1] }
      move_scores = move_scores.sort
      party = @battle.pbParty(@battler.index)
      target_choice = $spam_block_flags[:choice]
      switch = ai_should_switch?(move_scores)
      # switch = self.has_role?(:NONE) ? false : ai_should_switch?(move_scores)
      return [0, 0] unless switch
      return [0, 0] if party.length == 1
      return [0, 0] unless can_switch?
      return [0, 0] if trapped?

      lastlist = []
      $d_switch = 0
      $d_switch = 1 unless $doubles_switch.nil?
      $target_strong_moves = false
      # Get the optimal switch choice by type
      scores = get_optimal_switch_choice
      # scores.each {|s| s[0] += $switch_flags[:score] if !s[1].fainted?}
      # If we should switch due to effects in battle
      if switch == true
        availscores = scores.select { |e| !e[1].fainted? }
        # Switch to a dark type instead of the best type matchup
        # if $switch_flags[:dark]
        #  availscores = availscores.select { |e| e[1].pokemon.types.include?(:DARK) }
        # end
        for i in 0..availscores.size
          score = 0
          score, proj = availscores[i]
          unless proj.nil?
            opposing_side.battlers.each do |target|
              next if target.nil?

              score = PBAI::SwitchHandler.trigger_general(score, @ai, self, proj, target)
              target_moves = target.moves
              # target_moves = [$spam_block_flags[:choice]] if check_spam_block && $spam_block_flags[:choice].is_a?(PokeBattle_Move)
              unless target_moves.nil?
                for i in target_moves
                  score = PBAI::SwitchHandler.trigger_type(i.type, score, @ai, self, proj, target)
                end
              end
              PBAI.log_ai("\n#{proj.pokemon.name} => #{score}")
              PBAI.log_ai("\n#{proj.pokemon.name} removed from switch choices") if score <= move_scores[-1]
            end
          end
          $doubles_switch = proj if $d_switch == 0
          lastlist = [proj, score]
          eligible = true
          eligible = false if proj.nil?
          unless proj.nil?
            eligible = false unless proj.battler.nil? # Already active
            eligible = false if proj.pokemon.egg? # Egg
            eligible = false if proj == $doubles_switch && $d_switch == 1
            eligible = false if lastlist[0] == @battler
            eligible = false if score <= move_scores[-1]
          end
          next unless eligible

          PBAI.log_switch(proj.pokemon.name, ' << Chosen Switch In')
          index = party.index(proj.pokemon)
          return [score, index]
        end
      end
      $switch_flags[:move] = nil
      [0, 0]
    end

    # TODO: Tweak some of these
    def get_optimal_switch_choice
      str = '=' * 30
      str += "\nNow determining optimal switch choice"
      party = @battle.pbParty(index)
      self_party = []
      party.each do |mon|
        prj = @ai.pokemon_to_projection(mon)
        raise "No projection for #{mon.name}" unless prj

        self_party.push(mon) if prj.pokemon.owner.id == pokemon.owner.id && !mon.fainted? && pokemon != prj.pokemon
      end
      targets = opposing_side.battlers.clone
      @side.battlers.each do |proj|
        next if proj == self || proj.nil? || proj.index == index + 2 || proj.index == index - 2

        targets << proj
      end
      matchup = self_party.map do |pkmn|
        str += "\n\nScoring for #{pkmn.name}"
        proj = @ai.pokemon_to_projection(pkmn)
        # proj = @ai.pbMakeFakeBattler(pkmn)
        # echoln "Proj type: #{proj.class}"
        raise "No projection found for party member #{pkmn.name}" unless proj

        offensive_score = 1.0
        defensive_score = 1.0
        score = 0
        # proj.opposing_side.battlers.each do |t|
        targets.each do |target|
          next if target.nil?

          # target.battler = pbMakeFakeBattler(target.pokemon)

          # target = @ai.pokemon_to_projection(t.pokemon)
          # target = t.pbMakeFakeBattler(t.pokemon)
          # echoln "Target type: #{target.class}"
          if proj.fast_kill?(target)
            offensive_score += 13.0
            str += "\n+13.0 for fast kill"
          elsif proj.slow_kill?(target)
            offensive_score += 6.0
            str += "\n+6.0 for slow kill"
          else
            offensive_score -= 1.0
            str += "\n-1.0 for having no kill"
          end
          if proj.target_has_killing_move?(target) # FIXME: Doesnt work returns 0 damage. mon is null in get_pottential
            if proj.target_fast_kill?(target)
              defensive_score -= 5.0
              str += "\n-5.0 defensive for target having fast kill"
            else
              defensive_score -= 3.0
              str += "\n-3.0 defensive for target having slow kill"
            end
          elsif proj.target_has_2hko?(target)
            if !proj.fast_kill?(target)
              defensive_score -= 4.0
              str += "\n-4.0 defensive for target having 2HKO and us not having a fast kill"
            elsif !proj.target_fast_kill?(target) && proj.slow_kill?(target)
              defensive_score += 3.0
              str += "\n+3.0 for target having no kill and us having slow kill"
            else
              defensive_score += 5.0
              str += "\n+5.0 defensive for target having 2HKO and us having a fast KO"
            end
          else # cannot 1hko or 2hko then consider good switch in
            defensive_score += 10.0
            str += "\n10.0 defensive for target having no kills"
          end
          if proj.faster_than?(target) && !proj.has_killing_move?(target) && !proj.target_has_killing_move?(target)
            offensive_score += 1.0
            str += "\n+1.0 for being faster"
          end
          # threat_mod = PBAI::ThreatHandler.trigger_self(score, @ai, proj, target)
          # offensive_score += threat_mod
          # str += "\nThreat Preservation Modifier: #{threat_mod * -1}"
        end
        str += "\nOffensive Score: #{offensive_score}"
        str += "\nDefensive Score: #{defensive_score}"
        next [offensive_score, defensive_score, proj]
      end
      matchup.sort! do |a, b|
        # Sort by total score (offensive + defensive) in descending order
        total_a = a[0] + a[1]  # offensive + defensive for a
        total_b = b[0] + b[1]  # offensive + defensive for b
        ret = (total_b <=> total_a) # descending order
        next ret if ret != 0

        # If total scores are equal, tiebreak by offensive score
        ret = (b[0] <=> a[0])
        next ret if ret != 0

        # If offensive scores are also equal, tiebreak by total defenses
        next (b[2].pokemon.defense + b[2].pokemon.spdef) <=> (a[2].pokemon.defense + a[2].pokemon.spdef)
      end
      # PBAI.log_ai(scores.map { |e| e[2].pokemon.name + ": (#{e[0]}, #{e[1]})" }.join("\n"))
      scores = matchup.map do |e|
        proj = @ai.pokemon_to_projection(e[2].pokemon)
        raise "No projection found for party member #{e[2].pokemon.name}" unless proj

        str += "\n="
        str += '=' * 29
        str += "\nScoring for #{e[2].pokemon.name}"
        score = 0
        score += e[0]
        str += "\n+ #{e[0]} for offensive matchup"
        score += e[1]
        str += "\n+ #{e[1]} for defensive matchup"
        if @battle.doublebattle
          score -= 10 if proj.pokemon.owner.id != pokemon.owner.id
          if proj.pokemon.owner.id != pokemon.owner.id
            str += "\n- 10 to prevent attempting to switch to a pokemon that is not yours"
          end
        end
        str += "\n Starting switch score for #{e[2].pokemon.name} => #{score}"
        next [score, proj]
      end
      PBAI.log(str)
      scores.sort! do |a, b|
        ret = b[0] <=> a[0]
        next ret if ret != 0

        next (b[1].pokemon.defense + b[1].pokemon.spdef) <=> (a[1].pokemon.defense + a[1].pokemon.spdef)
      end
      PBAI.log_ai(scores.map { |f| f[1].pokemon.name + "=> #{f[0]}" }.join("\n"))
      scores
    end

    def get_best_switch_choice
      str = '=' * 30
      str += "\nNow determining best switch choice"
      party = @battle.pbParty(index)
      self_party = []
      party.each do |mon|
        prj = @ai.pokemon_to_projection(mon)
        raise "No projection for #{mon.name}" unless prj

        self_party.push(mon) if prj.pokemon.owner.id == pokemon.owner.id && !mon.fainted?
      end
      targets = opposing_side.battlers.clone
      @side.battlers.each do |proj|
        next if proj == self || proj.nil? || proj.index == index + 2 || proj.index == index - 2

        targets << proj
      end
      scores = self_party.map do |pkmn|
        str += "\n\nScoring for #{pkmn.name}"
        proj = @ai.pokemon_to_projection(pkmn)
        # proj = @ai.pbMakeFakeBattler(pkmn)
        echoln "Proj type: #{proj.class}"
        raise "No projection found for party member #{pkmn.name}" unless proj

        offensive_score = 1.0
        defensive_score = 1.0
        score = 0
        # proj.opposing_side.battlers.each do |t|
        targets.each do |target|
          next if target.nil?

          # target = @ai.pokemon_to_projection(t.pokemon)
          # target = t.pbMakeFakeBattler(t.pokemon)
          echoln "Target type: #{target.class}"
          if proj.fast_kill?(target)
            offensive_score += 13.0
            str += "\n+13.0 for fast kill"
          elsif proj.slow_kill?(target)
            offensive_score += 6.0
            str += "\n+6.0 for slow kill"
          else
            offensive_score -= 1.0
            str += "\n-1.0 for having no kill"
          end
          if proj.target_has_killing_move?(target) # FIXME: Doesnt work returns 0 damage. mon is null in get_pottential
            if proj.target_fast_kill?(target)
              defensive_score -= 5.0
              str += "\n-5.0 defensive for target having fast kill"
            else
              defensive_score -= 3.0
              str += "\n-3.0 defensive for target having slow kill"
            end
          elsif proj.target_has_2hko?(target)
            if !proj.fast_kill?(target)
              defensive_score -= 4.0
              str += "\n-4.0 defensive for target having 2HKO and us not having a fast kill"
            elsif !proj.target_fast_kill?(target) && proj.slow_kill?(target)
              defensive_score += 3.0
              str += "\n+3.0 for target having no kill and us having slow kill"
            else
              defensive_score += 5.0
              str += "\n+5.0 defensive for target having 2HKO and us having a fast KO"
            end
          else # cannot 1hko or 2hko then consider good switch in
            defensive_score += 10.0
            str += "\n10.0 defensive for target having no kills"
          end
          if proj.faster_than?(target) && !proj.has_killing_move?(target) && !proj.target_has_killing_move?(target)
            offensive_score += 1.0
            str += "\n+1.0 for being faster"
          end
          # threat_mod = PBAI::ThreatHandler.trigger_self(score, @ai, proj, target)
          # offensive_score += threat_mod
          # str += "\nThreat Preservation Modifier: #{threat_mod * -1}"
        end
        str += "\nOffensive Score: #{offensive_score}"
        str += "\nDefensive Score: #{defensive_score}"
        next [offensive_score, defensive_score, proj]
      end
      PBAI.log(str)
      scores.sort! do |a, b|
        # Sort by total score (offensive + defensive) in descending order
        total_a = a[0] + a[1]  # offensive + defensive for a
        total_b = b[0] + b[1]  # offensive + defensive for b
        ret = (total_b <=> total_a) # descending order
        next ret if ret != 0

        # If total scores are equal, tiebreak by offensive score
        ret = (b[0] <=> a[0])
        next ret if ret != 0

        # If offensive scores are also equal, tiebreak by total defenses
        next (b[2].pokemon.defense + b[2].pokemon.spdef) <=> (a[2].pokemon.defense + a[2].pokemon.spdef)
      end
      PBAI.log_ai(scores.map { |e| e[2].pokemon.name + ": (#{e[0]}, #{e[1]})" }.join("\n"))
      scores
    end

    # Calculates the score of the move against a specific target
    def get_move_score(target, move)
      # The target variable is a projection of a battler. We know its species and HP,
      # but its item, ability, moves and other properties are not known unless they are
      # explicitly shown or mentioned. Knowing these properties can change what our AI
      # chooses; if we know the item of our target projection, and it's an Air Balloon,
      # we won't choose a Ground move, for instance.
      if @ai.battle.wildBattle? && !$game_switches[908]
        PBAI.log_ai('Skip scoring for random wild battles')
        return 1
      end
      move = AI_Move.new(@ai, move)
      ai_move = move.move
      extra = 0
      if target.side == @side
        # The target is an ally
        # Heal Pulse, Pollen Puff
        return nil unless %w[HealTargetHalfOfTotalHP HealAllyOrDamageFoe].include?(ai_move.function)

        extra = 3

        # Move score calculation will only continue if the target is not an ally,
        # or if it is an ally, then the move must be Heal Pulse (0DF).
      end
      idx = -2
      # target = self.opposing_side.party.find {|mon| mon && mon.pokemon == target_choice} if $spam_block_triggered
      $test_trigger = true
      return 20 if single_move_choiced?

      if ai_move.statusMove?
        # Start status moves off with a score of 4.
        # Since this makes status moves unlikely to be chosen when the other moves
        # have a high base power, all status moves should ideally be addressed individually
        # in this method, and used in the optimal scenario for each individual move.
        score = either_target_can_2hko? ? 4 : 9
        score += extra
        PBAI.log_score("Test move #{ai_move.name} (#{score})...")
        # Trigger general score modifier code
        if !fast_kill?(target)
          score = PBAI::ScoreHandler.trigger_general(score, @ai, self, target, ai_move)
          # Trigger status-move score modifier code
          score = PBAI::ScoreHandler.trigger_status_moves(score, @ai, self, target, ai_move)
        else
          PBAI.log_score('Scoring stopped status move since we see a kill')
        end
      else
        # Set the move score to the base power of the move
        score = 1
        score += extra
        PBAI.log_score("Test move #{ai_move.name} (#{score})...")
        # Trigger general score modifier code
        score = PBAI::ScoreHandler.trigger_general(score, @ai, self, target, ai_move)
        # Trigger damaging-move score modifier code
        score = PBAI::ScoreHandler.trigger_damaging_moves(score, @ai, self, target, ai_move)
      end
      # Trigger move-specific score modifier code
      score = PBAI::ScoreHandler.trigger_move(ai_move, score, @ai, self, target)
      score = PBAI::ScoreHandler.trigger_final(score, @ai, self, target, ai_move)
      $test_trigger = false
      PBAI.log_score("= #{score}")
      # PBAI.display_score_messages if $DEBUG
      PBAI.display_score_messages
      score
    end

    # Calculates adjusted base power of a move.
    # Used as a starting point for a particular move's score against a target.
    # Copied from Essentials.
    def get_move_base_damage(move, target)
      baseDmg = move.baseDamage
      baseDmg = 60 if baseDmg == 1
      # Covers all function codes which have their own def pbBaseDamage
      case move.function
      # Sonic Boom, Dragon Rage, Super Fang, Night Shade, Endeavor
      when 'FixedDamage20', 'FixedDamage40', 'FixedDamageHalfTargetHP',
           'FixedDamageUserLevel', 'LowerTargetHPToUserHP'
        baseDmg = move.pbFixedDamage(self, target)
      when 'FixedDamageUserLevelRandom' # Psywave
        baseDmg = @battler.level
      when 'OHKO', 'OHKOIce', 'OHKOHitsUndergroundTarget'
        baseDmg = 200
      when 'CounterPhysicalDamage', 'CounterSpecialDamage', 'CounterDamagePlusHalf'
        baseDmg = 60
      when 'DoublePowerIfTargetUnderwater', 'DoublePowerIfTargetUnderground',
           'BindTargetDoublePowerIfTargetUnderwater'
        baseDmg = move.pbModifyDamage(baseDmg, @battler, target)
      # Gust, Twister, Venoshock, Smelling Salts, Wake-Up Slap, Facade, Hex, Brine,
      # Retaliate, Weather Ball, Return, Frustration, Eruption, Crush Grip,
      # Stored Power, Punishment, Hidden Power, Fury Cutter, Echoed Voice,
      # Trump Card, Flail, Electro Ball, Low Kick, Fling, Spit Up
      when 'DoublePowerIfTargetInSky',
           'FlinchTargetDoublePowerIfTargetInSky',
           'DoublePowerIfTargetPoisoned',
           'DoublePowerIfTargetParalyzedCureTarget',
           'DoublePowerIfTargetAsleepCureTarget',
           'DoublePowerIfUserPoisonedBurnedParalyzed',
           'DoublePowerIfTargetStatusProblem',
           'DoublePowerIfTargetHPLessThanHalf',
           'DoublePowerIfAllyFaintedLastTurn',
           'TypeAndPowerDependOnWeather',
           'PowerHigherWithUserHappiness',
           'PowerLowerWithUserHappiness',
           'PowerHigherWithUserHP',
           'PowerHigherWithTargetHP',
           'PowerHigherWithUserPositiveStatStages',
           'PowerHigherWithTargetPositiveStatStages',
           'TypeDependsOnUserIVs',
           'PowerHigherWithConsecutiveUse',
           'PowerHigherWithConsecutiveUseOnUserSide',
           'PowerHigherWithLessPP',
           'PowerLowerWithUserHP',
           'PowerHigherWithUserFasterThanTarget',
           'PowerHigherWithTargetWeight',
           'ThrowUserItemAtTarget',
           'PowerDependsOnUserStockpile',
           'DoublePowerInElectricTerrain',
           'DoublePowerInMistyTerrain',
           'UserFaintsPowersUpInMistyTerrainExplosive',
           'HitsAllFoesAndPowersUpInPsychicTerrain'
        baseDmg = move.pbBaseDamage(baseDmg, @battler, target)
      when 'DoublePowerIfUserHasNoItem' # Acrobatics
        baseDmg *= 2 if !@battler.item || @battler.hasActiveItem?(:FLYINGGEM)
      when 'PowerHigherWithTargetFasterThanUser' # Gyro Ball
        targetSpeed = target.effective_speed
        userSpeed = effective_speed
        baseDmg = [[(25 * targetSpeed / userSpeed).floor, 150].min, 1].max
      when 'RandomlyDamageOrHealTarget' # Present
        baseDmg = 50
      when 'RandomPowerDoublePowerIfTargetUnderground' # Magnitude
        baseDmg = 71
        baseDmg *= 2 if target.inTwoTurnAttack?('TwoTurnAttackInvulnerableUnderground') # Dig
      when 'TypeAndPowerDependOnUserBerry' # Natural Gift
        baseDmg = move.pbNaturalGiftBaseDamage(@battler.item_id)
      when 'PowerHigherWithUserHeavierThanTarget' # Heavy Slam
        baseDmg = move.pbBaseDamage(baseDmg, @battler, target)
        baseDmg *= 2 if Settings::MECHANICS_GENERATION >= 7 && target.effects[PBEffects::Minimize]
      when 'AlwaysCriticalHit', 'HitTwoTimes', 'HitTwoTimesPoisonTarget' # Frost Breath, Double Kick, Twineedle
        baseDmg *= 2
      when 'HitThreeTimesPowersUpWithEachHit' # Triple Kick
        baseDmg *= 6 # Hits do x1, x2, x3 baseDmg in turn, for x6 in total
      when 'HitTwoToFiveTimes' # Fury Attack
        if @battler.hasActiveAbility?(:SKILLLINK)
          baseDmg *= 5
        else
          baseDmg = (baseDmg * 31 / 10).floor # Average damage dealt
        end
      when 'HitTwoToFiveTimesOrThreeForAshGreninja'
        if @battler.isSpecies?(:GRENINJA) && @battler.form == 2
          baseDmg *= 4 # 3 hits at 20 power = 4 hits at 15 power
        elsif @battler.hasActiveAbility?(:SKILLLINK)
          baseDmg *= 5
        else
          baseDmg = (baseDmg * 31 / 10).floor # Average damage dealt
        end
      when 'HitOncePerUserTeamMember' # Beat Up
        mult = 0
        @battle.eachInTeamFromBattlerIndex(@battler.index) do |pkmn, _i|
          mult += 1 if pkmn&.able? && pkmn.status == :NONE
        end
        baseDmg *= mult
      when 'TwoTurnAttackOneTurnInSun' # Solar Beam
        baseDmg = move.pbBaseDamageMultiplier(baseDmg, @battler, target)
      when 'MultiTurnAttackPowersUpEachTurn' # Rollout
        baseDmg *= 2 if @battler.effects[PBEffects::DefenseCurl]
      when 'MultiTurnAttackBideThenReturnDoubleDamage' # Bide
        baseDmg = 40
      when 'UserFaintsFixedDamageUserHP' # Final Gambit
        baseDmg = @battler.hp
      when 'EffectivenessIncludesFlyingType'   # Flying Press
        if GameData::Type.exists?(:FLYING)
          targetTypes = target.pbTypes(true)
          mult = Effectiveness.calculate(
            :FLYING, targetTypes[0], targetTypes[1], targetTypes[2]
          )
          baseDmg = (baseDmg.to_f * mult / Effectiveness::NORMAL_EFFECTIVE).round
        end
        baseDmg *= 2 if target.effects[PBEffects::Minimize]
      when 'DoublePowerIfUserLastMoveFailed'   # Stomping Tantrum
        baseDmg *= 2 if @battler.lastRoundMoveFailed
      when 'HitTwoTimesFlinchTarget' # Double Iron Bash
        baseDmg *= 2
        baseDmg *= 2 if target.effects[PBEffects::Minimize]
      end
      baseDmg
    end

    # Determines if the target is immune to a move.
    # Copied from Essentials.
    def target_is_immune?(move, target)
      move = move.is_a?(Pokemon::Move) ? Battle::Move.from_pokemon_move(@battle, move) : move
      m = AI_Move.new(@ai, move)
      mov = m.move
      type = mov.pbCalcType(@battler)
      typeMod = mov.pbCalcTypeMod(type, @battler, target)
      tar = target.is_a?(Battle::Battler) ? target : target.battler
      # Immunity due to ability/item/other effects
      case type
      when :GROUND
        # return true if target.airborne? && !move.hitsFlyingTargets? && !move.boneMove?
        return true if target.airborne? && !move.hitsFlyingTargets?
        return true if target.hasActiveAbility?(:EARTHEATER)
      when :FIRE
        return true if target.hasActiveAbility?(%i[FLASHFIRE STEAMENGINE WELLBAKEDBODY])
        return true if @ai.battle.pbWeather == :HeavyRain
      when :WATER
        return true if target.hasActiveAbility?(%i[DRYSKIN STORMDRAIN WATERABSORB IRRIGATION STEAMENGINE
                                                   WATERCOMPACTION])

        if @ai.battle.doublebattle
          tar.eachAlly do |mon|
            return true if mon.hasActiveAbility?(:STORMDRAIN) && !@battler.hasActiveAbility?(%i[PROPELLERTAIL
                                                                                                STALWART])
          end
        end
        return true if @ai.battle.pbWeather == :HarshSun
      when :GRASS
        return true if target.hasActiveAbility?(:SAPSIPPER)
      when :POISON
        return true if target.hasActiveAbility?(:PASTELVEIL)
      when :ELECTRIC
        return true if target.hasActiveAbility?(%i[LIGHTNINGROD MOTORDRIVE VOLTABSORB])
        return true if move.is_a?(Battle::Move::ParalyzeTarget) && move.statusMove? && (target.pbHasType?(:GROUND) || !target.pbCanParalyze?(
          @battler, false, move
        ))

        if @ai.battle.doublebattle
          tar.eachAlly do |mon|
            return true if mon.hasActiveAbility?(:LIGHTNINGROD) && !@battler.hasActiveAbility?(%i[PROPELLERTAIL
                                                                                                  STALWART])
          end
        end
      when :DRAGON
        return true if target.hasActiveAbility?(:LEGENDARMOR)
      when :DARK
        return true if target.hasActiveAbility?(:UNTAINTED)
      when :ROCK
        return true if target.hasActiveAbility?(:SCALER)
      when :BUG
        return true if target.hasActiveAbility?(:PESTICIDE)
      end
      return true if move.damagingMove? && !Effectiveness.super_effective?(typeMod) &&
                     target.hasActiveAbility?(:WONDERGUARD)
      return true if move.damagingMove? && @battler.index != target.index && !target.opposes?(@battler) &&
                     target.hasActiveAbility?(:TELEPATHY)
      return true if move.statusMove? && move.canMagicCoat? && target.hasActiveAbility?(:MAGICBOUNCE) &&
                     target.opposes?(@battler)
      return true if move.soundMove? && target.hasActiveAbility?(:SOUNDPROOF)
      return true if move.bombMove? && target.hasActiveAbility?(:BULLETPROOF)

      if move.powderMove?
        return true if target.pbHasType?(:GRASS)
        return true if target.hasActiveAbility?(:OVERCOAT)
        return true if target.hasActiveItem?(:SAFETYGOGGLES)
      end
      return true if move.statusMove? && target.effects[PBEffects::Substitute] > 0 &&
                     !move.ignoresSubstitute?(@battler) && @battler.index != target.index
      return true if move.statusMove? && Settings::MECHANICS_GENERATION >= 7 &&
                     @battler.hasActiveAbility?(:PRANKSTER) && target.pbHasType?(:DARK) &&
                     target.opposes?(@battler)
      return true if move.priority > 0 && @battle.field.terrain == :Psychic &&
                     target.affectedByTerrain? && target.opposes?(@battler)
      return true if move.priority > 0 && target.priority_blocking?

      if @ai.battle.doublebattle
        tar.eachAlly do |mon|
          return true if move.priority > 0 && mon.priority_blocking?
        end
      end
      return true if move.windMove? && target.hasActiveAbility?(%i[WINDRIDER WINDPOWER])
      if move.statusMove? && target.hasActiveAbility?(:GOODASGOLD) && !@battler.hasActiveAbility?(:MYCELIUMMIGHT)
        return true
      end
      return true if target.hasActiveAbility?(:COMMANDER) && target.isCommander?
      return false if $inverse
      # Type effectiveness
      return true if move.damagingMove? && Effectiveness.ineffective?(typeMod) && !$inverse

      false
    end

    def get_move_accuracy(move, target)
      return 100 if target.effects[PBEffects::Minimize] && move.tramplesMinimize?
      return 100 if target.effects[PBEffects::Telekinesis] > 0

      baseAcc = move.pbBaseAccuracy(@battler, target)
      return 100 if baseAcc == 0

      baseAcc
    end

    def types(type3 = true)
      return @battler.pbTypes(type3) if @battler

      @pokemon.types
    end
    alias pbTypes types

    def effects
      @battler.effects
    end

    def stages
      @battler.stages
    end

    def is_species?(species)
      @battler.isSpecies?(species)
    end
    alias isSpecies? is_species?

    def has_type?(type)
      @battler.pbHasType?(type)
    end
    alias pbHasType? has_type?

    def ability
      @battler.ability
    end

    def has_ability?(ability)
      @battler.hasActiveAbility?(ability) && (OMNISCIENT_AI || @shown_ability)
    end
    alias hasActiveAbility? has_ability?

    def has_item?(item)
      @battler.hasActiveItem?(item) && (OMNISCIENT_AI || @shown_item)
    end
    alias hasActiveItem? has_item?

    def moves
      if @battler.nil?
        @pokemon.moves
      elsif OMNISCIENT_AI || @side.index == 0
        @battler.moves
      else
        @used_moves
      end
    end

    def opposes?(projection)
      if $spam_block_triggered
        @battler.index != projection.index
      else
        @battler.index % 2 != projection.index % 2
      end
    end

    def own_side
      @side
    end
    alias pbOwnSide own_side

    def affected_by_terrain?
      @battler.affectedByTerrain?
    end
    alias affectedByTerrain? affected_by_terrain?

    def airborne?
      @battler.airborne?
    end

    def semi_invulnerable?
      @battler.semiInvulnerable?
    end
    alias semiInvulnerable? semi_invulnerable?

    def in_two_turn_attack?(*args)
      @battler.inTwoTurnAttack?(*args)
    end
    alias inTwoTurnAttack? in_two_turn_attack?

    def can_attract?(target)
      @battler.pbCanAttract?(target)
    end
    alias pbCanAttract? can_attract?

    def takes_indirect_damage?
      @battler.takesIndirectDamage?
    end
    alias takesIndirectDamage? takes_indirect_damage?

    def weight
      @battler.pbWeight
    end
    alias pbWeight weight

    def can_sleep?(inflictor, move, ignore_status = false)
      @battler.pbCanSleep?(inflictor, false, move, ignore_status)
    end

    def can_poison?(inflictor, move)
      @battler.pbCanPoison?(inflictor, false, move)
    end

    def can_burn?(inflictor, move)
      @battler.pbCanBurn?(inflictor, false, move)
    end

    def can_paralyze?(inflictor, move)
      @battler.pbCanParalyze?(inflictor, false, move)
    end

    def can_freeze?(inflictor, move)
      @battler.pbCanFreeze?(inflictor, false, move)
    end

    def can_frostbite?(inflictor, move)
      @battler.pbCanFrostbite?(inflictor, false, move)
    end

    def register_damage_dealt(move, target, damage)
      move = move.id if move.is_a?(GameData::Move)
      @damage_dealt << [target, move, damage, damage / target.totalhp.to_f]
    end

    def register_damage_taken(move, user, damage)
      user.used_moves << move unless user.used_moves.any? { |m| m.id == move.id }
      move = move.id
      @damage_taken << [user, move, damage, damage / @battler.totalhp.to_f]
    end

    def get_damage_by_user(user)
      @damage_taken.select { |e| e[0] == user }
    end

    def get_damage_by_user_and_move(user, move)
      move = move.id if move.is_a?(GameData::Move)
      @damage_taken.select { |e| e[0] == user && e[1] == move }
    end

    def get_damage_by_move(move)
      move = move.id if move.is_a?(GameData::Move)
      @damage_taken.select { |e| e[1] == move }
    end

    def last_damage_taken
      @damage_taken[-1]
    end

    def last_damage_dealt
      @damage_dealt[-1]
    end

    # Estimates how much HP the battler will lose from end-of-round effects,
    # such as status conditions or trapping moves
    def estimate_hp_difference_at_end_of_round
      lost = 0
      # Future Sight
      @battle.positions.each_with_index do |pos, idxPos|
        next unless pos
        # Ignore unless future sight hits at the end of the round
        next if pos.effects[PBEffects::FutureSightCounter] != 1
        # And only if its target is this battler
        next if @battle.battlers[idxPos] != @battler

        # Find the user of the move
        moveUser = nil
        @battle.eachBattler do |b|
          next if b.opposes?(pos.effects[PBEffects::FutureSightUserIndex])
          next if b.pokemonIndex != pos.effects[PBEffects::FutureSightUserPartyIndex]

          moveUser = b
          break
        end
        unless moveUser # User isn't in battle, get it from the party
          party = @battle.pbParty(pos.effects[PBEffects::FutureSightUserIndex])
          pkmn = party[pos.effects[PBEffects::FutureSightUserPartyIndex]]
          if pkmn && pkmn.able?
            moveUser = Battle::Battler.new(@battle, pos.effects[PBEffects::FutureSightUserIndex])
            moveUser.pbInitDummyPokemon(pkmn, pos.effects[PBEffects::FutureSightUserPartyIndex])
          end
        end
        next unless moveUser && moveUser.pokemon != @battler.pokemon

        # We have our move user, and it's not targeting itself
        move_id = pos.effects[PBEffects::FutureSightMove]
        m = Battle::Move.from_pokemon_move(@battle, Pokemon::Move.new(move_id))
        move = AI_Move.new(@ai, m)
        # Calculate how much damage a Future Sight hit will do
        calcType = move.pbCalcType(moveUser)
        @battler.damageState.typeMod = move.pbCalcTypeMod(calcType, moveUser, @battler)
        move.pbCalcDamage(moveUser, @battler)
        dmg = @battler.damageState.calcDamage
        lost += dmg
      end
      if takes_indirect_damage?
        # Sea of Fire (Fire Pledge + Grass Pledge)
        weather = @battle.pbWeather
        if (side.effects[PBEffects::SeaOfFire] != 0) && !(weather == :Rain || weather == :HeavyRain ||
                 has_type?(:FIRE))
          lost += @battler.totalhp / 8.0
        end
        # Leech Seed
        lost += @battler.totalhp / 8.0 if effects[PBEffects::LeechSeed] >= 0
        # Poison
        if poisoned? && !has_ability?(:POISONHEAL)
          dmg = statusCount == 0 ? @battler.totalhp / 8.0 : @battler.totalhp * effects[PBEffects::Toxic] / 16.0
          lost += dmg
        end
        # Burn
        if burned?
          lost += (Settings::MECHANICS_GENERATION >= 7 ? @battler.totalhp / 16.0 : @battler.totalhp / 8.0)
        end
        if frostbitten?
          lost += (Settings::MECHANICS_GENERATION >= 7 ? @battler.totalhp / 16.0 : @battler.totalhp / 8.0)
        end
        # Sleep + Nightmare
        lost += @battler.totalhp / 4.0 if asleep? && effects[PBEffects::Nightmare]
        # Curse
        lost += @battler.totalhp / 4.0 if effects[PBEffects::Curse]
        # Trapping Effects
        if effects[PBEffects::Trapping] != 0
          dmg = (Settings::MECHANICS_GENERATION >= 7 ? @battler.totalhp / 8.0 : @battler.totalhp / 16.0)
          if @battle.battlers[effects[PBEffects::TrappingUser]].hasActiveItem?(:BINDINGBAND)
            dmg = (Settings::MECHANICS_GENERATION >= 7 ? @battler.totalhp / 6.0 : @battler.totalhp / 8.0)
          end
          lost += dmg
        end
      end
      lost
    end

    def will_die_from_attack?(target, move)
      dmg = get_calc(target, move)
      hp <= dmg
    end

    def may_die_next_round?
      dmg = last_damage_taken
      return false if dmg.nil?

      # Returns true if the damage from the last move is more than the remaining hp
      # This is used in determining if there is a point in using healing moves or items
      hplost = dmg[2]
      # We will also lose damage from status conditions and end-of-round effects like wrap,
      # so we make a rough estimate with those included.
      hplost += estimate_hp_difference_at_end_of_round
      hplost >= hp
    end

    def took_more_than_x_damage?(x)
      dmg = last_damage_taken
      return false if dmg.nil?

      # Returns true if the damage from the last move did more than (x*100)% of the total hp damage
      dmg[3] >= x
    end

    # If the battler can survive another hit from the same move the target used last,
    # but the battler will die if it does not heal, then healing is considered necessary.
    def is_healing_necessary?(x)
      may_die_next_round? && !took_more_than_x_damage?(x)
    end

    # Healing is pointless if the target did more damage last round than we can heal
    def is_healing_pointless?(x)
      took_more_than_x_damage?(x)
    end

    def predict_switch?(target)
      return true if target.bad_against?(self)
      return false if bad_against?(target)
      return false unless target.can_switch?

      kill = false
      for t in target.moves
        next if t.statusMove?

        kill = true if get_calc(target, t) >= hp
      end
      return false if kill == true && target.faster_than?(self)

      for i in moves
        return true if get_calc_self(target, i) >= target.hp
        return true if i.priority > 0 && i.damagingMove? && get_calc_self(target, i) >= target.hp
      end
      return true if target.bad_against?(self) && faster_than?(target)
      return false if $spam_block_triggered

      false
    end

    def has_killing_move?(target)
      for move in moves
        # echoln "move: #{move.name}  damage: #{self.get_potential_move_damage(target,move)}"
      end
      moves.any? { |move| get_potential_move_damage(target, move) >= target.pokemon.hp }
    end

    def has_killing_prio_move?(target)
      moves.any? do |move|
        move.priority > 0 && get_potential_move_damage(target, move) >= target.pokemon.hp + 8
      end
    end

    def either_target_can_2hko?
      if @battle.doublebattle
        dmg = 0
        opposing_side.battlers.each do |target|
          next if target.nil?

          dmg += 1 if target_has_2hko?(target)
        end
        dmg > 0
      else
        opposing_side.battlers.each do |target|
          return target_has_2hko?(target)
        end
      end
    end

    def faster_than?(target)
      t = target.is_a?(Battle::Battler) ? @ai.pokemon_to_projection(target) : target
      trick_room = @battle.field.effects[PBEffects::TrickRoom] != 0
      return false if t.nil?

      if trick_room
        effective_speed < t.effective_speed
      else
        effective_speed > t.effective_speed
      end
    end

    def target_has_killing_prio_move?(target)
      # for move in target.moves
      #   echoln 'target_has_killing_priomove'
      #   echoln "move: #{move.name} base: #{move.baseDamage} calc damage: #{target.get_potential_move_damage(self,
      #                                                                                                       move)}"
      # end
      target.moves.any? do |move|
        move.priority > 0 && target.get_potential_move_damage(self, move) >= pokemon.hp + 8
      end
    end

    def target_has_2hko_prio_move?(target)
      target.moves.any? do |move|
        move.priority > 0 && target.get_potential_move_damage(self, move) >= pokemon.hp / 2
      end
    end

    def target_has_killing_move?(target)
      target.moves.any? { |move| target.get_potential_move_damage(self, move) >= pokemon.hp }
    end

    def fast_kill?(target)
      return false if target_has_killing_prio_move?(target)
      return true if has_killing_prio_move?(target)
      return true if has_killing_move?(target) && faster_than?(target)

      false
    end

    def slow_kill?(target)
      has_killing_move?(target) && !faster_than?(target)
    end

    def has_2hko?(target)
      return true if fast_kill?(target)

      for move in moves
        return true if get_potential_move_damage(target, move) >= target.pokemon.hp / 2
      end
      false
    end

    def target_fast_kill?(target)
      return false if has_killing_prio_move?(target)
      return true if target_has_killing_prio_move?(target)
      return true if target_has_killing_move?(target) && !faster_than?(target)

      false
    end

    def target_slow_kill?(target)
      target_has_killing_move?(target) && faster_than?(target)
    end

    def target_has_fast_2hko?(target)
      return true if target_fast_kill?(target)

      for move in target.moves
        return true if target.get_potential_move_damage(self,
                                                        move) >= pokemon.hp / 2 && !faster_than?(target)
        return true if target_has_2hko_prio_move?(target)
      end
      false
    end

    def target_has_2hko?(target)
      return true if target_fast_kill?(target)

      for move in target.moves
        # echoln "move #{move.name} #{target.get_potential_move_damage(self,move)}"
        return true if target.get_potential_move_damage(self, move) >= pokemon.hp / 2
      end
      false
    end

    def target_highest_move_damage(target)
      move_damage = []
      target.moves.each { |move| move_damage.push(target.get_potential_move_damage(self, move)) }
      move_damage = move_damage.sort
      move_damage[-1]
    end

    def totalHazardDamage(pkmn)
      percentdamage = 0
      eff = 0
      if pkmn.pbOwnSide.effects[PBEffects::Spikes] > 0 && !pkmn.airborne? && pkmn.ability != :MAGICGUARD && !pkmn.hasActiveItem?(:HEAVYDUTYBOOTS)
        spikesdiv = [8, 8, 6, 4][pkmn.pbOwnSide.effects[PBEffects::Spikes]]
        percentdamage += (100.0 / spikesdiv).floor
      end
      if pkmn.pbOwnSide.effects[PBEffects::StealthRock] && pkmn.ability != :MAGICGUARD && !pkmn.hasActiveItem?(:HEAVYDUTYBOOTS) && pkmn.ability != :SCALER
        eff = Effectiveness.calculate(:ROCK, pkmn.type1, pkmn.type2) / 8
      end
      percentdamage += (12.5 * eff).floor
      percentdamage
    end

    def can_switch?
      party = @battle.pbParty(index)
      fainted = 0
      return false if @battle.wildBattle?

      for i in party
        fainted += 1 if i.fainted?
      end
      return false if fainted == party.length - 1
      return false if trapped?

      true
    end

    def trapped?
      return true if effects[PBEffects::Trapping] > 0
      return true if effects[PBEffects::MeanLook] >= 0
      return true if effects[PBEffects::JawLock] >= 0
      return true if @battle.allBattlers.any? { |b| b.effects[PBEffects::JawLock] == index }
      return true if effects[PBEffects::Octolock] >= 0
      return true if effects[PBEffects::Ingrain]
      return true if effects[PBEffects::NoRetreat]
      return true if @battle.field.effects[PBEffects::FairyLock] > 0

      trapped = false
      opposing_side.battlers.each do |target|
        next if target.nil?
        next if nil?

        trapped = true if (target.hasActiveAbility?(:ARENATRAP) && !airborne? && !pokemon.hasType?(:GHOST) && !hasActiveItem?(:SHEDSHELL)) || (target.hasActiveAbility?(%i[
                                                                                                                                                                          SHADOWTAG DEATHGRIP
                                                                                                                                                                        ]) && !pokemon.hasType?(:GHOST) && !hasActiveItem?(:SHEDSHELL))
      end
      trapped
    end

    def discourage_making_contact_with?(target)
      return false if has_ability?(:LONGREACH)
      return false if has_item?(:PROTECTIVEPADS)

      bad_abilities = %i[WEAKARMOR STAMINA IRONBARBS ROUGHSKIN PERISHBODY]
      return true if bad_abilities.any? { |a| target.has_ability?(a) }
      return true if target.has_ability?(:CUTECHARM) && target.can_attract?(self)
      return true if (target.has_ability?(:GOOEY) || target.has_ability?(:TANGLINGHAIR)) && faster_than?(target)
      return true if target.has_item?(:ROCKYHELMET)
      return true if target.has_ability?(:EFFECTSPORE) && !has_type?(:GRASS) && !has_ability?(:OVERCOAT)

      if (target.has_ability?(:STATIC) || target.has_ability?(:POISONPOINT) || target.has_ability?(:FLAMEBODY) || target.has_ability?(:ICEBODY)) && !has_non_volatile_status?
        true
      end
    end

    def get_move_damage(target, move)
      return 0 if target.nil?
      return 0 if @battler.nil?

      mov = AI_Move.new(@ai, move)

      calcType = mov.pbCalcType(self)
      mon = target.is_a?(Battle::Battler) ? target : target.battler
      mon.damageState.typeMod = mov.pbCalcTypeMod(calcType, self, mon)
      mov.pbCalcDamage(self, mon)
      multipliers = {
        base_damage_multiplier: 1.0,
        attack_multiplier: 1.0,
        defense_multiplier: 1.0,
        final_damage_multiplier: 1.0
      }
      mon.damageState.calcDamage
    end

    def get_potential_move_damage(target, move)
      # mon = target if mon.nil?
      # echoln "target class : #{target.class}"
      # echoln "target mon : #{target.pokemon}"
      mon = target.is_a?(Battle::Battler) ? target : target.battler
      if target.is_a?(AI_Learn) && mon.nil?
        mon = pbMakeFakeBattler(target.pokemon)
        target = pbMakeFakeBattler(target.pokemon)
      end
      # echoln "mon : #{mon}"
      user = @battler.nil? ? pbMakeFakeBattler(pokemon) : @battler
      move = Battle::Move.from_pokemon_move(@ai.battle, move) if move.is_a?(Pokemon::Move)
      # echoln "mon : #{mon}"
      return 0 if mon.nil?
      return 0 if move.category == 2
      return 0 if move.nil?

      move = move.is_a?(Pokemon::Move) ? Battle::Move.from_pokemon_move(@battle, move) : move
      mov = AI_Move.new(@ai, move)
      calcType = mov.pbCalcType(user)
      mon.damageState.typeMod = mov.pbCalcTypeMod(calcType, user, mon)
      # echoln "mon.damageState.typeMod: #{mon.damageState.typeMod}\n"
      # echoln "name : #{move.name} basedamage: #{move.baseDamage}\n"
      ret = mov.pbCalcDamage(user, mon)
      sturdy = target.hasActiveAbility?(:STURDY) && !@battle.moldBreaker || target.hasActiveItem?(:FOCUSSASH)
      ret = target.totalhp - 1 if ret >= target.hp && target.hp == target.totalhp && sturdy
      ret = (target.hp - user.hp) if user && target && move.id == :ENDEAVOR
      ret = user.hp if user && move.id == :FINALGAMBIT
      # echo "get_potential_move_damage move: #{move.name}, ret: #{ret}\n"
      ret
    end

    # Calculates the combined type effectiveness of all user and target types
    def calculate_type_matchup(target)
      user_types = pbTypes(true)
      target_types = target.pbTypes(true)
      mod = 1.0
      user_types.each do |user_type|
        target_types.each do |target_type|
          user_eff = GameData::Type.get(target_type).effectiveness(user_type)
          mod *= user_eff / 2.0
          target_eff = GameData::Type.get(user_type).effectiveness(target_type)
          mod *= 2.0 / target_eff
        end
      end
      mod
    end

    # Calculates the type effectiveness of a particular move against this user
    def calculate_move_matchup(move_id)
      move = Battle::Move.from_pokemon_move(@ai.battle, Pokemon::Move.new(move_id))
      # Calculate the type this move would be if used by us
      mon = is_a?(AI_Learn) ? pbMakeFakeBattler(pokemon) : @battler
      types = move.pbCalcType(mon)
      types = [types] unless types.is_a?(Array)
      user_types = types
      target_types = pbTypes(true)
      mod = 1.0
      user_types.each do |user_type|
        target_types.each do |target_type|
          user_eff = GameData::Type.get(target_type).effectiveness(user_type)
          mod *= user_eff / 2.0
        end
      end
      mod
    end

    def calculate_hits_to_kill_with_best_move(target)
      best_dmg = 1
        moves.each do |move|
          temp_dmg = get_potential_move_damage(target, move)
          best_dmg = temp_dmg if temp_dmg > best_dmg
          
        end
      turns_to_kill = (target.hp/best_dmg).ceil
      turns_to_kill
    end

    # Whether the type matchup between the user and target is favorable
    def bad_against?(target)
      calculate_type_matchup(target) < 1.0
    end

    # Whether the user would be considered an underdog to the target.
    # Considers type matchup and level
    def underdog?(target)
      return true if bad_against?(target)
      return true if target.level >= level + 5

      false
    end

    def has_usable_move_type?(type)
      moves.any? { |m| m.type == type && m.pp > 0 }
    end

    def get_offense_score(target)
      # NOTE: self does not have a @battler value as it is a party member, i.e. only a Battle::Pokemon object
      # Return 1.0+ value if self is good against the target
      # Note: self does not have a @battler value as it is a party member, i.e. only a Battle::Pokemon object
      # Return 1.0+ value if self is good against the target
      user_types = pbTypes(true)
      target_types = target.pbTypes(true)
      immune = {
        ability: [
          %i[FLASHFIRE WELLBAKEDBODY STEAMENGINE],
          %i[WATERABSORB STORMDRAIN DRYSKIN WATERCOMPACTION STEAMENGINE],
          [:SAPPSIPPER],
          %i[VOLTABSORB LIGHTNINGROD MOTORDRIVE],
          %i[LEVITATE EARTHEATER],
          [:SCALER],
          [:UNTAINTED],
          [:PASTELVEIL],
          [:LEGENDARMOR]
        ],
        type: %i[FIRE WATER GRASS ELECTRIC GROUND ROCK DARK POISON DRAGON]
      }
      target_ability = target.pokemon.ability_id
      max = 0
      user_types.each do |user_type|
        next unless has_usable_move_type?(user_type)

        mod = 1.0
        target_types.each do |target_type|
          eff = GameData::Type.get(target_type).effectiveness(user_type) / 2.0
          mod *= if eff >= 2.0
                   eff
                 else
                   eff
                 end
          for i in 0..8
            if immune[:ability][i].include?(target_ability) && immune[:type][i] == user_type && !@battle.moldBreaker
              mod *= 0.0
            end
          end
        end
        max = mod if mod > max
      end
      max
    end

    def end_of_round
      @flags = {}
      $ai_flags = {}
      $doubles_switch = nil
      $d_switch = 0
      $test_trigger = false
    end
  end

  class Side
    attr_reader :ai, :index, :battlers, :party, :trainers, :flags

    def initialize(ai, index, wild_pokemon = false)
      @ai = ai
      @index = index
      @battle = @ai.battle
      @wild_pokemon = wild_pokemon
      @battlers = []
      @party = []
    end

    def effects
      @battle.sides[@index].effects
    end

    def set_party(party)
      @party = party.map { |pokemon| AI_Learn.new(self, pokemon, @wild_pokemon) }
    end

    def set_trainers(trainers)
      @trainers = trainers
    end

    def opposing_side
      @ai.sides[1 - @index]
    end

    def recall(battlerIndex)
      index = PBAI.battler_to_proj_index(battlerIndex)
      proj = @battlers[index]
      raise 'Battler to be recalled was not found in the active battlers list.' if proj.nil?
      raise 'Battler to be recalled was not active.' unless proj.active?

      @battlers[index] = nil
      proj.battler = nil
    end

    def send_out(battlerIndex, battler)
      proj = @party.find { |proj| proj && proj.pokemon == battler.pokemon }
      raise 'Battler to be sent-out was not found in the party list.' if proj.nil?

      # if proj.active?
      #    raise "Battler to be sent-out was already sent out before."
      # end
      index = PBAI.battler_to_proj_index(battlerIndex)
      @battlers[index] = proj
      proj.ai_index = index
      proj.battler = battler
    end

    def start_calcs(battler)
      proj = battler.is_a?(AI_Learn) ? battler : @ai.pokemon_to_projection(battler.pokemon)
      opposing_side.party.each do |target|
        next if target.fainted?
        next if proj.self_calc.keys.include?(target.pokemon.species)

        opp = @ai.pbMakeFakeBattler(target.pokemon)
        proj.calc_all(target)
        proj.calc_all_self(opp)
      end
    end

    def end_of_round
      @battlers.each do |proj|
        next unless proj

        proj.end_of_round if proj
      end
      $switch_flags = {}
      $ai_flags = {}
      @flags = {}
    end
  end
end

class Battle
  attr_reader :battleAI

  alias ai_initialize initialize
  def initialize(*args)
    ai_initialize(*args)
    @battleAI = PBAI.new(self, wildBattle?)
    @battleAI.sides[0].set_party(@party1)
    @battleAI.sides[0].set_trainers(@player)
    @battleAI.sides[1].set_party(@party2)
    @battleAI.sides[1].set_trainers(@opponent)
  end

  def pbRecallAndReplace(idxBattler, idxParty, batonPass = false)
    if @battlers[idxBattler].fainted?
      $doubles_switch = nil
      $d_switch = 0
    end
    unless @battlers[idxBattler].fainted?
      @scene.pbRecall(idxBattler)
      @battleAI.sides[idxBattler % 2].recall(idxBattler)
    end
    @battlers[idxBattler].pbAbilitiesOnSwitchOut # Inc. primordial weather check
    @scene.pbShowPartyLineup(idxBattler & 1) if pbSideSize(idxBattler) == 1
    pbMessagesOnReplace(idxBattler, idxParty)
    pbReplace(idxBattler, idxParty, batonPass)
  end

  # Bug fix (used b instead of battler)
  def pbMessageOnRecall(battler)
    if battler.pbOwnedByPlayer?
      if battler.hp <= battler.totalhp / 4
        pbDisplayBrief(_INTL('Good job, {1}! Come back!', battler.name))
      elsif battler.hp <= battler.totalhp / 2
        pbDisplayBrief(_INTL('OK, {1}! Come back!', battler.name))
      elsif battler.turnCount >= 5
        pbDisplayBrief(_INTL('{1}, that’s enough! Come back!', battler.name))
      elsif battler.turnCount >= 2
        pbDisplayBrief(_INTL('{1}, come back!', battler.name))
      else
        pbDisplayBrief(_INTL('{1}, switch out! Come back!', battler.name))
      end
    else
      owner = pbGetOwnerName(battler.index)
      pbDisplayBrief(_INTL('{1} withdrew {2}!', owner, battler.name))
    end
  end

  alias ai_pbEndOfRoundPhase pbEndOfRoundPhase
  def pbEndOfRoundPhase
    ai_pbEndOfRoundPhase
    @battleAI.end_of_round
    return unless $spam_block_triggered

    PBAI.spam_block_countdown
    PBAI.log_spam("#{$spam_block_flags[:counter]}")
    return unless $spam_block_flags[:counter] == 0

    $spam_block_triggered = false
    PBAI.log('=' * 30)
    PBAI.log_spam('Spam Block turned off')
    PBAI.spam_block_reset
    PBAI.log('=' * 30)
  end

  alias ai_pbShowAbilitySplash pbShowAbilitySplash
  def pbShowAbilitySplash(battler, delay = false, logTrigger = true)
    ai_pbShowAbilitySplash(battler, delay, logTrigger)
    @battleAI.reveal_ability(battler)
    $spam_block_flags[:double_intimidate].push(GameData::Ability.get(battler.ability).id) if battler.pbOwnedByPlayer?
  end
end

class Battle::Move
  attr_reader :statUp, :statDown

  alias ai_pbReduceDamage pbReduceDamage
  def pbReduceDamage(user, target)
    ai_pbReduceDamage(user, target)
    @battle.battleAI.register_damage(self, user, target, target.damageState.hpLost)
  end

  def pbCouldBeCritical?(user, target)
    return false if target.pbOwnSide.effects[PBEffects::LuckyChant] > 0
    return false if target.hasActiveItem?(:MITHRILSHIELD)

    # Set up the critical hit ratios
    ratios = Settings::MECHANICS_GENERATION >= 7 ? [24, 8, 2, 1] : [16, 8, 4, 3, 2]
    c = 0
    # Ability effects that alter critical hit rate
    c = PBAI::AbilityEffects.triggerCriticalCalcFromUser(user.ability, user, target, c) if c >= 0 && user.abilityActive?
    if c >= 0 && target.abilityActive? && !@battle.moldBreaker
      c = PBAI::AbilityEffects.triggerCriticalCalcFromTarget(target.ability, user, target, c)
    end
    # Item effects that alter critical hit rate
    c = PBAI::ItemEffects.triggerCriticalCalcFromUser(user.item, user, target, c) if c >= 0 && user.itemActive?
    c = PBAI::ItemEffects.triggerCriticalCalcFromTarget(target.item, user, target, c) if c >= 0 && target.itemActive?
    return false if c < 0
    # Move-specific "always/never a critical hit" effects
    return false if pbCritialOverride(user, target) == -1

    true
  end
end

class Battle::Battler
  alias ai_pbInitialize pbInitialize
  def pbInitialize(pkmn, idxParty, batonPass = false)
    ai_pbInitialize(pkmn, idxParty, batonPass)
    ai = @battle.battleAI
    sideIndex = @index % 2
    ai.sides[sideIndex].send_out(@index, self)
  end

  alias ai_pbFaint pbFaint
  def pbFaint(*args)
    ai_pbFaint(*args)
    @battle.battleAI.faint_battler(self)
  end

  def defensive?
    has_role?(%i[TANK PHAZER SCREENS DEFENSIVEPIVOT OFFENSIVEPIVOT PHYSICALWALL SPECIALWALL
                 TOXICSTALLER STALLBREAKER TRICKROOMSETTER TARGETALLY REDIRECTION CLERIC LEAD SKILLSWAPALLY])
  end

  def setup?
    has_role?(%i[SETUPSWEEPER WINCON PHYSICALBREAKER SPECIALBREAKER])
  end

  def pivot?
    has_role?(%i[DEFENSIVEPIVOT OFFENSIVEPIVOT])
  end

  def priority_blocking?
    hasActiveAbility?(%i[QUEENLYMAJESTY DAZZLING ARMORTAIL])
  end

  def immune_to_status?(target)
    hasActiveAbility?(:GOODASGOLD) || (types.include?(:DARK) && target.hasActiveAbility?(:PRANKSTER))
  end

  def effective_speed
    mon = self
    stageMul = [2, 2, 2, 2, 2, 2, 2, 3, 4, 5, 6, 7, 8]
    stageDiv = [8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2]
    stage = mon.stages[:SPEED] + 6
    stage -= 1 if mon != @battler && mon.pbOwnSide.effects[PBEffects::StickyWeb]
    mults_abil = 1.0
    mults_item = 1.0
    mults = 1.0
    mults_abil = Battle::AbilityEffects.triggerSpeedCalc(mon.ability, mon, mults) if mon.abilityActive?
    # Item effects that alter calculated Speed
    mults_item = Battle::ItemEffects.triggerSpeedCalc(mon.item, mon, mults) if mon.itemActive?
    mults *= 2 if mon.pbOwnSide.effects[PBEffects::Tailwind] > 0
    mults /= 2 if mon.status == :PARALYSIS
    speed = (mon.speed.to_f * stageMul[stage] / stageDiv[stage]).floor
    speed * mults_abil * mults_item * mults
  end
end

class Array
  def sum
    n = 0
    each { |e| n += e }
    n
  end
end

# Overwrite Frisk to show the enemy held item
Battle::AbilityEffects::OnSwitchIn.add(:FRISK,
                                       proc { |ability, battler, battle|
                                         foes = []
                                         battle.eachOtherSideBattler(battler.index) do |b|
                                           foes.push(b) unless b.item.nil?
                                         end
                                         if foes.length > 0
                                           battle.pbShowAbilitySplash(battler)
                                           if Settings::MECHANICS_GENERATION >= 7
                                             foes.each do |b|
                                               battle.pbDisplay(_INTL('{1} frisked {2} and found its {3}!',
                                                                      battler.pbThis, b.pbThis(true), GameData::Item.get(b.item).name))
                                               battle.battleAI.reveal_item(b)
                                             end
                                           else
                                             foe = foes[battle.pbRandom(foes.length)]
                                             battle.pbDisplay(_INTL('{1} frisked the foe and found one {2}!',
                                                                    battler.pbThis, GameData::Item.get(foe.item).name))
                                             battle.battleAI.reveal_item(foe)
                                           end
                                           battle.pbHideAbilitySplash(battler)
                                         end
                                       })
