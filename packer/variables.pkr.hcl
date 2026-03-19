variable "iso_url" {
  type        = string
  description = "Path to the Windows 11 25H2 ISO file"
}

variable "iso_checksum" {
  type        = string
  default     = "none"
  description = "SHA256 checksum of the ISO file (format: sha256:abc123...). Use 'none' to skip verification."
}

variable "vm_name" {
  type        = string
  default     = "MalwareAnalysis-Win11-25H2"
  description = "Name of the virtual machine"
}

variable "cpus" {
  type        = number
  default     = 4
  description = "Number of CPUs for the VM"
}

variable "memory" {
  type        = number
  default     = 8192
  description = "Memory in MB for the VM"
}

variable "disk_size" {
  type        = number
  default     = 102400
  description = "Disk size in MB for the VM"
}

variable "winrm_username" {
  type        = string
  default     = "malware"
  description = "WinRM username (must match autounattend.xml)"
}

variable "winrm_password" {
  type        = string
  default     = "malware"
  sensitive   = true
  description = "WinRM password (must match autounattend.xml)"
}

variable "output_directory" {
  type        = string
  default     = "output"
  description = "Directory for the built VM files"
}

variable "tools_yaml_path" {
  type        = string
  default     = "config/tools.yaml"
  description = "Path to the tools YAML configuration file"
}
