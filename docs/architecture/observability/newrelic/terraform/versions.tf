terraform {
  required_version = ">= 1.6.0"

  # Backend parcial: bucket, region e dynamodb_table chegam por -backend-config
  # no init, a partir das variables do Environment prod. Sem state remoto cada
  # execucao comeca vazia e tenta criar de novo dashboards que ja existem, o que
  # a New Relic recusa com DUPLICATE ou, quando aceita, duplica os paineis.
  backend "s3" {
    key     = "newrelic/terraform.tfstate"
    encrypt = true
  }

  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.50"
    }
  }
}

provider "newrelic" {
  account_id = var.account_id
  api_key    = var.api_key
  region     = var.region
}
