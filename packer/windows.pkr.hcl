source "vmware-iso" "win11-malware" {
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  guest_os_type        = "windows11-64"
  vm_name              = var.vm_name
  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.disk_size
  disk_type_id         = 0
  disk_adapter_type    = "nvme"
  network_adapter_type = "e1000e"
  output_directory     = var.output_directory

  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "2h"

  floppy_files = [
    "${path.root}/../answer/autounattend.xml",
    "${path.root}/../answer/setup-winrm.ps1"
  ]

  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer build complete\""

  vmx_data = {
    "firmware"                = "efi"
    "uefi.secureBoot.enabled" = "FALSE"
    "vhv.enable"              = "TRUE"
  }
}

build {
  sources = ["source.vmware-iso.win11-malware"]

  # Stage 1: Upload provisioning scripts to guest
  provisioner "file" {
    source      = "${path.root}/../scripts/"
    destination = "C:\\provision\\scripts\\"
  }

  # Stage 2: Upload tools configuration
  provisioner "file" {
    source      = var.tools_yaml_path
    destination = "C:\\provision\\tools.yaml"
  }

  # Stage 3: Bootstrap Chocolatey and PowerShell YAML module
  provisioner "powershell" {
    script = "${path.root}/../scripts/install/Install-Choco.ps1"
  }

  # Stage 4: Install all tools from tools.yaml
  provisioner "powershell" {
    script = "${path.root}/../scripts/install/Install-Tools.ps1"
    environment_vars = [
      "TOOLS_YAML=C:\\provision\\tools.yaml"
    ]
    timeout = "3h"
  }

  # Stage 5: Windows hardening (Defender, Update, telemetry, UAC)
  provisioner "powershell" {
    script = "${path.root}/../scripts/config/Set-Hardening.ps1"
  }

  # Stage 6: OS cosmetic configuration (dark mode, file extensions, font)
  provisioner "powershell" {
    script = "${path.root}/../scripts/config/Set-OSConfig.ps1"
  }

  # Stage 7: Desktop layout (category folders + shortcuts)
  provisioner "powershell" {
    script = "${path.root}/../scripts/config/Set-DesktopLayout.ps1"
    environment_vars = [
      "TOOLS_YAML=C:\\provision\\tools.yaml"
    ]
  }

  # Stage 8: Reboot to apply all settings
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  # Stage 9: Post-build verification
  provisioner "powershell" {
    script = "${path.root}/../scripts/verify/Test-Build.ps1"
    environment_vars = [
      "TOOLS_YAML=C:\\provision\\tools.yaml"
    ]
  }
}
