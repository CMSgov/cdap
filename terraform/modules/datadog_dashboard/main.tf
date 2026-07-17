resource "datadog_dashboard" "application_metrics_dashboard" {
  layout_type = "ordered"
  title       = "${var.name_rewrite != null ? var.name_rewrite : upper(var.app)} Metrics Dashboard"

  # -------------------------------------------------------
  # TEMPLATE VARIABLES
  # $env     — filter by environment (e.g. dev, test, prod)
  # $servicename — drill down to a specific ECS service
  #                (globally unique, e.g. cdap-test-tftesting-a)
  # -------------------------------------------------------
  template_variable {
    name     = "env"
    prefix   = "environment"
    defaults = ["*"]
  }

  template_variable {
    name     = "servicename"
    prefix   = "servicename"
    defaults = ["*"]
  }

  # -------------------------------------------------------
  # HEADER
  # -------------------------------------------------------

  widget {
    note_definition {
      content          = "## ${upper(var.app)}\nMonitoring dashboard for all services under **${var.app}**.\n\nUse **$env** to filter by environment and **$servicename** to drill down to a specific service.\n\n[Runbook](${var.runbook_url}) | Alerts managed via Tofu monitors module"
      background_color = "blue"
      font_size        = "14"
      text_align       = "left"
      show_tick        = false
    }
  }

  # -------------------------------------------------------
  # MONITOR HEALTH
  # -------------------------------------------------------

  dynamic "widget" {
    for_each = var.enable_default_widgets.monitors ? [1] : []
    content {
      group_definition {
        title       = "Monitor Health"
        layout_type = "ordered"

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

  # -------------------------------------------------------
  # CUSTOM METRICS
  # Only rendered when custom_widgets are provided.
  # -------------------------------------------------------

  dynamic "widget" {
    for_each = length(var.custom_widgets) > 0 ? [1] : []
    content {
      group_definition {
        layout_type = "ordered"
        title       = "${var.app} Custom Metrics"

        dynamic "widget" {
          for_each = var.custom_widgets
          content {

            dynamic "timeseries_definition" {
              for_each = widget.value.type == "timeseries" ? [widget.value] : []
              content {
                title = timeseries_definition.value.title
                dynamic "request" {
                  for_each = timeseries_definition.value.queries
                  content {
                    q            = request.value.q
                    display_type = request.value.display_type
                  }
                }
              }
            }

            dynamic "query_value_definition" {
              for_each = widget.value.type == "query_value" ? [widget.value] : []
              content {
                title     = query_value_definition.value.title
                autoscale = true
                precision = query_value_definition.value.precision
                dynamic "request" {
                  for_each = query_value_definition.value.queries
                  content {
                    q = request.value.q
                  }
                }
              }
            }

            dynamic "toplist_definition" {
              for_each = widget.value.type == "toplist" ? [widget.value] : []
              content {
                title = toplist_definition.value.title
                dynamic "request" {
                  for_each = toplist_definition.value.queries
                  content {
                    q = request.value.q
                  }
                }
              }
            }

          }
        }
      }
    }
  }

  # -------------------------------------------------------
  # ECS
  # -------------------------------------------------------

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
        # All widgets use servicename which is globally unique
        # and consistent across all metric sources here.
        # -------------------------------------------------------

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

        # -------------------------------------------------------
        # TASK COUNTS
        # Current snapshot of running, missing, and pending tasks
        # per service. Use $servicename to drill down.
        # -------------------------------------------------------

        widget {
          toplist_definition {
            title     = "Running Tasks by Service"
            live_span = var.widget_live_spans.current
            request {
              q = "sum:aws.ecs.service.running{application:${var.app}, $env, $servicename} by {servicename}"
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

        widget {
          toplist_definition {
            title     = "Missing Tasks by Service (Desired - Running)"
            live_span = var.widget_live_spans.current
            request {
              q = "clamp_min(sum:aws.ecs.service.desired{application:${var.app}, $env, $servicename} by {servicename} - sum:aws.ecs.service.running{application:${var.app}, $env, $servicename} by {servicename}, 0)"
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

        widget {
          toplist_definition {
            title     = "Pending Tasks by Service"
            live_span = var.widget_live_spans.current
            request {
              q = "sum:aws.ecs.service.pending{application:${var.app}, $env, $servicename} by {servicename}"
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
        # crash-looping tasks and failed deployments.
        # Note: container.restarts is grouped by servicename
        # for consistency. Once Unified Service Tagging is
        # fully applied, this can be refined further.
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
            query      = "source:amazon_ecs application:${var.app} $env $servicename"
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
              q            = "avg:aws.ecs.cpuutilization{application:${var.app}, $env, $servicename} by {servicename}"
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
              q            = "avg:aws.ecs.memory_utilization{application:${var.app}, $env, $servicename} by {servicename}"
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
        # Real-time throughput and cumulative data transfer.
        # -------------------------------------------------------

        widget {
          timeseries_definition {
            title     = "Network Throughput (kB/s) by Service"
            live_span = var.widget_live_spans.ecs
            request {
              q            = "avg:container.net.rcvd{application:${var.app}, $env, $servicename} by {servicename}.as_rate()/1024"
              display_type = "line"
              metadata {
                expression = "avg:container.net.rcvd{application:${var.app}, $env, $servicename} by {servicename}.as_rate()/1024"
                alias_name = "kB/s In"
              }
            }
            request {
              q            = "avg:container.net.sent{application:${var.app}, $env, $servicename} by {servicename}.as_rate()/1024"
              display_type = "line"
              metadata {
                expression = "avg:container.net.sent{application:${var.app}, $env, $servicename} by {servicename}.as_rate()/1024"
                alias_name = "kB/s Out"
              }
            }
            marker {
              value        = "y > 10000"
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
              q            = "sum:container.net.rcvd{application:${var.app}, $env, $servicename} by {servicename}/1073741824"
              display_type = "bars"
              metadata {
                expression = "sum:container.net.rcvd{application:${var.app}, $env, $servicename} by {servicename}/1073741824"
                alias_name = "GB In"
              }
            }
            request {
              q            = "sum:container.net.sent{application:${var.app}, $env, $servicename} by {servicename}/1073741824"
              display_type = "bars"
              metadata {
                expression = "sum:container.net.sent{application:${var.app}, $env, $servicename} by {servicename}/1073741824"
                alias_name = "GB Out"
              }
            }
          }
        }

        # -------------------------------------------------------
        # DRILL-DOWN
        # Select a specific $servicename from the template
        # variable dropdown above to filter these widgets to
        # a single service. Shows task-level failure detail.
        # -------------------------------------------------------

        widget {
          event_stream_definition {
            title      = "Task Events — Selected Service"
            live_span  = var.widget_live_spans.ecs
            query      = "source:amazon_ecs application:${var.app} $env $servicename"
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

  # -------------------------------------------------------
  # APM / TRACES
  # Filtered by application tag — shows all services under
  # this application (APM uses the Datadog `service` tag, not `servicename`).
  # Select a specific service from the legend (or add a separate template
  # variable with prefix `service` if template-driven filtering is desired).
  # Note: APM traces are also tagged with `application` for cross-service views.
  # -------------------------------------------------------

  dynamic "widget" {
    for_each = var.enable_default_widgets.apm ? [1] : []
    content {
      group_definition {
        title       = "APM / Traces"
        layout_type = "ordered"

        widget {
          timeseries_definition {
            title     = "Request Rate by Service"
            live_span = var.widget_live_spans.apm
            request {
              q            = "sum:trace.${var.apm_primary_operation}.hits{application:${var.app}, $env} by {service}.as_rate()"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "p50 / p95 / p99 Latency"
            live_span = var.widget_live_spans.apm
            request {
              q            = "p50:trace.${var.apm_primary_operation}{application:${var.app}, $env} by {service}"
              display_type = "line"
            }
            request {
              q            = "p95:trace.${var.apm_primary_operation}{application:${var.app}, $env} by {service}"
              display_type = "line"
            }
            request {
              q            = "p99:trace.${var.apm_primary_operation}{application:${var.app}, $env} by {service}"
              display_type = "line"
            }
          }
        }

        widget {
          timeseries_definition {
            title     = "Avg Time per Request"
            live_span = var.widget_live_spans.apm
            request {
              display_type = "area"
              query {
                metric_query {
                  name  = "query1"
                  query = "sum:trace.${var.apm_primary_operation}.exec_time.by_service{service:${var.app}, $env} by {sublayer_service, sublayer_inferred}.rollup(sum).fill(zero)"
                }
              }
              query {
                metric_query {
                  name  = "query2"
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
            title     = "Error Rate by Service"
            live_span = var.widget_live_spans.apm
            request {
              q            = "sum:trace.${var.apm_primary_operation}.errors{application:${var.app}, $env} by {service}.as_rate()"
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
              q = "avg:trace.${var.apm_primary_operation}.apdex{application:${var.app}, $env}"
            }
            timeseries_background {
              type = "area"
              yaxis {
                include_zero = true
              }
            }
          }
        }

      }
    }
  }

  # -------------------------------------------------------
  # S3
  # -------------------------------------------------------

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

  # -------------------------------------------------------
  # LAMBDA
  # -------------------------------------------------------

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

  # -------------------------------------------------------
  # ALB
  # -------------------------------------------------------

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
            title     = "Active Connection Count by Load Balancer"
            live_span = var.widget_live_spans.alb
            request {
              q            = "sum:aws.applicationelb.active_connection_count{application:${var.app}, $env} by {loadbalancer}.as_count()"
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

  # -------------------------------------------------------
  # SQS
  # -------------------------------------------------------

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

  # -------------------------------------------------------
  # SNS
  # -------------------------------------------------------

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

  # -------------------------------------------------------
  # AURORA
  # -------------------------------------------------------

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
