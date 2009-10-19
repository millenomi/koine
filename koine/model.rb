require 'set'

module ILabs; end

module ILabs::Koine

	class Docset
		attr_reader :base_locale, :documents
		def initialize(base_locale)
			@base_locale = base_locale
			@documents = {}
		end
		
		def find_or_create_document(name)
			x = documents[name]
			x = documents[name] = Document.new(name) unless x
			x
		end

		def [](name, create = false)
			if create
				find_or_create_document(name)
			else
				documents[name]
			end
		end
		
		def add_document(d)
			documents[d.name] = d
			self
		end
		
		def locales
			s = Set.new
			documents.each do |name, doc|
				s.merge doc.locales
			end
			s
		end
		
		def each_document
			documents.each_value do |doc|
				yield doc
			end
		end
		
	end

	class Document
		attr_reader :name, :sources, :keys
		def initialize(name)
			@name = name
			@keys = []
			@sources = Set.new
		end
		
		def find_key(name)
			keys.each do |k|
				return k if k.key == name 
			end
			nil
		end

		def find_or_create_key(name)
			k = find_key(name)
			return k if k

			k = Key.new(name)
			keys << k
			return k
		end

		def [](name, create = false)
			if create
				find_or_create_key(name)
			else
				find_key(name)
			end
		end
		
		def locales
			s = Set.new
			keys.each do |key|
				s.merge key.localizations.keys
			end
			s
		end
	end

	class Key
		attr_reader :key, :localizations, :comments
		def initialize(key)
			@key = key
			@localizations = {}
			@comments = Set.new
		end

		def <=>(other)
			self.key <=> other.key
		end

		def update?(hash)
			changed = false

			if hash[:localizations] and hash[:localizations].length > 0
				localizations.update(hash[:localizations])
				changed = true
			end

			if hash[:comments] and hash[:comments].length > 0
				hash[:comments].each do |x|
					changed == true if comments.add? x
				end		
			end

			return changed
		end

		def update(hash)
			update?(hash); return nil
		end
	end

end
