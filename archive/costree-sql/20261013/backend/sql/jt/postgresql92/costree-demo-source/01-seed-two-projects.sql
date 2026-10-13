-- 两个演示项目的外部源数据（PostgreSQL）
-- 只重建 cost_demo_source 下的数据，不触碰 public 业务表。

BEGIN;

TRUNCATE TABLE
    cost_demo_source.dws_bu_pz_pzmx_gzl,
    cost_demo_source.work_order_fill,
    cost_demo_source.project_office_fill,
    cost_demo_source.precontrol_project_unit_amount,
    cost_demo_source.dwd_bd_bfcustomitem_gzl,
    cost_demo_source.ads_lc_lshsxm2022,
    cost_demo_source.unit_dict;

INSERT INTO cost_demo_source.unit_dict (
    source_record_id, accounting_unit_id, accounting_unit_code, accounting_unit_name,
    manage_unit_code, manage_unit_name, manage_unit_group,
    contact_unit_code, contact_unit_name, inside_group, inside_institute,
    disabled, source_update_time, source_deleted
) VALUES
('UNIT-DEMO-001', 'DEMO-ACCT-001', 'DEMO-001', '上海航天技术研究院', '8001', '院部', 'HEAD_OFFICE', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-002', 'DEMO-ACCT-002', 'DEMO-002', '上海航天精密机械研究所', '0800', '800所', 'ASSEMBLY', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-003', 'DEMO-ACCT-003', 'DEMO-003', '上海航天设备制造总厂有限公司', '0149', '149厂', 'ASSEMBLY', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-004', 'DEMO-ACCT-004', 'DEMO-004', '上海卫星装备研究所', '0812', '812所', 'ASSEMBLY', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-005', 'DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '0804', '电子所', 'PROFESSIONAL', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-006', 'DEMO-ACCT-006', 'DEMO-006', '上海神舟新能源发展有限公司', '0804', '电子所', 'PROFESSIONAL', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-007', 'DEMO-ACCT-007', 'DEMO-007', '上海航天计算机技术研究所', '0804', '电子所', 'PROFESSIONAL', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-008', 'DEMO-ACCT-008', 'DEMO-008', '上海航天动力技术研究所', '0806', '动力所', 'PROFESSIONAL', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-009', 'DEMO-ACCT-009', 'DEMO-009', '上海航天精密仪器研究所', '0811', '811所', 'PROFESSIONAL', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-010', 'DEMO-ACCT-010', 'DEMO-010', '上海无线电设备研究所', '0802', '802所', 'PROFESSIONAL', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-011', 'DEMO-ACCT-011', 'DEMO-011', '上海航天控制技术研究所', '0803', '803所', 'PROFESSIONAL', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-012', 'DEMO-ACCT-012', 'DEMO-012', '上海航天基础技术研究所', 'BASE', '基础所', 'FOUNDATION', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-014', 'DEMO-ACCT-014', 'DEMO-014', '上海航天第八研究部', '0008', '八部', 'OVERALL', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-015', 'DEMO-ACCT-015', 'DEMO-015', '上海卫星工程研究所', '0509', '509所', 'OVERALL', NULL, NULL, '是', '是', '0', '2026-07-21 12:00:00', '0'),
('UNIT-DEMO-013', 'DEMO-ACCT-013', 'DEMO-013', '单位层级演示院外协作单位', 'EXT', '院外单位', 'OUTER', 'DEMO-013', '单位层级演示院外协作单位', '否', '否', '0', '2026-07-21 12:00:00', '0');

INSERT INTO cost_demo_source.ads_lc_lshsxm2022 (
    lshsxm_id, lshsxm_xmnm, lshsxm_xmbh, lshsxm_xmmc, lshsxm_js,
    lshsxm_mx, lshsxm_xmlx, parent_xmnm, lshsxm_zt, disabled,
    xmsx, lastmodifiedtime, source_deleted
) VALUES
('SRC-TREE-DEMO-001', 'DOMAIN_DEMO', 'DEMO', '演示领域', '1', '否', 'DOMAIN', NULL, '启用', '0', 'DEMO', '2026-07-21 12:00:00', '0'),
('SRC-TREE-DEMO-002', 'SERIES_DEMO_UNIT', 'DEMO-SERIES', '数据闭环演示系列', '2', '否', 'SERIES', 'DOMAIN_DEMO', '启用', '0', 'DEMO', '2026-07-21 12:00:00', '0'),
('SRC-TREE-DEMO-003', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '3', '是', 'MODEL', 'SERIES_DEMO_UNIT', '启用', '0', 'DEMO', '2026-07-21 12:00:00', '0'),
('SRC-TREE-DEMO-004', 'MODEL_DEMO_YEARLY', 'ZY-2026-DEMO-YEAR-002', '跨年度账面演示项目', '3', '是', 'MODEL', 'SERIES_DEMO_UNIT', '启用', '0', 'DEMO', '2026-07-21 12:00:00', '0');

INSERT INTO cost_demo_source.dwd_bd_bfcustomitem_gzl (
    id, accountorg, cusitemcategory, cusitemcode, cusitemname, cusitemproperty,
    accountorgcode, accountorgname, ifstopname, iscompleted, isdisabled,
    treeinfo_isdetail, treeinfo_layer, dwts, zyxmid, zyxmcode, zyxmname,
    timestamp_lastchangedon, source_deleted
) VALUES
('SRC-DEMO-WO-01', 'DEMO-ACCT-001', 'DEMO', 'DEMO-WO-01', '院部总体工作令', '主业工作令', 'DEMO-001', '上海航天技术研究院', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-02', 'DEMO-ACCT-002', 'DEMO', 'DEMO-WO-02', '总装一工作令', '主业工作令', 'DEMO-002', '上海航天精密机械研究所', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-03', 'DEMO-ACCT-003', 'DEMO', 'DEMO-WO-03', '总装二工作令', '主业工作令', 'DEMO-003', '上海航天设备制造总厂有限公司', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-04', 'DEMO-ACCT-004', 'DEMO', 'DEMO-WO-04', '总装三工作令', '主业工作令', 'DEMO-004', '上海卫星装备研究所', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-05', 'DEMO-ACCT-005', 'DEMO', 'DEMO-WO-05', '电子分系统工作令一', '主业工作令', 'DEMO-005', '上海航天电子通讯设备研究所', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-06', 'DEMO-ACCT-006', 'DEMO', 'DEMO-WO-06', '电子分系统工作令二', '主业工作令', 'DEMO-006', '上海神舟新能源发展有限公司', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-07', 'DEMO-ACCT-007', 'DEMO', 'DEMO-WO-07', '电子分系统工作令三', '主业工作令', 'DEMO-007', '上海航天计算机技术研究所', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-08', 'DEMO-ACCT-008', 'DEMO', 'DEMO-WO-08', '动力分系统工作令', '主业工作令', 'DEMO-008', '上海航天动力技术研究所', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-09', 'DEMO-ACCT-009', 'DEMO', 'DEMO-WO-09', '仪器分系统工作令', '主业工作令', 'DEMO-009', '上海航天精密仪器研究所', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-10', 'DEMO-ACCT-010', 'DEMO', 'DEMO-WO-10', '无线电分系统工作令', '主业工作令', 'DEMO-010', '上海无线电设备研究所', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-11', 'DEMO-ACCT-011', 'DEMO', 'DEMO-WO-11', '控制分系统工作令', '主业工作令', 'DEMO-011', '上海航天控制技术研究所', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-12', 'DEMO-ACCT-012', 'DEMO', 'DEMO-WO-12', '基础保障工作令', '主业工作令', 'DEMO-012', '上海航天基础技术研究所', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-13', 'DEMO-ACCT-014', 'DEMO', 'DEMO-WO-13', '总体八部工作令', '主业工作令', 'DEMO-014', '上海航天第八研究部', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-WO-14', 'DEMO-ACCT-015', 'DEMO', 'DEMO-WO-14', '总体509所工作令', '主业工作令', 'DEMO-015', '上海卫星工程研究所', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_UNIT_HIERARCHY', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', '2026-07-21 12:00:00', '0'),
('SRC-DEMO-YEAR-WO-01', 'DEMO-ACCT-005', 'DEMO', 'DEMO-YEAR-WO-01', '跨年度电子系统工作令', '主业工作令', 'DEMO-005', '上海航天电子通讯设备研究所', '否', '否', '0', '是', '3', '20260721120000', 'MODEL_DEMO_YEARLY', 'ZY-2026-DEMO-YEAR-002', '跨年度账面演示项目', '2026-07-21 12:00:00', '0');

INSERT INTO cost_demo_source.precontrol_project_unit_amount (
    source_record_id, source_update_time, project_code, project_name,
    accounting_unit_id, unit_name, contract_amount, income_amount,
    target_cost_amount, approved_amount, source_deleted
) VALUES
('DEMO-UNIT-DEMO-WO-01', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-001', '上海航天技术研究院', 1500, 1200, 1000, 950, 0),
('DEMO-UNIT-DEMO-WO-02', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-002', '上海航天精密机械研究所', 1800, 1400, 1100, 1200, 0),
('DEMO-UNIT-DEMO-WO-03', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-003', '上海航天设备制造总厂有限公司', 1900, 1500, 1200, 1400, 0),
('DEMO-UNIT-DEMO-WO-04', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-004', '上海卫星装备研究所', 1700, 1300, 1050, 1000, 0),
('DEMO-UNIT-DEMO-WO-05', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-005', '上海航天电子通讯设备研究所', 1200, 900, 700, 650, 0),
('DEMO-UNIT-DEMO-WO-06', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-006', '上海神舟新能源发展有限公司', 1000, 760, 600, 590, 0),
('DEMO-UNIT-DEMO-WO-07', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-007', '上海航天计算机技术研究所', 1100, 850, 650, 630, 0),
('DEMO-UNIT-DEMO-WO-08', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-008', '上海航天动力技术研究所', 1500, 1100, 900, 880, 0),
('DEMO-UNIT-DEMO-WO-09', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-009', '上海航天精密仪器研究所', 1450, 1080, 850, 820, 0),
('DEMO-UNIT-DEMO-WO-10', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-010', '上海无线电设备研究所', 1600, 1200, 950, 900, 0),
('DEMO-UNIT-DEMO-WO-11', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-011', '上海航天控制技术研究所', 1550, 1180, 920, 910, 0),
('DEMO-UNIT-DEMO-WO-12', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-012', '上海航天基础技术研究所', 1300, 1000, 800, 780, 0),
('DEMO-UNIT-DEMO-WO-13', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-014', '上海航天第八研究部', 1400, 1050, 900, 880, 0),
('DEMO-UNIT-DEMO-WO-14', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-015', '上海卫星工程研究所', 1350, 1000, 850, 830, 0),
('DEMO-UNIT-OUTER', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目', 'DEMO-ACCT-013', '单位层级演示院外协作单位', 1000, 700, 800, 760, 0),
('DEMO-YEAR-UNIT-001', TIMESTAMP '2026-07-21 12:00:00', 'ZY-2026-DEMO-YEAR-002', '跨年度账面演示项目', 'DEMO-ACCT-005', '上海航天电子通讯设备研究所', 1600, 1400, 1200, 1100, 0);

INSERT INTO cost_demo_source.project_office_fill (
    source_record_id, project_code, product_attachment_type, subsystem_name,
    quantity, product_short_name, vertical_division,
    user_name, acquire_method, batch_category, platform_series, research_unit_name,
    tax_exempt, cycle_start, cycle_end, stage_code, basic_info, status,
    source_update_time, source_deleted
) VALUES
('DEMO-PROJECT-FILL-001', 'ZY-2026-DEMO-UNIT-001', '产品', '总体、总装、电子、动力、仪器、无线电、控制、基础', 1, '单位层级演示', true, '军事航天部队', '装备/批产', 'DEMO-01', '数据闭环演示系列', '上海航天技术研究院', '否', '2026-01', '2028-12', 'Z', '用于验证管理单位分组、预警和八项账面组成。', 'SUBMITTED', TIMESTAMP '2026-07-21 12:00:00', 0),
('DEMO-PROJECT-FILL-002', 'ZY-2026-DEMO-YEAR-002', '产品附件', '电子系统', 1, '跨年度电子', false, '军事航天部队', '单一来源', 'DEMO-02', '数据闭环演示系列', '上海航天电子通讯设备研究所', '否', '2023-01', '2026-12', 'Z', '用于验证同编号工作令跨年度合并和贷方排除。', 'SUBMITTED', TIMESTAMP '2026-07-21 12:00:00', 0);

INSERT INTO cost_demo_source.work_order_fill (
    source_work_order_id, fiscal_year, stage_codes, max_stage_code,
    subsystem_name, product_short_name, quantity, vertical_division,
    source_update_time, source_deleted
) VALUES
('SRC-DEMO-WO-01', '2026', 'M', 'M', '总体系统', '总体', 1, true, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-02', '2026', 'M', 'M', '总装系统', '总装一', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-03', '2026', 'M', 'M', '总装系统', '总装二', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-04', '2026', 'M', 'M', '总装系统', '总装三', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-05', '2026', 'C', 'C', '电子系统', '电子一', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-06', '2026', 'C', 'C', '电子系统', '电子二', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-07', '2026', 'C', 'C', '电子系统', '电子三', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-08', '2026', 'C', 'C', '动力系统', '动力', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-09', '2026', 'Z', 'Z', '仪器系统', '仪器', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-10', '2026', 'Z', 'Z', '无线电系统', '无线电', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-11', '2026', 'Z', 'Z', '控制系统', '控制', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-12', '2026', 'Z', 'Z', '基础保障', '基础', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-13', '2026', 'M', 'M', '总体系统', '八部', 1, true, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-WO-14', '2026', 'M', 'M', '总体系统', '509所', 1, true, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-YEAR-WO-01', '2023', 'M', 'M', '电子系统', '跨年电子', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-YEAR-WO-01', '2024', 'C', 'C', '电子系统', '跨年电子', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-YEAR-WO-01', '2025', 'C', 'C', '电子系统', '跨年电子', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0),
('SRC-DEMO-YEAR-WO-01', '2026', 'Z', 'Z', '电子系统', '跨年电子', 1, false, TIMESTAMP '2026-07-21 12:00:00', 0);

INSERT INTO cost_demo_source.dws_bu_pz_pzmx_gzl (
    id, ysnm, kjnd, kjqj, pzrq, pzbh, dwid, dwbh, dwmc, gldw,
    kmid, kmbh, kmmc, xmbh, xmnm, xmmc, gzlnm, gzllb, gzlmc,
    jzfx, je, yt, lastmodifiedtime, dwts, ejkmbh, ejkmmc, source_deleted
) VALUES
('RAW-DEMO-A-01', 'DEMO-LEDGER-DEMO-WO-01', '2026', '12', '20261231', 'PZ-DEMO-A-01', 'DEMO-ACCT-001', 'DEMO-001', '上海航天技术研究院', '院部', 'SUBJ-501101', '501101', '职工薪酬及劳务费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-01', 'DEMO-WO-01', '院部总体工作令', '借', '9000000', '院部总体工作令借方支出', '2026-07-21 12:00:00', '20260721120000', '501101', '职工薪酬及劳务费', '0'),
('RAW-DEMO-A-02', 'DEMO-LEDGER-DEMO-WO-02', '2026', '12', '20261231', 'PZ-DEMO-A-02', 'DEMO-ACCT-002', 'DEMO-002', '上海航天精密机械研究所', '800所', 'SUBJ-501102', '501102', '材料费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-02', 'DEMO-WO-02', '总装一工作令', '借', '12000000', '总装一工作令借方支出', '2026-07-21 12:00:00', '20260721120000', '501102', '材料费', '0'),
('RAW-DEMO-A-03', 'DEMO-LEDGER-DEMO-WO-03', '2026', '12', '20261231', 'PZ-DEMO-A-03', 'DEMO-ACCT-003', 'DEMO-003', '上海航天设备制造总厂有限公司', '149厂', 'SUBJ-501103', '501103', '专用费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-03', 'DEMO-WO-03', '总装二工作令', '借', '15000000', '总装二工作令借方支出', '2026-07-21 12:00:00', '20260721120000', '501103', '专用费', '0'),
('RAW-DEMO-A-04', 'DEMO-LEDGER-DEMO-WO-04', '2026', '12', '20261231', 'PZ-DEMO-A-04', 'DEMO-ACCT-004', 'DEMO-004', '上海卫星装备研究所', '812所', 'SUBJ-501104', '501104', '外协费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-04', 'DEMO-WO-04', '总装三工作令', '借', '9800000', '总装三工作令借方支出', '2026-07-21 12:00:00', '20260721120000', '501104', '外协费', '0'),
('RAW-DEMO-A-05', 'DEMO-LEDGER-DEMO-WO-05', '2026', '12', '20261231', 'PZ-DEMO-A-05', 'DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '电子所', 'SUBJ-501105', '501105', '燃料动力费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-05', 'DEMO-WO-05', '电子分系统工作令一', '借', '6800000', '电子分系统工作令一借方支出', '2026-07-21 12:00:00', '20260721120000', '501105', '燃料动力费', '0'),
('RAW-DEMO-A-06', 'DEMO-LEDGER-DEMO-WO-06', '2026', '12', '20261231', 'PZ-DEMO-A-06', 'DEMO-ACCT-006', 'DEMO-006', '上海神舟新能源发展有限公司', '电子所', 'SUBJ-501106', '501106', '事务费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-06', 'DEMO-WO-06', '电子分系统工作令二', '借', '6100000', '电子分系统工作令二借方支出', '2026-07-21 12:00:00', '20260721120000', '501106', '事务费', '0'),
('RAW-DEMO-A-07', 'DEMO-LEDGER-DEMO-WO-07', '2026', '12', '20261231', 'PZ-DEMO-A-07', 'DEMO-ACCT-007', 'DEMO-007', '上海航天计算机技术研究所', '电子所', 'SUBJ-501107', '501107', '固定资产折旧费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-07', 'DEMO-WO-07', '电子分系统工作令三', '借', '6200000', '电子分系统工作令三借方支出', '2026-07-21 12:00:00', '20260721120000', '501107', '固定资产折旧费', '0'),
('RAW-DEMO-A-08', 'DEMO-LEDGER-DEMO-WO-08', '2026', '12', '20261231', 'PZ-DEMO-A-08', 'DEMO-ACCT-008', 'DEMO-008', '上海航天动力技术研究所', '动力所', 'SUBJ-501108', '501108', '管理费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-08', 'DEMO-WO-08', '动力分系统工作令', '借', '8700000', '动力分系统工作令借方支出', '2026-07-21 12:00:00', '20260721120000', '501108', '管理费', '0'),
('RAW-DEMO-A-09', 'DEMO-LEDGER-DEMO-WO-09', '2026', '12', '20261231', 'PZ-DEMO-A-09', 'DEMO-ACCT-009', 'DEMO-009', '上海航天精密仪器研究所', '811所', 'SUBJ-501101', '501101', '职工薪酬及劳务费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-09', 'DEMO-WO-09', '仪器分系统工作令', '借', '8100000', '仪器分系统工作令借方支出', '2026-07-21 12:00:00', '20260721120000', '501101', '职工薪酬及劳务费', '0'),
('RAW-DEMO-A-10', 'DEMO-LEDGER-DEMO-WO-10', '2026', '12', '20261231', 'PZ-DEMO-A-10', 'DEMO-ACCT-010', 'DEMO-010', '上海无线电设备研究所', '802所', 'SUBJ-501102', '501102', '材料费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-10', 'DEMO-WO-10', '无线电分系统工作令', '借', '9400000', '无线电分系统工作令借方支出', '2026-07-21 12:00:00', '20260721120000', '501102', '材料费', '0'),
('RAW-DEMO-A-11', 'DEMO-LEDGER-DEMO-WO-11', '2026', '12', '20261231', 'PZ-DEMO-A-11', 'DEMO-ACCT-011', 'DEMO-011', '上海航天控制技术研究所', '803所', 'SUBJ-501104', '501104', '外协费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-11', 'DEMO-WO-11', '控制分系统工作令', '借', '9300000', '控制分系统工作令借方支出', '2026-07-21 12:00:00', '20260721120000', '501104', '外协费', '0'),
('RAW-DEMO-A-12', 'DEMO-LEDGER-DEMO-WO-12', '2026', '12', '20261231', 'PZ-DEMO-A-12', 'DEMO-ACCT-012', 'DEMO-012', '上海航天基础技术研究所', '基础所', 'SUBJ-501103', '501103', '专用费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-12', 'DEMO-WO-12', '基础保障工作令', '借', '7600000', '基础保障工作令借方支出', '2026-07-21 12:00:00', '20260721120000', '501103', '专用费', '0'),
('RAW-DEMO-A-13', 'DEMO-LEDGER-DEMO-WO-13', '2026', '12', '20261231', 'PZ-DEMO-A-13', 'DEMO-ACCT-014', 'DEMO-014', '上海航天第八研究部', '八部', 'SUBJ-501101', '501101', '职工薪酬及劳务费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-13', 'DEMO-WO-13', '总体八部工作令', '借', '8500000', '总体八部工作令借方支出', '2026-07-21 12:00:00', '20260721120000', '501101', '职工薪酬及劳务费', '0'),
('RAW-DEMO-A-14', 'DEMO-LEDGER-DEMO-WO-14', '2026', '12', '20261231', 'PZ-DEMO-A-14', 'DEMO-ACCT-015', 'DEMO-015', '上海卫星工程研究所', '509所', 'SUBJ-501102', '501102', '材料费', 'ZY-2026-DEMO-UNIT-001', 'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示项目', 'SRC-DEMO-WO-14', 'DEMO-WO-14', '总体509所工作令', '借', '8200000', '总体509所工作令借方支出', '2026-07-21 12:00:00', '20260721120000', '501102', '材料费', '0'),
('RAW-DEMO-B-01', 'DEMO-YEAR-LEDGER-2023-01', '2023', '12', '20231231', 'PZ-DEMO-B-2023-01', 'DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '电子所', 'SUBJ-501101', '501101', '职工薪酬及劳务费', 'ZY-2026-DEMO-YEAR-002', 'MODEL_DEMO_YEARLY', '跨年度账面演示项目', 'SRC-DEMO-YEAR-WO-01', 'DEMO-YEAR-WO-01', '跨年度电子系统工作令', '借', '1200000', '2023 年职工薪酬及劳务费', '2026-07-21 12:00:00', '20260721120000', '501101', '职工薪酬及劳务费', '0'),
('RAW-DEMO-B-02', 'DEMO-YEAR-LEDGER-2023-02', '2023', '12', '20231231', 'PZ-DEMO-B-2023-02', 'DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '电子所', 'SUBJ-501102', '501102', '材料费', 'ZY-2026-DEMO-YEAR-002', 'MODEL_DEMO_YEARLY', '跨年度账面演示项目', 'SRC-DEMO-YEAR-WO-01', 'DEMO-YEAR-WO-01', '跨年度电子系统工作令', '借', '800000', '2023 年材料费', '2026-07-21 12:00:00', '20260721120000', '501102', '材料费', '0'),
('RAW-DEMO-B-03', 'DEMO-YEAR-LEDGER-2024-01', '2024', '12', '20241231', 'PZ-DEMO-B-2024-01', 'DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '电子所', 'SUBJ-501103', '501103', '专用费', 'ZY-2026-DEMO-YEAR-002', 'MODEL_DEMO_YEARLY', '跨年度账面演示项目', 'SRC-DEMO-YEAR-WO-01', 'DEMO-YEAR-WO-01', '跨年度电子系统工作令', '借', '1400000', '2024 年专用费', '2026-07-21 12:00:00', '20260721120000', '501103', '专用费', '0'),
('RAW-DEMO-B-04', 'DEMO-YEAR-LEDGER-2024-02', '2024', '12', '20241231', 'PZ-DEMO-B-2024-02', 'DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '电子所', 'SUBJ-501104', '501104', '外协费', 'ZY-2026-DEMO-YEAR-002', 'MODEL_DEMO_YEARLY', '跨年度账面演示项目', 'SRC-DEMO-YEAR-WO-01', 'DEMO-YEAR-WO-01', '跨年度电子系统工作令', '借', '1100000', '2024 年外协费', '2026-07-21 12:00:00', '20260721120000', '501104', '外协费', '0'),
('RAW-DEMO-B-05', 'DEMO-YEAR-LEDGER-2025-01', '2025', '12', '20251231', 'PZ-DEMO-B-2025-01', 'DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '电子所', 'SUBJ-501105', '501105', '燃料动力费', 'ZY-2026-DEMO-YEAR-002', 'MODEL_DEMO_YEARLY', '跨年度账面演示项目', 'SRC-DEMO-YEAR-WO-01', 'DEMO-YEAR-WO-01', '跨年度电子系统工作令', '借', '900000', '2025 年燃料动力费', '2026-07-21 12:00:00', '20260721120000', '501105', '燃料动力费', '0'),
('RAW-DEMO-B-06', 'DEMO-YEAR-LEDGER-2025-02', '2025', '12', '20251231', 'PZ-DEMO-B-2025-02', 'DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '电子所', 'SUBJ-501106', '501106', '事务费', 'ZY-2026-DEMO-YEAR-002', 'MODEL_DEMO_YEARLY', '跨年度账面演示项目', 'SRC-DEMO-YEAR-WO-01', 'DEMO-YEAR-WO-01', '跨年度电子系统工作令', '借', '1100000', '2025 年事务费', '2026-07-21 12:00:00', '20260721120000', '501106', '事务费', '0'),
('RAW-DEMO-B-07', 'DEMO-YEAR-LEDGER-2026-01', '2026', '12', '20261231', 'PZ-DEMO-B-2026-01', 'DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '电子所', 'SUBJ-501107', '501107', '固定资产折旧费', 'ZY-2026-DEMO-YEAR-002', 'MODEL_DEMO_YEARLY', '跨年度账面演示项目', 'SRC-DEMO-YEAR-WO-01', 'DEMO-YEAR-WO-01', '跨年度电子系统工作令', '借', '1500000', '2026 年固定资产折旧费', '2026-07-21 12:00:00', '20260721120000', '501107', '固定资产折旧费', '0'),
('RAW-DEMO-B-08', 'DEMO-YEAR-LEDGER-2026-02', '2026', '12', '20261231', 'PZ-DEMO-B-2026-02', 'DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '电子所', 'SUBJ-501108', '501108', '管理费', 'ZY-2026-DEMO-YEAR-002', 'MODEL_DEMO_YEARLY', '跨年度账面演示项目', 'SRC-DEMO-YEAR-WO-01', 'DEMO-YEAR-WO-01', '跨年度电子系统工作令', '借', '2000000', '2026 年管理费', '2026-07-21 12:00:00', '20260721120000', '501108', '管理费', '0'),
('RAW-DEMO-B-09', 'DEMO-YEAR-LEDGER-2024-CREDIT', '2024', '12', '20241231', 'PZ-DEMO-B-2024-C', 'DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '电子所', 'SUBJ-501102', '501102', '材料费', 'ZY-2026-DEMO-YEAR-002', 'MODEL_DEMO_YEARLY', '跨年度账面演示项目', 'SRC-DEMO-YEAR-WO-01', 'DEMO-YEAR-WO-01', '跨年度电子系统工作令', '贷', '300000', '2024 年材料冲销贷方', '2026-07-21 12:00:00', '20260721120000', '501102', '材料费', '0'),
('RAW-DEMO-B-10', 'DEMO-YEAR-LEDGER-2026-CREDIT', '2026', '12', '20261231', 'PZ-DEMO-B-2026-C', 'DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '电子所', 'SUBJ-501104', '501104', '外协费', 'ZY-2026-DEMO-YEAR-002', 'MODEL_DEMO_YEARLY', '跨年度账面演示项目', 'SRC-DEMO-YEAR-WO-01', 'DEMO-YEAR-WO-01', '跨年度电子系统工作令', '贷', '200000', '2026 年外协冲销贷方', '2026-07-21 12:00:00', '20260721120000', '501104', '外协费', '0');

COMMIT;

SELECT 'unit_dict' AS source_table, count(*) AS row_count FROM cost_demo_source.unit_dict
UNION ALL SELECT 'ads_lc_lshsxm2022', count(*) FROM cost_demo_source.ads_lc_lshsxm2022
UNION ALL SELECT 'dwd_bd_bfcustomitem_gzl', count(*) FROM cost_demo_source.dwd_bd_bfcustomitem_gzl
UNION ALL SELECT 'precontrol_project_unit_amount', count(*) FROM cost_demo_source.precontrol_project_unit_amount
UNION ALL SELECT 'project_office_fill', count(*) FROM cost_demo_source.project_office_fill
UNION ALL SELECT 'work_order_fill', count(*) FROM cost_demo_source.work_order_fill
UNION ALL SELECT 'dws_bu_pz_pzmx_gzl', count(*) FROM cost_demo_source.dws_bu_pz_pzmx_gzl
ORDER BY source_table;
