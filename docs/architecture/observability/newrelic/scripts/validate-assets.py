"""Static guardrails for the versioned W5 New Relic assets."""

from __future__ import annotations

import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
DASHBOARDS = ROOT / "dashboards"
TERRAFORM = ROOT / "terraform"


def fail(message: str) -> None:
    print(f"ERROR: {message}")
    raise SystemExit(1)


templates = sorted(DASHBOARDS.glob("*.json.tftpl"))
if len(templates) != 6:
    fail(f"W5 exige exatamente seis dashboards; encontrados {len(templates)}")

for template in templates:
    text = template.read_text(encoding="utf-8")
    if "__ACCOUNT_ID__" in text:
        fail(f"placeholder de account ID não permitido em {template.name}")
    rendered = text.replace("${account_id}", "123456789")
    try:
        document = json.loads(rendered)
    except json.JSONDecodeError as exc:
        fail(f"JSON inválido em {template.name}: {exc}")
    if not document.get("name") or not document.get("pages"):
        fail(f"dashboard incompleto em {template.name}")

terraform_text = "\n".join(
    path.read_text(encoding="utf-8") for path in TERRAFORM.glob("*.tf")
)
required_metrics = [
    "workshop.ordem_servico.created.count",
    "workshop.ordem_servico.status.duration",
    "workshop.ordem_servico.processing.error.count",
    "workshop.integration.error.count",
    "workshop.auth.cpf.attempt.count",
    "workshop.auth.cpf.failure.count",
]
for metric in required_metrics:
    if metric not in terraform_text and metric not in "".join(
        path.read_text(encoding="utf-8") for path in templates
    ):
        fail(f"métrica do contrato ausente: {metric}")

if "threshold             = 3" not in terraform_text or "threshold_duration    = 300" not in terraform_text:
    fail("alerta não define o limite de três eventos em cinco minutos")
if "notification_destination_url" not in terraform_text:
    fail("canal configurável ausente")
if "newrelic_synthetics_monitor" not in terraform_text:
    fail("monitor sintético ausente")

all_text = "\n".join(
    path.read_text(encoding="utf-8")
    for path in ROOT.rglob("*")
    if path.is_file() and path.suffix in {".tf", ".tftpl", ".md", ".py"}
)
if re.search(r"(?:AKIA|ASIA)[0-9A-Z]{16}|api[-_ ]?key\s*[:=]\s*['\"][^$\"']+", all_text, re.I):
    fail("possível segredo versionado")

print("OK: seis dashboards, alerta, notificação, synthetic e higiene validados")
