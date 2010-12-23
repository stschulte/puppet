#!/usr/bin/env ruby

require 'spec_helper'
require 'puppet/property/ordered_list'

port = Puppet::Type.type(:port)

describe port do
  before do
    @class = port
    @provider_class = stub 'provider_class', :name => 'fake', :ancestors => [], :suitable? => true, :supports_parameter? => true
    @class.stubs(:defaultprovider).returns @provider_class
    @class.stubs(:provider).returns @provider_class

    @provider = stub 'provider', :class => @provider_class, :clean => nil, :exists? => false
    @resource = stub 'resource', :resource => nil, :provider => @provider

    @provider.stubs(:port_aliases).returns :absent

    @provider_class.stubs(:new).returns(@provider)
    @catalog = Puppet::Resource::Catalog.new
  end

  it "should have a title pattern that splits name and protocol" do
    regex = @class.title_patterns[0][0]
    regex.match("telnet/tcp").captures.should == ['telnet','tcp' ]
    regex.match("telnet/udp").captures.should == ['telnet','udp' ]
    regex.match("telnet/baz").should == nil
  end

  it "should have a second title pattern that will set only name" do
    regex = @class.title_patterns[1][0]
    regex.match("telnet/tcp").captures.should == ['telnet/tcp' ]
    regex.match("telnet/udp").captures.should == ['telnet/udp' ]
    regex.match("telnet/baz").captures.should == ['telnet/baz' ]
  end

  it "should have :name as a key_attribute" do
    @class.key_attributes.should == [:name, :protocol]
  end

  describe "when validating attributes" do

    [:name, :provider, :protocol].each do |param|
      it "should have a #{param} parameter" do
        @class.attrtype(param).should == :param
      end
    end

    [:ensure, :port_aliases, :description, :number].each do |property|
      it "should have #{property} property" do
        @class.attrtype(property).should == :property
      end
    end

  end

  describe "when validating values" do

    it "should support present as a value for ensure" do
      lambda { @class.new(:name => "whev", :protocol => :tcp, :ensure => :present) }.should_not raise_error
    end

    it "should support absent as a value for ensure" do
      proc { @class.new(:name => "whev", :protocol => :tcp, :ensure => :absent) }.should_not raise_error
    end

    it "should support :tcp  as a value for protocol" do
      proc { @class.new(:name => "whev", :protocol => :tcp) }.should_not raise_error
    end

    it "should support :udp  as a value for protocol" do
      proc { @class.new(:name => "whev", :protocol => :udp) }.should_not raise_error
    end

    it "should not support other protocols than tcp and udp" do
      proc { @class.new(:name => "whev", :protocol => :tcpp) }.should raise_error(Puppet::Error, /Invalid value/)
    end

    it "should use tcp as default protocol" do
      port_test = @class.new(:name => "whev")
      port_test[:protocol].should == :tcp
    end

    it "should support valid portnumbers" do
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => '0') }.should_not raise_error
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => '1') }.should_not raise_error
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => "#{2**16-1}") }.should_not raise_error
    end

    it "should not support portnumbers that arent numeric" do
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => "aa") }.should raise_error(Puppet::Error, /has to be numeric/)
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => "22a") }.should raise_error(Puppet::Error, /has to be numeric/)
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => "a22") }.should raise_error(Puppet::Error, /has to be numeric/)
    end

    it "should not support portnumbers that are out of range" do
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => "-1") }.should raise_error(Puppet::Error, /number .* out of range/)
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => "#{2**16}") }.should raise_error(Puppet::Error, /number .* out of range/)
    end

    it "should support single port_alias" do
      proc { @class.new(:name => "foo", :protocol => :tcp, :port_aliases => 'bar') }.should_not raise_error
    end

    it "should support multiple port_aliases" do
      proc { @class.new(:name => "foo", :protocol => :tcp, :port_aliases => ['bar','bar2']) }.should_not raise_error
    end

    it "should not support whitespaces in any port_alias" do
      proc { @class.new(:name => "whev", :protocol => :tcp, :port_aliases => ['bar','fo o']) }.should raise_error(Puppet::Error, /must not contain whitespace/)
    end

    it "should not support whitespaces in resourcename" do
      proc { @class.new(:name => "foo bar", :protocol => :tcp) }.should raise_error(Puppet::Error, /must not contain whitespace/)
    end

    it "should not allow a resource with no name" do
      # puppet catches a missing name before our validate method can complain about it
      # proc { @class.new(:protocol => :tcp) }.should raise_error(Puppet::Error, /Attribute.*name.*mandatory/)

      proc { @class.new(:protocol => :tcp) }.should raise_error(Puppet::Error, /Title or name must be provided/)
    end

    it "should allow a resource with no protocol when the default is tcp" do
      proc { @class.new(:name => "foo") }.should_not raise_error(Puppet::Error)
    end

    it "should not allow a resource with no protocol when we have no default" do
      @class.attrclass(:protocol).stubs(:method_defined?).with(:default).returns(false)
      proc { @class.new(:name => "foo") }.should raise_error(Puppet::Error, /Attribute.*protocol.*mandatory/)
    end

    it "should extract name and protocol from title if not explicitly set" do
      res = @class.new(:title => 'telnet/tcp', :number => '23')
      res[:number].should == '23'
      res[:name].should == 'telnet'
      res[:protocol].should == :tcp
    end

    it "should not extract name from title if explicitly set" do
      res = @class.new(:title => 'telnet/tcp', :name => 'ssh', :number => '23')
      res[:number].should == '23'
      res[:name].should == 'ssh'
      res[:protocol].should == :tcp
    end

    it "should not extract protocol from title if explicitly set" do
      res = @class.new(:title => 'telnet/tcp', :protocol => :udp, :number => '23')
      res[:number].should == '23'
      res[:name].should == 'telnet'
      res[:protocol].should == :udp
    end

    it "should not extract name and protocol from title when they are explicitly set" do
      res = @class.new(:title => 'foo/udp', :name => 'bar', :protocol => :tcp, :number => '23')
      res[:number].should == '23'
      res[:name].should == 'bar'
      res[:protocol].should == :tcp
    end

  end

  describe "when syncing" do

    it "should send the joined array to the provider for port_aliases property" do
      port_aliases = @class.attrclass(:port_aliases).new(:resource => @resource, :should => %w{foo bar})
      @provider.expects(:port_aliases=).with 'foo bar'
      port_aliases.sync
    end

    it "should care about the order of port_aliases" do
      port_aliases = @class.attrclass(:port_aliases).new(:resource => @resource, :should => %w{a z b})
      port_aliases.insync?(%w{a z b}).should == true
      port_aliases.insync?(%w{a b z}).should == false
      port_aliases.insync?(%w{b a z}).should == false
      port_aliases.insync?(%w{z a b}).should == false
      port_aliases.insync?(%w{z b a}).should == false
      port_aliases.insync?(%w{b z a}).should == false
    end

  end

  describe "when comparing uniqueness_key of two ports" do

    it "should be equal if name and protocol are the same" do
      foo_tcp1 =  @class.new(:name => "foo", :protocol => :tcp, :number => '23')
      foo_tcp2 =  @class.new(:name => "foo", :protocol => :tcp, :number => '23')
      foo_tcp1.uniqueness_key.should == ['foo', :tcp ]
      foo_tcp2.uniqueness_key.should == ['foo', :tcp ]
      foo_tcp1.uniqueness_key.should == foo_tcp2.uniqueness_key
    end

    it "should not be equal if protocol differs" do
      foo_tcp =  @class.new(:name => "foo", :protocol => :tcp, :number => '23')
      foo_udp =  @class.new(:name => "foo", :protocol => :udp, :number => '23')
      foo_tcp.uniqueness_key.should == [ 'foo', :tcp ]
      foo_udp.uniqueness_key.should == [ 'foo', :udp ]
      foo_tcp.uniqueness_key.should_not == foo_udp.uniqueness_key
    end

    it "should not be equal if name differs" do
      foo_tcp =  @class.new(:name => "foo", :protocol => :tcp, :number => '23')
      bar_tcp =  @class.new(:name => "bar", :protocol => :tcp, :number => '23')
      foo_tcp.uniqueness_key.should == [ 'foo', :tcp ]
      bar_tcp.uniqueness_key.should == [ 'bar', :tcp ]
      foo_tcp.uniqueness_key.should_not == bar_tcp.uniqueness_key
    end

    it "should not be equal if both name and protocol differ" do
      foo_tcp =  @class.new(:name => "foo", :protocol => :tcp, :number => '23')
      bar_udp =  @class.new(:name => "bar", :protocol => :udp, :number => '23')
      foo_tcp.uniqueness_key.should == [ 'foo', :tcp ]
      bar_udp.uniqueness_key.should == [ 'bar', :udp ]
      foo_tcp.uniqueness_key.should_not == bar_udp.uniqueness_key
    end

  end

end
