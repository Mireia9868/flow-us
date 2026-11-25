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
SELECT days.day, coalesce(daily.dau, 0) AS pilot_dau
FROM days LEFT JOIN daily USING (day) ORDER BY days.day;

-- 仅纳入已满 24 小时的报名者，以及在观察区间内确实有首条结果的人。
WITH opened AS (
  SELECT visitor_id, min(occurred_at) AS joined
  FROM pilot_events WHERE cohort = 'growth' AND event = 'app_opened' GROUP BY 1
  HAVING min(occurred_at) >= date('now', '-28 days')
), activated AS (
  SELECT o.visitor_id, min(e.occurred_at) AS first_result
  FROM opened o JOIN pilot_events e ON e.visitor_id = o.visitor_id
    AND e.cohort = 'growth' AND e.event = 'task_result_saved'
    AND e.occurred_at >= o.joined AND julianday(e.occurred_at) <= julianday(o.joined) + 1
  GROUP BY 1
), repeat_use AS (
  SELECT a.visitor_id, count(DISTINCT date(e.occurred_at)) AS workdays
  FROM activated a JOIN pilot_events e ON e.visitor_id = a.visitor_id
    AND e.cohort = 'growth' AND e.event IN ('focus_qualified', 'task_result_saved', 'task_completed')
    AND date(e.occurred_at) > date(a.first_result)
    AND date(e.occurred_at) <= date(a.first_result, '+7 days')
    AND strftime('%w', e.occurred_at) BETWEEN '1' AND '5'
  GROUP BY 1
)
SELECT count(*) FILTER (WHERE julianday(o.joined) <= julianday('now') - 1) AS eligible_for_activation,
       count(a.visitor_id) FILTER (WHERE julianday(o.joined) <= julianday('now') - 1) AS activated_in_24h,
       count(a.visitor_id) FILTER (WHERE date(a.first_result, '+7 days') < date('now')) AS eligible_for_reuse,
       count(r.visitor_id) FILTER (WHERE date(a.first_result, '+7 days') < date('now') AND r.workdays >= 2) AS reused_twice
FROM opened o LEFT JOIN activated a USING (visitor_id) LEFT JOIN repeat_use r USING (visitor_id);
