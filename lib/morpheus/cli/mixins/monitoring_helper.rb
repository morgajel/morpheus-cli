require 'morpheus/cli/mixins/print_helper'
require 'morpheus/cli/option_types'
require 'morpheus/rest_client'
# Mixin for Morpheus::Cli command classes
# Provides common methods for the monitoring domain, incidents, checks, 'n such
module Morpheus::Cli::MonitoringHelper

  def self.included(klass)
    klass.send :include, Morpheus::Cli::PrintHelper
  end

  def monitoring_interface
    # @api_client.monitoring
    raise "#{self.class} has not defined @monitoring_interface" if @monitoring_interface.nil?
    @monitoring_interface
  end

  def find_check_by_name_or_id(val)
    if val.to_s =~ /\A\d{1,}\Z/
      return find_check_by_id(val)
    else
      return find_check_by_name(val)
    end
  end

  def find_check_by_id(id)
    begin
      json_response = monitoring_interface.checks.get(id.to_i)
      return json_response['check']
    rescue RestClient::Exception => e
      if e.response && e.response.code == 404
        print_red_alert "Check not found by id #{id}"
        exit 1
      else
        raise e
      end
    end
  end

  def find_check_by_name(name)
    json_results = monitoring_interface.checks.list({name: name})
    if json_results['checks'].empty?
      print_red_alert "Check not found by name #{name}"
      exit 1
    end
    check = json_results['checks'][0]
    return check
  end

  # def find_incident_by_name_or_id(val)
  #   if val.to_s =~ /\A\d{1,}\Z/
  #     return find_incident_by_id(val)
  #   else
  #     return find_incident_by_name(val)
  #   end
  # end

  def find_incident_by_id(id)
    begin
      json_response = monitoring_interface.incidents.get(id.to_i)
      return json_response['incident']
    rescue RestClient::Exception => e
      if e.response && e.response.code == 404
        print_red_alert "Incident not found by id #{id}"
        exit 1
      else
        raise e
      end
    end
  end

  # def find_incident_by_name(name)
  #   json_results = monitoring_interface.incidents.get({name: name})
  #   if json_results['incidents'].empty?
  #     print_red_alert "Incident not found by name #{name}"
  #     exit 1
  #     end
  #   incident = json_results['incidents'][0]
  #   return incident
  # end


  def get_available_check_types(refresh=false)
    if !@available_check_types || refresh
      # @available_check_types = [{name: 'A Fake Check Type', code: 'achecktype'}]
      # todo: use options api instead probably...
      @available_check_types = check_types_interface.list_check_types['checkTypes']
    end
    return @available_check_types
  end

  def check_type_for_name_or_id(val)
    if val.to_s =~ /\A\d{1,}\Z/
      return check_type_for_id(val)
    else
      return check_type_for_name(val)
    end
  end
  
  def check_type_for_id(id)
    return get_available_check_types().find { |z| z['id'].to_i == id.to_i}
  end

  def check_type_for_name(name)
    return get_available_check_types().find { |z| z['name'].downcase == name.downcase || z['code'].downcase == name.downcase}
  end

  def format_severity(severity, return_color=cyan)
    out = ""
    status_string = severity
    if status_string == 'critical'
      out << "#{red}#{status_string.capitalize}#{return_color}"
    elsif status_string == 'warning'
      out << "#{yellow}#{status_string.capitalize}#{return_color}"
    elsif status_string == 'info'
      out << "#{cyan}#{status_string.capitalize}#{return_color}"
    else
      out << "#{cyan}#{status_string}#{return_color}"
    end
    out
  end

  def format_monitoring_issue_attachment_type(issue)
    if issue["app"]
      "App"
    elsif issue["check"]
      "Check"
    elsif issue["checkGroup"]
      "Group"
    else
      "Severity Change"
    end
  end

  def format_monitoring_incident_status(incident)
    status_string = incident['status']
    if status_string == 'closed'
      "closed ✓"
    else
      status_string
    end
  end

  def format_monitoring_issue_status(issue)
    format_monitoring_incident_status(issue)
  end

  

  # Incidents

  def print_incidents_table(incidents, opts={})
    columns = [
      {"ID" => lambda {|incident| incident['id'] } },
      {"SEVERITY" => lambda {|incident| format_severity(incident['severity']) } },
      {"NAME" => lambda {|incident| incident['name'] || 'No Subject' } },
      {"TIME" => lambda {|incident| format_local_dt(incident['startDate']) } },
      {"STATUS" => lambda {|incident| format_monitoring_incident_status(incident) } },
      {"DURATION" => lambda {|incident| format_duration(incident['startDate'], incident['endDate']) } }
    ]
    if opts[:include_fields]
      columns = opts[:include_fields]
    end
    print as_pretty_table(incidents, columns, opts)
  end

  def print_incident_history_table(history_items, opts={})
    columns = [
      # {"ID" => lambda {|issue| issue['id'] } },
      {"SEVERITY" => lambda {|issue| format_severity(issue['severity']) } },
      {"AVAILABLE" => lambda {|issue| format_boolean issue['available'] } },
      {"TYPE" => lambda {|issue| issue["attachmentType"] } },
      {"NAME" => lambda {|issue| issue['name'] } },
      {"DATE CREATED" => lambda {|issue| format_local_dt(issue['startDate']) } }
    ]
    if opts[:include_fields]
      columns = opts[:include_fields]
    end
    print as_pretty_table(history_items, columns, opts)
  end

  def print_incident_notifications_table(notifications, opts={})
    columns = [
      {"NAME" => lambda {|notification| notification['recipient'] ? notification['recipient']['name'] : '' } },
      {"DELIVERY TYPE" => lambda {|notification| notification['addressTypes'].to_s } },
      {"NOTIFIED ON" => lambda {|notification| format_local_dt(notification['dateCreated']) } },
      # {"AVAILABLE" => lambda {|notification| format_boolean notification['available'] } },
      # {"TYPE" => lambda {|notification| notification["attachmentType"] } },
      # {"NAME" => lambda {|notification| notification['name'] } },
      {"DATE CREATED" => lambda {|notification| 
        date_str = format_local_dt(notification['startDate']).to_s
        if notification['pendingUtil']
          "(pending) #{date_str}"
        else
          date_str
        end
      } }
    ]
    #event['pendingUntil']
    if opts[:include_fields]
      columns = opts[:include_fields]
    end
    print as_pretty_table(notifications, columns, opts)
  end


  # Checks

  def format_monitoring_check_status(check, return_color=cyan)
    #<morph:statusIcon unknown="${!check.lastRunDate}" muted="${!check.createIncident}" failure="${check.lastCheckStatus == 'error'}" health="${check.health}" class="pull-left"/>
    out = ""
    muted = !check['createIncident']
    status_string = check['lastCheckStatus'].to_s
    failure = check['lastCheckStatus'] == 'error'
    health = check['health'] # todo: examine at this too?
    if failure
      out << "#{red}#{status_string.capitalize}#{return_color}"
    else
      out << "#{cyan}#{status_string.capitalize}#{return_color}"
    end
    if muted
      out << "(muted)"
    end
    out
  end

  def format_monitoring_check_last_metric(check)
    #<td class="last-metric-col">${check.lastMetric} ${check.lastMetric ? checkTypes.find{ type -> type.id == check.checkTypeId}?.metricName : ''}</td>
    out = ""
    out << "#{check['lastMetric']} "
    # todo:
    out.strip
  end

  def format_monitoring_check_type(check)
    #<td class="check-type-col"><div class="check-type-icon ${morph.checkTypeCode(id:check.checkTypeId, checkTypes:checkTypes)}"></div></td>
    # return get_object_value(check, 'checkType.name') # this works too
    out = ""
    if check && check['checkType'] && check['checkType']['name']
      out << check['checkType']['name']
    elsif check['checkTypeId']
      out << check['checkTypeId'].to_s
    elsif !check.empty?
      out << check.to_s
    end
    out.strip! + "WEEEEEE"
  end

  def print_checks_table(incidents, opts={})
    columns = [
      {"ID" => lambda {|check| check['id'] } },
      {"STATUS" => lambda {|check| format_monitoring_check_status(check) } },
      {"NAME" => lambda {|check| check['name'] } },
      {"TIME" => lambda {|check| format_local_dt(check['lastRunDate']) } },
      {"AVAILABILITY" => {display_method: lambda {|check| check['availability'] ? "#{check['availability'].to_f.round(3).to_s}%" : "N/A"} }, justify: "center" },
      {"RESPONSE TIME" => {display_method: lambda {|check| check['lastTimer'] ? "#{check['lastTimer']}ms" : "N/A" } }, justify: "center" },
      {"LAST METRIC" => {display_method: lambda {|check| check['lastMetric'] ? "#{check['lastMetric']}" : "N/A" } }, justify: "center" },
      {"TYPE" => 'checkType.name'},
      
    ]
    if opts[:include_fields]
      columns = opts[:include_fields]
    end
    print as_pretty_table(incidents, columns, opts)
  end

  def print_check_history_table(history_items, opts={})
    columns = [
      # {"ID" => lambda {|issue| issue['id'] } },
      {"SEVERITY" => lambda {|issue| format_severity(issue['severity']) } },
      {"AVAILABLE" => lambda {|issue| format_boolean issue['available'] } },
      {"TYPE" => lambda {|issue| issue["attachmentType"] } },
      {"NAME" => lambda {|issue| issue['name'] } },
      {"DATE CREATED" => lambda {|issue| format_local_dt(issue['startDate']) } }
    ]
    if opts[:include_fields]
      columns = opts[:include_fields]
    end
    print as_pretty_table(history_items, columns, opts)
  end

  def print_check_notifications_table(notifications, opts={})
    columns = [
      {"NAME" => lambda {|notification| notification['recipient'] ? notification['recipient']['name'] : '' } },
      {"DELIVERY TYPE" => lambda {|notification| notification['addressTypes'].to_s } },
      {"NOTIFIED ON" => lambda {|notification| format_local_dt(notification['dateCreated']) } },
      # {"AVAILABLE" => lambda {|notification| format_boolean notification['available'] } },
      # {"TYPE" => lambda {|notification| notification["attachmentType"] } },
      # {"NAME" => lambda {|notification| notification['name'] } },
      {"DATE CREATED" => lambda {|notification| 
        date_str = format_local_dt(notification['startDate']).to_s
        if notification['pendingUtil']
          "(pending) #{date_str}"
        else
          date_str
        end
      } }
    ]
    #event['pendingUntil']
    if opts[:include_fields]
      columns = opts[:include_fields]
    end
    print as_pretty_table(notifications, columns, opts)
  end

  # Monitoring Contacts

  def find_contact_by_name_or_id(val)
    if val.to_s =~ /\A\d{1,}\Z/
      return find_contact_by_id(val)
    else
      return find_contact_by_name(val)
    end
  end

  def find_contact_by_id(id)
    begin
      json_response = monitoring_interface.contacts.get(id.to_i)
      return json_response['contact']
    rescue RestClient::Exception => e
      if e.response && e.response.code == 404
        print_red_alert "Contact not found by id #{id}"
        exit 1 # return nil
      else
        raise e
      end
    end
  end

  def find_contact_by_name(name)
    json_results = monitoring_interface.contacts.list({name: name})
    contacts = json_results["contacts"]
    if contacts.empty?
      print_red_alert "Contact not found by name #{name}"
      exit 1 # return nil
    elsif contacts.size > 1
      print_red_alert "#{contacts.size} Contacts found by name #{name}"
      print "\n"
      puts as_pretty_table(contacts, [{"ID" => "id" }, {"NAME" => "name"}], {color: red})
      print_red_alert "Try passing ID instead"
      print reset,"\n"
      exit 1 # return nil
    else
      return contacts[0]
    end
  end


  # Monitoring Check Groups

  def find_check_group_by_name_or_id(val)
    if val.to_s =~ /\A\d{1,}\Z/
      return find_check_group_by_id(val)
    else
      return find_check_group_by_name(val)
    end
  end

  def find_check_group_by_id(id)
    begin
      json_response = monitoring_interface.groups.get(id.to_i)
      return json_response['checkGroup']
    rescue RestClient::Exception => e
      if e.response && e.response.code == 404
        print_red_alert "Check Group not found by id #{id}"
        exit 1 # return nil
      else
        raise e
      end
    end
  end

  def find_check_group_by_name(name)
    json_results = monitoring_interface.groups.list({name: name})
    groups = json_results["groups"]
    if groups.empty?
      print_red_alert "Check Group not found by name #{name}"
      exit 1 # return nil
    elsif groups.size > 1
      print_red_alert "#{groups.size} Check Groups found by name #{name}"
      print "\n"
      puts as_pretty_table(groups, [{"ID" => "id" }, {"NAME" => "name"}], {color: red})
      print_red_alert "Try passing ID instead"
      print reset,"\n"
      exit 1 # return nil
    else
      return groups[0]
    end
  end

  # Monitoring apps

  def find_app_by_name_or_id(val)
    if val.to_s =~ /\A\d{1,}\Z/
      return find_app_by_id(val)
    else
      return find_app_by_name(val)
    end
  end

  def find_app_by_id(id)
    begin
      json_response = monitoring_interface.apps.get(id.to_i)
      return json_response['app']
    rescue RestClient::Exception => e
      if e.response && e.response.code == 404
        print_red_alert "Monitor App not found by id #{id}"
        exit 1 # return nil
      else
        raise e
      end
    end
  end

  def find_app_by_name(name)
    json_results = monitoring_interface.apps.list({name: name})
    apps = json_results["apps"]
    if apps.empty?
      print_red_alert "Monitor App not found by name #{name}"
      exit 1 # return nil
    elsif apps.size > 1
      print_red_alert "#{apps.size} apps found by name #{name}"
      print "\n"
      puts as_pretty_table(apps, [{"ID" => "id" }, {"NAME" => "name"}], {color: red})
      print_red_alert "Try passing ID instead"
      print reset,"\n"
      exit 1 # return nil
    else
      return apps[0]
    end
  end


end