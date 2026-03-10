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
local mason_tool_installer_ok, mason_tool_installer = pcall(require, 'mason-tool-installer')
if not mason_tool_installer_ok then
  vim.notify("require('mason-tool-installer') failed")
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
  ensure_installed = { "lua_ls", "jsonls", "bashls", "dockerls", "gopls", "golangci_lint_ls", "ts_ls", "marksman", "lemminx", "yamlls", "html", "rust_analyzer", "terraformls", "pyright", "jdtls", "cssls", "clangd" },
  automatic_installation = true,
})

mason_tool_installer.setup {
  ensure_installed = {
    "actionlint",
    "buf",
    "buildifier",
    "cfn-lint",
    "clang-format",
    "codespell",
    "cpplint",
    "gitlint",
    "goimports",
    "golangci-lint",
    "golines",
    "gomodifytags",
    "gotests",
    "impl",
    "jq",
    "json-to-struct",
    "luacheck",
    "luaformatter",
    "markdownlint",
    "pylint",
    "shellcheck",
    "shellharden",
    "sql-formatter",
    "staticcheck",
    "vale",
    "xmlformatter",
    "yamlfmt",
    "yamllint"
  }
}

-- configure lspconfig
-- https://vonheikemen.github.io/devlog/tools/setup-nvim-lspconfig-plus-nvim-cmp/
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#jsonls

-- Enable (broadcasting) snippet capability for completion
local lsp_defaults = {
  flags = {
    debounce_text_changes = 150,
  },
  capabilities = cmp_nvim_lsp.default_capabilities(),
}
vim.lsp.config('*',lsp_defaults)

-- marksman
vim.lsp.config('marksman', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('marksman')

-- JS
vim.lsp.config('ts_ls', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('ts_ls')
-- Lua
vim.lsp.config('lua_ls', {
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
})
vim.lsp.enable('lua_ls')

-- golangci-lint-langserver
vim.lsp.config('golangci_lint_ls', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('golangci_lint_ls')

-- Gopls
vim.lsp.config('gopls', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('gopls')

-- Docker
vim.lsp.config('dockerls', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('dockerls')

-- Bash
vim.lsp.config('bashls', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('bashls')

-- XML
vim.lsp.config('lemminx', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('lemminx')

-- YAML
-- You can add/overwrite schema as described here:
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#yamlls
vim.lsp.config('yamlls', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('yamlls')

-- Rust
vim.lsp.config('rust_analyzer', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('rust_analyzer')

-- Terraform
vim.lsp.config('terraformls', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('terraformls')

-- Python
vim.lsp.config('pyright', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('pyright')

-- Java
vim.lsp.config('jdtls', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('jdtls')

-- C++
vim.lsp.config('clangd', {
  on_attach = lsp_handlers.on_attach
})
vim.lsp.enable('clangd')

-- JSON
lsp_defaults.capabilities.textDocument.completion.completionItem.snippetSupport = true

vim.lsp.config('jsonls', {
  on_attach = lsp_handlers.on_attach,
  capabilities = lsp_defaults.capabilities,
  settings = {
    json = {
      schemas = schemastore.json.schemas(),
      validate = { enable = true },
    },
  },
})
vim.lsp.enable('jsonls')

-- HTML also supports snippets
vim.lsp.config('html', {
  on_attach = lsp_handlers.on_attach,
  capabilities = lsp_defaults.capabilities,
})
vim.lsp.enable('html')

-- CSS
vim.lsp.config('cssls', {
  on_attach = lsp_handlers.on_attach,
  capabilities = lsp_defaults.capabilities,
})
vim.lsp.enable('cssls')

lsp_handlers.setup()
