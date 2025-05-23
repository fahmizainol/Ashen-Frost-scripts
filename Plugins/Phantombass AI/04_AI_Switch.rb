class PBAI
  class SwitchHandler
    @@GeneralCode = []
    @@TypeCode = []
    @@SwitchOutCode = []

    def self.add(&code)
       @@GeneralCode << code
     end

    def self.add_type(*type,&code)
      @@TypeCode << code
    end

    def self.add_out(&code)
      @@SwitchOutCode << code
    end

    def self.trigger(list,score,ai,battler,proj,target)
      return score if list.nil?
      list = [list] if !list.is_a?(Array)
      list.each do |code|
      next if code.nil?
        newscore = code.call(score,ai,battler,proj,target)
        score = newscore if newscore.is_a?(Numeric)
      end
      return score
    end

    def self.out_trigger(list,score,ai,battler,target)
      return score if list.nil?
      list = [list] if !list.is_a?(Array)
      list.each do |code|
      next if code.nil?
        # echoln "code: #{code}"
        newscore = code.call(score,ai,battler,target)
        score = newscore if newscore.is_a?(Numeric)
      end
      return score
    end

    def self.trigger_general(score,ai,battler,proj,target)
      return self.trigger(@@GeneralCode,score,ai,battler,proj,target)
    end

    def self.trigger_out(score,ai,battler,target)
      return self.out_trigger(@@SwitchOutCode,score,ai,battler,target)
    end

    def self.trigger_type(type,score,ai,battler,proj,target)
      return self.trigger(@@TypeCode,score,ai,battler,proj,target)
    end
  end
end

#=======================
#Type Immunity Switch Out Determination
#=======================

PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next unless target.moves.any? {|move| move.damagingMove? && move.type == :FIRE}
  target_moves = target.moves
  for i in target_moves
    next if target_moves == nil
    has_move = true if i.type == :FIRE && i.damagingMove? && battler.calculate_move_matchup(i.id) > 1
  end
  if has_move
    score += 3
    PBAI.log_switch_out(3,"Fire type matchup")
    $switch_flags[:fire] = true
  end
  next score
end

PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next unless target.moves.any? {|move| move.damagingMove? && move.type == :WATER}
  target_moves = target.moves
  for i in target_moves
    next if target_moves == nil
    has_move = true if i.type == :WATER && i.damagingMove? && battler.calculate_move_matchup(i.id) > 1
  end
  if has_move
      score += 3
      PBAI.log_switch_out(3,"Water type matchup")
      $switch_flags[:water] = true
    end
  next score
end

PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next unless target.moves.any? {|move| move.damagingMove? && move.type == :GRASS}
  target_moves = target.moves
  for i in target_moves
    next if target_moves == nil
    has_move = true if i.type == :GRASS && i.damagingMove? && battler.calculate_move_matchup(i.id) > 1
  end
  if has_move
      score += 3
      PBAI.log_switch_out(3,"Grass type matchup")
      $switch_flags[:grass] = true
    end
  next score
end

PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next unless target.moves.any? {|move| move.damagingMove? && move.type == :ELECTRIC}
  target_moves = target.moves
  for i in target_moves
    next if target_moves == nil
    has_move = true if i.type == :ELECTRIC && i.damagingMove? && battler.calculate_move_matchup(i.id) > 1
  end
  if has_move
      score += 3
      PBAI.log_switch_out(3,"Electric type matchup")
      $switch_flags[:electric] = true
    end
  next score
end

PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next unless target.moves.any? {|move| move.damagingMove? && move.type == :POISON}
  target_moves = target.moves
  for i in target_moves
    next if target_moves == nil
    has_move = true if i.type == :POISON && i.damagingMove? && battler.calculate_move_matchup(i.id) > 1
  end
  if has_move
      score += 3
      PBAI.log_switch_out(3,"Poison type matchup")
      $switch_flags[:poison] = true
    end
  next score
end

PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next unless target.moves.any? {|move| move.damagingMove? && move.type == :GROUND}
  target_moves = target.moves
  for i in target_moves
    next if target_moves == nil
    has_move = true if i.type == :GROUND && i.damagingMove? && battler.calculate_move_matchup(i.id) > 1
  end
  if has_move
      score += 3
      PBAI.log_switch_out(3,"Ground type matchup")
      $switch_flags[:ground] = true
    end
  if target.inTwoTurnAttack?("TwoTurnAttackInvulnerableUnderground")
    score += 2
    $switch_flags[:digging] = true
    PBAI.log_switch_out(2,"Factor in digging")
  end
  next score
end

PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next unless target.moves.any? {|move| move.damagingMove? && move.type == :ROCK}
  target_moves = target.moves
  for i in target_moves
    next if target_moves == nil
    has_move = true if i.type == :ROCK && i.damagingMove? && battler.calculate_move_matchup(i.id) > 1
  end
  if has_move
      score += 3
      PBAI.log_switch_out(3,"Rock type matchup")
      $switch_flags[:rock] = true
    end
  next score
end

PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next unless target.moves.any? {|move| move.damagingMove? && move.type == :DARK}
  target_moves = target.moves
  for i in target_moves
    next if target_moves == nil
    has_move = true if i.type == :DARK && i.damagingMove? && battler.calculate_move_matchup(i.id) > 1
  end
  if has_move
      score += 3
      PBAI.log_switch_out(3,"Dark type matchup")
      $switch_flags[:dark] = true
    end
  next score
end

PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next unless target.moves.any? {|move| move.damagingMove? && move.type == :DRAGON}
  target_moves = target.moves
  for i in target_moves
    next if target_moves == nil
    has_move = true if i.type == :DRAGON && i.damagingMove? && battler.calculate_move_matchup(i.id) > 1
  end
  if has_move
      score += 3
      PBAI.log_switch_out(3,"Dragon type matchup")
      $switch_flags[:dragon] = true
    end
  next score
end

#=======================
# Other Determination of Whether to Switch Out
#=======================

# Matchup and Speed based
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  ttk = battler.calculate_hits_to_kill_with_best_move(target)
  echoln "ttk : #{ttk}"
  move = 0
  move2 = 0
  target_moves = target.moves
  calc = 0
  damage = 0
  pivot = nil
  if target.bad_against?(battler)
    if battler.fast_kill?(target)
      score -= 7
      PBAI.log_switch_out(-7,"We have fast kill")
    elsif battler.slow_kill?(target)
      score -= 5
      PBAI.log_switch_out(-5,"We have slow kill")
    elsif battler.target_fast_kill?(target)
      score += 4
      PBAI.log_switch_out(4,"Target has fast kill")
    end
  elsif battler.bad_against?(target)
    score -= 2
    PBAI.log_switch_out(-2,"Do not switch if target is bad against us")
  end
  next score
end

# Don't score out if under Power Trick
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next score if !battler.effects[PBEffects::PowerTrick]
  score -= 5
  PBAI.log_switch_out(-5,"Power Trick active")
  next score
end

# Don't score if behind a Substitute
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next score if battler.effects[PBEffects::Substitute] <= 0
  score -= 5
  PBAI.log_switch_out(-5,"Behind a Substitute")
  next score
end

# Don't score if immune to Ally spread attacks
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next score if !ai.battle.doublebattle
  ally = battler.side.battlers.find {|pm| pm && pm != battler && !pm.fainted?}
  next score if ally.nil?
  for move in ally.moves
    if ally.target_is_immune?(move,battler) && [:AllNearOthers,:AllBattlers,:BothSides].include?(move.pbTarget(battler))
      score -= 3
      PBAI.log_switch_out(-3,"Immune to ally spread move")
    end
  end
  next score
end

#Switch determined by whether you're set up
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  if battler.set_up_score > 0
    score -= 5
    PBAI.log_switch_out(-5,"Do not reset buffed stats")
  elsif battler.set_up_score < 0
    if battler.stages[:SPEED] < 0 && ai.battle.field.effects[PBEffects::TrickRoom] != 0
      score -= 5
      PBAI.log_switch_out(-5,"Abuse Trick Room")
    else
      score += battler.set_up_score.abs
      PBAI.log_switch_out(battler.set_up_score.abs,"Reset lowered stats")
    end
  end
  next score
end

# Switch if you're on your second Toxic turn or more
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  if battler.effects[PBEffects::Toxic] > 1
    score += 2
    PBAI.log_switch_out(2,"Reset Toxic clock")
  end
  next score
end

# Switching based on status and ability to abuse/cure
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  party = ai.battle.pbParty(battler.index)
  if battler.status != :NONE
    if party.any? {|pkmn| !pkmn.fainted? && [:CLERIC].include?(pkmn.roles) && !battler.has_role(:CLERIC)}
      score += 2
      $switch_flags[:need_cleric] = true
      PBAI.log_switch_out(2,"Try to switch to heal status with a Cleric in the back")
    end
    if battler.hasActiveAbility?(:NATURALCURE)
      score += 2
      PBAI.log_switch_out(2,"Heal with Natural Cure")
    end
    if battler.hasActiveAbility?(:GUTS)
      score -= 5
      PBAI.log_switch_out(-5,"Abuse Guts")
    end
  end
  next score
end

# Switch if Future Sight about to trigger and we have a Dark type
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  pos = ai.battle.positions[battler.index]
  party = ai.battle.pbParty(battler.index)
  # If Future Sight will hit at the end of the round
  if pos.effects[PBEffects::FutureSightCounter] == 1
    # And if we have a dark type in our party
    if party.any? { |pkmn| pkmn.types.include?(:DARK) }
      # We should score to a dark type,
      # but not if we're already close to dying anyway.
      if !battler.may_die_next_round?
        score += 2
        $switch_flags[:dark] = true
        PBAI.log_switch_out(2,"Try to switch due to Future Sight")
      end
    end
  end
  next score
end

#Switch if we can't 3HKO
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  calc = 0
  battler.opposing_side.battlers.each do |target|
    next if target.nil?
    next if ai.battle.wildBattle?
    for i in battler.moves
      next if i.statusMove?
      dmg = battler.get_calc_self(target, i)
      calc += 1 if dmg >= target.hp/3
    end
  end
  if calc == 0
    score += 3
    PBAI.log_switch_out(3,"Try to switch because we cannot 3HKO")
  end
  next score
end

#Don't score if we are trapped
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  if battler.trapped?
    score -= 10
    PBAI.log_switch_out(-10,"Trapped so don't try to score")
  end
  if !battler.can_switch?
    score -= 20
    PBAI.log_switch_out(-20,"Cannot switch anyway")
  end
  next score
end

#Battler Yawned
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  if battler.effects[PBEffects::Yawn] == 1
    score += 3
    PBAI.log_switch_out(3,"Try to switch due to being yawned")
  end
  next score
end

#Battler Salt Cured
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  if battler.effects[PBEffects::SaltCure]
    score += 3
    PBAI.log_switch_out(3,"Try to switch due to being salt cured")
  end
  next score
end

#Battler set up Focus Energy
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  if battler.effects[PBEffects::FocusEnergy] > 0 && battler.has_role?(:CRIT)
    score -= 5
    PBAI.log_switch_out(-5,"Do not switch to avoid negating Focus Energy")
  end
  next score
end

# Switch if target has a super effective move
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  target_moves = target.moves
  for move in target_moves
    if battler.calculate_move_matchup(move.id) > 1
      score += battler.calculate_move_matchup(move.id)
      PBAI.log_switch_out(battler.calculate_move_matchup(move.id),"Target has super effective move")
      $switch_flags[:move] = move
      break
    end
  end
  next score
end

# Establish setup fodder and score 
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  target_moves = target.moves
  threat_moves = 0
  battler.opposing_side.battlers.each do |target|
    next if target.nil?
    next if ai.battle.wildBattle?
    next if target_moves == nil
      target_moves.each do |move|
        next if move.statusMove?
        # TODO: might wanna consider status moves like burned, frostbite, etc
        dmg = target.get_potential_move_damage(battler, move)
        threat_moves += 1 if dmg >= battler.hp/2
      end
  end
  if threat_moves == 0
    $learned_flags[:setup_fodder].push(target)
    add = battler.setup? ? -4 : 4
    score += add
    PBAI.log_switch_out(add,"Establishing setup fodder since they have no threatening moves")
  end
  next score

end
# Establish setup fodder and score if we can't set up and can't 2HKO
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  target_moves = target.moves
  calc = 0
  damage = 0
  flag1 = false
  flag2 = false
  battler.opposing_side.battlers.each do |target|
    next if target.nil?
    next if ai.battle.wildBattle?
    next if target_moves == nil
    for i in target_moves
      calc += 1 if i.damagingMove?
    end
    if calc <= 0
      flag1 = true
    end
    for i in battler.moves
      dmg = battler.get_calc_self(target, i)
      damage += 1 if dmg >= target.totalhp/2
    end
    if damage == 0
      flag2 = true
    end
    if flag1 == true && flag2 == true
      $learned_flags[:setup_fodder].push(target)
      add = battler.setup? ? -2 : 2
      score += add
      PBAI.log_switch_out(add,"Establishing setup fodder")
    end
  end
  next score
end

# Switch if toxic spikes on the field and we have a grounded Poison that won't be 2HKO'd
# PBAI::SwitchHandler.add_out do |score,ai,battler,target|
#   pos = ai.battle.positions[battler.index]
#   party = ai.battle.pbParty(battler.index)
#   tspikes = $toxic_spikes[target.idxOpposingSide] == 0 ? 0 : $toxic_spikes[target.idxOpposingSide]
#   if tspikes > 0
#     if party.any? { |pkmn| pkmn.hasType?(:POISON) && pkmn.grounded? && !target.moves.any? {|move| Effectiveness.super_effective_type?(move.type,pkmn.types[0],pkmn.types[1])}}
#       score += tspikes
#       PBAI.log_switch_out(tspikes,"Toxic spikes removal")
#     end
#   end
#   next score
# end

# Switch determined by being choiced
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  $choiced_score = false
  if battler.choice_locked?
    choiced_move_name = GameData::Move.get(battler.effects[PBEffects::ChoiceBand])
    factor = 0
    battler.opposing_side.battlers.each do |pkmn|
      next if pkmn.nil?
      factor += pkmn.calculate_move_matchup(choiced_move_name)
    end
    if (factor < 1 && ai.battle.pbSideSize(0) == 1) || (factor < 2 && ai.battle.pbSideSize(0) == 2)
      score += 2
      PBAI.log_switch_out(2,"Choiced mon switch ins")
      $choiced_score = true
    end
    move = Battle::Move.from_pokemon_move(ai.battle,Pokemon::Move.new(choiced_move_name))
    if target.target_is_immune?(move,battler)
      score += 5
      PBAI.log_switch_out(5,"Immunity to move mon is choiced into")
      $choiced_score = true
    end
  end
  next score
end


# Don't switch if you have a non-bad matchup
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  weak = target.moves.any? {|move| move.damagingMove? && battler.get_calc(target,move) >= battler.hp}
  if battler.turnCount == 0 && weak == false
    score -= 5
    PBAI.log_switch_out(-5,"to not switch if we don't have a bad matchup.")
  end
  next score
end

# Battler Encored
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  if battler.effects[PBEffects::Encore] > 0
    encored_move_index = battler.pbEncoredMoveIndex
    if encored_move_index >= 0
      encored_move = battler.moves[encored_move_index]
      if encored_move.statusMove?
        score += 5
        PBAI.log_switch_out(5,"Encored into status move")
      else
        dmg = battler.get_calc_self(target, encored_move)
        if dmg > target.totalhp/2
          score -= 3
          PBAI.log_switch_out(-3,"Encored into good move")
        else
          # No record of dealing damage with this move,
          # which probably means the target is immune somehow,
          # or the battler happened to miss. Don't risk being stuck in
          # a bad move in any case, and score.
          score += 3
          PBAI.log_switch_out(3,"Encored into bad move")
        end
      end
    end
  end
  next score
end

# Switch if we will struggle
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  if !ai.battle.pbCanChooseAnyMove?(battler.index)
    score += 10
    PBAI.log_switch_out(10,"Preventing Struggle")
  end
  next score
end

# Switch if in last Perish Song turn
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  if battler.effects[PBEffects::PerishSong] == 1
    score += 10
    PBAI.log_switch_out(10,"Dodging Perish Song")
  end
  next score
end

# Don't score if you have Unburden proced
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  if battler.effects[PBEffects::Unburden] && !battler.item
    score -= 10
    PBAI.log_switch_out(-10,"Not wasting Unburden")
  end
  next score
end


# Don't switch if the rest of the party doesn't match well / Only switch if there is a mon in the party that can switch in
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  party = ai.battle.pbParty(battler.index)
  add = 0
  party.each do |pkmn|
    next if pkmn.fainted?
    next if pkmn == battler.pokemon
    mon = ai.pbMakeFakeBattler(pkmn) rescue nil
    mn = ai.pokemon_to_projection(pkmn)
    next if mon.nil?
    moves = 0
    best = 0
    target.moves.each do |move|
      next if move.statusMove?
      # echoln "i m switchahandler"
      # echoln "target: #{target}"
      dmg = target.get_potential_move_damage(mon, move) # FIXME: battler should be passed here since we're calcing the player's move against ai
      moves += 1 if dmg >= mon.hp/2
      best += 1 if dmg < mon.hp/2
    end
    $switch_flags[:has_se_move] = [] if !$switch_flags[:has_se_move]
    $switch_flags[:has_se_move] << pkmn if moves > 0
    PBAI.log("Good moves against #{pkmn.name}: #{moves}")
    if moves == 0 && best > 0
      add += 1 # So this determined by how much good switch ins ai has, not how good the potential switch in 
    end
  end
  if add > 0
    score += add
    PBAI.log_switch_out(add,"for having #{add} good switch ins and having a bad matchup")
  end
  if add == 0
    score -= 3
    PBAI.log_switch_out(-3,"for having no good switch ins")
  end
  PBAI.log("Good switch ins: #{add}")
  next score
end

=begin
# Anti Abuse Switch Choice
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next score if !$spam_block_triggered
  next score if !$spam_block_flags[:choice].is_a?(Battle::Move)
  nextMove = $spam_block_flags[:choice]
  nextDmg = battler.get_calc(target,nextMove)
  if nextDmg < battler.hp/2 || nextDmg < battler.totalhp/3
    score -= 3
    PBAI.log_switch_out(-3,"Spam Block consideration")
  end
  next score
end
=end
#Final score determination
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  next score if $switch_flags[:switch] == nil
  add = $switch_flags[:switch] ? 3 : 0
  if $choiced_score == true
    score += add
    PBAI.log_switch_out(add,"for having a good switch in to a choiced mon")
  end
  next score
end

#=======================
# Code for Weather Abusers for later
#=======================

=begin
#Weather Abusers
PBAI::SwitchHandler.add_out do |score,ai,battler,target|
  weather = [:DROUGHT,:DRIZZLE,:SANDSTREAM,:SANDSPIT,:DESOLATELAND,:PRIMORDIALSEA,:DELTASTREAM,:SNOWWARNING]
  weather_move = [:RAINDANCE,:SANDSTORM,:SUNNYDAY,:SNOWSCAPE]
  abuser = battler.side.party.find {|mon|
  pkmn = ai.pbMakeFakeBattler(mon)
  pkmn.has_role?(:WEATHERTERRAINABUSER)}
  changer = battler.opposing_side.battlers.find {|pkmn| pkmn.hasActiveAbility?(weather) || pkmn.hasMove?(weather_move) }
  if battler.has_role?(:WEATHERTERRAIN) && !abuser.nil? && !changer.nil?
    score = true
  end
  next score
end
=end
