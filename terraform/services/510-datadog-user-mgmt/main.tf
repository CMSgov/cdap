resource "datadog_team" "this" {
  for_each    = toset(var.app_teams)
  description = "Team that implements and manages ${each.key}"
  handle      = lower(each.key)
  name        = "${upper(each.key)} Team"
}


data "datadog_permissions" "dd_perms" {}

# Create an role that can silence incidents
resource "datadog_role" "incident_responder" {
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

# Create an role that can silence incidents
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

  # Incident response additions
  permission {
    id = data.datadog_permissions.all.permissions["monitors_downtime"]
  }
}
