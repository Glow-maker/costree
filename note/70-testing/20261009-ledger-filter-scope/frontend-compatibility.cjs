// Evidence preserved from the already executed 2026-10-09 frontend compatibility check.
// This extracts and executes current Vue page functions with MOCK API responses.
// It does not start a service, access a database, or constitute browser/onsite acceptance.
// Required cwd: H:/light/project/sqlbot_with_bcback/costree-frontend
// Execute through stdin so require('typescript') resolves from that frontend cwd:
// Get-Content -Raw 'H:/light/project/costree/note/70-testing/20261009-ledger-filter-scope/frontend-compatibility.cjs' | node -
// HISTORY-P, U and W are isolated mock fixture identifiers, not production records.

const fs=require('fs'),ts=require('typescript'),vm=require('vm'),assert=require('node:assert/strict');
const src=fs.readFileSync('src/views/cost/ledgerCompositionDetail/index.vue','utf8').split('<script setup lang="ts">')[1].split('</script>')[0];
const names=['buildScopeParams','buildOptionScopeParams','getSelectedOptionValue','searchFilterOptions','searchWorkOrderOptions','loadAllFilterOptions','loadFilterLayers','clearWorkOrderFilter','clearUnitFilters','handleProjectChange','handleAccountingUnitChange','handleWorkOrderChange','syncSelectedWorkOrder','syncRouteQuery'];
const ast=ts.createSourceFile('x.ts',src,ts.ScriptTarget.Latest,true);
const code=ast.statements.filter(s=>ts.isFunctionDeclaration(s)?names.includes(s.name?.text):ts.isVariableStatement(s)&&s.declarationList.declarations.some(d=>names.includes(d.name.getText(ast)))).map(s=>s.getText(ast)).join('\n');
const types=['DOMAIN','MODEL','PROJECT','MANAGE_UNIT','ACCOUNTING_UNIT','WORK_ORDER'];
const data={DOMAIN:[],MODEL:[],PROJECT:[{value:'HISTORY-P',label:'HISTORY-P',projectCode:'HISTORY-P',domainCode:null,modelCode:null}],MANAGE_UNIT:[],ACCOUNTING_UNIT:[{value:'U',label:'单位U',accountingUnitCode:'U'}],WORK_ORDER:[{value:'HISTORY-P|U|W',label:'W',projectCode:'HISTORY-P',accountingUnitCode:'U',workOrderNo:'W',domainCode:null,modelCode:null,manageUnitCode:null}]};
const requests=[];
const st={scopeFilters:{projectCode:'HISTORY-P'},selectedStageCodes:{value:[]},selectedWorkOrderKey:{value:''},optionLists:Object.fromEntries(types.map(t=>[t,[]])),optionRequestSequences:Object.fromEntries(types.map(t=>[t,0])),optionLoading:{},optionErrors:{},FILTER_OPTION_TYPES:types,legacyUnitName:{value:undefined},detailDrawerVisible:{value:false},queryParams:{},route:{path:'/cost/ledger-composition-detail',query:{from:'header'}},router:{replace:r=>st.route.query=r.query},getWorkOrderLedgerFilterOptions:async p=>{requests.push(p);return data[p.optionType]}};
const api=vm.runInNewContext(ts.transpile(code+'\n;({'+names.join(',')+'})',{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}),st);
st.refreshDashboard=async()=>api.syncRouteQuery();
(async()=>{await api.handleProjectChange();assert.equal(st.scopeFilters.projectCode,'HISTORY-P');assert.equal(st.route.query.projectCode,'HISTORY-P');assert.equal(st.optionLists.ACCOUNTING_UNIT.length,1);st.scopeFilters.accountingUnitCode='U';await api.handleAccountingUnitChange();assert.equal(st.optionLists.WORK_ORDER.length,1);st.selectedWorkOrderKey.value='HISTORY-P|U|W';await api.handleWorkOrderChange(st.selectedWorkOrderKey.value);assert.equal(st.scopeFilters.projectCode,'HISTORY-P');assert.equal(st.scopeFilters.domainCode,undefined);assert.equal(st.scopeFilters.modelCode,undefined);assert.equal(st.scopeFilters.accountingUnitCode,'U');assert.equal(st.scopeFilters.workOrderNo,'W');assert.equal(st.selectedWorkOrderKey.value,'HISTORY-P|U|W');assert.equal(st.route.query.projectCode,'HISTORY-P');assert.equal(st.optionLists.PROJECT[0].value,'HISTORY-P');console.log('ORPHAN_PROJECT_SELECT_ACCOUNTING_WORK_ORDER_ROUTE_OK',requests.length);})().catch(e=>{console.error(e);process.exitCode=1});
