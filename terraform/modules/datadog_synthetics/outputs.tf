output "synthetics_tests" {
  description = "List of {name, public_id} objects formatted for the datadog_monitors module's synthetics_tests input."
  value = [
    for key, test in datadog_synthetics_test.this : {
      name      = test.name
      public_id = test.id
    }
  ]
}
