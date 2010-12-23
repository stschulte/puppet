#!/usr/bin/env ruby

require 'spec_helper'
require 'shared_behaviours/all_parsedfile_providers'
require 'puppet_spec/files'

provider_class = Puppet::Type.type(:port).provider(:parsed)

describe provider_class do
  include PuppetSpec::Files

  before do
    @host_class = Puppet::Type.type(:port)
    @provider = @host_class.provider(:parsed)
    @servicesfile = tmpfile('services')
    @provider.stubs(:default_target).returns @servicesfile
    @provider.any_instance.stubs(:target).returns @servicesfile
  end

  after :each do
    @provider.initvars
  end

  def mkport(args)
    portresource = Puppet::Type::Port.new(:name => args[:name], :protocol => args[:protocol])
    portresource.stubs(:should).with(:target).returns @servicesfile

    # Using setters of provider
    port = @provider.new(portresource)
    args.each do |property,value|
      value = value.join(' ') if property == :port_aliases and value.is_a?(Array)
      port.send("#{property}=", value)
    end
    port
  end

  def genport(port)
    @provider.stubs(:filetype).returns(Puppet::Util::FileType::FileTypeRam)
    File.stubs(:chown)
    File.stubs(:chmod)
    Puppet::Util::SUIDManager.stubs(:asuser).yields
    port.flush
    @provider.target_object(@servicesfile).read
  end

  describe "when parsing a line with name port and protocol" do

    before do
      @example_line = "telnet   \t    23/udp"
    end

    it "should extract name from the first field" do
      @provider.parse_line(@example_line)[:name].should == 'telnet'
    end

    it "should extract number from second field" do
      @provider.parse_line(@example_line)[:number].should == '23'
    end

    it "should extract protocol udp from third field" do
      @provider.parse_line(@example_line)[:protocol].should == :udp
    end

    it "should extract protocol tcp from third field" do
      @provider.parse_line('telnet 23/tcp')[:protocol].should == :tcp
    end

    it "should drop trailing spaces" do
      @provider.parse_line('telnet 23/tcp  ')[:protocol].should == :tcp
    end

    it "should handle different delimiters" do
      @result = ['telnet','23',:tcp ]
      [
        "telnet 23/tcp",
        "telnet\t23/tcp",
        "telnet \t23/tcp",
        "telnet\t 23/tcp",
        "telnet  \t  23/tcp\t\t"
      ].each do |sample|
        hash = @provider.parse_line(sample)
        hash[:name].should == @result[0]
        hash[:number].should == @result[1]
        hash[:protocol].should == @result[2]
        hash[:description].should == ''
      end
    end

  end

  describe "when parsing a line with name, port, protocol, description" do

    before do
      @example_line = "telnet   \t    23/udp # Telnet"
    end

    it "should extract name from the first field" do
      @provider.parse_line(@example_line)[:name].should == 'telnet'
    end

    it "should extract number from second field" do
      @provider.parse_line(@example_line)[:number].should == '23'
    end

    it "should extract protocol from third field" do
      @provider.parse_line(@example_line)[:protocol].should == :udp
    end

    it "should extract description after the first #" do
      @provider.parse_line(@example_line)[:description].should == 'Telnet'
    end

    it "should correctly set description with multiple #" do
      @provider.parse_line('telnet 23/udp # My # desc')[:description].should == 'My # desc'
    end

    it "should handle different delimiters" do
      @result = ['telnet', '23', :udp, 'My # desc' ]
      [
        "telnet 23/udp # My # desc",
        "telnet\t 23/udp\t# My # desc",
        "telnet  \t23/udp   #\tMy # desc",
        "telnet   \t  \t 23/udp \t \t# \tMy # desc"
      ].each do |sample|
        hash = @provider.parse_line(sample)
        hash[:name].should == @result[0]
        hash[:number].should == @result[1]
        hash[:protocol].should == @result[2]
        hash[:description].should == @result[3]
      end

    end

  end

  describe "when parsing a line with name, number, procotol and aliases" do

    before do
      @example_line = "telnet   \t    23/udp alias1 alias2"
    end

    it "should extract name from the first field" do
      @provider.parse_line(@example_line)[:name].should == 'telnet'
    end

    it "should extract number from second field" do
      @provider.parse_line(@example_line)[:number].should == '23'
    end

    it "should extract protocol from third field" do
      @provider.parse_line(@example_line)[:protocol].should == :udp
    end

    it "should extract single alias" do
      @example_line = "telnet   \t    23/udp alias1"
      @provider.parse_line(@example_line)[:port_aliases].should == 'alias1'
    end

    it "should extract multiple aliases" do
      @provider.parse_line(@example_line)[:port_aliases].should == 'alias1 alias2'
    end

    it "should convert delimiter to single space" do
      @provider.parse_line("telnet 23/udp alias1\t\t alias2\talias3 alias4")[:port_aliases].should == 'alias1 alias2 alias3 alias4'
    end

    it "should set port_aliases to :absent if there is none" do
      @provider.parse_line("telnet 23/udp")[:port_aliases].should == :absent
      @provider.parse_line("telnet 23/udp  ")[:port_aliases].should == :absent
      @provider.parse_line("telnet 23/udp  # Bazinga!")[:port_aliases].should == :absent
    end

  end

  describe "when parsing a line with name, number, protocol, aliases and description" do

    before do
      @example_line = "telnet   \t    23/udp alias1 alias2 # Tel#net"
      @result = ['telnet','23',:udp,'alias1 alias2','Tel#net']
    end

    it "should extract name from the first field" do
      @provider.parse_line(@example_line)[:name].should == @result[0]
    end

    it "should extract number from second field" do
      @provider.parse_line(@example_line)[:number].should == @result[1]
    end

    it "should extract protocol from third field" do
      @provider.parse_line(@example_line)[:protocol].should == @result[2]
    end

    it "should extract aliases from forth field" do
      @provider.parse_line(@example_line)[:port_aliases].should == @result[3]
    end

    it "should extract description from the fifth field" do
      @provider.parse_line(@example_line)[:description].should == @result[4]
    end

  end

  describe "when operating on /etc/services like files" do

    it_should_behave_like "all parsedfile providers", provider_class

  end

  it "should be able to generate a simple services entry" do
    port = mkport(
      :name     => 'telnet',
      :protocol => :tcp,
      :number   => '23',
      :ensure   => :present
    )
    genport(port).should == "telnet\t23/tcp\n"
  end

  it "should be able to generate an entry with one alias" do
    port = mkport(
      :name         => 'pcx-pin',
      :protocol     => :tcp,
      :number       => '4005',
      :port_aliases => 'single_alias',
      :ensure       => :present
    )
    genport(port).should == "pcx-pin\t4005/tcp\tsingle_alias\n"
  end

  it "should be able to generate an entry with more than one alias" do
    port = mkport(
      :name         => 'pcx-splr-ft',
      :protocol     => :udp,
      :number       => '4003',
      :port_aliases => [ 'mult_alias', 'rquotad' ],
      :ensure       => :present
    )
    genport(port).should == "pcx-splr-ft\t4003/udp\tmult_alias rquotad\n"
  end

  it "should be able to generate a simple hostfile entry with comments" do
    port = mkport(
      :name        => 'telnet',
      :protocol    => :tcp,
      :number      => '23',
      :description => 'Fancy # comment',
      :ensure      => :present
    )
    genport(port).should == "telnet\t23/tcp\t# Fancy # comment\n"
  end

  it "should be able to generate an entry with one alias and a comment" do
    port = mkport(
      :name          => 'foo',
      :protocol      => :tcp,
      :number        => '1',
      :port_aliases  => 'bar',
      :description   => 'Bazinga!',
      :ensure        => :present
    )
    genport(port).should == "foo\t1/tcp\tbar\t# Bazinga!\n"
  end

  it "should be able to generate an entry with more than one alias and a comment" do
    port = mkport(
      :name          => 'foo',
      :protocol      => :udp,
      :number        => '3000',
      :port_aliases  => [ 'bar', 'baz', 'zap' ],
      :description   => 'Bazinga!',
      :ensure        => :present
    )
    genport(port).should == "foo\t3000/udp\tbar baz zap\t# Bazinga!\n"
  end

end
