# Runtime parameters and formula audit

This directory keeps `prototype_config.json` and `formula_audit.py`: the former is still loaded by `scripts/sim/sim_config.gd`; the latter is used for formula checks. Do not treat the directory name as the current design version.

Current systems follow [Core design](../core_design.md), [Courtyard operations](../courtyard_ops.md), [Exploration](../exploration.md), and [Spirit beasts](../spirit_beasts.md). Old design prose and old delivery notes have been deleted. Whole-island upkeep, discoloration, and protection-quota rewards from those notes must not be restored as design requirements. Parameter files and formula-audit code are not the preferred source of product rules. Changing them requires checking actual use and tests.
