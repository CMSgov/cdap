locals {
  service_name      = coalesce(var.service_name_override, var.platform.service)
  service_name_full = "${var.platform.app}-${var.platform.env}-${var.platform.service}"

  # Build a name → containerPort lookup from port_mappings
  port_map = {
    for pm in coalesce(var.port_mappings, []) :
    pm.name => pm.containerPort
    if pm.name != null && pm.containerPort != null
  }

  sc_port_name = coalesce(
    var.service_connect_port_name,
    try([for pm in coalesce(var.port_mappings, []) : pm.name if pm.name != null][0], null)
  )

  # ALB integration is active when a listener ARN is provided
  enable_alb_integration = var.alb_listener_arn != null

  # Resolve the ALB target port by name — caller must provide alb_port_name if using ALB
  alb_container_port = local.enable_alb_integration ? local.port_map[var.alb_port_name] : null
}

