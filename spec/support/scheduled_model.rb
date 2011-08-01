require 'schedule_atts'

class ScheduledModel
  include ScheduleAttributes
  attr_accessor :schedule_yaml, :additional_dates, :exception_dates
end
