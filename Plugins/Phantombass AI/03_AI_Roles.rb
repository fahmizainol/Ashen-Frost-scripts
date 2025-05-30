module GameData
  class Role
    attr_reader :id, :id_number, :real_name

    DATA = {}

    extend ClassMethods
    include InstanceMethods

    def self.load; end
    def self.save; end

    def initialize(hash)
      @id           = hash[:id]
      @id_number    = hash[:id_number]    || -1
      @real_name    = hash[:name]         || 'Unnamed'
    end

    # @return [String] the translated name of this Role
    def name
      _INTL(@real_name)
    end
  end
end

module Compiler
  def write_trainers(path = 'PBS/trainers.txt')
    write_pbs_file_message_start(path)
    File.open(path, 'wb') do |f|
      idx = 0
      add_PBS_header_to_file(f)
      GameData::Trainer.each do |trainer|
        echo '.' if idx % 50 == 0
        idx += 1
        Graphics.update if idx % 250 == 0
        f.write("\#-------------------------------\r\n")
        if trainer.version > 0
          f.write(format("[%s,%s,%d]\r\n", trainer.trainer_type, trainer.real_name, trainer.version))
        else
          f.write(format("[%s,%s]\r\n", trainer.trainer_type, trainer.real_name))
        end
        f.write(format("Items = %s\r\n", trainer.items.join(','))) if trainer.items.length > 0
        if trainer.real_lose_text && !trainer.real_lose_text.empty?
          f.write(format("LoseText = %s\r\n", trainer.real_lose_text))
        end
        trainer.pokemon.each do |pkmn|
          f.write(format("Pokemon = %s,%d\r\n", pkmn[:species], pkmn[:level]))
          f.write(format("    Name = %s\r\n", pkmn[:name])) if pkmn[:name] && !pkmn[:name].empty?
          f.write(format("    Form = %d\r\n", pkmn[:form])) if pkmn[:form] && pkmn[:form] > 0
          f.write(format("    Gender = %s\r\n", pkmn[:gender] == 1 ? 'female' : 'male')) if pkmn[:gender]
          f.write("    Shiny = yes\r\n") if pkmn[:shininess] && !pkmn[:super_shininess]
          f.write("    SuperShiny = yes\r\n") if pkmn[:super_shininess]
          f.write("    Shadow = yes\r\n") if pkmn[:shadowness]
          f.write(format("    Moves = %s\r\n", pkmn[:moves].join(','))) if pkmn[:moves] && pkmn[:moves].length > 0
          f.write(format("    Ability = %s\r\n", pkmn[:ability])) if pkmn[:ability]
          f.write(format("    AbilityIndex = %d\r\n", pkmn[:ability_index])) if pkmn[:ability_index]
          f.write(format("    Item = %s\r\n", pkmn[:item])) if pkmn[:item]
          f.write(format("    Nature = %s\r\n", pkmn[:nature])) if pkmn[:nature]
          f.write(format("    Roles = %s\r\n", pkmn[:roles].join(','))) if pkmn[:roles] && pkmn[:roles].length > 0
          ivs_array = []
          evs_array = []
          GameData::Stat.each_main do |s|
            next if s.pbs_order < 0

            ivs_array[s.pbs_order] = pkmn[:iv][s.id] if pkmn[:iv]
            evs_array[s.pbs_order] = pkmn[:ev][s.id] if pkmn[:ev]
          end
          f.write(format("    IV = %s\r\n", ivs_array.join(','))) if pkmn[:iv]
          f.write(format("    EV = %s\r\n", evs_array.join(','))) if pkmn[:ev]
          f.write(format("    Happiness = %d\r\n", pkmn[:happiness])) if pkmn[:happiness]
          f.write(format("    Ball = %s\r\n", pkmn[:poke_ball])) if pkmn[:poke_ball]
        end
      end
    end
    process_pbs_file_message_end
  end

  def compile_trainers(path = 'PBS/trainers.txt')
    compile_pbs_file_message_start(path)
    GameData::Trainer::DATA.clear
    schema = GameData::Trainer::SCHEMA
    max_level = GameData::GrowthRate.max_level
    trainer_names      = []
    trainer_lose_texts = []
    trainer_hash       = nil
    current_pkmn       = nil
    # Read each line of trainers.txt at a time and compile it as a trainer property
    idx = 0
    pbCompilerEachPreppedLine(path) do |line, line_no|
      echo '.' if idx % 50 == 0
      idx += 1
      Graphics.update if idx % 250 == 0
      if line[/^\s*\[\s*(.+)\s*\]\s*$/]
        # New section [trainer_type, name] or [trainer_type, name, version]
        if trainer_hash
          unless current_pkmn
            raise _INTL("Started new trainer while previous trainer has no Pokémon.\r\n{1}", FileLineData.linereport)
          end

          # Add trainer's data to records
          trainer_hash[:id] = [trainer_hash[:trainer_type], trainer_hash[:name], trainer_hash[:version]]
          GameData::Trainer.register(trainer_hash)
        end
        line_data = pbGetCsvRecord($~[1], line_no, [0, 'esU', :TrainerType])
        # Construct trainer hash
        trainer_hash = {
          trainer_type: line_data[0],
          name: line_data[1],
          version: line_data[2] || 0,
          pokemon: []
        }
        current_pkmn = nil
        trainer_names.push(trainer_hash[:name])
      elsif line[/^\s*(\w+)\s*=\s*(.*)$/]
        # XXX=YYY lines
        unless trainer_hash
          raise _INTL("Expected a section at the beginning of the file.\r\n{1}", FileLineData.linereport)
        end

        property_name = $~[1]
        line_schema = schema[property_name]
        next unless line_schema

        property_value = pbGetCsvRecord($~[2], line_no, line_schema)
        # Error checking in XXX=YYY lines
        case property_name
        when 'Pokemon'
          if property_value[1] > max_level
            raise _INTL("Bad level: {1} (must be 1-{2}).\r\n{3}", property_value[1], max_level, FileLineData.linereport)
          end
        when 'Name'
          if property_value.length > Pokemon::MAX_NAME_SIZE
            raise _INTL("Bad nickname: {1} (must be 1-{2} characters).\r\n{3}", property_value, Pokemon::MAX_NAME_SIZE,
                        FileLineData.linereport)
          end
        when 'Moves'
          property_value.uniq!
        when 'Roles'
          property_value.uniq!
        when 'IV'
          property_value.each do |iv|
            next if iv <= Pokemon::IV_STAT_LIMIT

            raise _INTL("Bad IV: {1} (must be 0-{2}).\r\n{3}", iv, Pokemon::IV_STAT_LIMIT, FileLineData.linereport)
          end
        when 'EV'
          property_value.each do |ev|
            next if ev <= Pokemon::EV_STAT_LIMIT

            raise _INTL("Bad EV: {1} (must be 0-{2}).\r\n{3}", ev, Pokemon::EV_STAT_LIMIT, FileLineData.linereport)
          end
          ev_total = 0
          GameData::Stat.each_main do |s|
            next if s.pbs_order < 0

            ev_total += property_value[s.pbs_order] || property_value[0]
          end
          if ev_total > Pokemon::EV_LIMIT
            raise _INTL("Total EVs are greater than allowed ({1}).\r\n{2}", Pokemon::EV_LIMIT, FileLineData.linereport)
          end
        when 'Happiness'
          if property_value > 255
            raise _INTL("Bad happiness: {1} (must be 0-255).\r\n{2}", property_value, FileLineData.linereport)
          end
        when 'Ball'
          unless GameData::Item.get(property_value).is_poke_ball?
            raise _INTL("Value {1} isn't a defined Poké Ball.\r\n{2}", property_value, FileLineData.linereport)
          end
        end
        # Record XXX=YYY setting
        case property_name
        when 'Items', 'LoseText'
          trainer_hash[line_schema[0]] = property_value
          trainer_lose_texts.push(property_value) if property_name == 'LoseText'
        when 'Pokemon'
          current_pkmn = {
            species: property_value[0],
            level: property_value[1]
          }
          trainer_hash[line_schema[0]].push(current_pkmn)
        else
          raise _INTL("Pokémon hasn't been defined yet!\r\n{1}", FileLineData.linereport) unless current_pkmn

          case property_name
          when 'IV', 'EV'
            value_hash = {}
            GameData::Stat.each_main do |s|
              next if s.pbs_order < 0

              value_hash[s.id] = property_value[s.pbs_order] || property_value[0]
            end
            current_pkmn[line_schema[0]] = value_hash
          else
            current_pkmn[line_schema[0]] = property_value
          end
        end
      end
    end
    # Add last trainer's data to records
    if trainer_hash
      unless current_pkmn
        raise _INTL("End of file reached while last trainer has no Pokémon.\r\n{1}", FileLineData.linereport)
      end

      trainer_hash[:id] = [trainer_hash[:trainer_type], trainer_hash[:name], trainer_hash[:version]]
      GameData::Trainer.register(trainer_hash)
    end
    # Save all data
    GameData::Trainer.save
    MessageTypes.setMessagesAsHash(MessageTypes::TrainerNames, trainer_names)
    MessageTypes.setMessagesAsHash(MessageTypes::TrainerLoseText, trainer_lose_texts)
    process_pbs_file_message_end
  end
end

class Pokemon
  attr_accessor :roles

  alias role_init initialize
  def initialize(*args)
    role_init(*args)
    @roles = []
  end

  def roles
    @roles = [] if @roles.nil?
    @roles.push(:NONE) if @roles == [] || @roles.nil?
    @roles
  end

  def add_role(value)
    return if value && !GameData::Role.exists?(value)

    @roles.push(:NONE) unless value
    @roles.push(GameData::Role.get(value).id)
  end

  def has_role?(role)
    x = []
    for i in @roles
      x.push(i)
      next unless role.is_a?(Array)
      return true if role.include?(i)
    end
    x.include?(role) && !role.is_a?(Array)
  end

  # TODO: Not used?
  def assign_roles
    roles = []
    physical_moves = 0
    special_moves = 0
    status_moves = 0
    @moves.each do |move|
      physical_moves += 1 if move.category == 0
      special_moves += 1 if move.category == 1
      status_moves += 1 if move.category == 2
    end
    roles.push(:PHYSICALBREAKER) if physical_moves > 2
    roles.push(:SPECIALBREAKER) if special_moves > 2
    roles.push(:REVENGEKILLER) if item_id == :CHOICESCARF
    for move in @moves
      m = GameData::Move.get(move.id).id
      roles.push(:SETUPSWEEPER) if PBAI::AI_Move.setup_move?(m)
      roles.push(:WEATHERTERRAIN) if PBAI::AI_Move.weather_terrain_move?(m)
      roles.push(:CLERIC) if %i[WISH HEALBELL AROMATHERAPY].include?(m)
      roles.push(:OFFENSIVEPIVOT) if %i[UTURN VOLTSWITCH FLIPTURN].include?(m)
      roles.push(:DEFENSIVEPIVOT) if %i[PARTINGSHOT CHILLYRECEPTION TELEPORT SHEDTAIL].include?(m)
      roles.push(:SPEEDCONTROL) if %i[ICYWIND THUNDERWAVE GLARE BULLDOZE DOLDRUMS ROCKTOMB POUNCE NUZZLE
                                      ELECTROWEB LOWSWEEP TAILWIND].include?(m)
      roles.push(:STALLBREAKER) if m == :TAUNT
      roles.push(:REDIRECTION) if %i[FOLLOWME ALLYSWITCH RAGEPOWDER].include?(m)
      roles.push(:SUPPORT) if %i[HELPINGHAND WIDEGUARD MATBLOCK POLLENPUFF AFTERYOU INSTRUCT].include?(m)
      roles.push(:HAZARDREMOVAL) if %i[RAPIDSPIN MORTALSPIN TIDYUP DEFOG].include?(m)
      roles.push(:SCREENS) if %i[LIGHTSCREEN REFLECT AURORAVEIL].include?(m)
      roles.push(:TOXICSTALLER) if m == :TOXIC
      roles.push(:LEAD) if %i[STEALTHROCK SPIKES TOXICSPIKES STICKYWEB STONEAXE CEASELESSEDGE].include?(m)
      roles.push(:TRICKROOMSETTER) if m == :TRICKROOM
      roles.push(:TANK) if %i[RECOVER ROOST MOONLIGHT MORNINGSUN SHOREUP PACKIN SOFTBOILED SYNTHESIS
                              HEALORDER].include?(m) && !roles.include?(:SETUPSWEEPER)
      roles.push(:PHAZER) if %i[ROAR DRAGONTAIL WHIRLWIND HAZE FREEZYFROST].include?(m)
      roles.push(:STATUSABSORBER) if m == :FACADE
      roles.push(:CRIT) if m == :FOCUSENERGY
    end
    case @ability
    when :DRIZZLE, :DROUGHT, :SNOWWARNING, :SANDSTREAM, :SANDSPIT, :ELECTRICSURGE, :PSYCHICSURGE, :GRASSYSURGE, :MISTYSURGE, :SEEDSOWER, :HADRONENGINE, :ORICHALCUMPULSE
      roles.push(:WEATHERTERRAIN)
    when :SWIFTSWIM, :DRYSKIN, :HYDRATION, :RAINDISH, :SOLARPOWER, :CHLOROPHYLL, :PROTOSYNTHESIS, :SLUSHRUSH, :ICEBODY, :ICEFACE, :SANDRUSH, :SANDVEIL,
      :SANDFORCE, :SNOWCLOAK, :FLOWERGIFT, :FORECAST, :SURGESURFER, :MEADOWRUSH, :BRAINBLAST, :HARVEST, :STEAMPOWERED
      roles.push(:WEATHERTERRAINABUSER)
    when :DEFIANT, :COMPETITIVE, :SOULHEART, :MOXIE, :ASONEICE, :ASONEGHOST, :GRIMNEIGH, :CHILLINGNEIGH, :LIONSPRIDE, :BEASTBOOST, :DOWNLOAD, :CONTRARY
      roles.push(:SETUPSWEEPER)
      roles.push(:SPECIALBREAKER) if %i[COMPETITIVE SOULHEART ASONEGHOST GRIMNEIGH LIONSPRIDE].include?(@ability)
      roles.push(:PHYSICALBREAKER) if %i[DEFIANT MOXIE ASONEICE CHILLINGNEIGH].include?(@ability)
    when :GUTS, :SHEDSKIN, :HOPEFULTOLL, :FAIRYBUBBLE, :PURIFYINGSALT
      roles.push(:STATUSABSORBER)
    end
    if ((species == :SWAMPERT && item == :SWAMPERTITE) || (species == :TOXTRICITY && item == :TOXTRICITITE) ||
       (species == :ABOMASNOW && item == :ABOMASITE)) && !roles.include?(:WEATHERTERRAINABUSER)
      roles.push(:WEATHERTERRAINABUSER)
    end
    if ((species == :CHARIZARD && item == :CHARIZARDITEY) || (species == :RILLABOOM && item == :RILLABOOMITE)) && !roles.include?(:WEATHERTERRAIN)
      roles.push(:WEATHERTERRAIN)
    end
    roles.push(:NONE) if roles == []
    roles.uniq
  end
end

module GameData
  class Trainer
    SCHEMA = {
      'Items' => [:items, '*e', :Item],
      'LoseText' => [:lose_text, 'q'],
      'Pokemon' => [:pokemon, 'ev', :Species], # Species, level
      'Form' => [:form,            'u'],
      'Name' => [:name,            's'],
      'Moves' => [:moves, '*e', :Move],
      'Ability' => [:ability, 'e', :Ability],
      'AbilityIndex' => [:ability_index, 'u'],
      'Item' => [:item, 'e', :Item],
      'Gender' => [:gender,          'e', { 'M' => 0, 'm' => 0, 'Male' => 0, 'male' => 0, '0' => 0,
                                            'F' => 1, 'f' => 1, 'Female' => 1, 'female' => 1, '1' => 1 }],
      'Nature' => [:nature,          'e', :Nature],
      'Roles' => [:roles, '*e', :Role],
      'IV' => [:iv,              'uUUUUU'],
      'EV' => [:ev,              'uUUUUU'],
      'Happiness' => [:happiness, 'u'],
      'Shiny' => [:shininess, 'b'],
      'SuperShiny' => [:super_shininess, 'b'],
      'Shadow' => [:shadowness, 'b'],
      'Ball' => [:poke_ball, 'e', :Item]
    }
    alias other_to_trainers to_trainer
    def to_trainer
      trainer = other_to_trainers
      trainer.party.each_with_index do |pkmn, i|
        pkmn.roles = pkmn.assign_roles
        PBAI.log("Roles for #{pkmn.species.name}: #{pkmn.roles}")
      end
      trainer
    end
    # def to_trainer
    #   # Determine trainer's name
    #   tr_name = self.name
    #   Settings::RIVAL_NAMES.each do |rival|
    #     next if rival[0] != @trainer_type || !$game_variables[rival[1]].is_a?(String)
    #     tr_name = $game_variables[rival[1]]
    #     break
    #   end
    #   # Create trainer object
    #   trainer = NPCTrainer.new(tr_name, @trainer_type)
    #   trainer.id        = $player.make_foreign_ID
    #   trainer.items     = @items.clone
    #   trainer.items     = [:MEGARING]
    #   trainer.lose_text = self.lose_text
    #   # Create each Pokémon owned by the trainer
    #   randPkmn = Randomizer.trainers
    #   trainer_exclusions = $game_switches[906] ? nil : [:RIVAL1,:RIVAL2,:RIVAL3,:LEADER_Falkner,:LEADER_Bugsy,:LEADER_Whitney,:LEADER_Morty,:LEADER_Chuck,:LEADER_Jasmine,:LEADER_Pryce,:LEADER_Clair,:ROCKETGRUNT_M,:ROCKETGRUNT_F,:ROCKETADMIN_Archer,:ROCKETBOSS,:ROCKETADMIN_Petrel,:ROCKETADMIN_Proton,:ROCKETADMIN_Ariana,:ELITEFOUR_Koga,:ELITEFOUR_Bruno,:ELITEFOUR_Karen,:ELITEFOUR_Will,:CHAMPION]
    #   if randPkmn.nil? || randPkmn == 0 || @version > 99 || Level_Scaling.no_change
    #     @pokemon.each do |pkmn_data|
    #       species = GameData::Species.get(pkmn_data[:species]).species
    #       pkmn = Pokemon.new(species, pkmn_data[:level], trainer, false)
    #       trainer.party.push(pkmn)
    #       # Set Pokémon's properties if defined
    #       if pkmn_data[:form]
    #         pkmn.forced_form = pkmn_data[:form] if MultipleForms.hasFunction?(species, "getForm")
    #         pkmn.form_simple = pkmn_data[:form]
    #       end
    #       pkmn.item = pkmn_data[:item]
    #       if pkmn_data[:moves] && pkmn_data[:moves].length > 0
    #         pkmn.moves = []
    #         pkmn_data[:moves].each { |move| pkmn.learn_move(move) }
    #       else
    #         pkmn.reset_moves
    #       end
    #       if $game_switches[LvlCap::Expert]
    #         pkmn.moves.each do |mov|
    #           mov.ppup = 3
    #         end
    #       else
    #         pkmn.moves[0].ppup = 3
    #       end
    #       if pkmn_data[:ability]
    #         pkmn.ability = pkmn_data[:ability]
    #         pkmn.set_ability = pkmn_data[:ability]
    #       else
    #         idx = pkmn_data[:ability_index] || rand(3)
    #         pkmn.set_ability_index = idx
    #         pkmn.set_ability = idx == 2 ? pkmn.species_data.hidden_abilities[0] : pkmn.species_data.abilities[idx]
    #       end
    #       pkmn.gender = pkmn_data[:gender] || ((trainer.male?) ? 0 : 1)
    #       pkmn.shiny = (pkmn_data[:shininess]) ? true : false
    #       pkmn.super_shiny = (pkmn_data[:super_shininess]) ? true : false
    #       if !pkmn_data[:roles]
    #           pkmn.roles = pkmn.assign_roles
    #           PBAI.log("Roles for #{pkmn.species.name}: #{pkmn.roles}")
    #       else
    #         for i in pkmn_data[:roles]
    #           pkmn.add_role(i)
    #         end
    #       end
    #       if pkmn_data[:nature]
    #         pkmn.nature = pkmn_data[:nature]
    #       else   # Make the nature random but consistent for the same species used by the same trainer type
    #         pkmn.nature = :BASHFUL
    #       end
    #       GameData::Stat.each_main do |s|
    #         if pkmn_data[:iv]
    #           pkmn.iv[s.id] = pkmn_data[:iv][s.id]
    #         else
    #           pkmn.iv[s.id] = $game_switches[Settings::DISABLE_EVS] ? 31 : [pkmn_data[:level] / 2, Pokemon::IV_STAT_LIMIT].min
    #         end
    #         if pkmn_data[:ev]
    #           pkmn.ev[s.id] = $game_switches[Settings::DISABLE_EVS] ? 0 : pkmn_data[:ev][s.id]
    #         else
    #           pkmn.ev[s.id] = $game_switches[Settings::DISABLE_EVS] ? 0 : ([pkmn_data[:level] * 3 / 2, Pokemon::EV_LIMIT / 6].min)
    #         end
    #       end
    #       pkmn.happiness = pkmn_data[:happiness] if pkmn_data[:happiness]
    #       pkmn.name = pkmn_data[:name] if pkmn_data[:name] && !pkmn_data[:name].empty?
    #       if pkmn_data[:shadowness]
    #         pkmn.makeShadow
    #         pkmn.update_shadow_moves(true)
    #         pkmn.shiny = false
    #       end
    #       pkmn.poke_ball = pkmn_data[:poke_ball] if pkmn_data[:poke_ball]
    #       pkmn.calc_stats
    #     end
    #   else
    #     idx = -1
    #     for i in randPkmn[:trainer]
    #       idx += 1
    #       break if i[0] == @trainer_type && i[1] == tr_name && i[2] == @version
    #     end
    #     randSpec = randPkmn[:pokemon][:species][idx]
    #     randLvl = randPkmn[:pokemon][:level][idx]
    #     lvl = -1
    #     randSpec.each do |pkmn_data|
    #       lvl += 1
    #       species = GameData::Species.get(pkmn_data).species
    #         pkmn = Pokemon.new(species, randLvl[lvl], trainer, false)
    #         pkmn.nature = :BASHFUL
    #         pkmn.reset_moves
    #         pkmn.calc_stats
    #         pkmn.assign_roles
    #         trainer.party.push(pkmn)
    #     end
    #   end
    #   return trainer
    # end
  end
end

class Battle::Battler
  attr_accessor :roles

  alias init_role pbInitBlank
  def pbInitBlank
    init_role
    @roles = []
  end

  alias pbInitRole pbInitPokemon
  def pbInitPokemon(pkmn, idxParty)
    pbInitRole(pkmn, idxParty)
    @roles = pkmn.roles
  end

  def roles
    @roles.push(:NONE) if @roles == [] || @roles.nil?
    @roles
  end

  def has_role?(role)
    x = []
    for i in @roles
      x.push(i)
      next unless role.is_a?(Array)
      return true if role.include?(i)
    end
    x.include?(role) && !role.is_a?(Array)
  end

  def role=(value)
    new_role = GameData::Role.try_get(value)
    @roles.push(new_role) ? new_role.id : nil
  end
end

GameData::Role.register({
                          id: :PHYSICALWALL,
                          id_number: 0,
                          name: _INTL('Physical Wall')
                        })

GameData::Role.register({
                          id: :SPECIALWALL,
                          id_number: 1,
                          name: _INTL('Special Wall')
                        })

GameData::Role.register({
                          id: :STALLBREAKER,
                          id_number: 2,
                          name: _INTL('Stallbreaker')
                        })

GameData::Role.register({
                          id: :PHYSICALBREAKER,
                          id_number: 3,
                          name: _INTL('Physical Breaker')
                        })

GameData::Role.register({
                          id: :SPECIALBREAKER,
                          id_number: 4,
                          name: _INTL('Special Breaker')
                        })

GameData::Role.register({
                          id: :TANK,
                          id_number: 5,
                          name: _INTL('Tank')
                        })

GameData::Role.register({
                          id: :LEAD,
                          id_number: 5,
                          name: _INTL('Lead')
                        })

GameData::Role.register({
                          id: :CLERIC,
                          id_number: 7,
                          name: _INTL('Cleric')
                        })

GameData::Role.register({
                          id: :REVENGEKILLER,
                          id_number: 8,
                          name: _INTL('Revenge Killer')
                        })

GameData::Role.register({
                          id: :WINCON,
                          id_number: 9,
                          name: _INTL('Win Condition')
                        })

GameData::Role.register({
                          id: :TOXICSTALLER,
                          id_number: 10,
                          name: _INTL('Toxic Staller')
                        })

GameData::Role.register({
                          id: :SETUPSWEEPER,
                          id_number: 11,
                          name: _INTL('Setup Sweeper')
                        })

GameData::Role.register({
                          id: :HAZARDREMOVAL,
                          id_number: 12,
                          name: _INTL('Hazard Removal')
                        })

GameData::Role.register({
                          id: :DEFENSIVEPIVOT,
                          id_number: 13,
                          name: _INTL('Defensive Pivot')
                        })

GameData::Role.register({
                          id: :SPEEDCONTROL,
                          id_number: 14,
                          name: _INTL('Speed Control')
                        })

GameData::Role.register({
                          id: :SCREENS,
                          id_number: 15,
                          name: _INTL('Screens')
                        })

GameData::Role.register({
                          id: :NONE,
                          id_number: 16,
                          name: _INTL('None')
                        })

GameData::Role.register({
                          id: :TARGETALLY,
                          id_number: 17,
                          name: _INTL('Target Ally')
                        })

GameData::Role.register({
                          id: :REDIRECTION,
                          id_number: 18,
                          name: _INTL('Redirection')
                        })

GameData::Role.register({
                          id: :TRICKROOMSETTER,
                          id_number: 19,
                          name: _INTL('Trick Room Setter')
                        })

GameData::Role.register({
                          id: :OFFENSIVEPIVOT,
                          id_number: 20,
                          name: _INTL('Offensive Pivot')
                        })

GameData::Role.register({
                          id: :STATUSABSORBER,
                          id_number: 21,
                          name: _INTL('Status Absorber')
                        })

GameData::Role.register({
                          id: :WEATHERTERRAIN,
                          id_number: 22,
                          name: _INTL('Weather/Terrain Setter')
                        })

GameData::Role.register({
                          id: :TRAPPER,
                          id_number: 23,
                          name: _INTL('Trapper')
                        })

GameData::Role.register({
                          id: :PHAZER,
                          id_number: 24,
                          name: _INTL('Phazer')
                        })

GameData::Role.register({
                          id: :SUPPORT,
                          id_number: 25,
                          name: _INTL('Support')
                        })

GameData::Role.register({
                          id: :WEATHERTERRAINABUSER,
                          id_number: 26,
                          name: _INTL('Weather/Terrain Abuser')
                        })

GameData::Role.register({
                          id: :FEAR,
                          id_number: 27,
                          name: _INTL('FEAR')
                        })

GameData::Role.register({
                          id: :CRIT,
                          id_number: 28,
                          name: _INTL('Crit')
                        })
