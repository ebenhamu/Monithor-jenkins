all:
  vars:
    ansible_ssh_private_key_file: ${key_name}
    ansible_user: ${ssh_user}
    jenkins_master_ip: ${jenkins_master_ip}
    ansible_python_interpreter: /usr/bin/python3
  children:
    jenkins:
      hosts:
        jenkins-master:
          ansible_host: ${jenkins_master_ip}
    servers:
      children:
        jenkins_server: