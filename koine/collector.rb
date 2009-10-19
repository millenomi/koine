
require 'find'
require 'koine/model'

module ILabs; end

module ILabs::Koine
	
	class Collector
		attr_reader :extractors, :docset, :base_locale, :ignore_dirs, :path
		def initialize(path)
			@path = path
			@extractors = []
			@documents = {}
			@base_locale = 'en'
			@ignore_dirs = []
		end

		def run
			if not @docset
				@docset = Docset.new(base_locale)
			end
			
			extractors.each { |x| x.will_begin self }
			Find.find(@path) do |file|
				if ignore_dirs.include? file
					Find.prune
					next
				end

				next if File.directory? file

				puts "Considering #{file}..."
				extractors.each { |x| x.collect file, self }
			end

			extractors.each { |x| x.did_end self }
			nil
		end

		def prune
			Find.prune
		end

		def document(name)
			docset.find_or_create_document(name)
		end

		def [](name)
			document(name)
		end

		def add_extractor(classy)
			extractors << classy.new
		end
	end
	
end
