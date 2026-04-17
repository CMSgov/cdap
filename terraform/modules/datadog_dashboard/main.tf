resource "datadog_dashboard" "Application_Metrics_Dashboard" {
  layout_type = "ordered"
  title       = "${var.app} Metrics Dashboard"
  template_variable {
    name    = "env"
    prefix  = "environment"
    default = "*"
  }

  # Custom widgets defined by the team in main.tf
  widget {
    group_definition {
      layout_type = "ordered"
      title       = "${var.app} Custom Metrics"

      # Loop through every widget passed by the team
      dynamic "widget" {
        for_each = var.custom_widgets
        content {

          # Render ONLY IF type == "timeseries"
          dynamic "timeseries_definition" {
            for_each = widget.value.type == "timeseries" ? [widget.value] : []
            content {
              title = timeseries_definition.value.title
              request {
                q            = timeseries_definition.value.query
                display_type = timeseries_definition.value.display_type
              }
            }
          }

          # Render ONLY IF type == "query_value"
          dynamic "query_value_definition" {
            for_each = widget.value.type == "query_value" ? [widget.value] : []
            content {
              title     = query_value_definition.value.title
              autoscale = true
              precision = query_value_definition.value.precision
              request {
                q = query_value_definition.value.query
              }
            }
          }

          # Render ONLY IF type == "toplist"
          dynamic "toplist_definition" {
            for_each = widget.value.type == "toplist" ? [widget.value] : []
            content {
              title = toplist_definition.value.title
              request {
                q = toplist_definition.value.query
              }
            }
          }

        }
      }
    }
  }

  dynamic "widget" {
    # Renders the block exactly once if true, zero times if false
    for_each = var.enable_default_widgets.ecs ? [1] : []
    content {
      group_definition {
        title       = "ECS"
        layout_type = "ordered"
        widget {
          timeseries_definition {
            title = "ECS CPU/MEM Utilization by Clustername"
            request {
              q = "avg:aws.ecs.cpuutilization{application:${var.app}, $env} by {clustername}"
            }
            request {
              q = "avg:aws.ecs.memory_utilization{application:${var.app}, $env} by {clustername}"
            }
          }
        }
        widget {
          query_value_definition {
            title = "Running Tasks"
            request {
              q = "avg:aws.ecs.service.running{application:${var.app}, $env}"
            }
            timeseries_background {
              type = "area"
            }
          }
        }
        widget {
          query_value_definition {
            title = "Desired Tasks"
            request {
              q = "avg:aws.ecs.service.desired{application:${var.app}, $env}"
            }
          }
        }
        widget {
          query_value_definition {
            title = "Pending Tasks"
            request {
              q = "avg:aws.ecs.service.pending{application:${var.app}, $env}"
            }
          }
        }
      }
    }
  }

  dynamic "widget" {
    # Renders the block exactly once if true, zero times if false
    for_each = var.enable_default_widgets.s3 ? [1] : []
    content {
      group_definition {
        layout_type = "ordered"
        title       = "S3"
        widget {
          toplist_definition {
            live_span = "4h"
            title     = "Bucket Size (Bytes)"
            request {
              q = "avg:aws.s3.bucket_size_bytes{application:${var.app}, $env} by {bucketname}"
            }
            style {
              display {
                type = "stacked"
              }
            }
          }
        }
        widget {
          toplist_definition {
            live_span = "4h"
            title     = "# Objects"

            request {
              formula {
                formula_expression = "query1"
              }
              query {
                metric_query {
                  aggregator      = "avg"
                  cross_org_uuids = []
                  data_source     = "metrics"
                  name            = "query1"
                  query           = "avg:aws.s3.number_of_objects{application:ab2d} by {bucketname}"
                }
              }
            }

            style {
              display {
                type = "stacked"
              }
            }
          }

        }
      }
    }
  }
  dynamic "widget" {
    for_each = var.enable_default_widgets.lambda ? [1] : []
    content {
      group_definition {
        title       = "Lambda"
        layout_type = "ordered"
        widget {
          timeseries_definition {
            title = "Invocations"
            request {
              q = "sum:aws.lambda.invocations{application:${var.app}, $env} by {functionname}.as_count()"
            }
          }
        }
        widget {
          timeseries_definition {
            title = "Errors"
            request {
              q = "sum:aws.lambda.errors{application:${var.app}, $env}.as_count()"
            }
          }
        }
        widget {
          timeseries_definition {
            title = "Duration"
            request {
              q = "avg:aws.lambda.duration{application:${var.app}, $env} by {functionname}"
            }
          }
        }
        widget {
          timeseries_definition {
            title = "Throttles"
            request {
              q = "sum:aws.lambda.throttles{application:${var.app}, $env}.as_count()"
            }
          }
        }
      }
    }
  }
  dynamic "widget" {
    # Renders the block exactly once if true, zero times if false
    for_each = var.enable_default_widgets.elb ? [1] : []
    content {
      group_definition {
        title       = "ELB"
        layout_type = "ordered"
        widget {
          timeseries_definition {
            title = "Active Connection Count"
            request {
              q = "sum:aws.applicationelb.active_connection_count{application:${var.app}, $env} by {environment}.as_count()"
            }
          }
        }
        widget {
          timeseries_definition {
            title = "HTTP 5XX Count"
            request {
              q = "sum:aws.applicationelb.httpcode_elb_5xx{application:${var.app}, $env} by {environment}.as_count()"
            }
          }
        }
      }
    }
  }

  dynamic "widget" {
    # Renders the block exactly once if true, zero times if false
    for_each = var.enable_default_widgets.sns ? [1] : []
    content {
      timeseries_definition {
        title = "SNS # Messages Published, Notifications Delivered/Failed"
        request {
          q = "sum:aws.sns.number_of_messages_published{application:${var.app}, $env} by {environment}.as_count()"
        }
        request {
          q = "sum:aws.sns.number_of_notifications_delivered{application:${var.app}, $env} by {environment}.as_count()"
        }
        request {
          q = "sum:aws.sns.number_of_notifications_failed{application:${var.app}, $env} by {environment}.as_count()"
        }
      }
    }
  }

  dynamic "widget" {
    # Renders the block exactly once if true, zero times if false
    for_each = var.enable_default_widgets.aurora ? [1] : []
    content {
      timeseries_definition {
        title = "Aurora Estimated Shared Memory (Bytes)"
        request {
          q = "avg:aws.rds.aurora_estimated_shared_memory_bytes{application:${var.app}, $env} by {environment}"
        }
      }
    }


  }
}