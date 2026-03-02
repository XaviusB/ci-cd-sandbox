Vagrant.configure("2") do |config|
  config.vm.box = "Ringworld/UbuntuServer"

  # Common provider settings
  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.linked_clone = true
  end

  # -----------------------------
  # HAProxy VM
  # -----------------------------
  config.vm.define "haproxy" do |haproxy|
    haproxy.vm.hostname = "haproxy"

    # Public adapter (NAT)
    haproxy.vm.network "public_network", bridge: "en0: Wi-Fi (AirPort)", ip: "192.168.0.252"
    # Private adapter with promiscuous mode
    haproxy.vm.network "private_network", ip: "192.168.56.10", netmask: "255.255.255.0"
    haproxy.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
      vb.cpus = 1
      vb.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
    end
    haproxy.vm.synced_folder "./scripts", "/scripts"
    haproxy.vm.synced_folder "./artifacts", "/artifacts"
    haproxy.vm.provision "shell", inline: <<-SHELL
      sudo /scripts/setup-dns-server.sh
      sudo /scripts/setup-dns-client.sh
      sudo /scripts/setup-ha-proxy.sh
      sudo /scripts/setup-http-proxy.sh
      # sudo /scripts/setup-vpn.sh
      sudo /scripts/setup-ssh-jail.sh
    SHELL
  end

  # -----------------------------
  # Gitea VM
  # -----------------------------
  config.vm.define "gitea" do |gitea|
    gitea.vm.hostname = "gitea"
    gitea.vm.network "private_network", ip: "192.168.56.11", netmask: "255.255.255.0"

    gitea.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus = 2
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
    end
    gitea.vm.synced_folder "./scripts", "/scripts"
    gitea.vm.synced_folder "./artifacts", "/artifacts"
    gitea.vm.provision "shell", inline: <<-SHELL
      sudo /scripts/setup-dns-client.sh
      sudo /scripts/setup-gitea.sh
      sudo /scripts/setup-gitea-backup.sh
    SHELL
  end

  # -----------------------------
  # Nexus VM
  # -----------------------------
  config.vm.define "nexus" do |nexus|
    nexus.vm.hostname = "nexus"
    nexus.vm.network "private_network", ip: "192.168.56.12", netmask: "255.255.255.0"

    nexus.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus = 2
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
    end
    nexus.vm.synced_folder "./scripts", "/scripts"
    nexus.vm.synced_folder "./artifacts", "/artifacts"
    nexus.vm.provision "shell", inline: <<-SHELL
      sudo /scripts/setup-dns-client.sh
      sudo /scripts/setup-nexus.sh
      sudo /scripts/setup-nexus-resources.sh
    SHELL
  end

  # -----------------------------
  # Runner VM
  # -----------------------------
  config.vm.define "runner" do |runner|
    runner.vm.hostname = "runner"
    runner.vm.network "private_network", ip: "192.168.56.13"

    runner.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus = 2
    end
    runner.vm.synced_folder "./scripts", "/scripts"
    runner.vm.synced_folder "./artifacts", "/artifacts"
    runner.vm.provision "shell", inline: <<-SHELL
      sudo /scripts/setup-dns-client.sh
      sudo /scripts/setup-gitea-runner.sh
    SHELL
  end

  # -----------------------------
  # Kubernetes VM
  # -----------------------------
  config.vm.define "kube" do |kube|
    kube.vm.hostname = "kube"
    kube.vm.network "private_network", ip: "192.168.56.14"

    kube.vm.provider "virtualbox" do |vb|
      vb.memory = 10240
      vb.cpus = 4
    end
    kube.vm.synced_folder "./scripts", "/scripts"
    kube.vm.synced_folder "./artifacts", "/artifacts"
    kube.vm.provision "shell", inline: <<-SHELL
      sudo /scripts/setup-dns-client.sh
      sudo /scripts/setup-asdf.sh
      sudo /scripts/setup-kube.sh
      sudo /scripts/setup-helm-charts.sh
    SHELL
  end
end
