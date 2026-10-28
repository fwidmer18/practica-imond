
-- ============================================================
-- 04_marts.sql
-- Marts de negocio para el dashboard
-- EcoBottle AR
-- Motor SQL: DuckDB
-- ============================================================


-- ------------------------------------------------------------
-- 1. Clasificacion de respuestas NPS
-- Equivalente a la columna calculada Categoria NPS
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW mart_nps_responses AS
SELECT
    n.nps_id,
    n.customer_key,
    n.channel_key,
    n.score,
    n.date_key,
    d.date_actual AS fecha,
    CASE
        WHEN n.score >= 9 THEN 'Promotor'
        WHEN n.score >= 7 THEN 'Neutro'
        WHEN n.score >= 0 THEN 'Detractor'
        ELSE 'Sin clasificar'
    END AS categoria_nps
FROM fact_nps AS n
LEFT JOIN dim_date AS d
    ON n.date_key = d.date_key;


-- ------------------------------------------------------------
-- 2. NPS agregado
-- Equivalente a la medida Puntos NPS
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW mart_nps AS
SELECT
    d.date_actual AS fecha,
    n.channel_key,
    ROUND(
        100.0 * (
            SUM(CASE WHEN n.score >= 9 THEN 1 ELSE 0 END)
            - SUM(CASE WHEN n.score <= 6 THEN 1 ELSE 0 END)
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS puntos_nps,
    COUNT(*) AS total_respuestas,
    SUM(CASE WHEN n.score >= 9 THEN 1 ELSE 0 END)
        AS cantidad_promotores,
    SUM(CASE WHEN n.score BETWEEN 7 AND 8 THEN 1 ELSE 0 END)
        AS cantidad_neutros,
    SUM(CASE WHEN n.score <= 6 THEN 1 ELSE 0 END)
        AS cantidad_detractores
FROM fact_nps AS n
JOIN dim_date AS d
    ON n.date_key = d.date_key
GROUP BY
    d.date_actual,
    n.channel_key;


-- ------------------------------------------------------------
-- 3. Ventas totales
-- Equivalente a la medida Total Ventas
-- Solo pedidos PAID y FULFILLED
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW mart_ventas AS
SELECT
    so.order_id,
    so.date_key,
    d.date_actual AS fecha,
    d.year,
    d.month,
    so.customer_key,
    so.channel_key,
    so.store_key,
    so.shipping_geography_key,
    g.province_name AS provincia,
    so.status,
    so.subtotal,
    so.tax_amount,
    so.shipping_fee,
    so.total_amount
FROM fact_sales_order AS so
LEFT JOIN dim_date AS d
    ON so.date_key = d.date_key
LEFT JOIN dim_geography AS g
    ON so.shipping_geography_key = g.geography_key
WHERE so.status IN ('PAID', 'FULFILLED');


-- ------------------------------------------------------------
-- 4. Ticket promedio
-- Total vendido / cantidad de pedidos validos
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW mart_ticket_promedio AS
SELECT
    COUNT(DISTINCT order_id) AS cantidad_pedidos,
    COALESCE(SUM(total_amount), 0) AS total_ventas,
    COALESCE(
        SUM(total_amount) / NULLIF(COUNT(DISTINCT order_id), 0),
        0
    ) AS ticket_promedio
FROM fact_sales_order
WHERE status IN ('PAID', 'FULFILLED');


-- ------------------------------------------------------------
-- 5. Ventas por producto
-- Para analizar ventas y ranking mensual de productos
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW mart_ventas_producto AS
SELECT
    d.date_actual AS fecha,
    d.year,
    d.month,
    d.month_name,
    so.channel_key,
    si.product_key,
    p.name AS producto,
    p.category AS categoria,
    SUM(si.quantity) AS unidades_vendidas,
    SUM(si.line_total) AS ventas_producto
FROM fact_sales_item AS si
JOIN fact_sales_order AS so
    ON si.order_id = so.order_id
JOIN dim_date AS d
    ON so.date_key = d.date_key
JOIN dim_product AS p
    ON si.product_key = p.product_key
WHERE so.status IN ('PAID', 'FULFILLED')
GROUP BY
    d.date_actual,
    d.year,
    d.month,
    d.month_name,
    so.channel_key,
    si.product_key,
    p.name,
    p.category;


-- ------------------------------------------------------------
-- 6. Usuarios activos
-- Clientes identificados + sesiones anonimas
-- customer_key = -1 representa un usuario anonimo
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW mart_usuarios_activos AS
SELECT
    d.date_actual AS fecha,
    COUNT(DISTINCT CASE
        WHEN ws.customer_key <> -1 THEN ws.customer_key
    END) AS usuarios_identificados,
    COUNT(DISTINCT CASE
        WHEN ws.customer_key = -1 THEN ws.session_id
    END) AS sesiones_anonimas,
    COUNT(DISTINCT CASE
        WHEN ws.customer_key <> -1 THEN ws.customer_key
    END)
    +
    COUNT(DISTINCT CASE
        WHEN ws.customer_key = -1 THEN ws.session_id
    END) AS usuarios_activos
FROM fact_web_session AS ws
JOIN dim_date AS d
    ON ws.date_key = d.date_key
GROUP BY
    d.date_actual;

    CREATE OR REPLACE VIEW mart_nps_promedio AS
SELECT
    ROUND(AVG(puntos_nps), 2) AS puntos_nps_promedio
FROM mart_nps;

SELECT * FROM mart_nps LIMIT 10;

SELECT * FROM mart_ventas LIMIT 10;

SELECT * FROM mart_ticket_promedio;

SELECT * FROM mart_ventas_producto LIMIT 10;

SELECT * FROM mart_usuarios_activos LIMIT 10;

COPY mart_ventas
TO 'dw/mart_ventas.csv'
(HEADER, DELIMITER ',');

COPY mart_ticket_promedio
TO 'dw/mart_ticket_promedio.csv'
(HEADER, DELIMITER ',');

COPY mart_nps
TO 'dw/mart_nps.csv'
(HEADER, DELIMITER ',');

COPY mart_nps_responses
TO 'dw/mart_nps_responses.csv'
(HEADER, DELIMITER ',');

COPY mart_ventas_producto
TO 'dw/mart_ventas_producto.csv'
(HEADER, DELIMITER ',');

COPY mart_usuarios_activos
TO 'dw/mart_usuarios_activos.csv'
(HEADER, DELIMITER ',');

COPY mart_nps_promedio
TO 'dw/mart_nps_promedio.csv'
(HEADER, DELIMITER ',');