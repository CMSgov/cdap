# -------------------------------------------------------
# Additional Task Policies —
# -------------------------------------------------------
resource "aws_iam_policy" "ecs_exec" {
  name        = "${module.platform.app}-${module.platform.env}-tftesting-ecs-exec"
  description = "Allows ECS Exec (execute-command) for interactive debugging. Test environments only."
  policy      = data.aws_iam_policy_document.ecs_exec.json
}

data "aws_iam_policy_document" "ecs_exec" {
  statement {
    sid = "AllowECSExec"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
}
