# AGENTS: modules/proxmox/config-renderer - Generated Config Pipeline

## OVERVIEW
Generic rendering module that converts template maps into generated config files consumed by 100-pve and service deploy modules.

## STRUCTURE
```text
config-renderer/
├── main.tf
└── AGENTS.md
```

## INTERFACE
| Kind | Name | Type | Required | Description |
|------|------|------|----------|-------------|
| variable | `template_vars` | `any` | Yes | Template context passed to all `templatefile(...)` calls. |
| variable | `template_files` | `map(object({source,output}))` | Yes | Template source path + output filename map. |
| variable | `output_dir` | `string` | No | Render destination directory (default `../../configs/rendered`). |
| output | `rendered_configs` | - | - | Map of rendered template content by key. |
| output | `rendered_files` | - | - | Map of emitted file paths by key. |

## CONSUMERS
- Called by `100-pve/secrets.tf` via `module.config_renderer`.
- Rendered outputs are consumed in `100-pve/lxc_configs.tf` and `100-pve/vm_configs.tf`.

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Template rendering loop | `main.tf` | `templatefile(...)` map transformation and file emission. |
| Render output paths | `main.tf` | `output_dir` + `template_files` controls generated target paths. |
| Upstream orchestrator | `100-pve/main.tf` | Supplies template vars and source files for all services. |

## CONVENTIONS
- Treat `template_vars` as a stable interface consumed by multiple templates.
- Keep template source paths explicit and workspace-relative.
- Keep output map keys deterministic for downstream output assertions.

## ANTI-PATTERNS
- Do not hand-edit generated outputs under `100-pve/configs/rendered/`.
- Do not move business logic into `.tf`; keep service specifics in `.tftpl`.
- Do not patch rendered files to fix drift; update template/input data and re-render.
