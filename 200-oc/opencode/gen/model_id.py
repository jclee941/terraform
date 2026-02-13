"""Model ID transformation for opencode variants.

Translates base model names (e.g. 'claude-opus-4-6-thinking') into
provider-prefixed IDs (e.g. 'google/antigravity-claude-opus-4-6-thinking')
based on variant and provider rules.

Rules (in priority order):
  1. anti + haiku → github-copilot fallback with dot notation
  2. copilot + anthropic → strip -thinking, apply dot notation
  3. main/claude (non-anti, non-copilot) → strip -thinking only
  4. anti (non-haiku) → keep base_model as-is (antigravity supports -thinking)
  5. All others → apply provider template directly
"""

from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass(frozen=True)
class AgentSpec:
    model: str
    provider: str
    temperature: float | None = None
    thinking_budget: str | None = None


def apply_dot_notation(model: str) -> str:
    result = re.sub(r'-(\d+)-(\d+)$', r'-\1.\2', model)
    result = re.sub(r'-(\d+)-(\d+)-', r'-\1.\2-', result)
    return result


def strip_thinking(model: str) -> str:
    return re.sub(r'-thinking$', '', model)


def is_haiku(model: str) -> bool:
    return 'haiku' in model


PROVIDER_TEMPLATES_BASE: dict[str, str] = {
    'anthropic': 'anthropic/{model}',
    'openai': 'openai/{model}',
    'google': 'google/antigravity-{model}',
    'opencode': 'opencode/{model}',
}

PROVIDER_OVERRIDES: dict[str, dict[str, str]] = {
    'anti': {
        'anthropic': 'google/antigravity-{model}',
    },
    'copilot': {
        'anthropic': 'github-copilot/{model}',
    },
}


def get_provider_template(variant: str, provider: str) -> str:
    overrides = PROVIDER_OVERRIDES.get(variant, {})
    if provider in overrides:
        return overrides[provider]
    return PROVIDER_TEMPLATES_BASE.get(provider, '{model}')


def resolve_model_id(
    variant: str,
    base_model: str,
    provider: str,
) -> str:
    """Resolve a base model name to a fully-qualified model ID.

    Args:
        variant: One of 'main', 'claude', 'anti', 'copilot'.
        base_model: Raw model name (e.g. 'claude-opus-4-6-thinking').
        provider: Provider key (e.g. 'anthropic', 'openai', 'google').

    Returns:
        Fully-qualified model ID string.
    """
    template = get_provider_template(variant, provider)

    if variant == 'anti':
        if is_haiku(base_model):
            # Rule 1: anti + haiku → github-copilot fallback with dot notation.
            transformed = apply_dot_notation(base_model)
            return f'github-copilot/{transformed}'
        else:
            # Rule 4: anti (non-haiku) → keep as-is, antigravity supports
            # -thinking model IDs natively.
            return template.replace('{model}', base_model)

    elif variant == 'copilot':
        if provider == 'anthropic':
            # Rule 2: copilot + anthropic → strip -thinking, dot notation.
            transformed = strip_thinking(base_model)
            transformed = apply_dot_notation(transformed)
            return template.replace('{model}', transformed)
        else:
            return template.replace('{model}', base_model)

    else:
        # Rule 3: main/claude → strip -thinking only.
        if provider == 'anthropic':
            transformed = strip_thinking(base_model)
            return template.replace('{model}', transformed)
        else:
            return template.replace('{model}', base_model)


def resolve_agents(
    variant: str,
    agents: dict[str, AgentSpec],
) -> dict[str, dict]:

    result = {}
    for name, spec in agents.items():
        model_id = resolve_model_id(variant, spec.model, spec.provider)
        entry: dict = {'model': model_id}
        if spec.temperature is not None:
            entry['temperature'] = spec.temperature
        if spec.thinking_budget is not None:
            entry['variant'] = spec.thinking_budget
        result[name] = entry
    return result


def resolve_categories(
    variant: str,
    categories: dict[str, AgentSpec],
) -> dict[str, dict]:

    return resolve_agents(variant, categories)
