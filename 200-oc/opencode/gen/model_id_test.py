"""Unit tests for model_id.py."""

import unittest
from model_id import (
    AgentSpec,
    apply_dot_notation,
    strip_thinking,
    is_haiku,
    get_provider_template,
    resolve_model_id,
    resolve_agents,
    resolve_categories,
    PROVIDER_TEMPLATES_BASE,
    PROVIDER_OVERRIDES,
)


class TestApplyDotNotation(unittest.TestCase):
    def test_converts_4_5(self):
        self.assertEqual(apply_dot_notation("claude-sonnet-4-5"), "claude-sonnet-4.5")

    def test_converts_4_6(self):
        self.assertEqual(apply_dot_notation("claude-opus-4-6-thinking"), "claude-opus-4.6-thinking")

    def test_no_match(self):
        self.assertEqual(apply_dot_notation("gpt-5.2"), "gpt-5.2")

    def test_haiku_4_5(self):
        self.assertEqual(apply_dot_notation("claude-haiku-4-5"), "claude-haiku-4.5")


class TestStripThinking(unittest.TestCase):
    def test_strips_suffix(self):
        self.assertEqual(strip_thinking("claude-opus-4-6-thinking"), "claude-opus-4-6")

    def test_no_suffix(self):
        self.assertEqual(strip_thinking("claude-sonnet-4-5"), "claude-sonnet-4-5")

    def test_non_claude(self):
        self.assertEqual(strip_thinking("gpt-5.2"), "gpt-5.2")


class TestIsHaiku(unittest.TestCase):
    def test_haiku(self):
        self.assertTrue(is_haiku("claude-haiku-4-5"))

    def test_not_haiku(self):
        self.assertFalse(is_haiku("claude-opus-4-6-thinking"))

    def test_gpt(self):
        self.assertFalse(is_haiku("gpt-5.2"))


class TestGetProviderTemplate(unittest.TestCase):
    def test_base_anthropic(self):
        self.assertEqual(get_provider_template("main", "anthropic"), "anthropic/{model}")

    def test_base_openai(self):
        self.assertEqual(get_provider_template("claude", "openai"), "openai/{model}")

    def test_base_google(self):
        self.assertEqual(get_provider_template("main", "google"), "google/antigravity-{model}")

    def test_anti_anthropic_override(self):
        self.assertEqual(get_provider_template("anti", "anthropic"), "google/antigravity-{model}")

    def test_copilot_anthropic_override(self):
        self.assertEqual(get_provider_template("copilot", "anthropic"), "github-copilot/{model}")

    def test_anti_openai_no_override(self):
        self.assertEqual(get_provider_template("anti", "openai"), "openai/{model}")


class TestResolveModelId(unittest.TestCase):
    """Tests for the 4 resolution rules."""

    # Rule 1: anti + haiku → github-copilot fallback + dot notation
    def test_anti_haiku_fallback(self):
        result = resolve_model_id("anti", "claude-haiku-4-5", "anthropic")
        self.assertEqual(result, "github-copilot/claude-haiku-4.5")

    # Rule 2: copilot + anthropic → strip -thinking + dot notation
    def test_copilot_anthropic_thinking(self):
        result = resolve_model_id("copilot", "claude-opus-4-6-thinking", "anthropic")
        self.assertEqual(result, "github-copilot/claude-opus-4.6")

    def test_copilot_anthropic_no_thinking(self):
        result = resolve_model_id("copilot", "claude-sonnet-4-5", "anthropic")
        self.assertEqual(result, "github-copilot/claude-sonnet-4.5")

    # Rule 3: main/claude → strip -thinking only
    def test_main_anthropic_thinking(self):
        result = resolve_model_id("main", "claude-opus-4-6-thinking", "anthropic")
        self.assertEqual(result, "anthropic/claude-opus-4-6")

    def test_claude_anthropic_thinking(self):
        result = resolve_model_id("claude", "claude-opus-4-6-thinking", "anthropic")
        self.assertEqual(result, "anthropic/claude-opus-4-6")

    def test_main_anthropic_no_thinking(self):
        result = resolve_model_id("main", "claude-sonnet-4-5", "anthropic")
        self.assertEqual(result, "anthropic/claude-sonnet-4-5")

    # Rule 4: anti (non-haiku) → keep as-is (antigravity supports -thinking)
    def test_anti_non_haiku_keeps_thinking(self):
        result = resolve_model_id("anti", "claude-opus-4-6-thinking", "anthropic")
        self.assertEqual(result, "google/antigravity-claude-opus-4-6-thinking")

    def test_anti_sonnet(self):
        result = resolve_model_id("anti", "claude-sonnet-4-5", "anthropic")
        self.assertEqual(result, "google/antigravity-claude-sonnet-4-5")

    # Other providers (no special rules)
    def test_openai_main(self):
        result = resolve_model_id("main", "gpt-5.2", "openai")
        self.assertEqual(result, "openai/gpt-5.2")

    def test_openai_anti(self):
        result = resolve_model_id("anti", "gpt-5.2", "openai")
        self.assertEqual(result, "openai/gpt-5.2")

    def test_google_main(self):
        result = resolve_model_id("main", "gemini-3-flash", "google")
        self.assertEqual(result, "google/antigravity-gemini-3-flash")

    def test_google_anti(self):
        result = resolve_model_id("anti", "gemini-3-flash", "google")
        self.assertEqual(result, "google/antigravity-gemini-3-flash")

    def test_copilot_openai(self):
        result = resolve_model_id("copilot", "gpt-5.2", "openai")
        self.assertEqual(result, "openai/gpt-5.2")


class TestResolveAgents(unittest.TestCase):
    def test_returns_dict(self):
        agents = {"test": AgentSpec(model="claude-opus-4-6-thinking", provider="anthropic")}
        result = resolve_agents("main", agents)
        self.assertIsInstance(result, dict)
        self.assertIn("test", result)

    def test_includes_model(self):
        agents = {"test": AgentSpec(model="claude-opus-4-6-thinking", provider="anthropic")}
        result = resolve_agents("main", agents)
        self.assertEqual(result["test"]["model"], "anthropic/claude-opus-4-6")

    def test_includes_temperature(self):
        agents = {"test": AgentSpec(model="gpt-5.2", provider="openai", temperature=0.5)}
        result = resolve_agents("main", agents)
        self.assertEqual(result["test"]["temperature"], 0.5)

    def test_excludes_none_temperature(self):
        agents = {"test": AgentSpec(model="gpt-5.2", provider="openai")}
        result = resolve_agents("main", agents)
        self.assertNotIn("temperature", result["test"])

    def test_includes_thinking_budget(self):
        agents = {"test": AgentSpec(
            model="claude-opus-4-6-thinking", provider="anthropic",
            thinking_budget="max",
        )}
        result = resolve_agents("main", agents)
        self.assertEqual(result["test"]["variant"], "max")

    def test_excludes_none_thinking_budget(self):
        agents = {"test": AgentSpec(model="claude-sonnet-4-5", provider="anthropic")}
        result = resolve_agents("main", agents)
        self.assertNotIn("variant", result["test"])


class TestResolveCategories(unittest.TestCase):
    def test_returns_dict(self):
        cats = {"quick": AgentSpec(model="claude-haiku-4-5", provider="anthropic")}
        result = resolve_categories("anti", cats)
        self.assertIsInstance(result, dict)
        self.assertIn("quick", result)

    def test_anti_haiku_fallback(self):
        cats = {"quick": AgentSpec(model="claude-haiku-4-5", provider="anthropic")}
        result = resolve_categories("anti", cats)
        self.assertEqual(result["quick"]["model"], "github-copilot/claude-haiku-4.5")


class TestIntegration(unittest.TestCase):
    """Integration tests with real config data."""

    def test_all_variants_all_agents(self):
        """Ensure resolve_model_id doesn't crash for any combination."""
        from config import AGENTS, VARIANTS

        for variant_name in VARIANTS:
            for agent_name, spec in AGENTS.items():
                model_id = resolve_model_id(variant_name, spec.model, spec.provider)
                self.assertIsInstance(model_id, str)
                self.assertGreater(len(model_id), 0, f"{variant_name}/{agent_name}")
                self.assertIn("/", model_id, f"{variant_name}/{agent_name}: {model_id}")

    def test_all_variants_all_categories(self):
        """Ensure resolve_model_id doesn't crash for any combination."""
        from config import CATEGORIES, VARIANTS

        for variant_name in VARIANTS:
            for cat_name, spec in CATEGORIES.items():
                model_id = resolve_model_id(variant_name, spec.model, spec.provider)
                self.assertIsInstance(model_id, str)
                self.assertGreater(len(model_id), 0, f"{variant_name}/{cat_name}")
                self.assertIn("/", model_id, f"{variant_name}/{cat_name}: {model_id}")


if __name__ == "__main__":
    unittest.main()
