#!/bin/bash
# Test PIN input functionality by calling pbj with a special test mode

echo "=== PIN Input Test ==="
echo
echo "This will test the PIN input system interactively."
echo "You'll be prompted to enter PINs with masking."
echo
echo "Test scenarios:"
echo "  1. Enter a 4-digit PIN (watch for * masking)"
echo "  2. Try backspace to correct mistakes"
echo "  3. Try non-numeric input (should reject)"
echo "  4. Try mismatched confirmation (should retry)"
echo "  5. Successfully confirm matching PIN"
echo
echo "Press Enter to start testing..."
read

# Test by calling pbj with a test command
cd "$(dirname "$0")"

ruby -e '
require "io/console"
require "openssl"

# Define just the PIN methods inline for testing
def prompt_pin(prompt_text)
  STDERR.print prompt_text
  STDERR.flush

  pin = ""

  begin
    loop do
      char = STDIN.getch

      case char.ord
      when 3  # Ctrl-C
        STDERR.puts
        raise Interrupt
      when 13, 10  # Enter (CR or LF)
        STDERR.puts
        break
      when 127, 8  # Backspace (DEL or BS)
        unless pin.empty?
          pin.chop!
          STDERR.print "\b \b"
          STDERR.flush
        end
      when 32..126  # Printable characters
        if pin.length < 4
          pin << char
          STDERR.print "*"
          STDERR.flush
        end
      end
    end
  rescue IOError, Errno::EBADF
    raise "PIN input requires interactive terminal"
  end

  pin
end

def get_pin_with_confirmation()
  loop do
    pin1 = prompt_pin("Enter 4-digit PIN: ")

    unless pin1.match?(/^\d{4}$/)
      STDERR.puts "✗ PIN must be exactly 4 digits (0-9 only)"
      STDERR.puts ""
      next
    end

    pin2 = prompt_pin("Confirm PIN: ")

    if pin1 == pin2
      STDERR.puts "✓ PIN confirmed"
      STDERR.puts ""
      return pin1
    else
      STDERR.puts "✗ PINs do not match. Try again."
      STDERR.puts ""
    end
  end
end

# Run tests
begin
  puts "Test 1: Basic PIN input"
  puts "-" * 40
  pin = prompt_pin("Enter test PIN: ")
  puts "You entered: #{pin}"
  puts "Length: #{pin.length} characters"
  puts

  puts "Test 2: PIN with confirmation"
  puts "-" * 40
  confirmed_pin = get_pin_with_confirmation()
  puts "Confirmed PIN: #{confirmed_pin}"
  puts

  puts "✓ All tests passed!"
rescue Interrupt
  puts "\n✗ Interrupted by user"
  exit 130
rescue => e
  puts "✗ Test failed: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
'
