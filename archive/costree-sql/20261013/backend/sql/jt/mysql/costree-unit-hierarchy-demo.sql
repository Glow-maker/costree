-- 成本树管理单位层级演示数据（MySQL 8）
-- 前置：新库执行最新版 costree-cost.sql；旧库执行 costree-cost-20260721-add-manage-unit-group.sql。
-- 固定租户：124。脚本只清理并重建 ZY-2026-DEMO-UNIT-001，可重复执行。

DROP TEMPORARY TABLE IF EXISTS `tmp_cost_demo_unit_dict`;
CREATE TEMPORARY TABLE `tmp_cost_demo_unit_dict` (
  `accounting_unit_id` varchar(128), `accounting_unit_code` varchar(128), `accounting_unit_name` varchar(255),
  `manage_unit_code` varchar(128), `manage_unit_name` varchar(255), `manage_unit_group` varchar(32),
  `inside_institute` bit(1)
);

INSERT INTO `tmp_cost_demo_unit_dict` VALUES
('DEMO-ACCT-001', 'DEMO-001', '上海航天技术研究院', '8001', '院部', 'HEAD_OFFICE', b'1'),
('DEMO-ACCT-002', 'DEMO-002', '上海航天精密机械研究所', '0800', '800所', 'ASSEMBLY', b'1'),
('DEMO-ACCT-003', 'DEMO-003', '上海航天设备制造总厂有限公司', '0149', '149厂', 'ASSEMBLY', b'1'),
('DEMO-ACCT-004', 'DEMO-004', '上海卫星装备研究所', '0812', '812所', 'ASSEMBLY', b'1'),
('DEMO-ACCT-005', 'DEMO-005', '上海航天电子通讯设备研究所', '0804', '电子所', 'PROFESSIONAL', b'1'),
('DEMO-ACCT-006', 'DEMO-006', '上海神舟新能源发展有限公司', '0804', '电子所', 'PROFESSIONAL', b'1'),
('DEMO-ACCT-007', 'DEMO-007', '上海航天计算机技术研究所', '0804', '电子所', 'PROFESSIONAL', b'1'),
('DEMO-ACCT-008', 'DEMO-008', '上海航天动力技术研究所', '0806', '动力所', 'PROFESSIONAL', b'1'),
('DEMO-ACCT-009', 'DEMO-009', '上海航天精密仪器研究所', '0811', '811所', 'PROFESSIONAL', b'1'),
('DEMO-ACCT-010', 'DEMO-010', '上海无线电设备研究所', '0802', '802所', 'PROFESSIONAL', b'1'),
('DEMO-ACCT-011', 'DEMO-011', '上海航天控制技术研究所', '0803', '803所', 'PROFESSIONAL', b'1'),
('DEMO-ACCT-012', 'DEMO-012', '上海航天基础技术研究所', 'BASE', '基础所', 'FOUNDATION', b'1'),
('DEMO-ACCT-014', 'DEMO-014', '上海航天第八研究部', '0008', '八部', 'OVERALL', b'1'),
('DEMO-ACCT-015', 'DEMO-015', '上海卫星工程研究所', '0509', '509所', 'OVERALL', b'1'),
('DEMO-ACCT-013', 'DEMO-013', '单位层级演示院外协作单位', 'EXT', '院外单位', 'OUTER', b'0');

UPDATE `cost_unit_dict` d
JOIN `tmp_cost_demo_unit_dict` s ON s.`accounting_unit_name` = d.`accounting_unit_name`
SET d.`manage_unit_code` = s.`manage_unit_code`, d.`manage_unit_name` = s.`manage_unit_name`,
    d.`manage_unit_group` = s.`manage_unit_group`, d.`inside_institute` = s.`inside_institute`,
    d.`inside_group` = s.`inside_institute`, d.`status` = 'ENABLE',
    d.`updater` = 'cost_demo', d.`update_time` = CURRENT_TIMESTAMP
WHERE d.`tenant_id` = 124 AND d.`deleted` = b'0';

INSERT INTO `cost_unit_dict` (
  `accounting_unit_id`, `accounting_unit_code`, `accounting_unit_name`, `manage_unit_code`, `manage_unit_name`,
  `manage_unit_group`, `contact_unit_code`, `contact_unit_name`, `inside_group`, `inside_institute`,
  `status`, `remark`, `creator`, `updater`, `deleted`, `tenant_id`
)
SELECT s.`accounting_unit_id`, s.`accounting_unit_code`, s.`accounting_unit_name`, s.`manage_unit_code`, s.`manage_unit_name`,
       s.`manage_unit_group`,
       IF(s.`inside_institute` = b'1', NULL, s.`accounting_unit_code`),
       IF(s.`inside_institute` = b'1', NULL, s.`accounting_unit_name`),
       s.`inside_institute`, s.`inside_institute`, 'ENABLE', '管理单位层级演示单位',
       'cost_demo', 'cost_demo', b'0', 124
FROM `tmp_cost_demo_unit_dict` s
WHERE NOT EXISTS (
  SELECT 1 FROM `cost_unit_dict` d
  WHERE d.`tenant_id` = 124 AND d.`deleted` = b'0' AND d.`accounting_unit_name` = s.`accounting_unit_name`
);

DELETE FROM `cost_warning_record`
WHERE `tenant_id` = 124
  AND (
    `project_id` IN (
      SELECT `id`
      FROM `cost_project`
      WHERE `tenant_id` = 124 AND `project_code` = 'ZY-2026-DEMO-UNIT-001'
    )
    OR `work_order_id` IN (
      SELECT `id`
      FROM `cost_work_order`
      WHERE `tenant_id` = 124 AND `project_code` = 'ZY-2026-DEMO-UNIT-001'
    )
  );
DELETE FROM `cost_work_order_ledger_detail` WHERE `tenant_id` = 124 AND `project_code` = 'ZY-2026-DEMO-UNIT-001';
DELETE FROM `cost_work_order` WHERE `tenant_id` = 124 AND `project_code` = 'ZY-2026-DEMO-UNIT-001';
DELETE FROM `cost_unit_cost_detail` WHERE `tenant_id` = 124 AND `project_code` = 'ZY-2026-DEMO-UNIT-001';
DELETE FROM `cost_project_basic` WHERE `tenant_id` = 124 AND `project_code` = 'ZY-2026-DEMO-UNIT-001';
DELETE FROM `cost_project` WHERE `tenant_id` = 124 AND `project_code` = 'ZY-2026-DEMO-UNIT-001';
DELETE FROM `cost_model_node` WHERE `tenant_id` = 124 AND `node_code` = 'MODEL_DEMO_UNIT_HIERARCHY';

INSERT INTO `cost_model_node` (`parent_id`, `node_code`, `node_name`, `node_type`, `domain_code`, `sort`, `status`, `remark`, `creator`, `updater`, `deleted`, `tenant_id`)
SELECT 0, 'DOMAIN_DEMO', '演示领域', 'DOMAIN', 'DEMO', 990, 'ENABLE', '单位层级专项演示', 'cost_demo', 'cost_demo', b'0', 124
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM `cost_model_node` WHERE `tenant_id` = 124 AND `deleted` = b'0' AND `node_code` = 'DOMAIN_DEMO');

INSERT INTO `cost_model_node` (`parent_id`, `node_code`, `node_name`, `node_type`, `domain_code`, `sort`, `status`, `remark`, `creator`, `updater`, `deleted`, `tenant_id`)
SELECT (SELECT MIN(`id`) FROM `cost_model_node` WHERE `tenant_id` = 124 AND `deleted` = b'0' AND `node_code` = 'DOMAIN_DEMO'),
       'SERIES_DEMO_UNIT', '单位层级演示系列', 'SERIES', 'DEMO', 10, 'ENABLE', '单位层级专项演示',
       'cost_demo', 'cost_demo', b'0', 124
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM `cost_model_node` WHERE `tenant_id` = 124 AND `deleted` = b'0' AND `node_code` = 'SERIES_DEMO_UNIT');

INSERT INTO `cost_model_node` (`parent_id`, `node_code`, `node_name`, `node_type`, `domain_code`, `sort`, `status`, `remark`, `creator`, `updater`, `deleted`, `tenant_id`)
SELECT (SELECT MIN(`id`) FROM `cost_model_node` WHERE `tenant_id` = 124 AND `deleted` = b'0' AND `node_code` = 'SERIES_DEMO_UNIT'),
       'MODEL_DEMO_UNIT_HIERARCHY', '单位层级完整演示型号', 'MODEL', 'DEMO', 10, 'ENABLE',
       '覆盖总体所、总装所、专业所、基础所和院外单位', 'cost_demo', 'cost_demo', b'0', 124;

INSERT INTO `cost_project` (
  `project_code`, `project_name`, `model_node_id`, `domain_code`, `domain_name`, `category_code`, `category_name`,
  `model_code`, `model_name`, `batch_no`, `stage_codes`, `unit_name`, `unit_type`,
  `project_office_status`, `unit_fill_status`, `audit_status`, `remark`, `creator`, `updater`, `deleted`, `tenant_id`
)
VALUES (
  'ZY-2026-DEMO-UNIT-001', '单位层级完整演示项目',
  (SELECT MIN(`id`) FROM `cost_model_node` WHERE `tenant_id` = 124 AND `deleted` = b'0' AND `node_code` = 'MODEL_DEMO_UNIT_HIERARCHY'),
  'DEMO', '演示领域', 'SERIES_DEMO_UNIT', '单位层级演示系列', 'MODEL_DEMO_UNIT_HIERARCHY',
  '单位层级完整演示型号', 'DEMO-01', 'M,C,Z', '院部', '院内单位',
  'FILLED', 'FILLED', 'SUBMITTED', '管理单位分组专项演示项目', 'cost_demo', 'cost_demo', b'0', 124
);

DROP TEMPORARY TABLE IF EXISTS `tmp_cost_demo_amount`;
CREATE TEMPORARY TABLE `tmp_cost_demo_amount` (
  `accounting_unit_name` varchar(255), `manage_unit_name` varchar(255), `inside_institute` bit(1),
  `work_order_no` varchar(128), `work_order_name` varchar(255),
  `contract_amount` decimal(18,2), `income_amount` decimal(18,2), `target_amount` decimal(18,2),
  `approved_amount` decimal(18,2), `book_amount` decimal(18,2),
  `subject_code` varchar(32), `subject_name` varchar(255)
);

INSERT INTO `tmp_cost_demo_amount` VALUES
('上海航天技术研究院', '院部', b'1', 'DEMO-WO-01', '院部总体工作令', 1500, 1200, 1000, 950, 900, '501101', '职工薪酬及劳务费'),
('上海航天精密机械研究所', '800所', b'1', 'DEMO-WO-02', '总装一工作令', 1800, 1400, 1100, 1200, 1200, '501102', '材料费'),
('上海航天设备制造总厂有限公司', '149厂', b'1', 'DEMO-WO-03', '总装二工作令', 1900, 1500, 1200, 1400, 1500, '501103', '专用费'),
('上海卫星装备研究所', '812所', b'1', 'DEMO-WO-04', '总装三工作令', 1700, 1300, 1050, 1000, 980, '501104', '外协费'),
('上海航天电子通讯设备研究所', '电子所', b'1', 'DEMO-WO-05', '电子分系统工作令一', 1200, 900, 700, 650, 680, '501105', '燃料动力费'),
('上海神舟新能源发展有限公司', '电子所', b'1', 'DEMO-WO-06', '电子分系统工作令二', 1000, 760, 600, 590, 610, '501106', '事务费'),
('上海航天计算机技术研究所', '电子所', b'1', 'DEMO-WO-07', '电子分系统工作令三', 1100, 850, 650, 630, 620, '501107', '固定资产折旧费'),
('上海航天动力技术研究所', '动力所', b'1', 'DEMO-WO-08', '动力分系统工作令', 1500, 1100, 900, 880, 870, '501108', '管理费'),
('上海航天精密仪器研究所', '811所', b'1', 'DEMO-WO-09', '仪器分系统工作令', 1450, 1080, 850, 820, 810, '501101', '职工薪酬及劳务费'),
('上海无线电设备研究所', '802所', b'1', 'DEMO-WO-10', '无线电分系统工作令', 1600, 1200, 950, 900, 940, '501102', '材料费'),
('上海航天控制技术研究所', '803所', b'1', 'DEMO-WO-11', '控制分系统工作令', 1550, 1180, 920, 910, 930, '501104', '外协费'),
('上海航天基础技术研究所', '基础所', b'1', 'DEMO-WO-12', '基础保障工作令', 1300, 1000, 800, 780, 760, '501103', '专用费'),
('上海航天第八研究部', '八部', b'1', 'DEMO-WO-13', '总体八部工作令', 1400, 1050, 900, 880, 850, '501101', '职工薪酬及劳务费'),
('上海卫星工程研究所', '509所', b'1', 'DEMO-WO-14', '总体509所工作令', 1350, 1000, 850, 830, 820, '501102', '材料费'),
('单位层级演示院外协作单位', '院外单位', b'0', NULL, NULL, 1000, 700, 800, 760, 0, NULL, NULL);

INSERT INTO `cost_unit_cost_detail` (
  `project_id`, `project_code`, `project_name`, `domain_code`, `domain_name`, `model_node_id`, `model_code`, `model_name`,
  `unit_id`, `unit_name`, `stage_code`, `source_record_id`, `source_update_time`,
  `contract_amount`, `income_amount`, `target_cost_amount`, `book_cost_amount`, `approved_amount`,
  `salary_amount`, `material_amount`, `outsource_amount`, `manage_amount`, `fuel_power_amount`, `other_amount`,
  `remark`, `creator`, `updater`, `deleted`, `tenant_id`
)
SELECT p.`id`, p.`project_code`, p.`project_name`, p.`domain_code`, p.`domain_name`, p.`model_node_id`, p.`model_code`, p.`model_name`,
       (SELECT MIN(d.`unit_id`) FROM `cost_unit_dict` d WHERE d.`tenant_id` = 124 AND d.`deleted` = b'0' AND d.`accounting_unit_name` = a.`accounting_unit_name`),
       a.`accounting_unit_name`, 'ALL', CONCAT('DEMO-UNIT-', COALESCE(a.`work_order_no`, 'OUTER')), CURRENT_TIMESTAMP,
       a.`contract_amount`, a.`income_amount`, a.`target_amount`, 0, a.`approved_amount`,
       0, 0, 0, 0, 0, 0, '管理单位层级演示金额', 'cost_demo', 'cost_demo', b'0', 124
FROM `tmp_cost_demo_amount` a
JOIN `cost_project` p ON p.`tenant_id` = 124 AND p.`deleted` = b'0'
  AND p.`project_code` = 'ZY-2026-DEMO-UNIT-001';

INSERT INTO `cost_work_order` (
  `source_work_order_id`, `project_id`, `project_code`, `project_name`, `unit_id`, `unit_name`,
  `accounting_unit_code`, `accounting_unit_name`, `fiscal_year`, `work_order_no`, `work_order_name`,
  `book_cost_amount`, `stage_codes`, `max_stage_code`, `subsystem_name`, `product_short_name`,
  `quantity`, `vertical_division`, `disabled`, `approved_amount`, `status`, `remark`,
  `creator`, `updater`, `deleted`, `tenant_id`
)
SELECT CONCAT('SRC-', a.`work_order_no`), p.`id`, p.`project_code`, p.`project_name`,
       (SELECT MIN(d.`unit_id`) FROM `cost_unit_dict` d WHERE d.`tenant_id` = 124 AND d.`deleted` = b'0' AND d.`accounting_unit_name` = a.`accounting_unit_name`),
       a.`accounting_unit_name`,
       (SELECT MIN(d.`accounting_unit_code`) FROM `cost_unit_dict` d WHERE d.`tenant_id` = 124 AND d.`deleted` = b'0' AND d.`accounting_unit_name` = a.`accounting_unit_name`),
       a.`accounting_unit_name`, '', a.`work_order_no`, a.`work_order_name`,
       a.`book_amount`, 'M,C,Z', 'Z', CONCAT(a.`manage_unit_name`, '分系统'), a.`manage_unit_name`,
       1, b'0', b'0', a.`approved_amount`, 'SUBMITTED', '管理单位层级演示工作令',
       'cost_demo', 'cost_demo', b'0', 124
FROM `tmp_cost_demo_amount` a
JOIN `cost_project` p ON p.`tenant_id` = 124 AND p.`deleted` = b'0'
  AND p.`project_code` = 'ZY-2026-DEMO-UNIT-001'
WHERE a.`inside_institute` = b'1';

INSERT INTO `cost_work_order_ledger_detail` (
  `source_detail_id`, `fiscal_year`, `accounting_period`, `voucher_date`, `voucher_no`,
  `accounting_unit_id`, `accounting_unit_code`, `accounting_unit_name`, `manage_unit_name`,
  `subject_id`, `subject_code`, `subject_name`, `project_code`, `source_project_id`, `project_name`,
  `source_work_order_id`, `work_order_no`, `work_order_name`, `debit_credit`, `amount`, `amount_wan`,
  `summary_text`, `source_lastmodify`, `second_subject_code`, `second_subject_name`, `source_timestamp`,
  `resolved_stage_code`, `project_id`, `work_order_id`, `remark`, `creator`, `updater`, `deleted`, `tenant_id`
)
SELECT CONCAT('DEMO-LEDGER-', a.`work_order_no`), '2026', '12', '2026-12-31', CONCAT('DEMO-', a.`work_order_no`),
       (SELECT MIN(d.`accounting_unit_id`) FROM `cost_unit_dict` d WHERE d.`tenant_id` = 124 AND d.`deleted` = b'0' AND d.`accounting_unit_name` = a.`accounting_unit_name`),
       (SELECT MIN(d.`accounting_unit_code`) FROM `cost_unit_dict` d WHERE d.`tenant_id` = 124 AND d.`deleted` = b'0' AND d.`accounting_unit_name` = a.`accounting_unit_name`),
       a.`accounting_unit_name`, a.`manage_unit_name`, a.`subject_code`, a.`subject_code`, a.`subject_name`,
       p.`project_code`, 'DEMO-PROJECT-001', p.`project_name`, CONCAT('SRC-', a.`work_order_no`),
       a.`work_order_no`, a.`work_order_name`, '借', a.`book_amount` * 10000, a.`book_amount`,
       '管理单位层级演示借方账面', CURRENT_TIMESTAMP, a.`subject_code`, a.`subject_name`,
       '20261231000000', 'Z', p.`id`,
       (SELECT MIN(w.`id`) FROM `cost_work_order` w WHERE w.`tenant_id` = 124 AND w.`deleted` = b'0'
        AND w.`project_code` = p.`project_code` AND w.`unit_name` = a.`accounting_unit_name`
        AND w.`work_order_no` = a.`work_order_no`),
       '管理单位层级演示账面明细', 'cost_demo', 'cost_demo', b'0', 124
FROM `tmp_cost_demo_amount` a
JOIN `cost_project` p ON p.`tenant_id` = 124 AND p.`deleted` = b'0'
  AND p.`project_code` = 'ZY-2026-DEMO-UNIT-001'
WHERE a.`inside_institute` = b'1';

-- 预期：14 个院内核算单位、12 个院内管理单位、1 个院外单位金额行。
SELECT SUM(IF(d.`inside_institute` = b'1', 1, 0)) AS `internal_accounting_units`,
       COUNT(DISTINCT IF(d.`inside_institute` = b'1', d.`manage_unit_name`, NULL)) AS `internal_manage_units`,
       SUM(IF(d.`inside_institute` = b'0', 1, 0)) AS `outer_units`
FROM `cost_unit_cost_detail` c
JOIN `cost_unit_dict` d ON d.`tenant_id` = c.`tenant_id` AND d.`deleted` = b'0' AND d.`accounting_unit_name` = c.`unit_name`
WHERE c.`tenant_id` = 124 AND c.`deleted` = b'0' AND c.`project_code` = 'ZY-2026-DEMO-UNIT-001';

SELECT d.`manage_unit_name`, SUM(c.`target_cost_amount`) AS `target_amount`,
       SUM(w.`book_cost_amount`) AS `book_amount`, SUM(c.`approved_amount`) AS `approved_amount`
FROM `cost_unit_cost_detail` c
JOIN `cost_unit_dict` d ON d.`tenant_id` = c.`tenant_id` AND d.`deleted` = b'0' AND d.`accounting_unit_name` = c.`unit_name`
LEFT JOIN `cost_work_order` w ON w.`tenant_id` = c.`tenant_id` AND w.`deleted` = b'0'
  AND w.`project_code` = c.`project_code` AND w.`unit_name` = c.`unit_name`
WHERE c.`tenant_id` = 124 AND c.`deleted` = b'0' AND c.`project_code` = 'ZY-2026-DEMO-UNIT-001'
  AND d.`manage_unit_name` = '电子所'
GROUP BY d.`manage_unit_name`;

DROP TEMPORARY TABLE IF EXISTS `tmp_cost_demo_amount`;
DROP TEMPORARY TABLE IF EXISTS `tmp_cost_demo_unit_dict`;
