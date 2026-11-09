# Entidades y objetos de valor

<!-- cspell:words Evans Fowler javac Dinero moneda monto entidad entidades inmutable inmutables inmutabilidad equals hashCode aliasing Direccion signum -->

> **Tipo de página:** explicación. Te ayuda a decidir si un concepto del dominio se distingue por su identidad o solo por sus datos; no es una guía de un *framework* concreto.

## El problema

En el sistema de pedidos aparecen `Pedido`, `Cliente`, `Dinero`, `Direccion`. Si todos se modelan como clases con un `id` generado por la base de datos y un *setter* por campo, el código trata igual cosas muy distintas: dos pedidos con los mismos datos siguen siendo dos pedidos distintos, pero dos importes de 10 dólares son simplemente el mismo importe.

Tratarlos igual tiene un costo concreto. Un importe mutable que se comparte entre dos objetos cambia en los dos cuando se cambia en uno, y compararlo exige acordarse de qué campos mirar.

## La idea central

Evans distingue dos clases de objetos del dominio según cómo se reconocen.

**Entidad.** Es un objeto que se distingue por su **identidad** y no por sus atributos. Representa un hilo de continuidad que atraviesa el tiempo: sus atributos pueden cambiar y sigue siendo el mismo. Según el resumen de Evans, una entidad a veces debe emparejarse con otra aunque sus atributos difieran, y debe distinguirse de otras aunque tengan los mismos atributos. Confundir identidades puede corromper datos. Por eso su definición en el modelo debe centrarse en el ciclo de vida y en la identidad.

**Objeto de valor** (*value object*). Es un objeto del que solo importan sus atributos y su lógica: describe algo y no tiene identidad conceptual. Evans pide tratarlo como **inmutable** y que sus operaciones sean funciones sin efectos secundarios, que no dependen de estado mutable.

Fowler lo expresa desde la igualdad: en un objeto de valor, la igualdad depende de los valores de sus propiedades; en los objetos que se distinguen por identidad se comparan referencias. Su regla principal es que los objetos de valor deben ser inmutables: para cambiar un valor se crea un objeto nuevo. Fowler menciona como ejemplo clásico una cantidad de dinero, que combina un número y una moneda.

Evans da la razón de no dar identidad a todo: seguir la identidad de las entidades es esencial, pero atribuirla a otros objetos puede dañar el rendimiento, añadir trabajo de análisis y enturbiar el modelo, porque todos los objetos pasan a parecer iguales.

## Cómo se estructura

| | Entidad | Objeto de valor |
| --- | --- | --- |
| Se reconoce por | Su identidad | Sus atributos |
| Dos instancias con los mismos atributos | Pueden ser distintas | Son equivalentes |
| Cambiar un atributo | Es el mismo objeto, con otro estado | Es otro valor: se crea uno nuevo |
| Ejemplo en pedidos | `Pedido`, `Cliente` | `Dinero`, `Direccion`, `Cantidad` |
| Igualdad | Por el identificador | Por todos sus atributos |

Tres reglas de diseño que salen de las fuentes:

1. **Un objeto de valor valida al crearse y no cambia después.** Si el monto no puede ser negativo, el constructor lo rechaza; así nunca existe un `Dinero` inválido.
2. **Sus operaciones devuelven valores nuevos.** `suma` no modifica el importe: devuelve otro. Evans pide que sean funciones sin efectos secundarios.
3. **La entidad se mantiene sencilla.** Evans recomienda que su definición se centre en la identidad y en el ciclo de vida,.

## Cuándo no usarlo

- **Cuando no hay reglas de negocio sobre el concepto.** Un campo de texto que solo se guarda y se muestra no necesita su propia clase; envolverlo en un tipo de valor sin validación añade código sin proteger nada.
- **Para modelar con identidad lo que no la necesita.** Es el caso contrario: dar `id` a cada dirección o a cada importe crea tablas, claves y comparaciones que el negocio no usa.
- **Para forzar inmutabilidad donde el concepto cambia con el tiempo.** El estado de un pedido cambia a lo largo de su vida; eso es una entidad, no un valor.

## Qué se gana y qué se pierde

| Se gana | Se pierde |
| --- | --- |
| Reglas como "el monto no es negativo" en un solo lugar | Más clases pequeñas que escribir |
| Valores comparables y utilizables sin cuidado, porque no cambian | Cada cambio crea un objeto nuevo |
| Entidades más sencillas, centradas en su ciclo de vida | Hay que decidir y documentar qué es entidad y qué es valor |

## Confusiones frecuentes

- **"Toda clase con un `id` es una entidad."** Es al revés: la identidad es lo que define a la entidad, y tenerla es una decisión de modelado que debe justificarse. Evans advierte del costo de atribuirla a objetos que no la necesitan.
- **"Un objeto de valor es un objeto sin comportamiento."** Evans pide que exprese el significado de sus atributos y que tenga funcionalidad relacionada: un `Dinero` sabe sumar y rechaza sumar monedas distintas.
- **"Inmutable es lo mismo que de solo lectura."** La regla de Fowler es que los valores no cambian: no basta con ocultar los *setters* si otra parte puede modificar por dentro un campo que es una lista o una fecha mutable. Su ejemplo es un cambio en una fecha compartida que mueve otra fecha sin que nadie lo pretenda.
- **"Dos entidades con los mismos datos son la misma."** Dos pedidos idénticos en contenido son dos pedidos; lo que los iguala es el identificador.

## Ejemplo

Dominio de pedidos con Java 21. Comprobado: compilado con `javac` de OpenJDK 21 y ejecutado.

`Dinero` es un `record`: inmutable, con igualdad por valor, y valida al crearse. `mas` devuelve un `Dinero` nuevo y rechaza monedas distintas:

```java
record Dinero(BigDecimal monto, String moneda) {
    Dinero {
        Objects.requireNonNull(monto);
        if (monto.signum() < 0) throw new IllegalArgumentException("El monto no puede ser negativo");
        if (moneda == null || moneda.length() != 3) throw new IllegalArgumentException("Moneda inválida");
    }

    Dinero mas(Dinero otro) {
        if (!moneda.equals(otro.moneda)) throw new IllegalArgumentException("Monedas distintas: " + moneda + " y " + otro.moneda);
        return new Dinero(monto.add(otro.monto), moneda);
    }
}
```

`Pedido` es una entidad: su igualdad depende solo del identificador y su total puede cambiar:

```java
static class Pedido {
    private final UUID id;
    private Dinero total;
    // ...
    @Override public boolean equals(Object o) { return o instanceof Pedido p && id.equals(p.id); }
    @Override public int hashCode() { return id.hashCode(); }
}
```

Salida de la ejecución:

```text
dos Dinero con el mismo valor son iguales: true
suma: Dinero[monto=15.50, moneda=USD]
rechazado: Monedas distintas: USD y EUR
rechazado: El monto no puede ser negativo
mismo id, distinto total, son el mismo pedido: true
mismo total, distinto id, son el mismo pedido: false
tras cambiar el total sigue siendo el mismo pedido: true
```

Las tres últimas líneas muestran la diferencia: en el valor manda el contenido; en la entidad, el identificador. En una aplicación con JPA, un objeto de valor suele guardarse dentro de la tabla de la entidad que lo usa, sin tabla ni clave propias; esa parte es ilustrativa y no se ejecutó. En .NET 8 el equivalente es un `record` para el valor y una clase con igualdad por identificador para la entidad.

## Referencias

- Evans, E. (2015). *Domain-Driven Design Reference: Definitions and Pattern Summaries*. Domain Language, Inc. <https://www.domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_2015-03.pdf> (consultado el 2026-11-09; [copia archivada](https://web.archive.org/web/20261011023500/https://www.domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_2015-03.pdf)). Secciones *Entities* y *Value Objects*: la identidad como definición de la entidad, y los objetos de valor inmutables con funciones sin efectos secundarios.
- Evans, E. (2003). *Domain-Driven Design: Tackling Complexity in the Heart of Software*. Addison-Wesley. Libro donde se formulan los patrones; no se consultó su texto, y la página se apoya en el resumen del propio Evans de 2015.
- Fowler, M. (2016). *ValueObject*. <https://martinfowler.com/bliki/ValueObject.html> (consultado el 2026-11-09; [copia archivada](https://web.archive.org/web/20261021181310/https://martinfowler.com/bliki/ValueObject.html)). Igualdad por valor, regla de inmutabilidad y el problema de los objetos mutables compartidos.

Última revisión: 2026-11-09
