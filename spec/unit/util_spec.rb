#!/usr/bin/env rspec

require 'spec_helper'

describe Puppet::Util do
  include Puppet::Util

  describe "when run execute" do

    before :each do
      @testscript = my_fixture('execute.rb')
    end

    describe "and the external command does not write anything" do

      it "should capture nothing" do
        execute([@testscript,'nooutput']).should == ""
      end

    end

    describe "and the external command logs output" do

      it "should be able to capture stdout" do
        execute([@testscript,'stdout']).should == "First line\nLast line\n"
      end

      it "should be able to capture stderr" do
        execute([@testscript,'stderr']).should == "First line\nSecond line\n"
      end

      it "should capture stdout and stderr at the same time" do
        # We cannot predict the order because stderr is most likely sync=true
        # while stdout is buffered, so we probably see all errors first. You
        # can # see the same effect when running the testscript like this
        #
        # ./execute.rb stdout_and_stderr            # correct order
        # ./execute.rb stdout_and_stderr 2>&1 | cat # incorrect order
        #
        output = execute([@testscript,'stdout_and_stderr']).split("\n")
        output.size.should == 4
        output.should include "Out 01"
        output.should include "Out 02"
        output.should include "Err 01"
        output.should include "Err 02"
      end

      it "should not capture stderr when using :combine=false" do
        output = execute([@testscript,'stdout_and_stderr'],:combine => false).should == "Out 01\nOut 02\n"
      end

      it "should not fail when stdout lacks a newline character" do
        execute([@testscript,'stdout_lacks_newline']).should == "First line\nLast line with missing newline"
      end

      it "should not fail when stderr lacks a newline character" do
        execute([@testscript,'stderr_lacks_newline']).should == "First line\nLast line with missing newline"
      end

      it "should not fail when stdout and stderr are closed during execution" do
        execute([@testscript,'closepipes']).should == "Bye\nBye\n"
      end

      it "should not fail when command use a spinner" do
        # using match here because I can't really say what the desired output
        # between "Please wait" and "DONE" is
        execute([@testscript,'spinner']).should match /Please wait.*DONE/m
      end

    end

    describe "and the external command reads from stdin" do

      before :each do
        @answerfile = my_fixture('execute_answerfile')
      end

      it "should not block when :stdinfile is not provided" do
        execute([@testscript,'stdin'],:stdinfile => nil).should == "Exit? [y/n]Got no answer\n"
      end

      it "should read from file when :stdinfile is provided" do
        execute([@testscript,'answerfile'], :stdinfile => @answerfile).should match /.*Got user root with uid 0 and gid 0$/m
      end

    end

    describe "and the external commands exits with returncode" do

      it "should not fail if returncode is zero" do
        proc { execute([@testscript, 'nooutput', 0], :failonfail => true)}.should_not raise_error
      end

      it "should fail if returncode is not zero" do
        proc { execute([@testscript, 'nooutput', 1], :failonfail => true)}.should raise_error(Puppet::ExecutionFailure, /Execution of.*returned 1/)
        proc { execute([@testscript, 'nooutput', 10], :failonfail => true)}.should raise_error(Puppet::ExecutionFailure, /Execution of.*returned 10/)
        proc { execute([@testscript, 'nooutput', -1], :failonfail => true)}.should raise_error(Puppet::ExecutionFailure, /Execution of.*returned (-1|255)/)
      end

      it "should never fail if failonfail is false" do
        proc { execute([@testscript, 'nooutput', 0], :failonfail => false)}.should_not raise_error
        proc { execute([@testscript, 'nooutput', 1], :failonfail => false)}.should_not raise_error
      end

    end

  end

end
