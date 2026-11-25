"""Offline structural checks for BizHunt AI Team v1 (Python 3.11+)."""
from pathlib import Path
import tomllib

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = ["product-lead","frontend-engineer","backend-engineer","qa-engineer","privacy-reviewer","growth-marketer","merchant-success"]

def main():
    directory = ROOT / ".codex" / "agents"
    paths = {path.stem: path for path in directory.glob("*.toml")}
    assert set(EXPECTED).issubset(paths), "Missing required specialist profiles"
    readme = (ROOT / "docs/ai-team/README.md").read_text(encoding="utf-8")
    names = set()
    for agent_id in EXPECTED:
        with paths[agent_id].open("rb") as source:
            config = tomllib.load(source)
        assert set(config) == {"name", "description", "developer_instructions"}, agent_id
        assert all(isinstance(v, str) and v.strip() for v in config.values()), agent_id
        name = "bizhunt_" + agent_id.replace("-", "_")
        assert config["name"] == name and name not in names, agent_id
        names.add(name)
        assert name in readme, agent_id
        for phrase in ("Mission:", "Deliverables:", "Never merge PRs or modify production Supabase", "synthetic local fixtures", "report checks actually run"):
            assert phrase in config["developer_instructions"], (agent_id, phrase)
        print(f"PASS {name}")
    print(f"Validated {len(names)} specialist profiles; no agents executed.")

if __name__ == "__main__":
    main()
