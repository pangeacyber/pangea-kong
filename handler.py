#! /usr/bin/env python3

import pathlib
import json
import os
from traceback import format_exception
import typing as t

import kong_pdk.pdk.kong as kong

from pangea import PangeaConfig
from pangea.services.ai_guard import AIGuard

token = os.getenv("PANGEA_AI_GUARD_TOKEN", "")

Schema = (
    {"message": {"type": "string"}},
)
version = '0.1.0'
priority = 0

DEFAULT_PANGEA_DOMAIN = "aws.us.pangea.cloud"


class Operation:
    def __init__(self, op_params: dict):
        self.json = op_params
        self.recipe = op_params.get("recipe", "pangea_prompt_guard")


class Rule:
    def __init__(self, rule: dict):
        self.rule = rule
        self.host = rule.get("host")
        self.endpoint = rule.get("endpoint")
        self.protos = rule.get("protocols")
        self.ports = rule.get("ports")
        self.recipe = rule.get("recipe")

    def match(self, host, endpoint, port, protocol) -> bool:
        if host != self.host or endpoint != self.endpoint:
            return False
        if self.protos and protocol not in self.protos:
            return False
        if self.ports and port not in self.ports:
            return False
        return True

    def operation_params(self, op, service="ai_guard") -> t.Optional[Operation]:
        svc = self.rule.get(service)
        if not svc:
            return None
        info = svc.get(op)
        if info is None or not info.get("enabled", True):
            return None
        return Operation(info)


class PangeaKongConfig:
    def __init__(self, j: dict):
        self.domain = j.get("pangea_domain")
        self.insecure = j.get("insecure", False)
        if not self.domain:
            self.domain = DEFAULT_PANGEA_DOMAIN
        rules = j.get("rules", [])
        self.rules: t.List[Rule] = []
        for i, rule in enumerate(rules):
            if not rule.get("host"):
                kong.kong.log.warn(f"Rule {i} is missing the host, host and endpoint are required. Ignoring rule")
                continue
            if not rule.get("endpoint"):
                kong.kong.log.warn(f"Rule {i} is missing the host, host and endpoint are required. Ignoring rule")
                continue
            self.rules.append(Rule(rule))

    def match_rule(self, k: kong.kong) -> t.Optional[Rule]:
        proto, err = k.request.get_scheme()
        if err:
            k.log.err(f"failed to get scheme: {err}")
            return
        host, err = k.request.get_host()
        if err:
            k.log.err(f"failed to get host: {err}")
            return
        port, err = k.request.get_port()
        if err:
            k.log.err(f"failed to get port: {err}")
            return
        endpoint, err = k.request.get_path()
        if err:
            k.log.err(f"failed to get endpoint: {err}")
            return
        for rule in self.rules:
            if rule.match(host, endpoint, port, proto):
                return rule


def load_config():
    loc = os.getenv("PANGEA_KONG_CONFIG_FILE")
    if not loc:
        pth = pathlib.Path(__file__).parent / "pangea_kong_config.json"
    else:
        pth = pathlib.Path(loc)
    if pth.exists():
        json_config = json.load(open(pth))
        return PangeaKongConfig(json_config)
    else:
        kong.kong.log.warn(f"No config provided, using default")
        return PangeaKongConfig(default_config)


default_config = {
  "pangea_domain": DEFAULT_PANGEA_DOMAIN,
  "rules": [
    {
      "host": "api.openai.com",
      "endpoint": "/v1/chat/completions",
      "protocols": ["https"],
      "ports": ["443"],
      "audit_values": {
        "model": "openai"
      },
      "format": "openai",
      "ai_guard": {
        "request": {
          "parameters": {
            "recipe": "pangea_prompt_guard",
          }
        },
        "response": {
        }
      }
    }
  ]
}


config = load_config()


class Plugin:
    def __init__(self, k_config):
        self.k_config = k_config
        kwargs = {
            "domain": config.domain,
        }
        if not config.domain.endswith(".pangea.cloud"):
            kwargs["environment"] = "local"
        if config.insecure:
            kwargs["insecure"] = True

        self.ai_guard = AIGuard(token, config=PangeaConfig(**kwargs))

    def access(self, k: kong.kong):
        try:
            rule = config.match_rule(k)
            if not rule:
                k.log.debug(f"No rule matched {k.request.get_host()}{k.request.get_path()}, allowing")
                return
            op = rule.operation_params("request")
            if op is None:
                k.log.debug(f"No work for 'request', allowing")
                return
            text = k.request.get_raw_body()
            response = self.ai_guard.guard_text(str(text), recipe=op.recipe)
            if response.http_status != 200:
                k.log.err(f"Failed to call AI Guard: {response.status_code}, {response.text}")
                return
            new_prompt = response.json["result"].get("prompt_text")
            blocked = response.json["result"].get("blocked", False)
            if blocked:
                for name, result in response.json["result"]["detectors"].items():
                    if result.get("detected", False):
                        k.log.warn(f"Detected unwanted prompt characteristics: {name}, {json.dumps(response.json)}")
                        return k.response.error(400, "Prompt has been rejected", {"Content-Type": "text/html"})
            else:
                k.log.debug(f"Prompt allowed: {json.dumps(response.json)}")
                if new_prompt:
                    k.service.request.set_raw_body(new_prompt)
        except Exception as e:
            k.log.err(f"Exception while trying to call AI Guard:\n {format_exception(e)}")


# for running in a dedicated process
if __name__ == "__main__":
    from kong_pdk.cli import start_dedicated_server
    start_dedicated_server("pangea_kong", Plugin, version, priority, Schema)
