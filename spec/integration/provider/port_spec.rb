#!/usr/bin/env ruby

require 'spec_helper'
require 'puppet/file_bucket/dipper'

describe "port provider (integration)" do
  include PuppetSpec::Files

  before :each do
    @fake_services = tmpfile('services')
    Puppet::Type.type(:port).defaultprovider.stubs(:default_target).returns @fake_services
  end

  def create_fake_services(content)
    File.open(@fake_services,'w') do |f|
      f.puts content
    end
  end

  def check_fake_services(expected_content)
    content = File.read(@fake_services).lines.map(&:chomp).reject{ |x| x =~ /^#|^$/ }.sort.join("\n")
    sorted_expected_content = expected_content.split("\n").sort.join("\n")
    content.should == sorted_expected_content
  end

  def run_in_catalog(resources)
    Puppet::FileBucket::Dipper.any_instance.stubs(:backup) # Don't backup to the filebucket
    catalog = Puppet::Resource::Catalog.new
    catalog.host_config = false
    resources.each do |resource|
      resource.expects(:err).never
      catalog.add_resource(resource)
    end
    catalog.apply
  end

  describe "when managing one resource" do

    describe "with ensure set to absent" do

      before :each do
        @example = Puppet::Type.type(:port).new(
          :name        => 'telnet',
          :protocol    => :tcp,
          :number      => '23',
          :description => 'Telnet with tcp',
          :ensure      => :absent
        )
      end

      it "should not modify /etc/services if resource is currently not present" do
        create_fake_services("ssh 22/tcp\nssh 22/udp")
        run_in_catalog([@example])
        check_fake_services("ssh 22/tcp\nssh 22/udp")
      end

      it "should remove the entry if the resource is currently present" do
        create_fake_services("ssh 22/tcp\ntelnet 99/tcp\nssh 22/udp")
        run_in_catalog([@example])
        check_fake_services("ssh\t22/tcp\nssh\t22/udp")
      end

      it "should not remove an entry if protocol does not match" do
        create_fake_services("ssh\t22/tcp\ntelnet\t23/udp\nssh\t22/udp")
        # example describes telnet/tcp not telnet/udp
        run_in_catalog([@example])
        check_fake_services("ssh\t22/tcp\ntelnet\t23/udp\nssh\t22/udp")
      end

    end

    describe "with no port alias" do

      before :each do
        @example = Puppet::Type.type(:port).new(
          :name        => 'telnet',
          :protocol    => :tcp,
          :number      => '23',
          :description => 'Telnet with tcp',
          :ensure      => :present
        )
        @correct_line = "telnet\t23/tcp\t# Telnet with tcp"
      end

      it "should not modify /etc/services if resource is in sync" do
        create_fake_services("telnet   23/tcp  #  Telnet with tcp")
        run_in_catalog([@example])
        check_fake_services("telnet   23/tcp  #  Telnet with tcp")
      end

      it "should change port number if out of sync" do
        create_fake_services("telnet   9/tcp  #  Telnet with tcp")
        run_in_catalog([@example])
        check_fake_services(@correct_line)
      end

      it "should change description if out of sync" do
        create_fake_services("telnet   23/tcp #   unknown")
        run_in_catalog([@example])
        check_fake_services(@correct_line)
      end

      it "should add the description if currently not present" do
        create_fake_services("telnet   23/tcp")
        run_in_catalog([@example])
        check_fake_services(@correct_line)
      end

      it "should not change unmanaged attributes" do
        create_fake_services("telnet   99/tcp alias1 alias2 # Wrong description")
        run_in_catalog([@example])
        # keep unmanaged aliases
        check_fake_services("telnet\t23/tcp\talias1 alias2\t# Telnet with tcp")
      end

      it "should add an entry to /etc/services if name is not present yet" do
        create_fake_services("ssh   22/tcp\nssh  22/udp # Test")
        run_in_catalog([@example])
        check_fake_services("ssh\t22/tcp\nssh\t22/udp\t# Test\n" + @correct_line)
      end

      it "should add an entry to /etc/services if protocol is not present yet" do
        create_fake_services("telnet   23/udp\nssh  22/udp # Test")
        run_in_catalog([@example])
        # example describes telnet/tcp an should not modify telnet/udp
        check_fake_services("telnet\t23/udp\nssh\t22/udp\t# Test\n" + @correct_line)
      end

    end

    describe "with port aliases" do

      before :each do
        @example = Puppet::Type.type(:port).new(
          :name         => 'telnet',
          :protocol     => :tcp,
          :number       => '23',
          :description  => 'Telnet with tcp',
          :port_aliases => [ 'foo', 'bar' ],
          :ensure       => :present
        )
        @correct_line = "telnet\t23/tcp\tfoo bar\t# Telnet with tcp"
      end

      it "should not modify /etc/services if resource is in sync" do
        create_fake_services("telnet   23/tcp  foo bar #  Telnet with tcp")
        run_in_catalog([@example])
        check_fake_services("telnet   23/tcp  foo bar #  Telnet with tcp")
      end

      it "should change port aliases if currently out of sync" do
        create_fake_services("telnet   23/tcp foo kar # Telnet with tcp")
        run_in_catalog([@example])
        check_fake_services(@correct_line)
      end

      # stschulte: I dont know if the order is crucial at all - if its not
      # one can easily modify this test and substitue Puppet::Property::OrderedList
      # with Puppet::Property::List
      it "should also change port aliases if they are in wrong order" do
        create_fake_services("telnet   23/tcp bar foo # Telnet with tcp")
        run_in_catalog([@example])
        check_fake_services(@correct_line)
      end

      it "should add missing port aliases" do
        create_fake_services("telnet   23/tcp bar # Telnet with tcp")
        run_in_catalog([@example])
        check_fake_services(@correct_line)
      end

      it "should remove any port alias that was not defined" do
        create_fake_services("telnet   23/tcp foo bar n # Telnet with tcp")
        run_in_catalog([@example])
        check_fake_services(@correct_line)
      end

    end

  end

  [true, false].each do |uniq|
    describe "when managing two resources #{uniq ? 'with unique names' : 'with the same name but different protocols'}" do

      before :each do

        @example1 = {
          :resource  => Puppet::Type.type(:port).new(
            :title       => 'telnet/tcp',
            :name        => 'telnet',
            :protocol    => :tcp,
            :number      => '23',
            :description => 'Telnet with tcp',
            :ensure      => :present
          ),
          :correctline   => "telnet\t23/tcp\t# Telnet with tcp",
          :incorrectline => "telnet\t23/tcp",
        }
        @example2 = {
          :resource => Puppet::Type.type(:port).new(
            :title       => 'telnet/udp',
            :name        => 'telnet',
            :protocol    => :udp,
            :number      => '23',
            :description => 'Telnet with udp',
            :ensure      => :present
          ),
          :correctline   => "telnet\t23/udp\t# Telnet with udp",
          :incorrectline => "telnet\t22/udp\t# Telnet with udp",
        }
        @example3 = {
          :resource => Puppet::Type.type(:port).new(
            :title       => 'mandelspawn/udp',
            :name        => 'mandelspawn',
            :port_aliases=> 'mandelbrot',
            :protocol    => :udp,
            :number      => '9359',
            :description => 'network mandelbrot',
            :ensure      => :present
          ),
          :correctline   => "mandelspawn\t9359/udp\tmandelbrot\t# network mandelbrot",
          :incorrectline => "mandelspawn\t9359/udp\tmandlbrot\t# network mandelbrot",
        }

        if uniq
          @examples = [ @example1, @example3 ]
        else
          @examples = [ @example1, @example2 ]
        end

        @desired_result = @examples.collect{|h| h[:correctline]}.join("\n")

      end


      describe "and one resource is absent" do

        it "should add the second resource if only the first one is present" do
          create_fake_services(@examples[0][:correctline])
          run_in_catalog(@examples.map { |example| example[:resource] })
          check_fake_services(@desired_result)
        end

        it "should add the first resource if only the second one is present" do
          create_fake_services(@examples[1][:correctline])
          run_in_catalog(@examples.map { |example| example[:resource] })
          check_fake_services(@desired_result)
        end

      end

      describe "and both resources are absent" do

        it "should add both resources" do
          create_fake_services("ssh 23/tcp # Yeah")
          run_in_catalog(@examples.map { |example| example[:resource] })
          check_fake_services("ssh\t23/tcp\t# Yeah\n" + @desired_result)
        end

      end

      describe "and both resources are in sync" do

        it "should not do anything" do
          create_fake_services(@examples.map{|example| example[:correctline]})
          run_in_catalog(@examples.map { |example| example[:resource] })
          check_fake_services(@desired_result)
        end

      end

      describe "and both resources are out of sync" do

        it "should change both resources" do
          create_fake_services(@examples.map{|example| example[:incorrectline]})
          run_in_catalog(@examples.map { |example| example[:resource] })
          check_fake_services(@desired_result)
        end

      end

    end

  end

end
