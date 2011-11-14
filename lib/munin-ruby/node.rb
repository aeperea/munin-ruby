require 'digest/md5'

module Munin
  class Node
    include Munin::Parser
    include Munin::Cache
    
    attr_reader :connection
    
    # Initialize a new Node instance
    #
    # host      - Server host
    # port      - Server port
    # reconnect - Reconnect if connection was closed (default: true)
    #
    
    def initialize(host='127.0.0.1', port=4949, reconnect=true)
      @connection = Munin::Connection.new(host, port, reconnect)
    end
    
    # Open service connection
    #
    def connect
      connection.open
    end
    
    # Close server connection
    #
    def disconnect(reconnect=true)
      connection.close(reconnect)
    end
    
    # Get a node version
    #
    def version
      cache 'version' do
        connection.send_data("version")
        str = connection.read_line
        if str =~  /^munins node on/
          str.split.last
        else
          raise InvalidResponse
        end
      end
    end
    
    # Get a list of all available metrics
    #
    def list
      cache 'list' do
        connection.send_data("list")
        connection.read_line.split
      end
    end
    
    # Get a configuration information for service
    #
    # services - Name of the service, or list of service names
    #
    def config(services)
      unless [String, Array].include?(services.class)
        raise ArgumentError, "Service(s) argument required"
      end
      
      return_single = services.kind_of?(String)
      results       = []
      names         = [services].flatten.uniq
      
      if names.empty?
        raise ArgumentError, "Service(s) argument required"
      end
      
      key = 'config_' + Digest::MD5.hexdigest(names.to_s)
      
      cache(key) do
        names.each do |service|
          begin
            connection.send_data("config #{service}")
            lines = connection.read_packet
            results << parse_config(lines)
          rescue UnknownService, BadExit
            # TODO
          end
        end
        return_single && results.size == 1 ? results.first : results
      end
    end
    
    # Get all service metrics values
    #
    # services - Name of the service, or list of service names
    #
    def fetch(services)
      return_single = services.kind_of?(String)
      results = []
      names = [services].flatten
      names.each do |service|
        begin
          connection.send_data("fetch #{service}")
          lines = connection.read_packet
          results << parse_fetch(lines)
        rescue UnknownService, BadExit
          # TODO
        end
      end
      return_single && results.size == 1 ? results.first : results
    end
  end
end