---
name: ansible-redhat-cop-practices
description: Applies Red Hat Community of Practice (redhat-cop) Ansible good practices when writing or reviewing roles, playbooks, collections, inventories, and plugins in this project. Use when working with Ansible in EDB_Testing, editing roles or playbooks under ansible_collections/edb/postgres_operations or when the user references redhat-cop, GPA, or Ansible best practices.
---

# Red Hat COP Ansible Good Practices

Follow the [Good Practices for Ansible (GPA)](https://redhat-cop.github.io/automation-good-practices/) from the Red Hat Community of Practice. Source: [github.com/redhat-cop/automation-good-practices](https://github.com/redhat-cop/automation-good-practices).

## Guiding principles (Zen of Ansible)

- Clear is better than cluttered. Concise is better than verbose. Simple is better than complex. Readability counts.
- Playbooks are not for programming; put logic in roles or custom modules.
- Declarative is better than imperative (most of the time). Convention over configuration.
- Helping users get things done matters most. User experience beats ideological purity.
- Every task should be idempotent; support check mode where possible.

## Structures

- **Landscape** → deploy at once (workflow or "playbook of playbooks").
- **Type** → one per host; one playbook fully deploys that type.
- **Function** → implemented as a **role**; reusability.
- **Component** → task files inside a role (or separate component-roles if large); maintainability.

Use roles for actual logic; keep playbooks as a list of roles. Avoid mixing `roles` and `tasks` (with include_role/import_role) in the same play—pick one style.

## Roles

### Design and naming

- Design roles by **functionality**, not software implementation (e.g. "NTP configuration" role, not "chrony role").
- **Variable naming**: prefix all defaults and role arguments with the role name (e.g. `foo_packages`, not `packages`). Internal (non-user) variables: prefix with two underscores, e.g. `__foo_variable`.
- **Tags**: prefix with role name or a unique descriptive prefix.
- **Role names**: no dashes (causes issues with collections); use underscores if needed.
- **Modules in roles**: prefix with role name, e.g. `foo_module`.
- Do not rely on host group names in roles; use a (list) variable or make the group name a role parameter. Set that variable at group level in inventory if needed.

### Vars vs defaults

- **defaults/main.yml**: every argument from outside the role gets a default here; document in README. Use for optional keys; no meaningful default → leave commented and let the role fail if undefined.
- **vars/main.yml**: static/magic values and large lists; do not use for user-overridable defaults (high precedence).
- Required packages → `vars/main.yml` as `foo_packages`; extra packages → `foo_extra_packages` in defaults (default `[]`).

### Platform and provider

- Avoid distribution/version checks in tasks. Use **vars per platform**: e.g. `vars/RedHat_8.yml`, `vars/Fedora.yml`, loaded via `include_vars` with `role_path` and a loop from least to most specific (`os_family`, `distribution`, `distribution_major_version`, `distribution_version`). Use `ansible_facts['distribution']` (bracket notation), not `ansible_distribution`.
- Multiple implementations (providers): input variable `$ROLENAME_provider`; if unset, detect current provider or choose by OS. Set `$ROLENAME_provider_os_default` for the default per OS.
- Platform-specific **tasks**: use `lookup('first_found')` with files from most to least specific, with a `default.yml` (or `skip: true`). Use `role_path` for paths.

### Idempotency and check mode

- Roles must be idempotent and report changes correctly (no fake changes on second run). For `command:` (or similar), set `changed_when:` explicitly.
- Support check mode when possible; document and justify if not. Use idempotent modules or `check_mode:`/`changed_when:`; avoid relying on registered vars from skipped non-idempotent tasks.

### Files and templates

- Use `{{ role_path }}/vars/...` and `{{ role_path }}/tasks/...` for includes with variable filenames so files are resolved within the role only.
- Templates: add `{{ ansible_managed | comment }}` at top; no "Last modified" dates (breaks idempotent change reporting). Prefer `backup: true` unless users need it configurable.
- Document clearly which config files the role **replaces** vs modifies.

### Other role rules

- Use Galaxy-compatible skeleton; semantic versioning for tags (0.y.z until stable). Use FQCN in examples (e.g. `edb.postgres_operations.install_postgres_rhel`).
- README: purpose, required/optional arguments, idempotent (Y/N), capabilities, example playbooks, rollback if applicable.
- Sub-task files: prefix task names with a short hint, e.g. `sub | Some task description`.
- From Ansible 2.11+: use `meta/argument_specs.yml` for role argument validation.

## Coding style

- **Naming**: `snake_case`; valid Python identifiers (no special chars in variables). Mnemonic names; avoid abbreviations or capitalize them. Name all tasks, plays, and blocks; task names in **imperative** ("Ensure service is running"). No numbering in role/playbook names.
- **YAML**: indent 2 spaces; indent list contents beyond the list marker. Use `.yml` extension. Use `true`/`false` for booleans (not `yes`/`no` or `True`/`False`). Spell out task arguments in YAML form (no `key=value`). Double quotes for YAML strings; single quotes for Jinja2 strings. No quotes for short keywords like `present`, `absent`.
- **Jinja2**: one space inside `{{ }}`, e.g. `{{ myvar }}`. Use bracket notation for keys: `item['key']`, not `item.key`. Use `| bool` for bare variables in `when:`. Long lines: use YAML folding `>-`; break long `when:` (and conditions) into a list. Prefer filter plugins over complex Jinja for data transformation.
- **Tasks**: prefer dedicated modules over `command`/`shell`; if using them, add a comment and ensure idempotency/check mode. Do not use `meta: end_play` (use `meta: end_host` if needed). Dynamic task names: put Jinja at the **end** of the name string (e.g. "Manage device {{ device }}"). Avoid variables in play names and in default loop variable in task names.
- **Debug**: set `verbosity:` on debug tasks so production logs stay clean.

## Playbooks

- Keep playbooks **simple**: ideally a list of roles (or a list of import_role/include_role tasks). Put logic in roles.
- Use either **roles** or **tasks** (with import_role/include_role), not both in the same play.
- **Tags**: use only (1) role-named tags to enable/disable roles, or (2) purpose-level tags that are safe to run alone. One tag should be enough for a meaningful outcome. Document tags. Never use tags that are unsafe or meaningless when used alone.

## Collections

- Structure at type or landscape level. Package roles in a collection for distribution and execution environments.
- Collection-wide variables: document them; reference in role defaults, e.g. `alpha_controller_username: "{{ mycollection_controller_username }}"`. Keep role variable naming (e.g. `alpha_*`) so roles stay reusable outside the collection.
- Include root README (purpose, license link, supported ansible-core versions, dependencies) and LICENSE or COPYING.

## Inventories

- **Single source of truth (SSOT)**: identify SSOTs (cloud/CMDB/inventory) and combine via dynamic inventory; keep only what is not provided elsewhere in static inventory.
- **As-Is vs To-Be**: keep discovered state (facts) separate from desired state (variables). Do not mix them.
- **Structure**: use an **inventory directory** with `group_vars/`, `host_vars/` (directories per group/host with one or more YAML files), and host/group lists. Avoid a single monolithic file when combining multiple sources.
- **Loop over hosts**: run plays against inventory groups and use host/group variables; do not maintain a separate list of hosts and loop over it. Use `--limit` and Ansible's parallelism instead of hand-written loops over host lists.

## Inventories and variables (precedence)

- Prefer **inventory variables** for desired state; avoid play/playbook variables and `include_vars` for that. Use extra vars for debugging/temporary overrides, not for defining desired state.
- Restrict variable types: prefer inventory vars and role defaults; use scoped (block/task) vars only when needed (e.g. loops, temporary values).

## Plugins

- Document all plugins (parameters, return values, examples). Use reST/Sphinx docstrings and Python type hints. Prefer **pytest** for unit tests. Keep plugin entry files small; move reusable logic to module_utils/ or plugin_utils/. Use ansible.plugin_builder for new plugins. Use clear, specific error messages and appropriate verbosity for info.

## Quick checklist when writing or reviewing

- [ ] Role vars/defaults prefixed with role name; internals with `__`.
- [ ] No hardcoded group names; use variables or parameters.
- [ ] Platform-specific data in vars files; paths use `role_path`.
- [ ] Idempotent tasks; `changed_when:` for command/shell where needed.
- [ ] Playbook is simple (roles or import_role list); not mixing roles + tasks section.
- [ ] Tags are role-level or purpose-level and safe alone.
- [ ] Bracket notation for facts/vars; imperative task names; `.yml`; 2-space indent.
- [ ] Inventory as directory with group_vars/host_vars; desired state in inventory, not extra vars.

## Project context (EDB_Testing)

- Collection namespace: `edb.postgres_operations`. Roles: `deploy_cluster`, `deploy_replica_cluster`, `install_postgres_rhel`, `manage_aap_cluster`, `efm_integration`, `check_health`, `execute_sql`.
- Playbooks live under `ansible_collections/edb/postgres_operations/playbooks/` (at project root). Keep them as thin wrappers that call roles with optional vars.
- When adding or changing roles, follow the variable-prefix rule (e.g. `install_postgres_rhel_app_password`, `deploy_cluster_edb_pull_secret_name`).

## Additional resources

- Full guidelines and rationale: [reference.md](reference.md) (if present)
- Official GPA site: https://redhat-cop.github.io/automation-good-practices/
- Red Hat COP repo: https://github.com/redhat-cop/automation-good-practices
