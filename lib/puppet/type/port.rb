module Puppet
  newtype(:port) do
    @doc = "Installs and manages port entries. For most systems, these
      entries will just be in /etc/services, but some systems (notably OS X)
      will have different solutions."

    def self.title_patterns
      [
        # we just have one titlepattern "name:protocol"
        [
          /^(.*?)(?::(tcp|udp))?$/, # Regex to parse title
          [
            [ :name, lambda{|x| x} ],
            [ :protocol, lambda{ |x| :tcp } ], # TEST
          ]
        ]
      ]
    end

    ensurable

    newparam(:protocol) do
      desc "The protocols the port uses. Valid values are *udp* and *tcp*.
        Most services have both protocols, but not all. If you want both
        protocols you have to define two resources. You can define both
        resources with the same title as long as the combination of
        resourcetitle and protocol is uniq. Keep in mind that if another
        resource requires Port['title'] it requires both resources"

      newvalues :tcp, :udp

      defaultto :tcp

      isnamevar
    end


    newproperty(:number) do
      desc "The port number."

      validate do |value|
        raise Puppet::Error, "number has to be numeric, not #{value}" unless value =~ /^[0-9]+/
        raise Puppet::Error, "number #{value} out of range" unless (0...2**16).include?(Integer(value))
      end
    end

    newproperty(:description) do
      desc "The port description."
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
        raise Puppet::Error, "Aliases cannot have whitespaces in them" if value =~ /\s/
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

    newparam(:name) do
      desc "The port name."

      validate do |value|
        raise Puppet::Error "Portname cannot have whitespaces in them" if value =~ /\s/
      end

      isnamevar
    end
  end
end

