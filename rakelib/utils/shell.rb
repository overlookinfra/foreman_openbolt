# frozen_string_literal: true

require 'open3'

# Color helpers for terminal output. Yes, the colorize gem does this,
# but these few lines allow us to avoid another gem dependency.
#   .red     - errors and fatal failures
#   .green   - success (build complete, image cached, tests passed)
#   .yellow  - non-fatal warnings
#   .magenta - workflow status (high-level step descriptions)
#   .cyan    - low-level command execution info
class String
  def red = "\033[31m#{self}\033[0m"
  def green = "\033[32m#{self}\033[0m"
  def yellow = "\033[33m#{self}\033[0m"
  def magenta = "\033[35m#{self}\033[0m"
  def cyan = "\033[36m#{self}\033[0m"
end

module Shell
  Result = Struct.new(:output, :exitcode)

  module_function

  # Run a command with full terminal passthrough (colors, progress bars).
  # Aborts if exit code is not in allowed_exit_codes. Returns the exit code.
  def run(cmd, print_command: true, allowed_exit_codes: [0])
    display = if cmd.is_a?(Array)
                cmd.map { |arg| arg.match?(%r{[^a-zA-Z0-9_./:\-=]}) ? "'#{arg}'" : arg }.join(' ')
              else
                cmd
              end
    puts "Running #{display}".cyan if print_command
    system(*Array(cmd))
    abort "Command not found: #{display}".red unless $?
    exitcode = $?.exitstatus
    unless allowed_exit_codes.include?(exitcode)
      abort "Command failed! Command: #{display}, Exit code: #{exitcode}".red
    end
    exitcode
  end

  # Run a command and capture its output.
  # Aborts if exit code is not in allowed_exit_codes.
  # Returns a Result with .output (String) and .exitcode (Integer).
  # When silent (default), output is not printed to the terminal.
  # When not silent, each line is printed as it arrives in addition to
  # being captured.
  def capture(cmd, silent: true, print_command: true, allowed_exit_codes: [0])
    display = if cmd.is_a?(Array)
                cmd.map { |arg| arg.match?(%r{[^a-zA-Z0-9_./:\-=]}) ? "'#{arg}'" : arg }.join(' ')
              else
                cmd
              end
    puts "Running #{display}".cyan if print_command
    output = ''
    exitcode = nil
    begin
      Open3.popen2e(*[cmd].flatten) do |_stdin, stdout_stderr, thread|
        stdout_stderr.each do |line|
          puts line unless silent
          output += line
        end
        exitcode = thread.value.exitstatus
      end
    rescue Errno::ENOENT
      abort "Command not found: #{display}".red
    end
    unless allowed_exit_codes.include?(exitcode)
      err = "Command failed! Command: #{display}, Exit code: #{exitcode}"
      err += "\nOutput:\n#{output}" if silent
      abort err.red
    end
    Result.new(output.chomp, exitcode)
  end
end
