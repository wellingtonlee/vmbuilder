source "vmware-iso" "win11-base" {
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  guest_os_type        = "windows11-64"
  vm_name              = var.vm_name
  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.disk_size
  disk_type_id         = 0
  disk_adapter_type    = "nvme"
  network_adapter_type = "vmxnet3"
  boot_wait            = "6s"
  boot_command         = ["<enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><enter>"]
  output_directory     = var.output_directory

  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "2h"

  cd_files = [
    "${path.root}/../../answer/autounattend.xml",
    "${path.root}/../../answer/setup-winrm.ps1"
  ]
  cd_label = "OEMDRV"

  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer base build complete\""

  tools_upload_flavor = "windows"
  tools_upload_path   = "C:\\Windows\\Temp\\windows.iso"
  tools_mode          = "upload"

  version    = 21
  vhv_enabled = false

  vmx_data = {
    "firmware"                = "efi"
    "uefi.secureBoot.enabled" = "FALSE"
    "usb.present"             = "TRUE"
    "ehci.present"            = "TRUE"
    "keyboard.vusb.enable"    = "TRUE"
    "mouse.vusb.enable"       = "TRUE"
  }
}

build {
  sources = ["source.vmware-iso.win11-base"]

  # Install VMware Tools from the uploaded ISO
  provisioner "powershell" {
    script = "${path.root}/../../scripts/install/Install-VMwareTools.ps1"
  }

  # Reboot after VMware Tools install
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }
}
