-- 成本库 MVP 外网测试数据 SQL
-- 状态：初稿
-- 说明：只放模拟测试数据，不放表结构。
-- 注意：本脚本会清空成本库 MVP 表内测试数据，适合外网测试库重复初始化。

USE `costree_mvp`;

SET @cost_tenant_id := 124;

SET FOREIGN_KEY_CHECKS = 0;

DELETE FROM `cost_warning_record`;
DELETE FROM `cost_import_error`;
DELETE FROM `cost_import_batch`;
DELETE FROM `cost_unit_cost_detail`;
DELETE FROM `cost_work_order_ledger_detail`;
DELETE FROM `cost_work_order_project_ref`;
DELETE FROM `cost_work_order`;
DELETE FROM `cost_project_basic`;
DELETE FROM `cost_unit_dict`;
DELETE FROM `cost_project`;
DELETE FROM `cost_model_node`;
DELETE FROM `cost_source_project_tree`;

SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO `cost_model_node`
(`id`, `parent_id`, `node_code`, `node_name`, `node_type`, `domain_code`, `sort`, `status`, `remark`, `creator`, `updater`, `tenant_id`)
VALUES
(1, 0, 'DOMAIN_LAUNCH', '运载火箭', 'DOMAIN', 'LAUNCH', 10, 'ENABLE', '外网测试领域', 'cost_seed', 'cost_seed', @cost_tenant_id),
(2, 0, 'DOMAIN_MISSILE', '导弹武器', 'DOMAIN', 'MISSILE', 20, 'ENABLE', '外网测试领域', 'cost_seed', 'cost_seed', @cost_tenant_id),
(3, 0, 'DOMAIN_SATELLITE', '卫星项目', 'DOMAIN', 'SATELLITE', 30, 'ENABLE', '外网测试领域', 'cost_seed', 'cost_seed', @cost_tenant_id),
(4, 0, 'DOMAIN_SPACE', '空间安全', 'DOMAIN', 'SPACE', 40, 'ENABLE', '外网测试领域', 'cost_seed', 'cost_seed', @cost_tenant_id),
(11, 1, 'SERIES_LAUNCH_A', '长征系列', 'SERIES', 'LAUNCH', 10, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(12, 1, 'SERIES_LAUNCH_B', '商业运载系列', 'SERIES', 'LAUNCH', 20, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(21, 2, 'SERIES_MISSILE_A', '战术武器系列', 'SERIES', 'MISSILE', 10, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(22, 2, 'SERIES_MISSILE_B', '防空武器系列', 'SERIES', 'MISSILE', 20, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(31, 3, 'SERIES_SAT_A', '遥感卫星系列', 'SERIES', 'SATELLITE', 10, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(32, 3, 'SERIES_SAT_B', '通信卫星系列', 'SERIES', 'SATELLITE', 20, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(41, 4, 'SERIES_SPACE_A', '空间监测系列', 'SERIES', 'SPACE', 10, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(42, 4, 'SERIES_SPACE_B', '空间防护系列', 'SERIES', 'SPACE', 20, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(111, 11, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 'MODEL', 'LAUNCH', 10, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(112, 12, 'MODEL_LAUNCH_SY1', 'SY-1 商业发射', 'MODEL', 'LAUNCH', 20, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(211, 21, 'MODEL_MISSILE_DW1', 'DW-1 制导武器', 'MODEL', 'MISSILE', 10, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(212, 22, 'MODEL_MISSILE_FK2', 'FK-2 防空型号', 'MODEL', 'MISSILE', 20, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(311, 31, 'MODEL_SAT_YG5', 'YG-5 遥感平台', 'MODEL', 'SATELLITE', 10, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(312, 32, 'MODEL_SAT_TX3', 'TX-3 通信平台', 'MODEL', 'SATELLITE', 20, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(411, 41, 'MODEL_SPACE_JC2', 'JC-2 空间监测', 'MODEL', 'SPACE', 10, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id),
(412, 42, 'MODEL_SPACE_FH1', 'FH-1 空间防护', 'MODEL', 'SPACE', 20, 'ENABLE', NULL, 'cost_seed', 'cost_seed', @cost_tenant_id);

INSERT INTO `cost_project`
(`id`, `project_code`, `project_name`, `model_node_id`, `domain_code`, `domain_name`, `category_code`, `category_name`, `model_code`, `model_name`, `batch_no`, `stage_codes`, `unit_id`, `unit_name`, `unit_type`, `project_office_status`, `unit_fill_status`, `audit_status`, `dept_id`, `owner_user_id`, `warning_status`, `remark`, `creator`, `updater`, `tenant_id`)
VALUES
(1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 111, 'LAUNCH', '运载火箭', 'SERIES_LAUNCH_A', '长征系列', 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 'B01', 'M,C,Z', 2001, '一部总体室', '院内单位', 'FILLED', 'FILLED', 'SUBMITTED', 101, 10001, 'OVER', '外网测试项目', 'cost_seed', 'cost_seed', @cost_tenant_id),
(1002, 'ZY-2026-LA-002', 'SY-1 商业发射主业项目', 112, 'LAUNCH', '运载火箭', 'SERIES_LAUNCH_B', '商业运载系列', 'MODEL_LAUNCH_SY1', 'SY-1 商业发射', 'B02', 'M,C', 2002, '二部发射系统室', '院内单位', 'FILLED', 'PART_FILLED', 'DRAFT', 102, 10002, 'NORMAL', '外网测试项目', 'cost_seed', 'cost_seed', @cost_tenant_id),
(1003, 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', 211, 'MISSILE', '导弹武器', 'SERIES_MISSILE_A', '战术武器系列', 'MODEL_MISSILE_DW1', 'DW-1 制导武器', 'W01', 'M,C,S,D', 2003, '三部武器系统室', '院内单位', 'FILLED', 'FILLED', 'SUBMITTED', 103, 10003, 'OVER', '外网测试项目', 'cost_seed', 'cost_seed', @cost_tenant_id),
(1004, 'ZY-2026-DW-002', 'FK-2 防空型号主业项目', 212, 'MISSILE', '导弹武器', 'SERIES_MISSILE_B', '防空武器系列', 'MODEL_MISSILE_FK2', 'FK-2 防空型号', 'W02', 'M,C,S', 2004, '四部防空系统室', '院内单位', 'PART_FILLED', 'PART_FILLED', 'DRAFT', 104, 10004, 'NORMAL', '外网测试项目', 'cost_seed', 'cost_seed', @cost_tenant_id),
(1005, 'ZY-2026-ST-001', 'YG-5 遥感平台主业项目', 311, 'SATELLITE', '卫星项目', 'SERIES_SAT_A', '遥感卫星系列', 'MODEL_SAT_YG5', 'YG-5 遥感平台', 'S01', 'M,C,Z', 2005, '五部卫星总体室', '院内单位', 'FILLED', 'FILLED', 'APPROVED', 105, 10005, 'OVER', '外网测试项目', 'cost_seed', 'cost_seed', @cost_tenant_id),
(1006, 'ZY-2026-ST-002', 'TX-3 通信平台主业项目', 312, 'SATELLITE', '卫星项目', 'SERIES_SAT_B', '通信卫星系列', 'MODEL_SAT_TX3', 'TX-3 通信平台', 'S02', 'M,C', 2006, '六部通信载荷室', '院内单位', 'NOT_FILLED', 'PART_FILLED', 'DRAFT', 106, 10006, 'NORMAL', '外网测试项目', 'cost_seed', 'cost_seed', @cost_tenant_id),
(1007, 'ZY-2026-SP-001', 'JC-2 空间监测主业项目', 411, 'SPACE', '空间安全', 'SERIES_SPACE_A', '空间监测系列', 'MODEL_SPACE_JC2', 'JC-2 空间监测', 'K01', 'M,C,Z', 2007, '七部空间监测室', '院内单位', 'FILLED', 'FILLED', 'SUBMITTED', 107, 10007, 'OVER', '外网测试项目', 'cost_seed', 'cost_seed', @cost_tenant_id),
(1008, 'ZY-2026-SP-002', 'FH-1 空间防护主业项目', 412, 'SPACE', '空间安全', 'SERIES_SPACE_B', '空间防护系列', 'MODEL_SPACE_FH1', 'FH-1 空间防护', 'K02', 'M,C', 2008, '八部空间防护室', '院内单位', 'PART_FILLED', 'NOT_FILLED', 'REJECTED', 108, 10008, 'NORMAL', '外网测试项目', 'cost_seed', 'cost_seed', @cost_tenant_id);

INSERT INTO `cost_source_project_tree`
(`id`, `source_project_id`, `project_code`, `project_name`, `project_category`, `domain_code`, `domain_name`, `parent_source_id`, `parent_path`, `level_no`, `source_lastmodify`, `custom_01`, `custom_02`, `remark`, `creator`, `updater`, `tenant_id`)
VALUES
(8001, 'SRC-XM-1001', 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', '主业项目第三层级/长征系列', 'LAUNCH', '运载火箭', 'SRC-DOMAIN-LAUNCH', '/SRC-DOMAIN-LAUNCH/SRC-SERIES-LAUNCH-A', 3, '2026-05-01 08:30:00', 'B01', 'M,C,Z', '业务参考主业项目树样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8002, 'SRC-XM-1002', 'ZY-2026-LA-002', 'SY-1 商业发射主业项目', '主业项目第三层级/商业运载系列', 'LAUNCH', '运载火箭', 'SRC-DOMAIN-LAUNCH', '/SRC-DOMAIN-LAUNCH/SRC-SERIES-LAUNCH-B', 3, '2026-05-01 09:00:00', 'B02', 'M,C', '业务参考主业项目树样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8003, 'SRC-XM-1003', 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', '主业项目第三层级/战术武器系列', 'MISSILE', '导弹武器', 'SRC-DOMAIN-MISSILE', '/SRC-DOMAIN-MISSILE/SRC-SERIES-MISSILE-A', 3, '2026-05-02 08:30:00', 'W01', 'M,C,S,D', '业务参考主业项目树样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8004, 'SRC-XM-1004', 'ZY-2026-DW-002', 'FK-2 防空型号主业项目', '主业项目第三层级/防空武器系列', 'MISSILE', '导弹武器', 'SRC-DOMAIN-MISSILE', '/SRC-DOMAIN-MISSILE/SRC-SERIES-MISSILE-B', 3, '2026-05-02 09:00:00', 'W02', 'M,C,S', '业务参考主业项目树样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8005, 'SRC-XM-1005', 'ZY-2026-ST-001', 'YG-5 遥感平台主业项目', '主业项目第三层级/遥感卫星系列', 'SATELLITE', '卫星项目', 'SRC-DOMAIN-SATELLITE', '/SRC-DOMAIN-SATELLITE/SRC-SERIES-SAT-A', 3, '2026-05-03 08:30:00', 'S01', 'M,C,Z', '业务参考主业项目树样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8006, 'SRC-XM-1006', 'ZY-2026-ST-002', 'TX-3 通信平台主业项目', '主业项目第三层级/通信卫星系列', 'SATELLITE', '卫星项目', 'SRC-DOMAIN-SATELLITE', '/SRC-DOMAIN-SATELLITE/SRC-SERIES-SAT-B', 3, '2026-05-03 09:00:00', 'S02', 'M,C', '业务参考主业项目树样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8007, 'SRC-XM-1007', 'ZY-2026-SP-001', 'JC-2 空间监测主业项目', '主业项目第三层级/空间监测系列', 'SPACE', '空间安全', 'SRC-DOMAIN-SPACE', '/SRC-DOMAIN-SPACE/SRC-SERIES-SPACE-A', 3, '2026-05-04 08:30:00', 'K01', 'M,C,Z', '业务参考主业项目树样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8008, 'SRC-XM-1008', 'ZY-2026-SP-002', 'FH-1 空间防护主业项目', '主业项目第三层级/空间防护系列', 'SPACE', '空间安全', 'SRC-DOMAIN-SPACE', '/SRC-DOMAIN-SPACE/SRC-SERIES-SPACE-B', 3, '2026-05-04 09:00:00', 'K02', 'M,C', '业务参考主业项目树样例', 'cost_seed', 'cost_seed', @cost_tenant_id);

INSERT INTO `cost_unit_dict`
(`id`, `accounting_unit_id`, `accounting_unit_code`, `accounting_unit_name`, `manage_unit_code`, `manage_unit_name`, `contact_unit_code`, `contact_unit_name`, `inside_group`, `inside_institute`, `unit_id`, `status`, `remark`, `creator`, `updater`, `tenant_id`)
VALUES
(9001, 'ACCT-0110', '0110', '上海航天技术研究院', '8001', '院部', NULL, NULL, b'1', b'1', 2001, 'ENABLE', '截图单位字典样例：院部', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9002, 'ACCT-01100008', '01100008', '上海机电工程研究所', '0008', '八部', NULL, NULL, b'1', b'1', 2011, 'ENABLE', '截图单位字典样例：八部', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9003, 'ACCT-01100805', '01100805', '上海宇航系统工程研究所', '0805', '805所', NULL, NULL, b'1', b'1', 2012, 'ENABLE', '截图单位字典样例：805所', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9004, 'ACCT-01100509', '01100509', '上海卫星工程研究所', '0509', '509所', NULL, NULL, b'1', b'1', 2013, 'ENABLE', '截图单位字典样例：509所', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9005, 'ACCT-01100800', '01100800', '上海航天精密机械研究所', '0800', '800所', NULL, NULL, b'1', b'1', 2014, 'ENABLE', '截图单位字典样例：800所', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9006, 'ACCT-01100149', '01100149', '上海航天设备制造总厂有限公司', '0149', '149厂', NULL, NULL, b'1', b'1', 2015, 'ENABLE', '截图单位字典样例：149厂', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9007, 'ACCT-01100812', '01100812', '上海卫星装备研究所', '0812', '812所', NULL, NULL, b'1', b'1', 2016, 'ENABLE', '截图单位字典样例：812所', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9008, 'ACCT-01100802', '01100802', '上海无线电设备研究所', '0802', '802所', NULL, NULL, b'1', b'1', 2017, 'ENABLE', '截图单位字典样例：802所', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9009, 'ACCT-01100803', '01100803', '上海航天控制技术研究所', '0803', '803所', NULL, NULL, b'1', b'1', 2018, 'ENABLE', '截图单位字典样例：803所', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9010, 'ACCT-01100804', '01100804', '上海航天电子通讯设备研究所', '0804', '电子所', NULL, NULL, b'1', b'1', 2019, 'ENABLE', '截图单位字典样例：电子所', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9011, 'ACCT-0110080201', '0110080201', '上海神添实业有限公司', '0802', '802所', NULL, NULL, b'1', b'1', 2020, 'ENABLE', '截图单位字典样例：802所下属单位', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9012, 'ACCT-0110080402', '0110080402', '上海神舟新能源发展有限公司', '0804', '电子所', NULL, NULL, b'1', b'1', 2021, 'ENABLE', '截图单位字典样例：电子所下属单位', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9013, 'ACCT-01100809', '01100809', '上海航天计算机技术研究所', '0804', '电子所', NULL, NULL, b'1', b'1', 2022, 'ENABLE', '截图单位字典样例：电子所管理', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9014, 'ACCT-01100813', '01100813', '上海航天测控通信研究所', '0804', '电子所', NULL, NULL, b'1', b'1', 2023, 'ENABLE', '截图单位字典样例：电子所管理', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9051, 'ACCT-EXT-XH', 'EXT-XH-001', '星河装备有限公司', 'EXT', '院外协作单位', 'XH-001', '星河装备有限公司', b'0', b'0', 3051, 'ENABLE', '外网测试院外单位', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9052, 'ACCT-EXT-HY', 'EXT-HY-001', '海岳科技有限公司', 'EXT', '院外协作单位', 'HY-001', '海岳科技有限公司', b'0', b'0', 3052, 'ENABLE', '外网测试院外单位', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9053, 'ACCT-EXT-QH', 'EXT-QH-001', '启航商业航天有限公司', 'EXT', '院外协作单位', 'QH-001', '启航商业航天有限公司', b'0', b'0', 3053, 'ENABLE', '外网测试院外单位', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9054, 'ACCT-EXT-BC', 'EXT-BC-001', '北辰电子有限公司', 'EXT', '院外协作单位', 'BC-001', '北辰电子有限公司', b'0', b'0', 3054, 'ENABLE', '外网测试院外单位', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9055, 'ACCT-EXT-ZHCK', 'EXT-ZHCK-001', '中航测控有限公司', 'EXT', '院外协作单位', 'ZHCK-001', '中航测控有限公司', b'0', b'0', 3055, 'ENABLE', '外网测试院外单位', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9056, 'ACCT-EXT-YW', 'EXT-YW-001', '远望卫星技术有限公司', 'EXT', '院外协作单位', 'YW-001', '远望卫星技术有限公司', b'0', b'0', 3056, 'ENABLE', '外网测试院外单位', 'cost_seed', 'cost_seed', @cost_tenant_id),
(9057, 'ACCT-EXT-TS', 'EXT-TS-001', '天枢光电有限公司', 'EXT', '院外协作单位', 'TS-001', '天枢光电有限公司', b'0', b'0', 3057, 'ENABLE', '外网测试院外单位', 'cost_seed', 'cost_seed', @cost_tenant_id);

INSERT INTO `cost_project_basic`
(`id`, `project_id`, `project_code`, `project_name`, `subsystem_name`, `user_name`, `acquire_method`, `batch_category`, `platform_series`, `research_unit_id`, `research_unit_name`, `target_price`, `competitor_unit_1`, `competitor_price_1`, `competitor_unit_2`, `competitor_price_2`, `contract_amount`, `target_cost_amount`, `approved_amount`, `cycle_start`, `cycle_end`, `stage_code`, `basic_info`, `status`, `remark`, `dept_id`, `owner_user_id`, `creator`, `updater`, `tenant_id`)
VALUES
(2001, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', '总体设计', '项目办A', '竞争择优', 'B01/总体', '长征系列', 2001, '上海航天技术研究院', 12800.00, '星河装备有限公司', 13200.00, '海岳科技有限公司', 12950.00, 12600.00, 10400.00, 10180.00, '2026-01', '2026-12', 'C', '总体方案与成本控制样本', 'SUBMITTED', '项目办测试数据', 101, 10001, 'cost_seed', 'cost_seed', @cost_tenant_id),
(2002, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', '动力系统', '项目办A', '单一来源', 'B01/动力', '长征系列', 2011, '上海机电工程研究所', 8600.00, NULL, NULL, NULL, NULL, 8500.00, 7200.00, NULL, '2026-02', '2026-11', 'C', '动力系统目标成本样本', 'DRAFT', '待补审定金额', 101, 10001, 'cost_seed', 'cost_seed', @cost_tenant_id),
(2003, 1002, 'ZY-2026-LA-002', 'SY-1 商业发射主业项目', '发射服务', '项目办B', '其他', 'B02/服务', '商业运载系列', 2002, '上海航天技术研究院', 6800.00, '启航商业航天有限公司', 7000.00, NULL, NULL, 6600.00, 5400.00, NULL, '2026-03', '2026-10', 'M', '商业发射服务样本', 'DRAFT', NULL, 102, 10002, 'cost_seed', 'cost_seed', @cost_tenant_id),
(2004, 1003, 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', '制导控制', '项目办C', '竞争择优', 'W01/制导', '战术武器系列', 2003, '上海无线电设备研究所', 9800.00, '北辰电子有限公司', 10200.00, '中航测控有限公司', 9950.00, 9600.00, 8100.00, 8020.00, '2026-01', '2027-03', 'S', '制导控制分系统样本', 'SUBMITTED', NULL, 103, 10003, 'cost_seed', 'cost_seed', @cost_tenant_id),
(2005, 1003, 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', '弹体结构', '项目办C', '单一来源', 'W01/结构', '战术武器系列', 2013, '结构研制单位', 7200.00, NULL, NULL, NULL, NULL, 7100.00, 5900.00, NULL, '2026-02', '2027-02', 'D', '弹体结构成本样本', 'SUBMITTED', NULL, 103, 10003, 'cost_seed', 'cost_seed', @cost_tenant_id),
(2006, 1004, 'ZY-2026-DW-002', 'FK-2 防空型号主业项目', '雷达接口', '项目办D', '竞争择优', 'W02/接口', '防空武器系列', 2004, '四部防空系统室', 5100.00, '天目雷达', 5300.00, NULL, NULL, 5000.00, 4100.00, NULL, '2026-04', '2027-01', 'C', '接口适配样本', 'DRAFT', NULL, 104, 10004, 'cost_seed', 'cost_seed', @cost_tenant_id),
(2007, 1005, 'ZY-2026-ST-001', 'YG-5 遥感平台主业项目', '卫星平台', '项目办E', '竞争择优', 'S01/平台', '遥感卫星系列', 2005, '五部卫星总体室', 15000.00, '星图空间', 15400.00, '远望卫星', 15150.00, 14800.00, 12200.00, 12020.00, '2026-01', '2027-06', 'Z', '遥感卫星平台样本', 'APPROVED', NULL, 105, 10005, 'cost_seed', 'cost_seed', @cost_tenant_id),
(2008, 1006, 'ZY-2026-ST-002', 'TX-3 通信平台主业项目', '通信载荷', '项目办F', '单一来源', 'S02/载荷', '通信卫星系列', 2006, '六部通信载荷室', 11800.00, NULL, NULL, NULL, NULL, 11600.00, 9700.00, NULL, '2026-02', '2027-04', 'C', '通信载荷样本', 'DRAFT', NULL, 106, 10006, 'cost_seed', 'cost_seed', @cost_tenant_id),
(2009, 1007, 'ZY-2026-SP-001', 'JC-2 空间监测主业项目', '监测载荷', '项目办G', '竞争择优', 'K01/载荷', '空间监测系列', 2007, '七部空间监测室', 9200.00, '天枢光电', 9500.00, NULL, NULL, 9000.00, 7600.00, 7510.00, '2026-01', '2026-12', 'Z', '空间监测载荷样本', 'SUBMITTED', NULL, 107, 10007, 'cost_seed', 'cost_seed', @cost_tenant_id),
(2010, 1008, 'ZY-2026-SP-002', 'FH-1 空间防护主业项目', '防护系统', '项目办H', '其他', 'K02/系统', '空间防护系列', 2008, '八部空间防护室', 7800.00, NULL, NULL, NULL, NULL, 7600.00, 6400.00, NULL, '2026-05', '2027-05', 'M', '空间防护系统样本', 'REJECTED', '模拟退回状态', 108, 10008, 'cost_seed', 'cost_seed', @cost_tenant_id);

INSERT INTO `cost_work_order`
(`id`, `project_id`, `project_code`, `project_name`, `unit_id`, `unit_name`, `work_order_no`, `work_order_name`, `product_target_cost`, `book_cost_amount`, `stage_codes`, `max_stage_code`, `subsystem_name`, `product_short_name`, `quantity`, `vertical_division`, `approved_amount`, `status`, `remark`, `dept_id`, `owner_user_id`, `creator`, `updater`, `tenant_id`)
VALUES
(3001, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 2011, '上海机电工程研究所', 'WO-LA-001-01', '发动机方案设计工作令', 1200.00, 1180.00, 'M', 'M', '动力系统', '发动机方案', 2, b'0', 1160.00, 'SUBMITTED', 'M阶段院内工作令样本', 101, 11001, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3002, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 2011, '上海机电工程研究所', 'WO-LA-001-02', '发动机试制工作令', 3200.00, 3680.00, 'M,C', 'C', '动力系统', '发动机试制', 2, b'0', 3600.00, 'SUBMITTED', '多阶段合并，按C阶段归集；超支样本', 101, 11002, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3003, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 2011, '上海机电工程研究所', 'WO-LA-001-03', '动力系统定型工作令', 1800.00, 1960.00, 'M,C,Z', 'Z', '动力系统', '动力定型', 1, b'0', 1900.00, 'SUBMITTED', '多阶段合并，按Z阶段归集', 101, 11003, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3004, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 2012, '上海宇航系统工程研究所', 'WO-LA-001-04', '总体控制单机工作令', 2100.00, 2180.00, 'M,C', 'C', '控制系统', '控制单机', 4, b'0', 2140.00, 'DRAFT', '控制系统C阶段样本', 101, 11004, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3005, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 2012, '上海宇航系统工程研究所', 'WO-LA-001-05', '箭上软件联试工作令', 1500.00, 1420.00, 'C,Z', 'Z', '控制系统', '箭上软件', 1, b'0', 1410.00, 'SUBMITTED', 'Z阶段低于目标样本', 101, 11005, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3006, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 2013, '上海卫星工程研究所', 'WO-LA-001-06', '遥测接口方案工作令', 900.00, 860.00, 'M', 'M', '测控系统', '遥测接口', 2, b'0', 850.00, 'SUBMITTED', 'M阶段样本', 101, 11006, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3007, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 2013, '上海卫星工程研究所', 'WO-LA-001-07', '遥测终端试制工作令', 2600.00, 2490.00, 'M,C', 'C', '测控系统', '遥测终端', 1, b'1', 2480.00, 'SUBMITTED', '纵向分工样本', 101, 11007, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3008, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 2015, '上海航天设备制造总厂有限公司', 'WO-LA-001-08', '箱体结构加工工作令', 2200.00, 2310.00, 'C', 'C', '结构系统', '结构箱体', 6, b'0', 2290.00, 'SUBMITTED', '149厂C阶段样本', 101, 11008, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3009, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 2015, '上海航天设备制造总厂有限公司', 'WO-LA-001-09', '总装保障工作令', 1300.00, 1280.00, 'C,Z', 'Z', '总装保障', '总装保障', 1, b'0', 1270.00, 'SUBMITTED', '149厂Z阶段样本', 101, 11009, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3010, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 2018, '上海航天控制技术研究所', 'WO-LA-001-10', '伺服机构联试工作令', 1650.00, 1710.00, 'M,C,Z', 'Z', '伺服控制', '伺服机构', 3, b'0', 1690.00, 'SUBMITTED', '803所Z阶段样本', 101, 11010, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3011, 1002, 'ZY-2026-LA-002', 'SY-1 商业发射主业项目', 2001, '上海航天技术研究院', 'WO-LA-002-01', '商业发射保障工作令', 1800.00, 1900.00, 'M', 'M', '发射保障', '保障服务', 1, b'0', NULL, 'DRAFT', NULL, 102, 11011, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3012, 1003, 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', 2017, '上海无线电设备研究所', 'WO-DW-001-01', '导引头工作令', 2800.00, 3220.00, 'M,C,S', 'S', '制导控制', '导引头', 3, b'0', NULL, 'SUBMITTED', '超支样本', 103, 11012, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3013, 1003, 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', 2018, '上海航天控制技术研究所', 'WO-DW-001-02', '舵机控制工作令', 1600.00, 1710.00, 'M,C,S,D', 'D', '控制系统', '舵机', 6, b'0', NULL, 'SUBMITTED', NULL, 103, 11013, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3014, 1003, 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', 2014, '上海航天精密机械研究所', 'WO-DW-001-03', '弹体结构工作令', 2300.00, 2240.00, 'M,C,S,D', 'D', '弹体结构', '壳体', 1, b'1', NULL, 'SUBMITTED', NULL, 103, 11014, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3015, 1004, 'ZY-2026-DW-002', 'FK-2 防空型号主业项目', 2017, '上海无线电设备研究所', 'WO-DW-002-01', '雷达接口适配工作令', 1200.00, 1270.00, 'M,C', 'C', '接口系统', '接口板', 8, b'0', NULL, 'DRAFT', NULL, 104, 11015, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3016, 1005, 'ZY-2026-ST-001', 'YG-5 遥感平台主业项目', 2013, '上海卫星工程研究所', 'WO-ST-001-01', '平台综合电子工作令', 3600.00, 4100.00, 'M,C,Z', 'Z', '卫星平台', '综合电子', 2, b'0', 4010.00, 'APPROVED', '超支样本', 105, 11016, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3017, 1005, 'ZY-2026-ST-001', 'YG-5 遥感平台主业项目', 2016, '上海卫星装备研究所', 'WO-ST-001-02', '遥感载荷工作令', 4200.00, 4540.00, 'M,C,Z', 'Z', '遥感载荷', '相机载荷', 1, b'0', 4480.00, 'APPROVED', NULL, 105, 11017, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3018, 1005, 'ZY-2026-ST-001', 'YG-5 遥感平台主业项目', 2023, '上海航天测控通信研究所', 'WO-ST-001-03', '测控数传工作令', 2200.00, 2140.00, 'M,C,Z', 'Z', '测控系统', '数传终端', 2, b'0', 2100.00, 'APPROVED', NULL, 105, 11018, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3019, 1006, 'ZY-2026-ST-002', 'TX-3 通信平台主业项目', 2019, '上海航天电子通讯设备研究所', 'WO-ST-002-01', '通信转发器工作令', 3300.00, 3350.00, 'M,C', 'C', '通信载荷', '转发器', 3, b'0', NULL, 'DRAFT', NULL, 106, 11019, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3020, 1007, 'ZY-2026-SP-001', 'JC-2 空间监测主业项目', 2022, '上海航天计算机技术研究所', 'WO-SP-001-01', '光学监测载荷工作令', 2400.00, 2790.00, 'M,C,Z', 'Z', '监测载荷', '光学载荷', 2, b'0', NULL, 'SUBMITTED', '超支样本', 107, 11020, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3021, 1007, 'ZY-2026-SP-001', 'JC-2 空间监测主业项目', 2020, '上海神添实业有限公司', 'WO-SP-001-02', '数据处理软件工作令', 1600.00, 1720.00, 'M,C,Z', 'Z', '地面处理', '处理软件', 1, b'0', NULL, 'SUBMITTED', NULL, 107, 11021, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3022, 1008, 'ZY-2026-SP-002', 'FH-1 空间防护主业项目', 2021, '上海神舟新能源发展有限公司', 'WO-SP-002-01', '空间防护组件工作令', 2100.00, 2050.00, 'M', 'M', '防护系统', '防护组件', 4, b'1', NULL, 'REJECTED', '模拟退回', 108, 11022, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3023, 1002, 'ZY-2026-LA-002', 'SY-1 商业发射主业项目', 2001, '上海航天技术研究院', 'WO-LA-002-02', '商业发射待分配保障工作令', 900.00, 940.00, 'M', 'M', '发射保障', NULL, 1, b'0', NULL, 'SUBMITTED', '产品简称未填，进入待分配池', 102, 11023, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3024, 1003, 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', 2018, '上海航天控制技术研究所', 'WO-DW-001-04', '控制系统待分配联试工作令', 700.00, 860.00, 'M,C', 'C', '控制系统', '待分配', 2, b'0', NULL, 'DRAFT', '产品简称填写待分配，进入待分配池；超支样本', 103, 11024, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3025, 1005, 'ZY-2026-ST-001', 'YG-5 遥感平台主业项目', 2023, '上海航天测控通信研究所', 'WO-ST-001-04', '测控数据待分配工作令', 600.00, 580.00, 'Z', 'Z', '测控系统', '', 1, b'0', NULL, 'SUBMITTED', '产品简称空字符串，进入待分配池', 105, 11025, 'cost_seed', 'cost_seed', @cost_tenant_id),
(3026, 1007, 'ZY-2026-SP-001', 'JC-2 空间监测主业项目', 2020, '上海神添实业有限公司', 'WO-SP-001-03', '院外单位待分配处理工作令', 500.00, 620.00, 'M,C,Z', 'Z', '地面处理', '待分配', 1, b'0', NULL, 'SUBMITTED', '院外单位待分配池穿透样本；超支样本', 107, 11026, 'cost_seed', 'cost_seed', @cost_tenant_id);

INSERT INTO `cost_work_order_project_ref`
(`id`, `source_work_order_id`, `accounting_unit_code`, `accounting_unit_name`, `fiscal_year`, `work_order_no`, `work_order_name`, `disabled`, `linked_project_code`, `linked_project_name`, `linked_source_project_id`, `project_id`, `custom_01`, `custom_02`, `source_lastmodify`, `remark`, `creator`, `updater`, `tenant_id`)
VALUES
(8101, 'SRC-GZL-3001', '01100008', '上海机电工程研究所', '2026', 'WO-LA-001-01', '发动机方案设计工作令', b'0', 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'SRC-XM-1001', 1001, 'M', '动力系统', '2026-05-01 10:00:00', '业务参考工作令关联主业项目字典样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8102, 'SRC-GZL-3002', '01100008', '上海机电工程研究所', '2026', 'WO-LA-001-02', '发动机试制工作令', b'0', 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'SRC-XM-1001', 1001, 'M,C', '动力系统', '2026-05-01 10:05:00', '多阶段合并，成本归集到C阶段', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8103, 'SRC-GZL-3003', '01100008', '上海机电工程研究所', '2026', 'WO-LA-001-03', '动力系统定型工作令', b'0', 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'SRC-XM-1001', 1001, 'M,C,Z', '动力系统', '2026-05-01 10:10:00', '多阶段合并，成本归集到Z阶段', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8104, 'SRC-GZL-3004', '01100805', '上海宇航系统工程研究所', '2026', 'WO-LA-001-04', '总体控制单机工作令', b'0', 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'SRC-XM-1001', 1001, 'M,C', '控制系统', '2026-05-01 10:15:00', '业务参考工作令关联主业项目字典样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8105, 'SRC-GZL-3005', '01100805', '上海宇航系统工程研究所', '2026', 'WO-LA-001-05', '箭上软件联试工作令', b'0', 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'SRC-XM-1001', 1001, 'C,Z', '控制系统', '2026-05-01 10:20:00', '业务参考工作令关联主业项目字典样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8106, 'SRC-GZL-3006', '01100509', '上海卫星工程研究所', '2026', 'WO-LA-001-06', '遥测接口方案工作令', b'0', 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'SRC-XM-1001', 1001, 'M', '测控系统', '2026-05-01 10:25:00', '业务参考工作令关联主业项目字典样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8107, 'SRC-GZL-3007', '01100509', '上海卫星工程研究所', '2026', 'WO-LA-001-07', '遥测终端试制工作令', b'0', 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'SRC-XM-1001', 1001, 'M,C', '测控系统', '2026-05-01 10:30:00', '业务参考工作令关联主业项目字典样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8108, 'SRC-GZL-3008', '01100149', '上海航天设备制造总厂有限公司', '2026', 'WO-LA-001-08', '箱体结构加工工作令', b'0', 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'SRC-XM-1001', 1001, 'C', '结构系统', '2026-05-01 10:35:00', '业务参考工作令关联主业项目字典样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8109, 'SRC-GZL-3012', '01100802', '上海无线电设备研究所', '2026', 'WO-DW-001-01', '导引头工作令', b'0', 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', 'SRC-XM-1003', 1003, 'M,C,S', '制导控制', '2026-05-02 10:00:00', '业务参考工作令关联主业项目字典样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8110, 'SRC-GZL-3016', '01100509', '上海卫星工程研究所', '2026', 'WO-ST-001-01', '平台综合电子工作令', b'0', 'ZY-2026-ST-001', 'YG-5 遥感平台主业项目', 'SRC-XM-1005', 1005, 'M,C,Z', '卫星平台', '2026-05-03 10:00:00', '业务参考工作令关联主业项目字典样例', 'cost_seed', 'cost_seed', @cost_tenant_id);

INSERT INTO `cost_work_order_ledger_detail`
(`id`, `source_detail_id`, `fiscal_year`, `accounting_period`, `voucher_date`, `voucher_no`, `accounting_unit_id`, `accounting_unit_code`, `accounting_unit_name`, `manage_unit_name`, `subject_id`, `subject_code`, `subject_name`, `project_code`, `source_project_id`, `project_name`, `source_work_order_id`, `work_order_no`, `work_order_name`, `debit_credit`, `amount`, `amount_wan`, `summary_text`, `source_lastmodify`, `second_subject_code`, `second_subject_name`, `source_timestamp`, `resolved_stage_code`, `project_id`, `work_order_id`, `remark`, `creator`, `updater`, `tenant_id`)
VALUES
(8201, 'YSNM-LA-3001-001', '2026', '01', '2026-01-12', 'PZ-LA-0001', 'ACCT-01100008', '01100008', '上海机电工程研究所', '八部', 'KM-500101', '500101', '直接人工', 'ZY-2026-LA-001', 'SRC-XM-1001', 'CZ-8A 批产改进主业项目', 'SRC-GZL-3001', 'WO-LA-001-01', '发动机方案设计工作令', '借', 5200000.00, 520.00, '方案设计人工成本', '2026-01-12 18:00:00', '50010101', '薪酬', '202601120001', 'M', 1001, 3001, '业务参考账面成本明细样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8202, 'YSNM-LA-3001-002', '2026', '01', '2026-01-20', 'PZ-LA-0002', 'ACCT-01100008', '01100008', '上海机电工程研究所', '八部', 'KM-500201', '500201', '材料费', 'ZY-2026-LA-001', 'SRC-XM-1001', 'CZ-8A 批产改进主业项目', 'SRC-GZL-3001', 'WO-LA-001-01', '发动机方案设计工作令', '借', 6600000.00, 660.00, '方案样机材料成本', '2026-01-20 18:00:00', '50020101', '材料费', '202601200001', 'M', 1001, 3001, '业务参考账面成本明细样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8203, 'YSNM-LA-3002-001', '2026', '03', '2026-03-08', 'PZ-LA-0101', 'ACCT-01100008', '01100008', '上海机电工程研究所', '八部', 'KM-500201', '500201', '材料费', 'ZY-2026-LA-001', 'SRC-XM-1001', 'CZ-8A 批产改进主业项目', 'SRC-GZL-3002', 'WO-LA-001-02', '发动机试制工作令', '借', 14800000.00, 1480.00, '试制材料成本', '2026-03-08 18:00:00', '50020101', '材料费', '202603080001', 'C', 1001, 3002, '多阶段工作令归集到C阶段', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8204, 'YSNM-LA-3002-002', '2026', '03', '2026-03-16', 'PZ-LA-0102', 'ACCT-01100008', '01100008', '上海机电工程研究所', '八部', 'KM-500301', '500301', '外协费', 'ZY-2026-LA-001', 'SRC-XM-1001', 'CZ-8A 批产改进主业项目', 'SRC-GZL-3002', 'WO-LA-001-02', '发动机试制工作令', '借', 12600000.00, 1260.00, '试制外协加工', '2026-03-16 18:00:00', '50030101', '外协费', '202603160001', 'C', 1001, 3002, '多阶段工作令归集到C阶段', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8205, 'YSNM-LA-3002-003', '2026', '04', '2026-04-12', 'PZ-LA-0103', 'ACCT-01100008', '01100008', '上海机电工程研究所', '八部', 'KM-500401', '500401', '制造费用', 'ZY-2026-LA-001', 'SRC-XM-1001', 'CZ-8A 批产改进主业项目', 'SRC-GZL-3002', 'WO-LA-001-02', '发动机试制工作令', '借', 9400000.00, 940.00, '试制制造费用', '2026-04-12 18:00:00', '50040101', '管理费', '202604120001', 'C', 1001, 3002, '多阶段工作令归集到C阶段', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8206, 'YSNM-LA-3003-001', '2026', '06', '2026-06-10', 'PZ-LA-0201', 'ACCT-01100008', '01100008', '上海机电工程研究所', '八部', 'KM-500101', '500101', '直接人工', 'ZY-2026-LA-001', 'SRC-XM-1001', 'CZ-8A 批产改进主业项目', 'SRC-GZL-3003', 'WO-LA-001-03', '动力系统定型工作令', '借', 7600000.00, 760.00, '定型人工成本', '2026-06-10 18:00:00', '50010101', '薪酬', '202606100001', 'Z', 1001, 3003, '多阶段工作令归集到Z阶段', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8207, 'YSNM-LA-3004-001', '2026', '04', '2026-04-18', 'PZ-LA-0301', 'ACCT-01100805', '01100805', '上海宇航系统工程研究所', '805所', 'KM-500201', '500201', '材料费', 'ZY-2026-LA-001', 'SRC-XM-1001', 'CZ-8A 批产改进主业项目', 'SRC-GZL-3004', 'WO-LA-001-04', '总体控制单机工作令', '借', 12400000.00, 1240.00, '控制单机材料成本', '2026-04-18 18:00:00', '50020101', '材料费', '202604180001', 'C', 1001, 3004, '业务参考账面成本明细样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8208, 'YSNM-LA-3005-001', '2026', '07', '2026-07-03', 'PZ-LA-0401', 'ACCT-01100805', '01100805', '上海宇航系统工程研究所', '805所', 'KM-500501', '500501', '软件费用', 'ZY-2026-LA-001', 'SRC-XM-1001', 'CZ-8A 批产改进主业项目', 'SRC-GZL-3005', 'WO-LA-001-05', '箭上软件联试工作令', '借', 14200000.00, 1420.00, '联试软件成本', '2026-07-03 18:00:00', '50050101', '其他', '202607030001', 'Z', 1001, 3005, '业务参考账面成本明细样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8209, 'YSNM-LA-3008-001', '2026', '05', '2026-05-09', 'PZ-LA-0501', 'ACCT-01100149', '01100149', '上海航天设备制造总厂有限公司', '149厂', 'KM-500201', '500201', '材料费', 'ZY-2026-LA-001', 'SRC-XM-1001', 'CZ-8A 批产改进主业项目', 'SRC-GZL-3008', 'WO-LA-001-08', '箱体结构加工工作令', '借', 23100000.00, 2310.00, '结构加工材料成本', '2026-05-09 18:00:00', '50020101', '材料费', '202605090001', 'C', 1001, 3008, '业务参考账面成本明细样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8210, 'YSNM-DW-3012-001', '2026', '04', '2026-04-14', 'PZ-DW-0001', 'ACCT-01100802', '01100802', '上海无线电设备研究所', '802所', 'KM-500301', '500301', '外协费', 'ZY-2026-DW-001', 'SRC-XM-1003', 'DW-1 制导武器主业项目', 'SRC-GZL-3012', 'WO-DW-001-01', '导引头工作令', '借', 32200000.00, 3220.00, '导引头外协成本', '2026-04-14 18:00:00', '50030101', '外协费', '202604140001', 'S', 1003, 3012, '业务参考账面成本明细样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8211, 'YSNM-ST-3016-001', '2026', '06', '2026-06-22', 'PZ-ST-0001', 'ACCT-01100509', '01100509', '上海卫星工程研究所', '509所', 'KM-500201', '500201', '材料费', 'ZY-2026-ST-001', 'SRC-XM-1005', 'YG-5 遥感平台主业项目', 'SRC-GZL-3016', 'WO-ST-001-01', '平台综合电子工作令', '借', 41000000.00, 4100.00, '平台综合电子材料成本', '2026-06-22 18:00:00', '50020101', '材料费', '202606220001', 'Z', 1005, 3016, '业务参考账面成本明细样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8212, 'YSNM-LA-3002-004', '2026', '04', '2026-04-28', 'PZ-LA-0104', 'ACCT-01100008', '01100008', '上海机电工程研究所', '八部', 'KM-500201', '500201', '材料费', 'ZY-2026-LA-001', 'SRC-XM-1001', 'CZ-8A 批产改进主业项目', 'SRC-GZL-3002', 'WO-LA-001-02', '发动机试制工作令', '贷', -600000.00, -60.00, '材料冲销', '2026-04-28 18:00:00', '50020101', '材料费', '202604280001', 'C', 1001, 3002, '贷方冲销样例，后续聚合口径需确认', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8213, 'YSNM-LA-3023-001', '2026', '02', '2026-02-16', 'PZ-LA-0601', 'ACCT-00000001', '00000001', '上海航天技术研究院', '八院本级', 'KM-500601', '500601', '其他直接费', 'ZY-2026-LA-002', 'SRC-XM-1002', 'SY-1 商业发射主业项目', 'SRC-GZL-3023', 'WO-LA-002-02', '商业发射待分配保障工作令', '借', 9400000.00, 940.00, '待分配保障支出', '2026-02-16 18:00:00', '50060101', '其他', '202602160001', 'M', 1002, 3023, '待分配池账面明细样例：产品简称未填', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8214, 'YSNM-DW-3024-001', '2026', '05', '2026-05-11', 'PZ-DW-0401', 'ACCT-01100803', '01100803', '上海航天控制技术研究所', '803所', 'KM-500301', '500301', '外协费', 'ZY-2026-DW-001', 'SRC-XM-1003', 'DW-1 制导武器主业项目', 'SRC-GZL-3024', 'WO-DW-001-04', '控制系统待分配联试工作令', '借', 8600000.00, 860.00, '待分配联试外协支出', '2026-05-11 18:00:00', '50030101', '外协费', '202605110001', 'C', 1003, 3024, '待分配池账面明细样例：产品简称待分配', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8215, 'YSNM-ST-3025-001', '2026', '08', '2026-08-09', 'PZ-ST-0401', 'ACCT-01100539', '01100539', '上海航天测控通信研究所', '539所', 'KM-500501', '500501', '软件费用', 'ZY-2026-ST-001', 'SRC-XM-1005', 'YG-5 遥感平台主业项目', 'SRC-GZL-3025', 'WO-ST-001-04', '测控数据待分配工作令', '借', 5800000.00, 580.00, '测控数据待分配支出', '2026-08-09 18:00:00', '50050101', '其他', '202608090001', 'Z', 1005, 3025, '待分配池账面明细样例：产品简称空字符串', 'cost_seed', 'cost_seed', @cost_tenant_id),
(8216, 'YSNM-SP-3026-001', '2026', '09', '2026-09-18', 'PZ-SP-0301', 'ACCT-OUT-002', 'OUT-002', '上海神添实业有限公司', '院外单位', 'KM-500301', '500301', '外协费', 'ZY-2026-SP-001', 'SRC-XM-1007', 'JC-2 空间监测主业项目', 'SRC-GZL-3026', 'WO-SP-001-03', '院外单位待分配处理工作令', '借', 6200000.00, 620.00, '院外待分配外协支出', '2026-09-18 18:00:00', '50030101', '外协费', '202609180001', 'Z', 1007, 3026, '待分配池账面明细样例：院外单位', 'cost_seed', 'cost_seed', @cost_tenant_id);

INSERT INTO `cost_unit_cost_detail`
(`id`, `project_id`, `project_code`, `project_name`, `domain_code`, `domain_name`, `model_node_id`, `model_code`, `model_name`, `unit_id`, `unit_name`, `stage_code`, `contract_amount`, `income_amount`, `target_cost_amount`, `book_cost_amount`, `salary_amount`, `material_amount`, `outsource_amount`, `manage_amount`, `fuel_power_amount`, `other_amount`, `remark`, `creator`, `updater`, `tenant_id`)
VALUES
(7001, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 2011, '上海机电工程研究所', 'M', 1500.00, 980.00, 1200.00, 1180.00, 280.00, 420.00, 200.00, 130.00, 60.00, 90.00, 'LA-001院内单位M阶段成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7002, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 2011, '上海机电工程研究所', 'C', 4200.00, 3150.00, 3200.00, 3680.00, 920.00, 1200.00, 780.00, 360.00, 220.00, 200.00, 'LA-001院内单位C阶段成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7003, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 2011, '上海机电工程研究所', 'Z', 2400.00, 1720.00, 1800.00, 1960.00, 480.00, 620.00, 420.00, 210.00, 110.00, 120.00, 'LA-001院内单位Z阶段成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7004, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 2012, '上海宇航系统工程研究所', 'C', 2500.00, 1850.00, 2100.00, 2180.00, 560.00, 710.00, 360.00, 260.00, 140.00, 150.00, 'LA-001院内单位C阶段成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7005, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 2012, '上海宇航系统工程研究所', 'Z', 1800.00, 1320.00, 1500.00, 1420.00, 430.00, 330.00, 280.00, 180.00, 90.00, 110.00, 'LA-001院内单位Z阶段成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7006, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 2013, '上海卫星工程研究所', 'M', 1100.00, 760.00, 900.00, 860.00, 210.00, 250.00, 150.00, 120.00, 60.00, 70.00, 'LA-001院内单位M阶段成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7007, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 2013, '上海卫星工程研究所', 'C', 3100.00, 2380.00, 2600.00, 2490.00, 420.00, 1160.00, 320.00, 260.00, 150.00, 180.00, 'LA-001院内单位C阶段成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7008, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 2015, '上海航天设备制造总厂有限公司', 'C', 2600.00, 2040.00, 2200.00, 2310.00, 360.00, 1120.00, 330.00, 260.00, 110.00, 130.00, 'LA-001院内单位C阶段成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7009, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 2015, '上海航天设备制造总厂有限公司', 'Z', 1700.00, 1200.00, 1300.00, 1280.00, 280.00, 520.00, 190.00, 150.00, 70.00, 70.00, 'LA-001院内单位Z阶段成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7010, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 2018, '上海航天控制技术研究所', 'Z', 2100.00, 1540.00, 1650.00, 1710.00, 470.00, 430.00, 310.00, 220.00, 120.00, 160.00, 'LA-001院内单位Z阶段成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7011, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 3051, '星河装备有限公司', 'M', 980.00, 660.00, 850.00, 790.00, 120.00, 210.00, 260.00, 90.00, 40.00, 70.00, 'LA-001院外单位M阶段成本结构样本，无工作令', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7012, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 3052, '海岳科技有限公司', 'C', 1500.00, 1120.00, 1250.00, 1370.00, 180.00, 360.00, 520.00, 150.00, 70.00, 90.00, 'LA-001院外单位C阶段成本结构样本，无工作令', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7013, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 3053, '启航商业航天有限公司', 'Z', 1200.00, 880.00, 980.00, 940.00, 150.00, 240.00, 310.00, 110.00, 50.00, 80.00, 'LA-001院外单位Z阶段成本结构样本，无工作令', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7014, 1001, 'ZY-2026-LA-001', 'CZ-8A 批产改进主业项目', 'LAUNCH', '运载火箭', 111, 'MODEL_LAUNCH_CZ8', 'CZ-8A 批产改进', 3054, '北辰电子有限公司', 'C', 900.00, 620.00, 760.00, 810.00, 110.00, 180.00, 310.00, 90.00, 40.00, 80.00, 'LA-001院外单位C阶段成本结构样本，无工作令', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7015, 1002, 'ZY-2026-LA-002', 'SY-1 商业发射主业项目', 'LAUNCH', '运载火箭', 112, 'MODEL_LAUNCH_SY1', 'SY-1 商业发射', 2001, '上海航天技术研究院', 'M', 2300.00, 1500.00, 1800.00, 1900.00, 520.00, 280.00, 610.00, 260.00, 120.00, 110.00, '总体展示成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7016, 1002, 'ZY-2026-LA-002', 'SY-1 商业发射主业项目', 'LAUNCH', '运载火箭', 112, 'MODEL_LAUNCH_SY1', 'SY-1 商业发射', 3053, '启航商业航天有限公司', 'M', 900.00, 620.00, 700.00, 680.00, 80.00, 120.00, 330.00, 60.00, 30.00, 60.00, '院外单位样本，无工作令', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7017, 1003, 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', 'MISSILE', '导弹武器', 211, 'MODEL_MISSILE_DW1', 'DW-1 制导武器', 2017, '上海无线电设备研究所', 'S', 3600.00, 2800.00, 2800.00, 3220.00, 830.00, 980.00, 620.00, 330.00, 190.00, 270.00, '总体展示成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7018, 1003, 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', 'MISSILE', '导弹武器', 211, 'MODEL_MISSILE_DW1', 'DW-1 制导武器', 2018, '上海航天控制技术研究所', 'D', 1900.00, 1320.00, 1600.00, 1710.00, 470.00, 520.00, 260.00, 210.00, 110.00, 140.00, '总体展示成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7019, 1003, 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', 'MISSILE', '导弹武器', 211, 'MODEL_MISSILE_DW1', 'DW-1 制导武器', 2014, '上海航天精密机械研究所', 'D', 2600.00, 2050.00, 2300.00, 2240.00, 360.00, 980.00, 310.00, 250.00, 130.00, 210.00, '总体展示成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7020, 1003, 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', 'MISSILE', '导弹武器', 211, 'MODEL_MISSILE_DW1', 'DW-1 制导武器', 3054, '北辰电子有限公司', 'S', 1200.00, 860.00, 980.00, 1060.00, 120.00, 180.00, 520.00, 90.00, 50.00, 100.00, '院外单位样本，无工作令', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7021, 1003, 'ZY-2026-DW-001', 'DW-1 制导武器主业项目', 'MISSILE', '导弹武器', 211, 'MODEL_MISSILE_DW1', 'DW-1 制导武器', 3055, '中航测控有限公司', 'D', 980.00, 720.00, 760.00, 730.00, 90.00, 140.00, 330.00, 70.00, 40.00, 60.00, '院外单位样本，无工作令', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7022, 1004, 'ZY-2026-DW-002', 'FK-2 防空型号主业项目', 'MISSILE', '导弹武器', 212, 'MODEL_MISSILE_FK2', 'FK-2 防空型号', 2017, '上海无线电设备研究所', 'C', 1500.00, 980.00, 1200.00, 1270.00, 310.00, 420.00, 220.00, 150.00, 80.00, 90.00, '总体展示成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7023, 1005, 'ZY-2026-ST-001', 'YG-5 遥感平台主业项目', 'SATELLITE', '卫星项目', 311, 'MODEL_SAT_YG5', 'YG-5 遥感平台', 2013, '上海卫星工程研究所', 'Z', 4700.00, 3600.00, 3600.00, 4100.00, 980.00, 1460.00, 720.00, 420.00, 250.00, 270.00, '总体展示成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7024, 1005, 'ZY-2026-ST-001', 'YG-5 遥感平台主业项目', 'SATELLITE', '卫星项目', 311, 'MODEL_SAT_YG5', 'YG-5 遥感平台', 2016, '上海卫星装备研究所', 'Z', 5200.00, 4100.00, 4200.00, 4540.00, 1080.00, 1380.00, 960.00, 510.00, 280.00, 330.00, '总体展示成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7025, 1005, 'ZY-2026-ST-001', 'YG-5 遥感平台主业项目', 'SATELLITE', '卫星项目', 311, 'MODEL_SAT_YG5', 'YG-5 遥感平台', 2023, '上海航天测控通信研究所', 'Z', 2500.00, 2100.00, 2200.00, 2140.00, 520.00, 610.00, 420.00, 260.00, 150.00, 180.00, '总体展示成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7026, 1006, 'ZY-2026-ST-002', 'TX-3 通信平台主业项目', 'SATELLITE', '卫星项目', 312, 'MODEL_SAT_TX3', 'TX-3 通信平台', 2019, '上海航天电子通讯设备研究所', 'C', 3900.00, 2860.00, 3300.00, 3350.00, 820.00, 1040.00, 660.00, 380.00, 210.00, 240.00, '总体展示成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7027, 1007, 'ZY-2026-SP-001', 'JC-2 空间监测主业项目', 'SPACE', '空间安全', 411, 'MODEL_SPACE_JC2', 'JC-2 空间监测', 2022, '上海航天计算机技术研究所', 'Z', 3000.00, 2300.00, 2400.00, 2790.00, 690.00, 870.00, 520.00, 300.00, 180.00, 230.00, '总体展示成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7028, 1007, 'ZY-2026-SP-001', 'JC-2 空间监测主业项目', 'SPACE', '空间安全', 411, 'MODEL_SPACE_JC2', 'JC-2 空间监测', 2020, '上海神添实业有限公司', 'Z', 1900.00, 1380.00, 1600.00, 1720.00, 520.00, 260.00, 410.00, 230.00, 110.00, 190.00, '总体展示成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(7029, 1008, 'ZY-2026-SP-002', 'FH-1 空间防护主业项目', 'SPACE', '空间安全', 412, 'MODEL_SPACE_FH1', 'FH-1 空间防护', 2021, '上海神舟新能源发展有限公司', 'M', 2500.00, 1740.00, 2100.00, 2050.00, 430.00, 760.00, 320.00, 260.00, 120.00, 160.00, '总体展示成本结构样本', 'cost_seed', 'cost_seed', @cost_tenant_id);

INSERT INTO `cost_import_batch`
(`id`, `import_type`, `file_name`, `file_url`, `total_count`, `success_count`, `failure_count`, `update_support`, `status`, `remark`, `creator`, `updater`, `tenant_id`)
VALUES
(4001, 'PROJECT_BASIC', '项目基本情况导入模板-样例.xlsx', '/mock/cost/import/project-basic-demo.xlsx', 10, 10, 0, b'1', 'SUCCESS', '外网测试导入批次', 'cost_seed', 'cost_seed', @cost_tenant_id),
(4002, 'WORK_ORDER', '工作令基础信息导入模板-样例.xlsx', '/mock/cost/import/work-order-demo.xlsx', 23, 22, 1, b'1', 'PART_SUCCESS', '含一条模拟错误', 'cost_seed', 'cost_seed', @cost_tenant_id),
(4003, 'SOURCE_PROJECT_TREE', '主业项目树同步样例.xlsx', '/mock/cost/import/source-project-tree-demo.xlsx', 8, 8, 0, b'1', 'SUCCESS', '业务方建表参考源项目树样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(4004, 'WORK_ORDER_REF', '工作令关联主业项目字典同步样例.xlsx', '/mock/cost/import/work-order-ref-demo.xlsx', 10, 10, 0, b'1', 'SUCCESS', '业务方建表参考工作令关联样例', 'cost_seed', 'cost_seed', @cost_tenant_id),
(4005, 'LEDGER_DETAIL', '工作令账面成本明细同步样例.xlsx', '/mock/cost/import/ledger-detail-demo.xlsx', 12, 12, 0, b'1', 'SUCCESS', '业务方建表参考账面成本明细样例', 'cost_seed', 'cost_seed', @cost_tenant_id);

INSERT INTO `cost_import_error`
(`id`, `batch_id`, `row_num`, `field_name`, `error_message`, `raw_data`, `creator`, `updater`, `tenant_id`)
VALUES
(5001, 4002, 12, 'work_order_no', '工作令编号不能为空', '{"projectCode":"ZY-2026-ST-002","workOrderName":"模拟错误行"}', 'cost_seed', 'cost_seed', @cost_tenant_id);

INSERT INTO `cost_warning_record`
(`id`, `project_id`, `work_order_id`, `warning_source`, `warning_title`, `target_cost_amount`, `actual_cost_amount`, `over_amount`, `over_rate`, `threshold_rate`, `warning_level`, `responsible_unit_name`, `push_status`, `pushed_time`, `receiver_scope`, `status`, `remark`, `creator`, `updater`, `tenant_id`)
VALUES
(6001, 1001, 3002, 'WORK_ORDER', '发动机试制工作令超支预警', 3200.00, 3680.00, 480.00, 0.1500, 0.1000, 'OVER', '上海机电工程研究所', 'PUSHED', '2026-05-17 02:00:00', 'ALL', 'OPEN', '外网测试全部推送', 'cost_seed', 'cost_seed', @cost_tenant_id),
(6002, 1003, 3012, 'WORK_ORDER', '导引头工作令超支预警', 2800.00, 3220.00, 420.00, 0.1500, 0.1000, 'OVER', '上海无线电设备研究所', 'NOT_PUSHED', NULL, 'ALL', 'OPEN', '外网测试待推送', 'cost_seed', 'cost_seed', @cost_tenant_id),
(6003, 1005, 3016, 'WORK_ORDER', '平台综合电子工作令超支预警', 3600.00, 4100.00, 500.00, 0.1389, 0.1000, 'OVER', '上海卫星工程研究所', 'PUSHED', '2026-05-17 02:00:00', 'ALL', 'OPEN', '外网测试全部推送', 'cost_seed', 'cost_seed', @cost_tenant_id),
(6004, 1007, 3020, 'WORK_ORDER', '光学监测载荷工作令超支预警', 2400.00, 2790.00, 390.00, 0.1625, 0.1000, 'OVER', '上海航天计算机技术研究所', 'FAILED', NULL, 'ALL', 'OPEN', '外网测试失败样本', 'cost_seed', 'cost_seed', @cost_tenant_id),
(6005, 1007, 3021, 'WORK_ORDER', '数据处理软件工作令关注预警', 1600.00, 1720.00, 120.00, 0.0750, 0.1000, 'NORMAL', '上海神添实业有限公司', 'NOT_PUSHED', NULL, 'ALL', 'OPEN', '低于阈值样本，用于筛选测试', 'cost_seed', 'cost_seed', @cost_tenant_id),
(6006, 1001, NULL, 'PROJECT', 'CZ-8A 批产改进项目汇总关注预警', 22290.00, 22980.00, 690.00, 0.0309, 0.1000, 'NORMAL', '上海航天技术研究院', 'NOT_PUSHED', NULL, 'ALL', 'OPEN', '项目级汇总样本', 'cost_seed', 'cost_seed', @cost_tenant_id);

