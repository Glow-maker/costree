const fs = require('fs')
const vm = require('vm')
const assert = require('assert')
const root = 'cost-server-offline-package-20261009/01-database/'
const html = fs.readFileSync(root + 'sql-parameters.html', 'utf8')
const script = html.match(/<script>([\s\S]*)<\/script>/)[1]
const context = vm.createContext({ document: { getElementById: () => ({}) }, URL: {}, Blob: function () {} })
vm.runInContext(script, context)
const unchanged = vm.runInContext("render('public','124')", context)
for (const [name, text] of Object.entries(unchanged)) {
  // Python text loading normalizes CRLF to LF in embedded templates; SQL stays identical.
  assert(text === fs.readFileSync(root + name, 'utf8').replace(/\r\n/g, '\n'), name)
}
const changed = vm.runInContext("render('costree_mvp','456')", context)
for (const text of Object.values(changed)) {
  assert(text.includes('search_path TO "costree_mvp";'))
  assert(!text.includes('search_path TO "public";'))
}
assert(changed['01-full-upgrade.sql'].includes('tenant_id=456'))
assert(!changed['01-full-upgrade.sql'].includes('tenant_id=124'))
for (const [schema, tenant] of [['public;drop', '124'], ['public', '-1'], ['public', '9223372036854775808'], ['', '124'], ['public', '1;drop']]) {
  assert.throws(() => vm.runInContext('render(' + JSON.stringify(schema) + ',' + JSON.stringify(tenant) + ')', context))
}
console.log('PASS: five SQL templates identical after newline normalization; schema/tenant substitution; five invalid inputs rejected.')
