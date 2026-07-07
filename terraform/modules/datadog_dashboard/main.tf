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

  dynamic "widget" {
    for_each = var.enable_default_widgets.monitors ? [1] : []
    content {
      group_definition {
        title       = "Monitor Health"
        layout_type = "ordered"

        # Alerting only — filters to just triggered monitors
        widget {
          manage_status_definition {
            title               = "Alerting Monitors — ${var.app}"
            color_preference    = "text"
            display_format      = "counts"
            hide_zero_counts    = true
            show_last_triggered = true
            sort                = "status,asc"
            summary_type        = "monitors"
            query               = "tag:application:${var.app} status:alert"
          }
        }

        # Shows all monitors tagged with application:<app>
        widget {
          manage_status_definition {
            title               = "All Monitors — ${var.app}"
            color_preference    = "text"
            display_format      = "counts"
            hide_zero_counts    = true
            show_last_triggered = true
            sort                = "status,asc"
            summary_type        = "monitors"
            query               = "tag:application:${var.app}"
          }
        }
      }
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

        # -------------------------------------------------------
        # HEALTH SUMMARY
        # Quick red/green/yellow indicators — first thing anyone
        # should look at to determine if action is needed.
        # -------------------------------------------------------

        # Unhealthy Tasks
        widget {
          query_value_definition {
            title     = "Unhealthy Tasks (Desired - Running)"
            live_span = var.widget_live_spans.current
            autoscale = true
            precision = 0
            request {
              q = "clamp_min(sum:aws.ecs.service.desired{application:${var.app}, $env} by {servicename} - sum:aws.ecs.service.running{application:${var.app}, $env} by {servicename}, 0)"
              conditional_formats {
                comparator = ">"
                value      = 0
                palette    = "white_on_red"
              }
              conditional_formats {
                comparator = "<="
                value      = 0
                palette    = "white_on_green"
              }
            }
          }
        }

        # Pending Tasks
        widget {
          query_value_definition {
            title     = "Pending Tasks (Stuck Starting)"
            live_span = var.widget_live_spans.current
            autoscale = true
            precision = 0
            request {
              q          = "sum:aws.ecs.service.pending{application:${var.app}, $env}"
              aggregator = "last"
              conditional_formats {
                comparator = ">"
                value      = 0
                palette    = "white_on_yellow"
              }
              conditional_formats {
                comparator = "<="
                value      = 0
                palette    = "white_on_green"
              }
            }
          }
        }
        # -------------------------------------------------------
        # TASK TRENDS
        # Running tasks over time shows service stability.
        # Pending tasks over time surfaces stuck deployments.
        # Desired is omitted — it only changes during intentional
        # scaling events which are visible in the event stream.
        # -------------------------------------------------------

        # Running Tasks by Service — current snapshot
        widget {
          toplist_definition {
            title     = "Running Tasks by Service"
            live_span = var.widget_live_spans.current
            request {
              q = "sum:aws.ecs.service.running{application:${var.app}, $env} by {servicename}"
              conditional_formats {
                comparator = "<"
                value      = 1
                palette    = "white_on_red"
              }
              conditional_formats {
                comparator = ">="
                value      = 1
                palette    = "white_on_green"
              }
            }
          }
        }

        # Missing Tasks by Service — current snapshot
        widget {
          toplist_definition {
            title     = "Missing Tasks by Service (Desired - Running)"
            live_span = var.widget_live_spans.current
            request {
              q = "clamp_min(sum:aws.ecs.service.desired{application:${var.app}, $env} by {servicename} - sum:aws.ecs.service.running{application:${var.app}, $env} by {servicename}, 0)"
              conditional_formats {
                comparator = ">"
                value      = 0
                palette    = "white_on_red"
              }
              conditional_formats {
                comparator = "<="
                value      = 0
                palette    = "white_on_green"
              }
            }
          }
        }

        # Pending Tasks by Service — current snapshot
        widget {
          toplist_definition {
            title     = "Pending Tasks by Service"
            live_span = var.widget_live_spans.current
            request {
              q = "sum:aws.ecs.service.pending{application:${var.app}, $env} by {servicename}"
              conditional_formats {
                comparator = ">"
                value      = 0
                palette    = "white_on_yellow"
              }
              conditional_formats {
                comparator = "<="
                value      = 0
                palette    = "white_on_green"
              }
            }
          }
        }

        # -------------------------------------------------------
        # FAILURE SIGNALS
        # Container restarts and ECS events help identify
        # crash-looping tasks and failed deployments that may
        # not be obvious from task counts alone.
        # -------------------------------------------------------

        widget {
          timeseries_definition {
            title     = "Container Restarts by Service"
            live_span = var.widget_live_spans.ecs
            request {
              q            = "sum:container.restarts{application:${var.app}, $env} by {servicename}"
              display_type = "bars"
              style {
                palette = "warm"
              }
            }
          }
        }

        widget {
          event_stream_definition {
            title      = "ECS Task & Deployment Events"
            live_span  = var.widget_live_spans.ecs
            query      = "source:amazon_ecs application:${var.app}"
            event_size = "s"
          }
        }

        # -------------------------------------------------------
        # RESOURCE UTILIZATION
        # CPU and memory consumption per service over time.
        # High utilization can cause task failures or throttling
        # before a crash is visible in task count metrics.
        # -------------------------------------------------------

        widget {
          timeseries_definition {
            title     = "CPU Utilization by Service"
            live_span = var.widget_live_spans.ecs
            request {
              q            = "avg:aws.ecs.cpuutilization{application:${var.app}, $env} by {servicename}"
              display_type = "line"
            }
            marker {
              value        = "y > 80"
              display_type = "error dashed"
              label        = "Critical CPU"
            }
            marker {
              value        = "y > 60"
              display_type = "warning dashed"
              label        = "High CPU"
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
            marker {
              value        = "y > 85"
              display_type = "error dashed"
              label        = "Critical Memory"
            }
            marker {
              value        = "y > 70"
              display_type = "warning dashed"
              label        = "High Memory"
            }
          }
        }

        # -------------------------------------------------------
        # NETWORK I/O
        # Real-time throughput and cumulative data transfer
        # per service. Most relevant for data pipeline and
        # batch processing services moving large volumes of data.
        # -------------------------------------------------------

        widget {
          timeseries_definition {
            title     = "Network Throughput (MB/s) by Container"
            live_span = var.widget_live_spans.ecs
            request {
              q            = "avg:container.net.rcvd{cluster_name:${var.app}*, $env} by {containername}.as_rate()/1048576"
              display_type = "line"
              metadata {
                expression = "avg:container.net.rcvd{cluster_name:${var.app}*, $env} by {containername}.as_rate()/1048576"
                alias_name = "MB/s In"
              }
            }
            request {
              q            = "avg:container.net.sent{cluster_name:${var.app}*, $env} by {containername}.as_rate()/1048576"
              display_type = "line"
              metadata {
                expression = "avg:container.net.sent{cluster_name:${var.app}*, $env} by {containername}.as_rate()/1048576"
                alias_name = "MB/s Out"
              }
            }
            # Adjust this threshold to match your team's expected peak throughput
            marker {
              value        = "y > 100"
              display_type = "warning dashed"
              label        = "High Throughput"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Total Data Transferred (GB) by Service"
            live_span = var.widget_live_spans.ecs
            request {
              q            = "sum:container.net.rcvd{cluster_name:${var.app}*, $env} by {servicename}/1073741824"
              display_type = "bars"
              metadata {
                expression = "sum:container.net.rcvd{cluster_name:${var.app}*, $env} by {servicename}/1073741824"
                alias_name = "GB In"
              }
            }
            request {
              q            = "sum:container.net.sent{cluster_name:${var.app}*, $env} by {servicename}/1073741824"
              display_type = "bars"
              metadata {
                expression = "sum:container.net.sent{cluster_name:${var.app}*, $env} by {servicename}/1073741824"
                alias_name = "GB Out"
              }
            }
          }
        }

        # -------------------------------------------------------
        # DRILL-DOWN
        # Use the $servicename template variable to filter all
        # widgets to a specific service. These widgets show
        # task-level detail to help identify exactly what is
        # failing and why.
        # -------------------------------------------------------

        widget {
          event_stream_definition {
            title      = "Task Events — Selected Service"
            live_span  = var.widget_live_spans.ecs
            query      = "source:amazon_ecs application:${var.app} $servicename"
            event_size = "l"
          }
        }

        widget {
          timeseries_definition {
            title     = "Container Restarts — Selected Service"
            live_span = var.widget_live_spans.ecs
            request {
              q            = "sum:container.restarts{application:${var.app}, $env, $servicename} by {containername}"
              display_type = "bars"
              style {
                palette = "warm"
              }
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
              q            = "sum:trace.http.request.hits{application:${var.app}, $env}.as_rate()"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "p50 / p95 / p99 Latency"
            live_span = var.widget_live_spans.apm
            request {
              q            = "p50:trace.http.request{application:${var.app}, $env}"
              display_type = "line"
            }
            request {
              q            = "p95:trace.http.request{application:${var.app}, $env}"
              display_type = "line"
            }
            request {
              q            = "p99:trace.http.request{application:${var.app}, $env}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Error Rate"
            live_span = var.widget_live_spans.apm
            request {
              q            = "sum:trace.http.request.errors{application:${var.app}, $env}.as_rate()"
              display_type = "bars"
            }
          }
        }

        widget {
          query_value_definition {
            title     = "Apdex Score"
            live_span = var.widget_live_spans.current
            autoscale = true
            precision = 2
            request {
              q = "avg:trace.http.request.apdex{application:${var.app}, $env}"
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
              q            = "p95:aws.applicationelb.target_response_time{application:${var.app}, $env} by {targetgroup}"
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
