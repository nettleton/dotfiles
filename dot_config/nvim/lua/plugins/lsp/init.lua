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
local mason_tool_installer_ok, mason_tool_installer = pcall(require, 'mason-tool-installer')
if not mason_tool_installer_ok then
  vim.notify("require('mason-tool-installer') failed")
  return
end
local null_ls_ok, null_ls = pcall(require, "null-ls")
if not null_ls_ok then
  vim.notify("require('null-ls') failed")
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
  ensure_installed = { "sumneko_lua", "jsonls", "bashls", "dockerls", "gopls", "golangci_lint_ls", "tsserver", "marksman", "lemminx", "yamlls", "html", "sqls", "rust_analyzer", "terraformls", "pyright", "jdtls", "cssls", "clangd", "vimls" },
  automatic_installation = true,
})

mason_tool_installer.setup {
  ensure_installed = {
    "actionlint",
    "buf",
    "buildifier",
    "cbfmt",
    "cfn-lint",
    "clang-format",
    "codespell",
    "cpplint",
    "fixjson",
    "gitlint",
    "gofumpt",
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
    "vint",
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

-- golangci-lint-langserver
lspconfig.golangci_lint_ls.setup{
  on_attach = lsp_handlers.on_attach
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
lsp_defaults.capabilities.textDocument.completion.completionItem.snippetSupport = true

lspconfig.jsonls.setup {
  on_attach = lsp_handlers.on_attach,
  capabilities = lsp_defaults.capabilities,
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
  capabilities = lsp_defaults.capabilities,
}

-- CSS
lspconfig.cssls.setup {
  on_attach = lsp_handlers.on_attach,
  capabilities = lsp_defaults.capabilities,
}

lsp_handlers.setup()

-- null-ls
local code_actions = null_ls.builtins.code_actions
local diagnostics = null_ls.builtins.diagnostics
local formatting = null_ls.builtins.formatting

-- Mason installs tools into ~/.local/share/nvim/mason/bin
-- Some of these tools may benefit from configurations
-- Some config can just be defined in files like .luacheckrc
-- You can test your config with commands like the following:
-- ~/.local/share/nvim/mason/bin/luacheck ~/.local/share/chezmoi/dot_config/nvim/lua/plugins/init.lua
-- TODO: unclear if "vale sync needs to be run after Mason installs vale

null_ls.setup {
  debug = false,
  sources = {
    code_actions.gitsigns,
    code_actions.shellcheck,
    diagnostics.actionlint,
    diagnostics.buf,
    diagnostics.buildifier,
    diagnostics.cfn_lint,
    diagnostics.codespell,
    diagnostics.fish,
    diagnostics.gitlint,
    diagnostics.golangci_lint,
    diagnostics.luacheck,
    diagnostics.markdownlint,
    diagnostics.pylint,
    diagnostics.shellcheck,
    diagnostics.staticcheck,
    diagnostics.vale,
    diagnostics.yamllint,
    formatting.buf,
    formatting.buildifier,
    formatting.clang_format,
    formatting.codespell,
    formatting.fish_indent,
    formatting.fixjson,
    formatting.gofumpt,
    formatting.goimports,
    formatting.golines,
    formatting.jq,
    formatting.markdownlint,
    formatting.shellharden,
    formatting.sql_formatter,
    formatting.xmllint,
    formatting.yamlfmt,
  }
}



