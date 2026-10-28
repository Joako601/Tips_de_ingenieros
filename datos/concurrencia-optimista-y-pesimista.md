# Concurrencia optimista y pesimista

<!-- cspell:words Kung Robinson Jakarta rowversion OptimisticLockException PESSIMISTIC DbUpdateConcurrencyException ConcurrencyCheck Cancelacion cancelacion PREPARACION reintenta -->

> **Tipo de página:** explicación. Te ayuda a elegir cómo evitar que dos personas o procesos se pisen los cambios; no es una referencia de JPA ni de EF Core.

## El problema

Un cliente cancela su pedido desde la aplicación. En el mismo momento, un operador del depósito abre ese pedido en el panel interno y lo marca como "en preparación". Cada uno leyó el pedido antes de que el otro guardara. El segundo en guardar pisa el cambio del primero, en silencio: el pedido queda en preparación aunque el cliente lo canceló.

Este es el caso de la **actualización perdida** (*lost update*) que se describe en [transacciones y aislamiento](transacciones-y-acid.md), pero con una diferencia: aquí entre la lectura y la escritura pasan segundos o minutos, mientras una persona mira la pantalla. No se puede resolver solo con una transacción de base de datos abierta todo ese tiempo.

## La idea central

Hay dos estrategias, y las dos tienen décadas de historia:

- **Concurrencia optimista:** supone que los conflictos son raros. No bloquea nada al leer. Al guardar, comprueba que nadie haya cambiado el dato desde que se leyó y, si alguien lo cambió, rechaza la operación. H. T. Kung y John Robinson formalizaron este enfoque para bases de datos en 1981.
- **Concurrencia pesimista:** supone que los conflictos son probables. Bloquea el dato al leerlo, y nadie más puede modificarlo hasta que termine quien lo bloqueó.

Martin Fowler describe las dos como patrones en *Patterns of Enterprise Application Architecture* (2002): *Optimistic Offline Lock* y *Pessimistic Offline Lock*. "Offline" se refiere a que protegen una **transacción de negocio** que abarca varias peticiones, como "abrir el pedido, editarlo y guardarlo", y no solo una transacción de base de datos.

## Cómo se estructura

**Optimista con columna de versión.** Cada fila tiene un número de versión. Al guardar, la sentencia incluye la versión que se leyó y la incrementa:

```sql
UPDATE pedidos SET estado = 'EN_PREPARACION', version = version + 1
WHERE id = 1 AND version = 0;
```

Si otra transacción ya guardó, la versión ya no es 0 y la sentencia afecta **cero filas**. La aplicación detecta el conflicto y decide qué hacer: avisar al usuario, recargar o reintentar.

- En JPA basta con un atributo marcado con `@Version`. Si el `UPDATE` no afecta filas, el proveedor lanza `OptimisticLockException`.
- En EF Core, en SQL Server, se usa una columna `rowversion` mapeada con `[Timestamp]`, que la base cambia sola en cada modificación. Ante un conflicto, `SaveChanges` lanza `DbUpdateConcurrencyException`. `[ConcurrencyCheck]` sirve para que una propiedad concreta actúe como *token* de concurrencia.

**Pesimista con bloqueo de fila.** Se bloquea la fila al leerla, dentro de una transacción:

```sql
SELECT * FROM pedidos WHERE id = 1 FOR UPDATE;
```

Otra transacción que intente modificar o bloquear esa fila espera hasta que la primera termine. En JPA se pide con `LockModeType.PESSIMISTIC_WRITE`.

Si la transacción de negocio dura más que una petición, el bloqueo pesimista no puede ser un `FOR UPDATE`, porque la transacción de base de datos se cierra al terminar cada petición. En ese caso el bloqueo lo lleva la aplicación, por ejemplo con una tabla que registra quién tiene tomado cada pedido y hasta cuándo.

## Cuándo no usarlo

- **Optimista con mucha contención sobre la misma fila.** Si cien procesos actualizan el mismo contador a la vez, la mayoría falla y reintenta. Se gasta más trabajo en reintentos que en avanzar. Fowler advierte que, si los conflictos son frecuentes, quien pierde descubre al final que todo su trabajo fue inútil.
- **Pesimista entre peticiones de usuario.** Un bloqueo que depende de que la persona termine de editar puede quedar tomado si cierra el navegador. Hace falta un tiempo de expiración y una forma de liberar bloqueos huérfanos.
- **Cualquiera de los dos cuando una sentencia atómica alcanza.** Si la regla cabe en un `UPDATE ... WHERE cantidad > 0`, no hace falta versionar ni bloquear.

## Qué se gana y qué se pierde

| Estrategia | Se gana | Se pierde |
| --- | --- | --- |
| Optimista | Sin bloqueos ni esperas; escala bien con pocos conflictos | El conflicto se descubre al final y hay que manejarlo: avisar o reintentar |
| Pesimista | El conflicto se evita desde el principio | Esperas, riesgo de bloqueos mutuos y de bloqueos huérfanos |

## Confusiones frecuentes

- **"El bloqueo pesimista (`SELECT ... FOR UPDATE`) siempre es malo porque frena la base de datos."** Con mucha contención sobre la misma fila, el optimista produce una cadena de reintentos fallidos, y bloquear es más eficiente: las transacciones esperan su turno en lugar de repetir trabajo.
- **"`@Version` bloquea la fila."** No bloquea nada. Solo detecta, al guardar, que otro cambió la fila.
- **"Con concurrencia optimista no hace falta manejar errores."** La excepción de conflicto es parte del diseño. Si nadie la captura, el usuario ve un error genérico en lugar de "otra persona modificó este pedido; recarga para ver los cambios".
- **"Optimista y pesimista son niveles de aislamiento."** Son estrategias de la aplicación o del ORM. Funcionan sobre cualquier nivel de aislamiento, incluido `READ COMMITTED`.

## Ejemplo

Dominio de pedidos con Java 21 y JPA (Spring Boot 3). El fragmento es ilustrativo: omite los `import`, el resto de la entidad y la configuración.

La entidad lleva un atributo de versión. JPA lo incluye en cada `UPDATE` y lo incrementa:

```java
@Entity
class PedidoEntity {
    @Id
    private UUID id;

    private String estado;

    @Version
    private long version;

    void cancelar() {
        if ("ENVIADO".equals(estado)) {
            throw new IllegalStateException("No se puede cancelar un pedido enviado");
        }
        estado = "CANCELADO";
    }
}
```

El servicio carga el pedido y lo modifica dentro de una transacción. El controlador traduce el conflicto a una respuesta que la interfaz pueda mostrar:

```java
@Service
class ServicioDeCancelacion {
    private final PedidoRepository pedidos;

    ServicioDeCancelacion(PedidoRepository pedidos) {
        this.pedidos = pedidos;
    }

    @Transactional
    void cancelar(UUID pedidoId) {
        var pedido = pedidos.findById(pedidoId).orElseThrow();
        pedido.cancelar();
    }
}

@RestController
class CancelacionController {
    private final ServicioDeCancelacion servicio;

    CancelacionController(ServicioDeCancelacion servicio) {
        this.servicio = servicio;
    }

    @PostMapping("/pedidos/{id}/cancelacion")
    ResponseEntity<String> cancelar(@PathVariable UUID id) {
        try {
            servicio.cancelar(id);
            return ResponseEntity.noContent().build();
        } catch (ObjectOptimisticLockingFailureException e) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body("Otra persona modificó este pedido; recarga para ver los cambios");
        }
    }
}
```

Spring envuelve la `OptimisticLockException` de JPA en `ObjectOptimisticLockingFailureException`. Según la especificación, el conflicto puede detectarse recién al escribir los cambios, que en este caso ocurre al confirmar la transacción. Por eso la captura está fuera del servicio transaccional, en el controlador.

Comprobado en PostgreSQL 18 con dos sesiones que leyeron la versión 0: la primera en guardar actualiza una fila y la segunda afecta cero filas. Ese es el caso en que JPA lanza la excepción.

En C# con .NET 8 y EF Core, la entidad lleva `[Timestamp] public byte[] Version { get; set; }` y el servicio captura `DbUpdateConcurrencyException`.

## Referencias

- Kung, H. T. y Robinson, J. T. (1981). On Optimistic Methods for Concurrency Control. *ACM Transactions on Database Systems*, 6(2), 213-226. <https://doi.org/10.1145/319566.319567>. Formulación del control de concurrencia optimista.
- Fowler, M. (2002). *Patterns of Enterprise Application Architecture*. Addison-Wesley. ISBN 978-0-321-12742-6. Patrones *Optimistic Offline Lock* y *Pessimistic Offline Lock*. Resúmenes del autor: <https://martinfowler.com/eaaCatalog/optimisticOfflineLock.html> (consultado el 2026-10-28; [copia archivada](https://web.archive.org/web/20261021002135/https://martinfowler.com/eaaCatalog/optimisticOfflineLock.html)) y <https://martinfowler.com/eaaCatalog/pessimisticOfflineLock.html> (consultado el 2026-10-28; [copia archivada](https://web.archive.org/web/20261005035444/https://martinfowler.com/eaaCatalog/pessimisticOfflineLock.html)).
- Eclipse Foundation (2022). *Jakarta Persistence 3.1 Specification*. <https://jakarta.ee/specifications/persistence/3.1/jakarta-persistence-spec-3.1.html> (consultado el 2026-10-28; [copia archivada](https://web.archive.org/web/20261008214808/https://jakarta.ee/specifications/persistence/3.1/jakarta-persistence-spec-3.1.html)). Sección 3.4: bloqueo optimista, atributos de versión, bloqueo pesimista y `OptimisticLockException`.
- Microsoft (s. f.). *Handling Concurrency Conflicts (EF Core)*. <https://learn.microsoft.com/en-us/ef/core/saving/concurrency> (consultado el 2026-10-28; [copia archivada](https://web.archive.org/web/20260915021448/https://learn.microsoft.com/en-us/ef/core/saving/concurrency)). `[Timestamp]` con `rowversion`, `[ConcurrencyCheck]` y `DbUpdateConcurrencyException`.
- PostgreSQL Global Development Group (s. f.). *Explicit Locking*. <https://www.postgresql.org/docs/current/explicit-locking.html> (consultado el 2026-10-28; [copia archivada](https://web.archive.org/web/20261023034335/https://www.postgresql.org/docs/current/explicit-locking.html)). Bloqueo de filas con `FOR UPDATE`.

Última revisión: 2026-10-28
