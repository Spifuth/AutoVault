# AutoVault Hooks

This directory contains custom hooks that are executed at various points during AutoVault operations.

## Available Hooks

| Hook | When | Can Cancel |
|------|------|------------|
| `pre-customer-remove` | Before removing a customer | ✅ Yes |
| `post-customer-remove` | After removing a customer | ❌ No |
| `post-templates-apply` | After applying templates | ❌ No |
| `on-error` | When any error occurs | ❌ No |

## Creating a Hook

1. Copy the example file: `cp pre-customer-remove.sh.example pre-customer-remove.sh`
2. Make it executable: `chmod +x pre-customer-remove.sh`
3. Edit to add your logic

## Hook Interface

Hooks receive context as arguments and environment variables:

### Arguments
- `$1`, `$2`, etc. - Context specific to the hook (see examples)

### Environment Variables
- `VAULT_ROOT` - Path to the Obsidian vault
- `CONFIG_JSON` - Path to the configuration file
- `AUTOVAULT_HOOK` - Name of the current hook
- `AUTOVAULT_OPERATION` - Operation being performed

## Exit Codes

- **Pre-hooks**: Return non-zero to cancel the operation
- **Post-hooks**: Return value is logged but doesn't affect operation
- **on-error**: Return value is ignored

## Disabling Hooks

Set environment variable: `AUTOVAULT_HOOKS_ENABLED=false`

## Custom Hooks Directory

Set environment variable: `AUTOVAULT_HOOKS_DIR=/path/to/hooks`
