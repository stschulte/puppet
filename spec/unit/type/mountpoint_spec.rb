#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

mountpoint = Puppet::Type.type(:mountpoint)

describe mountpoint do

  before do
    @class = mountpoint
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

    [:name, :provider].each do |param|
      it "should have a #{param} parameter" do
        @class.attrtype(param).should == :param
      end
    end

    [:ensure, :device, :fstype, :options ].each do |param|
      it "should have a #{param} property" do
        @class.attrtype(param).should == :property
      end
    end

    it "should have options be a list property" do
      @class.attrclass(:options).ancestors.should include Puppet::Property::List
    end

  end

  describe "when validating values" do

    describe "for ensure" do
      it "should support mounted as a value for ensure" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted) }.should_not raise_error
      end

      it "should support unmounted as a value for ensure" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :unmounted) }.should_not raise_error
      end
    end

    describe "for name" do

      it "should support normal paths for name" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted) }.should_not raise_error
        proc { @class.new(:name => "/media/cdrom_foo_bar", :ensure => :mounted) }.should_not raise_error
      end

      it "should not support spaces in name" do
        proc { @class.new(:name => "/mnt/foo bar", :ensure => :mounted) }.should raise_error
        proc { @class.new(:name => "/m nt/foo", :ensure => :mounted) }.should raise_error
      end

      # ticket 6793
      it "should not support trailing spaces" do
        proc { @class.new(:name => "/mnt/foo/", :ensure => :mounted) }.should raise_error
        proc { @class.new(:name => "/mnt/foo//", :ensure => :mounted) }.should raise_error
      end

      it "should not allow relative paths" do
        proc { @class.new(:name => "mnt/foo/", :ensure => :mounted) }.should raise_error
        proc { @class.new(:name => "./foo/", :ensure => :mounted) }.should raise_error
      end

    end


    describe "for device" do

      it "should support normal /dev paths for device" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :device => '/dev/hda1') }.should_not raise_error
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :device => '/dev/dsk/c0d0s0') }.should_not raise_error
      end

      it "should support labels for device" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :device => 'LABEL=/boot') }.should_not raise_error
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :device => 'LABEL=SWAP-hda6') }.should_not raise_error
      end

      it "should support pseudo devices for device" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :device => 'ctfs') }.should_not raise_error
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :device => 'swap') }.should_not raise_error
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :device => 'sysfs') }.should_not raise_error
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :device => 'proc') }.should_not raise_error
      end

      it "should not support blanks in device" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :device => '/dev/my dev/foo') }.should raise_error
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :device => "/dev/my\tdev/foo") }.should raise_error
      end

    end

    describe "for fstype" do

      it "should support valid fstypes" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :fstype => 'ext3') }.should_not raise_error
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :fstype => 'proc') }.should_not raise_error
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :fstype => 'sysfs') }.should_not raise_error
      end

      it "should support auto as a special fstype" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :fstype => 'auto') }.should_not raise_error
      end

      it "should not support blanks in fstype" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :fstype => 'ext 3') }.should raise_error
      end

    end

    describe "for options" do

      it "should support a single option" do
         proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :options => 'ro') }.should_not raise_error
      end

      it "should support muliple options as an array" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :options => ['ro','rsize=4096']) }.should_not raise_error
      end

      it "should support an empty array as options" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :options => []) }.should_not raise_error
      end

      it "should not support a comma separated option" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :options => ['ro','foo,bar','intr']) }.should raise_error
      end

      it "should not support blanks in options" do
        proc { @class.new(:name => "/mnt/foo", :ensure => :mounted, :options => ['ro','foo bar','intr']) }.should raise_error
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
