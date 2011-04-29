#!/usr/bin/env ruby
#
# Test the execute function with different test-cases

# No Output
def nooutput
end

# Handle STDOUT
def stdout
  STDOUT.print "First line\n"
  STDOUT.print "Last line\n"
end

# Missing newline. Is execute blocking here?
def stdout_lacks_newline
  STDOUT.print "First line\n"
  STDOUT.print "Last line with missing newline"
end

def stderr_lacks_newline
  STDERR.print "First line\n"
  STDERR.print "Last line with missing newline"
end

def stderr
  STDERR.print "First line\n"
  STDERR.print "Second line\n"
end

# Throw STDERR in the mix
def stdout_and_stderr
  STDOUT.print "Out 01\n"
  STDERR.print "Err 01\n"
  STDOUT.print "Out 02\n"
  STDERR.print "Err 02\n"
end

# Close pipe
def closepipes
  STDOUT.print "Bye\n"
  STDOUT.close
  sleep 0.2
  STDERR.print "Bye\n"
  STDERR.close
end

def spinner
  STDOUT.sync = true
  STDOUT.print "Please wait |"
  [ '/', '-', '\\', '|', '/', '-', '\\', '|'].each do |c|
    sleep 0.05
    STDOUT.print "\rPlease wait #{c}"
  end
  STDOUT.print "\n"
  STDOUT.print "DONE\n"
end

def stdin
  STDOUT.print "Exit? [y/n]"
  if a = STDIN.gets
    STDOUT.print "Got #{a}\n"
  else
    STDOUT.print "Got no answer\n"
  end
end

def answerfile
  STDOUT.print "User: "
  user = STDIN.gets.chomp
  STDOUT.print "Uid : "
  uid = STDIN.gets.chomp
  STDOUT.print "Gid : "
  gid = STDIN.gets.chomp
  STDOUT.print "Got user #{user} with uid #{uid} and gid #{gid}\n"
end

testcase = ARGV[0]
returncode = ARGV[1]

send(testcase.intern)
exit Integer(returncode)
