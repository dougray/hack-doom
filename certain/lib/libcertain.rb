require 'pty'
require 'open3'

# GameServer defines a running game server
class GameServer
  def initialize(iwad, assets, wads, marines, level, port)
    @doombin = `which zandronum`.strip!
    @wsbin = `which websocketd`.strip!
    @wsport = port
    @args = "-iwad #{iwad} -host #{marines} -coop -file #{assets.join(' ')} #{wads.join(' ')} +map #{level}"
    @extCmd = ExternalCommand.new
    @gamCmd = GameCommand.new
  end

  def where?
    @doombin
  end

  def start
    # Check for if the user wants to start a websocket
    if $nowebsocket 
      command = "#{@doombin} #{@args}" 
    elsif
      command = "#{@wsbin} --port=#{@wsport} #{@doombin} #{@args}" 
    end

    if $verbose then puts "Launching with command:  \"#{command}\"" end
    i, o = Open3.popen2 "#{command}"
    gc = GameCommand.new
    ec = ExternalCommand.new
    
    # Begin command loop
    Thread.new do
      ARGF.each_line do |line|
        stop && exit if line =~ /quit/
        request = line.split(/\s+/)
        if request.empty?
          puts "No command"
        elsif request[0] =~ /map/
          i.puts "map #{request[1]}"
        elsif !ec.commands.has_key? request[0]
          puts "Command not recognized"
        else
          i.puts ec.command(request)
        end
      end
    
      i.close
    end

    # Parse output from the @doombin
    while res = o.gets
      gc.commands.each {|x| puts res if res.include? x}
    end
  end

  def stop
    `ps aux | grep #{@doombin} | grep -v grep | awk '{print $2}' | xargs kill`
  end
end

# GameEvent is the base class that defines communication to and from a game in progress
class GameEvent
  def intialize
    # List of valid commands
    @commands = Hash.new
  end

  attr_reader :commands
end

# GameCommand is for events originating within a game
class GameCommand < GameEvent
  def initialize
    # List of valid commands
    @commands = [ 'Hackswitch', 'Secret' ]
  end

  # Translate the requested text into a command
  def command (request)
    tokens = request.split(/\s+/)
    raise ArgumentError, "Not a command" if tokens.empty?
  end
end

# ExternalCommand is for events originating outside the game
class ExternalCommand < GameEvent
  def initialize
    @commands = { 'openhackdoor'  => 'OpenHackdoor',
                  'spawnenemy'    => 'SpawnEnemy',
                  'spawnpowerup'  => 'SpawnPowerUp',
                  'lowerhacklift' => 'LowerHacklift',
                  'raisehacklift' => 'RaiseHacklift' }
  end

  # Translate the requested text into a command
  def command (request)
    failure = false

    # Determine in-game command to run with arguments
    case request[0]
      when "openhackdoor"
        failure = true if request.size < 2

      when "spawnenemy"
        failure = true if request.size < 3
        if request[3] == nil then request[3] = 0 end
        if request[4] == nil then request[4] = 0 end

      when "spawnpowerup"
        failure = true if request.size < 3

      when "lowerhacklift"
        failure = true if request.size < 2
        if request[2] == nil then request[2] = 90 end

      when "raisehacklift"
        failure = true if request.size < 2
        if request[2] == nil then request[2] = 90 end

      else
        raise ArgumentError, "Unknown command"
    end

    # Run the command
    if failure
      return "echo Not enough arguments"
    else
      transCommand = request.shift
      return "pukename \"HackDoom #{@commands[transCommand]}\" #{request.join(" ")}"
    end
  end
end
