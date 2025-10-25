#!/usr/bin/env ruby
# Quick test script for PIN input functionality

# Load the PBJ class by reading and evaluating the script
pbj_script = File.read(File.join(__dir__, 'bin', 'pbj'))

# Extract just the class definition (skip the main execution block)
class_code = pbj_script[/^require.*?^class PBJ.*?^end$/m]

# Evaluate to define the class
eval(class_code)

puts "=== PIN Input Test ==="
puts

pbj = PBJ.new

begin
  puts "Test 1: Basic PIN input"
  puts "-" * 40
  pin = pbj.prompt_pin("Enter test PIN: ")
  puts "You entered: #{pin}"
  puts

  puts "Test 2: PIN with confirmation"
  puts "-" * 40
  confirmed_pin = pbj.get_pin_with_confirmation()
  puts "Confirmed PIN: #{confirmed_pin}"
  puts

  puts "✓ All tests passed!"
rescue => e
  puts "✗ Test failed: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
