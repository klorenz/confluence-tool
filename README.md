# atlassian-confluence-api

This provides an API for doing bulk changes in confluence.

This is at a pretty early stage.

# what works

- ConfluenceAPI already works, but is not yet stable
- Following CLI commands work
- `page-prop-get` 
- `update` 
- `aupdate` 

# Debugging

run `node-inspector & coffee --nodejs --debug-brk lib/cli.coffee`
