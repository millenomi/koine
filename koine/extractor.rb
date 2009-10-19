module ILabs; end

module ILabs::Koine
	module Extractor
		def will_begin(collector)
		end

		def collect(file, collector)
		end

		def did_end(collector)
		end

		def output_of_sh(*args)
			w = nil
			IO.popen('-') do |io|
				exec(*args) unless io
				
				if io
					if block_given?
						yield io
					else
						w = io.read
					end
				end
			end

			return w
		end
		
		def sh(*args)
			fork do
				exec *args
			end
			Process.wait
		end
	end
end
