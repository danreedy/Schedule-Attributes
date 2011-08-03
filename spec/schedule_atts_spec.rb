require 'spec_helper'

require 'support/scheduled_model'
require 'facets/date'

describe ScheduledModel do
  describe "#schedule" do
    context "when initialized" do
      subject{ ScheduledModel.new.schedule }
      it "the schedule should be for every day" do
        subject.should be_a(IceCube::Schedule)
        subject.rdates.should == []
        subject.start_date.should == Date.today.to_time
        subject.start_date.should be_a(Time)
        subject.end_date.should == nil
        subject.rrules.should == [IceCube::Rule.daily]
      end
    end
  end

  describe "#schedule_attributes" do
    describe "=" do
      describe "setting the correct schedule" do
        let(:scheduled_model){ ScheduledModel.new.tap{|m| m.schedule_attributes = schedule_attributes} }
        subject{ scheduled_model.schedule }
        context "given :interval_unit=>none" do
          let(:schedule_attributes){ { :repeat => '0', :date => '1-1-1985', :interval => '5 (ignore this)' } }
          its(:start_date){ should == Date.new(1985, 1, 1).to_time }
          its(:all_occurrences){ should == [Date.new(1985, 1, 1).to_time] }
          its(:rrules){ should be_blank }
        end

        context "given :duration=>3600" do
          let(:schedule_attributes){ { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'day', :interval => '3', :duration => '3600' } }
          its(:duration) { should == 3600 }
        end

        context "given no :duration" do
          let(:schedule_attributes){ { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'day', :interval => '3' } }
          its(:duration) { should be_nil }
        end

        context "given :interval_unit=>day" do
          let(:schedule_attributes){ { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'day', :interval => '3' } }
          its(:start_date){ should == Date.new(1985, 1, 1).to_time }
          its(:rrules){ should == [IceCube::Rule.daily(3)] }
          it{ subject.first(3).should == [Date.civil(1985, 1, 1), Date.civil(1985, 1, 4), Date.civil(1985, 1, 7)].map(&:to_time) }
        end

        context "given :interval_unit=>day & :ends=>eventually & :until_date" do
          let(:schedule_attributes){ { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'day', :interval => '3', :until_date => '29-12-1985', :ends => 'eventually' } }
          its(:start_date){ should == Date.new(1985, 1, 1).to_time }
          its(:rrules){ should == [ IceCube::Rule.daily(3).until(Date.new(1985, 12, 29).to_time) ] }
          it{ subject.first(3).should == [Date.civil(1985, 1, 1), Date.civil(1985, 1, 4), Date.civil(1985, 1, 7)].map(&:to_time) }
        end

        context "given :interval_unit=>day & :ends=>never & :until_date" do
          let(:schedule_attributes){ { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'day', :interval => '3', :until_date => '29-12-1985', :ends => 'never' } }
          its(:start_date){ should == Date.new(1985, 1, 1).to_time }
          its(:rrules){ should == [IceCube::Rule.daily(3)] }
          it{ subject.first(3).should == [Date.civil(1985, 1, 1), Date.civil(1985, 1, 4), Date.civil(1985, 1, 7)].map(&:to_time) }
        end

        context "given :interval_unit=>week & :mon,:wed,:fri" do
          let(:schedule_attributes){ { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'week', :interval => '3', :monday => '1', :wednesday => '1', :friday => '1' } }
          its(:start_date){ should == Date.new(1985, 1, 1).to_time }
          its(:rrules){ should == [IceCube::Rule.weekly(3).day(:monday, :wednesday, :friday)] }
          it { subject.occurs_at?(ScheduleAttributes.parse_in_timezone('1985-1-2')).should be_true }
          it { subject.occurs_at?(ScheduleAttributes.parse_in_timezone('1985-1-4')).should be_true }
          it { subject.occurs_at?(ScheduleAttributes.parse_in_timezone('1985-1-7')).should be_false }
          it { subject.occurs_at?(ScheduleAttributes.parse_in_timezone('1985-1-21')).should be_true }
        end
      end

      context "setting the schedule_yaml column" do
        let(:scheduled_model){ ScheduledModel.new.tap{|m| m.schedule_attributes = { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'day', :interval => '3' }} }
        subject{ scheduled_model }
        let(:expected_schedule){ IceCube::Schedule.from_yaml(scheduled_model.schedule_yaml) }

        its(:schedule_yaml){ should == scheduled_model.schedule.to_yaml }
        its(:schedule){ should == expected_schedule }
      end
    end


    describe "providing the correct attributes" do
      require 'ostruct'

      let(:scheduled_model){ ScheduledModel.new }
      subject{ scheduled_model.schedule_attributes }
      before{ scheduled_model.stub(:schedule => schedule) }
      let(:schedule){ IceCube::Schedule.new(Date.tomorrow.to_time) }

      context "when it's a 1-time thing" do
        before{ schedule.add_recurrence_date(Date.tomorrow.to_time) }
        it{ should == OpenStruct.new(:repeat => 0, :date => Date.tomorrow, :start_date => Date.today) }
        its(:date){ should be_a(Date) }
      end

      context "when it repeats daily" do
        before do
          schedule.add_recurrence_rule(IceCube::Rule.daily(4))
        end
        it{ should == OpenStruct.new(:repeat => 1, :start_date => Date.tomorrow, :interval_unit => 'day', :interval => 4, :ends => 'never', :date => Date.today) }
        its(:start_date){ should be_a(Date) }
      end

      context "when it repeats with an end date" do
        before do
          schedule.add_recurrence_rule(IceCube::Rule.daily(4).until((Date.today+10).to_time))
        end
        it{ should == OpenStruct.new(:repeat => 1, :start_date => Date.tomorrow, :interval_unit => 'day', :interval => 4, :ends => 'eventually', :until_date => Date.today+10, :date => Date.today) }
        its(:start_date){ should be_a(Date) }
        its(:until_date){ should be_a(Date) }
      end

      context "when it repeats weekly" do
        before do
          schedule.add_recurrence_date(Date.tomorrow)
          schedule.add_recurrence_rule(IceCube::Rule.weekly(4).day(:monday, :wednesday, :friday))
        end
        it do
          should == OpenStruct.new(
            :repeat        => 1,
            :start_date    => Date.tomorrow,
            :interval_unit => 'week',
            :interval      => 4,
            :ends          => 'never',
            :monday        => 1,
            :wednesday     => 1,
            :friday        => 1,

            :date          => Date.today #for the form
          )
        end
      end
    end
  end
  
  describe "#add_exception_date" do
    let(:scheduled_model) { ScheduledModel.new }
    subject{ scheduled_model.exception_dates}
    context "a date is provided" do
      before do
        scheduled_model.add_exception_date Date.today
      end
      its(:size){ should == 1 }
    end
    
    context "multiple dates are provided" do
      before do
        scheduled_model.add_exception_date [Date.yesterday, Date.today, Date.tomorrow]
      end
      its(:size){ should == 3 }
    end
  end
  
  describe "#additional_dates" do
    describe "=" do
      let(:scheduled_model){ ScheduledModel.new.tap{|m| m.additional_dates = additional_dates} }
      subject{ scheduled_model.additional_dates }
      describe "setting values" do
        context "adding an array of dates" do
          let(:additional_dates){ [Date.yesterday, Date.today, Date.tomorrow] }
          its(:size) { should == additional_dates.size }
          it{ should be_a(Array) }
        end
        context "providing bogus values" do
          let(:additional_dates){ "A String!" }
          lambda { it(should_raise(ArgumentError)) }
        end
      end
    end
  end
  
  describe "#exception_dates" do
    describe "=" do
      let(:scheduled_model){ ScheduledModel.new.tap{|m| m.exception_dates = exception_dates} }
      subject{ scheduled_model.exception_dates }
      
      describe "setting values" do        
        context "adding an array of dates" do
          let(:exception_dates){ [Date.yesterday, Date.today, Date.tomorrow] }
          its(:size) { should == exception_dates.size }
          it{ should be_a(Array)}
        end
        context "providing bogus values" do
          let(:exception_dates){ "A String!" }
          lambda { it(should_raise(ArgumentError)) }
        end
      end
    end
    describe "adding and removing additional and exception dates" do
      require 'ostruct'
      
      let(:scheduled_model){ ScheduledModel.new.tap{|m| m.schedule_attributes = schedule_attributes } }
      let(:schedule_attributes){ { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'day', :interval => 1, :until_date => '4-1-1985', :ends => 'eventually' } }
      subject{ scheduled_model.schedule }
      
      context "when 0 dates are added" do
        its(:start_date){ should == Date.new(1985, 1, 1).to_time }
        it{ subject.all_occurrences.should == [Date.civil(1985, 1, 1), Date.civil(1985, 1, 2), Date.civil(1985, 1, 3), Date.civil(1985, 1, 4)].map(&:to_time) }
      end
      
      context "when 1 exception date is added" do
        before do
          scheduled_model.add_exception_date Date.civil(1985, 1, 2)
        end
        it{ subject.all_occurrences.should == [Date.civil(1985,1,1), Date.civil(1985,1,3), Date.civil(1985,1,4)].map(&:to_time) }
      end
      
      context "when 2 exception dates are added" do
        before do
          scheduled_model.add_exception_date [Date.civil(1985,1,2), Date.civil(1985,1,4)]
        end
        it{ subject.all_occurrences.should == [Date.civil(1985,1,1), Date.civil(1985,1,3)].map(&:to_time) }
      end
      
      context "when 1 additional date is added" do
        before do
          scheduled_model.add_additional_date Date.civil(1985,3,1)
        end
        it { subject.all_occurrences.should == [Date.civil(1985,1,1), Date.civil(1985,1,2), Date.civil(1985,1,3), Date.civil(1985,1,4), Date.civil(1985,3,1)].map(&:to_time)}
      end
      
      context "when 2 additional dates are added" do
        before do
          scheduled_model.add_additional_date [Date.civil(1985,3,1), Date.civil(1985,4,1)]
        end
        it { subject.all_occurrences.should == [Date.civil(1985,1,1), Date.civil(1985,1,2), Date.civil(1985,1,3), Date.civil(1985,1,4), Date.civil(1985,3,1), Date.civil(1985,4,1)].map(&:to_time)}
      end
    end
  end
end
