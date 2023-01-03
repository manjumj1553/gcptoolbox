variable "zone" {
  type = string
}

variable "project_id" {
  type = string
}

variable "project_number" {
  type = string
}

variable "basename" {
  type = string
}

variable "region" {
  type = string
}

variable "username" {
  type = string
}

variable "privatekeypath" {
    type = string
    default = "~/.ssh/id_rsa"
}

variable "publickeypath" {
    type = string
    default = "~/.ssh/id_rsa.pub"
}
