require 'ostruct'

module ActionController
  class Base
    attr_accessor :response_body

    def headers
      @headers ||= {}
    end

    def response
      @response ||= OpenStruct.new
    end

  end
end

$: << File.join(File.dirname(__FILE__), "/../lib")
require 'streamy_csv.rb'
require 'csv'

describe StreamyCsv do

  it 'extends the action controller with the module' do
    ActionController::Base.ancestors.should include(StreamyCsv)
  end

  before(:each) do
    @controller = ActionController::Base.new
    @header = CSV::Row.new([:name, :title], ['Name', 'Title'], true)
  end
  context '#stream_csv' do
    it 'sets the streaming headers' do
      @controller.stream_csv('abc.csv', @header)
      @controller.headers.should include({'X-Accel-Buffering' => 'no',
        "Cache-Control" => "no-cache"
      })
    end

    it 'sets the file headers' do
      @controller.stream_csv('abc.csv', @header)
      @controller.headers.should include({"Content-Type" => "text/csv",
        "Content-disposition" => "attachment; filename=\"abc.csv\""
      })
    end

    it 'streams the csv file' do
      row_1 = CSV::Row.new([:name, :title], ['AB', 'Mr'])
      row_2 = CSV::Row.new([:name, :title], ['CD', 'Pres'])

      rows = [@header, row_1]

      @controller.stream_csv('abc.csv', @header) do |rows|
        rows << row_1
        rows << row_2
      end

      @controller.response.status.should == 200
      @controller.response_body.is_a?(Enumerable).should == true
    end
    it 'sanitizes header and contents and streams the csv file' do
      row_1 = CSV::Row.new([:name, :title], ['AB', 'Mr'])
      row_2 = CSV::Row.new([:name, :title], ["=cmd|' /C", 'Pres'])
      header = row_2
      rows = [header, row_1]

      @controller.stream_csv('abc.csv', header) do |rows|
        rows << row_1
        rows << row_2
      end
      @controller.response.status.should == 200
      @controller.response_body.is_a?(Enumerable).should == true
      @controller.response_body.take(1)[0].to_s[4].bytes.should == '\\'.bytes
      @controller.response_body.take(1)[0].to_s[5].bytes.should == '|'.bytes
      @controller.response_body.take(3)[2].to_s[4].bytes.should == '\\'.bytes
      @controller.response_body.take(3)[2].to_s[5].bytes.should == '|'.bytes
    end
    it 'does not sanitize the csv if the option provided' do
      row_1 = CSV::Row.new([:name, :title], ['AB', 'Mr'])
      row_2 = CSV::Row.new([:name, :title], ["=cmd|' /C", 'Pres'])
      header = row_2
      rows = [header, row_1]

      @controller.stream_csv('abc.csv', header, false) do |rows|
        rows << row_1
        rows << row_2
      end
      @controller.response.status.should == 200
      @controller.response_body.is_a?(Enumerable).should == true
      @controller.response_body.take(1)[0].to_s[3].bytes.should == 'd'.bytes
      @controller.response_body.take(1)[0].to_s[4].bytes.should == '|'.bytes
      @controller.response_body.take(3)[2].to_s[3].bytes.should == 'd'.bytes
      @controller.response_body.take(3)[2].to_s[4].bytes.should == '|'.bytes
    end
  end

  describe '#santize!' do
    it 'escapes unscaped pipe characters enumberables having strings starting with operators' do
      enumerable = CSV::Row.new([:name, :title], ["=cmd|' /C", 'Pres'])
      @controller.send(:sanitize!, enumerable)
      enumerable.take(2)[0][1][4].bytes.should == '\\'.bytes
      enumerable.take(2)[0][1][5].bytes.should == '|'.bytes
    end
    it 'does not escape pipes that are already scaped' do
      enumerable = CSV::Row.new([:name, :title], ["=cmd\\|' /C", 'Pres'])
      @controller.send(:sanitize!, enumerable)
      enumerable.take(2)[0][1][3].bytes.should == 'd'.bytes
      enumerable.take(2)[0][1][4].bytes.should == '\\'.bytes
      enumerable.take(2)[0][1][5].bytes.should == '|'.bytes
    end
    it 'does not escape pipes that are not started with an operator' do
      enumerable = CSV::Row.new([:name, :title], ["cmd|' /C", 'Pres'])
      @controller.send(:sanitize!, enumerable)
      enumerable.take(2)[0][1][2].bytes.should == 'd'.bytes
      enumerable.take(2)[0][1][3].bytes.should == '|'.bytes
    end
  end

end