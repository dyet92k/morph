#!/usr/bin/env ruby

# This wrapper script runs a command and lets standard out and error flow
# through. However, it does limit the number of lines of output. This is
# used by morph as a wrapper around running scrapers to ensure that they
# can't fill up the docker container log file (and hence the server disk).

require 'optparse'
require 'open3'

command = nil
exit_status = nil

OptionParser.new do |opts|
  opts.banner = 'Usage: ./limit_output.rb [command to run]'

  command = ARGV[0]
  if command.nil?
    STDERR.puts 'Please give me a command to run'
    puts opts
    exit
  end
end.parse!

# Disable output buffering
STDOUT.sync = true
STDERR.sync = true

stdout_buffer = ''
stderr_buffer = ''

Open3.popen3(command) do |_stdin, stdout, stderr, wait_thr|
  streams = [stdout, stderr]
  until streams.empty?
    IO.select(streams).flatten.compact.each do |io|
      if io.eof?
        streams.delete io
        next
      end

      on_stdout_stream = io.fileno == stdout.fileno
      # Just send this stuff straight through
      buffer = on_stdout_stream ? stdout_buffer : stderr_buffer
      s = io.readpartial(1)
      buffer << s
      if s == "\n"
        if on_stdout_stream
          STDOUT << buffer
          stdout_buffer = ''
        else
          STDERR << buffer
          stderr_buffer = ''
        end
      end
    end
  end

  # Output whatever is left in the buffers
  STDOUT << stdout_buffer
  STDERR << stderr_buffer

  exit_status = wait_thr.value.exitstatus
end

exit(exit_status)
