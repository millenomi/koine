
require 'koine/model'
require 'yaml'

module ILabs; end

module ILabs::Koine
	class Docset
		def self.from_hash h
			{'base_locale' => String, 'documents' => Array}.each do |key, cls|
				raise "#{key} not found or not of the expected type; can't create document set" unless h[key].kind_of? cls
			end
			
			me = Docset.new(h['base_locale'])
			h['documents'].each do |doch|
				me.add_document Document.from_hash(doch)
			end
			me
		end
		
		def to_hash
			{
				'base_locale' => base_locale,
				'documents' => documents.values.map {|x| x.to_hash } 
			}
		end

		def to_yaml
			to_hash.to_yaml
		end		
	end
	
	class Document
		def self.from_hash h
			{'name' => String, 'sources' => Array, 'keys' => Array}.each do |key, cls|
				raise "#{key} not found or not of the expected type; can't create document" unless h[key].kind_of? cls
			end
			
			me = self.new h['name']
			me.sources.add h['sources']
			me.keys.insert 0, *(h['keys'].map {|x| Key.from_hash(x) })
			me
		end
		
		def to_hash
			{ 'name' => name, 'sources' => sources.to_a,
			 'keys' => keys.map { |x| x.to_hash } }
		end

		def to_yaml
			to_hash.to_yaml
		end
		
		def to_localizer_hash(locale)
			h = { 'name' => name, 'keys' => [] }
			
			keys.each do |k|
				w = {}
				w['key'] = k.key
				w[locale] = k.key
				if k.comments.length > 0
					w['comments'] = k.comments.to_a.sort
				end
				h['keys'] << w
			end
			
			h
		end
	end
	
	class Key
		def self.from_hash h
			{'key' => String, 'localizations' => Hash}.each do |key, cls|
				raise "#{key} not found or not of the expected type (is #{h[key].class}, expected #{cls}); can't create key" unless h[key].kind_of? cls
			end
			
			me = self.new h['key']
			me.localizations.update h['localizations']
			unless not h['comments'] or h['comments'].kind_of? Array
				raise "'comments' not of the expected type (is #{h['comments'].class}, expected Array; can't create key" 
			end
			if h['comments']
				h['comments'].each do |comment|
					me.comments.add comment
				end
			end

			me
		end
		
		def to_hash
			{
				'key' => key, 'localizations' => localizations, 
			 	'comments' => comments.to_a.sort
			}
		end

		def to_yaml
			to_hash.to_yaml
		end
	end
end
