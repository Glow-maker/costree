-- 唯一可编辑的上游完整性判定区，必须是一条 SELECT，返回恰好一行。
-- 列：snapshot_tag text、is_complete boolean。
-- 请替换为源系统“六个相关数据集均发布完成”的真实批次记录查询。
-- 不能把调度任务开始时间、NOW()、随意写 true 当作上游完成证据。
-- 同一数据库 REPEATABLE READ 保证读取时点一致，不保证上游 ETL 已完成。
-- 默认安全失败；未确认真实发布完成条件前不能投产自动运行。
SELECT 'REPLACE_WITH_SOURCE_PUBLISHED_GENERATION'::text AS snapshot_tag,
       false::boolean AS is_complete;
