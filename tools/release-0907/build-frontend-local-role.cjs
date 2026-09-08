// Release-process-only I/O throttling for Windows EMFILE. No dependency files are edited.
const fs = require('fs')
const path = require('path')
const { pathToFileURL } = require('url')
const frontend = path.resolve(__dirname, '../../../sqlbot_with_bcback/costree-frontend')
function limiter() {
let active = 0
const waiting = []
return async function limited(run) {
  if (active >= 8) await new Promise(resolve => waiting.push(resolve))
  else active++
  try {
    for (let attempt = 0; ; attempt++) {
      try { return await run() } catch (error) {
        if (!['EMFILE', 'ENFILE'].includes(error.code) || attempt >= 100) throw error
        await new Promise(resolve => setTimeout(resolve, 100))
      }
    }
  } finally { const next = waiting.shift(); if (next) next(); else active-- }
}
}
// Separate queues avoid deadlocks when a library implements promises via callback I/O.
const limited = limiter(), callbackLimited = limiter()
for (const name of ['readFile', 'writeFile', 'appendFile']) {
  const original = fs.promises[name].bind(fs.promises)
  fs.promises[name] = (...args) => limited(() => original(...args))
}
for (const name of ['readFile', 'writeFile', 'appendFile']) {
  const original = fs[name].bind(fs)
  fs[name] = (...args) => {
    const callback = args.pop()
    if (typeof callback !== 'function') throw new TypeError('Callback required')
    callbackLimited(() => new Promise((resolve, reject) => original(...args, (error, result) => error ? reject(error) : resolve(result))))
      .then(result => callback(null, result), error => callback(error))
  }
}
require('module').syncBuiltinESMExports()
process.chdir(frontend)
import(pathToFileURL(path.join(frontend, 'node_modules/vite/dist/node/index.js')).href)
  .then(({build}) => build({mode:'prod',build:{outDir:'dist-cost-local-role-0907',rollupOptions:{maxParallelFileOps:16}}}))
  .catch(error => { console.error(error); process.exitCode = 1 })
