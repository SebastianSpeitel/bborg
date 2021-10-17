# bborg

Bash script for automating borg.

## Features

- A single config for all your backups
- Just a single bash script
- Still easy to configure for just a single backup
- familiar SSH config syntax

## Configuration

The config is read from `~/.config/borg/backups` by default.

### Examples

```bash
# Sets a global default compression
Compression auto,zstd,12

Backup local
    Repo ~/backup
    Passphrase hunter2

Backup remote
    Repo backup:~/backup
    # Gets the passphrase via pass
    PassCommand pass backups/remote | head -n1
```

```bash
# Setting the repo globally allows configuring a single backup named default
Repo backup:~/backup
```

### Options

#### `Repo`

Borg repository identifier.

#### `Path`

**Default**: `~`

Path to backup.

#### `Compression`

Comprssion to use.
See `borg help compression` for more information.

#### `Archive`

**Default**: `$(date -I)` (The current date in ISO format)

Name of the archive to create.

#### `IgnoreFile`

**Default**: `.borgignore`

File passed to borg via `--exclude-from`.
If it's a relative path (not starting with `/`), it gets appended to `Path`.

#### `Passphrase`

Passphrase passed to borg.

#### `PassCommand`

When set, the output of this command will be used as the passphrase.
