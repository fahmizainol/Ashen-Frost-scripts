class GoatAI
    attr_accessor :battle #:Battle

    attr_accessor :player_trainer
    attr_accessor :ai_trainer
    attr_accessor :battlers
    attr_accessor :player_battler
    attr_accessor :ai_battler

    attr_accessor :move_scores
    attr_accessor :switch_score
    attr_accessor :threat_score

    def initialize(battle)
        @battle = battle
        @player_trainer = @battle.player
        @ai_trainer = @battle.opponent
        @battlers = @battle.battlers
        @player_battler = @battle.battlers[0] # Just doing single now
        @ai_battler = @battle.battlers[1]

        @move_scores = [[-1, -1, -1, -1]] # [moveidx]
        @switch_score = 0
    end

    def pbProcessAITurn
        print "inspecting self"
        # print(@battle.battlers[1].pokemon)
        # PBDebug.log(@battle.battlers[1].moves)
        @move_scores = pbGetMoveScore
        # @move_scores
    end

    def pbGetMoveScore
        fake_player_mon = pbMakeFakeBattler(@battle.battlers[0].displayPokemon, false)
        move_scores = [[-1, -1, -1, -1]]
        # echo "fake hp #{fake_player_mon.totalhp}"
        # echo "fake mon abilioty #{fake_player_mon.hasActiveAbility?(:ADAPTABILITY)}"
        # print(@battle.battlers[1].pokemon)
        @battle.eachSameSideBattler(1) do |b|
            b.eachMoveWithIndex do |move, i|
                move.pbCheckDamageAbsorption(b, @battle.battlers[0])
                # move.pbCheckDamageAbsorption(b, fake_player_mon)
                move.pbCalcDamage(b, fake_player_mon)
                dmg =move.pbReduceDamage(b, fake_player_mon)
                move_scores[0][i] = dmg
            end
            # move_scores[0][i] = pbReduceDamage(@battle.battlers[1], @battle.battlers[0])
            # echo(move_scores)
            # echo "test: #{test}"
            # echo b.moves
        end
        echo "move_scores: #{move_scores}"
        return move_scores
    end

    def pbMakeFakeBattler(pokemon,batonpass=false)
        return nil if pokemon.nil?
        pokemon = pokemon.clone
        battler = Battle::Battler.new(@battle,@index)
        return if battler.pokemon == pokemon
        battler.pbInitPokemon(pokemon,@index)
        battler.pbInitEffects(batonpass)
        return battler
      end
    end