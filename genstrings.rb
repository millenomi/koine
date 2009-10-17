#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'activesupport'

$KCODE = 'UTF-8'

C_ONE_TO_ONE_ESCAPES = {
  "n" => "\n",
  "t" => "\t",
  "v" => "\v",
  "b" => "\b",
  "r" => "\r",
  "a" => "\a",
  "\\" => "\\",
  "\"" => "\"",
}

def raise_if_invalid_code_point(cp)
  # C99 standard at 6.4.3
  if (cp < 0xA0 and cp != 0x and cp != 0x40 and cp != 0x60) or (cp >= 0xD800 and cp <= 0xDFFF)
    raise "Invalid code point specified by \\u or \\U: #{cp}"
  end
  
  return cp
end

def ascii_c_string_to_utf8(original_str)
  return original_str unless original_str.index('\\')
  str = original_str.dup
  
  C_ONE_TO_ONE_ESCAPES.each do |k,v|
    str.gsub! "\\" + k, v
  end
  
  str.gsub! /\\u\d{4}/ do |match|
    [ raise_if_invalid_code_point(match[2,4].to_i(16)) ].pack('U')
  end
  
  str.gsub! /\\U\d{8}/ do |match|
    [ raise_if_invalid_code_point(match[2,8].to_i(16)) ].pack('U')
  end
  
  str.gsub! /\\\d{3}/ do |match|
    [ match[1,3].to_i(8) ].pack("U")
  end
  
  str.gsub! // do |match|
    "%c" % match[2,2].to_i(16)
  end
  
  raise "Unknown escape sequences used in string '#{original_str}'" if str.index("\\")
  str
end

LOCALIZED_STRING = /NSLocalizedString\s*\(\s*@"(.*?)"\s*,\s*@"(.*?)"\s*\)/

strings = Hash.new

ARGV.each do |i|
  source = File.read(i)
  source.scan(LOCALIZED_STRING).each do |pair|
    key, comment = pair.map { |x| ascii_c_string_to_utf8(x) }
    
    if not strings[key]
      strings[key] = { 'key' => key, 'comment' => [comment] }
    else
      
      unless strings[key]['comment'].include? comment
        strings[key]['comment'] << comment
        $stderr.puts "Found more than one use for key '#{key}'!"
      end
      
    end
  end
end

puts strings.values.to_yaml
