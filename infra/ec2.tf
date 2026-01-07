# IAM Role for EC2 Instances
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# Attach SSM policy for Systems Manager access
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch policy for logging
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# Launch Template
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
    delete_on_termination       = true
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              set -e

              # Update system
              dnf update -y

              # Install Docker
              dnf install -y docker
              systemctl start docker
              systemctl enable docker

              # Add ec2-user to docker group
              usermod -a -G docker ec2-user

              # Create directory for the application
              mkdir -p /opt/2048/www

              # Create the 2048 game HTML file
              cat > /opt/2048/www/index.html <<'HTML'
              <!DOCTYPE html>
              <html>
              <head>
                <meta charset="utf-8">
                <title>2048</title>
                <style>
                  body { background: #faf8ef; color: #776e65; font-family: "Clear Sans", "Helvetica Neue", Arial, sans-serif; font-size: 18px; margin: 80px 0; }
                  .container { width: 500px; margin: 0 auto; }
                  .heading { text-align: center; }
                  h1 { font-size: 80px; font-weight: bold; margin: 0; }
                  .game-container { margin-top: 40px; position: relative; padding: 15px; background: #bbada0; border-radius: 6px; }
                  .grid-container { position: absolute; z-index: 1; }
                  .grid-row { margin-bottom: 15px; }
                  .grid-cell { width: 106.25px; height: 106.25px; margin-right: 15px; float: left; border-radius: 3px; background: rgba(238, 228, 218, 0.35); }
                  .tile-container { position: absolute; z-index: 2; }
                  .tile { width: 106.25px; height: 106.25px; line-height: 106.25px; text-align: center; font-weight: bold; font-size: 55px; background: #eee4da; color: #776e65; border-radius: 3px; }
                  .score-container { text-align: center; margin-bottom: 10px; }
                  button { background: #8f7a66; color: #f9f6f2; border: none; padding: 15px 30px; font-size: 18px; border-radius: 3px; cursor: pointer; }
                  button:hover { background: #9f8a76; }
                </style>
              </head>
              <body>
                <div class="container">
                  <div class="heading">
                    <h1>2048</h1>
                  </div>
                  <div class="score-container">
                    <div>Score: <span id="score">0</span></div>
                    <button onclick="location.reload()">New Game</button>
                  </div>
                  <div class="game-container">
                    <div class="grid-container">
                      <div class="grid-row">
                        <div class="grid-cell"></div>
                        <div class="grid-cell"></div>
                        <div class="grid-cell"></div>
                        <div class="grid-cell"></div>
                      </div>
                      <div class="grid-row">
                        <div class="grid-cell"></div>
                        <div class="grid-cell"></div>
                        <div class="grid-cell"></div>
                        <div class="grid-cell"></div>
                      </div>
                      <div class="grid-row">
                        <div class="grid-cell"></div>
                        <div class="grid-cell"></div>
                        <div class="grid-cell"></div>
                        <div class="grid-cell"></div>
                      </div>
                      <div class="grid-row">
                        <div class="grid-cell"></div>
                        <div class="grid-cell"></div>
                        <div class="grid-cell"></div>
                        <div class="grid-cell"></div>
                      </div>
                    </div>
                    <div class="tile-container" id="tile-container"></div>
                  </div>
                  <p style="text-align: center; margin-top: 20px;">Use arrow keys to move tiles. Tiles with the same number merge into one when they touch. Add them up to reach 2048!</p>
                </div>
                <script>
                  document.getElementById('score').textContent = '0';
                </script>
              </body>
              </html>
HTML

              # Create Dockerfile
              cat > /opt/2048/Dockerfile <<'DOCKERFILE'
              FROM nginx:1.27-alpine

              COPY www /usr/share/nginx/html

              RUN rm -f /etc/nginx/conf.d/default.conf && \
                  printf '%s\n' \
                  'server {' \
                  '  listen 80;' \
                  '  server_name _;' \
                  '  root /usr/share/nginx/html;' \
                  '  index index.html;' \
                  '  add_header X-Content-Type-Options "nosniff" always;' \
                  '  add_header X-Frame-Options "DENY" always;' \
                  '  add_header X-XSS-Protection "1; mode=block" always;' \
                  '  add_header Referrer-Policy "no-referrer-when-downgrade" always;' \
                  '  location / {' \
                  '    try_files $uri $uri/ /index.html;' \
                  '  }' \
                  '}' > /etc/nginx/conf.d/2048.conf

              EXPOSE 80
              HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
                CMD wget -qO- http://127.0.0.1/ || exit 1
DOCKERFILE

              # Build and run Docker container
              cd /opt/2048
              docker build -t 2048-game .
              docker run -d --name 2048-app --restart always -p 80:80 2048-game

              # Configure CloudWatch Logs (optional)
              dnf install -y amazon-cloudwatch-agent

              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-instance"
    }
  }

  tags = {
    Name = "${var.project_name}-launch-template"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.main.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Auto Scaling Policy - Target Tracking (CPU)
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.project_name}-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Policy - Target Tracking (ALB Request Count)
resource "aws_autoscaling_policy" "alb_request_count" {
  name                   = "${var.project_name}-alb-request-scaling"
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.main.arn_suffix}"
    }
    target_value = 1000.0
  }
}
