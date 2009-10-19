#!/usr/bin/env ruby

require 'koine/common'
require 'tempfile'
require 'osx/cocoa'
require 'fileutils'

module ILabs; end
module ILabs::Koine; end

module ILabs::Koine::Apple
	ISO_NAMES_TO_NEXTSTEP_NICKNAMES = {
		'en' => 'English',
		'it' => 'Italian',
		'nl' => 'Dutch',
		'fr' => 'French',
		'de' => 'German',
		'ja' => 'Japanese',
		'es' => 'Spanish'
	}
	
	module AppleApplier
		include ILabs::Koine::Applier
		
		def lproj(locale, producer)
			lproj = File.join(producer.path, locale + '.lproj')
			if not File.exist? lproj
				FileUtils.mkdir lproj
			end
			
			lproj
		end
		
		def source_lproj(locale, producer)
			raise "The source path was not set in the producer!" unless producer.sources_path
			lp = File.join(producer.sources_path, locale + '.lproj')
			if not File.exist? lp and ISO_NAMES_TO_NEXTSTEP_NICKNAMES[locale]
				lp = File.join(producer.sources_path, ISO_NAMES_TO_NEXTSTEP_NICKNAMES[locale] + '.lproj')
			end
			
			if not File.exist? lp
				raise "The source lproj for locale #{locale} doesn't seem to exist."
			end
			
			lp
		end
		
		def base_lproj(producer)
			source_lproj(producer.docset.base_locale, producer)
		end
			
	end

	class Strings
		include ILabs::Koine::Extractor
		include AppleApplier

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
			if (cp < 0xA0 and cp != 0x24 and cp != 0x40 and cp != 0x60) or (cp >= 0xD800 and cp <= 0xDFFF)
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

			str.gsub! /\\x\d{2}/ do |match|
				"%c" % match[2,2].to_i(16)
			end

			raise "Unknown escape sequences used in string '#{original_str}'" if str.index("\\")
			str
		end

		LOCALIZED_STRING = /NSLocalizedString\s*\(\s*@"(.*?)"\s*,\s*@"(.*?)"\s*\)/
		# TODO NSLocalizedStringFromTable et al

		def collect(i, collector)
			return unless i =~ /.m$/ or i =~ /.mm$/
			puts "Processing #{i} for strings."

			source = File.read(i)
			source.scan(LOCALIZED_STRING).each do |pair|
				key, comment = pair.map { |x| ascii_c_string_to_utf8(x) }

				# TODO different string tables!
				doc = collector['Localizable.strings']
				doc.sources.add File.basename(i)
				doc[key, create = true].update :localizations => { collector.base_locale => key}, :comments => comment
			end
		end
	
		def apply(locales, producer)
			producer.docset.each_document do |d|
				next unless d.name =~ /.strings$/
				locales.each do |locale|
					
					file = File.join(lproj(locale, producer), d.name)
					strings = self.class.make_apple_strings(d, locale)
					
					File.open(file, "w") do |io|
						io << strings
					end
					
				end
			end
		end
		
		def self.make_apple_strings(doc, locale)
			dict = OSX::NSMutableDictionary.new
			doc.keys.each do |k|
				dict[k.key] = k.localizations[locale] if k.localizations[locale]
			end
			return dict.descriptionInStringsFileFormat.to_s
		end
	end

	class NIBs
		include ILabs::Koine::Extractor
		include AppleApplier

		def collect(file, collector)
			return unless file =~ /.nib$/ or file =~ /.xib$/
			return unless file =~ /.lproj\//
			
			puts "Extracting strings via ibtool from #{file}."

			t = Tempfile.new('ibtool-strings-collect')
			sh '/usr/bin/ibtool', '--export-strings-file', t.path, file
			d = OSX::NSDictionary.dictionaryWithContentsOfFile t.path
			t.delete()

			if d
				base = File.basename(file)
				d.each do |k, v|
					doc = collector[base]
					doc.sources.add base
					doc[k.to_s, create = true].update :localizations =>
					{ collector.base_locale => v.to_s }
				end
			end

			collector.prune if File.directory? file
		end
		
		def apply(locales, producer)
			producer.docset.each_document do |d|
				next unless d.name =~ /.nib$/ or d.name =~ /.xib$/
				locales.each do |l|
					# next if l == producer.docset.base_locale
					
					strings = Strings.make_apple_strings(d, l)
					t = Tempfile.open('ibtool-strings-apply')
					t << strings
					t.close()
					
					original_nib = File.join(base_lproj(producer), d.name)
					target_nib = File.join(lproj(l, producer), d.name)
					sh '/usr/bin/ibtool', '--import-strings-file', t.path(), '--compile', target_nib.gsub(/\.xib$/, '.nib'), original_nib
					
					t.delete()
				end
			end
		end
	end

	class XcodeCollector < ILabs::Koine::Collector
		def initialize(xcode_project = nil, use_env = false)
			if use_env and not xcode_project
				xcode_project = ENV['SRCROOT']
			end
			super(xcode_project)
			
			self.add_extractor Strings
			self.add_extractor NIBs
			self.ignore_dirs << File.join(xcode_project, 'build')
			# TODO ILabs-specific stuff away
			self.ignore_dirs << File.join(xcode_project, 'Build')
			self.ignore_dirs << File.join(xcode_project, 'TemporaryItems')
		end
	end
	
	class XcodeProducer < ILabs::Koine::Producer
		def initialize(path, docset, xcode_project = nil, use_env = false)
			if use_env
				xcode_project = xcode_project || ENV['SRCROOT']
				path = path || File.join(ENV['BUILT_PRODUCTS_DIR'], ENV['UNLOCALIZED_RESOURCES_FOLDER_PATH'])
			end
			
			super(path, docset)
			
			self.sources_path = xcode_project
			self.add_applier Strings
			self.add_applier NIBs
		end
	end
end
