terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

locals {
  instance_type = "t2.micro"
}

resource "aws_instance" "jenkins" {
  count         = 1  # Set to desired number of instances
  ami           = var.ami
  instance_type = var.instance_type
  key_name = var.key_name
  vpc_security_group_ids = [var.security_group_id]
  tags = {
    Name = "Monithor-Jenkins-Master"
    Managed_By  = "Terraform"
  }
}

# resource "aws_instance" "control_plane" {
#   ami           = "ami-05d38da78ce859165"
#   instance_type = local.instance_type
#   count         = 1
#   key_name      = var.key_name
#   tags = {
#     Name     = "monithor_control_plane"
#     k8s_role = "monithor_control_plane"
#   }
#     root_block_device {
#     volume_size = 10  # Set the root disk size to 10GB
#     volume_type = "gp2"  # You can specify the volume type as well, default is "gp2"
#   }
# }

# resource "aws_instance" "worker" {
#   ami           = "ami-05d38da78ce859165"
#   instance_type = local.instance_type
#   count         = 2
#   key_name      = var.key_name

#   tags = {  
#     Name     = "monithor_worker_${count.index + 1}"
#     k8s_role = "monithor_worker"
#   }
#     root_block_device {
#     volume_size = 10  # Set the root disk size to 10GB
#     volume_type = "gp2"  # You can specify the volume type as well, default is "gp2"
#   }
# }

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.yaml"
  content  = templatefile("${path.module}/../ansible/inventory.yaml.tpl", {
    key_name            = "${var.key_path}/${var.key_name}.pem"
    ssh_user            = var.ssh_user
    jenkins_master_ip   = aws_instance.jenkins[0].public_ip
  })
}

resource "local_file" "ansible_cfg" {
  content = templatefile("${path.module}/../ansible/ansible.cfg.tpl", {
    inventory_file = "${path.module}/../ansible/inventory.yaml"
    remote_user = var.ssh_user
    private_key_file = "${var.key_path}${var.key_name}.pem"
    host_key_checking = false
  })
  filename = "${path.module}/../ansible/ansible.cfg"
}

resource "null_resource" "run_ansible" {
  depends_on = [local_file.ansible_inventory]

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ${path.module}/../ansible/inventory.yaml ${path.module}/../ansible/main.yaml "
  }
}

# output "public_ips" {
#   value = {
#     control_pane = aws_instance.control_plane.*.public_ip
#     workers       = { for i, worker in aws_instance.worker : "worker_${i + 1}" => worker.public_ip }
    
#   }
# }

# output "private_ips" {
#   value = {
#     control_pane = aws_instance.control_plane.*.private_ip
#     workers       = { for i, worker in aws_instance.worker : "worker_${i + 1}" => worker.private_ip }
#   }
# }

# output "jenkins_master_ip" {
#   value = aws_instance.jenkins[0].public_ip
# }