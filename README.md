# Trabajo Práctico: Ecosistema de Datos Comercial - EcoBottle AR

Este repositorio contiene la resolución del Trabajo Práctico de Introducción al Marketing Online y los Negocios Digitales[cite: 1]. El objetivo principal es diseñar e implementar un mini-ecosistema de datos comercial y construir un modelo para un dashboard de KPIs clave[cite: 1].

## 1. Instrucciones de Ejecución

Para reproducir este entorno de manera local mediante la consola, sigue estos pasos:

1. **Clonar el repositorio:** 
   Debes clonar tu fork del repositorio de manera local usando git[cite: 7].
   ```bash
   git clone 
   cd 

```

2. **Crear y activar un entorno virtual:**
La gestión del entorno virtual es una buena práctica requerida.


```bash
python -m venv .venv

```


* En Mac / Linux: `source .venv/bin/activate`.


* En Windows: `.venv\Scripts\activate`. *(Nota: Si Windows arroja un error de políticas, ejecuta primero `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process`).*




3. **Instalar dependencias:**
Se requiere instalar DuckDB y demás librerías.


```bash
pip install -r requirements.txt

```


4. **Ejecutar el modelo de datos (ETL):**
El script armará el Data Warehouse procesando los archivos de la carpeta `sql/`. Las tablas transformadas se guardarán como archivos `.csv` en el directorio `dw/`.


```bash
python run_sql.py

```



## 2. Gestión del Repositorio

Toda la gestión del repositorio se realizó mediante el uso exclusivo de la consola. Para el control de versiones se adoptó el estándar de **Conventional Commits** (ej: `feat: add dim_customer table`, `docs: update README instructions`) asegurando buenas prácticas.

## 3. Supuestos del Modelo

Durante la construcción del esquema estrella según el modelado de Kimball, se asumieron las siguientes reglas de negocio para asegurar la integridad de los datos:

* **Integridad Referencial (Nulos):** Para eventos anónimos o no aplicables (ej: usuarios no logueados en sesiones web, NPS anónimos, o pedidos ONLINE que no tienen una tienda física asignada), se insertó un registro comodín con el valor `-1` en las tablas de dimensiones (Cliente, Tienda, Geografía).


* **Cálculo de Ingresos:** Para los KPIs monetarios (Ventas Totales, Ticket Promedio y Ventas por Provincia), se consideraron únicamente los pedidos (`sales_order`) cuyo estado (`status`) era `PAID` o `FULFILLED`.


* **Usuarios Activos:** Se contabilizan tanto clientes identificados (`customer_id`) como visitas anónimas únicas (`session_id`) en la tabla de sesiones web.



## 4. Diccionario de Datos

El modelo de datos se estructuró en un esquema estrella con claves primarias (PK) y foráneas (FK).

### Dimensiones (Contexto)

* **`dim_date`**: Tabla de fechas generada día a día desde 2024 a 2025. PK: `date_key` (formato YYYYMMDD).


* **`dim_channel`**: Canales de venta (Online/Offline). PK: `channel_key`.


* **`dim_customer`**: Identificación y estado de los clientes. Incluye fila -1 para anónimos. PK: `customer_key`.


* **`dim_geography`**: Normalización geográfica uniendo dirección (`address`) y provincia (`province`). PK: `geography_key`.


* **`dim_product`**: Maestro de productos (SKU) y su categoría/familia aplanada. PK: `product_key`.


* **`dim_store`**: Puntos de venta físicos. Incluye fila -1 para compras puramente online. PK: `store_key`.



### Tablas de Hechos (Métricas)

* **`fact_sales_order`**: Cabecera transaccional de ventas. Grano: Un registro por pedido. Métricas: `subtotal`, `tax_amount`, `shipping_fee`, `total_amount`.


* **`fact_sales_item`**: Detalle de líneas de pedido. Grano: Un registro por producto vendido en cada pedido. Métricas: `quantity`, `unit_price`, `discount_amount`, `line_total`. Base para el ranking de productos.


* **`fact_web_session`**: Actividad digital. Grano: Un registro por sesión. Métricas de tráfico (origen y dispositivo). Base para usuarios activos.


* **`fact_nps`**: Encuestas de satisfacción del cliente. Grano: Un registro por respuesta. Métrica: `score` (0 a 10).



## 5. Consultas Clave (KPIs)

Las consultas SQL utilizadas para calcular los requerimientos del dashboard se encuentran detalladas en `sql/03_consultas.sql`. La lógica principal implementada es:

1. **Ventas Totales ($M):** Se sumó el campo `total_amount` de la tabla de hechos `fact_sales_order`, filtrando por estado `PAID` o `FULFILLED` y agrupando por canal y período.


2. **Usuarios Activos (nK):** Se realizó un conteo de valores únicos (`COUNT DISTINCT`) de clientes (o id de sesión si son anónimos) en la tabla de hechos `fact_web_session` por período.


3. **Ticket Promedio ($K):** Se dividió la suma de `total_amount` sobre el conteo total de pedidos en `fact_sales_order`, aplicando los mismos filtros de estado de compra.


4. **NPS:** Sobre las respuestas de `fact_nps`, se restó el porcentaje de detractores (score 0-6) al porcentaje de promotores (score 9-10) y se multiplicó por 100, agrupado por canal y período.


5. **Ventas por Provincia:** Se agrupó el `total_amount` de las ventas concretadas uniendo `fact_sales_order` con la dimensión geográfica para obtener el nombre de la provincia (`province_name`).


6. **Ranking de Ventas por Producto:** Se agrupó el campo `line_total` de la tabla `fact_sales_item` mediante una función de ventana (`RANK() OVER`) particionada por mes y ordenada descendentemente por las ventas totales.