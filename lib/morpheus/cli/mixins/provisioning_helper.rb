require 'morpheus/cli/mixins/print_helper'
require 'morpheus/cli/option_types'
# Mixin for Morpheus::Cli command classes
# Provides common methods for provisioning instances
module Morpheus::Cli::ProvisioningHelper

  def self.included(klass)
    klass.send :include, Morpheus::Cli::PrintHelper
  end

  def api_client
    raise "#{self.class} has not defined @api_client" if @api_client.nil?
    @api_client
  end

  def instances_interface
    # @api_client.instances
    raise "#{self.class} has not defined @instances_interface" if @instances_interface.nil?
    @instances_interface
  end

  def options_interface
    # @api_client.options
    raise "#{self.class} has not defined @options_interface" if @options_interface.nil?
    @options_interface
  end

  def instance_types_interface
    # @api_client.instance_types
    raise "#{self.class} has not defined @instance_types_interface" if @instance_types_interface.nil?
    @instance_types_interface
  end

  def get_available_groups(refresh=false)
    if !@available_groups || refresh
      option_results = options_interface.options_for_source('groups',{})
      @available_groups = option_results['data'].collect {|it|
        {"id" => it["value"], "name" => it["name"], "value" => it["value"]}
      }
    end
    #puts "get_available_groups() rtn: #{@available_groups.inspect}"
    return @available_groups
  end

  def get_available_clouds(group_id, refresh=false)
    if !group_id
      option_results = options_interface.options_for_source('clouds', {})
      return option_results['data'].collect {|it|
        {"id" => it["value"], "name" => it["name"], "value" => it["value"], "zoneTypeId" => it["zoneTypeId"]}
      }
    end
    group = find_group_by_id_for_provisioning(group_id)
    if !group
      return []
    end
    if !group["clouds"] || refresh
      option_results = options_interface.options_for_source('clouds', {groupId: group_id})
      group["clouds"] = option_results['data'].collect {|it|
        {"id" => it["value"], "name" => it["name"], "value" => it["value"], "zoneTypeId" => it["zoneTypeId"]}
      }
    end
    return group["clouds"]
  end

  def find_group_by_id_for_provisioning(val)
    groups = get_available_groups()
    group = groups.find {|it| it["id"].to_s == val.to_s }
    if !group
      print_red_alert "Group not found by id #{val}"
      exit 1
    end
    return group
  end

  def find_group_by_name_for_provisioning(val)
    groups = get_available_groups()
    group = groups.find {|it| it["name"].to_s.downcase == val.to_s.downcase }
    if !group
      print_red_alert "Group not found by name #{val}"
      exit 1
    end
    return group
  end

  def find_group_by_name_or_id_for_provisioning(val)
    if val.to_s =~ /\A\d{1,}\Z/
      return find_group_by_id_for_provisioning(val)
    else
      return find_group_by_name_for_provisioning(val)
    end
  end

  def find_cloud_by_id_for_provisioning(group_id, val)
    clouds = get_available_clouds(group_id)
    cloud = clouds.find {|it| it["id"].to_s == val.to_s }
    if !cloud
      print_red_alert "Cloud not found by id #{val}"
      exit 1
    end
    return cloud
  end

  def find_cloud_by_name_for_provisioning(group_id, val)
    clouds = get_available_clouds(group_id)
    cloud = clouds.find {|it| it["name"].to_s.downcase == val.to_s.downcase }
    if !cloud
      print_red_alert "Cloud not found by name #{val}"
      exit 1
    end
    return cloud
  end

  def find_cloud_by_name_or_id_for_provisioning(group_id, val)
    if val.to_s =~ /\A\d{1,}\Z/
      return find_cloud_by_id_for_provisioning(group_id, val)
    else
      return find_cloud_by_name_for_provisioning(group_id, val)
    end
  end

  def find_instance_type_by_id(id)
    begin
      json_response = instance_types_interface.get(id.to_i)
      return json_response['instanceType']
    rescue RestClient::Exception => e
      if e.response && e.response.code == 404
        print_red_alert "Instance Type not found by id #{id}"
        return nil
      else
        raise e
      end
    end
  end

  def find_instance_type_by_code(code)
    results = instance_types_interface.list({code: code})
    instance_types = results['instanceTypes']
    if instance_types.empty?
      print_red_alert "Instance Type not found by code #{code}"
      return nil
    end
    if instance_types.size() > 1
      print as_pretty_table(instance_types, [:id,:name,:code], {color:red})
      print_red_alert "Try using ID instead"
      return nil
    end
    # return instance_types[0]
    # fetch by ID to get full details
    # could also use ?details-true with search
    return find_instance_type_by_id(instance_types[0]['id'])
  end

  def find_instance_type_by_name(name)
    results = instance_types_interface.list({name: name})
    instance_types = results['instanceTypes']
    if instance_types.empty?
      print_red_alert "Instance Type not found by name #{name}"
      return nil
    end
    if instance_types.size() > 1
      print as_pretty_table(instance_types, [:id,:name,:code], {color:red})
      print_red_alert "Try using ID instead"
      return nil
    end
    # return instance_types[0]
    # fetch by ID to get full details
    # could also use ?details-true with search
    return find_instance_type_by_id(instance_types[0]['id'])
  end

  def find_instance_type_by_name_or_id(val)
    if val.to_s =~ /\A\d{1,}\Z/
      return find_instance_type_by_id(val)
    else
      return find_instance_type_by_name(val)
    end
  end

  def find_instance_by_name_or_id(val)
    if val.to_s =~ /\A\d{1,}\Z/
      return find_instance_by_id(val)
    else
      return find_instance_by_name(val)
    end
  end

  def find_instance_by_id(id)
    begin
      json_response = instances_interface.get(id.to_i)
      return json_response['instance']
    rescue RestClient::Exception => e
      if e.response && e.response.code == 404
        print_red_alert "Instance not found by id #{id}"
        exit 1
      else
        raise e
      end
    end
  end

  def find_instance_by_name(name)
    json_results = instances_interface.get({name: name.to_s})
    if json_results['instances'].empty?
      print_red_alert "Instance not found by name #{name}"
      exit 1
    end
    instance = json_results['instances'][0]
    return instance
  end

  # prompts user for all the configuartion options for a particular instance
  # returns payload of data for a new instance
  def prompt_new_instance(options={})
    #puts "prompt_new_instance() #{options}"
    print reset # clear colors
    options[:options] ||= {}
    # Group
    group_id = nil
    group = options[:group] ? find_group_by_name_or_id_for_provisioning(options[:group]) : nil
    if group
      group_id = group["id"]
    else
      # print_red_alert "Group not found or specified!"
      # exit 1
      group_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldName' => 'group', 'type' => 'select', 'fieldLabel' => 'Group', 'selectOptions' => get_available_groups(), 'required' => true, 'description' => 'Select Group.'}],options[:options],api_client,{})
      group_id = group_prompt['group']
    end

    # Cloud
    cloud_id = nil
    cloud = options[:cloud] ? find_cloud_by_name_or_id_for_provisioning(group_id, options[:cloud]) : nil
    if cloud
      cloud_id = cloud["id"]
    else
      # print_red_alert "Cloud not specified!"
      # exit 1
      available_clouds = get_available_clouds(group_id)
      cloud_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldName' => 'cloud', 'type' => 'select', 'fieldLabel' => 'Cloud', 'selectOptions' => get_available_clouds(group_id), 'required' => true, 'description' => 'Select Cloud.', 'defaultValue' => options[:default_cloud] ? options[:default_cloud] : nil}],options[:options],api_client,{groupId: group_id})
      cloud_id = cloud_prompt['cloud']
      cloud = available_clouds.find {|it| it['id'] == cloud_id.to_i || it['name'] == cloud_id.to_s }
    end
    # Instance Type
    instance_type_code = nil
    if options[:instance_type_code]
      instance_type_code = options[:instance_type_code]
    else
      instance_type_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldName' => 'type', 'type' => 'select', 'fieldLabel' => 'Type', 'optionSource' => 'instanceTypes', 'required' => true, 'description' => 'Select Instance Type.'}],options[:options],api_client,{groupId: group_id})
      instance_type_code = instance_type_prompt['type']
    end
    if instance_type_code.to_s =~ /\A\d{1,}\Z/
      instance_type = find_instance_type_by_id(instance_type_code)
    else
      instance_type = find_instance_type_by_code(instance_type_code)
    end
    exit 1 if !instance_type

    # Instance Name
    instance_name = nil
    if options[:instance_name]
      options[:options]['name'] = options[:instance_name]
    elsif options[:options]['instance'] && options[:options]['instance']['name']
      options[:options]['name'] = options[:options]['instance']['name']
    end
    name_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldName' => 'name', 'fieldLabel' => 'Instance Name', 'type' => 'text', 'required' => options[:name_required]}], options[:options])
    instance_name = name_prompt['name']
    

    payload = {
      'zoneId' => cloud_id,
      # 'siteId' => siteId,
      'instance' => {
        'name' => instance_name,
        'cloud' => cloud['name'],
        'site' => {
          'id' => group_id
        },
        'type' => instance_type_code,
        'instanceType' => {
          'code' => instance_type_code
        }
      }
    }

    # allow arbitrary -O values passed by the user
    if options[:options]
      arbitrary_options = (options[:options] || {}).reject {|k,v| k.is_a?(Symbol) }
      # remove some things that are being prompted for
      arbitrary_options.delete('group')
      arbitrary_options.delete('cloud')
      arbitrary_options.delete('type')
      arbitrary_options.delete('name')
      arbitrary_options.delete('version')
      arbitrary_options.delete('layout')
      arbitrary_options.delete('servicePlan')
      arbitrary_options.delete('description')
      arbitrary_options.delete('environment')
      arbitrary_options.delete('instanceContext')
      arbitrary_options.delete('tags')
      payload.deep_merge!(arbitrary_options)
    end

    # Description
    if options[:description]
      options[:options]['description'] = options[:description]
    end
    v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldName' => 'description', 'fieldLabel' => 'Description', 'type' => 'text', 'required' => false}], options[:options])
    payload['instance']['description'] = v_prompt['description'] if !v_prompt['description'].empty?

    # Environment
    if options[:environment]
      options[:options]['environment'] = options[:environment]
    elsif options[:options]['instanceContext'] && !options[:options]['environment']
      options[:options]['environment'] = options[:options]['instanceContext']
    end
    v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldName' => 'environment', 'fieldLabel' => 'Environment', 'type' => 'select', 'required' => false, 'selectOptions' => get_available_environments()}], options[:options])
    payload['instance']['instanceContext'] = v_prompt['environment'] if !v_prompt['environment'].empty?

    # Tags
    v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldName' => 'tags', 'fieldLabel' => 'Tags', 'type' => 'text', 'required' => false}], options[:options])
    payload['instance']['tags'] = v_prompt['tags'].split(',').collect {|it| it.to_s.strip }.compact.uniq if !v_prompt['tags'].empty?

    # Version and Layout

    available_versions = options_interface.options_for_source('instanceVersions',{groupId: group_id, cloudId: cloud_id, instanceTypeId: instance_type['id']})['data']
    default_version_value = payload['instance']['version'] ? payload['instance']['version'] : payload['version']
    default_layout_value = payload['instance']['layout'] ? payload['instance']['layout'] : payload['layout']
    if default_layout_value && default_layout_value.is_a?(Hash)
      default_layout_value = default_layout_value['id']
    end
    # JD: version is always nil because it is not stored in the blueprint or config !!
    # so for now, infer the version from the layout
    # requires api 3.6.2 to get "layouts" from /options/versions
    if default_layout_value && default_version_value.to_s.empty?
      available_versions.each do |available_version|
        if available_version["layouts"]
          selected_layout = available_version["layouts"].find {|it| it["value"].to_s == default_layout_value.to_s || it["id"].to_s == default_layout_value.to_s || it["code"].to_s == default_layout_value.to_s }
          if selected_layout
            default_version_value = available_version["value"]
            break
          end
        end
      end
    end

    # do not require version if a layout is passed
    version_value = default_version_value
    version_is_required = default_layout_value.nil?
    if default_layout_value.nil? && options[:options]["layout"].nil? && options[:always_prompt] != true
      #version_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldName' => 'version', 'type' => 'select', 'fieldLabel' => 'Version', 'optionSource' => 'instanceVersions', 'required' => true, 'skipSingleOption' => true, 'autoPickOption' => true, 'description' => 'Select which version of the instance type to be provisioned.', 'defaultValue' => default_version_value}],options[:options],api_client,{groupId: group_id, cloudId: cloud_id, instanceTypeId: instance_type['id']})
      version_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldName' => 'version', 'type' => 'select', 'fieldLabel' => 'Version', 'selectOptions' => available_versions, 'required' => version_is_required, 'skipSingleOption' => true, 'autoPickOption' => true, 'description' => 'Select which version of the instance type to be provisioned.', 'defaultValue' => default_version_value}],options[:options],api_client,{groupId: group_id, cloudId: cloud_id, instanceTypeId: instance_type['id']})
      version_value = version_prompt['version']
    end
    # JD: there is a bug here, the version needs to be passed perhaps? or the optionSource methods need updating...
    # could just allow for now ...
    # if options[:options]["layout"]
    #   layout_id = options[:options]["layout"]
    #   ...
    # end
    layout_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldName' => 'layout', 'type' => 'select', 'fieldLabel' => 'Layout', 'optionSource' => 'layoutsForCloud', 'required' => true, 'description' => 'Select which configuration of the instance type to be provisioned.', 'defaultValue' => default_layout_value}],options[:options],api_client,{groupId: group_id, cloudId: cloud_id, instanceTypeId: instance_type['id'], version: version_value})
    layout_id = layout_prompt['layout']
    layout = instance_type['instanceTypeLayouts'].find{ |lt| lt['id'] == layout_id.to_i}
    if !layout
      print_red_alert "Layout not found by id #{layout_id}"
      exit 1
    end
    payload['instance']['layout'] = {'id' => layout['id']}

    # prompt for service plan
    service_plans_json = @instances_interface.service_plans({zoneId: cloud_id, layoutId: layout_id, siteId: group_id})
    service_plans = service_plans_json["plans"]
    service_plans_dropdown = service_plans.collect {|sp| {'name' => sp["name"], 'value' => sp["id"], 'code' => sp['code']} } # already sorted
    default_plan = nil
    if payload['plan']
      default_plan = payload['plan']
    elsif payload['instance'] && payload['instance']['plan']
      default_plan = payload['instance']['plan']
    end
    default_plan_value = default_plan.is_a?(Hash) ? default_plan['id'] : default_plan
    plan_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldName' => 'servicePlan', 'type' => 'select', 'fieldLabel' => 'Plan', 'selectOptions' => service_plans_dropdown, 'required' => true, 'description' => 'Choose the appropriately sized plan for this instance', 'defaultValue' => default_plan_value}],options[:options])
    plan_id = plan_prompt['servicePlan']
    service_plan = service_plans.find {|sp| sp["id"] == plan_id.to_i }
    if !service_plan
      print_red_alert "Plan not found by id #{plan_id}"
      exit 1
    end
    #todo: consolidate these, instances api looks for instance.plan.id and apps looks for plan.id
    payload['plan'] = {'id' => service_plan["id"], 'code' => service_plan["code"], 'name' => service_plan["name"]}
    payload['instance']['plan'] = {'id' => service_plan["id"], 'code' => service_plan["code"], 'name' => service_plan["name"]}

    # prompt for resource pool
    has_zone_pools = layout["provisionType"] && layout["provisionType"]["id"] && layout["provisionType"]["hasZonePools"]
    if has_zone_pools
      resource_pool_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => 'config', 'fieldName' => 'resourcePoolId', 'type' => 'select', 'fieldLabel' => 'Resource Pool', 'optionSource' => 'zonePools', 'required' => true, 'skipSingleOption' => true, 'description' => 'Select resource pool.'}],options[:options],api_client,{groupId: group_id, siteId: group_id, zoneId: cloud_id, cloudId: cloud_id, instanceTypeId: instance_type['id'], planId: service_plan["id"], layoutId: layout["id"]})
      if resource_pool_prompt['config'] && resource_pool_prompt['config']['resourcePoolId']
        payload['config'] ||= {}
        payload['config']['resourcePoolId'] = resource_pool_prompt['config']['resourcePoolId']
      end
    end

    # plan_info has this property already..
    # has_datastore = layout["provisionType"] && layout["provisionType"]["id"] && layout["provisionType"]["hasDatastore"]
    # service_plan['hasDatastore'] = has_datastore

    # prompt for volumes
    # if payload['volumes'].nil?
      volumes = prompt_volumes(service_plan, options, api_client, {zoneId: cloud_id, layoutId: layout_id, siteId: group_id})
      if !volumes.empty?
        payload['volumes'] = volumes
      end
    # end

    # if payload['networkInterfaces'].nil?
      if layout["provisionType"] && layout["provisionType"]["id"] && layout["provisionType"]["hasNetworks"]
        # prompt for network interfaces (if supported)
        begin
          network_interfaces = prompt_network_interfaces(cloud_id, layout["provisionType"]["id"], options)
          if !network_interfaces.empty?
            payload['networkInterfaces'] = network_interfaces
          end
        rescue RestClient::Exception => e
          print yellow,"Unable to load network options. Proceeding...",reset,"\n"
          print_rest_exception(e, options) if Morpheus::Logging.debug?
        end
      end
    # end

    # build option types
    option_type_list = []
    if !layout['optionTypes'].nil? && !layout['optionTypes'].empty?
      option_type_list += layout['optionTypes']
    end
    if !instance_type['optionTypes'].nil? && !instance_type['optionTypes'].empty?
      option_type_list += instance_type['optionTypes']
    end
    if !layout['provisionType'].nil? && !layout['provisionType']['optionTypes'].nil? && !layout['provisionType']['optionTypes'].empty?
      option_type_list += layout['provisionType']['optionTypes']
    end
    if !payload['volumes'].empty?
      option_type_list = reject_volume_option_types(option_type_list)
    end
    # remove networkId option if networks were configured above
    if !payload['networkInterfaces'].empty?
      option_type_list = reject_networking_option_types(option_type_list)
    end
    # remove resourcePoolId if it was configured above
    if has_zone_pools
      option_type_list = option_type_list.reject {|opt| ['resourcePool','resourcePoolId','azureResourceGroupId'].include?(opt['fieldName']) }
    end

    instance_config_payload = Morpheus::Cli::OptionTypes.prompt(option_type_list, options[:options], @api_client, {groupId: group_id, cloudId: cloud_id, zoneId: cloud_id, instanceTypeId: instance_type['id'], version: version_value})
    payload.deep_merge!(instance_config_payload)

    # Security Groups
    # ((opt['code'] == 'provisionType.amazon.securityId') ||(opt['name'] == 'config.securityId'))


    ## Advanced Options

    # scale factor


    # prompt for environment variables
    evars = prompt_evars(options)
    if !evars.empty?
      payload['evars'] = evars
    end

    # prompt for metadata variables
    metadata = prompt_metadata(options)
    if !metadata.empty?
      payload['metadata'] = metadata
    end

    return payload
  end

  # This recreates the behavior of multi_disk.js
  # returns array of volumes based on service plan options (plan_info)
  def prompt_volumes(plan_info, options={}, api_client=nil, api_params={})
    #puts "Configure Volumes:"
    no_prompt = (options[:no_prompt] || (options[:options] && options[:options][:no_prompt]))

    volumes = []

    plan_size = nil
    if plan_info['maxStorage']
      plan_size = plan_info['maxStorage'].to_i / (1024 * 1024 * 1024)
    end

    root_storage_types = []
    if plan_info['rootStorageTypes']
      plan_info['rootStorageTypes'].each do |opt|
        if !opt.nil?
          root_storage_types << {'name' => opt['name'], 'value' => opt['id']}
        end
      end
    end

    storage_types = []
    if plan_info['storageTypes']
      plan_info['storageTypes'].each do |opt|
        if !opt.nil?
          storage_types << {'name' => opt['name'], 'value' => opt['id']}
        end
      end
    end

    datastore_options = []
    if plan_info['supportsAutoDatastore']
      if plan_info['autoOptions']
        plan_info['autoOptions'].each do |opt|
          if !opt.nil?
            datastore_options << {'name' => opt['name'], 'value' => opt['id']}
          end
        end
      end
    end
    if plan_info['datastores']
      plan_info['datastores'].each do |k, v|
        v.each do |opt|
          if !opt.nil?
            datastore_options << {'name' => "#{k}: #{opt['name']}", 'value' => opt['id']}
          end
        end
      end
    end
    # api does not always return datastores, so go get them if needed..
    if plan_info['hasDatastore'] && datastore_options.empty?
      option_results = options_interface.options_for_source('datastores', api_params)
      option_results['data'].each do |it|
          datastore_options << {"id" => it["value"] || it["id"], "name" => it["name"], "value" => it["value"] || it["id"]}
      end
    end

    #puts "Configure Root Volume"

    field_context = "rootVolume"

    volume_label = 'root'
    volume = {
      'id' => -1,
      'rootVolume' => true,
      'name' => volume_label,
      'size' => plan_size,
      'sizeId' => nil,
      'storageType' => nil,
      'datastoreId' => nil
    }
    if options[:options] && options[:options]['volumes'] && options[:options]['volumes'][0]
      volume = options[:options]['volumes'][0]
    end

    if root_storage_types.empty?
      # this means there's no configuration, just send a single root volume to the server
      storage_type_id = nil
      storage_type = nil
    else
      v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'storageType', 'type' => 'select', 'fieldLabel' => 'Root Storage Type', 'selectOptions' => root_storage_types, 'required' => true, 'skipSingleOption' => true, 'description' => 'Choose a storage type.', 'defaultValue' => volume['storageType']}], options[:options])
      storage_type_id = v_prompt[field_context]['storageType']
      storage_type = plan_info['storageTypes'].find {|i| i['id'] == storage_type_id.to_i }
      volume['storageType'] = storage_type_id
    end

    # sometimes the user chooses sizeId from a list of size options (AccountPrice) and other times it is free form
    root_custom_size_options = []
    if plan_info['rootCustomSizeOptions'] && plan_info['rootCustomSizeOptions'][storage_type_id.to_s]
      plan_info['rootCustomSizeOptions'][storage_type_id.to_s].each do |opt|
        if !opt.nil?
          root_custom_size_options << {'name' => opt['value'], 'value' => opt['key']}
        end
      end
    end

    if plan_info['rootDiskCustomizable'] && storage_type && storage_type['customLabel']
      v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'name', 'type' => 'text', 'fieldLabel' => 'Root Volume Label', 'required' => true, 'description' => 'Enter a volume label.', 'defaultValue' => volume['name']}], options[:options])
      volume['name'] = v_prompt[field_context]['name']
    end
    if plan_info['rootDiskCustomizable'] && storage_type && storage_type['customSize']
      if root_custom_size_options.empty?
        v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'size', 'type' => 'number', 'fieldLabel' => 'Root Volume Size (GB)', 'required' => true, 'description' => 'Enter a volume size (GB).', 'defaultValue' => volume['size']}], options[:options])
        volume['size'] = v_prompt[field_context]['size']
        volume['sizeId'] = nil #volume.delete('sizeId')
      else
        v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'sizeId', 'type' => 'select', 'fieldLabel' => 'Root Volume Size', 'selectOptions' => root_custom_size_options, 'required' => true, 'description' => 'Choose a volume size.', 'defaultValue' => volume['sizeId']}], options[:options])
        volume['sizeId'] = v_prompt[field_context]['sizeId']
        volume['size'] = nil #volume.delete('size')
      end
    else
      # might need different logic here ? =o
      #volume['size'] = plan_size
      #volume['sizeId'] = nil #volume.delete('sizeId')
    end
    if !datastore_options.empty?
      v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'datastoreId', 'type' => 'select', 'fieldLabel' => 'Root Datastore', 'selectOptions' => datastore_options, 'required' => true, 'description' => 'Choose a datastore.', 'defaultValue' => volume['datastoreId']}], options[:options])
      volume['datastoreId'] = v_prompt[field_context]['datastoreId']
    end

    volumes << volume

    if plan_info['addVolumes']
      volume_index = 1
      has_another_volume = (options[:options] && options[:options]["dataVolume#{volume_index}"]) || (options[:options] && options[:options]['volumes'] && options[:options]['volumes'][volume_index])
      add_another_volume = has_another_volume || (!no_prompt && Morpheus::Cli::OptionTypes.confirm("Add data volume?", {:default => false}))
      while add_another_volume do
          #puts "Configure Data #{volume_index} Volume"

          field_context = "dataVolume#{volume_index}"

          volume_label = (volume_index == 1 ? 'data' : "data #{volume_index}")
          volume = {
            #'id' => -1,
            'rootVolume' => false,
            'name' => volume_label,
            'size' => plan_size,
            'sizeId' => nil,
            'storageType' => nil,
            'datastoreId' => nil
          }
          if options[:options] && options[:options]['volumes'] && options[:options]['volumes'][volume_index]
            volume = options[:options]['volumes'][volume_index]
          end

          v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'storageType', 'type' => 'select', 'fieldLabel' => "Disk #{volume_index} Storage Type", 'selectOptions' => storage_types, 'required' => true, 'skipSingleOption' => true, 'description' => 'Choose a storage type.', 'defaultValue' => volume['storageType']}], options[:options])
          storage_type_id = v_prompt[field_context]['storageType']
          volume['storageType'] = storage_type_id
          storage_type = plan_info['storageTypes'].find {|i| i['id'] == storage_type_id.to_i }

          # sometimes the user chooses sizeId from a list of size options (AccountPrice) and other times it is free form
          custom_size_options = []
          if plan_info['customSizeOptions'] && plan_info['customSizeOptions'][storage_type_id.to_s]
            plan_info['customSizeOptions'][storage_type_id.to_s].each do |opt|
              if !opt.nil?
                custom_size_options << {'name' => opt['value'], 'value' => opt['key']}
              end
            end
          end

          if plan_info['customizeVolume'] && storage_type['customLabel']
            v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'name', 'type' => 'text', 'fieldLabel' => "Disk #{volume_index} Volume Label", 'required' => true, 'description' => 'Enter a volume label.', 'defaultValue' => volume['name']}], options[:options])
            volume['name'] = v_prompt[field_context]['name']
          end
          if plan_info['customizeVolume'] && storage_type['customSize']
            if custom_size_options.empty?
              v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'size', 'type' => 'number', 'fieldLabel' => "Disk #{volume_index} Volume Size (GB)", 'required' => true, 'description' => 'Enter a volume size (GB).', 'defaultValue' => volume['size']}], options[:options])
              volume['size'] = v_prompt[field_context]['size']
              volume['sizeId'] = nil #volume.delete('sizeId')
            else
              v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'sizeId', 'type' => 'select', 'fieldLabel' => "Disk #{volume_index} Volume Size", 'selectOptions' => custom_size_options, 'required' => true, 'description' => 'Choose a volume size.', 'defaultValue' => volume['sizeId']}], options[:options])
              volume['sizeId'] = v_prompt[field_context]['sizeId']
              volume['size'] = nil #volume.delete('size')
            end
          else
            # might need different logic here ? =o
            volume['size'] = plan_size
            volume['sizeId'] = nil #volume.delete('sizeId')
          end
          if !datastore_options.empty?
            v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'datastoreId', 'type' => 'select', 'fieldLabel' => "Disk #{volume_index} Datastore", 'selectOptions' => datastore_options, 'required' => true, 'description' => 'Choose a datastore.', 'defaultValue' => volume['datastoreId']}], options[:options])
            volume['datastoreId'] = v_prompt[field_context]['datastoreId']
          end

          volumes << volume

          volume_index += 1
          if options[:options] && options[:options]['volumes'] && options[:options]['volumes'][volume_index]
            add_another_volume = true
          elsif plan_info['maxDisk'] && volume_index >= plan_info['maxDisk']
            # todo: should maxDisk check consider the root volume too?
            add_another_volume = false
          else
            has_another_volume = options[:options] && options[:options]["dataVolume#{volume_index}"]
            add_another_volume = has_another_volume || (!no_prompt && Morpheus::Cli::OptionTypes.confirm("Add another data volume?", {:default => false}))
          end

        end

      end

      return volumes
    end


    # This recreates the behavior of multi_disk.js
    # returns array of volumes based on service plan options (plan_info)
    def prompt_resize_volumes(current_volumes, plan_info, options={})
      #puts "Configure Volumes:"
      no_prompt = (options[:no_prompt] || (options[:options] && options[:options][:no_prompt]))

      current_root_volume = current_volumes[0]

      volumes = []

      plan_size = nil
      if plan_info['maxStorage']
        plan_size = plan_info['maxStorage'].to_i / (1024 * 1024 * 1024)
      end

      root_storage_types = []
      if plan_info['rootStorageTypes']
        plan_info['rootStorageTypes'].each do |opt|
          if !opt.nil?
            root_storage_types << {'name' => opt['name'], 'value' => opt['id']}
          end
        end
      end

      storage_types = []
      if plan_info['storageTypes']
        plan_info['storageTypes'].each do |opt|
          if !opt.nil?
            storage_types << {'name' => opt['name'], 'value' => opt['id']}
          end
        end
      end

      datastore_options = []
      if plan_info['supportsAutoDatastore']
        if plan_info['autoOptions']
          plan_info['autoOptions'].each do |opt|
            if !opt.nil?
              datastore_options << {'name' => opt['name'], 'value' => opt['id']}
            end
          end
        end
      end
      if plan_info['datastores']
        plan_info['datastores'].each do |k, v|
          v.each do |opt|
            if !opt.nil?
              datastore_options << {'name' => "#{k}: #{opt['name']}", 'value' => opt['id']}
            end
          end
        end
      end

      #puts "Configure Root Volume"

      field_context = "rootVolume"

      if root_storage_types.empty?
        # this means there's no configuration, just send a single root volume to the server
        storage_type_id = nil
        storage_type = nil
      else
        #v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'storageType', 'type' => 'select', 'fieldLabel' => 'Root Storage Type', 'selectOptions' => root_storage_types, 'required' => true, 'skipSingleOption' => true, 'description' => 'Choose a storage type.'}], options[:options])
        #storage_type_id = v_prompt[field_context]['storageType']
        storage_type_id = current_root_volume['type'] || current_root_volume['storageType']
        storage_type = plan_info['storageTypes'].find {|i| i['id'] == storage_type_id.to_i }
      end

      # sometimes the user chooses sizeId from a list of size options (AccountPrice) and other times it is free form
      root_custom_size_options = []
      if plan_info['rootCustomSizeOptions'] && plan_info['rootCustomSizeOptions'][storage_type_id.to_s]
        plan_info['rootCustomSizeOptions'][storage_type_id.to_s].each do |opt|
          if !opt.nil?
            root_custom_size_options << {'name' => opt['value'], 'value' => opt['key']}
          end
        end
      end

      volume = {
        'id' => current_root_volume['id'],
        'rootVolume' => true,
        'name' => current_root_volume['name'],
        'size' => current_root_volume['size'] > plan_size ? current_root_volume['size'] : plan_size,
        'sizeId' => nil,
        'storageType' => storage_type_id,
        'datastoreId' => current_root_volume['datastoreId']
      }

      if plan_info['rootDiskCustomizable'] && storage_type && storage_type['customLabel']
        v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'name', 'type' => 'text', 'fieldLabel' => 'Root Volume Label', 'required' => true, 'description' => 'Enter a volume label.', 'defaultValue' => volume['name']}], options[:options])
        volume['name'] = v_prompt[field_context]['name']
      end
      if plan_info['rootDiskCustomizable'] && storage_type && storage_type['customSize']
        if root_custom_size_options.empty?
          v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'size', 'type' => 'number', 'fieldLabel' => 'Root Volume Size (GB)', 'required' => true, 'description' => 'Enter a volume size (GB).', 'defaultValue' => volume['size']}], options[:options])
          volume['size'] = v_prompt[field_context]['size']
          volume['sizeId'] = nil #volume.delete('sizeId')
        else
          v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'sizeId', 'type' => 'select', 'fieldLabel' => 'Root Volume Size', 'selectOptions' => root_custom_size_options, 'required' => true, 'description' => 'Choose a volume size.'}], options[:options])
          volume['sizeId'] = v_prompt[field_context]['sizeId']
          volume['size'] = nil #volume.delete('size')
        end
      else
        # might need different logic here ? =o
        volume['size'] = plan_size
        volume['sizeId'] = nil #volume.delete('sizeId')
      end
      # if !datastore_options.empty?
      #   v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'datastoreId', 'type' => 'select', 'fieldLabel' => 'Root Datastore', 'selectOptions' => datastore_options, 'required' => true, 'description' => 'Choose a datastore.'}], options[:options])
      #   volume['datastoreId'] = v_prompt[field_context]['datastoreId']
      # end

      volumes << volume

      # modify or delete existing data volumes
      (1..(current_volumes.size-1)).each do |volume_index|
        current_volume = current_volumes[volume_index]
        if current_volume

          field_context = "dataVolume#{volume_index}"

          if no_prompt
            volume_action = 'keep'
          else
            action_options = [{'name' => 'Modify', 'value' => 'modify'}, {'name' => 'Keep', 'value' => 'keep'}, {'name' => 'Delete', 'value' => 'delete'}]
            v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'action', 'type' => 'select', 'fieldLabel' => "Modify/Keep/Delete volume '#{current_volume['name']}'", 'selectOptions' => action_options, 'required' => true, 'description' => 'Modify, Keep or Delete existing data volume?'}], options[:options])
            volume_action = v_prompt[field_context]['action']
          end

          if volume_action == 'delete'
            # deleted volume is just excluded from post params
            next
          elsif volume_action == 'keep'
            volume = {
              'id' => current_volume['id'].to_i,
              'rootVolume' => false,
              'name' => current_volume['name'],
              'size' => current_volume['size'] > plan_size ? current_volume['size'] : plan_size,
              'sizeId' => nil,
              'storageType' => (current_volume['type'] || current_volume['storageType']),
              'datastoreId' => current_volume['datastoreId']
            }
            volumes << volume
          else
            # v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'storageType', 'type' => 'select', 'fieldLabel' => "Disk #{volume_index} Storage Type", 'selectOptions' => storage_types, 'required' => true, 'skipSingleOption' => true, 'description' => 'Choose a storage type.'}], options[:options])
            # storage_type_id = v_prompt[field_context]['storageType']
            storage_type_id = current_volume['type'] || current_volume['storageType']
            storage_type = plan_info['storageTypes'].find {|i| i['id'] == storage_type_id.to_i }
            # sometimes the user chooses sizeId from a list of size options (AccountPrice) and other times it is free form
            custom_size_options = []
            if plan_info['customSizeOptions'] && plan_info['customSizeOptions'][storage_type_id.to_s]
              plan_info['customSizeOptions'][storage_type_id.to_s].each do |opt|
                if !opt.nil?
                  custom_size_options << {'name' => opt['value'], 'value' => opt['key']}
                end
              end
            end

            volume = {
              'id' => current_volume['id'].to_i,
              'rootVolume' => false,
              'name' => current_volume['name'],
              'size' => current_volume['size'] > plan_size ? current_volume['size'] : plan_size,
              'sizeId' => nil,
              'storageType' => (current_volume['type'] || current_volume['storageType']),
              'datastoreId' => current_volume['datastoreId']
            }

            if plan_info['customizeVolume'] && storage_type['customLabel']
              v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'name', 'type' => 'text', 'fieldLabel' => "Disk #{volume_index} Volume Label", 'required' => true, 'description' => 'Enter a volume label.', 'defaultValue' => volume['name']}], options[:options])
              volume['name'] = v_prompt[field_context]['name']
            end
            if plan_info['customizeVolume'] && storage_type['customSize']
              if custom_size_options.empty?
                v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'size', 'type' => 'number', 'fieldLabel' => "Disk #{volume_index} Volume Size (GB)", 'required' => true, 'description' => 'Enter a volume size (GB).', 'defaultValue' => volume['size']}], options[:options])
                volume['size'] = v_prompt[field_context]['size']
                volume['sizeId'] = nil #volume.delete('sizeId')
              else
                v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'sizeId', 'type' => 'select', 'fieldLabel' => "Disk #{volume_index} Volume Size", 'selectOptions' => custom_size_options, 'required' => true, 'description' => 'Choose a volume size.'}], options[:options])
                volume['sizeId'] = v_prompt[field_context]['sizeId']
                volume['size'] = nil #volume.delete('size')
              end
            else
              # might need different logic here ? =o
              volume['size'] = plan_size
              volume['sizeId'] = nil #volume.delete('sizeId')
            end
            # if !datastore_options.empty?
            #   v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'datastoreId', 'type' => 'select', 'fieldLabel' => "Disk #{volume_index} Datastore", 'selectOptions' => datastore_options, 'required' => true, 'description' => 'Choose a datastore.'}], options[:options])
            #   volume['datastoreId'] = v_prompt[field_context]['datastoreId']
            # end

            volumes << volume

          end

        end
      end


      if plan_info['addVolumes']
        volume_index = current_volumes.size
        has_another_volume = options[:options] && options[:options]["dataVolume#{volume_index}"]
        add_another_volume = has_another_volume || (!no_prompt && Morpheus::Cli::OptionTypes.confirm("Add data volume?"))
        while add_another_volume do
            #puts "Configure Data #{volume_index} Volume"

            field_context = "dataVolume#{volume_index}"

            v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'storageType', 'type' => 'select', 'fieldLabel' => "Disk #{volume_index} Storage Type", 'selectOptions' => storage_types, 'required' => true, 'skipSingleOption' => true, 'description' => 'Choose a storage type.'}], options[:options])
            storage_type_id = v_prompt[field_context]['storageType']
            storage_type = plan_info['storageTypes'].find {|i| i['id'] == storage_type_id.to_i }

            # sometimes the user chooses sizeId from a list of size options (AccountPrice) and other times it is free form
            custom_size_options = []
            if plan_info['customSizeOptions'] && plan_info['customSizeOptions'][storage_type_id.to_s]
              plan_info['customSizeOptions'][storage_type_id.to_s].each do |opt|
                if !opt.nil?
                  custom_size_options << {'name' => opt['value'], 'value' => opt['key']}
                end
              end
            end

            volume_label = (volume_index == 1 ? 'data' : "data #{volume_index}")
            volume = {
              'id' => -1,
              'rootVolume' => false,
              'name' => volume_label,
              'size' => plan_size,
              'sizeId' => nil,
              'storageType' => storage_type_id,
              'datastoreId' => nil
            }

            if plan_info['customizeVolume'] && storage_type['customLabel']
              v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'name', 'type' => 'text', 'fieldLabel' => "Disk #{volume_index} Volume Label", 'required' => true, 'description' => 'Enter a volume label.', 'defaultValue' => volume_label}], options[:options])
              volume['name'] = v_prompt[field_context]['name']
            end
            if plan_info['customizeVolume'] && storage_type['customSize']
              if custom_size_options.empty?
                v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'size', 'type' => 'number', 'fieldLabel' => "Disk #{volume_index} Volume Size (GB)", 'required' => true, 'description' => 'Enter a volume size (GB).', 'defaultValue' => plan_size}], options[:options])
                volume['size'] = v_prompt[field_context]['size']
                volume['sizeId'] = nil #volume.delete('sizeId')
              else
                v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'sizeId', 'type' => 'select', 'fieldLabel' => "Disk #{volume_index} Volume Size", 'selectOptions' => custom_size_options, 'required' => true, 'description' => 'Choose a volume size.'}], options[:options])
                volume['sizeId'] = v_prompt[field_context]['sizeId']
                volume['size'] = nil #volume.delete('size')
              end
            else
              # might need different logic here ? =o
              volume['size'] = plan_size
              volume['sizeId'] = nil #volume.delete('sizeId')
            end
            if !datastore_options.empty?
              v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'datastoreId', 'type' => 'select', 'fieldLabel' => "Disk #{volume_index} Datastore", 'selectOptions' => datastore_options, 'required' => true, 'description' => 'Choose a datastore.'}], options[:options])
              volume['datastoreId'] = v_prompt[field_context]['datastoreId']
            end

            volumes << volume

            # todo: should maxDisk check consider the root volume too?
            if plan_info['maxDisk'] && volume_index >= plan_info['maxDisk']
              add_another_volume = false
            else
              volume_index += 1
              has_another_volume = options[:options] && options[:options]["dataVolume#{volume_index}"]
              add_another_volume = has_another_volume || (!no_prompt && Morpheus::Cli::OptionTypes.confirm("Add another data volume?"))
            end

          end

        end

        return volumes
      end


  # This recreates the behavior of multi_networks.js
  # This is used by both `instances add` and `hosts add`
  # returns array of networkInterfaces based on provision type and cloud settings
  def prompt_network_interfaces(zone_id, provision_type_id, options={})
    #puts "Configure Networks:"
    no_prompt = (options[:no_prompt] || (options[:options] && options[:options][:no_prompt]))
    network_interfaces = []

    zone_network_options_json = api_client.options.options_for_source('zoneNetworkOptions', {zoneId: zone_id, provisionTypeId: provision_type_id})
    # puts "zoneNetworkOptions JSON"
    # puts JSON.pretty_generate(zone_network_options_json)
    zone_network_data = zone_network_options_json['data'] || {}
    networks = zone_network_data['networks']
    network_groups = zone_network_data['networkGroups']
    if network_groups
      networks = network_groups + networks
    end
    network_interface_types = (zone_network_data['networkTypes'] || []).sort { |x,y| x['displayOrder'] <=> y['displayOrder'] }
    enable_network_type_selection = (zone_network_data['enableNetworkTypeSelection'] == 'on' || zone_network_data['enableNetworkTypeSelection'] == true)
    has_networks = zone_network_data["hasNetworks"] == true
    max_networks = (zone_network_data["maxNetworks"].to_i > 0) ? zone_network_data["maxNetworks"].to_i : nil

    # skip unless provision type supports networks
    if !has_networks
      return nil
    end

    # no networks available, shouldn't happen
    if networks.empty?
      return network_interfaces
    end

    network_options = []
    networks.each do |opt|
      if !opt.nil?
        network_options << {'name' => opt['name'], 'value' => opt['id']}
      end
    end

    network_interface_type_options = []
    network_interface_types.each do |opt|
      if !opt.nil?
        network_interface_type_options << {'name' => opt['name'], 'value' => opt['id']}
      end
    end

    interface_index = 0
    add_another_interface = true
    while add_another_interface do
      # if !no_prompt
      #   if interface_index == 0
      #     puts "Configure Network Interface"
      #   else
      #     puts "Configure Network Interface #{interface_index+1}"
      #   end
      # end

      field_context = interface_index == 0 ? "networkInterface" : "networkInterface#{interface_index+1}"
      network_interface = {}
      if options[:options] && options[:options]['networkInterfaces'] && options[:options]['networkInterfaces'][interface_index]
        network_interface = options[:options]['networkInterfaces'][interface_index]
      end

      # choose network
      v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'networkId', 'type' => 'select', 'fieldLabel' => "Network", 'selectOptions' => network_options, 'required' => true, 'skipSingleOption' => false, 'description' => 'Choose a network for this interface.', 'defaultValue' => network_interface['networkId']}], options[:options])
      network_interface['network'] = {}
      network_interface['network']['id'] = v_prompt[field_context]['networkId'].to_s
      selected_network = networks.find {|it| it["id"].to_s == network_interface['network']['id'] }

      if !selected_network
        print_red_alert "Network not found by id #{network_interface['network']['id']}!"
        exit 1
      end

      # choose network interface type
      if enable_network_type_selection && !network_interface_type_options.empty?
        v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'networkInterfaceTypeId', 'type' => 'select', 'fieldLabel' => "Network Interface Type", 'selectOptions' => network_interface_type_options, 'required' => true, 'skipSingleOption' => true, 'description' => 'Choose a network interface type.', 'defaultValue' => network_interface['networkInterfaceTypeId']}], options[:options])
        network_interface['networkInterfaceTypeId'] = v_prompt[field_context]['networkInterfaceTypeId'].to_i
      end

      # choose IP unless network has a pool configured
      ip_required = true
      if selected_network['id'].to_s.include?('networkGroup')
        #puts "IP Address: Using network group." if !no_prompt
        ip_required = false
      elsif selected_network['pool']
        #puts "IP Address: Using pool '#{selected_network['pool']['name']}'" if !no_prompt
        ip_required = false
      elsif selected_network['dhcpServer']
        #puts "IP Address: Using DHCP" if !no_prompt
        ip_required = false
      end
      v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'ipAddress', 'type' => 'text', 'fieldLabel' => "IP Address", 'required' => ip_required, 'description' => 'Enter an IP for this network interface. x.x.x.x', 'defaultValue' => network_interface['ipAddress']}], options[:options])
      if v_prompt[field_context] && !v_prompt[field_context]['ipAddress'].to_s.empty?
        network_interface['ipAddress'] = v_prompt[field_context]['ipAddress']
      end

      network_interfaces << network_interface
      interface_index += 1
      if options[:options] && options[:options]['networkInterfaces'] && options[:options]['networkInterfaces'][interface_index]
        add_another_interface = true
      elsif max_networks && network_interfaces.size >= max_networks
        add_another_interface = false
      else
        has_another_interface = options[:options] && options[:options]["networkInterface#{interface_index+1}"]
        add_another_interface = has_another_interface || (!no_prompt && Morpheus::Cli::OptionTypes.confirm("Add another network interface?", {:default => false}))
      end

    end

    return network_interfaces

  end

  # Prompts user for environment variables for new instance
  # returns array of evar objects {id: null, name: "VAR", value: "somevalue"}
  def prompt_evars(options={})
    #puts "Configure Environment Variables:"
    no_prompt = (options[:no_prompt] || (options[:options] && options[:options][:no_prompt]))
    evars = []
    evar_index = 0
    has_another_evar = options[:options] && options[:options]["evar#{evar_index}"]
    add_another_evar = has_another_evar || (!no_prompt && Morpheus::Cli::OptionTypes.confirm("Add an environment variable?", {default: false}))
    while add_another_evar do
      field_context = "evar#{evar_index}"
      evar = {}
      evar['id'] = nil
      evar_label = evar_index == 0 ? "ENV" : "ENV [#{evar_index+1}]"
      v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'name', 'type' => 'text', 'fieldLabel' => "#{evar_label} Name", 'required' => true, 'description' => 'Environment Variable Name.', 'defaultValue' => evar['name']}], options[:options])
      evar['name'] = v_prompt[field_context]['name']
      v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'value', 'type' => 'text', 'fieldLabel' => "#{evar_label} Value", 'required' => true, 'description' => 'Environment Variable Value', 'defaultValue' => evar['value']}], options[:options])
      evar['value'] = v_prompt[field_context]['value']
      evars << evar
      evar_index += 1
      has_another_evar = options[:options] && options[:options]["evar#{evar_index}"]
      add_another_evar = has_another_evar || (!no_prompt && Morpheus::Cli::OptionTypes.confirm("Add another environment variable?", {default: false}))
    end

    return evars
  end

  # Prompts user for environment variables for new instance
  # returns array of metadata objects {id: null, name: "MYTAG", value: "myvalue"}
  def prompt_metadata(options={})
    #puts "Configure Environment Variables:"
    no_prompt = (options[:no_prompt] || (options[:options] && options[:options][:no_prompt]))
    metadata_array = []
    metadata_index = 0
    has_another_metadata = options[:options] && options[:options]["metadata#{metadata_index}"]
    add_another_metadata = has_another_metadata || (!no_prompt && Morpheus::Cli::OptionTypes.confirm("Add a metadata tag?", {default: false}))
    while add_another_metadata do
      field_context = "metadata#{metadata_index}"
      metadata = {}
      metadata['id'] = nil
      metadata_label = metadata_index == 0 ? "Metadata Tag" : "Metadata Tag [#{metadata_index+1}]"
      v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'name', 'type' => 'text', 'fieldLabel' => "#{metadata_label} Name", 'required' => true, 'description' => 'Metadata Tag Name.', 'defaultValue' => metadata['name']}], options[:options])
      # todo: metadata.type ?
      metadata['name'] = v_prompt[field_context]['name']
      v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldContext' => field_context, 'fieldName' => 'value', 'type' => 'text', 'fieldLabel' => "#{metadata_label} Value", 'required' => true, 'description' => 'Metadata Tag Value', 'defaultValue' => metadata['value']}], options[:options])
      metadata['value'] = v_prompt[field_context]['value']
      metadata_array << metadata
      metadata_index += 1
      has_another_metadata = options[:options] && options[:options]["metadata#{metadata_index}"]
      add_another_metadata = has_another_metadata || (!no_prompt && Morpheus::Cli::OptionTypes.confirm("Add another metadata tag?", {default: false}))
    end

    return metadata_array
  end

  # Prompts user for load balancer settings
  # returns Hash of parameters like {loadBalancerId: "-1", etc}
  def prompt_instance_load_balancer(instance, default_lb_id, options)
    #puts "Configure Environment Variables:"
    no_prompt = (options[:no_prompt] || (options[:options] && options[:options][:no_prompt]))
    payload = {}
    api_params = {}
    if instance['id']
      api_params['instanceId'] = instance['id']
    end
    if instance['zone']
      api_params['zoneId'] = instance['zone']['id']
    elsif instance['cloud']
      api_params['zoneId'] = instance['cloud']['id']
    end
    if instance['group']
      api_params['siteId'] = instance['group']['id']
    elsif instance['site']
      api_params['siteId'] = instance['site']['id']
    end
    if instance['plan']
      api_params['planId'] = instance['plan']['id']
    end
    v_prompt = Morpheus::Cli::OptionTypes.prompt([{'fieldName' => 'loadBalancerId', 'type' => 'select', 'fieldLabel' => "Load Balancer", 'optionSource' => 'loadBalancers', 'required' => true, 'description' => 'Select Load Balancer for instance', 'defaultValue' => default_lb_id || ''}], options[:options], api_client, api_params)
    lb_id = v_prompt['loadBalancerId']
    payload['loadBalancerId'] = lb_id

    # todo: finish implmenting this

    # loadBalancerId
    # loadBalancerProxyProtocol
    # loadBalancerName
    # loadBalancerDescription
    # loadBalancerSslCert
    # loadBalancerScheme
    
    return payload
  end

  # reject old volume option types
  # these will eventually get removed from the associated optionTypes
  def reject_volume_option_types(option_types)
    option_types.reject {|opt|
      ['osDiskSize', 'osDiskType',
       'diskSize', 'diskType',
       'datastoreId', 'storagePodId'
       ].include?(opt['fieldName'])
    }
  end

  # reject old networking option types
  # these will eventually get removed from the associated optionTypes
  def reject_networking_option_types(option_types)
    option_types.reject {|opt|
      ['networkId', 'networkType', 'ipAddress', 'netmask', 'gateway', 'nameservers',
       'vmwareNetworkType', 'vmwareIpAddress', 'vmwareNetmask', 'vmwareGateway', 'vmwareNameservers',
       'subnetId'
       ].include?(opt['fieldName'])
    }
  end

  # reject old option types that now come from the selected service plan
  # these will eventually get removed from the associated optionTypes
  def reject_service_plan_option_types(option_types)
    option_types.reject {|opt|
      ['cpuCount', 'memorySize', 'memory'].include?(opt['fieldName'])
    }
  end

  # reject old security group option types
  def reject_security_group_option_types(option_types)
    option_types.reject {|opt|
      opt['code'] == 'provisionType.amazon.securityId' || opt['fieldName'] == 'securityId'
    }
  end

  def get_available_environments(refresh=false)
    if !@available_environments || refresh
      begin
        option_results = options_interface.options_for_source('environments',{})
        @available_environments = option_results['data'].collect {|it|
          {"code" => (it["code"] || it["value"]), "name" => it["name"], "value" => it["value"]}
        }
      rescue RestClient::Exception => e
        # if e.response && e.response.code == 404
          Morpheus::Logging::DarkPrinter.puts "Unable to determine available environments, using default options" if Morpheus::Logging.debug?
          @available_environments = get_static_environments()
        # else
        #   raise e
        # end
      end
    end
    return @available_environments
  end

  def get_static_environments
    [{'name' => 'Dev', 'value' => 'dev'}, {'name' => 'Test', 'value' => 'qa'}, {'name' => 'Staging', 'value' => 'staging'}, {'name' => 'Production', 'value' => 'production'}]
  end

end
