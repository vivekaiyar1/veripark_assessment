terraform {
  required_version = ">=1.10.4"


  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.20.0"
    }


    random = {
      source = "hashicorp/random"
      version = "3.6.0"
    }
  }
}
