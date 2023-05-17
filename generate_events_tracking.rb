#!/usr/bin/ruby 

require 'YAML'

class ParsedEvent
	def initialize(description, properties)
		@event_name = parse_event_name(description)
		@dto_name = parse_dto_name(properties)
		@enum_case = parse_enum_case(@event_name)
	end

	def parse_enum_case(description)
		to_snake_case(description)
	end

	def to_snake_case(text)
		text.gsub(':', '_').gsub('.', '_').gsub(' ', '_').downcase
	end

	def parse_event_name(description)
		regexp = /^Event (.+)$/
		regexp_result = description.match(regexp)
    	if regexp_result
        	return regexp_result.captures.first
        end
		return description
	end

	def parse_dto_name(properties)
		if properties
			to_snake_case(@event_name).split('_').map { |e| e.capitalize  }.join('')
		else 
			return nil
		end
	end

	def detailed
		if @dto_name
			"Event #{@event_name} with dto named #{@dto_name}"
		else 
			"Event #{@event_name} without properties"
		end
	end

	def generate_enum_entrance
		if @dto_name 
	 	    "case #{@enum_case}(#{@dto_name})"
		else 
		    "case #{@enum_case}"
		end
	end

	def generate_coding_key
		"case #{@enum_case} = \"#{@event_name}\""
	end

	def generate_event_name_entry
		"case .#{@enum_case}:
            return \"#{@event_name}\""
	end

	def has_custom_key	
		if @dto_name 
			true
		else 
			false
		end
	end

	def has_custom_key_entry
		if @dto_name 
			"case .#{@enum_case}:
            return true"
		else 
			"case .#{@enum_case}:
            return false"
		end
	end

	def encode_entry
		if @dto_name
			"case .#{@enum_case}(let dto):
            try? dto.encode(to: encoder)"
		end
	end

	def decoding_entry
		if @dto_name
		"else if eventName == \"#{@event_name}\" {
            let value = try container.decode(#{@dto_name}.self, forKey: .customProperties)
            event = .#{@enum_case}(value)
        } " 
		else
 		"else if eventName == \"#{@event_name}\" {
            event = .#{@enum_case}
        } "
		end
	end
end

def is_event(dict)
	d = dict['description']
	if d
		d.include? 'Event '
	else 
		false
	end
end

def events_from_yaml(file) 
	yaml = YAML.load_file(file)
	schemas = yaml['components']['schemas']
	events = schemas.map { |e| e.last  }.filter{ |d| is_event(d) }.map { |e| ParsedEvent.new(e['description'], e['properties']) }
end


def generate_enum(filepath, events, enum_name)
	puts "Generating enum for #{events.count} events"

	File.open(filepath, 'w') { |file| file.write("//
//  #{enum_name}.swift
//  Uklon
//
//  Created by Dmytro Kovryhin on 26.10.2022.
//  Copyright © 2022 Uklon. All rights reserved.
//

import Foundation

public enum #{enum_name}: Encodable {") 

	events.each { |event|
		
		file.write('''
	''' + event.generate_enum_entrance)
	}

	file.write('''
	    
	public enum CodingKeys: String, CodingKey {
        ''')
	events.each { |event|
		file.write('''
		''' + event.generate_coding_key)
	}
	file.write('''
	}

	public var eventName: String {
        switch self {''')

    events.each { |event|
		file.write('''
		''' + event.generate_event_name_entry)
	}
	file.write('''
        }
    }

    public var hasCustomProperties: Bool {
        switch self {''')

    events.each { |event|
		file.write('''
		''' + event.has_custom_key_entry)
	}

    file.write('''	
		}	
    }

    public func encode(to encoder: Encoder) throws {
        switch self {''')

	events.filter { |e| e.has_custom_key }.each { |event|
		file.write('''
		''' + event.encode_entry)
	}

	file.write('''
		default:
			()
        }
    }
}''')
}
end

def generate_analytics_events(filepath, events)
	File.open(filepath, 'w') { |file|
		file.write("//
//  #{filepath}
//  Uklon2018
//
//  Created by Dmytro Kovryhin on 26.10.2022.
//  Copyright © 2022 Uklon. All rights reserved.
//

import Foundation

")
		file.write('''

public struct AnalyticsEvent: Codable {
	public enum DecodingError: Error {
        case wrongJSON
    }

    public enum CodingKeys: String, CodingKey {
        case eventName = "event_type"
        case timestamp = "event_timestamp"
        case customProperties = "custom_properties"
    }
    
    public let timestamp: TimeInterval
    let event: Events
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(event.eventName, forKey: .eventName)
        if event.hasCustomProperties {
            try? container.encode(event, forKey: .customProperties)
        }
        try? container.encode(timestamp, forKey: .timestamp)
    }
    
    public init(timestamp: TimeInterval,
                event: Events) {
        self.timestamp = timestamp
        self.event = event
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let eventName = try container.decode(String.self, forKey: .eventName)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
    	''')

    decoding_string = events.map { |e| e.decoding_entry }.join('')
	decoding_string = decoding_string[5..-1]
	file.write(decoding_string)
	
	

	file.write('''else {
            throw DecodingError.wrongJSON
        }
    }
}''')
	}
end

def clean_empty_properties
	puts 'removing unnecessary files..'
	Dir.glob("src/*.swift").each { |filename|
		if !File.open(filename).each_line.any?{|line| line.include?('public var') || line.include?('enum')}
  			File.delete(filename)
		end
	}
end

def generate_properties_dtos
	system './generate_events_dtos.sh'
end

generate_properties_dtos
clean_empty_properties

events = events_from_yaml('events.yaml')
generate_enum('src/Events.swift', events, 'Events')
generate_analytics_events('src/AnalyticsEvent.swift', events)
system 'mv src Demo.playground/Sources'
system 'open Demo.playground'
