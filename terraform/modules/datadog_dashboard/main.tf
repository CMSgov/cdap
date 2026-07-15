resource "datadog_dashboard" "application_metrics_dashboard" {
  layout_type = "ordered"
  title       = "${var.name_rewrite != null ? var.name_rewrite : var.app} Metrics Dashboard"
  template_variable {
    name     = "env"
    prefix   = "environment"
    defaults = ["*"]
  }

  widget {
    note_definition {
      content          = "## ${upper(var.app)}\nMonitoring dashboard. Filters apply via the **env** template variable above.\n\n [Runbook](${var.runbook_url}) | Alerts managed via Tofu monitors module"
      background_color = "blue"
      font_size        = "14"
      text_align       = "left"
      show_tick        = false
    }
  }

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
    for_each = var.enable_default_widgets.ecs ? [1] : []
    content {
      group_definition {
        title       = "ECS"
        layout_type = "ordered"

        widget {
          timeseries_definition {
            title     = "CPU Utilization by Service"
            live_span = var.widget_live_spans.ecs
            request {
              q            = "avg:aws.ecs.cpuutilization{application:${var.app}, $env} by {servicename}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Memory Utilization by Service"
            live_span = var.widget_live_spans.ecs
            request {
              q            = "avg:aws.ecs.memory_utilization{application:${var.app}, $env} by {servicename}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Running vs Desired vs Pending by Service"
            live_span = var.widget_live_spans.ecs
            request {
              q            = "avg:aws.ecs.service.running{application:${var.app}, $env} by {servicename}"
              display_type = "line"
            }
            request {
              q            = "avg:aws.ecs.service.desired{application:${var.app}, $env} by {servicename}"
              display_type = "line"
            }
            request {
              q            = "avg:aws.ecs.service.pending{application:${var.app}, $env} by {servicename}"
              display_type = "line"
            }
          }
        }

        widget {
          toplist_definition {
            title     = "Desired Task Count by Service"
            live_span = var.widget_live_spans.ecs
            request {
              q = "avg:aws.ecs.service.desired{application:${var.app}, $env} by {servicename}"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Network I/O (Bytes In/Out) by Container"
            live_span = var.widget_live_spans.ecs
            request {
              q            = "avg:aws.ecs.container.net.rcvd_bytes{application:${var.app}, $env} by {containername}.as_rate()"
              display_type = "line"
            }
            request {
              q            = "avg:aws.ecs.container.net.sent_bytes{application:${var.app}, $env} by {containername}.as_rate()"
              display_type = "line"
            }
          }
        }

      }
    }
  }
  dynamic "widget" {
    for_each = var.enable_default_widgets.apm ? [1] : []
    content {
      group_definition {
        title       = "APM / Traces"
        layout_type = "ordered"

        widget {
          timeseries_definition {
            title     = "Request Rate"
            live_span = var.widget_live_spans.apm
            request {
              q            = "sum:trace.${var.apm_primary_operation}.hits{service:${var.app}, $env}.as_rate()"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "p50 / p95 / p99 Latency"
            live_span = var.widget_live_spans.apm
            request {
              q            = "p50:trace.${var.apm_primary_operation}{service:${var.app}, $env}"
              display_type = "line"
            }
            request {
              q            = "p95:trace.${var.apm_primary_operation}{service:${var.app}, $env}"
              display_type = "line"
            }
            request {
              q            = "p99:trace.${var.apm_primary_operation}{service:${var.app}, $env}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title = "Avg Time per Request"
            live_span = var.widget_live_spans.apm
            request {
              display_type = "area"
              query {
                metric_query {
                  name = "query1"
                  query = "sum:trace.${var.apm_primary_operation}.exec_time.by_service{service:${var.app}, $env} by {sublayer_service, sublayer_inferred}.rollup(sum).fill(zero)"
                }
              }
              query {
                metric_query {
                  name = "query2"
                  query = "sum:trace.${var.apm_primary_operation}.hits{service:${var.app}, $env}.rollup(sum).fill(zero).as_count()"
                }
              }
              formula {
                formula_expression = "median_3(query1 / query2)"
                number_format {
                  unit {
                    canonical {
                      unit_name = "second"
                    }
                  }
                }
              }
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Error Rate"
            live_span = var.widget_live_spans.apm
            request {
              q            = "sum:trace.${var.apm_primary_operation}.errors{service:${var.app}, $env}.as_rate()"
              display_type = "bars"
            }
          }
        }

        widget {
          query_value_definition {
            title     = "Apdex Score"
            live_span = var.widget_live_spans.apm
            autoscale = true
            precision = 2
            request {
              q = "avg:trace.${var.apm_primary_operation}.apdex{service:${var.app}, $env}"
            }
          }
        }

      }
    }
  }

  dynamic "widget" {
    for_each = var.enable_default_widgets.s3 ? [1] : []
    content {
      group_definition {
        title       = "S3"
        layout_type = "ordered"

        widget {
          toplist_definition {
            title     = "Bucket Size (Bytes) by Bucket"
            live_span = var.widget_live_spans.s3
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
            title     = "Object Count by Bucket"
            live_span = var.widget_live_spans.s3
            request {
              formula {
                formula_expression = "query1"
              }
              query {
                metric_query {
                  aggregator  = "avg"
                  data_source = "metrics"
                  name        = "query1"
                  query       = "avg:aws.s3.number_of_objects{application:${var.app}, $env} by {bucketname}"
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
            title     = "Invocations by Function"
            live_span = var.widget_live_spans.lambda
            request {
              q            = "sum:aws.lambda.invocations{application:${var.app}, $env} by {functionname}.as_count()"
              display_type = "bars"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Errors by Function"
            live_span = var.widget_live_spans.lambda
            request {
              q            = "sum:aws.lambda.errors{application:${var.app}, $env} by {functionname}.as_count()"
              display_type = "bars"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Error Rate by Function (%)"
            live_span = var.widget_live_spans.lambda
            request {
              q            = "sum:aws.lambda.errors{application:${var.app}, $env} by {functionname}.as_count() / sum:aws.lambda.invocations{application:${var.app}, $env} by {functionname}.as_count() * 100"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Duration (avg) by Function"
            live_span = var.widget_live_spans.lambda
            request {
              q            = "avg:aws.lambda.duration{application:${var.app}, $env} by {functionname}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Throttles by Function"
            live_span = var.widget_live_spans.lambda
            request {
              q            = "sum:aws.lambda.throttles{application:${var.app}, $env} by {functionname}.as_count()"
              display_type = "bars"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Concurrent Executions by Function"
            live_span = var.widget_live_spans.lambda
            request {
              q            = "avg:aws.lambda.concurrent_executions{application:${var.app}, $env} by {functionname}"
              display_type = "line"
            }
          }
        }

      }
    }
  }

  dynamic "widget" {
    for_each = var.enable_default_widgets.alb ? [1] : []
    content {
      group_definition {
        title       = "ALB"
        layout_type = "ordered"

        widget {
          timeseries_definition {
            title     = "Request Count by Target Group"
            live_span = var.widget_live_spans.alb
            request {
              q            = "sum:aws.applicationelb.request_count{application:${var.app}, $env} by {targetgroup}.as_count()"
              display_type = "bars"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Target Response Time p95 by Target Group"
            live_span = var.widget_live_spans.alb
            request {
              q            = "avg:aws.applicationelb.target_response_time.p95{application:${var.app}, $env} by {targetgroup}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "HTTP 5XX by Target Group"
            live_span = var.widget_live_spans.alb
            request {
              q            = "sum:aws.applicationelb.httpcode_target_5xx{application:${var.app}, $env} by {targetgroup}.as_count()"
              display_type = "bars"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "HTTP 4XX by Target Group"
            live_span = var.widget_live_spans.alb
            request {
              q            = "sum:aws.applicationelb.httpcode_target_4xx{application:${var.app}, $env} by {targetgroup}.as_count()"
              display_type = "bars"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Active Connection Count by Target Group"
            live_span = var.widget_live_spans.alb
            request {
              q            = "sum:aws.applicationelb.active_connection_count{application:${var.app}, $env} by {targetgroup}.as_count()"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Healthy vs Unhealthy Host Count by Target Group"
            live_span = var.widget_live_spans.alb
            request {
              q            = "avg:aws.applicationelb.healthy_host_count{application:${var.app}, $env} by {targetgroup}"
              display_type = "line"
            }
            request {
              q            = "avg:aws.applicationelb.un_healthy_host_count{application:${var.app}, $env} by {targetgroup}"
              display_type = "line"
            }
          }
        }

      }
    }
  }


  dynamic "widget" {
    for_each = var.enable_default_widgets.sqs ? [1] : []
    content {
      group_definition {
        title       = "SQS"
        layout_type = "ordered"

        widget {
          timeseries_definition {
            title     = "Messages Visible by Queue"
            live_span = var.widget_live_spans.sqs
            request {
              q            = "avg:aws.sqs.approximate_number_of_messages_visible{application:${var.app}, $env} by {queuename}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Dead Letter Queue Messages Visible"
            live_span = var.widget_live_spans.sqs
            request {
              q            = "avg:aws.sqs.approximate_number_of_messages_visible{application:${var.app}, $env, queuename:*dlq*} by {queuename}"
              display_type = "bars"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Oldest Message Age (seconds) by Queue"
            live_span = var.widget_live_spans.sqs
            request {
              q            = "max:aws.sqs.approximate_age_of_oldest_message{application:${var.app}, $env} by {queuename}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Messages Sent / Deleted by Queue"
            live_span = var.widget_live_spans.sqs
            request {
              q            = "sum:aws.sqs.number_of_messages_sent{application:${var.app}, $env} by {queuename}.as_count()"
              display_type = "bars"
            }
            request {
              q            = "sum:aws.sqs.number_of_messages_deleted{application:${var.app}, $env} by {queuename}.as_count()"
              display_type = "line"
            }
          }
        }

      }
    }
  }

  dynamic "widget" {
    for_each = var.enable_default_widgets.sns ? [1] : []
    content {
      group_definition {
        title       = "SNS"
        layout_type = "ordered"

        widget {
          timeseries_definition {
            title     = "Messages Published / Delivered / Failed by Topic"
            live_span = var.widget_live_spans.sns
            request {
              q            = "sum:aws.sns.number_of_messages_published{application:${var.app}, $env} by {topicname}.as_count()"
              display_type = "bars"
            }
            request {
              q            = "sum:aws.sns.number_of_notifications_delivered{application:${var.app}, $env} by {topicname}.as_count()"
              display_type = "line"
            }
            request {
              q            = "sum:aws.sns.number_of_notifications_failed{application:${var.app}, $env} by {topicname}.as_count()"
              display_type = "bars"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Notification Failure Rate by Topic (%)"
            live_span = var.widget_live_spans.sns
            request {
              q            = "sum:aws.sns.number_of_notifications_failed{application:${var.app}, $env} by {topicname}.as_count() / sum:aws.sns.number_of_messages_published{application:${var.app}, $env} by {topicname}.as_count() * 100"
              display_type = "line"
            }
          }
        }

      }
    }
  }

  dynamic "widget" {
    for_each = var.enable_default_widgets.aurora ? [1] : []
    content {
      group_definition {
        title       = "Aurora"
        layout_type = "ordered"

        widget {
          timeseries_definition {
            title     = "DB Connections by Instance"
            live_span = var.widget_live_spans.aurora
            request {
              q            = "avg:aws.rds.database_connections{application:${var.app}, $env} by {dbinstanceidentifier}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "CPU Utilization by Instance"
            live_span = var.widget_live_spans.aurora
            request {
              q            = "avg:aws.rds.cpuutilization{application:${var.app}, $env} by {dbinstanceidentifier}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Read / Write Latency by Instance"
            live_span = var.widget_live_spans.aurora
            request {
              q            = "avg:aws.rds.read_latency{application:${var.app}, $env} by {dbinstanceidentifier}"
              display_type = "line"
            }
            request {
              q            = "avg:aws.rds.write_latency{application:${var.app}, $env} by {dbinstanceidentifier}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Read / Write IOPS by Instance"
            live_span = var.widget_live_spans.aurora
            request {
              q            = "avg:aws.rds.read_iops{application:${var.app}, $env} by {dbinstanceidentifier}"
              display_type = "line"
            }
            request {
              q            = "avg:aws.rds.write_iops{application:${var.app}, $env} by {dbinstanceidentifier}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Freeable Memory by Instance"
            live_span = var.widget_live_spans.aurora
            request {
              q            = "avg:aws.rds.freeable_memory{application:${var.app}, $env} by {dbinstanceidentifier}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Aurora Replica Lag by Instance"
            live_span = var.widget_live_spans.aurora
            request {
              q            = "avg:aws.rds.aurora_replica_lag{application:${var.app}, $env} by {dbinstanceidentifier}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Estimated Shared Memory (Bytes) by Instance"
            live_span = var.widget_live_spans.aurora
            request {
              q            = "avg:aws.rds.aurora_estimated_shared_memory_bytes{application:${var.app}, $env} by {dbinstanceidentifier}"
              display_type = "line"
            }
          }
        }
      }
    }
  }
}
