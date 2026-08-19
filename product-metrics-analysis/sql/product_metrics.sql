-- ============================================================
-- Ключевые бизнес-метрики сервиса доставки в Саранске
-- Период: май — июнь 2021
-- ============================================================

-- 1. DAU: количество уникальных активных пользователей за день
SELECT
    log_date,
    COUNT(DISTINCT user_id) AS dau
FROM analytics_events
JOIN cities USING (city_id)
WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
  AND event = 'order'
  AND city_name = 'Саранск'
GROUP BY log_date
ORDER BY log_date;

-- 2. Conversion Rate: доля пользователей, совершивших заказ
SELECT
    log_date,
    ROUND(
        COUNT(DISTINCT user_id) FILTER (WHERE event = 'order')
        / COUNT(DISTINCT user_id)::numeric,
        2
    ) AS conversion_rate
FROM analytics_events
JOIN cities USING (city_id)
WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
  AND city_name = 'Саранск'
GROUP BY log_date
ORDER BY log_date;

-- 3. Средний чек по месяцам
WITH orders AS (
    SELECT
        *,
        revenue * commission AS commission_revenue
    FROM analytics_events
    JOIN cities
        ON analytics_events.city_id = cities.city_id
    WHERE revenue IS NOT NULL
      AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
      AND city_name = 'Саранск'
)
SELECT
    DATE_TRUNC('month', log_date)::date AS month,
    COUNT(DISTINCT order_id) FILTER (WHERE event = 'order') AS total_orders,
    ROUND(SUM(commission_revenue)::numeric, 2) AS commission_revenue,
    ROUND(
        SUM(commission_revenue)::numeric
        / COUNT(DISTINCT order_id) FILTER (WHERE event = 'order'),
        2
    ) AS avg_check
FROM orders
GROUP BY month
ORDER BY month;

-- 4. Топ-3 ресторанов по LTV за период
WITH orders AS (
    SELECT
        analytics_events.rest_id,
        analytics_events.city_id,
        revenue * commission AS commission_revenue
    FROM analytics_events
    JOIN cities
        ON analytics_events.city_id = cities.city_id
    WHERE revenue IS NOT NULL
      AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
      AND city_name = 'Саранск'
)
SELECT
    orders.rest_id,
    chain AS restaurant_chain,
    type AS cuisine_type,
    ROUND(SUM(commission_revenue)::numeric, 2) AS ltv
FROM orders
JOIN partners
    ON orders.rest_id = partners.rest_id
   AND orders.city_id = partners.city_id
GROUP BY orders.rest_id, chain, type
ORDER BY ltv DESC
LIMIT 3;

-- 5. Топ-5 блюд по LTV среди двух ресторанов-лидеров
WITH orders AS (
    SELECT
        events.rest_id,
        events.city_id,
        events.object_id,
        revenue * commission AS commission_revenue
    FROM analytics_events AS events
    JOIN cities
        ON events.city_id = cities.city_id
    WHERE revenue IS NOT NULL
      AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
      AND city_name = 'Саранск'
),
top_ltv_restaurants AS (
    SELECT
        orders.rest_id,
        chain,
        type,
        ROUND(SUM(commission_revenue)::numeric, 2) AS ltv
    FROM orders
    JOIN partners
        ON orders.rest_id = partners.rest_id
       AND orders.city_id = partners.city_id
    GROUP BY orders.rest_id, chain, type
    ORDER BY ltv DESC
    LIMIT 2
)
SELECT
    chain AS restaurant_chain,
    dishes.name AS dish_name,
    spicy,
    fish,
    meat,
    ROUND(SUM(orders.commission_revenue)::numeric, 2) AS ltv
FROM orders
JOIN top_ltv_restaurants
    ON orders.rest_id = top_ltv_restaurants.rest_id
JOIN dishes
    ON orders.object_id = dishes.object_id
   AND top_ltv_restaurants.rest_id = dishes.rest_id
GROUP BY chain, dishes.name, spicy, fish, meat
ORDER BY ltv DESC
LIMIT 5;

-- 6. Retention Rate в первую неделю после первого посещения
WITH new_users AS (
    SELECT DISTINCT
        first_date,
        user_id
    FROM analytics_events
    JOIN cities
        ON analytics_events.city_id = cities.city_id
    WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
      AND city_name = 'Саранск'
),
active_users AS (
    SELECT DISTINCT
        log_date,
        user_id
    FROM analytics_events
    JOIN cities
        ON analytics_events.city_id = cities.city_id
    WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
      AND city_name = 'Саранск'
)
SELECT
    log_date::date - first_date::date AS day_since_install,
    COUNT(DISTINCT new_users.user_id) AS retained_users,
    ROUND(
        (
            1.0 * COUNT(DISTINCT new_users.user_id)
            / MAX(COUNT(DISTINCT new_users.user_id)) OVER (
                ORDER BY log_date::date - first_date::date
            )
        )::numeric,
        2
    ) AS retention_rate
FROM new_users
JOIN active_users
    ON new_users.user_id = active_users.user_id
WHERE log_date >= first_date
  AND log_date::date - first_date::date < 8
GROUP BY log_date::date - first_date::date
ORDER BY day_since_install;

-- 7. Сравнение Retention Rate когорт мая и июня
WITH new_users AS (
    SELECT DISTINCT
        first_date,
        user_id
    FROM analytics_events
    JOIN cities
        ON analytics_events.city_id = cities.city_id
    WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
      AND city_name = 'Саранск'
),
active_users AS (
    SELECT DISTINCT
        log_date,
        user_id
    FROM analytics_events
    JOIN cities
        ON analytics_events.city_id = cities.city_id
    WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
      AND city_name = 'Саранск'
),
daily_retention AS (
    SELECT
        new_users.user_id,
        first_date,
        log_date::date - first_date::date AS day_since_install
    FROM new_users
    JOIN active_users
        ON new_users.user_id = active_users.user_id
       AND log_date >= first_date
)
SELECT
    DATE_TRUNC('month', first_date)::date AS month,
    day_since_install,
    COUNT(DISTINCT user_id) AS retained_users,
    ROUND(
        (
            1.0 * COUNT(DISTINCT user_id)
            / MAX(COUNT(DISTINCT user_id)) OVER (
                PARTITION BY DATE_TRUNC('month', first_date)::date
                ORDER BY day_since_install
            )
        )::numeric,
        2
    ) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY month, day_since_install
ORDER BY month, day_since_install;
