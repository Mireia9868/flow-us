-- 只纳入已结束的 UTC 日期，补齐没有活跃的日期。
WITH RECURSIVE days(day) AS (
  SELECT date('now', '-28 days')
  UNION ALL
  SELECT date(day, '+1 day') FROM days WHERE day < date('now', '-1 day')
), daily AS (
  SELECT date(occurred_at) AS day, count(DISTINCT visitor_id) AS dau
  FROM pilot_events
  WHERE cohort = 'growth' AND event IN ('focus_qualified', 'task_result_saved', 'task_completed')
    AND occurred_at >= date('now', '-28 days') AND occurred_at < date('now')
  GROUP BY 1
)
SELECT days.day,
       coalesce(daily.dau, 0) AS pilot_dau,
       round(avg(coalesce(daily.dau, 0)) OVER (), 2) AS avg_pilot_dau_28d
FROM days LEFT JOIN daily USING (day) ORDER BY days.day;

-- 最近 28 天首次开启试用记录的浏览器。暂停后重新开启仍计入原批次。
WITH opened AS (
  SELECT visitor_id, min(occurred_at) AS joined
  FROM pilot_events WHERE cohort = 'growth' AND event = 'app_opened' GROUP BY 1
  HAVING min(occurred_at) >= date('now', '-28 days')
), first_day AS (
  SELECT o.visitor_id,
         min(CASE WHEN e.event = 'task_created' THEN e.occurred_at END) AS first_task,
         min(CASE WHEN e.event = 'focus_started' THEN e.occurred_at END) AS first_focus,
         min(CASE WHEN e.event = 'task_result_saved' THEN e.occurred_at END) AS first_result
  FROM opened o LEFT JOIN pilot_events e ON e.visitor_id = o.visitor_id
    AND e.cohort = 'growth'
    AND e.event IN ('task_created', 'focus_started', 'task_result_saved')
    AND e.occurred_at >= o.joined AND julianday(e.occurred_at) <= julianday(o.joined) + 1
  GROUP BY 1
), repeat_use AS (
  SELECT a.visitor_id, count(DISTINCT date(e.occurred_at)) AS workdays
  FROM first_day a JOIN pilot_events e ON e.visitor_id = a.visitor_id
    AND e.cohort = 'growth' AND e.event IN ('focus_qualified', 'task_result_saved', 'task_completed')
    AND date(e.occurred_at) > date(a.first_result)
    AND date(e.occurred_at) <= date(a.first_result, '+7 days')
    AND strftime('%w', e.occurred_at) BETWEEN '1' AND '5'
  GROUP BY 1
), totals AS (
  SELECT count(*) AS opted_in,
         count(*) FILTER (WHERE julianday(o.joined) <= julianday('now') - 1) AS eligible_for_activation,
         count(a.first_task) FILTER (WHERE julianday(o.joined) <= julianday('now') - 1) AS created_task_in_24h,
         count(a.first_focus) FILTER (WHERE julianday(o.joined) <= julianday('now') - 1) AS started_focus_in_24h,
         count(a.first_result) FILTER (WHERE julianday(o.joined) <= julianday('now') - 1) AS activated_in_24h,
         count(a.first_result) FILTER (WHERE date(a.first_result, '+7 days') < date('now')) AS eligible_for_reuse,
         count(r.visitor_id) FILTER (WHERE date(a.first_result, '+7 days') < date('now') AND r.workdays >= 2) AS reused_twice
  FROM opened o JOIN first_day a USING (visitor_id) LEFT JOIN repeat_use r USING (visitor_id)
)
SELECT *,
       opted_in - eligible_for_activation AS awaiting_24h,
       round(100.0 * activated_in_24h / nullif(eligible_for_activation, 0), 1) AS activation_pct,
       round(100.0 * reused_twice / nullif(eligible_for_reuse, 0), 1) AS reuse_pct
FROM totals;
