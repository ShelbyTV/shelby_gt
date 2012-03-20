#!/usr/bin/env ruby
#puts "Runs some number of copies of the given command.  Always restarts the command if a copy dies."
#puts "usage: `pump_iron.rb <num_procs> <cmd> [arg1, arg2, ...]`"

Process.daemon(true, true)
puts "PumpIron daemon start."


num_procs = ARGV.shift
cmd = ARGV.shift
args = ARGV


$running = true
trap(:TERM) { puts "trapped SIG_TERM, stopping (not killing children)..."; $running = false; }
trap(:INT) { puts "trapped SIG_INT, stopping (not killing children)..."; $running = false; }
trap(:USR1) { puts "trapped SIG_USR1, killing all children & stopping..."; PumpIron.kill_all_children; $running = false; }


class PumpIron
  @@children_pids = []
  
  def self.spawn_and_watch(cmd, args)
    puts "spawning `#{cmd} #{args}`"
    pid = Process.spawn(cmd, *args)
    @@children_pids << pid
  
    #wait until process dies, then restart it (with this method, to keep watching it)
    Thread.new(pid, cmd, args) do |pid, cmd, args|
      puts "watching #{pid}..."
      Process.waitpid(pid)
      puts "#{pid} exited.  Restart? #{$running}!"
      spawn_and_watch(cmd, args) if $running
      @@children_pids.delete(pid)
    end
  
  end
  
  def self.kill_all_children
    @@children_pids.each { |pid| puts "`kill #{pid}`"; Process.kill("TERM", pid); }
  end
end


num_procs.to_i.times { PumpIron.spawn_and_watch(cmd, args) }

sleep(5) while($running)
puts "PumpIron daemon exit."