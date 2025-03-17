#! /usr/bin/env python3

import pathlib
import json
import os
from traceback import format_exception
import typing as t

import kong_pdk.pdk.kong as kong

from pangea import PangeaConfig
from pangea.services.ai_guard import AIGuard
from pangea_translator import get_translator

token_secret = os.getenv("PANGEA_AI_GUARD_TOKEN", "")
with open(token_secret) as f: token = f.read()

Schema = (
    {"message": {"type": "string"}},
)
version = '0.1.0'
priority = 0

DEFAULT_PANGEA_DOMAIN = "aws.us.pangea.cloud"


class Operation:
    def __init__(self, op_params: dict):
        self.json = op_params.copy()
        if "recipe" not in self.json:
            self.json["recipe"] = "pangea_prompt_guard"


class Rule:
    def __init__(self, rule: dict):
        self.rule = rule
        self.host = rule.get("host")
        self.endpoint = rule.get("endpoint")
        self.prefix = rule.get("prefix")
        self.protos = rule.get("protocols")
        self.ports = rule.get("ports")
        self.parser = rule.get("parser")
        self.allow_failure = rule.get("allow_on_error", False)

    def match(self, host, endpoint, port, protocol, prefix) -> bool:
        if host != self.host:
            return False
        if self.endpoint and endpoint != self.endpoint:
            return False
        if self.prefix and prefix != self.prefix:
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
        info = svc.get(op, {}).get("parameters")
        if info is None or info.get("enabled", True) is not True:
            return None
        return Operation(info)


class PangeaKongConfig:
    def __init__(self, j: dict):
        self.domain = j.get("pangea_domain")
        self.insecure = j.get("insecure", False)
        self.header_recipe_map = j.get("headers", {})
        if not self.domain:
            self.domain = DEFAULT_PANGEA_DOMAIN
        rules = j.get("rules", [])
        self.rules: t.List[Rule] = []
        for i, rule in enumerate(rules):
            if not rule.get("host"):
                kong.kong.log.warn(f"Rule {i} is missing the host which is required. Ignoring rule")
                continue
            endpoint = rule.get("endpoint")
            prefix = rule.get("prefix")
            if not endpoint or not prefix:
                kong.kong.log.warn(f"Rule {i} is missing the endpoint or forwarding prefix, at least one is required. Ignoring rule")
                continue
            self.rules.append(Rule(rule))

    def match_rule(self, k: kong.kong) -> t.Optional[Rule]:
        proto, err = k.request.get_forwarded_scheme()
        if err:
            k.log.err(f"failed to get scheme: {err}")
            return None
        host, err = k.request.get_forwarded_host()
        if err:
            k.log.err(f"failed to get host: {err}")
            return None
        port, err = k.request.get_forwarded_port()
        if err:
            k.log.err(f"failed to get port: {err}")
            return None
        endpoint, err = k.request.get_forwarded_path()
        if err:
            k.log.err(f"failed to get endpoint: {err}")
            return None
        prefix, err = k.request.get_forwarded_prefix()
        if err:
            prefix = None
        if prefix and endpoint.startswith(prefix):
            endpoint = endpoint[len(prefix):]
        for rule in self.rules:
            if rule.match(host, endpoint, port, proto, prefix):
                return rule

        return None

def load_config():
    loc = os.getenv("PANGEA_KONG_CONFIG_FILE")
    if loc:
        pth = pathlib.Path(loc)
    else:
        pth = pathlib.Path("/etc/pangea_kong_config.json")
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
      # "prefix": "/a_prefix",
      "allow_on_error": False,
      "protocols": ["https"],
      "ports": ["443"],
      "audit_values": {
        "model": "openai"
      },
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
        allow_failure = False
        try:
            rule = config.match_rule(k)
            if not rule:
                k.log.debug(f"No rule matched {k.request.get_host()}{k.request.get_path()}, allowing")
                return
            allow_failure = rule.allow_failure is True
            op = rule.operation_params("request")
            k.log.debug(f"Rule op: {json.dumps(op.json)}")
            if op is None:
                k.log.debug(f"No work for 'request', allowing")
                return

            k.log.debug(f"Request headers: {k.request.get_headers()}")
            # recipe is in the config, but can be overridden by this header
            recipe = k.request.get_header("x-pangea-aig-recipe")
            if recipe and recipe[0]:
                # it comes in an array
                recipe = recipe[0]
            else:
                recipe = None
            # can be further overridden by the configured header/recipe map
            # for header_name, recipe_map in config.header_recipe_map.items():
            #     header_name = header_name.lower()
            #     header = k.request.get_header(header_name)
            #     if not header:
            #         continue
            #     else:
            #         header = header[0]
            #     if header in recipe_map:
            #         recipe = recipe_map[header]
            if recipe:
                op.json["recipe"] = recipe

            text, err = k.request.get_raw_body()
            if err:
                k.log.err(f"Got error when getting request raw body: '{err}'")
            translator = None
            log_fields = {
                "model": f'{{"provider": "{rule.parser}"}}',
                "extra_info": f'{{"api": "{k.request.get_forwarded_path()[0]}"}}',
            }
            op.json["log_fields"] = log_fields
            try:
                if isinstance(text, bytes):
                    text = text.decode("utf8")
                payload = json.loads(text)
                k.log.debug(f"PARAMS: {json.dumps(op.json)}")
                if rule.parser:
                    translator = get_translator(payload, llm_hint=rule.parser)
                    model, model_version = translator.get_model_and_version()
                    if not model_version:
                        model_version = "null"
                    log_fields["model"] = f'{{"provider": "{rule.parser}", "model": "{model}", "version": {model_version}}}'
                    pangea_messages = translator.get_pangea_messages()
                    response = self.ai_guard.guard_text(messages=pangea_messages.messages, **op.json)
                else:
                    response = self.ai_guard.guard_text(messages=payload, **op.json)
            except (json.JSONDecodeError, TypeError) as e:
                k.log.debug(f"JSON parse failed: {str(e)}")
                k.log.debug(f"JSON parse failed: {repr(text)}")
                response = self.ai_guard.guard_text(str(text), **op.json)

            if response.http_status != 200:
                k.log.err(f"Failed to call AI Guard: {response.status_code}, {response.text}")
                raise Exception("Failed to call AI Guard")

            new_prompt = response.json["result"].get("prompt_text")
            if not new_prompt:
                new_prompt = response.json["result"].get("prompt_messages")
                if rule.parser and translator:
                    new_prompt = translator.transformed_original_input(messages=new_prompt)

                new_prompt = json.dumps(new_prompt)
            else:
                new_prompt = str(new_prompt)

            blocked = response.json["result"].get("blocked", False)
            if blocked:
                for name, result in response.json["result"]["detectors"].items():
                    if result.get("detected", False):
                        k.log.warn(f"Detected unwanted prompt characteristics: {name}, {json.dumps(response.json)}")
                        return k.response.error(400, f"Prompt has been rejected: {response.json['summary']}", {"Content-Type": "text/html"})
            else:
                k.log.debug(f"Prompt allowed: {json.dumps(response.json)}")
                if new_prompt:
                    k.service.request.set_raw_body(new_prompt)
        except Exception as e:
            k.log.err(f"Exception while trying to call AI Guard:\n {format_exception(e)}")
            if not allow_failure:
                k.response.error(400, "Prompt has been rejected", {"Content-Type": "text/html"})


# for running in a dedicated process
if __name__ == "__main__":
    from kong_pdk.cli import start_dedicated_server
    start_dedicated_server("pangea_kong", Plugin, version, priority, Schema)
