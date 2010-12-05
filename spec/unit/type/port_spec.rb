#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/property/ordered_list'

port = Puppet::Type.type(:port)

describe port do
  before do
    @class = port
    @provider_class = stub 'provider_class', :name => 'fake', :ancestors => [], :suitable? => true, :supports_parameter? => true
    @class.stubs(:defaultprovider).returns @provider_class
    @class.stubs(:provider).returns @provider_class

    @provider = stub 'provider', :class => @provider_class, :clean => nil
    @resource = stub 'resource', :resource => nil, :provider => @provider

    @provider.stubs(:port_aliases).returns :absent

    @provider_class.stubs(:new).returns(@provider)
    @catalog = Puppet::Resource::Catalog.new
  end

  it "should have a title pattern that splits name and protocol" do
    regex = @class.title_patterns[0][0]
    regex.match("telnet:tcp").captures.should == ['telnet','tcp' ]
  end

  it "should have two key_attributes" do
    @class.key_attributes.size.should == 2
  end

  it "should have :name as a key_attribute" do
    @class.key_attributes.should include :name
  end

  it "should have :protocol as a key_attribute" do
    @class.key_attributes.should include :protocol
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

    it "should have a list port_aliases" do
      @class.attrclass(:port_aliases).ancestors.should include Puppet::Property::OrderedList
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
      proc { @class.new(:name => "whev", :protocol => :tcpp) }.should raise_error(Puppet::Error)
    end

    it "should support valid portnumbers" do
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => '0') }.should_not raise_error
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => '1') }.should_not raise_error
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => "#{2**16-1}") }.should_not raise_error
    end

    it "should not support portnumbers that arent numeric" do
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => "aa") }.should raise_error(Puppet::Error)
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => "22a") }.should raise_error(Puppet::Error)
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => "a22") }.should raise_error(Puppet::Error)
    end

    it "should not support portnumbers that are out of range" do
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => "-1") }.should raise_error(Puppet::Error)
      proc { @class.new(:name => "whev", :protocol => :tcp, :number => "#{2**16}") }.should raise_error(Puppet::Error)
    end

    it "should support single port_alias" do
      proc { @class.new(:name => "foo", :protocol => :tcp, :port_aliases => 'bar') }.should_not raise_error
    end

    it "should support multiple port_aliases" do
      proc { @class.new(:name => "foo", :protocol => :tcp, :port_aliases => ['bar','bar2']) }.should_not raise_error
    end

    it "should not support whitespaces in any port_alias" do
      proc { @class.new(:name => "whev", :protocol => :tcp, :port_aliases => ['bar','fo o']) }.should raise_error(Puppet::Error)
    end

    it "should not support whitespaces in resourcename" do
      proc { @class.new(:name => "foo bar", :protocol => :tcp) }.should raise_error(Puppet::Error)
    end

  end

  describe "when syncing" do

    it "should send the first value to the provider for number property" do
      @port = @class.attrclass(:number).new(:resource => @resource, :should => %w{100 200})
      @provider.expects(:number=).with '100'
      @port.sync
    end

    it "should send the joined array to the provider for port_aliases property" do
      @port_aliases = @class.attrclass(:port_aliases).new(:resource => @resource, :should => %w{foo bar})
      @provider.expects(:port_aliases=).with 'foo bar'
      @port_aliases.sync
    end

    it "should care about the order of port_aliases" do
      @port_aliases = @class.attrclass(:port_aliases).new(:resource => @resource, :should => %w{a z b})
      @port_aliases.insync?(%w{a z b}).should == true
      @port_aliases.insync?(%w{a b z}).should == false
      @port_aliases.insync?(%w{b a z}).should == false
      @port_aliases.insync?(%w{z a b}).should == false
      @port_aliases.insync?(%w{z b a}).should == false
      @port_aliases.insync?(%w{b z a}).should == false
    end

  end

end
