/* Shared by the offline HTML and Node regression tests. No network or database access. */
(function (root) {
  'use strict'
  function render(templates, input) {
    const tenant = String(input.tenant || '').trim()
    const cost = String(input.cost || '').trim()
    const dm = String(input.dm || '').trim()
    const prefix = String(input.prefix || '')
    if (!/^[1-9]\d{0,17}$/.test(tenant)) throw new Error('请填写真实的正整数租户 ID（不超过18位）')
    if (!/^[a-z_][a-z0-9_]{0,62}$/.test(cost)) throw new Error('成本 schema 仅支持小写字母、数字、下划线，请核对实际名称')
    if (!/^[A-Z_][A-Z0-9_]{0,62}$/.test(dm)) throw new Error('中台 schema 仅支持大写字母、数字、下划线，请核对实际名称')
    if (!/^[A-Za-z0-9_:-]*$/.test(prefix)) throw new Error('Redis 前缀不能包含空格、引号或通配符')
    if (!['tenant', 'global'].includes(input.cacheMode)) throw new Error('请选择实际 Redis 缓存模式')
    const vars = {TENANT:tenant, COST_SCHEMA:cost, DM_SCHEMA:dm, PREFIX:prefix,
      CACHE_TENANT: input.cacheMode === 'tenant' ? tenant + ':' : ''}
    return Object.fromEntries(Object.entries(templates).map(([name, sql]) => {
      const value = sql.replace(/@@([A-Z_]+)@@/g, (_, key) => {
        if (!(key in vars)) throw new Error('未知模板变量: ' + key)
        return vars[key]
      })
      if (/@@[A-Z_]+@@/.test(value)) throw new Error('存在未替换参数')
      return [name, value]
    }))
  }
  if (typeof module !== 'undefined') module.exports = {render}
  else root.CostRelease = {render}
})(typeof window === 'undefined' ? {} : window)
