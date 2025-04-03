pipeline {
    agent any

    environment {
        CONTROL_PLANE_SCRIPT = 'setup.cp.sh'
        WORKER_SCRIPT = 'setup.wn.sh'
    }

    stages {
        // SSH into the control-plane instance and run the control-plane setup script
        stage('Setup Control Plane') {
            steps {
                script {
                    sh '''
                    ssh -o StrictHostKeyChecking=no user@control-plane.example.com << EOF
                        # Copy and run the control-plane setup script
                        cat > ${CONTROL_PLANE_SCRIPT} << 'SCRIPT'
                        #!/bin/bash
                        sudo hostnamectl set-hostname control-plane.example.com

                        cat<<EOF>>/etc/hosts
                        172.31.40.172 control-plane.example.com control-plane
                        172.31.41.162 worker-node1.example.com worker-node1
                        172.31.39.195 worker-node2.example.com worker-node2
                        EOF

                        systemctl stop ufw
                        systemctl disable ufw

                        sudo swapoff -a
                        sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

                        sudo tee /etc/modules-load.d/containerd.conf <<EOF
                        overlay
                        br_netfilter
                        EOF

                        sudo modprobe overlay
                        sudo modprobe br_netfilter

                        sudo tee /etc/sysctl.d/kubernetes.conf <<EOT
                        net.bridge.bridge-nf-call-ip6tables = 1
                        net.bridge.bridge-nf-call-iptables = 1
                        net.ipv4.ip_forward = 1
                        EOT

                        sudo sysctl --system

                        sudo apt update
                        sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

                        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
                        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

                        sudo apt update 
                        sudo apt install -y containerd.io

                        containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
                        sudo sed -i 's/SystemdCgroup \\= false/SystemdCgroup \\= true/g' /etc/containerd/config.toml

                        sudo systemctl restart containerd
                        sudo systemctl enable containerd

                        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
                        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

                        sudo apt update
                        sudo apt install -y kubelet kubeadm kubectl
                        sudo apt-mark hold kubelet kubeadm kubectl

                        sudo kubeadm config images pull

                        sudo kubeadm init --control-plane-endpoint=control-plane.example.com

                        mkdir -p $HOME/.kube
                        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
                        sudo chown $(id -u):$(id -g) $HOME/.kube/config

                        kubectl cluster-info
                        kubectl get nodes

                        kubeadm token create --print-join-command
                        SCRIPT
                        chmod +x ${CONTROL_PLANE_SCRIPT}
                        ./${CONTROL_PLANE_SCRIPT}
                    EOF
                    '''
                }
            }
        }

        // SSH into each worker node and run the worker setup script
        stage('Setup Worker Nodes') {
            steps {
                script {
                    sh '''
                    for WORKER in worker-node1.example.com worker-node2.example.com; do
                        ssh -o StrictHostKeyChecking=no user@$WORKER << EOF
                            cat > ${WORKER_SCRIPT} << 'SCRIPT'
                            #!/bin/bash
                            sudo hostnamectl set-hostname $WORKER

                            cat<<EOF>>/etc/hosts
                            172.31.40.172 control-plane.example.com control-plane
                            172.31.41.162 worker-node1.example.com worker-node1
                            172.31.39.195 worker-node2.example.com worker-node2
                            EOF

                            systemctl stop ufw
                            systemctl disable ufw

                            sudo swapoff -a
                            sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

                            sudo tee /etc/modules-load.d/containerd.conf <<EOF
                            overlay
                            br_netfilter
                            EOF
                            sudo modprobe overlay
                            sudo modprobe br_netfilter

                            sudo tee /etc/sysctl.d/kubernetes.conf <<EOT
                            net.bridge.bridge-nf-call-ip6tables = 1
                            net.bridge.bridge-nf-call-iptables = 1
                            net.ipv4.ip_forward = 1
                            EOT

                            sudo sysctl --system

                            sudo apt update
                            sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

                            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
                            sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

                            sudo apt update 
                            sudo apt install -y containerd.io

                            containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
                            sudo sed -i 's/SystemdCgroup \\= false/SystemdCgroup \\= true/g' /etc/containerd/config.toml

                            sudo systemctl restart containerd
                            sudo systemctl enable containerd

                            curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
                            echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

                            sudo apt update
                            sudo apt install -y kubelet kubeadm kubectl
                            sudo apt-mark hold kubelet kubeadm kubectl

                            kubeadm join control-plane.example.com:6443 --token hm2xhs.te22mroma0gv9ij6 --discovery-token-ca-cert-hash sha256:591f87cfa052a19b64c2712094de2720b72ab052336f8d501a880ab6b09f0cdc
                            SCRIPT
                            chmod +x ${WORKER_SCRIPT}
                            ./${WORKER_SCRIPT}
                        EOF
                    done
                    '''
                }
            }
        }

        // SSH into the control-plane instance and label worker nodes
        stage('Label Worker Nodes') {
            steps {
                script {
                    sh '''
                    ssh -o StrictHostKeyChecking=no user@control-plane.example.com << EOF
                        kubectl get nodes
                        kubectl label node worker-node1.example.com node-role.kubernetes.io/worker=worker
                        kubectl label node worker-node2.example.com node-role.kubernetes.io/worker=worker
                    EOF
                    '''
                }
            }
        }

        // SSH into the control-plane instance and display the admin.conf
        stage('Verify Configuration') {
            steps {
                script {
                    sh '''
                    ssh -o StrictHostKeyChecking=no user@control-plane.example.com << EOF
                        cat /etc/kubernetes/admin.conf
                    EOF
                    '''
                }
            }
        }
    }
}