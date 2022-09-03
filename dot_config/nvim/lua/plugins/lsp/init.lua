local mason_ok, mason = pcall(require, "mason")
if not mason_ok then
  vim.notify("require('mason') failed")
  return
end
local mason_lspconfig_ok, masonlspconfig = pcall(require, "mason-lspconfig")
if not mason_lspconfig_ok then
  vim.notify("require('mason-lspconfig') failed")
  return
end
local lspconfig_ok, lspconfig = pcall(require, "lspconfig")
if not lspconfig_ok then
  vim.notify("require('lspconfig') failed")
  return
end
local cmp_nvim_lsp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if not cmp_nvim_lsp_ok then
  vim.notify("require('cmp_nvim_lsp') failed")
  return
end
local lsp_handlers_ok, lsp_handlers = pcall(require, 'plugins.lsp.handlers')
if not lsp_handlers_ok then
  vim.notify("require('plugins.lsp.handers') failed")
  return
end
local schemastore_ok, schemastore = pcall(require, 'schemastore')
if not schemastore_ok then
  vim.notify("require('schemastore') failed")
  return
end

mason.setup({
    ui = {
        icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗"
        }
    }
})

masonlspconfig.setup({
  ensure_installed = { "sumneko_lua", "jsonls", "bashls", "dockerls", "gopls", "tsserver", "marksman", "lemminx", "yamlls", "html", "sqls", "rust_analyzer", "terraformls", "pyright", "ltex", "jdtls", "cssls", "clangd", "vimls" },
  automatic_installation = true,
})

-- configure lspconfig
-- https://vonheikemen.github.io/devlog/tools/setup-nvim-lspconfig-plus-nvim-cmp/
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#jsonls

-- Enable (broadcasting) snippet capability for completion
local capabilities = vim.lsp.protocol.make_client_capabilities()

local lsp_defaults = {
  flags = {
    debounce_text_changes = 150,
  },
  capabilities = cmp_nvim_lsp.update_capabilities(
    capabilities
  ),
}

lspconfig.util.default_config = vim.tbl_deep_extend(
  'force',
  lspconfig.util.default_config,
  lsp_defaults
)

-- marksman
lspconfig.marksman.setup {
  on_attach = lsp_handlers.on_attach
}

-- JS
lspconfig.tsserver.setup {
  on_attach = lsp_handlers.on_attach
}

-- Lua
lspconfig.sumneko_lua.setup {
  on_attach = lsp_handlers.on_attach,
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = {'vim'},
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
}

-- Gopls
lspconfig.gopls.setup {
  on_attach = lsp_handlers.on_attach
}

-- Docker
lspconfig.dockerls.setup {
  on_attach = lsp_handlers.on_attach
}

-- Bash
lspconfig.bashls.setup {
  on_attach = lsp_handlers.on_attach
}

-- XML
lspconfig.lemminx.setup {
  on_attach = lsp_handlers.on_attach
}

-- YAML
-- You can add/overwrite schema as described here:
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#yamlls
lspconfig.yamlls.setup {
  on_attach = lsp_handlers.on_attach
}

-- SQL
lspconfig.sqls.setup {
  on_attach = lsp_handlers.on_attach
}

-- Rust
lspconfig.rust_analyzer.setup {
  on_attach = lsp_handlers.on_attach
}

-- Terraform
lspconfig.terraformls.setup {
  on_attach = lsp_handlers.on_attach
}

-- Python
lspconfig.pyright.setup {
  on_attach = lsp_handlers.on_attach
}

-- LaTeX
lspconfig.ltex.setup {
  on_attach = lsp_handlers.on_attach
}

-- Java
lspconfig.jdtls.setup {
  on_attach = lsp_handlers.on_attach
}

-- C++
lspconfig.clangd.setup {
  on_attach = lsp_handlers.on_attach
}

-- VimL
lspconfig.vimls.setup {
  on_attach = lsp_handlers.on_attach
}

-- JSON
capabilities.textDocument.completion.completionItem.snippetSupport = true

lspconfig.jsonls.setup {
  on_attach = lsp_handlers.on_attach,
  capabilities = capabilities,
  settings = {
    json = {
      schemas = schemastore.json.schemas(),
      validate = { enable = true },
    },
  },
}

-- HTML also supports snippets
lspconfig.html.setup {
  on_attach = lsp_handlers.on_attach,
  capabilities = capabilities,
}

-- CSS
lspconfig.cssls.setup {
  on_attach = lsp_handlers.on_attach,
  capabilities = capabilities,
}


lsp_handlers.setup()
