variable "account_id" {
  description = "New Relic account ID. Never commit the value to a secret-bearing file."
  type        = number
}

variable "api_key" {
  description = "New Relic User API key supplied through TF_VAR_api_key or the CI environment."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "New Relic region used by the account."
  type        = string
  default     = "US"
}

variable "environment" {
  description = "Environment used by alert NRQL filters."
  type        = string
  default     = "prod"
}

variable "notification_enabled" {
  description = "Creates the notification destination/channel/workflow when true."
  type        = bool
  default     = false
}

variable "notification_destination_type" {
  description = "Configured destination type, for example WEBHOOK or EMAIL."
  type        = string
  default     = "WEBHOOK"
}

variable "notification_destination_url" {
  description = "Notification endpoint supplied only at apply time; never commit a real URL."
  type        = string
  sensitive   = true
  default     = ""
}

variable "notification_payload" {
  description = <<-EOT
    Corpo enviado ao destino da notificacao. O default segue o contrato do Discord,
    que exige um objeto com a chave "content"; destinos com contrato proprio exigem
    o formato deles, senao respondem 400 e a notificacao falha em silencio: o
    incidente abre no New Relic e nada chega ao canal.

    As chaves duplas sao Handlebars, avaliadas pelo New Relic — nao por Terraform,
    que so interpola $${...}. Os nomes NAO usam ponto: `issue.id` e `issue.title`
    nao existem e o New Relic renderiza "N/A" no lugar. Os corretos sao:

      {{issueId}}                 identificador do incidente
      {{annotations.title.[0]}}   titulo; e lista, o `.[0]` e obrigatorio
      {{issuePageUrl}}            link para o incidente
      {{state}}                   CREATED, ACTIVATED ou CLOSED
      {{priority}}                severidade

    `{{escape ...}}` protege valores com aspas, que senao quebram o JSON.

    Mantenha apenas id, titulo, estado e link; o contrato de observabilidade
    proibe CPF, JWT, segredo e identificador de ordem de servico em notificacao.
  EOT
  type        = string
  default     = <<-EOT
    {"content": "🚨 Incidente {{issueId}} [{{state}}]: {{escape annotations.title.[0]}} — {{issuePageUrl}}"}
  EOT
}

variable "synthetic_enabled" {
  description = "Creates the synthetic monitor when true. Disabled by default until a real URL is approved."
  type        = bool
  default     = false
}

variable "synthetic_uri" {
  description = "API Gateway URL for the synthetic smoke check."
  type        = string
  default     = "https://example.invalid/api/health"
}

variable "synthetic_locations" {
  description = "Public New Relic locations for the synthetic monitor."
  type        = list(string)
  default     = ["AWS_US_EAST_1"]
}
