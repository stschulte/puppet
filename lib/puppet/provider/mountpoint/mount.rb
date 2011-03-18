Puppet::Type.type(:mountpoint).provide(:mount) do

  commands :mount  => '/bin/mount'
  commands :umount => '/bin/umount'

  self::REGEX = case Facter.value(:operatingsystem)
    when "Darwin"
      /^(.*?) on (?:\/private\/var\/automount)?(\S*) \(([A-Za-z]*),?([^\)]*)\)$/
    when "Solaris", "HP-UX"
      /^(\S*) on (\S*) (\S*)/
    else
      /^(\S*) on (\S*) type (\S*) \((.*)\)$/
  end
  self::FIELDS = case Facter.value(:operatingsystem)
    when "Darwin"
      [:device, :name, :fstype, :options]
    when "Solaris"
      [:name, :device, :options]
    when "HP-UX"
      [:name]
    else
      [:device,:name,:fstype,:options]
  end

  def self.parse_line(line)
    if match = self::REGEX.match(line)
      hash = {}
      self::FIELDS.zip(match.captures) do |field,value|
        if field == :options
          value.gsub!(/,\s*/,',')  # Darwin adds spaces between options
          value.gsub!(/\//,',')    # Solaris uses / as delimiter
        end
        hash[field] = value
        hash[:ensure] = :mounted
        Puppet.debug hash.inspect
      end
      hash
    else
      Puppet.warning "Failed to match mount line #{line}"
      nil
    end
  end

  def self.instances
    mountpoints = []
    mount.split("\n").each do |line|
      if mountpoint = parse_line(line)
        mountpoints << new(mountpoint)
      end
    end
    mountpoints
  end

  def self.prefetch(mountpoints)
    instances.each do |prov|
      if mountpoint = mountpoints[prov.name]
        mountpoint.provider = prov
      end
    end
  end

  def perform_mount
    args = []
    args << resource[:device] if resource[:device]
    case Facter.value(:operatingsystem)
    when 'HP-UX', 'Solaris'
      args << '-F' << resource[:fstype] if resource[:fstype]
    else
      args << '-t' << resource[:fstype] if resource[:fstype]
    end
    args << '-o' << resource[:options] if resource[:options]
    args << resource[:name]
    mount *args
  end

  def perform_remount
    options = "remount"
    options += ",#{resource[:options]}" if resource[:options]
    args = []
    args << '-o' << options
    args << resource[:name]
    mount *args
  end

  def perform_umount
    umount resource[:name]
  end

  remount_sufficient = [:options]
  [:device, :fstype, :options].each do |property|
    define_method(property) do
      @property_hash[property] || :absent
    end
    define_method("#{property}=") do |val|
      @property_hash[property] = val
      if remount_sufficient.include?(property)
        @flush_need_remount = true
      else
        @flush_need_umount_mount = true
      end
    end
  end

  def remount(tryremount = true)
    info "Remounting"
    if resource[:remounts] == :true and tryremount
      perform_remount
    else
      perform_umount
      perform_mount
    end
  end

  def ensure
    @property_hash[:ensure] || :unmounted
  end

  def ensure=(value)
    if value == :mounted
      perform_mount
    else
      perform_umount
    end
    @property_hash[:ensure] == value
  end

  def flush
    if @flush_need_umount_mount
      remount(false)
    elsif @flush_need_remount
      remount(true)
    end
  end

end
