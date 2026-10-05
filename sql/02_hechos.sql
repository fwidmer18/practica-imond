-- =====================================================================
-- 02_hechos.sql — Tablas de HECHOS del modelo estrella
-- =====================================================================
-- Este archivo se ejecuta después de 01_dimensiones.sql porque los hechos
-- apuntan a las dimensiones con FOREIGN KEY (REFERENCES).
--
-- Para cada tabla de hechos:
--   1. Definí el GRANO: ¿qué representa UNA fila?
--      (ej.: un producto dentro de un pedido, una sesión web, una respuesta NPS)
--   2. CREATE TABLE con:
--        - PRIMARY KEY
--        - una FOREIGN KEY por cada dimensión:  product_key INTEGER REFERENCES dim_product (product_key)
--        - las métricas (cantidades, importes, puntajes...)
--   3. INSERT INTO ... SELECT uniendo las tablas de origen (raw.) con las dimensiones
--      para obtener las claves.
--
-- Patrón para obtener la clave de una dimensión:
--
--   SELECT i.order_item_id, p.product_key, i.quantity, i.line_total
--   FROM raw.sales_order_item AS i
--   JOIN dim_product AS p ON p.product_id = i.product_id
--
-- Si una FOREIGN KEY apunta a una clave que no existe en la dimensión,
-- DuckDB rechaza la carga y run_sql.py te muestra el error.
-- =====================================================================


-- TU TURNO: creá acá las tablas de hechos.

-- =====================================================================
-- 1. HECHOS: VENTAS (CABECERA)
-- Grano: Un registro por cada pedido (sales_order).
-- Uso: Ventas Totales, Ticket Promedio y Ventas por Provincia.
-- =====================================================================

CREATE TABLE fact_sales_order (
    order_id BIGINT PRIMARY KEY,
    date_key INTEGER REFERENCES dim_date (date_key),
    customer_key INTEGER REFERENCES dim_customer (customer_key),
    channel_key INTEGER REFERENCES dim_channel (channel_key),
    store_key INTEGER REFERENCES dim_store (store_key),
    shipping_geography_key INTEGER REFERENCES dim_geography (geography_key),
    status VARCHAR,
    subtotal DECIMAL(12,2),
    tax_amount DECIMAL(12,2),
    shipping_fee DECIMAL(12,2),
    total_amount DECIMAL(12,2)
);

INSERT INTO fact_sales_order
SELECT 
    o.order_id,
    CAST(strftime(o.order_date, '%Y%m%d') AS INTEGER) AS date_key,
    COALESCE(c.customer_key, -1) AS customer_key, 
    ch.channel_key,
    COALESCE(s.store_key, -1) AS store_key, -- Si es ONLINE, va el -1 (No aplica)
    COALESCE(g.geography_key, -1) AS shipping_geography_key,
    o.status,
    o.subtotal,
    o.tax_amount,
    o.shipping_fee,
    o.total_amount
FROM raw.sales_order AS o
LEFT JOIN dim_customer AS c ON o.customer_id = c.customer_id
LEFT JOIN dim_channel AS ch ON o.channel_id = ch.channel_id
LEFT JOIN dim_store AS s ON o.store_id = s.store_id
LEFT JOIN dim_geography AS g ON o.shipping_address_id = g.address_id;