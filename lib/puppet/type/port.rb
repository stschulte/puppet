require 'puppet/property/ordered_list'
require 'puppet/provider/parsedfile'

module Puppet
  newtype(:port) do
    @doc = "Installs and manages port entries. For most systems, these
      entries will just be in `/etc/services`, but some systems (notably OS X)
      will have different solutions.

      This type uses a composite key of (port) `name` and (port) `number` to
      identify a resource. You are able to set both keys with the resource
      title if you seperate them with a slash. So instead of specifying protocol
      explicitly:

          port { \"telnet\":
            protocol => tcp,
            number   => 23,
          }

      you can also specify both name and protocol implicitly through the title:

          port { \"telnet/tcp\":
            number => 23,
          }

      The second way is the prefered way if you want to specifiy a port that
      uses both tcp and udp as a protocol. You need to define two resources
      for such a port but the resource title still has to be unique.

      Example: To make sure you have the telnet port in your `/etc/services`
      file you will now write:

          port { \"telnet/tcp\":
            number => 23,
          }
          port { \"telnet/udp\":
            number => 23,
          }

      Currently only tcp and udp are supported and recognised when setting
      the protocol via the title."

    def self.namevar_join(hash)
      "#{hash[:name]}/#{hash[:protocol]}"
    end

    def self.title_patterns
      [
        # we have two title_patterns "name" and "name:protocol". We won't use
        # one pattern (that will eventually set :protocol to nil) because we
        # want to use a default value for :protocol. And that does only work
        # when :protocol is not put in the parameter hash while initialising
        [
          /^(.*)\/(tcp|udp)$/, # Set name and protocol
          [
            # We don't need a lot of post-parsing
            [ :name, lambda{|x| x} ],
            [ :protocol, lambda{ |x| x.intern } ]
          ]
        ],
        [
          /^(.*)$/,
          [
            [ :name, lambda{|x| x} ]
          ]
        ]
      ]
    end

    ensurable

    newparam(:name) do
      desc "The port name."

      validate do |value|
        raise Puppet::Error, "Port name must not contain whitespace: #{value}" if value =~ /\s/
      end

      isnamevar
    end

    newparam(:protocol) do
      desc "The protocol the port uses. Valid values are *udp* and *tcp*.
        Most services have both protocols, but not all. If you want both
        protocols you have to define two resources. Remeber that you cannot
        specify two resources with the same title but you can use a title
        to set name and protocol at the same time (an example can be found
        in the documentation of the port resource itself)."

      newvalues :tcp, :udp

      defaultto :tcp

      isnamevar
    end


    newproperty(:number) do
      desc "The port number."

      validate do |value|
        raise Puppet::Error, "number has to be numeric, not #{value}" unless value =~ /^-?[0-9]+$/
        raise Puppet::Error, "number #{value} out of range (0-65535)" unless (0...2**16).include?(Integer(value))
      end

    end

    newproperty(:description) do
      desc "The description for the port. The description will appear"
        "as a comment in the `/etc/services` file"
    end

    newproperty(:port_aliases, :parent => Puppet::Property::OrderedList) do
      desc "Any aliases the port might have. Multiple values must be
        specified as an array."

      def inclusive?
        true
      end

      def delimiter
        " "
      end

      validate do |value|
        raise Puppet::Error, "Aliases must not contain whitespace: #{value}" if value =~ /\s/
      end
    end


    newproperty(:target) do
      desc "The file in which to store service information. Only used by
        those providers that write to disk."

      defaultto do
        if @resource.class.defaultprovider.ancestors.include?(Puppet::Provider::ParsedFile)
          @resource.class.defaultprovider.default_target
        else
          nil
        end
      end
    end

    validate do
      unless @parameters[:name] and @parameters[:protocol]
        raise Puppet::Error, "Attributes 'name' and 'protocol' are mandatory"
      end
    end

  end
end
