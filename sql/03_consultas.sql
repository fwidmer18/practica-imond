-- =====================================================================
-- 03_consultas.sql — Consultas para revisar el modelo y calcular KPIs
-- =====================================================================
-- Cada SELECT de este archivo se muestra en la terminal al ejecutar
-- run_sql.py. Usalo para:
--   * comprobar que las tablas se cargaron bien (cantidad de filas, nulos...)
--   * escribir las consultas clave de los KPIs que pide la consigna
--     (ventas, usuarios activos, ticket promedio, NPS, ventas por provincia,
--     ranking mensual por producto) usando las tablas del modelo estrella.
-- =====================================================================


-- Ejemplo: revisar la dimensión producto
SELECT product_key, name, category, family, list_price
FROM dim_product
ORDER BY product_key;


-- TU TURNO: agregá acá tus consultas.
-- =====================================================================
-- 1. KPI: Ventas Totales ($M)
-- Regla: SUM(total_amount) de fact_sales_order con status 
-- IN ('PAID', 'FULFILLED')[cite: 5].
-- =====================================================================
SELECT 
    d.year AS anio,
    d.month AS mes,
    c.name AS canal,
    SUM(f.total_amount) AS total_ventas
FROM fact_sales_order AS f
JOIN dim_date AS d ON f.date_key = d.date_key
JOIN dim_channel AS c ON f.channel_key = c.channel_key
WHERE f.status IN ('PAID', 'FULFILLED')
GROUP BY d.year, d.month, c.name
ORDER BY d.year, d.month, c.name;


-- =====================================================================
-- 2. KPI: Usuarios Activos (nK)
-- Regla: COUNT(DISTINCT customer_id) o session_id si son anónimos 
-- en la web_session por período[cite: 5].
-- =====================================================================
SELECT 
    d.year AS anio,
    d.month AS mes,
    COUNT(DISTINCT CASE 
        WHEN f.customer_key != -1 THEN CAST(f.customer_key AS VARCHAR) 
        ELSE CAST(f.session_id AS VARCHAR) 
    END) AS usuarios_activos
FROM fact_web_session AS f
JOIN dim_date AS d ON f.date_key = d.date_key
GROUP BY d.year, d.month
ORDER BY d.year, d.month;
