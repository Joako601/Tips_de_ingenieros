# Paginación: por desplazamiento o por cursor

<!-- cspell:words Winand keyset OFFSET JdbcClient jdbc Jdbc paginación paginar KeysetScrollPosition AIP serializa Markus descartarlas creacion Creacion despues tamano -->

> **Tipo de página:** explicación. Te ayuda a elegir cómo dividir un listado en páginas; no es una referencia de un *framework*.

## El problema

`GET /pedidos` devuelve todos los pedidos. Con cien pedidos no hay problema. Con un millón, el servidor arma una lista enorme en memoria, la serializa y la envía por la red, y el cliente espera segundos para mostrar las primeras veinte filas.

La solución obvia es dividir el resultado en páginas. Lo que no es obvio es que la forma más común de hacerlo se vuelve lenta y entrega datos repetidos a medida que el sistema crece.

## La idea central

Hay dos estrategias principales para paginar.

**Por desplazamiento** (*offset*): el cliente pide "la página 5, de 20 elementos", y el servidor la traduce a `LIMIT 20 OFFSET 80`. Es la más común y la más fácil de implementar.

**Por cursor** o **por clave** (*keyset*): el cliente envía el último elemento que vio, y el servidor pide "los 20 siguientes a ese". Markus Winand llama a este enfoque *método de búsqueda* (*seek method*): en lugar de numerar filas, busca la última entrada de la página anterior y continúa desde ahí.

Winand explica el problema de fondo del desplazamiento: `OFFSET` solo dice cuántas filas descartar, sin más contexto. La base de datos tiene que leer y ordenar esas filas antes de descartarlas. Pedir la página 5 000 obliga a recorrer las 100 000 filas anteriores.

## Cómo se estructura

**Por desplazamiento:**

```sql
SELECT id, fecha_creacion FROM pedidos
ORDER BY fecha_creacion DESC, id DESC
LIMIT 20 OFFSET 100000;
```

**Por cursor**, usando el último elemento de la página anterior. La comparación de tuplas (*row values*) `(a, b) < (x, y)` respeta el mismo orden que el `ORDER BY`:

```sql
SELECT id, fecha_creacion FROM pedidos
WHERE (fecha_creacion, id) < (:ultimaFecha, :ultimoId)
ORDER BY fecha_creacion DESC, id DESC
LIMIT 20;
```

Para que el cursor sea rápido hacen falta dos cosas:

- **Un índice que coincida con el orden**, en este caso `(fecha_creacion DESC, id DESC)`.
- **Un orden total.** Si dos pedidos tienen la misma fecha, sin el `id` como desempate se pueden saltar o repetir filas.

En la API, el cursor se entrega como un valor opaco. Las guías de diseño de APIs de Google (AIP-158) lo llaman `page_token`: la respuesta incluye un `next_page_token`, el cliente lo devuelve para pedir la página siguiente, y la ausencia de ese campo indica que no hay más páginas.

## Cuándo no usarlo

- **El cursor cuando el usuario necesita saltar a una página concreta.** Por cursor no hay "ir a la página 37". Si la interfaz muestra números de página y los usuarios los usan, el desplazamiento encaja mejor.
- **El cursor en tablas pequeñas.** Si el listado nunca pasa de unos cientos de filas, la diferencia de rendimiento no se nota y el desplazamiento es más simple.
- **El desplazamiento en listados que crecen mientras se recorren**, como pedidos recientes o una cola de trabajo, o en exportaciones que recorren todo. Ahí se notan los dos problemas: lentitud y filas repetidas.

## Qué se gana y qué se pierde

| Estrategia | Se gana | Se pierde |
| --- | --- | --- |
| Desplazamiento | Simple; permite saltar a cualquier página y mostrar el total | Cada página más profunda es más lenta; filas repetidas o saltadas si cambian los datos |
| Cursor | Tiempo constante en cualquier página; sin repetidos al insertar filas | No se puede saltar a una página; exige un índice y un orden total |

## Confusiones frecuentes

- **"`OFFSET 100000 LIMIT 20` es rápido porque solo devuelve 20 filas."** Devuelve 20, pero lee 100 020. En el ejemplo de abajo, PostgreSQL recorre 100 020 entradas del índice para entregar las últimas 20.
- **"El desplazamiento solo es un problema de rendimiento."** Winand muestra el otro problema: si entra un pedido nuevo entre la página 1 y la 2, todo se corre una posición y el último elemento de la página 1 vuelve a aparecer al principio de la 2.
- **"El cursor tiene que ser el `id`."** Puede ser cualquier combinación de columnas que defina un orden total. Lo habitual es el campo por el que se ordena más el `id` como desempate.
- **"Exponer el cursor como `?despues_de_id=123` está bien."** Funciona, pero ata la API a la consulta interna. Un valor opaco, como los `page_token` de Google, permite cambiar la implementación sin romper a los clientes.

## Ejemplo

Medido en PostgreSQL 18 con un millón de pedidos y un índice `(fecha_creacion DESC, id DESC)`, pidiendo la página que empieza en la fila 100 001:

| Consulta | Filas leídas del índice | Bloques leídos | Tiempo |
| --- | --- | --- | --- |
| `LIMIT 20 OFFSET 100000` | 100 020 | 1 024 | 18,5 ms |
| `WHERE (fecha_creacion, id) < (...) LIMIT 20` | 20 | 4 | 0,075 ms |

La consulta por desplazamiento crece con la profundidad de la página. La consulta por cursor lee lo mismo en la página 1 que en la página 5 000.

En Java 21 con Spring, la consulta por cursor puede escribirse con `JdbcClient`. El fragmento es ilustrativo: omite los `import` y la codificación del cursor como valor opaco.

```java
record ResumenDePedido(UUID id, OffsetDateTime fechaCreacion) {}

record PaginaDePedidos(List<ResumenDePedido> pedidos, String siguiente) {}

@Service
class ListadoDePedidos {
    private final JdbcClient jdbc;

    ListadoDePedidos(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    PaginaDePedidos despuesDe(OffsetDateTime ultimaFecha, UUID ultimoId, int tamano) {
        var pedidos = jdbc.sql("""
                SELECT id, fecha_creacion FROM pedidos
                WHERE (fecha_creacion, id) < (:ultimaFecha, :ultimoId)
                ORDER BY fecha_creacion DESC, id DESC
                LIMIT :tamano
                """)
                .param("ultimaFecha", ultimaFecha)
                .param("ultimoId", ultimoId)
                .param("tamano", tamano)
                .query(ResumenDePedido.class)
                .list();
        var siguiente = pedidos.size() < tamano ? null : Cursor.de(pedidos.getLast());
        return new PaginaDePedidos(pedidos, siguiente);
    }
}
```

Spring Data también ofrece paginación por cursor con `KeysetScrollPosition` y `Window`, sin escribir el SQL a mano. En C# con .NET 8 se escribe igual con EF Core, con un `Where` que compara la fecha y el `id`.

## Referencias

- Winand, M. (2012). *SQL Performance Explained*. ISBN 978-3-9503078-2-5. Cap. 7, *Partial Results*. Versión en línea del autor: <https://use-the-index-luke.com/sql/partial-results/fetch-next-page> (consultado el 2026-10-29; [copia archivada](https://web.archive.org/web/20261021084142/https://use-the-index-luke.com/sql/partial-results/fetch-next-page)). Método de desplazamiento frente a método de búsqueda, comparación de tuplas y desplazamiento de las páginas al insertar filas.
- Winand, M. (2014, actualizado en 2023). *We need tool support for keyset pagination*. <https://use-the-index-luke.com/no-offset> (consultado el 2026-10-29; [copia archivada](https://web.archive.org/web/20260922150947/https://use-the-index-luke.com/no-offset)). Por qué `OFFSET` obliga a leer las filas descartadas y produce duplicados.
- Google (s. f.). *AIP-158: Pagination*. <https://google.aip.dev/158> (consultado el 2026-10-29; [copia archivada](https://web.archive.org/web/20260926083905/https://google.aip.dev/158)). `page_size`, `page_token` y `next_page_token` como cursor opaco.
- Spring (s. f.). *Scrolling* (Spring Data Commons Reference). <https://docs.spring.io/spring-data/commons/reference/repositories/scrolling.html> (consultado el 2026-10-29; [copia archivada](https://web.archive.org/web/20260401212600/https://docs.spring.io/spring-data/commons/reference/repositories/scrolling.html)). Paginación por cursor con `KeysetScrollPosition` y `Window`.

Última revisión: 2026-10-29
