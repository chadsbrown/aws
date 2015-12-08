include Opscode::Aws::Ec2

def whyrun_supported?
  true
end

action :create do
  sg = security_group_by_name(new_resource.group_name, new_resource.vpc_id)
  sg_exists = sg && sg[:group_name] == new_resource.group_name

  unless sg_exists
    converge_by("creating new Security Group #{new_resource.group_name}") do
      sg = ec2.create_security_group(group_name: new_resource.group_name,
                                     description: new_resource.description,
                                     vpc_id: new_resource.vpc_id)
    end
  end
end

action :delete do
  sg = security_group_by_name(new_resource.group_name, new_resource.vpc_id)
  sg_exists = sg && sg[:group_name] == new_resource.group_name
  if sg_exists
    converge_by("deleting Security Group #{sg[:group_id]} (#{new_resource.group_name})") do
      ec2.delete_security_group(group_id: sg[:group_id])
    end
  else
    Chef::Log.warn("Security Group specified doesn't exist -- deletion will not be attempted")
  end
end

action :overwrite do
  sg = security_group_by_name(new_resource.group_name, new_resource.vpc_id)
  instance_id = query_instance_id
  instance_sgs = instance_security_groups(instance_id)
  vpc_id = query_vpc_id
  sg_exists = sg && sg[:group_name] == new_resource.group_name
  instance_has_group = instance_sgs.include?(sg[:group_id])

  if (sg_exists && !instance_has_group) || instance_sgs.len != 1
    instance_id = query_instance_id
    converge_by("setting Security Group #{sg[:group_id]} to instance") do
      ec2.modify_instance_attribute(instance_id: instance_id,
                                    groups: [sg[:group_id]])
    end
  end
end

action :add do
  sg = security_group_by_name(new_resource.group_name, new_resource.vpc_id)
  instance_id = query_instance_id
  instance_sgs = instance_security_groups(instance_id)
  vpc_id = query_vpc_id
  sg_exists = sg && sg[:group_name] == new_resource.group_name
  instance_has_group = instance_sgs.include?(sg[:group_id])

  if sg_exists && !instance_has_group
    instance_sgs << sg[:group_id]
    converge_by("merging Security Group to instance.  group list: #{sg[:group_id]}") do
      ec2.modify_instance_attribute(instance_id: instance_id,
                                    groups: instance_sgs)
    end
  end
end

action :remove do
  sg = security_group_by_name(new_resource.group_name, new_resource.vpc_id)
  instance_id = query_instance_id
  instance_sgs = instance_security_groups(instance_id)
  vpc_id = query_vpc_id
Chef::Log.warn("vpc_id is #{vpc_id}")
  sg_exists = sg && sg[:group_name] == new_resource.group_name

  if sg_exists
    instance_has_group = instance_sgs.include?(sg[:group_id])
  else
    Chef::Log.warn("Security Group specified doesn't exist -- removal will not be attempted")
  end

  if instance_has_group
    instance_sgs.delete(sg[:group_id])
    if instance_sgs.length == 0
      fail 'instance #{instance_id} must have at least one security group'
    end
    converge_by("unsetting Security Group #{sg[:group_id]} to instance") do
      ec2.modify_instance_attribute(instance_id: instance_id,
                                    groups: instance_sgs)
    end
  end
end

def security_group_by_name(security_group_name, vpc_id)
  ec2.describe_security_groups[:security_groups].find { |sg| sg[:group_name] == security_group_name && sg[:vpc_id] == vpc_id }
end

def instance_security_groups(instance_id)
  ec2.describe_instance_attribute(instance_id: instance_id, attribute: 'groupSet')[:groups].map(&:group_id)
end
