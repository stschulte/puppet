#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:mountpoint) do

  before do
    @class = described_class
    @provider_class = @class.provide(:fake) { mk_resource_methods }
    @provider = @provider_class.new
    @resource = stub 'resource', :resource => nil, :provider => @provider

    @class.stubs(:defaultprovider).returns @provider_class
    @class.any_instance.stubs(:provider).returns @provider
  end

  it "should have :name as its keyattribute" do
    @class.key_attributes.should == [:name]
  end

  describe "when validating attributes" do

    [:name, :provider, :remounts].each do |param|
      it "should have a #{param} parameter" do
        @class.attrtype(param).should == :param
      end
    end

    [:ensure, :device, :fstype, :options ].each do |property|
      it "should have a #{property} property" do
        @class.attrtype(property).should == :property
      end
    end

  end

  describe "when validating values" do

    describe "for name" do

      it "should support absolute paths" do
        proc { @class.new(:name => "/foo", :ensure => :mounted) }.should_not raise_error
      end

      it "should support root /" do
        proc { @class.new(:name => "/", :ensure => :mounted) }.should_not raise_error
      end

      it "should not support whitespace" do
        proc { @class.new(:name => "/foo bar", :ensure => :mounted) }.should raise_error(Puppet::Error, /name.*whitespace/)
      end

      it "should not allow trailing slashes" do
        proc { @class.new(:name => "/foo/", :ensure => :mounted) }.should raise_error(Puppet::Error, /mount should be specified without a trailing slash/)
        proc { @class.new(:name => "/foo//", :ensure => :mounted) }.should raise_error(Puppet::Error, /mount should be specified without a trailing slash/)
      end

    end


    describe "for ensure" do

      it "should support mounted as a value for ensure" do
        proc { @class.new(:name => "/foo", :ensure => :mounted) }.should_not raise_error
      end

      it "should support unmounted as a value for ensure" do
        proc { @class.new(:name => "/foo", :ensure => :unmounted) }.should_not raise_error
      end

    end

    describe "for device" do

      it "should support normal /dev paths for device" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :device => '/dev/hda1') }.should_not raise_error
        proc { @class.new(:name => "/foo", :ensure => :mounted, :device => '/dev/dsk/c0d0s0') }.should_not raise_error
      end

      it "should support labels for device" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :device => 'LABEL=/boot') }.should_not raise_error
        proc { @class.new(:name => "/foo", :ensure => :mounted, :device => 'LABEL=SWAP-hda6') }.should_not raise_error
      end

      it "should support pseudo devices for device" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :device => 'ctfs') }.should_not raise_error
        proc { @class.new(:name => "/foo", :ensure => :mounted, :device => 'swap') }.should_not raise_error
        proc { @class.new(:name => "/foo", :ensure => :mounted, :device => 'sysfs') }.should_not raise_error
        proc { @class.new(:name => "/foo", :ensure => :mounted, :device => 'proc') }.should_not raise_error
      end

      it "should not support whitespace in device" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :device => '/dev/my dev/foo') }.should raise_error Puppet::Error, /device.*whitespace/
        proc { @class.new(:name => "/foo", :ensure => :mounted, :device => "/dev/my\tdev/foo") }.should raise_error Puppet::Error, /device.*whitespace/
      end

    end

    describe "for fstype" do

      it "should support valid fstypes" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :fstype => 'ext3') }.should_not raise_error
        proc { @class.new(:name => "/foo", :ensure => :mounted, :fstype => 'proc') }.should_not raise_error
        proc { @class.new(:name => "/foo", :ensure => :mounted, :fstype => 'sysfs') }.should_not raise_error
      end

      it "should support auto as a special fstype" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :fstype => 'auto') }.should_not raise_error
      end

      it "should not support whitespace in fstype" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :fstype => 'ext 3') }.should raise_error Puppet::Error, /fstype.*whitespace/
      end

    end

    describe "for options" do

      it "should support a single option" do
         proc { @class.new(:name => "/foo", :ensure => :mounted, :options => 'ro') }.should_not raise_error
      end

      it "should support muliple options as an array" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :options => ['ro','rsize=4096']) }.should_not raise_error
      end

      it "should support an empty array as options" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :options => []) }.should_not raise_error
      end

      it "should not support a comma separated option" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :options => ['ro','foo,bar','intr']) }.should raise_error Puppet::Error, /option.*have to be specified as an array/
      end

      it "should not support blanks in options" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :options => ['ro','foo bar','intr']) }.should raise_error Puppet::Error, /option.*whitespace/
      end

    end

    describe "for remounts" do

      it "should support true as a value for remounts" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :remounts => :true) }.should_not raise_error
      end

      it "should support false as value for remounts" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :remounts => :true) }.should_not raise_error
      end

      it "should not support anything else as a value" do
        proc { @class.new(:name => "/foo", :ensure => :mounted, :remounts => :truu) }.should raise_error Puppet::Error, /remounts failed.*Invalid value/
      end

      ["FreeBSD", "Darwin","AIX"].each do |os|
        describe "when on #{os}" do

          it "should always default to false" do
            Facter.stubs(:value).with(:operatingsystem).returns os
            @class.new(:name => "/mnt/foo", :fstype => 'ext3', :ensure => :mounted)[:remounts].should == :false
            @class.new(:name => "/mnt/foo", :fstype => 'nfs', :ensure => :mounted)[:remounts].should == :false
          end

        end
      end

      ["Solaris", "HP-UX"].each do |os|
        describe "when on #{os}" do

          before :each do
            Facter.stubs(:value).with(:operatingsystem).returns os
          end

          it "should default to false for nfs mounts" do
            @class.new(:name => "/mnt/foo", :fstype => 'nfs', :ensure => :mounted)[:remounts].should == :false
          end

          it "should default to true for other fstypes" do
            @class.new(:name => "/mnt/foo", :fstype => 'ext3', :ensure => :mounted)[:remounts].should == :true
          end

        end
      end

      ["Linux"].each do |os|
        describe "when on #{os}" do
          it "should alway default to true" do
            Facter.stubs(:value).with(:operatingsystem).returns os
            @class.new(:name => "/mnt/foo", :fstype => 'ext3', :ensure => :mounted)[:remounts].should == :true
            @class.new(:name => "/mnt/foo", :fstype => 'nfs', :ensure => :mounted)[:remounts].should == :true
          end
        end
      end

    end

  end

  describe "when syncing options" do

    before :each do
      @options = @class.attrclass(:options).new(:resource => @resource, :should => %w{rw rsize=2048 wsize=2048})
    end

    it "should pass the sorted joined array to the provider" do
      @provider.expects(:options=).with('rsize=2048,rw,wsize=2048')
      @options.sync
    end

    # Good look fixing this one ;-) -- stefan
    it "should always treat options insync" do
      @options.insync?(%w{rw rsize=2048}).should == true
      @options.insync?(%w{rw rsize=2048 wsize=2048 intr}).should == true
      @options.insync?(%w{rw rsize=1024 wsize=2048}).should == true
      @options.insync?(%w{foo}).should == true
    end

  end

end
