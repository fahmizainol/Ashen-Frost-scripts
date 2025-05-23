#===============================================================================
# * Set the Controls Screen - by FL (Credits will be apreciated)
#===============================================================================
#
# This script is for Pokémon Essentials. It creates a "Set the controls" screen
# on pause menu, allowing the player to map the actions to the keys in keyboard, 
# ignoring the values defined on F1. You can also define the default controls.
#
#== INSTALLATION ===============================================================
#
# To this script works, put it above main OR convert into a plugin.
#
#== NOTES ======================================================================
#
# '$PokemonSystem.game_controls = nil' resets the controls.
#
# This script, by default, doesn't allows the player to redefine some commands
# like F8 (screenshot key), but if the player assign an action to this key,
# like the "Cancel" action, this key will do this action AND take screenshots
# when pressed. Remember that F12 will reset the game.
#
#===============================================================================

if !PluginManager.installed?("Set the Controls Screen")
  PluginManager.register({                                                 
    :name    => "Set the Controls Screen",                                        
    :version => "1.1.2",                                                     
    :link    => "https://www.pokecommunity.com/showthread.php?t=309391",             
    :credits => "FL"
  })
end

# Open the controls UI.
# You can call this method directly from other places like an event.
def open_set_controls_ui(menu_to_refresh=nil, gamepad = false)
  scene = PokemonControls_Scene.new(gamepad)
  screen = PokemonControlsScreen.new(scene)
  pbFadeOutIn {
    screen.start_screen
    menu_to_refresh.pbRefresh if menu_to_refresh
  }
end

module Keys
  # Here you can change the number of keys for each action and the
  # default values
  def self.default_controls
    controls = [
      ControlConfig.new("Down", "Down"),
      ControlConfig.new("Left", "Left"),
      ControlConfig.new("Right", "Right"),
      ControlConfig.new("Up", "Up"),
      ControlConfig.new("Action", "C"),
      ControlConfig.new("Action", "Enter"),
      ControlConfig.new("Action", "Space"),
      ControlConfig.new("Cancel",  "X"),
      ControlConfig.new("Cancel", "Esc"),
      ControlConfig.new("Menu", "Z"),
      ControlConfig.new("Scroll Up, etc.", "A"),
      ControlConfig.new("Scroll Up, etc.", "Page Up"),
      ControlConfig.new("Scroll Down", "S"),
      ControlConfig.new("Scroll Down", "Page Down"),
      ControlConfig.new("Ready Menu, etc.", "D"),
      ControlConfig.new("Speed Up", "Q"),
      ControlConfig.new("Speed Up", "Alt"),
      ControlConfig.new("Quick Save, etc.", "F"),
      ControlConfig.new("Move Info", "M"),
      ControlConfig.new("Battle Info", "N"),
      ControlConfig.new("Skip Text", "W"),
      ControlConfig.new("Skip Text", "Shift")
    ]
    return controls
  end

  # Available keys
  CONTROLS_LIST = {
    # Mouse buttons
    "Backspace"    => 0x08,
    "Tab"          => 0x09,
    "Clear"        => 0x0C,
    "Enter"        => 0x0D,
    "Shift"        => 0x10,
    "Ctrl"         => 0x11,
    "Alt"          => 0x12,
    "Pause"        => 0x13,
    # IME keys
    "Caps Lock"    => 0x14,
    "Esc"          => 0x1B,
    "Space"        => 0x20,
    "Page Up"      => 0x21,
    "Page Down"    => 0x22,
    "End"          => 0x23,
    "Home"         => 0x24,
    "Left"         => 0x25,
    "Up"           => 0x26,
    "Right"        => 0x27,
    "Down"         => 0x28,
    "Select"       => 0x29,
    "Print"        => 0x2A,
    "Execute"      => 0x2B,
    "Print Screen" => 0x2C,
    "Insert"       => 0x2D,
    "Delete"       => 0x2E,
    "Help"         => 0x2F,
    "0"            => 0x30,
    "1"            => 0x31,
    "2"            => 0x32,
    "3"            => 0x33,
    "4"            => 0x34,
    "5"            => 0x35,
    "6"            => 0x36,
    "7"            => 0x37,
    "8"            => 0x38,
    "9"            => 0x39,
    "A"            => 0x41,
    "B"            => 0x42,
    "C"            => 0x43,
    "D"            => 0x44,
    "E"            => 0x45,
    "F"            => 0x46,
    "G"            => 0x47,
    "H"            => 0x48,
    "I"            => 0x49,
    "J"            => 0x4A,
    "K"            => 0x4B,
    "L"            => 0x4C,
    "M"            => 0x4D,
    "N"            => 0x4E,
    "O"            => 0x4F,
    "P"            => 0x50,
    "Q"            => 0x51,
    "R"            => 0x52,
    "S"            => 0x53,
    "T"            => 0x54,
    "U"            => 0x55,
    "V"            => 0x56,
    "W"            => 0x57,
    "X"            => 0x58,
    "Y"            => 0x59,
    "Z"            => 0x5A,
    # Windows keys
    "Numpad 0"     => 0x60,
    "Numpad 1"     => 0x61,
    "Numpad 2"     => 0x62,
    "Numpad 3"     => 0x63,
    "Numpad 4"     => 0x64,
    "Numpad 5"     => 0x65,
    "Numpad 6"     => 0x66,
    "Numpad 7"     => 0x67,
    "Numpad 8"     => 0x68,
    "Numpad 9"     => 0x69,
    "Multiply"     => 0x6A,
    "Add"          => 0x6B,
    "Separator"    => 0x6C,
    "Subtract"     => 0x6D,
    "Decimal"      => 0x6E,
    "Divide"       => 0x6F,
    "F1"           => 0x70,
    "F2"           => 0x71,
    "F3"           => 0x72,
    "F4"           => 0x73,
    "F5"           => 0x74,
    "F6"           => 0x75,
    "F7"           => 0x76,
    "F8"           => 0x77,
    "F9"           => 0x78,
    "F10"          => 0x79,
    "F11"          => 0x7A,
    "F12"          => 0x7B,
    "F13"          => 0x7C,
    "F14"          => 0x7D,
    "F15"          => 0x7E,
    "F16"          => 0x7F,
    "F17"          => 0x80,
    "F18"          => 0x81,
    "F19"          => 0x82,
    "F20"          => 0x83,
    "F21"          => 0x84,
    "F22"          => 0x85,
    "F23"          => 0x86,
    "F24"          => 0x87,
    "Num Lock"     => 0x90,
    "Scroll Lock"  => 0x91,
    # Multiple position Shift, Ctrl and Menu keys
    ";:"           => 0xBA,
    "+"            => 0xBB,
    ","            => 0xBC,
    "-"            => 0xBD,
    "."            => 0xBE,
    "/?"           => 0xBF,
    "`~"           => 0xC0,
    "{"            => 0xDB,
    "\|"           => 0xDC,
    "}"            => 0xDD,
    "'\""          => 0xDE,
    "AX"           => 0xE1, # Japan only
  }

  def self.key_name(key_code)
    return CONTROLS_LIST.key(key_code) if CONTROLS_LIST.key(key_code)
    return key_code==0 ? "None" : "?"
  end 

  def self.key_code(key_name)
    ret  = CONTROLS_LIST[key_name]
    raise "The button #{key_name} no longer exists! " if !ret
    return ret
  end 

  def self.detect_key
    loop do
      Graphics.update
      Input.update
      for key_code in CONTROLS_LIST.values
        return key_code if Input.triggerex?(key_code)
      end
    end
  end
end 

class ControlConfig
  attr_reader :control_action
  attr_accessor :key_code

  def initialize(control_action, default_key)
    @control_action = control_action
    @key_code = Keys.key_code(default_key)
  end

  def key_name
    return Keys.key_name(@key_code)
  end
end

# Added classes for controller rebind support
module Gamepad
  # Here you can change the number of keys for each action and the
  # default values
  # Default values for controller buttons
  def self.default_controls
    controls = [
      ControllerConfig.new("Down", "D-pad Down"),
      ControllerConfig.new("Down", "LS Down"),
      ControllerConfig.new("Left", "D-pad Left"),
      ControllerConfig.new("Left", "LS Left"),
      ControllerConfig.new("Right", "D-pad Right"),
      ControllerConfig.new("Right", "LS Right"),
      ControllerConfig.new("Up", "D-pad Up"),
      ControllerConfig.new("Up", "LS Up"),
      ControllerConfig.new("Action", "A / Cross"),
      ControllerConfig.new("Cancel",  "B / Circle"),
      ControllerConfig.new("Menu", "X / Square"),
      ControllerConfig.new("Menu", "Start"),
      ControllerConfig.new("Scroll Up, etc.", "L1 / LB"),
      ControllerConfig.new("Scroll Down", "R1 / RB"),
      ControllerConfig.new("Ready Menu, etc.", "Y / Triangle"),
      ControllerConfig.new("Speed Up", "R2 / ZR"),
      ControllerConfig.new("Quick Save, etc.", "L2 / ZL"),
      ControllerConfig.new("Move Info", "Left Stick / L3"),
      ControllerConfig.new("Battle Info", "Right Stick / R3"),
      ControllerConfig.new("Skip Text", "Back")
    ]
    return controls
  end

  # Available controller buttons
  CONTROLS_LIST = {
    "A / Cross"    => 0,
    "B / Circle"   => 1,
    "X / Square"   => 2,
    "Y / Triangle" => 3,
    "Back"         => 4,
    "Start"        => 6,
    "Left Stick / L3"  => 7,
    "Right Stick / R3" => 8,
    "L1 / LB"      => 9,
    "R1 / RB"      => 10,
    "D-pad Up"     => 11,
    "D-pad Down"   => 12,
    "D-pad Left"   => 13,
    "D-pad Right"  => 14,
    "Misc"         => 15,
    "Paddle 1"     => 16,
    "Paddle 2"     => 17,
    "Paddle 3"     => 18,
    "Paddle 4"     => 19,
    "Touchpad"     => 20,
    # Axis-controls
    "L2 / ZL"      => :TRIGGERLEFT,
    "R2 / ZR"      => :TRIGGERRIGHT,
    "LS Up"        => :LEFTSTICKUP,
    "LS Down"      => :LEFTSTICKDOWN,
    "LS Left"      => :LEFTSTICKLEFT,
    "LS Right"     => :LEFTSTICKRIGHT,
    "RS Up"        => :RIGHTSTICKUP,
    "RS Down"      => :RIGHTSTICKDOWN,
    "RS Left"      => :RIGHTSTICKLEFT,
    "RS Right"     => :RIGHTSTICKRIGHT
  }

  def self.button_name(button_code)
    return CONTROLS_LIST.key(button_code) if CONTROLS_LIST.key(button_code)
    return button_code == -1 ? "None" : "?"
  end 

  def self.button_code(button_name)
    ret  = CONTROLS_LIST[button_name]
    raise "The button #{button_name} no longer exists! " if !ret
    return ret
  end 

  def self.detect_button
    loop do
      Graphics.update
      Input.update
      # Adding support for axis controls - LS/RS set to 0.5 to prevent automatic trigger
      for button_code in CONTROLS_LIST.values
        case button_code
        when :LEFTSTICKUP
          return button_code if Input::Controller.axes_left[1] < -0.5
        when :LEFTSTICKDOWN
          return button_code if Input::Controller.axes_left[1] > 0.5
        when :LEFTSTICKLEFT
          return button_code if Input::Controller.axes_left[0] < -0.5
        when :LEFTSTICKRIGHT
          return button_code if Input::Controller.axes_left[0] > 0.5
        when :RIGHTSTICKUP
          return button_code if Input::Controller.axes_right[1] < -0.5
        when :RIGHTSTICKDOWN
          return button_code if Input::Controller.axes_right[1] > 0.5
        when :RIGHTSTICKLEFT
          return button_code if Input::Controller.axes_right[0] < -0.5
        when :RIGHTSTICKRIGHT
          return button_code if Input::Controller.axes_right[0] > 0.5
        when :TRIGGERLEFT
          return button_code if Input::Controller.axes_trigger[0] > 0.0
        when :TRIGGERRIGHT
          return button_code if Input::Controller.axes_trigger[1] > 0.0
        else
          return button_code if Input::Controller.triggerex?(button_code)
        end
      end
    end
  end
end 

class ControllerConfig
  attr_reader :control_action
  attr_accessor :button_code

  def initialize(control_action, default_button)
    @control_action = control_action
    @button_code = Gamepad.button_code(default_button)
  end

  def button_name
    return Gamepad.button_name(@button_code)
  end
end

if !$joiplay && !Input::Controller.connected?
  
  module Input
    class << self
      if !method_defined?(:_old_fl_press?)
        alias :_old_fl_press? :press?
        def press?(button)
          key = buttonToKey(button)
          return key ? pressex_array?(key) : _old_fl_press?(button)
        end

        alias :_old_fl_trigger? :trigger?
        def trigger?(button)
          key = buttonToKey(button)
          return key ? triggerex_array?(key) : _old_fl_trigger?(button)
        end

        alias :_old_fl_repeat? :repeat?
        def repeat?(button)
          key = buttonToKey(button)
          return key ? repeatex_array?(key) : _old_fl_repeat?(button)
        end

        alias :_old_fl_release? :release?
        def release?(button)
          key = buttonToKey(button)
          return key ? releaseex_array?(key) : _old_fl_releaseex?(button)
        end
      end

      def pressex_array?(array)
        for item in array
          return true if pressex?(item)
        end
        return false
      end

      def triggerex_array?(array)
        for item in array
          return true if triggerex?(item)
        end
        return false
      end

      def repeatex_array?(array)
        for item in array
          return true if repeatex?(item)
          return true if triggerex?(item) # Fix for MKXP-Z issue
        end
        return false
      end

      def releaseex_array?(array)
        for item in array
          return true if releaseex?(item)
        end
        return false
      end

      def dir4
        return 0 if press?(DOWN) && press?(UP)
        return 0 if press?(LEFT) && press?(RIGHT)
        for button in [DOWN,LEFT,RIGHT,UP]
          return button if press?(button)
        end
        return 0
      end

      def dir8
        buttons = []
        for b in [DOWN,LEFT,RIGHT,UP]
          buttons.push(b) if press?(b)
        end
        if buttons.length==0
          return 0
        elsif buttons.length==1
          return buttons[0]
        elsif buttons.length==2
          return 0 if (buttons[0]==DOWN && buttons[1]==UP)
          return 0 if (buttons[0]==LEFT && buttons[1]==RIGHT)
        end
        up_down    = 0
        left_right = 0
        for b in buttons
          up_down    = b if up_down==0 && (b==UP || b==DOWN)
          left_right = b if left_right==0 && (b==LEFT || b==RIGHT)
        end
        if up_down==DOWN
          return 1 if left_right==LEFT
          return 3 if left_right==RIGHT
          return 2
        elsif up_down==UP
          return 7 if left_right==LEFT
          return 9 if left_right==RIGHT
          return 8
        else
          return 4 if left_right==LEFT
          return 6 if left_right==RIGHT
          return 0
        end
      end

      def buttonToKey(button)
        $PokemonSystem = PokemonSystem.new if !$PokemonSystem
        case button
          when Input::DOWN
            return $PokemonSystem.game_control_code("Down")
          when Input::LEFT
            return $PokemonSystem.game_control_code("Left")
          when Input::RIGHT
            return $PokemonSystem.game_control_code("Right")
          when Input::UP
            return $PokemonSystem.game_control_code("Up")
          when Input::ACTION # Z, W, Y, Shift
            return $PokemonSystem.game_control_code("Menu")
          when Input::BACK # X, ESC
            return $PokemonSystem.game_control_code("Cancel")
          when Input::USE # C, ENTER, Space
            return $PokemonSystem.game_control_code("Action")
          when Input::JUMPUP # A, Q, Page Up
            return $PokemonSystem.game_control_code("Scroll Up, etc.")
          when Input::JUMPDOWN # S, Page Down
            return $PokemonSystem.game_control_code("Scroll Down")
          when Input::SPECIAL # F, F5, Tab
            return $PokemonSystem.game_control_code("Ready Menu, etc.")
          when Input::AUX1 # Q, Alt
            return $PokemonSystem.game_control_code("Speed Up")
          when Input::AUX2 # D
            return $PokemonSystem.game_control_code("Quick Save, etc.")
          when Input::D
            return $PokemonSystem.game_control_code("Move Info")
          when Input::E
            return $PokemonSystem.game_control_code("Battle Info")
          when Input::F
            return $PokemonSystem.game_control_code("Skip Text")
          else
            return nil
        end
      end
    end
  end
end

class Window_PokemonControls < Window_DrawableCommand
  attr_reader :reading_input
  attr_reader :controls
  attr_reader :changed
  attr_reader :gamepad

  DEFAULT_EXTRA_INDEX = 0
  EXIT_EXTRA_INDEX = 1

  def initialize(controls,x,y,width,height,gamepad)
    @controls = controls
    @name_base_color   = Color.new(88,88,80)
    @name_shadow_color = Color.new(168,184,184)
    @sel_base_color    = Color.new(24,112,216)
    @sel_shadow_color  = Color.new(136,168,208)
    @reading_input = false
    @changed = false
    @gamepad = gamepad
    super(x,y,width,height)
  end

  def itemCount
    return @controls.length + EXIT_EXTRA_INDEX + 1
  end

  def set_new_input(new_input)
    @reading_input = false
    # Added for gamepad support
    ctrl_index = @gamepad ? @controls[@index].button_code : @controls[@index].key_code
    return if ctrl_index == new_input
    # More gamepad support
    for control in @controls # Remove the same input for the same array
      if @gamepad
        control.button_code = -1 if control.button_code == new_input
      else
        control.key_code = 0 if control.key_code == new_input
      end
    end
    # Added for gamepad support
    if @gamepad
      @controls[@index].button_code = new_input
    else
      @controls[@index].key_code = new_input
    end
    @changed = true
    refresh
  end

  def on_exit_index?
    return @controls.length + EXIT_EXTRA_INDEX == @index
  end

  def on_default_index?
    return @controls.length + DEFAULT_EXTRA_INDEX == @index
  end
  
  def item_description
    ret = nil
    if on_exit_index?
      ret = _INTL("Exit. If you changed anything, asks if you want to keep changes.")
    elsif on_default_index?
      ret = _INTL("Restore the default controls.")
    else
      ret= control_description(@controls[@index].control_action)
    end
    return ret
  end 

  def control_description(control_action)
    hash = {}
    hash["Down"        ] = _INTL("Moves the character. Select entries and navigate menus.")
    hash["Left"        ] = hash["Down"]
    hash["Right"       ] = hash["Down"]
    hash["Up"          ] = hash["Down"]
    hash["Action"      ] = _INTL("Confirm a choice, check things, talk to people, and move through text.")
    hash["Cancel"      ] = _INTL("Exit, cancel a choice or mode, enable running, and skip through text.")
    hash["Menu"        ] = _INTL("Open the menu. Also has various functions depending on context.")
    hash["Scroll Up, etc."   ] = _INTL("Advance quickly in menus, opens text log in overworld.")
    hash["Scroll Down" ] = _INTL("Advance quickly in menus.")
    hash["Ready Menu, etc."  ] = _INTL("Open Ready Menu, with registered items; shift command during triple battles.")
    hash["Speed Up"    ] = _INTL("Increases the game's running speed, with values 1x, 3x, and 5x.")
    hash["Quick Save, etc." ] = _INTL("Quicksaves the game, sorts bag, filters by Pokémon in Tutor.net.")
    hash["Move Info"   ] = _INTL("Opens the move info menu during move selection in battles.")
    hash["Battle Info" ] = _INTL("Opens the battle info menu during move selection in battles.")
    hash["Skip Text" ] = _INTL("Advance quickly through text boxes.")
    return hash.fetch(control_action, _INTL("Set the controls."))
  end

  def drawItem(index,count,rect)
    rect = drawCursor(index,rect)
    name = case index-@controls.length
      when DEFAULT_EXTRA_INDEX   ; _INTL("Default")
      when EXIT_EXTRA_INDEX      ; _INTL("Exit")
      else                       ; @controls[index].control_action
    end
    width = rect.width*9/20
    pbDrawShadowText(
      self.contents,rect.x,rect.y,width,rect.height,
      name,@name_base_color,@name_shadow_color
    )
    self.contents.draw_text(rect.x,rect.y,width,rect.height,name)
    return if index >= @controls.length
    value = @gamepad ? _INTL(@controls[index].button_name) : _INTL(@controls[index].key_name)
    xpos = width + rect.x
    pbDrawShadowText(
      self.contents,xpos,rect.y,width,rect.height,
      value,@sel_base_color,@sel_shadow_color
    )
    self.contents.draw_text(xpos,rect.y,width,rect.height,value)
  end

  def update
    oldindex=self.index
    super
    do_refresh=self.index!=oldindex
    if self.active && self.index<=@controls.length
      if Input.trigger?(Input::USE)
        if on_default_index?
          if pbConfirmMessage(_INTL("Are you sure you would like to restore the default controls?"))
            pbPlayDecisionSE()
            @controls = @gamepad ? Gamepad.default_controls : Keys.default_controls
            @changed = true
            do_refresh = true
          end
        elsif self.index < @controls.length
          @reading_input = true
        end
      end
    end
    refresh if do_refresh
  end
end

class PokemonControls_Scene

  def initialize(gamepad)
    @gamepad = gamepad
  end

  def start_scene
    @sprites = {}
    @viewport = Viewport.new(0,0,Graphics.width,Graphics.height)
    @viewport.z = 99999
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Controls"),0,0,Graphics.width,64,@viewport
    )
    @sprites["textbox"] = pbCreateMessageWindow
    @sprites["textbox"].letterbyletter=false
    game_controls = @gamepad ? $PokemonSystem.game_controller.map{|c| c.clone} : $PokemonSystem.game_controls.map{|c| c.clone}
    @sprites["controlwindow"] = Window_PokemonControls.new(
      game_controls,0,@sprites["title"].height,Graphics.width,
      Graphics.height-@sprites["title"].height-@sprites["textbox"].height,
      @gamepad
    )
    @sprites["controlwindow"].viewport = @viewport
    @sprites["controlwindow"].visible = true
    @changed = false
    pbDeactivateWindows(@sprites)
    pbFadeInAndShow(@sprites) { update }
  end

  def update
    pbUpdateSpriteHash(@sprites)
  end

  def main
    last_index=-1
    should_refresh_text = false
    pbActivateWindow(@sprites,"controlwindow"){
    loop do
      Graphics.update
      Input.update
      update
      should_refresh_text = @sprites["controlwindow"].index!=last_index
      if @sprites["controlwindow"].reading_input
        if @gamepad
          @sprites["textbox"].text = _INTL("Press a new button.")
          @sprites["controlwindow"].set_new_input(Gamepad.detect_button)
        else
          @sprites["textbox"].text = _INTL("Press a new key.")
          @sprites["controlwindow"].set_new_input(Keys.detect_key)
        end
        should_refresh_text = true
        @changed = true
      else
        if Input.trigger?(Input::BACK) || (
          Input.trigger?(Input::USE) && @sprites["controlwindow"].on_exit_index?
        )
          if(
            @sprites["controlwindow"].changed && 
            pbConfirmMessage(_INTL("Keep changes?"))
          )
            should_refresh_text = true # Visual effect
            if (@gamepad ? @sprites["controlwindow"].controls.find{|c| c.button_code == -1} : @sprites["controlwindow"].controls.find{|c| c.key_code == 0})
              @sprites["textbox"].text = _INTL("Fill all fields!")
              should_refresh_text = false
            else
              # Adds controller support
              if @gamepad 
                $PokemonSystem.game_controller = @sprites["controlwindow"].controls
              else
                $PokemonSystem.game_controls = @sprites["controlwindow"].controls
              end
              break
            end
          else
            break
          end
        end
      end
      if should_refresh_text
        if @sprites["textbox"].text!=@sprites["controlwindow"].item_description
          @sprites["textbox"].text = @sprites["controlwindow"].item_description
        end
        last_index = @sprites["controlwindow"].index
      end
    end
    }
  end

  def end_scene
    pbFadeOutAndHide(@sprites) { update }
    pbDisposeMessageWindow(@sprites["textbox"])
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

class PokemonControlsScreen
  def initialize(scene)
    @scene=scene
  end

  def start_screen
    @scene.start_scene
    @scene.main
    @scene.end_scene
  end
end

class PokemonSystem
  attr_writer :game_controls
  attr_writer :game_controller

  def game_controls
    @game_controls = Keys.default_controls if !@game_controls
    return @game_controls
  end

  def game_controller
    @game_controller = Gamepad.default_controls if !@game_controller
    return @game_controller
  end

  def game_control_code(control_action)
    ret = []
    for control in game_controls
      ret.push(control.key_code) if control.control_action == control_action
    end
    # Added controller support
    for gamepad_control in game_controller
      ret.push(gamepad_control.button_code) if gamepad_control.control_action == control_action
    end
    return ret
  end
end