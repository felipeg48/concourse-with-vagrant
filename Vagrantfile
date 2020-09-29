IMAGE_NAME = "bento/ubuntu-20.04"
N = 1

Vagrant.configure("2") do |config|
    config.ssh.insert_key = false

    config.vm.provider "virtualbox" do |v|
        v.memory = 2048
        v.cpus = 2
    end

    config.vm.define "concourse-web" do |web|
        web.vm.box = IMAGE_NAME
        web.vm.network "private_network", ip: "192.168.50.10"
        web.vm.hostname = "concourse-web"
        web.vm.synced_folder "keys/", "/vagrant"
        web.vm.provision "shell", path: "setup/concourse-setup.sh"
    end

    (1..N).each do |i|
        config.vm.define "concourse-worker-#{i}" do |worker|
            worker.vm.box = IMAGE_NAME
            worker.vm.network "private_network", ip: "192.168.50.#{i + 11}"
            worker.vm.hostname = "concourse-worker-#{i}"
            worker.vm.synced_folder "keys/", "/vagrant"
            worker.vm.provision :shell, :path => "setup/worker-setup.sh"
        end
    end
end