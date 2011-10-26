namespace :data do
  desc "download master data and update the database"
  task :update => :environment do
    require 'net/http'
    require "nokogiri"

    p "[INFO] starting"

    p "[INFO] deleting old data"
    [Room, Course, Teacher, Timeslot, Booking, Group].each {|e| e.delete_all }

    i=0
    begin
    fetch_timetables.each do |booking|
      tmp = booking.xpath('room').text
      next if tmp.empty?
      room = Room.find_by_name(tmp) || Room.create(name: tmp, label: tmp.upcase.insert(2,'.'), building: tmp[0], floor: tmp[1])

      booking.xpath('courses/course').each do |c|
        tmp = c.xpath('modul').text
        course = Course.find_by_name(tmp) || Course.create(name: tmp, label: get_modul_label(tmp) )

        day = Day.find_by_name(booking.xpath('weekday').text)
        binding.pry if day.nil?
        time_conditions = { start_label: booking.xpath('starttime').text,
                            end_label: booking.xpath('stoptime').text,
                            day_id: day.id }
        time = Timeslot.find(:first, conditions: time_conditions ) || Timeslot.create( time_conditions )

        group = Group.find_or_create_by_name(c.xpath('group').text)
        conditions ={
                      room_id: room.id,
                      timeslot_id: time.id,
                      course_id: course.id,
                      group_id: group.id
                    }
        b = Booking.find( :first, conditions: conditions )
        if b.nil?
          b = Booking.create( conditions.merge( suffix: booking.xpath('suffix').text ) )
          p "[INFO] new booking created"
        end
        c.xpath('teacher').each do |t|
          tmp = t.text
          teacher = Teacher.find_by_name(tmp) || Teacher.create(name: tmp, label: get_teacher_name(tmp) )
          b.teachers << teacher unless b.teachers.include?(teacher)
        end

        #c.xpath('teacher').each do |t|
        #  tmp = t.text
        #  teacher = Teacher.find_by_name(tmp) || Teacher.create(name: tmp, label: get_teacher_name(tmp) )
        #end
        #unless Booking.find( :first, conditions: conditions )
        #  Booking.create( conditions.merge( suffix: booking.xpath('suffix').text ) )
        #  p "[create: ]#{conditions}"
        #end
      end
    end
    [Booking, Teacher, Room, Course, Group, Timeslot].each do |c|
      p "[INFO] #{c.count} #{c.to_s.pluralize}"
    end
    rescue => e
      p "[ERROR] main: #{e.message}"
      p e.backtrace
    end
  end

  def mark_data_as_orphin
    #TODO
  end

  def delete_orphans
    #[Booking, Room, Timeslot, Course, Teacher].each {|m| m.delete_if{|e| e.orphan} }
  end

  def fetch_timetables
    xml = nil
    Timeout::timeout(5) do
      net = Net::HTTP.get_response(URI.parse('http://fi.cs.hm.edu/fi/rest/public/timetable/group.xml'))
      raise "HTTP Error: #{net.code}" if %w(404 500).include? net.code
      xml = Nokogiri::XML(net.body)
    end
    return xml.xpath('/list/timetable/day/time/booking')
  rescue => e
    p "[ERROR] fetch_timetables: #{e.message}"
    p e.backtrace
  end

  def get_modul_label(modul)
    xml = ''
    Timeout::timeout(5) do
      net = Net::HTTP.get_response(URI.parse("http://fi.cs.hm.edu/fi/rest/public/modul/title/#{modul}.xml"))
      raise "HTTP Error: #{net.code}" if %w(404 500).include? net.code
      xml = Nokogiri::XML(net.body)
    end
    xml.xpath('/modul/name').first.text
  rescue => e
    p "[ERROR] get_modul_label: #{e.message}"
    p e.backtrace
  end

  def get_teacher_name(teacher)
    xml = ''
    Timeout::timeout(5) do
      net = Net::HTTP.get_response(URI.parse("http://fi.cs.hm.edu/fi/rest/public/person/name/#{teacher}.xml"))
      raise "HTTP Error: #{net.code}" if %w(404 500).include? net.code
      xml = Nokogiri::XML(net.body)
    end
    person = xml.xpath('/person').first

    "#{person.xpath('title').text} #{person.xpath('firstname').text} #{person.xpath('lastname').text}"
  rescue => e
    p "[ERROR] get_teacher_name: #{e.message}"
    p e.backtrace
  end
end
