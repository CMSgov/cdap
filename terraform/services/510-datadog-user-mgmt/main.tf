resource "datadog_team" "this" {
  for_each    = toset(var.app_teams)
  description = "Team that implements and manages ${each.key}"
  handle      = lower(each.key)
  name        = "${upper(each.key)} Team"
}

data "datadog_permissions" "all" {}

# recreate a read-only role that can be modified as needed
resource "datadog_role" "observer" {
  name = "Observer"

  # Standard read permissions
  permission {
    id = data.datadog_permissions.all.permissions["monitors_read"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["dashboards_read"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["metrics_read"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["apm_read"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["infrastructure_read"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["synthetics_read"]
  }
}

# role that can silence incidents
resource "datadog_role" "incident_responder" {
  name = "Engineering - Incident Responder"

  # Standard read permissions
  permission {
    id = data.datadog_permissions.all.permissions["monitors_read"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["dashboards_read"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["metrics_read"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["apm_read"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["infrastructure_read"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["synthetics_read"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["monitors_downtime"]
  }
}

# Can manage API and Application keys without risking monitor modifications
resource "datadog_role" "program_manager" {
  name = "Program Management"
  # API key management
  permission {
    id = data.datadog_permissions.all.permissions["api_keys_read"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["api_keys_write"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["user_app_keys"]
  }
}

resource "datadog_role" "user_admin" {
  name = "User Admin"

  permission {
    id = data.datadog_permissions.all.permissions["user_access_invite"]
  }
  permission {
    id = data.datadog_permissions.all.permissions["user_access_manage"]
  }
}

