# warning, game jam hacked together code follows
# constants, many with specific bits set, including for demo mode
ADD_FIRST_BABY = 0
ADD_SECOND_BABY = 2 ** 54
ADD_THIRD_BABY = 2 ** 55 + 2 ** 52
MOVE_STRETCHER_LEFT = 2 ** 57 + 2 ** 55 + 2 ** 52
MOVE_STRETCHER_MIDDLE = 2 ** 40 + 2 ** 38 + 2 ** 35
MOVE_STRETCHER_RIGHT = 2 ** 21 + 2 ** 19 + 2 ** 16
STRETCHER_LEFT = 130
STRETCHER_MIDDLE = 515
STRETCHER_RIGHT = 840

class Game
  attr_gtk

  # TODO:
  # add a sound when a baby hits the ground - DONE
  # add a sound when a baby is bounced in the paramedics stretcher - DONE
  # simplify speed and wave progression (also adjust baby jump patterns based on wave)
  # simplify score - the number of babies rescued - DONE
  # see above warning - code is still a mess :)

  def tick_game_scene # refactored this area to make it a bit easier to read, and do post jam updates
    draw_background_and_paramedics
    check_if_baby_at_a_bounce # set for later checks for if baby is caught by stretcher
    draw_wave
    should_a_baby_jump_now # takes into account where other babies may be, and the wave
    update_fire_on_building
    check_user_input
    check_should_babies_be_moved_right # this also checks if any babies have been missed
    draw_bouncing_babies # missed babies were removed from usual bouncing positions
    draw_score_and_lives
    draw_the_rest # this draws any missed babies on the ground, along with everything else
    check_next_wave
    check_game_over
  end

  def tick
    defaults
    scene_manager
  end

  def defaults
    return unless state.defaults_set.nil?
    audio[:game_music] = {
      input: 'sounds/game_music.ogg',  # Filename
      x: 0.0, y: 0.0, z: 0.0,          # Relative position to the listener, x, y, z from -1.0 to 1.0
      gain: 0.06,                      # Volume (0.0 to 1.0)
      pitch: 1.0,                      # Pitch of the sound (1.0 = original pitch)
      paused: true,                    # Set to true to pause the sound at the current playback position
      looping: true,                   # Set to true to loop the sound/music until you stop it
    }
    outputs.background_color = [ 0, 0, 0 ]
    state.masks = [
      "111111111111111111111111111110111111111101111111111111111".to_i(2),
      "111111111111111111111111111110111111111101111111111111111".to_i(2),
      "111111111101111111111111111110111111111101111111111111111".to_i(2),
      "111000111111111111111110000000000011111000000000000000000".to_i(2),
      "110000000000001111111111111111111111111111111111111111111".to_i(2),
      "111010101010101111111110101010101011111010101010101010101".to_i(2),
      "111100000000001111111100000000000111111100000000000000011".to_i(2),
      "111100000000001111111100000000000001110000000000000000001".to_i(2),
      "111111100000000111111110000000000011111100000000000000011".to_i(2),
      "111111000000001111110000000000000001110000000000000000000".to_i(2),
      "111111100000000111111110000000000011111000000000000000011".to_i(2),
      "111110000000001111111100000000000001110000000000000000001".to_i(2)
    ]
    state.wave = 1
    state.lives = 5
    state.game_over = false
    state.wave_over = false
    state.first_bounce = false
    state.second_bounce = false
    state.third_bounce = false
    state.skip_key_checks = false
    state.game_delay = 7 # match demo speed (initially - this will speed up)
    state.score = 0
    state.start_ticks = 0
    state.visited_left = false
    state.visited_middle = false
    state.visited_right = false
    state.missed_baby_left = false
    state.missed_baby_middle = false
    state.missed_baby_right = false
    state.current_scene = :title_scene
    state.babies_spawned = 0
    state.baby_in_air_max = 1
    state.baby_pattern = 0
    state.paramedics = STRETCHER_LEFT
    # bouncing_babies is a number, with some amount of bits set. Each bit represents a baby in that 'slot'.
    # bouncing_babies is 'shifted' right to move the babies along from left to right.
    state.bouncing_babies = 0
    # the babies array below defines where the baby in each slot shows up on the screen.
    # this is used to build a hash of hashes, the key to each hash/slot/baby corresponding to it's bit.
    state.babies = [ # coordinates where babies bounce on screen, there are 57 positions
      [19,540], # 56, in the burning building!
      [100,492], [135,435], [154,383], [174,323], [193,255], [212,179], [231,94],
      [250,52], # 48, first bounce
      [270,125], [289,191], [308,249], [327,298], [346,340], [366,374], [385,400], [404,418], [423,427], [442,429],
      [462,423], [481,409], [500,387], [519,356], [538,318], [558,272], [577,218], [596,156], [615,85],
      [634,52], # 28, second bounce
      [654,110], [673,164], [692,210], [711,248], [730,278], [750,300], [772,314], [798,318],
      [823,308], [846,290], [865,264], [884,230], [903,188], [922,138], [942,80],
      [961,52], # 12, third bounce
      [980,95], [999,139], [1018,175], [1038,204], [1057,224], [1076,237],
      [1095,243], [1114,237], [1134,226], [1153,206], [1172,178],
      [1186,161] # 0, safe at the ambulance :)
    ]
    state.defaults_set = true

    if !state.boingy
      position = 56 # the number of positions (0 based index) - there are 57
      state.boingy = {}
      state.babies.each do |x_coor, y_coor|
        state.boingy[position] = { x: x_coor, y: y_coor, angle: 360 - ((56 - position) * 90) }
        position -= 1 # decreasing as we go from left to right
      end
    end
  end

  def scene_manager
    current_scene = state.current_scene

    case current_scene
    when :title_scene
      tick_title_scene
    when :game_scene
      tick_game_scene
    when :game_over_scene
      tick_game_over_scene
    end

    if state.current_scene != current_scene
      raise "Scene was changed incorrectly. Set state.next_scene to change scenes."
    end

    if state.next_scene
      state.current_scene = state.next_scene
      state.next_scene = nil
    end
  end

  def tick_title_scene
    outputs.sprites << { x: 0, y: 0, w: 1280, h: 720, path: 'sprites/boingy/title_scene.png' }
    outputs.sprites << { x: state.paramedics, y: 16, w: 290, h: 84, path: 'sprites/boingy/stretcher.png' }
    # for the demo/title screen, it's a looping fixed sequence of actions
    case state.bouncing_babies
    when ADD_FIRST_BABY
      state.bouncing_babies = state.bouncing_babies | (1<<57) # put a baby just left of the window
    when ADD_SECOND_BABY
      state.bouncing_babies = state.bouncing_babies | (1<<57) # put a baby just left of the window
    when ADD_THIRD_BABY
      state.bouncing_babies = state.bouncing_babies | (1<<57) # put a baby just left of the window
    when MOVE_STRETCHER_LEFT
      state.paramedics = STRETCHER_LEFT
    when MOVE_STRETCHER_MIDDLE
      state.paramedics = STRETCHER_MIDDLE
    when MOVE_STRETCHER_RIGHT
      state.paramedics = STRETCHER_RIGHT
    end
   
    if state.bouncing_babies > 0 # if there is at least one bouncing baby
      state.boingy.each do |n, v|
        if ((state.bouncing_babies >> n) & 1) == 1 # if the key/bit is set, draw that baby
          outputs.sprites << { x: v[:x], y: v[:y], w: 64, h: 64, angle: v[:angle], path: 'sprites/boingy/baby.png' }
        end
      end
    end

    if rand < 0.96
      outputs.sprites << { x: 19, y: 642, w: 64, h: 64, path: 'sprites/boingy/fire.png', flip_horizontally: state.fireflip }
    else
      if state.fireflip != false
        state.fireflip = false
      else
        state.fireflip = true
      end
    end

    if state.tick_count % 7 == 0 # demo speed
      state.bouncing_babies = state.bouncing_babies >> 1 # shift babies over to the right
    end

    if inputs.mouse.click or inputs.keyboard.key_up.space
      state.bouncing_babies = 0 # start with no babies
      state.paramedics = STRETCHER_LEFT # start game with stretcher at the left
      audio[:game_music].paused = false # begin playing the main game music
      audio[:game_music].looping = true
      state.next_scene = :game_scene
    end
  end

  def tick_game_over_scene
    outputs.primitives << state.all_primitives
    if inputs.mouse.click or inputs.keyboard.key_up.space
      state.defaults_set = nil
    end
  end

  def check_if_baby_at_a_bounce
    if ((state.bouncing_babies >> 48) & 1) == 1 # there is a baby is at the first bounce
      state.first_bounce = true
    end
    if ((state.bouncing_babies >> 28) & 1) == 1 # there is a baby is at the second bounce
      state.second_bounce = true
    end
    if ((state.bouncing_babies >> 12) & 1) == 1 # there is a baby is at the third bounce
      state.third_bounce = true
    end
  end

  def should_a_baby_jump_now
    # time for some action - if any of these bits are set, do not jump
    if state.babies_spawned < 10.lesser(state.wave * 2) # the total spwned is capped per wave
      if state.bouncing_babies.to_s(2).count("1") < state.baby_in_air_max # max in the air at once
        if (state.bouncing_babies & state.masks[state.baby_pattern]) == 0
          # if there is not already one in the window, put one there
          if ((state.bouncing_babies >> 57) & 1) == 0
            state.bouncing_babies = state.bouncing_babies | (1<<57)
            state.babies_spawned += 1
            if state.babies_spawned >= 10.lesser(state.wave * 2) # [10, (state.wave * 2)].min # b > 10 ? 10 : b
              state.wave_over = true
            end
            # putz "#{state.bouncing_babies.to_s(2)}"
          end
        end
      end
    end
  end

  def update_fire_on_building
    if rand < 0.96
      state.all_primitives.append({ x: 19, y: 642, w: 64, h: 64, path: 'sprites/boingy/fire.png',
        flip_horizontally: state.fireflip }.sprite!)
    else
      if state.fireflip != false
        state.fireflip = false
      else
        state.fireflip = true
      end
    end
  end

  def check_user_input
    if state.skip_key_checks != true
      # check keys for stretcher movement - if a baby has been missed, skip this section a while
      if inputs.keyboard.key_down.left
        case state.paramedics
        when STRETCHER_MIDDLE
          state.paramedics = STRETCHER_LEFT 
        when STRETCHER_RIGHT
          state.paramedics = STRETCHER_MIDDLE     
        end
      elsif inputs.keyboard.key_down.right
        case state.paramedics
        when STRETCHER_MIDDLE
          state.paramedics = STRETCHER_RIGHT 
        when STRETCHER_LEFT
          state.paramedics = STRETCHER_MIDDLE     
        end    
      elsif inputs.keyboard.key_down.one
        state.paramedics = STRETCHER_LEFT
        state.visited_left = true
      elsif inputs.keyboard.key_down.two
        state.paramedics = STRETCHER_MIDDLE
        state.visited_middle = true
      elsif inputs.keyboard.key_down.three
        state.paramedics = STRETCHER_RIGHT
        state.visited_right = true
      end

      if inputs.keyboard.key_down.forward_slash
        @show_fps = !@show_fps
      end
      if @show_fps
        state.all_primitives.append({ x: 1278, y: 660, text: "#{gtk.current_framerate.to_sf}", size_enum: 3, alignment_enum: 2,
        r: 255, g: 255, b: 255, font: "fonts/IBM_EGA_8x8.ttf"}.label!)
        # args.outputs.primitives << args.gtk.current_framerate_primitives
        # hacky if fps is on, do auto paramedics
        state.paramedics = STRETCHER_LEFT if state.first_bounce == true
        state.paramedics = STRETCHER_MIDDLE if state.second_bounce == true
        state.paramedics = STRETCHER_RIGHT if state.third_bounce == true
      end
    end

    case state.paramedics
    when STRETCHER_LEFT
      state.visited_left = true
    when STRETCHER_MIDDLE
      state.visited_middle = true
    when STRETCHER_RIGHT
      state.visited_right = true
    end 

    if state.tick_count == state.start_ticks + 100
      state.skip_key_checks = false
      state.missed_baby_left = false
      state.missed_baby_middle = false
      state.missed_baby_right = false
    end
  end

  def check_should_babies_be_moved_right
    if state.tick_count % state.game_delay == 0
      if state.skip_key_checks != true
        state.bouncing_babies = state.bouncing_babies >> 1 # shift babies over to the right
      end
 
      if ((state.bouncing_babies >> 0) & 1) == 1
          state.score += 1 if state.score < 999999
      end

      if state.first_bounce == true
        if ((state.bouncing_babies >> 48) & 1) == 0
          if state.visited_left == false
            audio[:boing] = {
              input: 'sounds/baby_cry.ogg',  # Filename
              x: 0.0, y: 0.0, z: 0.0,        # Relative position to the listener, x, y, z from -1.0 to 1.0
              gain: 0.3,                     # Volume (0.0 to 1.0)
              pitch: 1.0,                    # Pitch of the sound (1.0 = original pitch)
              paused: false,                 # Set to true to pause the sound at the current playback position
              looping: false,                # Set to true to loop the sound/music until you stop it
            }
            state.lives -= 1
            # remove this baby from state.bouncing_babies (it's been moved one slot to the right)
            state.bouncing_babies = state.bouncing_babies & ~(1<<47)
            state.start_ticks = state.tick_count
            state.skip_key_checks = true
            state.missed_baby_left = true
            state.game_over = true if state.lives < 1
          else
            audio[:boing] = {
              input: 'sounds/boing.ogg',  # Filename
              x: 0.0, y: 0.0, z: 0.0,     # Relative position to the listener, x, y, z from -1.0 to 1.0
              gain: 0.5,                  # Volume (0.0 to 1.0)
              pitch: 1.0,                 # Pitch of the sound (1.0 = original pitch)
              paused: false,              # Set to true to pause the sound at the current playback position
              looping: false,             # Set to true to loop the sound/music until you stop it
            }
          end
          state.first_bounce = false
        end
      end
      if state.second_bounce == true
        if ((state.bouncing_babies >> 28) & 1) == 0
          if state.visited_middle == false
            audio[:boing] = {
              input: 'sounds/baby_cry.ogg',  # Filename
              x: 0.0, y: 0.0, z: 0.0,        # Relative position to the listener, x, y, z from -1.0 to 1.0
              gain: 0.3,                     # Volume (0.0 to 1.0)
              pitch: 1.0,                    # Pitch of the sound (1.0 = original pitch)
              paused: false,                 # Set to true to pause the sound at the current playback position
              looping: false,                # Set to true to loop the sound/music until you stop it
            }
            state.lives -= 1 
            # remove this baby from state.bouncing_babies (it's been moved one slot to the right)
            state.bouncing_babies = state.bouncing_babies & ~(1<<27)
            state.start_ticks = state.tick_count
            state.skip_key_checks = true
            state.missed_baby_middle = true
            state.game_over = true if state.lives < 1
          else
            audio[:boing] = {
              input: 'sounds/boing.ogg',  # Filename
              x: 0.0, y: 0.0, z: 0.0,     # Relative position to the listener, x, y, z from -1.0 to 1.0
              gain: 0.5,                  # Volume (0.0 to 1.0)
              pitch: 1.0,                 # Pitch of the sound (1.0 = original pitch)
              paused: false,              # Set to true to pause the sound at the current playback position
              looping: false,             # Set to true to loop the sound/music until you stop it
            }
          end
          state.second_bounce = false
        end
      end
      if state.third_bounce == true
        if ((state.bouncing_babies >> 12) & 1) == 0
          if state.visited_right == false
            audio[:boing] = {
              input: 'sounds/baby_cry.ogg',  # Filename
              x: 0.0, y: 0.0, z: 0.0,        # Relative position to the listener, x, y, z from -1.0 to 1.0
              gain: 0.3,                     # Volume (0.0 to 1.0)
              pitch: 1.0,                    # Pitch of the sound (1.0 = original pitch)
              paused: false,                 # Set to true to pause the sound at the current playback position
              looping: false,                # Set to true to loop the sound/music until you stop it
            }
            state.lives -= 1 
            # remove this baby from state.bouncing_babies (it's been moved one slot to the right)
            state.bouncing_babies = state.bouncing_babies & ~(1<<11)
            state.start_ticks = state.tick_count
            state.skip_key_checks = true
            state.missed_baby_right = true
            state.game_over = true if state.lives < 1
          else
            audio[:boing] = {
              input: 'sounds/boing.ogg',  # Filename
              x: 0.0, y: 0.0, z: 0.0,     # Relative position to the listener, x, y, z from -1.0 to 1.0
              gain: 0.5,                  # Volume (0.0 to 1.0)
              pitch: 1.0,                 # Pitch of the sound (1.0 = original pitch)
              paused: false,              # Set to true to pause the sound at the current playback position
              looping: false,             # Set to true to loop the sound/music until you stop it
            }
          end
          state.third_bounce = false
        end
      end
      state.visited_left = false
      state.visited_middle = false
      state.visited_right = false
    end
  end

  def draw_bouncing_babies
    if state.bouncing_babies > 0 # if there is at least one bouncing baby
      state.boingy.each do |n, v|
        if ((state.bouncing_babies >> n) & 1) == 1 # if the key/bit is set, draw that baby
          state.all_primitives.append({ x: v[:x], y: v[:y], w: 64, h: 64, angle: v[:angle], path: 'sprites/boingy/baby.png' }.sprite!)
        end
      end
    end
  end

  def draw_wave
    state.all_primitives.append({ x: 842, y: 710, text: state.wave, size_enum: 3, alignment_enum: 1,
      r: 255, g: 255, b: 255, font: "fonts/IBM_EGA_8x8.ttf"}.label!)
  end

  def draw_score_and_lives
    state.all_primitives.append({ x: 1192, y: 710, text: state.score, size_enum: 3, alignment_enum: 1,
      r: 255, g: 255, b: 255, font: "fonts/IBM_EGA_8x8.ttf"}.label!)

    (1..state.lives).each do |x_coor| # draw a baby for each life the player has
      state.all_primitives.append({ x: 524 - x_coor * 70, y: 652, w: 64, h: 64, angle: 0, path: 'sprites/boingy/baby.png' }.sprite!)
    end
  end

  def draw_the_rest
    if state.missed_baby_left == true
      state.all_primitives.append({ x: 250 + 2, y: 12, w: 64, h: 64, angle: 0, path: 'sprites/boingy/baby.png' }.sprite!)
    end

    if state.missed_baby_middle == true
      state.all_primitives.append({ x: 634 + 2, y: 12, w: 64, h: 64, angle: 0, path: 'sprites/boingy/baby.png' }.sprite!)
    end

    if state.missed_baby_right == true
      state.all_primitives.append({ x: 961 + 2, y: 12, w: 64, h: 64, angle: 0, path: 'sprites/boingy/baby.png' }.sprite!)
    end
    outputs.primitives << state.all_primitives
  end

  def check_next_wave
    if state.wave_over == true # no more left to spawn this wave
      if state.bouncing_babies == 0 # there aren't any in the air
        state.babies_spawned = 0
        state.wave_over = false
        state.baby_in_air_max += 1 if state.baby_in_air_max < 5 # increase the cap by 1, to a max of 5
        if state.wave == 5
          # update this area .. at some stage remove the 'starter' patterns from the mix
          # state.masks.delete_at(1)
            state.masks = state.masks - ["111111111111111111111111111110111111111101111111111111111".to_i(2)]
            state.masks = state.masks - ["111111111111111111111111111110111111111101111111111111111".to_i(2)]
            state.masks = state.masks - ["111111111101111111111111111110111111111101111111111111111".to_i(2)]
            state.masks = state.masks - ["111000111111111111111110000000000011111000000000000000000".to_i(2)]
        end
        state.wave += 1 if state.wave < 99999 # advance to the next wave
        if state.baby_pattern < ( state.masks.length - 1 )
          state.baby_pattern += 1
        else
          state.baby_pattern = 0
        end
        if state.wave % 5 == 0
          state.game_delay -= 1 if state.game_delay > 5
        end
      end
    end
    # outputs.labels << { x: 130, y: 30.from_top, text: "#{state.babies_spawned}", r: 255, g: 255, b: 255 }
    # outputs.labels << { x: 130, y: 50.from_top, text: "#{state.wave_over}", r: 255, g: 255, b: 255 }
    # outputs.labels << { x: 130, y: 70.from_top, text: "#{gtk.current_framerate.to_sf}", r: 255, g: 255, b: 255 }
    # outputs.labels << { x: 130, y: 30.from_top, text: "#{state.baby_pattern}", r: 255, g: 255, b: 255 }
  end

  def check_game_over
    if state.game_over == true
      state.all_primitives.append({ x: 640, y: 360, text: "Game Over", size_enum: 5, alignment_enum: 1,
        r: 209, g: 150, b: 150, font: "fonts/IBM_EGA_8x8.ttf"}.label!)      
      audio[:game_music].looping = false
      state.next_scene = :game_over_scene
    end
  end

  def draw_background_and_paramedics
    state.all_primitives = [] # group everything into one array/draw call
    state.all_primitives.append({ x: 0, y: 0, w: 1280, h: 720, path: 'sprites/boingy/game_scene.png' }.sprite!)
    state.all_primitives.append({ x: state.paramedics, y: 16, w: 290, h: 84, path: 'sprites/boingy/stretcher.png' }.sprite!)
  end

end

def tick args
  $game ||= Game.new
  $game.args = args
  $game.tick
end

# DR will call this method (in addition do doing what it already does) if $gtk.reset is called
def reset
  $game = nil
end

$gtk.reset
