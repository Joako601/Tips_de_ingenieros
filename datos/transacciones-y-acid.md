# Transacciones ACID y niveles de aislamiento

<!-- cspell:words Haerder Reuter Berenson Kleppmann Transactional serializabilidad serializable SERIALIZABLE Theo Härder Andreas Atomicidad atomicidad reintenta SIGMOD serialización -->

> **Tipo de página:** explicación. Te ayuda a entender qué garantiza una transacción y qué no; no es una referencia completa de cada motor de base de datos.

## El problema

En Spring basta con poner `@Transactional` sobre un método, y en .NET con abrir `BeginTransaction()`, para sentir que el código está protegido. Pero la mayoría de los equipos no sabe qué garantiza exactamente esa transacción cuando dos peticiones llegan al mismo tiempo.

El caso típico: queda una unidad de un producto en stock y dos clientes la compran a la vez. Cada petición lee el stock, ve que hay una unidad, la descuenta y confirma. Las dos transacciones terminan bien, sin errores, y el stock queda en -1.

## La idea central

Una **transacción** agrupa varias operaciones para que la base de datos las trate como una unidad. Theo Härder y Andreas Reuter acuñaron en 1983 el acrónimo **ACID** para sus cuatro propiedades:

- **Atomicidad (*Atomicity*):** o se aplican todas las operaciones o ninguna.
- **Consistencia (*Consistency*):** la transacción lleva la base de un estado válido a otro estado válido.
- **Aislamiento (*Isolation*):** las transacciones concurrentes no deberían interferir entre sí.
- **Durabilidad (*Durability*):** lo confirmado sobrevive a una caída del sistema.

La propiedad que más confusiones genera es el **aislamiento**, porque tiene grados. El aislamiento completo (**serializable**) significa que el resultado es el mismo que si las transacciones se hubieran ejecutado una detrás de otra. Es caro, así que los motores ofrecen niveles más débiles.

El estándar SQL define cuatro niveles según qué fenómenos permiten: `READ UNCOMMITTED`, `READ COMMITTED`, `REPEATABLE READ` y `SERIALIZABLE`. En 1995, Berenson, Bernstein, Gray y otros mostraron que esas definiciones son ambiguas y no cubren algunas anomalías importantes. Una de ellas es la **actualización perdida** (*lost update*): dos transacciones leen el mismo dato, cada una lo modifica según lo que leyó y la segunda en confirmar pisa el cambio de la primera.

## Cómo se estructura

| Nivel | Qué evita | Qué puede seguir pasando |
| --- | --- | --- |
| `READ UNCOMMITTED` | Casi nada | Leer datos que otra transacción todavía no confirmó |
| `READ COMMITTED` | Leer datos sin confirmar | Que el mismo dato cambie entre dos lecturas, actualizaciones perdidas |
| `REPEATABLE READ` | Lo anterior y que un dato leído cambie | Depende del motor; en PostgreSQL, algunas anomalías entre varias filas |
| `SERIALIZABLE` | Todas las anomalías | Nada, a cambio de transacciones que fallan y hay que reintentar |

**El nivel por defecto no es serializable.** PostgreSQL y SQL Server usan `READ COMMITTED` por defecto, y Spring respeta el nivel de la base salvo que indiques otro (`Isolation.DEFAULT`).

Cuando un nivel más estricto detecta un conflicto, no espera a resolverlo solo: aborta una de las transacciones. La documentación de PostgreSQL lo dice explícitamente: ante el error *could not serialize access due to concurrent update*, la aplicación debe abortar y **reintentar la transacción completa**.

## Cuándo no usarlo

Subir el nivel de aislamiento no siempre es la respuesta:

- **`SERIALIZABLE` para todo.** Protege contra todas las anomalías, pero produce más transacciones abortadas. Si el código no las reintenta, cambias datos incorrectos por errores visibles para el usuario.
- **Una transacción larga para proteger una operación que espera al usuario.** Una transacción de base de datos no debería quedar abierta mientras alguien llena un formulario. Para eso existen los bloqueos a nivel de aplicación (ver [concurrencia optimista y pesimista](concurrencia-optimista-y-pesimista.md)).
- **Cuando una sola sentencia resuelve el problema.** Si la operación cabe en un `UPDATE` con su condición, la base la aplica de forma atómica sin cambiar el nivel de aislamiento.

## Qué se gana y qué se pierde

| Opción | Se gana | Se pierde |
| --- | --- | --- |
| `READ COMMITTED` (por defecto) | Buen rendimiento y pocos conflictos | Protección contra actualizaciones perdidas: queda a cargo del código |
| `REPEATABLE READ` / `SERIALIZABLE` | La base detecta los conflictos por ti | Transacciones abortadas que hay que reintentar |
| `UPDATE` atómico con condición | Correcto en cualquier nivel, sin reintentos | Solo sirve si la regla cabe en una sentencia |
| `SELECT ... FOR UPDATE` | Las transacciones se ordenan en lugar de fallar | Esperas y posibles bloqueos mutuos (*deadlocks*) |

## Confusiones frecuentes

- **"ACID significa que las transacciones se ejecutan de una en una."** Eso sería aislamiento serializable, y casi ninguna base lo usa por defecto. Con `READ COMMITTED` dos transacciones pueden leer el mismo dato y pisarse.
- **"`@Transactional` evita los problemas de concurrencia."** Garantiza atomicidad: si algo falla, se deshace todo. No impide que otra transacción lea el mismo stock al mismo tiempo.
- **"La C de ACID es la misma consistencia que la del teorema CAP."** Son cosas distintas. En ACID, consistencia significa que se respetan las reglas de los datos; en sistemas distribuidos, que todos los nodos ven el mismo valor. Martin Kleppmann señala además que la C de ACID depende sobre todo de la aplicación, no de la base.
- **"`REPEATABLE READ` significa lo mismo en todos los motores."** Berenson y sus colegas mostraron que las definiciones del estándar son ambiguas, y cada motor las implementa distinto. Hay que leer la documentación del motor que usas.

## Ejemplo

Stock de un producto con una unidad y dos pedidos simultáneos, en PostgreSQL 18. Estos son los resultados reales de ejecutar cada variante con dos sesiones concurrentes.

**Leer, comprobar y restar** en `READ COMMITTED`, que es lo que hace la mayoría del código:

```sql
BEGIN;
SELECT cantidad FROM stock WHERE producto_id = 'A';      -- las dos sesiones leen 1
-- la aplicación comprueba que cantidad > 0
UPDATE stock SET cantidad = cantidad - 1 WHERE producto_id = 'A';
COMMIT;
-- resultado: cantidad = -1
```

**La misma operación en `REPEATABLE READ`.** La segunda sesión falla y el stock queda bien, pero el código tiene que reintentar:

```text
ERROR:  could not serialize access due to concurrent update
-- resultado: cantidad = 0
```

**Una sola sentencia con la condición.** Funciona en `READ COMMITTED`: la segunda sesión espera a la primera, vuelve a evaluar la condición sobre la fila actualizada y no modifica nada:

```sql
UPDATE stock SET cantidad = cantidad - 1
WHERE producto_id = 'A' AND cantidad > 0;
-- resultado: cantidad = 0; la segunda sesión afecta 0 filas
```

En Java 21 con Spring Data JPA, la versión atómica queda así. El fragmento es ilustrativo: omite los `import` y la entidad.

```java
interface StockRepository extends JpaRepository<Stock, String> {
    @Modifying
    @Query("UPDATE Stock s SET s.cantidad = s.cantidad - :cantidad "
            + "WHERE s.productoId = :productoId AND s.cantidad >= :cantidad")
    int descontar(String productoId, int cantidad);
}

@Service
class ServicioDeStock {
    private final StockRepository stock;

    ServicioDeStock(StockRepository stock) {
        this.stock = stock;
    }

    @Transactional
    void reservar(String productoId, int cantidad) {
        if (stock.descontar(productoId, cantidad) == 0) {
            throw new StockInsuficiente(productoId);
        }
    }
}
```

El número de filas afectadas dice si había stock. No hace falta leer antes ni cambiar el nivel de aislamiento.

En C# con .NET 8 y EF Core 8, `ExecuteUpdateAsync` permite la misma sentencia atómica sin cargar la entidad.

## Referencias

- Haerder, T. y Reuter, A. (1983). Principles of Transaction-Oriented Database Recovery. *ACM Computing Surveys*, 15(4), 287-317. <https://doi.org/10.1145/289.291>. Origen del acrónimo ACID.
- Berenson, H., Bernstein, P., Gray, J., Melton, J., O'Neil, E. y O'Neil, P. (1995). A Critique of ANSI SQL Isolation Levels. En *Proceedings of the 1995 ACM SIGMOD International Conference on Management of Data*, 1-10. <https://doi.org/10.1145/223784.223785>. Versión abierta: <https://arxiv.org/abs/cs/0701157> (consultado el 2026-10-28; [copia archivada](https://web.archive.org/web/20260611060140/https://arxiv.org/abs/cs/0701157)). Ambigüedad de los niveles del estándar y definición de la actualización perdida (sección 4.1).
- PostgreSQL Global Development Group (s. f.). *Transaction Isolation*. <https://www.postgresql.org/docs/current/transaction-iso.html> (consultado el 2026-10-28; [copia archivada](https://web.archive.org/web/20261024010311/https://www.postgresql.org/docs/current/transaction-iso.html)). Nivel por defecto, comportamiento de las actualizaciones concurrentes en cada nivel y reintento ante errores de serialización.
- Microsoft (s. f.). *SET TRANSACTION ISOLATION LEVEL (Transact-SQL)*. <https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql?view=sql-server-ver17> (consultado el 2026-10-28; [copia archivada](https://web.archive.org/web/20261018220722/https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql?view=sql-server-ver17)). `READ COMMITTED` como nivel por defecto de SQL Server.
- Spring (s. f.). *Enum Class Isolation*. <https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/transaction/annotation/Isolation.html> (consultado el 2026-10-28; [copia archivada](https://web.archive.org/web/20260607194214/https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/transaction/annotation/Isolation.html)). `Isolation.DEFAULT` usa el nivel de la base de datos.
- Kleppmann, M. (2017). *Designing Data-Intensive Applications*. O'Reilly Media. ISBN 978-1-449-37332-0. Cap. 7 (*Transactions*): significado de cada letra de ACID, niveles débiles de aislamiento y actualizaciones perdidas.

Última revisión: 2026-10-28
