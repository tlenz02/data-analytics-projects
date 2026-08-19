-- ============================================================
-- Анализ продаж билетов сервиса Яндекс Афиша
-- SQL-часть проекта для портфолио
-- ============================================================

-- 1. Общие ключевые показатели сервиса по валютам
SELECT
    currency_code,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    AVG(revenue) AS avg_revenue_per_order,
    COUNT(DISTINCT user_id) AS total_users
FROM afisha.purchases
GROUP BY currency_code
ORDER BY total_revenue DESC;

-- 2. Распределение выручки и заказов по типам устройств
-- Только заказы в рублях
SELECT
    device_type_canonical,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    AVG(revenue) AS avg_revenue_per_order,
    ROUND(
        SUM(revenue)::numeric
        / SUM(SUM(revenue)) OVER ()::numeric,
        3
    ) AS revenue_share
FROM afisha.purchases
WHERE currency_code = 'rub'
GROUP BY device_type_canonical
ORDER BY revenue_share DESC;

-- 3. Распределение выручки и заказов по типам мероприятий
-- Только заказы в рублях
SELECT
    event_type_main,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    AVG(revenue) AS avg_revenue_per_order,
    COUNT(DISTINCT event_name_code) AS total_event_name,
    AVG(tickets_count) AS avg_tickets,
    SUM(revenue) / SUM(tickets_count) AS avg_ticket_revenue,
    ROUND(
        SUM(revenue)::numeric
        / SUM(SUM(revenue)) OVER ()::numeric,
        3
    ) AS revenue_share
FROM afisha.purchases
JOIN afisha.events USING (event_id)
WHERE currency_code = 'rub'
GROUP BY event_type_main
ORDER BY total_orders DESC;

-- 4. Недельная динамика ключевых показателей
-- Только заказы в рублях
SELECT
    DATE_TRUNC('week', created_dt_msk)::date AS week,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    COUNT(DISTINCT user_id) AS total_users,
    SUM(revenue) / COUNT(order_id) AS revenue_per_order
FROM afisha.purchases
WHERE currency_code = 'rub'
GROUP BY week
ORDER BY week;

-- 5. Топ-7 регионов по общей выручке
-- Только заказы в рублях
SELECT
    region_name,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    COUNT(DISTINCT user_id) AS total_users,
    SUM(tickets_count) AS total_tickets,
    SUM(revenue) / SUM(tickets_count) AS one_ticket_cost
FROM afisha.purchases
JOIN afisha.events USING (event_id)
JOIN afisha.city USING (city_id)
JOIN afisha.regions USING (region_id)
WHERE currency_code = 'rub'
GROUP BY region_name
ORDER BY total_revenue DESC
LIMIT 7;
