# -*- mode: ruby -*-
# vi: set ft=ruby :
# =============================================================================
# SOC Home Lab — Vagrantfile
# Auteur : André Capito (@acapitow)
#
# Objectif : « une seule commande » (`vagrant up`) crée les 5 VM, les met sur un
# réseau interne isolé, les configure via Ansible et enrôle les agents Wazuh.
#
# Profils :
#   LAB_PROFILE=full   (défaut)  -> 5 VM, ≈16 Go de RAM côté hôte
#   LAB_PROFILE=light            -> 4 VM (sans Kali), RAM réduite, ≈8 Go
#
# Variables d'environnement reconnues (toutes optionnelles) :
#   LAB_PROFILE, LAB_SIEM_RAM, LAB_CPUS, LAB_DISABLE_WS01, LAB_DISABLE_DC01,
#   ANSIBLE_MODE (host|local), AIRGAP (true|false)
# =============================================================================

Vagrant.require_version ">= 2.3.0"

# --- Paramètres lus depuis l'environnement ----------------------------------
PROFILE       = (ENV["LAB_PROFILE"] || "full").downcase          # full | light
LIGHT         = PROFILE == "light"
ANSIBLE_MODE  = (ENV["ANSIBLE_MODE"] || "host").downcase         # host | local
AIRGAP        = (ENV["AIRGAP"] || "false").downcase == "true"    # coupe l'interface NAT
DISABLE_WS01  = (ENV["LAB_DISABLE_WS01"] || "false").downcase == "true"
DISABLE_DC01  = (ENV["LAB_DISABLE_DC01"] || "false").downcase == "true"
CPUS          = (ENV["LAB_CPUS"] || (LIGHT ? "1" : "2")).to_i
SIEM_RAM      = (ENV["LAB_SIEM_RAM"] || (LIGHT ? "3072" : "6144")).to_i

# --- Réseau interne isolé ----------------------------------------------------
LAB_NET   = "soc-lab"          # nom du réseau interne VirtualBox
SUBNET    = "10.20.0"          # => 10.20.0.0/24
NETMASK   = "255.255.255.0"

# --- Noms des boxes (centralisés pour être changés facilement) ---------------
BOX_WIN_SERVER = "gusztavvargadr/windows-server-2022-standard"
BOX_WIN_CLIENT = "gusztavvargadr/windows-11"   # ou "gusztavvargadr/windows-10"
BOX_UBUNTU     = "bento/ubuntu-22.04"
BOX_KALI       = "kalilinux/rolling"

# --- Définition déclarative des VM -------------------------------------------
# L'ordre compte : SIEM01 doit être provisionné AVANT les agents.
machines = []

# SIEM01 — Wazuh all-in-one (toujours présent)
machines << {
  name: "siem01", box: BOX_UBUNTU, ip: "#{SUBNET}.40",
  mem: SIEM_RAM, cpus: [CPUS, 2].max, os: :linux,
  playbook: "ansible/site.yml", groups: ["linux", "siem"]
}

# SRV01 — cible Linux (toujours présent)
machines << {
  name: "srv01", box: BOX_UBUNTU, ip: "#{SUBNET}.30",
  mem: 1024, cpus: 1, os: :linux,
  playbook: "ansible/site.yml", groups: ["linux", "srv", "wazuh_agents"]
}

# DC01 — contrôleur de domaine (sauf si désactivé)
unless DISABLE_DC01
  machines << {
    name: "dc01", box: BOX_WIN_SERVER, ip: "#{SUBNET}.10",
    mem: LIGHT ? 2048 : 4096, cpus: CPUS, os: :windows,
    playbook: "ansible/site.yml", groups: ["windows", "dc", "wazuh_agents"]
  }
end

# WS01 — poste joint au domaine (sauf si désactivé / profil minimal)
unless DISABLE_WS01 || DISABLE_DC01
  machines << {
    name: "ws01", box: BOX_WIN_CLIENT, ip: "#{SUBNET}.20",
    mem: LIGHT ? 2048 : 4096, cpus: CPUS, os: :windows,
    playbook: "ansible/site.yml", groups: ["windows", "ws", "wazuh_agents"]
  }
end

# ATTACK01 — Kali, désactivé en profil léger
unless LIGHT
  machines << {
    name: "attack01", box: BOX_KALI, ip: "#{SUBNET}.50",
    mem: 2048, cpus: CPUS, os: :linux,
    playbook: "ansible/site.yml", groups: ["linux", "attacker"]
  }
end

Vagrant.configure("2") do |config|
  config.vm.boot_timeout = 600          # boot Windows parfois long au 1er démarrage
  config.ssh.insert_key  = false

  machines.each do |m|
    config.vm.define m[:name] do |node|
      node.vm.box      = m[:box]
      node.vm.hostname = m[:name] unless m[:os] == :windows  # Windows renommé par Ansible

      # Interface réseau INTERNE isolée (porte tout le trafic du labo)
      node.vm.network "private_network",
                      ip: m[:ip],
                      netmask: NETMASK,
                      virtualbox__intnet: LAB_NET

      # Réglages VirtualBox (RAM / CPU / nom affiché)
      node.vm.provider "virtualbox" do |vb|
        vb.name   = "SOC-LAB-#{m[:name]}"
        vb.memory = m[:mem]
        vb.cpus   = m[:cpus]
        vb.gui    = false
        # Carte réseau interne en plus de la NAT par défaut de Vagrant.
        vb.customize ["modifyvm", :id, "--nic2", "intnet"]
        vb.customize ["modifyvm", :id, "--intnet2", LAB_NET]
        # AIRGAP : on débranche l'interface NAT (nic1) => plus d'accès Internet.
        # À n'activer qu'APRÈS un premier provisioning réussi (`vagrant reload`).
        vb.customize ["modifyvm", :id, "--cableconnected1", AIRGAP ? "off" : "on"]
      end

      # Communicator : WinRM pour Windows, SSH pour Linux
      if m[:os] == :windows
        node.vm.communicator = "winrm"
        node.winrm.username  = "vagrant"
        node.winrm.password  = "vagrant"
        node.vm.boot_timeout = 900
      end

      # ----- Provisioning -----------------------------------------------------
      # Mode "host"  : Ansible tourne sur l'hôte (recommandé, voir docs/setup.md)
      # Mode "local" : Ansible est installé dans la VM (Linux) — utile sans WSL
      provisioner = (ANSIBLE_MODE == "local" && m[:os] == :linux) ? "ansible_local" : "ansible"

      node.vm.provision provisioner do |ansible|
        ansible.playbook       = m[:playbook]
        ansible.compatibility_mode = "2.0"
        ansible.limit          = m[:name]            # ne cible que cette VM
        # Regroupe la VM pour que les group_vars/<groupe>.yml s'appliquent.
        ansible.groups         = m[:groups].each_with_object({}) { |g, h| (h[g] ||= []) << m[:name] }
        ansible.extra_vars     = {
          lab_subnet: "#{SUBNET}.0/24",
          lab_profile: PROFILE,
          siem_ip: "#{SUBNET}.40",
          dc_ip: "#{SUBNET}.10"
        }
        # Décommentez pour des secrets chiffrés : ansible.vault_password_file = "ansible/.vault_pass"
      end
    end
  end

  # Message d'accueil après `vagrant up`
  config.trigger.after :up do |t|
    t.name = "SOC Home Lab prêt"
    t.info = <<~MSG
      ─────────────────────────────────────────────
      SOC Home Lab (profil: #{PROFILE}) — VM actives.
      Dashboard Wazuh : https://#{SUBNET}.40
      Lancer les scénarios : cd scenarios && ./run_all_scenarios.sh
      ─────────────────────────────────────────────
    MSG
  end
end
