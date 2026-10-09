const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const front = 'H:/light/project/sqlbot_with_bcback/costree-frontend';
const ts = require(front + '/node_modules/typescript');
const source = fs.readFileSync(front + '/src/views/cost/ledgerCompositionDetail/index.vue','utf8');
const part = (a,b) => source.slice(source.indexOf(a),source.indexOf(b,source.indexOf(a)));
const code = part('const syncRouteQuery =','const getRouteScopeParams =') + '\n' + part('const reloadFromRoute =','watch(') + '\n' + part('const handleDetailDrawerClosed =','const handleRankTabChange =');
let releases=[], opens=0;
const state={
 route:{path:'/cost/ledger-composition-detail',query:{projectCode:'P',manageUnitName:'NAME_NOT_MAPPED',itemCode:'501101'}},
 scopeFilters:{projectCode:'P'}, detailDrawerVisible:{value:true}, queryParams:{itemCode:'501101'},
 detailLoading:{value:false},detailRows:{value:[]},detailTotal:{value:0},
 selectedStageCodes:{value:[]},selectedWorkOrderKey:{value:''},legacyUnitName:{value:undefined},legacyManageUnitName:{value:undefined},rankDimension:{value:'PROJECT'},
 getRouteScopeParams:()=>({projectCode:'P'}),routeScopeMatchesCurrent:()=>true,
 normalizeQueryValue:x=>x || undefined,splitStageCodes:()=>[],buildScopeParams:()=>({projectCode:'P'}),
 loadAllFilterOptions:()=>new Promise(resolve=>releases.push(resolve)),
 searchManageUnitOptions:async()=>{},searchAccountingUnitOptions:async()=>{},applyLegacyUnitFilters:()=>false,
 syncSelectedWorkOrder:()=>{},refreshDashboard:async()=>{},clearDetailScopeOverrides:()=>{},
 compositionDetail:{value:{}},compositionItems:{value:[]},openDetailDrawer:()=>{opens++;state.detailDrawerVisible.value=true}
};
state.router={replace:({query})=>{state.route.query=query}};
const context=vm.createContext(state);
vm.runInContext('let routeReloadSequence=0;let detailRequestSequence=0;'+ts.transpile(code)+'\nglobalThis.run=reloadFromRoute;globalThis.closed=handleDetailDrawerClosed;',context);
(async()=>{
 const first=context.run();
 assert.equal(state.detailDrawerVisible.value,false);
 context.closed(); // animation completes before options load
 assert.equal(state.route.query.itemCode,undefined);
 const second=context.run(); // watch triggered by clearing itemCode
 releases[1]();await second;
 releases[0]();await first;
 assert.equal(opens,0);assert.equal(state.detailDrawerVisible.value,false);
 const tree=fs.readFileSync(front+'/src/views/cost/treeDetail/index.vue','utf8');
 const begin=tree.indexOf('const getManageUnitIdentity =');const end=tree.indexOf('const getCostWarningClass',begin);
 const identify=vm.runInNewContext(ts.transpile(tree.slice(begin,end))+'\ngetManageUnitIdentity',{
 unitDictByName:{value:new Map()},normalizeText:(v,f)=>String(v||'').trim()||f
 });
 const result=identify('OUTSIDE_NAME_NOT_MATCHED');
 assert.equal(result.insideInstitute,true);assert.equal(result.manageUnitGroup,'UNCLASSIFIED');
 console.log(JSON.stringify({routeRace:{reproduced:true,condition:'unresolved legacy management-unit name + delayed filter load + drawer closed event',openedAfterReload:opens,itemCodeCleared:true},missingDictionaryClassification:{reproduced:true,...result}},null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
