actions :create, :delete, :overwrite, :add, :remove
default_action :create

state_attrs :aws_access_key,
            :group_name,
            :vpc_id

attribute :aws_access_key,        kind_of: String
attribute :aws_secret_access_key, kind_of: String
attribute :aws_session_token,     kind_of: String, default: nil
attribute :group_name,            kind_of: String
attribute :description,           kind_of: String
attribute :vpc_id,                kind_of: String, default: nil
