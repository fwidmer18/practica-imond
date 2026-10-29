# Trabajo Práctico: Ecosistema de Datos Comercial - EcoBottle AR

Este repositorio contiene la resolución del Trabajo Práctico de Introducción al Marketing Online y los Negocios Digitales. El objetivo principal es diseñar e implementar un mini-ecosistema de datos comercial y construir un modelo para un dashboard de KPIs clave.

## 1. Instrucciones de Ejecución

Para reproducir este entorno de manera local mediante la consola, seguí estos pasos:

1. **Clonar el repositorio:**

   Debés clonar tu fork del repositorio de manera local usando Git.

   ```bash
   git clone https://github.com/fwidmer18/practica-imond.git

   cd practica-imond
   ```

2. **Crear y activar un entorno virtual:**

   La gestión del entorno virtual es una buena práctica requerida.

   ```bash
   python -m venv .venv
   ```

   - En Mac / Linux: `source .venv/bin/activate`.
   - En Windows: `.venv\Scripts\activate`.

   **Nota:** Si Windows arroja un error de políticas, ejecutá primero:

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   ```

3. **Instalar dependencias:**

   Se requiere instalar DuckDB y las demás librerías.

   ```bash
   pip install -r requirements.txt
   ```

4. **Ejecutar el modelo de datos (ETL):**

   El script construye el Data Warehouse procesando los archivos de la carpeta `sql/`. Las tablas transformadas se guardan como archivos `.csv` en el directorio `dw/`.

   ```bash
   python run_sql.py
   ```

## 2. Gestión del Repositorio

Toda la gestión del repositorio se realizó mediante el uso de la consola. Para el control de versiones se adoptó el estándar de **Conventional Commits** (por ejemplo, `feat: add dim_customer table` y `docs: update README instructions`), asegurando buenas prácticas.

## 3. Supuestos del Modelo

Durante la construcción del esquema estrella según el modelado de Kimball, se asumieron las siguientes reglas de negocio para asegurar la integridad de los datos:

- **Integridad referencial (nulos):** Para eventos anónimos o no aplicables (por ejemplo, usuarios no logueados en sesiones web, NPS anónimos o pedidos ONLINE que no tienen una tienda física asignada), se insertó un registro comodín con el valor `-1` en las tablas de dimensiones correspondientes (Cliente, Tienda y Geografía).

- **Cálculo de ingresos:** Para los KPIs monetarios (Ventas Totales, Ticket Promedio y Ventas por Provincia), se consideraron únicamente los pedidos (`sales_order`) cuyo estado (`status`) era `PAID` o `FULFILLED`.

- **Usuarios activos:** Se contabilizan tanto clientes identificados (`customer_id`) como visitas anónimas únicas (`session_id`) en la tabla de sesiones web.

## 4. Diccionario de Datos

El modelo de datos se estructuró en un esquema estrella con claves primarias (PK) y foráneas (FK).

### Dimensiones (Contexto)

- **`dim_date`:** Tabla de fechas generada día a día desde 2024 a 2025. PK: `date_key` (formato YYYYMMDD).

- **`dim_channel`:** Canales de venta (Online/Offline). PK: `channel_key`.

- **`dim_customer`:** Identificación y estado de los clientes. Incluye fila `-1` para anónimos. PK: `customer_key`.

- **`dim_geography`:** Normalización geográfica uniendo dirección (`address`) y provincia (`province`). PK: `geography_key`.

- **`dim_product`:** Maestro de productos (SKU) y su categoría/familia aplanada. PK: `product_key`.

- **`dim_store`:** Puntos de venta físicos. Incluye fila `-1` para compras puramente online. PK: `store_key`.

### Tablas de Hechos (Métricas)

- **`fact_sales_order`:** Cabecera transaccional de ventas. Grano: un registro por pedido. Métricas: `subtotal`, `tax_amount`, `shipping_fee` y `total_amount`.

- **`fact_sales_item`:** Detalle de líneas de pedido. Grano: un registro por producto vendido en cada pedido. Métricas: `quantity`, `unit_price`, `discount_amount` y `line_total`. Base para el ranking de productos.

- **`fact_web_session`:** Actividad digital. Grano: un registro por sesión. Contiene información de tráfico, como origen y dispositivo. Base para el análisis de usuarios activos.

- **`fact_nps`:** Encuestas de satisfacción del cliente. Grano: un registro por respuesta. Métrica: `score` (de 0 a 10).

## 5. Consultas Clave (KPIs)

Las consultas SQL utilizadas para calcular los requerimientos del dashboard se encuentran detalladas en `sql/03_consultas.sql`. La lógica principal implementada es:

1. **Ventas Totales ($M):** Se sumó el campo `total_amount` de la tabla de hechos `fact_sales_order`, filtrando por estado `PAID` o `FULFILLED` y agrupando por canal y período.

2. **Usuarios Activos (nK):** Se realizó un conteo de valores únicos (`COUNT DISTINCT`) de clientes identificados o de sesiones para las visitas anónimas en la tabla de hechos `fact_web_session`, por período.

3. **Ticket Promedio ($K):** Se dividió la suma de `total_amount` por el conteo de pedidos en `fact_sales_order`, aplicando los mismos filtros de estado de compra.

4. **NPS:** Sobre las respuestas de `fact_nps`, se restó el porcentaje de detractores (score de 0 a 6) al porcentaje de promotores (score de 9 a 10) y se multiplicó por 100, agrupando por canal y período.

5. **Ventas por Provincia:** Se agrupó el `total_amount` de las ventas concretadas, uniendo `fact_sales_order` con la dimensión geográfica para obtener el nombre de la provincia (`province_name`).

6. **Ranking de Ventas por Producto:** Se agrupó el campo `line_total` de la tabla `fact_sales_item` mediante una función de ventana (`RANK() OVER`), particionada por mes y ordenada descendentemente por las ventas totales.

## 6. Data Marts

Los data marts constituyen una capa de preparación y consulta de datos construida a partir del modelo estrella. Su objetivo es facilitar el análisis de los indicadores comerciales y de satisfacción, ofreciendo información organizada para las visualizaciones de Power BI.

A diferencia de las tablas de hechos y dimensiones, los marts no forman parte del diagrama del modelo estrella: son una capa posterior que utiliza sus datos para preparar consultas específicas.

Los marts se definen en el archivo `sql/04_marts.sql` y sus resultados se exportan al directorio `dw/` en formato CSV.

### Marts implementados

| Data mart | Descripción |
|---|---|
| `mart_ventas` | Contiene información de los pedidos considerados válidos según los estados definidos en SQL, junto con fechas, canales, clientes, tiendas, geografía e importes. |
| `mart_ticket_promedio` | Calcula la cantidad de pedidos incluidos, la facturación total y el ticket promedio. |
| `mart_nps` | Resume el NPS por fecha y canal, incluyendo el total de respuestas y las cantidades de promotores, neutros y detractores. |
| `mart_nps_responses` | Organiza las respuestas individuales de NPS, incluyendo la fecha, el canal, el cliente, la puntuación y su clasificación. |
| `mart_ventas_producto` | Permite analizar cantidades vendidas e importes por producto, categoría, canal y período. |
| `mart_usuarios_activos` | Resume los usuarios activos por fecha, distinguiendo clientes identificados y sesiones anónimas. Permite analizar la evolución diaria de la actividad digital. |
| `mart_usuarios_activos_total` | Calcula el total global de usuarios activos únicos, sumando los clientes identificados distintos y las sesiones anónimas distintas de `fact_web_session`. Está destinado a mostrar el total general en una tarjeta de Power BI, evitando sumar los conteos diarios y duplicar usuarios que aparecen en varias fechas. |
| `mart_nps_promedio` | Calcula el indicador NPS anual y la cantidad de respuestas consideradas en cada año. |

### Uso de los marts en Power BI

Los resultados de los marts se utilizan como fuentes de datos para construir las visualizaciones e indicadores del dashboard, entre ellos:

- Evolución de las ventas y del ticket promedio.
- Ventas por canal, producto y categoría.
- Evolución diaria de usuarios activos.
- Total global de usuarios activos únicos.
- Distribución de las respuestas NPS entre promotores, neutros y detractores.
- Evolución temporal y anual del NPS.

Para el análisis de usuarios activos, `mart_usuarios_activos` se utiliza para visualizar los valores diarios, mientras que `mart_usuarios_activos_total` permite mostrar el total global sin sumar los conteos de cada día. Este último no responde dinámicamente a filtros de fecha, ya que calcula el total de toda la tabla `fact_web_session`.

Los cálculos principales se realizan en SQL para que la lógica de negocio quede definida en el proceso de transformación de datos y los resultados puedan consumirse desde Power BI.

La ejecución de `python run_sql.py` permite reconstruir el Data Warehouse y volver a generar los archivos de salida, de acuerdo con las instrucciones implementadas en el script.