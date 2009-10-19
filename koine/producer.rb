module ILabs; end

module ILabs::Koine
	class Producer
		attr_accessor :sources_path
		attr_reader :path, :docset, :appliers
		def initialize(path, docset)
			@path = path
			@docset = docset
			@appliers = []
		end
		
		def run
			locs = self.docset.locales
			appliers.each do |applier|
				applier.apply locs, self
			end
		end
		
		def add_applier classy
			appliers << classy.new
		end
	end
	
	module Applier
		def apply(docset, locales, producer)
		end
	end
end
