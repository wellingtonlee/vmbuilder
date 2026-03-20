variable "source_path" {
  type        = string
  description = "Path to the base VM's VMX file"
}

variable "vm_name" {
  type        = string
  default     = "MalwareAnalysis-Win11-25H2"
  description = "Name of the virtual machine"
}

variable "winrm_username" {
  type        = string
  default     = "malware"
  description = "WinRM username (must match base VM)"
}

variable "winrm_password" {
  type        = string
  default     = "malware"
  sensitive   = true
  description = "WinRM password (must match base VM)"
}

variable "output_directory" {
  type        = string
  default     = "output"
  description = "Directory for the provisioned VM files"
}

variable "tools_yaml_path" {
  type        = string
  default     = "config/tools.yaml"
  description = "Path to the tools YAML configuration file"
}

variable "skip_verify" {
  type        = string
  default     = "0"
  description = "Set to 1 to skip post-build verification"
}
