require 'puppet/property/list'
module Puppet
  newtype(:mountpoint) do
    @doc = "Manages mounted filesystems, but does not create any information
      in the fstab.  You have to use the mounttab type for that.  The type is
      currently not able to manage mount options.  So if you want to have non-
      default mountoptions  make sure you also use the mounttab type to create
      an fstab entry first.

      Note that if a `mountpoint` receives an event from another resource,
      it will try to remount the filesystems if it is currently mounted.  Depending
      on the operating system, the provider and the value of the remount parameter
      this can be a simple mount -o remount or mount/remount."

    feature :refreshable, "The provider can remount the filesystem.",
      :methods => [:remount]

    newproperty(:ensure) do
      desc "Control wether the mountpoint should be mounted or not. You can
        use `mounted` to mount the device or `unmounted` to make sure that
        no device is mounted on the specified mountpoint"

      newvalue :mounted
      newvalue :unmounted

    end

    newproperty(:device) do
      desc "The device providing the mount.  This can be whatever
        device is supporting by the mount, including network
        devices or devices specified by UUID rather than device
        path, depending on the operating system.  If you already have an entry
        in your fstab (or you use the mounttab type to create such an entry),
        it is generally not necessary to specify the fstype explicitly"

      validate do |value|
        raise Puppet::Error, "device is not allowed to contain whitespaces" if value =~ /\s/
      end
      
    end

    newproperty(:fstype) do
      desc "The mount type.  Valid values depend on the
        operating system.  If you already have an entry in your fstab (or you use
        the mounttab type to create such an entry), it is generally not necessary to
        specify the fstype explicitly"

      validate do |value|
        raise Puppet::Error, "fstype is not allowed to contain whitespaces" if value =~ /\s/
      end

    end

    newproperty(:options, :parent => Puppet::Property::List) do
      desc "Mount options for the mount. This property is currently just used
        when mounting the device. It is always treated insync so if the
        desired device is already mounted but mounted with wrong options,
        puppet will not correct it. This limitation is there because options
        reported by the mount command are often different from the options
        you may find in fstab"

      def insync?(is = nil)
        true
      end

      def delimiter
        ","
      end

      def inclusive?
        true
      end

      validate do |value|
        raise Puppet::Error, "multiple options have to be specified as an array not a comma separated list" if value =~ /,/
        raise Puppet::Error, "options are not allowed to contain whitespaces" if value =~ /\s/
      end

    end

    newparam(:name) do
      desc "The mount path for the mount."

      isnamevar
    end

    newparam(:remounts) do
      desc "Whether the mount can be remounted with `mount -o remount`.  If
        this is false, then the filesystem will be unmounted and remounted
        manually, which is prone to failure."

      newvalues(:true, :false)
      defaultto do
        case Facter.value(:operatingsystem)
        # Solaris -o remount only changes options from ro to rw, so mostly useless
        when "FreeBSD", "Darwin", "AIX", "Solaris"
          false
        else
          true
        end
      end
    end

    def refresh
      # Only remount if we're supposed to be mounted.
      provider.remount if provider.get(:fstype) != "swap" and provider.get(:ensure) == :mounted
    end

  end
end
