#!/bin/bash
# Test PIN-based encryption/decryption round-trip

echo "=== PIN-Based Encryption Test ==="
echo

cd "$(dirname "$0")"

ruby -e '
require "openssl"

# Constants from pbj
PIN_PADDING_B64 = "XJv3x5LT080xr0zjLgzaAS/UvSfSJigSZUD7Ug=="
PIN_PADDING = PIN_PADDING_B64.unpack1("m0").freeze

def derive_pin_key(pin)
  raise "PIN must be 4 characters" unless pin.length == 4
  pin_bytes = pin.bytes
  key = pin_bytes.pack("C*") + PIN_PADDING
  raise "Key derivation failed" unless key.bytesize == 32
  key
end

def encrypt_key_for_recovery(key, pin)
  derive_key = derive_pin_key(pin)
  cipher = OpenSSL::Cipher.new("aes-256-gcm")
  cipher.encrypt
  cipher.key = derive_key
  iv = cipher.random_iv
  ciphertext = cipher.update(key) + cipher.final
  auth_tag = cipher.auth_tag
  encrypted_blob = iv + auth_tag + ciphertext
  [encrypted_blob].pack("m0")
end

def decrypt_key_from_recovery(encrypted_b64, pin)
  derive_key = derive_pin_key(pin)
  encrypted_blob = encrypted_b64.unpack1("m0")
  iv = encrypted_blob[0, 12]
  auth_tag = encrypted_blob[12, 16]
  ciphertext = encrypted_blob[28..-1]

  raise "Invalid encrypted blob format" if ciphertext.nil? || ciphertext.empty?

  cipher = OpenSSL::Cipher.new("aes-256-gcm")
  cipher.decrypt
  cipher.key = derive_key
  cipher.iv = iv
  cipher.auth_tag = auth_tag

  key = cipher.update(ciphertext) + cipher.final
  raise "Decrypted key has wrong size" unless key.bytesize == 32
  key
rescue OpenSSL::Cipher::CipherError
  raise "Decryption failed - wrong PIN or corrupted data"
end

# Run tests
begin
  puts "Test 1: Generate random 32-byte key"
  puts "-" * 60
  original_key = OpenSSL::Random.random_bytes(32)
  puts "Generated key: #{[original_key].pack("m0")[0..20]}... (#{original_key.bytesize} bytes)"
  puts

  puts "Test 2: Encrypt with PIN \"1234\""
  puts "-" * 60
  pin = "1234"
  encrypted = encrypt_key_for_recovery(original_key, pin)
  puts "Encrypted blob: #{encrypted[0..40]}..."
  puts "Blob length: #{encrypted.length} chars base64"
  puts

  puts "Test 3: Decrypt with correct PIN \"1234\""
  puts "-" * 60
  decrypted_key = decrypt_key_from_recovery(encrypted, pin)
  puts "Decrypted key: #{[decrypted_key].pack("m0")[0..20]}... (#{decrypted_key.bytesize} bytes)"
  puts

  if original_key == decrypted_key
    puts "✓ Keys match! Encryption round-trip successful"
  else
    puts "✗ Keys DO NOT match!"
    exit 1
  end
  puts

  puts "Test 4: Try decrypting with wrong PIN \"9999\""
  puts "-" * 60
  begin
    decrypt_key_from_recovery(encrypted, "9999")
    puts "✗ ERROR: Should have failed with wrong PIN!"
    exit 1
  rescue => e
    puts "✓ Correctly failed: #{e.message}"
  end
  puts

  puts "Test 5: Encrypt with different PIN \"4242\""
  puts "-" * 60
  pin2 = "4242"
  encrypted2 = encrypt_key_for_recovery(original_key, pin2)
  decrypted2 = decrypt_key_from_recovery(encrypted2, pin2)

  if original_key == decrypted2
    puts "✓ Encryption with different PIN works"
  else
    puts "✗ Failed with different PIN"
    exit 1
  end
  puts

  puts "Test 6: Verify encrypted blobs differ (different IVs)"
  puts "-" * 60
  encrypted3 = encrypt_key_for_recovery(original_key, pin)
  if encrypted != encrypted3
    puts "✓ Different encryptions produce different blobs (random IV)"
  else
    puts "✗ Encrypted blobs are identical (IV not random?)"
    exit 1
  end
  puts

  puts "=" * 60
  puts "✓ All encryption tests passed!"
  puts "=" * 60
rescue => e
  puts "✗ Test failed: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
'
