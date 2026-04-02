# ------------------------------------------------------------------------
#  PARAMETER STORE
# ------------------------------------------------------------------------
resource "aws_ssm_parameter" "cw_agent_config" {
  name        = "/cloudwatch-agent/config"
  description = "Cloudwatch agent config"
  type        = "String"
  
  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }
    metrics = {
      append_dimensions = {
        InstanceId = "$${aws:InstanceId}"
      }
      metrics_collected = {
        cpu = {
          measurement = ["usage_idle", "usage_iowait"]
          metrics_collection_interval = 60
          resources = ["*"]
        }
        disk = {
          measurement = ["used_percent"]
          metrics_collection_interval = 60
          resources = ["/"]
        }
        net = {
          measurement = ["bytes_sent"] 
          metrics_collection_interval = 60
          resources = ["*"]
        }
      }
    }
  })
}

# ------------------------------------------------------------------------
# SSM ASSOCIATION 
# ------------------------------------------------------------------------
resource "aws_ssm_association" "install_cw_agent" {
  name = "AWS-ConfigureAWSPackage"

  targets {
    key    = "tag:AutoAlert"
    values = ["true"]
  }

  parameters = {
    action = "Install"
    name   = "AmazonCloudWatchAgent"
  }
}

resource "aws_ssm_association" "start_cw_agent" {
  name = "AmazonCloudWatch-ManageAgent"

  targets {
    key    = "tag:AutoAlert"
    values = ["true"]
  }

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationSource   = "ssm"
    optionalConfigurationLocation = aws_ssm_parameter.cw_agent_config.name
    optionalRestart               = "yes"
  }

  depends_on = [aws_ssm_association.install_cw_agent]
}