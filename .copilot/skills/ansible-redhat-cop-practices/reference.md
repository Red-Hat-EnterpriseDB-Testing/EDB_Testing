# Red Hat COP Automation Good Practices – Reference

This file supplements the main skill with links and optional detail. Use when you need the full rationale or official wording.

## Official sources

- **Good Practices for Ansible (GPA)**: https://redhat-cop.github.io/automation-good-practices/
- **GitHub repository**: https://github.com/redhat-cop/automation-good-practices
- **Main reference (in repo)**: [reference.md](https://github.com/redhat-cop/automation-good-practices/blob/main/reference.md) – detailed guidelines and rationale

## Summary

The GPA emphasizes: roles for logic, simple playbooks, idempotency, variable naming (role-prefixed), platform-specific vars/tasks via vars files and `first_found`, inventory as SSOT for desired state, and consistent YAML/Jinja2 style. When in doubt, prefer the official GPA site or repo for the authoritative text.
