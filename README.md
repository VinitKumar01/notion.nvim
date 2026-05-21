# notion.nvim

A Neovim plugin for interacting with Notion.

## Installation

Create the following file:

```bash
~/.config/nvim/lua/plugins/notion.lua
```

Add this content to the file:

```lua
return {
  {
    "VinitKumar01/notion.nvim",
  },
}
```

---

## Install Plugin

After creating the file, open Neovim and run:

```vim
:Lazy sync
```

This will fetch and install the plugin.

---

## Setup

You must set the `NOTION_API_KEY` environment variable.

### Bash

Add this to your `~/.bashrc`:

```bash
export NOTION_API_KEY="your_notion_api_key"
```

Then reload your shell:

```bash
source ~/.bashrc
```

### Zsh

Add this to your `~/.zshrc`:

```bash
export NOTION_API_KEY="your_notion_api_key"
```

Then reload your shell:

```bash
source ~/.zshrc
```

---

## Verify

Check that the variable is set:

```bash
echo $NOTION_API_KEY
```
